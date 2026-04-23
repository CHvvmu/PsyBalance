import 'package:flutter/material.dart';

class DailyCheckInPage extends StatefulWidget {
  const DailyCheckInPage({super.key});

  @override
  State<DailyCheckInPage> createState() => _DailyCheckInPageState();
}

class _DailyCheckInPageState extends State<DailyCheckInPage> {
  final TextEditingController _notesController = TextEditingController();

  double _energy = 8;
  double _stress = 3;
  double _sleep = 7;
  int _moodIndex = 3;
  bool _hasPhoto = false;
  String _mealType = 'Завтрак';

  static const List<String> _mealTypes = <String>[
    'Завтрак',
    'Обед',
    'Ужин',
    'Перекус',
  ];

  static const List<IconData> _moodIcons = <IconData>[
    Icons.sentiment_very_dissatisfied_rounded,
    Icons.sentiment_dissatisfied_rounded,
    Icons.sentiment_neutral_rounded,
    Icons.sentiment_satisfied_rounded,
    Icons.sentiment_very_satisfied_rounded,
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _saveReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Отчет за день сохранен')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                  IconButton(
                    onPressed: () {
                      final NavigatorState navigator = Navigator.of(context);
                      if (navigator.canPop()) {
                        navigator.pop();
                      }
                    },
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    'Ежедневный чекин',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: colors.onSurface,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Как вы себя чувствуете?',
                          style: textTheme.titleMedium?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _CheckinSlider(
                      label: 'Энергия',
                      value: _energy,
                      minLabel: 'Усталость',
                      maxLabel: 'Бодрость',
                      onChanged: (double value) {
                        setState(() {
                          _energy = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _CheckinSlider(
                      label: 'Стресс',
                      value: _stress,
                      minLabel: 'Спокойствие',
                      maxLabel: 'Напряжение',
                      onChanged: (double value) {
                        setState(() {
                          _stress = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _CheckinSlider(
                      label: 'Качество сна',
                      value: _sleep,
                      minLabel: 'Плохо',
                      maxLabel: 'Отлично',
                      onChanged: (double value) {
                        setState(() {
                          _sleep = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Настроение',
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List<Widget>.generate(_moodIcons.length, (int index) {
                        final bool selected = index == _moodIndex;
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              _moodIndex = index;
                            });
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: selected
                                  ? colors.primary.withValues(alpha: 0.15)
                                  : theme.scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              _moodIcons[index],
                              size: 28,
                              color: selected
                                  ? colors.primary
                                  : textTheme.bodyMedium?.color,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Фотодневник еды',
                    style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: 12),
                  _DashedBorderContainer(
                    radius: 28,
                    color: theme.dividerColor,
                    child: Container(
                      height: 240,
                      color: colors.surface,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          if (_hasPhoto)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Image.network(
                                'https://dimg.dreamflow.cloud/v1/image/healthy+breakfast+bowl+with+avocado+and+eggs',
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: theme.scaffoldBackgroundColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    size: 36,
                                    color: textTheme.bodyMedium?.color,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Нажмите, чтобы добавить фото',
                                  style: textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              margin: const EdgeInsets.all(20),
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _hasPhoto = !_hasPhoto;
                                  });
                                },
                                icon: Icon(
                                  Icons.photo_camera_rounded,
                                  color: colors.onPrimary,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _mealTypes.map((String item) {
                        final bool selected = _mealType == item;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(item),
                            selected: selected,
                            onSelected: (_) {
                              setState(() {
                                _mealType = item;
                              });
                            },
                            selectedColor: colors.primary,
                            backgroundColor: colors.surface,
                            labelStyle: textTheme.labelMedium?.copyWith(
                              color: selected ? colors.onPrimary : colors.onSurface,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            side: BorderSide(
                              color: selected ? colors.primary : theme.dividerColor,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Заметки (необязательно)',
                style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Как прошел ваш прием пищи? Было ли чувство сытости?',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveReport,
                child: const Text('Сохранить отчет за день'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckinSlider extends StatelessWidget {
  const _CheckinSlider({
    required this.label,
    required this.value,
    required this.minLabel,
    required this.maxLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final String minLabel;
  final String maxLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(color: colors.onSurface),
            ),
            Text(
              '${value.round()}/10',
              style: textTheme.labelMedium?.copyWith(color: colors.onSurface),
            ),
          ],
        ),
        Slider(
          value: value,
          divisions: 10,
          min: 0,
          max: 10,
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(minLabel, style: textTheme.bodySmall),
            Text(maxLabel, style: textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _DashedBorderContainer extends StatelessWidget {
  const _DashedBorderContainer({
    required this.child,
    required this.radius,
    required this.color,
  });

  final Widget child;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color, radius: radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final Path path = Path()..addRRect(rrect);
    const double dashWidth = 8;
    const double dashSpace = 6;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

