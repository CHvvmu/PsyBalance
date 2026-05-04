import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'active_plan_repository.dart';
import 'plan_item_details_page.dart';

class ClientPlanPage extends StatefulWidget {
  const ClientPlanPage({super.key});

  @override
  State<ClientPlanPage> createState() => _ClientPlanPageState();
}

class _ClientPlanPageState extends State<ClientPlanPage> {
  final SupabaseClient _client = Supabase.instance.client;

  RealtimeChannel? _realtimeChannel;
  Timer? _refreshDebounce;

  bool _isLoading = true;
  bool _reloadRequestedWhileLoading = false;
  String? _errorMessage;
  String? _planId;
  String? _weekStartLabel;
  String? _realtimeUserId;
  List<PlanItemData> _items = <PlanItemData>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlan());
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    unawaited(_disposeRealtimeChannel());
    super.dispose();
  }

  Future<void> _ensureRealtimeSubscription(String userId) async {
    if (_realtimeUserId == userId && _realtimeChannel != null) {
      return;
    }

    await _disposeRealtimeChannel();

    final RealtimeChannel channel = _client.channel('client-plan-$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'behavior_events',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'primary_user_id',
        value: userId,
      ),
      callback: (payload) {
        debugPrint(
          'CLIENT PLAN REALTIME EVENT: userId=$userId eventType=${payload.eventType}',
        );
        _scheduleReload();
      },
    );

    channel.subscribe((status, error) {
      if (error != null) {
        debugPrint('CLIENT PLAN REALTIME SUBSCRIBE ERROR: userId=$userId error=$error');
      }

      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('CLIENT PLAN REALTIME SUBSCRIBED: userId=$userId');
      }
    });

    _realtimeChannel = channel;
    _realtimeUserId = userId;
  }

  Future<void> _disposeRealtimeChannel() async {
    final RealtimeChannel? channel = _realtimeChannel;
    _realtimeChannel = null;
    _realtimeUserId = null;

    if (channel == null) {
      return;
    }

    try {
      await channel.unsubscribe();
    } catch (error) {
      debugPrint('CLIENT PLAN REALTIME UNSUBSCRIBE ERROR: $error');
    }

    try {
      await _client.removeChannel(channel);
    } catch (error) {
      debugPrint('CLIENT PLAN REALTIME REMOVE CHANNEL ERROR: $error');
    }
  }

  void _scheduleReload() {
    if (!mounted) {
      return;
    }

    if (_isLoading) {
      _reloadRequestedWhileLoading = true;
      return;
    }

    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }

      unawaited(_loadPlan());
    });
  }

  Future<void> _loadPlan() async {
    final User? currentUser = _client.auth.currentUser;
    debugPrint('CLIENT PLAN LOAD START');

    if (currentUser == null) {
      await _disposeRealtimeChannel();

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'План доступен после входа в аккаунт';
        _planId = null;
        _weekStartLabel = null;
        _items = <PlanItemData>[];
      });
      return;
    }

    await _ensureRealtimeSubscription(currentUser.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic>? planRow = await loadOrCreateActivePlanRow(
        client: _client,
        userId: currentUser.id,
        sourceLabel: 'client-plan-page',
      );
      if (planRow == null) {
        debugPrint('CLIENT PLAN LOAD EMPTY: userId=${currentUser.id} reason=plan_row_null');
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _planId = null;
          _weekStartLabel = null;
          _items = <PlanItemData>[];
        });
        return;
      }

      final String planId = planRow['id']?.toString() ?? '';
      final String weekStartLabel = _formatWeekStart(planRow['week_start']?.toString());

      final List<Map<String, dynamic>> rows = await loadActivePlanItemRows(
        client: _client,
        planId: planId,
        sourceLabel: 'client-plan-page',
      );

      final List<PlanItemData> items = await buildPlanItemsFromProjectedRows(
        client: _client,
        rows: rows,
      );
      items.sort(_compareItemsByCreatedAt);

      debugPrint(
        'CLIENT PLAN LOAD SUCCESS: userId=${currentUser.id} planId=$planId items=${items.length}',
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
      debugPrint('CLIENT PLAN LOAD ERROR: userId=${currentUser.id} error=$error');
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'План пока недоступен';
        _planId = null;
        _weekStartLabel = null;
        _items = <PlanItemData>[];
      });
    } finally {
      if (mounted && _reloadRequestedWhileLoading) {
        _reloadRequestedWhileLoading = false;
        _scheduleReload();
      }
    }
  }

  Future<void> _openItemDetails(PlanItemData item) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PlanItemDetailsPage(item: item),
      ),
    );

    if (changed == true && mounted) {
      await _loadPlan();
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

  String _formatWeekStart(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }

    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }

    final DateTime normalized = DateUtils.dateOnly(parsed);
    final String day = normalized.day.toString().padLeft(2, '0');
    final String month = normalized.month.toString().padLeft(2, '0');
    return '$day.$month.${normalized.year}';
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

  Widget _buildHeaderCard(ThemeData theme, ColorScheme colors) {
    final TextTheme textTheme = theme.textTheme;

    return Container(
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
            'План на неделю',
            style: textTheme.titleLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Здесь показываются только реальные шаги из Supabase.',
            style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _InfoChip(
                icon: Icons.date_range_rounded,
                label: 'Неделя',
                value: _weekStartLabel?.isNotEmpty == true ? _weekStartLabel! : '—',
              ),
              _InfoChip(
                icon: Icons.list_alt_rounded,
                label: 'Шагов',
                value: _items.length.toString(),
              ),
              const _InfoChip(
                icon: Icons.sync_rounded,
                label: 'Источник',
                value: 'Supabase',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colors) {
    return Container(
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
            _errorMessage ?? 'План пока недоступен',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Попробуйте обновить экран через пару секунд.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _loadPlan,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Обновить'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colors) {
    final String message = _planId == null
        ? 'План появится после первых шагов.'
        : 'Пока здесь тихо. Когда coach назначит шаги, они появятся здесь.';

    return Container(
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
            'Нет активных шагов',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _loadPlan,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Проверить снова'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(PlanItemData item, ThemeData theme, ColorScheme colors) {
    final _StatusColors statusColors = _statusColors(item.normalizedStatus);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _openItemDetails(item),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
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
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.displayDescription,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _InfoChip(
                                icon: Icons.event_rounded,
                                label: 'Дата',
                                value: item.displayScheduledLabel,
                              ),
                              _InfoChip(
                                icon: Icons.sell_outlined,
                                label: 'Категория',
                                value: item.displayCategoryLabel,
                              ),
                            ],
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
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Открыть детали шага',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('План на неделю'),
        actions: <Widget>[
          IconButton(
            onPressed: _isLoading ? null : _loadPlan,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPlan,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildHeaderCard(theme, colors),
                const SizedBox(height: 20),
                if (_isLoading)
                  _buildLoadingState(theme, colors)
                else if (_errorMessage != null)
                  _buildErrorState(theme, colors)
                else if (_items.isEmpty)
                  _buildEmptyState(theme, colors)
                else
                  Column(
                    children: _items.map((PlanItemData item) => _buildItemCard(item, theme, colors)).toList(),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
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
