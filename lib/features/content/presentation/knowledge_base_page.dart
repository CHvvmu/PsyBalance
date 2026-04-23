import 'package:flutter/material.dart';

class KnowledgeBasePage extends StatefulWidget {
  const KnowledgeBasePage({super.key});

  @override
  State<KnowledgeBasePage> createState() => _KnowledgeBasePageState();
}

class _KnowledgeBasePageState extends State<KnowledgeBasePage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Все';

  static const List<String> _categories = <String>[
    'Все',
    'Психология',
    'Питание',
    'Сон',
    'Активность',
  ];

  static const List<_KnowledgeItem> _items = <_KnowledgeItem>[
    _KnowledgeItem(
      category: 'Психология',
      title: "Мифы о мотивации: почему 'надо' не работает",
      minutes: 4,
      imageUrl:
          'https://dimg.dreamflow.cloud/v1/image/abstract+soft+painting+of+a+person+climbing+a+gentle+hill',
    ),
    _KnowledgeItem(
      category: 'Питание',
      title: 'Белок: сколько на самом деле нужно организму?',
      minutes: 5,
      imageUrl:
          'https://dimg.dreamflow.cloud/v1/image/minimalist+flat+lay+of+healthy+nuts+and+beans+in+ceramic+bowls',
    ),
    _KnowledgeItem(
      category: 'Сон',
      title: 'Ритуалы перед сном для снижения кортизола',
      minutes: 3,
      imageUrl:
          'https://dimg.dreamflow.cloud/v1/image/serene+bedroom+with+soft+morning+light+and+a+cup+of+herbal+tea',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final String query = _searchController.text.trim().toLowerCase();

    final List<_KnowledgeItem> filtered = _items.where((item) {
      final bool categoryMatch =
          _selectedCategory == 'Все' || _selectedCategory == item.category;
      final bool queryMatch =
          query.isEmpty || item.title.toLowerCase().contains(query);
      return categoryMatch && queryMatch;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'База знаний',
                      style: textTheme.headlineMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Короткие уроки для осознанных перемен',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Поиск материалов...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Row(
                  children: _categories.map((String category) {
                    final bool selected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = category;
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned(
                        right: -28,
                        top: -42,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: colors.onPrimary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.onPrimary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'УРОК ДНЯ',
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Как остановить эмоциональное переедание',
                            style: textTheme.titleLarge?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Простая техника 'Стоп', чтобы вернуть контроль за 30 секунд.",
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.9),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Урок открыт.')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.onPrimary,
                              foregroundColor: colors.onSurface,
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: const Text('Начать урок'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Популярное сейчас',
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...filtered.map(
                      (_KnowledgeItem item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _KnowledgeCard(item: item),
                      ),
                    ),
                    if (filtered.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Text(
                          'Ничего не найдено',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.eco_rounded,
                        size: 40,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Ваш прогресс обучения',
                            style: textTheme.labelLarge?.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Вы изучили 12 материалов из 40',
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: 0.3,
                              minHeight: 6,
                              backgroundColor:
                                  colors.primary.withValues(alpha: 0.15),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(colors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnowledgeCard extends StatelessWidget {
  const _KnowledgeCard({required this.item});

  final _KnowledgeItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 128,
            child: Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  color: theme.scaffoldBackgroundColor,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: textTheme.bodyMedium?.color,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.category,
                    style: textTheme.labelSmall?.copyWith(color: colors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: textTheme.labelLarge?.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Icon(Icons.schedule_rounded, size: 14, color: textTheme.bodyMedium?.color),
                    const SizedBox(width: 4),
                    Text('${item.minutes} мин', style: textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeItem {
  const _KnowledgeItem({
    required this.category,
    required this.title,
    required this.minutes,
    required this.imageUrl,
  });

  final String category;
  final String title;
  final int minutes;
  final String imageUrl;
}

