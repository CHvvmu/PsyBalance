import 'package:flutter/material.dart';

class CoachClientDetailsPage extends StatefulWidget {
  const CoachClientDetailsPage({
    super.key,
    required this.onOpenChat,
    required this.onOpenCall,
    required this.onOpenPlanEditor,
    required this.onBack,
  });

  final VoidCallback onOpenChat;
  final VoidCallback onOpenCall;
  final VoidCallback onOpenPlanEditor;
  final VoidCallback onBack;

  @override
  State<CoachClientDetailsPage> createState() => _CoachClientDetailsPageState();
}

class _CoachClientDetailsPageState extends State<CoachClientDetailsPage> {
  final List<_ActivityItemData> _activities = <_ActivityItemData>[
    const _ActivityItemData(
      title: 'Утренняя зарядка',
      subtitle: '15 минут, низкая интенсивность',
      isActive: true,
    ),
    const _ActivityItemData(
      title: 'Прогулка 8000 шагов',
      subtitle: 'Ежедневно, фиксация скриншотом',
      isActive: true,
    ),
    const _ActivityItemData(
      title: 'Медитация перед сном',
      subtitle: '10 минут в приложении',
      isActive: false,
    ),
  ];

  void _toggleActivity(int index, bool value) {
    setState(() {
      _activities[index] = _activities[index].copyWith(isActive: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    const Color success = Color(0xFF16A34A);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(
                    bottom: BorderSide(color: theme.dividerColor),
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        IconButton(
                          onPressed: widget.onBack,
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: colors.onSurface,
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            _RoundActionIcon(
                              icon: Icons.videocam_rounded,
                              onTap: widget.onOpenCall,
                            ),
                            const SizedBox(width: 8),
                            _RoundActionIcon(
                              icon: Icons.chat_bubble_rounded,
                              onTap: widget.onOpenChat,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        _NetworkAvatar(
                          imageUrl:
                              'https://dimg.dreamflow.cloud/v1/image/young+woman+smiling+gently',
                          size: 72,
                          borderColor: colors.secondary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Анна Кузнецова',
                                style: textTheme.titleLarge?.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: <Widget>[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Низкий риск срыва',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colors.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Была в сети 15 мин назад',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Чек-ин за сегодня',
                          style: textTheme.titleMedium?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: const <Widget>[
                            Expanded(
                              child: _MetricCard(
                                title: 'Энергия',
                                value: '8/10',
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                title: 'Стресс',
                                value: '3/10',
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _MetricCard(
                                title: 'Сон',
                                value: '7.5ч',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Дневник питания',
                              style: textTheme.titleMedium?.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: Text(
                                'История',
                                style: textTheme.labelLarge?.copyWith(
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const _MealEntryTile(
                          mealType: 'Завтрак',
                          description: 'Овсянка с ягодами и миндалем',
                          time: '08:30',
                          imageUrl:
                              'https://dimg.dreamflow.cloud/v1/image/oatmeal+with+berries',
                        ),
                        const SizedBox(height: 10),
                        const _MealEntryTile(
                          mealType: 'Обед',
                          description: 'Куриная грудка и зеленый салат',
                          time: '13:15',
                          imageUrl:
                              'https://dimg.dreamflow.cloud/v1/image/grilled+chicken+salad',
                        ),
                        const SizedBox(height: 10),
                        const _MealEntryTile(
                          mealType: 'Полдник',
                          description: 'Яблоко и горсть орехов',
                          time: '16:45',
                          imageUrl:
                              'https://dimg.dreamflow.cloud/v1/image/apple+and+nuts',
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'План активности',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: colors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Неделя 3: Формирование привычки',
                                  style: textTheme.bodySmall,
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: Icon(
                                Icons.add_circle_outline_rounded,
                                size: 28,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...List<Widget>.generate(_activities.length, (int index) {
                          final _ActivityItemData item = _activities[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == _activities.length - 1 ? 0 : 8,
                            ),
                            child: _ActivityItemTile(
                              item: item,
                              onChanged: (bool value) =>
                                  _toggleActivity(index, value),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: widget.onOpenPlanEditor,
                          child: const Text('Обновить план на неделю'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colors.onPrimary,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: colors.secondary),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: colors.onSurface,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Анализ тренера',
                                style: textTheme.labelLarge?.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Анна стабильно соблюдает питьевой режим, но пропускает вечерние чекины. Рекомендую сместить фокус на гигиену сна.',
                            style: textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: const Text('Добавить заметку'),
                          ),
                        ],
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

class _RoundActionIcon extends StatelessWidget {
  const _RoundActionIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: colors.primary),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: textTheme.labelSmall?.copyWith(color: textTheme.bodyMedium?.color),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
          ),
        ],
      ),
    );
  }
}

class _MealEntryTile extends StatelessWidget {
  const _MealEntryTile({
    required this.mealType,
    required this.description,
    required this.time,
    required this.imageUrl,
  });

  final String mealType;
  final String description;
  final String time;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  width: 52,
                  height: 52,
                  color: theme.scaffoldBackgroundColor,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 20,
                    color: textTheme.bodyMedium?.color,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  mealType,
                  style: textTheme.labelMedium?.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(time, style: textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _ActivityItemTile extends StatelessWidget {
  const _ActivityItemTile({required this.item, required this.onChanged});

  final _ActivityItemData item;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(item.subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Switch(
            value: item.isActive,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _NetworkAvatar extends StatelessWidget {
  const _NetworkAvatar({
    required this.imageUrl,
    required this.size,
    required this.borderColor,
  });

  final String imageUrl;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 3),
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.25),
              alignment: Alignment.center,
              child: Icon(
                Icons.person_rounded,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActivityItemData {
  const _ActivityItemData({
    required this.title,
    required this.subtitle,
    required this.isActive,
  });

  final String title;
  final String subtitle;
  final bool isActive;

  _ActivityItemData copyWith({
    String? title,
    String? subtitle,
    bool? isActive,
  }) {
    return _ActivityItemData(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      isActive: isActive ?? this.isActive,
    );
  }
}

