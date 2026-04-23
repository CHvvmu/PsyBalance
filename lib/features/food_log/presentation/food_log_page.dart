import 'package:flutter/material.dart';

class FoodLogPage extends StatefulWidget {
  const FoodLogPage({super.key});

  @override
  State<FoodLogPage> createState() => _FoodLogPageState();
}

class _FoodLogPageState extends State<FoodLogPage> {
  final TextEditingController _notesController = TextEditingController();
  String _selectedMealType = 'Завтрак';
  bool _hasPhoto = false;

  static const List<String> _mealTypes = <String>[
    'Завтрак',
    'Обед',
    'Ужин',
    'Перекус',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _saveFoodLog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Запись в фотодневник сохранена')),
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
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Фотодневник еды',
                    style: textTheme.titleLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.dividerColor, width: 2),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (_hasPhoto)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.network(
                          'https://dimg.dreamflow.cloud/v1/image/healthy+breakfast+bowl+with+avocado+and+eggs',
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.photo_camera_rounded,
                            size: 38,
                            color: textTheme.bodyMedium?.color,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Нажмите, чтобы добавить фото',
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: FloatingActionButton(
                          heroTag: 'food_photo_fab',
                          mini: true,
                          onPressed: () {
                            setState(() {
                              _hasPhoto = !_hasPhoto;
                            });
                          },
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          child: const Icon(Icons.photo_camera_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _mealTypes.map((String mealType) {
                    final bool selected = mealType == _selectedMealType;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(mealType),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _selectedMealType = mealType;
                          });
                        },
                        selectedColor: colors.primary,
                        backgroundColor: colors.surface,
                        labelStyle: textTheme.labelMedium?.copyWith(
                          color: selected ? colors.onPrimary : colors.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Заметки',
                style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Опишите прием пищи и уровень сытости...',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveFoodLog,
                child: const Text('Сохранить прием пищи'),
              ),
              const SizedBox(height: 18),
              Text(
                'Сегодня',
                style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 8),
              const _FoodEntryTile(
                mealType: 'Завтрак',
                title: 'Овсянка с ягодами',
                time: '08:30',
              ),
              const SizedBox(height: 8),
              const _FoodEntryTile(
                mealType: 'Обед',
                title: 'Курица и салат',
                time: '13:15',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodEntryTile extends StatelessWidget {
  const _FoodEntryTile({
    required this.mealType,
    required this.title,
    required this.time,
  });

  final String mealType;
  final String title;
  final String time;

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
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.restaurant_rounded, color: colors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(mealType, style: theme.textTheme.labelMedium),
                Text(title, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(time, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

