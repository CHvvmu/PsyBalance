import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_client_page.dart';
import 'coach_route_args.dart';

class CoachClientsPage extends StatefulWidget {
  const CoachClientsPage({
    super.key,
    required this.onOpenClient,
    required this.onOpenChat,
    required this.onOpenProfile,
  });

  final ValueChanged<CoachClientRouteArgs> onOpenClient;
  final ValueChanged<CoachClientRouteArgs> onOpenChat;
  final VoidCallback onOpenProfile;

  @override
  State<CoachClientsPage> createState() => _CoachClientsPageState();
}

class _CoachClientsPageState extends State<CoachClientsPage> {
  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<CoachClientCardData> _clients = <CoachClientCardData>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    debugPrint('COACH CLIENTS LOAD START');

    final User? currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      debugPrint('COACH CLIENTS LOAD ERROR: current user is null');
      if (!mounted) {
        return;
      }

      setState(() {
        _clients = <CoachClientCardData>[];
        _isLoading = false;
        _errorMessage = 'Не удалось загрузить клиентов';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<dynamic> clientRows = await _client
          .from('clients')
          .select('id, user_id, coach_id, created_at')
          .eq('coach_id', currentUser.id)
          .order('created_at', ascending: false);

      debugPrint('COACH CLIENTS RAW CLIENTS: ${clientRows.length}');

      final List<String> userIds = clientRows
          .map((dynamic rowData) {
            final Map<String, dynamic> row = rowData as Map<String, dynamic>;
            return row['user_id']?.toString() ?? '';
          })
          .where((String value) => value.isNotEmpty)
          .toList();

      debugPrint('COACH CLIENTS USER IDS: $userIds');

      final Map<String, Map<String, dynamic>> usersById = <String, Map<String, dynamic>>{};
      if (userIds.isNotEmpty) {
        try {
          final List<dynamic> userRows = await _client
              .from('users')
              .select(
                'id, full_name, email, avatar_url, birth_date, gender, goal, activity_level, last_activity_date, last_session_date, progress_status, notes, onboarding_completed',
              )
              .inFilter('id', userIds);

          debugPrint('COACH CLIENTS RAW USERS: ${userRows.length}');

          for (final dynamic rowData in userRows) {
            final Map<String, dynamic> row = rowData as Map<String, dynamic>;
            final String userId = row['id']?.toString() ?? '';
            if (userId.isNotEmpty) {
              usersById[userId] = row;
              debugPrint('COACH CLIENTS RAW USER JSON: $row');
            }
          }
        } catch (error, stackTrace) {
          debugPrint('COACH CLIENTS USERS QUERY ERROR: $error');
          debugPrint('COACH CLIENTS USERS QUERY STACK: $stackTrace');
          debugPrint('COACH CLIENTS USERS QUERY FAILED FOR IDS: $userIds');
        }
      }

      final List<CoachClientCardData> loadedClients = <CoachClientCardData>[];
      for (final dynamic rowData in clientRows) {
        try {
          final Map<String, dynamic> row = rowData as Map<String, dynamic>;
          final String userId = row['user_id']?.toString() ?? '';
          if (userId.isEmpty) {
            debugPrint('COACH CLIENTS SKIP ROW: missing user_id, raw=$row');
            continue;
          }

          final Map<String, dynamic>? userRow = usersById[userId];
          if (userRow == null) {
            debugPrint('COACH CLIENTS SKIP CLIENT: missing user row for userId=$userId');
            continue;
          }

          debugPrint('COACH CLIENTS PARSE USER JSON: $userRow');

          final CoachClientCardData client = CoachClientCardData.fromUserRow(
            clientId: userId,
            row: userRow,
          );

          debugPrint(
            'COACH CLIENTS LOAD ITEM: clientId=${client.clientId} clientName=${client.displayName}',
          );

          loadedClients.add(client);
        } catch (error, stackTrace) {
          debugPrint('COACH CLIENTS PARSE ERROR: $error');
          debugPrint('COACH CLIENTS PARSE STACK: $stackTrace');
          debugPrint('COACH CLIENTS BROKEN CLIENT ROW: $rowData');
        }
      }

      debugPrint('COACH CLIENTS LOAD SUCCESS: ${loadedClients.length}');

      if (!mounted) {
        return;
      }

      setState(() {
        _clients = loadedClients;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      debugPrint('COACH CLIENTS LOAD ERROR: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _clients = <CoachClientCardData>[];
        _isLoading = false;
        _errorMessage = 'Не удалось загрузить клиентов';
      });
    }
  }

  Future<void> _openAddClientPage() async {
    final bool? result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const AddClientPage(),
      ),
    );

