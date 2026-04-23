import 'dart:math' as math;

import 'package:flutter/material.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final TextEditingController _clientSearchController = TextEditingController();

  static const List<_CoachItemData> _coaches = <_CoachItemData>[
    _CoachItemData(name: 'Михаил Воронов', initials: 'МВ', clientsCount: 12, rating: '4.9'),
    _CoachItemData(name: 'Елена Степанова', initials: 'ЕС', clientsCount: 8, rating: '4.7'),
    _CoachItemData(name: 'Артем Кузнецов', initials: 'АК', clientsCount: 15, rating: '5.0'),
  ];

  static const List<_ClientSubscriptionItemData> _subscriptions =
      <_ClientSubscriptionItemData>[
    _ClientSubscriptionItemData(
      clientName: 'Александр Иванов',
      plan: 'Премиум',
      status: 'Активен',
      expiry: '12.09.2024',
      coachName: 'Михаил Воронов',
    ),
    _ClientSubscriptionItemData(
      clientName: 'Мария Петрова',
      plan: 'Базовый',
      status: 'Истекает',
      expiry: '05.08.2024',
      coachName: 'Елена Степанова',
    ),
    _ClientSubscriptionItemData(
      clientName: 'Дмитрий Волков',
      plan: 'Премиум',
      status: 'Активен',
      expiry: '20.10.2024',
      coachName: 'Артем Кузнецов',
    ),
  ];

  @override
  void dispose() {
    _clientSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final String query = _clientSearchController.text.trim().toLowerCase();
    final List<_ClientSubscriptionItemData> filteredSubscriptions = _subscriptions
        .where((item) => item.clientName.toLowerCase().contains(query))
        .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Создание тренера будет доступно позже.')),
          );
        },
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Новый тренер'),
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
                        'PsyBalance Админ',
                        style: textTheme.headlineMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Аналитика и команда', style: textTheme.bodyMedium),
                    ],
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.settings_rounded, color: colors.onSurface),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Финансовые показатели',
                    style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: <Widget>[
                      Expanded(
                        child: _StatCard(
                          label: 'ARPU',
                          value: '6 250 ₽',
                          trendText: '+5%',
                          trendUp: true,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Отток',
                          value: '4.2%',
                          trendText: '-1.2%',
                          trendUp: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.dividerColor),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
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
                          'Выручка PsyBalance (20%)',
                          style: textTheme.titleSmall?.copyWith(color: colors.onSurface),
                        ),
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: colors.onSurface,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: _RevenueBarChart(
                        values: const <double>[120, 150, 180, 170, 210, 240, 280],
                        labels: const <String>[
                          'Янв',
                          'Фев',
                          'Мар',
                          'Апр',
                          'Май',
                          'Июн',
                          'Июл',
                        ],
                        barColor: colors.primary,
                        labelStyle: textTheme.labelSmall ?? const TextStyle(),
                        labelColor: textTheme.bodySmall?.color ?? colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text('Итого за месяц', style: textTheme.labelSmall),
                        Text(
                          '168 400 ₽',
                          style: textTheme.labelLarge?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Тренеры',
                        style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Создание тренера будет доступно позже.'),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Создать'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._coaches.map(
                    (coach) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CoachItem(data: coach),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Клиенты и подписки',
                    style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _clientSearchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Поиск клиента...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...filteredSubscriptions.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ClientSubscriptionItem(data: item),
                    ),
                  ),
                  if (filteredSubscriptions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Text(
                        'По вашему запросу ничего не найдено',
                        style: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.secondary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.sensors_rounded,
                        color: colors.onSurface,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Статус PsyBalance',
                            style: textTheme.labelLarge?.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Все системы работают в штатном режиме. Активных сессий: 142',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.trendText,
    required this.trendUp,
  });

  final String label;
  final String value;
  final String trendText;
  final bool trendUp;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final Color trendColor = trendUp ? const Color(0xFF166534) : const Color(0xFF991B1B);
    final IconData trendIcon = trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: textTheme.labelSmall),
          const SizedBox(height: 6),
          Text(value, style: textTheme.titleMedium?.copyWith(color: colors.onSurface)),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Icon(trendIcon, size: 14, color: trendColor),
              const SizedBox(width: 4),
              Text(
                trendText,
                style: textTheme.labelSmall?.copyWith(color: trendColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoachItem extends StatelessWidget {
  const _CoachItem({required this.data});

  final _CoachItemData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.primary.withValues(alpha: 0.15),
            child: Text(
              data.initials,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.name,
                  style: theme.textTheme.labelLarge?.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  'Клиентов: ${data.clientsCount}  •  Рейтинг: ${data.rating}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.more_horiz_rounded, color: colors.onSurface),
          ),
        ],
      ),
    );
  }
}

class _ClientSubscriptionItem extends StatelessWidget {
  const _ClientSubscriptionItem({required this.data});

  final _ClientSubscriptionItemData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool expiring = data.status == 'Истекает';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  data.clientName,
                  style: theme.textTheme.labelLarge?.copyWith(color: colors.onSurface),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: expiring
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  data.status,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: expiring
                        ? const Color(0xFF92400E)
                        : const Color(0xFF166534),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Тариф: ${data.plan}  •  До: ${data.expiry}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text('Тренер: ${data.coachName}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RevenueBarChart extends StatelessWidget {
  const _RevenueBarChart({
    required this.values,
    required this.labels,
    required this.barColor,
    required this.labelStyle,
    required this.labelColor,
  });

  final List<double> values;
  final List<String> labels;
  final Color barColor;
  final TextStyle labelStyle;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RevenueBarChartPainter(
        values: values,
        labels: labels,
        barColor: barColor,
        labelStyle: labelStyle,
        labelColor: labelColor,
      ),
    );
  }
}

class _RevenueBarChartPainter extends CustomPainter {
  _RevenueBarChartPainter({
    required this.values,
    required this.labels,
    required this.barColor,
    required this.labelStyle,
    required this.labelColor,
  });

  final List<double> values;
  final List<String> labels;
  final Color barColor;
  final TextStyle labelStyle;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || labels.length != values.length) {
      return;
    }

    const double left = 8;
    const double right = 8;
    const double top = 12;
    const double bottom = 24;

    final Rect chart = Rect.fromLTWH(
      left,
      top,
      size.width - left - right,
      size.height - top - bottom,
    );

    final double maxValue = values.reduce(math.max);
    final double step = chart.width / values.length;
    const double barWidth = 20;

    final Paint barPaint = Paint()..color = barColor;

    for (int i = 0; i < values.length; i++) {
      final double normalized = values[i] / maxValue;
      final double barHeight = chart.height * normalized;
      final double x = chart.left + step * i + (step - barWidth) / 2;
      final double y = chart.bottom - barHeight;

      final RRect bar = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(bar, barPaint);

      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: labelStyle.copyWith(color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(x + (barWidth - painter.width) / 2, chart.bottom + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueBarChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.labels != labels ||
        oldDelegate.barColor != barColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.labelColor != labelColor;
  }
}

class _CoachItemData {
  const _CoachItemData({
    required this.name,
    required this.initials,
    required this.clientsCount,
    required this.rating,
  });

  final String name;
  final String initials;
  final int clientsCount;
  final String rating;
}

class _ClientSubscriptionItemData {
  const _ClientSubscriptionItemData({
    required this.clientName,
    required this.plan,
    required this.status,
    required this.expiry,
    required this.coachName,
  });

  final String clientName;
  final String plan;
  final String status;
  final String expiry;
  final String coachName;
}

