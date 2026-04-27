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
      description.isEmpty ? 'Описание не указано' : description;

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
        return 'В процессе';
      case 'done':
        return 'Сделано';
      default:
        return 'Ожидает';
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

  Future<void> _updateStatus(String status) async {
    if (_isUpdating) {
      return;
    }

    debugPrint('PLAN UPDATE START: item_id=${widget.item.id}, status=$status');

    setState(() {
      _isUpdating = true;
    });

    try {
      await _client.from('plan_items').update(<String, dynamic>{
        'status': status,
      }).eq('id', widget.item.id);

      debugPrint('PLAN UPDATE SUCCESS: item_id=${widget.item.id}, status=$status');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Статус сохранён')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('PLAN UPDATE ERROR: item_id=${widget.item.id}, status=$status, error=$error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось обновить статус')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали задачи'),
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
                onPressed: _isUpdating ? null : () => _updateStatus('in_progress'),
                child: _isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('В процессе'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isUpdating ? null : () => _updateStatus('done'),
                child: const Text('Сделано'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
