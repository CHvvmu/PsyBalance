import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../plan/active_plan_repository.dart';
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
  String? _weekStartValue;
  List<PlanItemData> _items = <PlanItemData>[];

  String get _displayClientId => widget.clientId.trim();

  String get _displayClientName {
    final String trimmed = widget.clientName.trim();
    return trimmed.isEmpty ? 'Без имени' : trimmed;
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
        _errorMessage = 'План пока недоступен';
        _planId = null;
        _weekStartLabel = null;
        _weekStartValue = null;
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
      final Map<String, dynamic>? planRow = await loadOrCreateActivePlanRow(
        client: _client,
        userId: clientId,
        sourceLabel: 'coach-plan-editor',
      );

      final String? planId = planRow?['id']?.toString();
      final String weekStartLabel = _formatDateLabel(planRow?['week_start']?.toString());
      final String weekStartValue = planRow?['week_start']?.toString() ?? '';

      final List<Map<String, dynamic>> rows = planId == null || planId.isEmpty
          ? <Map<String, dynamic>>[]
          : await loadActivePlanItemRows(
              client: _client,
              planId: planId,
              sourceLabel: 'coach-plan-editor',
            );

      final List<PlanItemData> items = rows
          .map((Map<String, dynamic> rowData) => PlanItemData.fromMap(rowData))
          .toList()
        ..sort(_compareItemsByCreatedAt);

      debugPrint(
        'COACH PLAN LOAD SUCCESS: clientId=$clientId planId=${planId ?? ''} items=${items.length}',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _planId = planId;
        _weekStartLabel = weekStartLabel;
        _weekStartValue = weekStartValue;
        _items = items;
      });
    } catch (error) {
      debugPrint('COACH PLAN LOAD ERROR: clientId=$clientId error=$error');
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'План пока недоступен';
        _planId = null;
        _weekStartLabel = null;
        _weekStartValue = null;
        _items = <PlanItemData>[];
      });
    }
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
    String planId = _planId ?? '';
    final String weekStartValue = _weekStartValue?.trim().isNotEmpty == true
        ? _weekStartValue!.trim()
        : _formatDatabaseDate(_startOfWeek(DateTime.now()));

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

        if (_planId == null || _planId!.isEmpty) {
          final Map<String, dynamic>? activePlan = await loadOrCreateActivePlanRow(
            client: _client,
            userId: clientId,
            sourceLabel: 'coach-plan-editor-save',
          );

          _planId = activePlan?['id']?.toString();
          planId = _planId ?? '';
        }

        await _client.rpc(
          'create_plan_item',
          params: <String, dynamic>{
            'p_client_id': clientId,
            'p_title': draft.title,
            'p_description': draft.description.isEmpty ? null : draft.description,
            'p_week_start': weekStartValue,
            'p_request_key': _requestKey('create', clientId: clientId, itemId: 'new'),
          },
        );

        debugPrint('COACH PLAN ITEM INSERT SUCCESS: clientId=$clientId planId=$planId');
        await _loadPlan();
      } else {
        debugPrint(
          'COACH PLAN ITEM UPDATE START: clientId=$clientId itemId=${item.id}',
        );

        await _client.rpc(
          'update_plan_item',
          params: <String, dynamic>{
            'p_task_id': item.id,
            'p_title': draft.title,
            'p_description': draft.description.isEmpty ? null : draft.description,
            'p_request_key': _requestKey('update', clientId: clientId, itemId: item.id),
          },
        );

        debugPrint('COACH PLAN ITEM UPDATE SUCCESS: clientId=$clientId itemId=${item.id}');
        await _loadPlan();
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(item == null ? 'Шаг добавлен' : 'Шаг обновлён'),
        ),
      );
    } catch (error) {
      debugPrint(
        'COACH PLAN ITEM SAVE ERROR: clientId=$clientId planId=$planId error=$error',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить шаг')),
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

  String _requestKey(
    String action, {
    required String clientId,
    required String itemId,
  }) {
    return 'coach_plan:$action:$clientId:$itemId:${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> _deleteItem(PlanItemData item) async {
    if (_isLoading || _isSaving) {
      return;
    }

    final bool shouldDelete = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Удалить шаг?'),
              content: Text('Шаг "${item.displayTitle}" будет удалён из плана.'),
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

      await _loadPlan();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Шаг удалён')),
      );
    } catch (error) {
      debugPrint(
        'COACH PLAN ITEM DELETE ERROR: clientId=$clientId itemId=${item.id} error=$error',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить шаг')),
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
            _errorMessage ?? 'План пока недоступен',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Попробуйте еще раз через пару секунд.',
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
            'Пока в плане нет шагов',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте первый небольшой шаг, чтобы мягко запустить ритм работы.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : () => _openItemEditor(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить шаг'),
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
        label: const Text('Новый шаг'),
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
                              label: 'Шагов',
                              value: _items.length.toString(),
                            ),
                            const _InfoChip(
                              icon: Icons.sync_rounded,
                              label: 'Сохранение',
                              value: 'Автосохранение',
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
                          'Шаги плана',
                          style: textTheme.titleMedium?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isLoading || _isSaving ? null : () => _openItemEditor(),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Добавить шаг'),
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
  });

  final String title;
  final String description;
}

class _CoachPlanItemEditorDialog extends StatefulWidget {
  const _CoachPlanItemEditorDialog({this.item});

  final PlanItemData? item;

  @override
  State<_CoachPlanItemEditorDialog> createState() => _CoachPlanItemEditorDialogState();
}

class _CoachPlanItemEditorDialogState extends State<_CoachPlanItemEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _descriptionController = TextEditingController(text: widget.item?.description ?? '');
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
        const SnackBar(content: Text('Введите название шага')),
      );
      return;
    }

    Navigator.of(context).pop(
      _CoachPlanItemDraft(
        title: title,
        description: description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Новый шаг' : 'Изменить шаг'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Название шага',
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
