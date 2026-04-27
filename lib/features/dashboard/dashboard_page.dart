import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../plan/plan_item_details_page.dart';

class ClientDashboardPage extends StatelessWidget {
  const ClientDashboardPage({
    super.key,
    required this.onOpenFood,
    required this.onOpenStress,
    required this.onOpenSleep,
    required this.onOpenSport,
    required this.onOpenPlan,
    required this.onOpenKnowledgeBase,
    required this.onOpenChat,
    required this.onAdd,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenFood;
  final VoidCallback onOpenStress;
  final VoidCallback onOpenSleep;
  final VoidCallback onOpenSport;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenKnowledgeBase;
  final VoidCallback onOpenChat;
  final VoidCallback onAdd;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    const Color success = Color(0xFF43A047);
    const Color accent = Color(0xFFE8DCCB);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAdd,
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'PsyBalance: Анна',
                        style: textTheme.headlineMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ваш 14-й день пути к балансу',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: onOpenProfile,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.person_rounded,
                            size: 20,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _NetworkAvatar(
                        imageUrl:
                            'https://dimg.dreamflow.cloud/v1/image/friendly+female+face',
                        size: 48,
                        borderColor: colors.primary,
                        borderWidth: 2,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Прогресс веса',
                          style: textTheme.titleMedium?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'За неделю',
                            style: textTheme.labelMedium?.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: _WeeklyWeightChart(
                        values: const <double>[78.5, 78.2, 77.9, 78.1, 77.6, 77.4, 77.2],
                        labels: const <String>['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
                        lineColor: colors.primary,
                        fillColor: colors.primary.withValues(alpha: 0.1),
                        labelColor: textTheme.bodySmall?.color ?? colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        Column(
                          children: <Widget>[
                            Text(
                              '-1.3 кг',
                              style: textTheme.titleLarge?.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('за неделю', style: textTheme.labelSmall),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: theme.dividerColor,
                        ),
                        Column(
                          children: <Widget>[
                            Text(
                              '77.2 кг',
                              style: textTheme.titleLarge?.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('текущий вес', style: textTheme.labelSmall),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Быстрый чекин PsyBalance',
                    style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _QuickActionButton(
                          icon: Icons.photo_camera_rounded,
                          label: 'Еда',
                          backgroundColor: colors.primary.withValues(alpha: 0.2),
                          foregroundColor: colors.primary,
                          onTap: onOpenFood,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickActionButton(
                          icon: Icons.self_improvement_rounded,
                          label: 'Стресс',
                          backgroundColor: colors.secondary.withValues(alpha: 0.2),
                          foregroundColor: colors.secondary,
                          onTap: onOpenStress,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickActionButton(
                          icon: Icons.bed_rounded,
                          label: 'Сон',
                          backgroundColor: accent.withValues(alpha: 0.4),
                          foregroundColor: colors.onSurface,
                          onTap: onOpenSleep,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickActionButton(
                          icon: Icons.fitness_center_rounded,
                          label: 'Спорт',
                          backgroundColor: success.withValues(alpha: 0.2),
                          foregroundColor: success,
                          onTap: onOpenSport,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _DailyPlanSection(
                onOpenLegacyPlan: onOpenPlan,
                onOpenKnowledgeBase: onOpenKnowledgeBase,
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.secondary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: <Widget>[
                    _NetworkAvatar(
                      imageUrl:
                          'https://dimg.dreamflow.cloud/v1/image/professional+male+coach',
                      size: 50,
                      backgroundColor: colors.secondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Ваш тренер PsyBalance: Михаил',
                            style: textTheme.labelLarge?.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'На связи с 9:00 до 21:00',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: onOpenChat,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 16,
                              color: colors.onSurface,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Чат',
                              style: textTheme.labelMedium?.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyPlanSection extends StatefulWidget {
  const _DailyPlanSection({
    required this.onOpenLegacyPlan,
    required this.onOpenKnowledgeBase,
  });

  final VoidCallback onOpenLegacyPlan;
  final VoidCallback onOpenKnowledgeBase;

  @override
  State<_DailyPlanSection> createState() => _DailyPlanSectionState();
}

class _DailyPlanSectionState extends State<_DailyPlanSection> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;
  String? _planId;
  String? _weekStartLabel;
  List<PlanItemData> _items = <PlanItemData>[];

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final User? currentUser = _client.auth.currentUser;
    debugPrint('PLAN LOAD START');

    if (currentUser == null) {
      debugPrint('PLAN LOAD ERROR: current user is null');
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
      return;
    }

    try {
      final Map<String, dynamic>? planRow = await _client
          .from('plans')
          .select('id, week_start')
          .eq('user_id', currentUser.id)
          .order('week_start', ascending: false)
          .limit(1)
          .maybeSingle();

      if (planRow == null) {
        debugPrint('PLAN LOAD EMPTY: no plan assigned');
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

      final List<dynamic> rows = await _client
          .from('plan_items')
          .select('id, plan_id, title, description, status, created_at')
          .eq('plan_id', planId);

      final List<PlanItemData> items = rows
          .map((dynamic rowData) => PlanItemData.fromMap(rowData as Map<String, dynamic>))
          .toList()
        ..sort((PlanItemData left, PlanItemData right) {
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
        });

      if (items.isEmpty) {
        debugPrint('PLAN LOAD EMPTY: plan_id=$planId items=0');
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _planId = planId;
          _weekStartLabel = weekStartLabel;
          _items = <PlanItemData>[];
        });
        return;
      }

      debugPrint('PLAN LOAD SUCCESS: plan_id=$planId items=${items.length}');
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
      debugPrint('PLAN LOAD ERROR: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Не удалось загрузить план';
        _items = <PlanItemData>[];
        _planId = null;
        _weekStartLabel = null;
      });
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

  String _formatWeekStart(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }

    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return '';
    }

    final DateTime normalized = DateUtils.dateOnly(parsed);
    final String day = normalized.day.toString().padLeft(2, '0');
    final String month = normalized.month.toString().padLeft(2, '0');
    return '$day.$month.${normalized.year}';
  }

  Color _statusBackground(String status, ColorScheme colors) {
    switch (status) {
      case 'in_progress':
        return colors.secondary.withValues(alpha: 0.2);
      case 'done':
        return const Color(0xFF43A047).withValues(alpha: 0.16);
      default:
        return colors.primary.withValues(alpha: 0.18);
    }
  }

  Color _statusForeground(String status, ColorScheme colors) {
    switch (status) {
      case 'in_progress':
        return colors.secondary;
      case 'done':
        return const Color(0xFF43A047);
      default:
        return colors.primary;
    }
  }

  Widget _buildItemCard(PlanItemData item, ThemeData theme, ColorScheme colors) {
    final String normalizedStatus = item.normalizedStatus;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _openItemDetails(item),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    item.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _statusBackground(normalizedStatus, colors),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.statusLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: _statusForeground(normalizedStatus, colors),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colors) {
    final String message = _planId == null
        ? 'План пока не назначен'
        : 'В этом плане пока нет задач';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.event_note_rounded,
            size: 36,
            color: colors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme, ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: colors.error,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Не удалось загрузить план',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loadPlan,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'План на сегодня',
                    style: theme.textTheme.titleMedium?.copyWith(color: colors.onSurface),
                  ),
                  if (_weekStartLabel != null && _weekStartLabel!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'Неделя от $_weekStartLabel',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              TextButton(
                onPressed: widget.onOpenLegacyPlan,
                child: Text(
                  'См. всё',
                  style: theme.textTheme.labelLarge?.copyWith(color: colors.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoading)
            _buildLoadingState(theme, colors)
          else if (_errorMessage != null)
            _buildErrorState(theme, colors)
          else if (_items.isEmpty)
            _buildEmptyState(theme, colors)
          else
            Column(
              children: _items
                  .map((PlanItemData item) => _buildItemCard(item, theme, colors))
                  .toList(),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onOpenKnowledgeBase,
            icon: const Icon(Icons.menu_book_rounded),
            label: const Text('Открыть базу знаний'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: foregroundColor, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(color: foregroundColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkAvatar extends StatelessWidget {
  const _NetworkAvatar({
    required this.imageUrl,
    required this.size,
    this.borderColor,
    this.borderWidth = 0,
    this.backgroundColor,
  });

  final String imageUrl;
  final double size;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final Widget image = ClipOval(
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext context, Object _, StackTrace? __) {
          return Container(
            width: size,
            height: size,
            color: backgroundColor ?? Theme.of(context).colorScheme.primary,
            alignment: Alignment.center,
            child: Icon(
              Icons.person_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          );
        },
      ),
    );

    if (borderWidth <= 0 || borderColor == null) {
      return SizedBox(width: size, height: size, child: image);
    }

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor!, width: borderWidth),
      ),
      child: image,
    );
  }
}

class _WeeklyWeightChart extends StatelessWidget {
  const _WeeklyWeightChart({
    required this.values,
    required this.labels,
    required this.lineColor,
    required this.fillColor,
    required this.labelColor,
  });

  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final Color fillColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WeeklyWeightChartPainter(
        values: values,
        labels: labels,
        lineColor: lineColor,
        fillColor: fillColor,
        labelColor: labelColor,
        textStyle: Theme.of(context).textTheme.labelSmall ?? const TextStyle(),
      ),
    );
  }
}

class _WeeklyWeightChartPainter extends CustomPainter {
  _WeeklyWeightChartPainter({
    required this.values,
    required this.labels,
    required this.lineColor,
    required this.fillColor,
    required this.labelColor,
    required this.textStyle,
  });

  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final Color fillColor;
  final Color labelColor;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || labels.length != values.length) {
      return;
    }

    const double left = 8;
    const double right = 8;
    const double top = 12;
    const double bottom = 24;
    final Rect chartRect = Rect.fromLTWH(
      left,
      top,
      size.width - left - right,
      size.height - top - bottom,
    );

    final double minValue = values.reduce(math.min);
    final double maxValue = values.reduce(math.max);
    final double rawRange = maxValue - minValue;
    final double range = rawRange < 0.5 ? 0.5 : rawRange;

    final List<Offset> points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final double t = i / (values.length - 1);
      final double x = chartRect.left + (chartRect.width * t);
      final double normalized = (values[i] - minValue) / range;
      final double y = chartRect.bottom - (chartRect.height * normalized);
      points.add(Offset(x, y));
    }

    final Path linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final Offset p1 = points[i];
      final Offset p2 = points[i + 1];
      final double midX = (p1.dx + p2.dx) / 2;
      linePath.cubicTo(midX, p1.dy, midX, p2.dy, p2.dx, p2.dy);
    }

    final Path fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, chartRect.bottom)
      ..lineTo(points.first.dx, chartRect.bottom)
      ..close();

    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final Paint linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    final Paint pointPaint = Paint()..color = lineColor;
    for (final Offset point in points) {
      canvas.drawCircle(point, 3.5, pointPaint);
    }

    for (int i = 0; i < labels.length; i++) {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: textStyle.copyWith(color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final double x = points[i].dx - (painter.width / 2);
      final double y = chartRect.bottom + 6;
      painter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyWeightChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.labels != labels ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.textStyle != textStyle;
  }
}

