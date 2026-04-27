import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../plan/plan_item_details_page.dart';

class CoachPlanEditorPage extends StatefulWidget {
  const CoachPlanEditorPage({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  final String clientId;
  final String clientName;

  @override
  State<CoachPlanEditorPage> createState() => _CoachPlanEditorPageState();
}

class _CoachPlanEditorPageState extends State<CoachPlanEditorPage> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _planId;
  String? _weekStartLabel;
  List<PlanItemData> _items = <PlanItemData>[];

  String get _displayClientId => widget.clientId.trim();

  String get _displayClientName {
    final String trimmed = widget.clientName.trim();
    return trimmed.isEmpty ? 'Клиент' : trimmed;
  }

  @override
  void initState() {
    super.initState();
    debugPrint(
      'COACH PLAN EDITOR INIT: clientId=$_displayClientId, clientName=$_displayClientName',
    );
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final String clientId = _displayClientId;
    debugPrint('COACH PLAN LOAD START: clientId=$clientId');

    if (clientId.isEmpty) {
      debugPrint('COACH PLAN LOAD ERROR: empty clientId');
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Не удалось открыть план клиента';
        _planId = null;
        _weekStartLabel = null;
        _items = <PlanItemData>[];
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final Map<String, dynamic>? planRow = await _client
          .from('plans')
          .select('id, user_id, week_start, created_at')
          .eq('user_id', clientId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final Map<String, dynamic> resolvedPlanRow =
          planRow ?? await _createPlan(clientId);
      final String planId = resolvedPlanRow['id']?.toString() ?? '';
      final String weekStartLabel = _formatDateLabel(
        resolvedPlanRow['week_start']?.toString(),
      );

      final List<dynamic> rows = await _client
          .from('plan_items')
          .select('id, plan_id, title, description, status, created_at')
          .eq('plan_id', planId);

      final List<PlanItemData> items = rows
          .map((dynamic rowData) => PlanItemData.fromMap(rowData as Map<String, dynamic>))
          .toList()
        ..sort(_compareItemsByCreatedAt);

      debugPrint(
        'COACH PLAN LOAD SUCCESS: clientId=$clientId planId=$planId items=${items.length}',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _planId = planId;
        _weekStartLabel = weekStartLabel;
        _items = items;
      });
    } catch (error) {
      debugPrint('COACH PLAN LOAD ERROR: clientId=$clientId error=$error');
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Не удалось загрузить план';
        _planId = null;
        _weekStartLabel = null;
        _items = <PlanItemData>[];
      });
    }
  }

  Future<Map<String, dynamic>> _createPlan(String clientId) async {
    final String weekStart = _formatDatabaseDate(_startOfWeek(DateTime.now()));
    debugPrint('COACH PLAN CREATE START: clientId=$clientId weekStart=$weekStart');

    final Map<String, dynamic> inserted =
        await _client.from('plans').insert(<String, dynamic>{
      'user_id': clientId,
      'week_start': weekStart,
    }).select('id, user_id, week_start, created_at').single();

    debugPrint(
      'COACH PLAN CREATE SUCCESS: clientId=$clientId planId=${inserted['id']}',
    );

    return inserted;
  }

  Future<void> _openItemEditor({PlanItemData? item}) async {
    if (_isLoading || _isSaving) {
      return;
    }

    final _CoachPlanItemDraft? draft = await showDialog<_CoachPlanItemDraft>(
      context: context,
      builder: (BuildContext context) {
        return _CoachPlanItemEditorDialog(item: item);
      },
    );

    if (draft == null || !mounted) {
      return;
    }

    await _saveItem(item: item, draft: draft);
  }

  Future<void> _saveItem({
    required _CoachPlanItemDraft draft,
    PlanItemData? item,
  }) async {
    final String clientId = _displayClientId;
    final String planId = _planId ?? '';

    if (planId.isEmpty) {
      debugPrint('COACH PLAN ITEM SAVE ERROR: clientId=$clientId planId is empty');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('План ещё не загружен')),
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (item == null) {
        debugPrint(
          'COACH PLAN ITEM INSERT START: clientId=$clientId planId=$planId title=${draft.title}',
        );

        final Map<String, dynamic> inserted = await _client
            .from('plan_items')
            .insert(<String, dynamic>{
          'plan_id': planId,
          'title': draft.title,
          'description': draft.description,
          'status': draft.status,
          'updated_at': DateTime.now().toIso8601String(),
        }).select('id, plan_id, title, description, status, created_at').single();

        final PlanItemData newItem = PlanItemData.fromMap(inserted);
        debugPrint(
          'COACH PLAN ITEM INSERT SUCCESS: clientId=$clientId itemId=${newItem.id}',
        );
        _upsertLocalItem(newItem);
      } else {
        debugPrint(
          'COACH PLAN ITEM UPDATE START: clientId=$clientId itemId=${item.id}',
        );

        final Map<String, dynamic> updated = await _client
            .from('plan_items')
            .update(<String, dynamic>{
          'title': draft.title,
          'description': draft.description,
          'status': draft.status,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', item.id).select('id, plan_id, title, description, status, created_at').single();

        final PlanItemData updatedItem = PlanItemData.fromMap(updated);
        debugPrint(
          'COACH PLAN ITEM UPDATE SUCCESS: clientId=$clientId itemId=${updatedItem.id}',
        );
        _upsertLocalItem(updatedItem);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item == null ? 'Задача добавлена' : 'Задача обновлена',
          ),
        ),
      );
    } catch (error) {
      debugPrint(
        'COACH PLAN ITEM SAVE ERROR: clientId=$clientId planId=$planId error=$error',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить задачу')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteItem(PlanItemData item) async {
    if (_isLoading || _isSaving) {
      return;
    }

    final bool shouldDelete = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Удалить задачу?'),
              content: Text('Задача "${item.displayTitle}" будет удалена из плана.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Удалить'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete || !mounted) {
      return;
    }

    final String clientId = _displayClientId;
    final String planId = _planId ?? '';

    if (planId.isEmpty) {
      debugPrint('COACH PLAN ITEM DELETE ERROR: clientId=$clientId planId is empty');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      debugPrint(
        'COACH PLAN ITEM DELETE START: clientId=$clientId itemId=${item.id}',
      );

      await _client.from('plan_items').delete().eq('id', item.id);

      debugPrint(
        'COACH PLAN ITEM DELETE SUCCESS: clientId=$clientId itemId=${item.id}',
      );

      _removeLocalItem(item.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Задача удалена')),
      );
    } catch (error) {
      debugPrint(
        'COACH PLAN ITEM DELETE ERROR: clientId=$clientId itemId=${item.id} error=$error',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить задачу')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _upsertLocalItem(PlanItemData item) {
    final List<PlanItemData> nextItems = List<PlanItemData>.from(_items);
    final int index = nextItems.indexWhere((PlanItemData value) => value.id == item.id);

    if (index == -1) {
      nextItems.add(item);
    } else {
      nextItems[index] = item;
    }

    nextItems.sort(_compareItemsByCreatedAt);

    if (!mounted) {
      return;
    }

    setState(() {
      _items = nextItems;
    });
  }

  void _removeLocalItem(String itemId) {
    if (!mounted) {
      return;
    }

    setState(() {
      _items = _items.where((PlanItemData item) => item.id != itemId).toList();
    });
  }

  int _compareItemsByCreatedAt(PlanItemData left, PlanItemData right) {
    final DateTime? leftCreated = left.createdAt;
    final DateTime? rightCreated = right.createdAt;

    if (leftCreated == null && rightCreated == null) {
      return 0;
    }
    if (leftCreated == null) {
      return 1;
    }
    if (rightCreated == null) {
      return -1;
    }
    return leftCreated.compareTo(rightCreated);
  }

  DateTime _startOfWeek(DateTime dateTime) {
    final DateTime localDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    return localDate.subtract(Duration(days: localDate.weekday - 1));
  }

  String _formatDatabaseDate(DateTime dateTime) {
    final String day = dateTime.day.toString().padLeft(2, '0');
    final String month = dateTime.month.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day';
  }

  String _formatDateLabel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Неделя не указана';
    }

    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }

    final String day = parsed.day.toString().padLeft(2, '0');
    final String month = parsed.month.toString().padLeft(2, '0');
    return '$day.$month.${parsed.year}';
  }

  String _formatCreatedAt(DateTime? value) {
    if (value == null) {
      return 'Дата создания не указана';
    }

    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String hours = value.hour.toString().padLeft(2, '0');
    final String minutes = value.minute.toString().padLeft(2, '0');
    return '$day.$month.${value.year} $hours:$minutes';
  }

  _StatusColors _statusColors(String status) {
    switch (status) {
      case 'in_progress':
        return const _StatusColors(
          background: Color(0xFFFEF3C7),
          border: Color(0xFFFDE68A),
          text: Color(0xFF92400E),
        );
      case 'done':
        return const _StatusColors(
          background: Color(0xFFDCFCE7),
          border: Color(0xFFBBF7D0),
          text: Color(0xFF166534),
        );
      default:
        return const _StatusColors(
          background: Color(0xFFE0F2FE),
          border: Color(0xFFBAE6FD),
          text: Color(0xFF075985),
        );
    }
  }

  Widget _buildItemCard(PlanItemData item, ThemeData theme, ColorScheme colors) {
    final TextTheme textTheme = theme.textTheme;
    final _StatusColors statusColors = _statusColors(item.normalizedStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.displayTitle,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.displayDescription,
                      style: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColors.background,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColors.border),
                ),
                child: Text(
                  item.statusLabel,
                  style: textTheme.labelSmall?.copyWith(color: statusColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatCreatedAt(item.createdAt),
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _openItemEditor(item: item),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Изменить'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _deleteItem(item),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Удалить'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    side: BorderSide(color: colors.error.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme, ColorScheme colors) {
    return SizedBox(
      height: 240,
      child: Center(
        child: CircularProgressIndicator(color: colors.primary),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _errorMessage ?? 'Не удалось загрузить план',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Попробуйте обновить страницу.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _loadPlan,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Пока нет задач в плане',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте первую задачу, чтобы начать работу с планом клиента.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : () => _openItemEditor(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить задачу'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading || _isSaving ? null : () => _openItemEditor(),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Новая задача'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Редактор плана',
                          style: textTheme.titleMedium?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _displayClientName,
                          style: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading || _isSaving ? null : _loadPlan,
                    icon: Icon(Icons.refresh_rounded, color: colors.onSurface),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadPlan,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Клиент: $_displayClientName',
                            style: textTheme.titleMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Client ID: $_displayClientId',
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _InfoChip(
                              icon: Icons.date_range_rounded,
                              label: 'Неделя',
                              value: _weekStartLabel ?? '—',
                            ),
                            _InfoChip(
                              icon: Icons.list_alt_rounded,
                              label: 'Задач',
                              value: _items.length.toString(),
                            ),
                            const _InfoChip(
                              icon: Icons.sync_rounded,
                              label: 'Сохранение',
                              value: 'Supabase',
                            ),
                          ],
                        ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Задачи плана',
                          style: textTheme.titleMedium?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isLoading || _isSaving ? null : () => _openItemEditor(),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Добавить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_isLoading)
                      _buildLoadingState(theme, colors)
                    else if (_errorMessage != null)
                      _buildErrorState(theme, colors)
                    else if (_items.isEmpty)
                      _buildEmptyState(theme, colors)
                    else
                      ..._items.map((PlanItemData item) => _buildItemCard(item, theme, colors)),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: textTheme.labelSmall,
              ),
              Text(
                value,
                style: textTheme.labelLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusColors {
  const _StatusColors({
    required this.background,
    required this.border,
    required this.text,
  });

  final Color background;
  final Color border;
  final Color text;
}

class _CoachPlanItemDraft {
  const _CoachPlanItemDraft({
    required this.title,
    required this.description,
    required this.status,
  });

  final String title;
  final String description;
  final String status;
}

class _CoachPlanItemEditorDialog extends StatefulWidget {
  const _CoachPlanItemEditorDialog({this.item});

  final PlanItemData? item;

  @override
  State<_CoachPlanItemEditorDialog> createState() => _CoachPlanItemEditorDialogState();
}

class _CoachPlanItemEditorDialogState extends State<_CoachPlanItemEditorDialog> {
  static const List<DropdownMenuItem<String>> _statusItems = <DropdownMenuItem<String>>[
    DropdownMenuItem<String>(value: 'pending', child: Text('Ожидает')),
    DropdownMenuItem<String>(value: 'in_progress', child: Text('В процессе')),
    DropdownMenuItem<String>(value: 'done', child: Text('Сделано')),
  ];

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _status;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _descriptionController = TextEditingController(text: widget.item?.description ?? '');
    _status = widget.item?.normalizedStatus ?? 'pending';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название задачи')),
      );
      return;
    }

    Navigator.of(context).pop(
      _CoachPlanItemDraft(
        title: title,
        description: description,
        status: _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Новая задача' : 'Изменить задачу'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Название',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                items: _statusItems,
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _status = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Статус',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
