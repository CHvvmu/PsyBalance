import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlanItemData {
  const PlanItemData({
    required this.id,
    required this.planId,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String planId;
  final String title;
  final String description;
  final String status;
  final DateTime? createdAt;

  factory PlanItemData.fromMap(Map<String, dynamic> row) {
    return PlanItemData(
      id: row['id']?.toString() ?? '',
      planId: row['plan_id']?.toString() ?? '',
      title: row['title']?.toString().trim() ?? '',
      description: row['description']?.toString().trim() ?? '',
      status: row['status']?.toString().trim() ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
    );
  }

  String get displayTitle => title.isEmpty ? 'Без названия' : title;

  String get displayDescription =>
      description.isEmpty ? 'Краткое описание появится позже' : description;

  String get normalizedStatus {
    switch (status) {
      case 'in_progress':
      case 'done':
        return status;
      default:
        return 'pending';
    }
  }

  String get statusLabel {
    switch (normalizedStatus) {
      case 'in_progress':
        return 'В работе';
      case 'done':
        return 'Шаг выполнен';
      default:
        return 'Намечен';
    }
  }
}

class PlanItemDetailsPage extends StatefulWidget {
  const PlanItemDetailsPage({super.key, required this.item});

  final PlanItemData item;

  @override
  State<PlanItemDetailsPage> createState() => _PlanItemDetailsPageState();
}

class _PlanItemDetailsPageState extends State<PlanItemDetailsPage> {
  final SupabaseClient _client = Supabase.instance.client;
  bool _isUpdating = false;
  String? _pendingEventType;

  static const String _appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.1.0+1',
  );

  String _platformLabel() {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Map<String, dynamic> _buildTaskEventMetadata({required String trigger}) {
    return <String, dynamic>{
      'source_screen': 'plan_item_details_page',
      'platform': _platformLabel(),
      'app_version': _appVersion,
      'trigger': trigger,
    };
  }

  Widget _buildButtonChild(String eventType, String label) {
    if (_pendingEventType == eventType) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Text(label);
  }

  Future<PlanItemData?> _reloadProjectedItem() async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('plan_items')
          .select('id, plan_id, title, description, status, created_at')
          .eq('id', widget.item.id)
          .maybeSingle();

      if (row == null) {
        return null;
      }

      return PlanItemData.fromMap(row);
    } catch (error) {
      debugPrint('TASK EVENT REFRESH WARNING: item_id=${widget.item.id}, error=$error');
      return null;
    }
  }

  Future<void> _submitTaskEvent(
    String eventType, {
    required String trigger,
    required String successMessage,
  }) async {
    if (_isUpdating) {
      return;
    }

    debugPrint('TASK EVENT START: item_id=${widget.item.id}, event_type=$eventType');

    setState(() {
      _isUpdating = true;
      _pendingEventType = eventType;
    });

    try {
      await _client.rpc(
        'record_task_event',
        params: <String, dynamic>{
          'task_id': widget.item.id,
          'event_type': eventType,
          'event_source': 'user',
          'metadata': _buildTaskEventMetadata(trigger: trigger),
        },
      );

      final PlanItemData? refreshedItem = await _reloadProjectedItem();
      if (refreshedItem != null) {
        debugPrint(
          'TASK EVENT REFRESH SUCCESS: item_id=${widget.item.id}, status=${refreshedItem.status}',
        );
      }

      debugPrint('TASK EVENT SUCCESS: item_id=${widget.item.id}, event_type=$eventType');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('TASK EVENT ERROR: item_id=${widget.item.id}, event_type=$eventType, error=$error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить действие')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _pendingEventType = null;
        });
      }
    }
  }

  Color _statusColor(String status, ColorScheme colors) {
    switch (status) {
      case 'in_progress':
        return colors.secondary;
      case 'done':
        return const Color(0xFF43A047);
      default:
        return colors.primary;
    }
  }

  Color _statusBackground(String status, ColorScheme colors) {
    switch (status) {
      case 'in_progress':
        return colors.secondary.withValues(alpha: 0.18);
      case 'done':
        return const Color(0xFF43A047).withValues(alpha: 0.15);
      default:
        return colors.primary.withValues(alpha: 0.16);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final PlanItemData item = widget.item;
    final String normalizedStatus = item.normalizedStatus;
    final bool isCompleted = normalizedStatus == 'done';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали шага'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      item.displayTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _statusBackground(normalizedStatus, colors),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.statusLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _statusColor(normalizedStatus, colors),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Описание',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.displayDescription,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isUpdating
                    ? null
                    : () => _submitTaskEvent(
                          'reopened',
                          trigger: isCompleted ? 'reopen_button' : 'start_work_button',
                          successMessage: isCompleted ? 'Шаг снова в работе' : 'Шаг отправлен в работу',
                        ),
                child: _buildButtonChild(
                  'reopened',
                  isCompleted ? 'Снова в работу' : 'В работу',
                ),
              ),
              if (!isCompleted) ...<Widget>[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isUpdating
                      ? null
                      : () => _submitTaskEvent(
                            'completed',
                            trigger: 'completed_button',
                            successMessage: 'Шаг отмечен как выполненный',
                          ),
                  child: _buildButtonChild('completed', 'Шаг выполнен'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isUpdating
                      ? null
                      : () => _submitTaskEvent(
                            'skipped',
                            trigger: 'skip_button',
                            successMessage: 'Шаг пропущен',
                          ),
                  child: _buildButtonChild('skipped', 'Пропустить'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
