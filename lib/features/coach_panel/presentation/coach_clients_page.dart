import 'package:flutter/material.dart';

enum _RiskLevel { high, medium, low }

class CoachClientsPage extends StatefulWidget {
  const CoachClientsPage({
    super.key,
    required this.onOpenClient,
    required this.onOpenChat,
    required this.onCreateClient,
  });

  final ValueChanged<String> onOpenClient;
  final ValueChanged<String> onOpenChat;
  final VoidCallback onCreateClient;

  @override
  State<CoachClientsPage> createState() => _CoachClientsPageState();
}

class _CoachClientsPageState extends State<CoachClientsPage> {
  final TextEditingController _searchController = TextEditingController();

  static const List<_ClientRiskItem> _clients = <_ClientRiskItem>[
    _ClientRiskItem(
      name: 'Александра Иванова',
      avatarDesc: 'woman with glasses',
      lastActive: 'Был(а) в сети: 10 мин назад',
      riskLevel: _RiskLevel.high,
      riskLabel: '3 пропуска',
      foodStat: '1/3',
      foodDone: false,
      activityStat: '0/1',
      activityDone: false,
    ),
    _ClientRiskItem(
      name: 'Дмитрий Петров',
      avatarDesc: 'man with beard',
      lastActive: 'Был(а) в сети: 2 часа назад',
      riskLevel: _RiskLevel.medium,
      riskLabel: '1 пропуск',
      foodStat: '3/3',
      foodDone: true,
      activityStat: '0/1',
      activityDone: false,
    ),
    _ClientRiskItem(
      name: 'Елена Соколова',
      avatarDesc: 'smiling woman',
      lastActive: 'Был(а) в сети: вчера',
      riskLevel: _RiskLevel.low,
      riskLabel: 'В норме',
      foodStat: '3/3',
      foodDone: true,
      activityStat: '1/1',
      activityDone: true,
    ),
    _ClientRiskItem(
      name: 'Иван Кузнецов',
      avatarDesc: 'young man',
      lastActive: 'Был(а) в сети: 5 мин назад',
      riskLevel: _RiskLevel.low,
      riskLabel: 'В норме',
      foodStat: '2/3',
      foodDone: true,
      activityStat: '1/1',
      activityDone: true,
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

    final List<_ClientRiskItem> filtered = _clients
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onCreateClient,
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Новый клиент'),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.psychology,
                              size: 24,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'PsyBalance',
                              style: textTheme.titleLarge?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Мои подопечные',
                          style: textTheme.headlineMedium?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Всего 12 клиентов • 2 требуют внимания',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {},
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
                        Icons.tune_rounded,
                        size: 20,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Поиск по имени...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: const <Widget>[
                    _RiskStatCard(
                      count: '2',
                      title: 'Высокий риск',
                      background: Color(0xFFFEE2E2),
                      border: Color(0xFFFECACA),
                      textColor: Color(0xFF991B1B),
                    ),
                    SizedBox(width: 12),
                    _RiskStatCard(
                      count: '4',
                      title: 'Средний риск',
                      background: Color(0xFFFEF3C7),
                      border: Color(0xFFFDE68A),
                      textColor: Color(0xFF92400E),
                    ),
                    SizedBox(width: 12),
                    _RiskStatCard(
                      count: '6',
                      title: 'В норме',
                      background: Color(0xFFDCFCE7),
                      border: Color(0xFFBBF7D0),
                      textColor: Color(0xFF166534),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Список клиентов',
                style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 10),
              ...filtered.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ClientRiskCard(
                    item: item,
                    onOpenClient: () => widget.onOpenClient(item.name),
                    onOpenChat: () => widget.onOpenChat(item.name),
                  ),
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
                    style: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskStatCard extends StatelessWidget {
  const _RiskStatCard({
    required this.count,
    required this.title,
    required this.background,
    required this.border,
    required this.textColor,
  });

  final String count;
  final String title;
  final Color background;
  final Color border;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            count,
            style: textTheme.titleLarge?.copyWith(color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: textTheme.labelSmall?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _ClientRiskCard extends StatelessWidget {
  const _ClientRiskCard({
    required this.item,
    required this.onOpenClient,
    required this.onOpenChat,
  });

  final _ClientRiskItem item;
  final VoidCallback onOpenClient;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final _RiskColors riskColors = _RiskColors.fromLevel(item.riskLevel);

    return InkWell(
      onTap: onOpenClient,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                _ClientAvatar(name: item.name, descriptor: item.avatarDesc),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.name,
                        style: textTheme.labelLarge?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(item.lastActive, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: riskColors.background,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: riskColors.border),
                  ),
                  child: Text(
                    item.riskLabel,
                    style: textTheme.labelSmall?.copyWith(color: riskColors.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _TaskStatPill(
                    icon: Icons.photo_camera_outlined,
                    title: 'Еда',
                    value: item.foodStat,
                    done: item.foodDone,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TaskStatPill(
                    icon: Icons.directions_walk_rounded,
                    title: 'Активность',
                    value: item.activityStat,
                    done: item.activityDone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOpenClient,
                    child: const Text('Открыть'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Чат'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskStatPill extends StatelessWidget {
  const _TaskStatPill({
    required this.icon,
    required this.title,
    required this.value,
    required this.done,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final Color tint = done ? const Color(0xFF166534) : const Color(0xFF991B1B);
    final Color bg = done ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bg.withValues(alpha: 0.85)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$title: $value',
              style: theme.textTheme.labelMedium?.copyWith(
                color: done ? tint : colors.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientAvatar extends StatelessWidget {
  const _ClientAvatar({required this.name, required this.descriptor});

  final String name;
  final String descriptor;

  @override
  Widget build(BuildContext context) {
    final List<String> parts = name.split(' ').where((e) => e.isNotEmpty).toList();
    final String initials = parts
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();

    final int hash = descriptor.hashCode;
    final Color bg = Color(0xFFE8E2D9 + (hash & 0x000F0F0F)).withValues(alpha: 1);

    return CircleAvatar(
      radius: 22,
      backgroundColor: bg,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _RiskColors {
  const _RiskColors({
    required this.background,
    required this.border,
    required this.text,
  });

  final Color background;
  final Color border;
  final Color text;

  factory _RiskColors.fromLevel(_RiskLevel level) {
    switch (level) {
      case _RiskLevel.high:
        return const _RiskColors(
          background: Color(0xFFFEE2E2),
          border: Color(0xFFFECACA),
          text: Color(0xFF991B1B),
        );
      case _RiskLevel.medium:
        return const _RiskColors(
          background: Color(0xFFFEF3C7),
          border: Color(0xFFFDE68A),
          text: Color(0xFF92400E),
        );
      case _RiskLevel.low:
        return const _RiskColors(
          background: Color(0xFFDCFCE7),
          border: Color(0xFFBBF7D0),
          text: Color(0xFF166534),
        );
    }
  }
}

class _ClientRiskItem {
  const _ClientRiskItem({
    required this.name,
    required this.avatarDesc,
    required this.lastActive,
    required this.riskLevel,
    required this.riskLabel,
    required this.foodStat,
    required this.foodDone,
    required this.activityStat,
    required this.activityDone,
  });

  final String name;
  final String avatarDesc;
  final String lastActive;
  final _RiskLevel riskLevel;
  final String riskLabel;
  final String foodStat;
  final bool foodDone;
  final String activityStat;
  final bool activityDone;
}