    if (result == true && mounted) {
      await _loadClients();
    }
  }

  bool _requiresAttention(CoachClientCardData client) {
    final DateTime? lastActivity = client.lastActivityDate;
    final bool staleActivity =
        lastActivity == null || DateTime.now().difference(lastActivity).inDays >= 7;
    final bool stagnating = client.displayProgressStatus.toLowerCase() == 'stagnating';
    return staleActivity || stagnating;
  }

  void _openClient(CoachClientCardData client) {
    debugPrint(
      'COACH NAV CLIENT OPEN: clientId=${client.clientId} clientName=${client.displayName}',
    );
    widget.onOpenClient(
      CoachClientRouteArgs(
        clientId: client.clientId,
        clientName: client.displayName,
      ),
    );
  }

  void _openChat(CoachClientCardData client) {
    debugPrint(
      'COACH NAV CHAT OPEN FROM LIST: clientId=${client.clientId} clientName=${client.displayName}',
    );
    widget.onOpenChat(
      CoachClientRouteArgs(
        clientId: client.clientId,
        clientName: client.displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final String query = _searchController.text.trim().toLowerCase();

    final List<CoachClientCardData> filteredClients = _clients
        .where(
          (client) =>
              client.displayName.toLowerCase().contains(query) ||
              client.email.toLowerCase().contains(query) ||
              client.displayGoal.toLowerCase().contains(query) ||
              client.displayActivityLevel.toLowerCase().contains(query) ||
              client.displayProgressStatus.toLowerCase().contains(query),
        )
        .toList();

    final int attentionCount = _clients.where(_requiresAttention).length;
    final int activeCount = _clients
        .where((CoachClientCardData client) =>
            client.displayProgressStatus.toLowerCase() == 'active')
        .length;
    final int stagnatingCount = _clients
        .where((CoachClientCardData client) =>
            client.displayProgressStatus.toLowerCase() == 'stagnating')
        .length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddClientPage,
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Новый клиент'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadClients,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
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
                          'Всего ${_clients.length} клиентов • $attentionCount требуют внимания',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: widget.onOpenProfile,
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
                      const SizedBox(width: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _loadClients,
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
                            Icons.refresh_rounded,
                            size: 20,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Поиск по имени, email, цели или активности...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _CoachStatCard(
                    value: _clients.length.toString(),
                    label: 'Клиентов',
                    background: const Color(0xFFE0F2FE),
                    border: const Color(0xFFBAE6FD),
                    textColor: const Color(0xFF075985),
                  ),
                  _CoachStatCard(
                    value: activeCount.toString(),
                    label: 'Активные',
                    background: const Color(0xFFDCFCE7),
                    border: const Color(0xFFBBF7D0),
                    textColor: const Color(0xFF166534),
                  ),
                  _CoachStatCard(
                    value: stagnatingCount.toString(),
                    label: 'Снижение',
                    background: const Color(0xFFFEF3C7),
                    border: const Color(0xFFFDE68A),
                    textColor: const Color(0xFF92400E),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Список клиентов',
                style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const _LoadingStateCard()
              else if (_errorMessage != null)
                _ErrorStateCard(
                  message: _errorMessage!,
                  onRetry: _loadClients,
                )
              else if (filteredClients.isEmpty)
                const _EmptyStateCard()
              else
                ...filteredClients.map(
                  (CoachClientCardData client) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CoachClientCard(
                      item: client,
                      onOpenClient: () => _openClient(client),
                      onOpenChat: () => _openChat(client),
                    ),
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

class _CoachStatCard extends StatelessWidget {
  const _CoachStatCard({
    required this.value,
    required this.label,
    required this.background,
    required this.border,
    required this.textColor,
  });

  final String value;
  final String label;
  final Color background;
  final Color border;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _CoachClientCard extends StatelessWidget {
  const _CoachClientCard({
    required this.item,
    required this.onOpenClient,
    required this.onOpenChat,
  });

  final CoachClientCardData item;
  final VoidCallback onOpenClient;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final _StatusColors statusColors = _statusColorsFor(item.displayProgressStatus);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onOpenClient,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _ClientAvatar(
                    name: item.displayName,
                    avatarUrl: item.avatarUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.displayName,
                          style: textTheme.titleMedium?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.email.isNotEmpty ? item.email : 'Email не указан',
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _MetaChip(label: 'Возраст', value: item.displayAgeLabel),
                            _MetaChip(label: 'Цель', value: item.displayGoal),
                            _MetaChip(
                              label: 'Активность',
                              value: item.displayActivityLevel,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusBadge(
                    label: item.displayProgressStatusLabel,
                    statusColors: statusColors,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Последняя активность: ${item.displayLastActivityDate}',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Последняя сессия: ${item.displayLastSessionDate}',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                item.onboardingLabel,
                style: textTheme.bodySmall,
              ),
              if (item.notes.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  item.notes,
                  style: textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onOpenClient,
                      child: const Text('Открыть'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenChat,
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text('Чат'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurface),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.statusColors});

  final String label;
  final _StatusColors statusColors;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: statusColors.border),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(color: statusColors.text),
      ),
    );
  }
}

class _LoadingStateCard extends StatelessWidget {
  const _LoadingStateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        'Клиенты не найдены',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

class _ErrorStateCard extends StatelessWidget {
  const _ErrorStateCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}

class _ClientAvatar extends StatelessWidget {
  const _ClientAvatar({required this.name, required this.avatarUrl});

  final String name;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final List<String> parts = name.split(' ').where((String part) => part.isNotEmpty).toList();
    final String initials = parts
        .take(2)
        .map((String part) => part.characters.first.toUpperCase())
        .join();

    final Color background = const Color(0xFFE8E2D9).withValues(alpha: 1);

    if (avatarUrl.trim().isNotEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _InitialsAvatar(
              initials: initials,
              background: background,
            ),
          ),
        ),
      );
    }

    return _InitialsAvatar(initials: initials, background: background);
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials, required this.background});

  final String initials;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
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

class _StatusColors {
  const _StatusColors({
    required this.background,
    required this.border,
    required this.text,
  });

  final Color background;
  final Color border;
  final Color text;
}

_StatusColors _statusColorsFor(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return const _StatusColors(
        background: Color(0xFFDCFCE7),
        border: Color(0xFFBBF7D0),
        text: Color(0xFF166534),
      );
    case 'stagnating':
      return const _StatusColors(
        background: Color(0xFFFEF3C7),
        border: Color(0xFFFDE68A),
        text: Color(0xFF92400E),
      );
    case 'no data':
      return const _StatusColors(
        background: Color(0xFFF3F4F6),
        border: Color(0xFFE5E7EB),
        text: Color(0xFF6B7280),
      );
    default:
      return const _StatusColors(
        background: Color(0xFFE0F2FE),
        border: Color(0xFFBAE6FD),
        text: Color(0xFF075985),
      );
  }
}
