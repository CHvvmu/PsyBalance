import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'active_plan_repository.dart';

class PlanItemData {
  const PlanItemData({
    required this.id,
    required this.planId,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.scheduledAt,
    required this.category,
  });

  final String id;
  final String planId;
  final String title;
  final String description;
  final String status;
  final DateTime? createdAt;
  final DateTime? scheduledAt;
  final String category;

  factory PlanItemData.fromMap(Map<String, dynamic> row) {
    final Map<String, dynamic>? metadata = row['metadata'] is Map
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : null;

    String _textValue(List<Object?> values) {
      for (final Object? value in values) {
        final String text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          return text;
        }
      }

      return '';
    }

    DateTime? _dateValue(List<Object?> values) {
      for (final Object? value in values) {
        final String text = value?.toString().trim() ?? '';
        if (text.isEmpty) {
          continue;
        }

        final DateTime? parsed = DateTime.tryParse(text);
        if (parsed != null) {
          return parsed;
        }
      }

      return null;
    }

    return PlanItemData(
      id: row['id']?.toString() ?? '',
      planId: row['plan_id']?.toString() ?? '',
      title: _textValue(<Object?>[
        row['title'],
        metadata?['task_title'],
      ]),
      description: _textValue(<Object?>[
        row['description'],
        metadata?['task_description'],
        metadata?['description'],
      ]),
      status: row['status']?.toString().trim() ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      scheduledAt: _dateValue(<Object?>[
        row['scheduled_at'],
        metadata?['scheduled_at'],
      ]),
      category: _textValue(<Object?>[
        row['task_category'],
        metadata?['task_category'],
        metadata?['category'],
      ]),
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

  String get displayScheduledLabel {
    final DateTime? value = scheduledAt;
    if (value == null) {
      return 'Дата не указана';
    }

    final DateTime local = value.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }

  String get displayCategoryLabel {
    final String value = category.trim();
    return value.isEmpty ? 'Без категории' : value;
  }
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value as Map);
  }

  return <String, dynamic>{};
}

Future<Map<String, Map<String, dynamic>>> loadPlanItemMetadataByTaskId(
  SupabaseClient client,
  Iterable<String> taskIds,
) async {
  final List<String> uniqueIds = taskIds
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toSet()
      .toList();

  if (uniqueIds.isEmpty) {
    return <String, Map<String, dynamic>>{};
  }

  final List<dynamic> rows = await client
      .from('task_activity')
      .select('task_id, metadata, task_snapshot, created_at')
      .inFilter('task_id', uniqueIds)
      .order('created_at', ascending: true);

  final Map<String, Map<String, dynamic>> metadataByTaskId = <String, Map<String, dynamic>>{};

  for (final dynamic rowData in rows) {
    final Map<String, dynamic> row = rowData as Map<String, dynamic>;
    final String taskId = row['task_id']?.toString().trim() ?? '';
    if (taskId.isEmpty || metadataByTaskId.containsKey(taskId)) {
      continue;
    }

    final Map<String, dynamic> merged = <String, dynamic>{}
      ..addAll(_jsonMap(row['metadata']))
      ..addAll(_jsonMap(row['task_snapshot']));

    if (merged.isNotEmpty) {
      metadataByTaskId[taskId] = merged;
    }
  }

  return metadataByTaskId;
}

Future<List<PlanItemData>> buildPlanItemsFromProjectedRows({
  required SupabaseClient client,
  required List<Map<String, dynamic>> rows,
}) async {
  final Map<String, Map<String, dynamic>> metadataByTaskId =
      await loadPlanItemMetadataByTaskId(
    client,
    rows.map((Map<String, dynamic> row) => row['id']?.toString() ?? ''),
  );

  return rows.map((Map<String, dynamic> row) {
    final Map<String, dynamic> mergedRow = Map<String, dynamic>.from(row);
    final String taskId = mergedRow['id']?.toString() ?? '';
    final Map<String, dynamic>? metadata = metadataByTaskId[taskId];
    if (metadata != null && metadata.isNotEmpty) {
      mergedRow['metadata'] = metadata;
    }

    return PlanItemData.fromMap(mergedRow);
  }).toList();
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

  String _buildRequestKey(String eventType) {
    return 'plan_item:${widget.item.id}:$eventType:${DateTime.now().microsecondsSinceEpoch}';
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
      final Map<String, dynamic>? row = await loadPlanItemRowById(
        client: _client,
        itemId: widget.item.id,
        sourceLabel: 'plan-item-details',
      );

      if (row == null) {
        return null;
      }

      final Map<String, dynamic> mergedRow = Map<String, dynamic>.from(row);
      final Map<String, Map<String, dynamic>> metadataByTaskId =
          await loadPlanItemMetadataByTaskId(_client, <String>[widget.item.id]);
      final Map<String, dynamic>? metadata = metadataByTaskId[widget.item.id];
      if (metadata != null && metadata.isNotEmpty) {
        mergedRow['metadata'] = metadata;
      }

      return PlanItemData.fromMap(mergedRow);
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
      final String requestKey = _buildRequestKey(eventType);
      final Map<String, dynamic> metadata = _buildTaskEventMetadata(trigger: trigger);

      switch (eventType) {
        case 'completed':
          await _client.rpc(
            'complete_task',
            params: <String, dynamic>{
              'p_task_id': widget.item.id,
              'p_request_key': requestKey,
              'p_metadata': metadata,
            },
          );
          break;
        case 'skipped':
          await _client.rpc(
            'skip_task',
            params: <String, dynamic>{
              'p_task_id': widget.item.id,
              'p_request_key': requestKey,
              'p_metadata': metadata,
            },
          );
          break;
        case 'reopened':
          await _client.rpc(
            'reopen_task',
            params: <String, dynamic>{
              'p_task_id': widget.item.id,
              'p_request_key': requestKey,
              'p_metadata': metadata,
            },
          );
          break;
        default:
          throw StateError('Unsupported task event type: $eventType');
      }

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
                    const SizedBox(height: 16),
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
