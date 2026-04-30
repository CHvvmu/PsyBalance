import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/identity_avatar.dart';
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
        avatarUrl: client.avatarUrl,
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
        avatarUrl: client.avatarUrl,
      ),
    );
  }

  void _showCheckInComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Функция отметки скоро появится'),
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
        label: const Text('Добавить клиента'),
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
                    label: 'Неактивные',
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
                      onCheckIn: () => _showCheckInComingSoon(context),
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
    required this.onCheckIn,
  });

  final CoachClientCardData item;
  final VoidCallback onOpenClient;
  final VoidCallback onOpenChat;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    try {
      return _buildCard(context);
    } catch (error, stackTrace) {
      debugPrint('COACH CLIENT CARD BUILD ERROR: $error');
      debugPrint('COACH CLIENT CARD BUILD STACK: $stackTrace');
      return _CoachClientCardFallback(
        onOpenClient: onOpenClient,
        onOpenChat: onOpenChat,
        onCheckIn: onCheckIn,
      );
    }
  }

  Widget _buildCard(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color cardBackground =
        theme.brightness == Brightness.light ? const Color(0xFFF8F4ED) : colors.surfaceContainerLow;
    final String displayName = _displayNameFor(item);
    final String? ageLabel = _ageLabelFor(item.age);
    final String behavioralStatus = _statusValue(item);
    final _StatusColors statusColors = _statusColorsFor(behavioralStatus);
    final String statusLabel = _statusLabelFor(behavioralStatus);
    final String? goal = _cleanVisibleText(item.goal);
    final String? activityLevel = _cleanVisibleText(item.activityLevel);
    final String? notes = _cleanVisibleText(item.notes);

    final List<Widget> metaRows = <Widget>[];

    final Widget? goalRow = _buildMetaRow(
      icon: Icons.flag_rounded,
      label: 'Цель',
      value: goal,
    );
    if (goalRow != null) {
      metaRows.add(goalRow);
    }

    final Widget? activityRow = _buildMetaRow(
      icon: Icons.bolt_rounded,
      label: 'Активность',
      value: activityLevel,
    );
    if (activityRow != null) {
      metaRows.add(activityRow);
    }

    final Widget? streakRow = _buildMetaRow(
      icon: Icons.local_fire_department_rounded,
      label: 'Серия',
      value: _consistencyStreakLabelFor(item),
    );
    if (streakRow != null) {
      metaRows.add(streakRow);
    }

    final Widget? lastActivityRow = _buildMetaRow(
      icon: Icons.schedule_rounded,
      label: 'Последняя активность',
      value: _formatLastActivityLabel(item.lastActivityDate),
    );
    if (lastActivityRow != null) {
      metaRows.add(lastActivityRow);
    }

    return Material(
      color: cardBackground,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onOpenClient,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(
                context,
                displayName: displayName,
                ageLabel: ageLabel,
                avatarUrl: _cleanVisibleText(item.avatarUrl) ?? '',
                statusLabel: statusLabel,
                statusColors: statusColors,
              ),
              if (metaRows.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      metaRows.first,
                      for (final Widget row in metaRows.skip(1)) ...<Widget>[
                        const SizedBox(height: 8),
                        row,
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const _BehaviorSummaryBlock(),
              if (notes != null) ...<Widget>[
                const SizedBox(height: 12),
                _CoachNoteBlock(notes: notes),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  SizedBox(
                    width: 100,
                    child: _CardActionButton(
                      icon: Icons.open_in_new_rounded,
                      label: 'Открыть',
                      onPressed: onOpenClient,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: _CardActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Чат',
                      onPressed: onOpenChat,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: _CardActionButton(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Отметка',
                      onPressed: onCheckIn,
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

  Widget _buildHeader(
    BuildContext context, {
    required String displayName,
    required String? ageLabel,
    required String avatarUrl,
    required String statusLabel,
    required _StatusColors statusColors,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    Widget identity() {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IdentityAvatar(
            displayName: displayName.trim().isEmpty ? 'Без имени' : displayName,
            avatarUrl: avatarUrl,
            size: 52,
            backgroundColor: colors.secondary.withValues(alpha: 0.18),
            textColor: colors.onSurface,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (ageLabel != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    ageLabel,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 360;
        final Widget badge = _StatusBadge(
          label: statusLabel,
          statusColors: statusColors,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              identity(),
              const SizedBox(height: 10),
              badge,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: identity()),
            const SizedBox(width: 10),
            Flexible(
              fit: FlexFit.loose,
              child: Align(
                alignment: Alignment.topRight,
                child: badge,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CoachClientCardFallback extends StatelessWidget {
  const _CoachClientCardFallback({
    required this.onOpenClient,
    required this.onOpenChat,
    required this.onCheckIn,
  });

  final VoidCallback onOpenClient;
  final VoidCallback onOpenChat;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color cardBackground =
        theme.brightness == Brightness.light ? const Color(0xFFF8F4ED) : colors.surfaceContainerLow;

    return Material(
      color: cardBackground,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onOpenClient,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.warning_rounded,
                    color: colors.tertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Карточка клиента временно недоступна',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  SizedBox(
                    width: 100,
                    child: _CardActionButton(
                      icon: Icons.open_in_new_rounded,
                      label: 'Открыть',
                      onPressed: onOpenClient,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: _CardActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Чат',
                      onPressed: onOpenChat,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: _CardActionButton(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Отметка',
                      onPressed: onCheckIn,
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

String _displayNameFor(CoachClientCardData item) {
  final String name = _cleanVisibleText(item.displayName) ?? '';
  final String email = _cleanVisibleText(item.email) ?? '';
  if (name.isEmpty || name == item.clientId || (email.isNotEmpty && name == email)) {
    return 'Без имени';
  }

  return name;
}

String? _ageLabelFor(int? age) {
  if (age == null || age < 0) {
    return null;
  }

  return '$age лет';
}

String? _cleanVisibleText(String? value) {
  final String trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }

  switch (trimmed.toLowerCase()) {
    case 'null':
    case 'none':
    case 'undefined':
      return null;
    default:
      return trimmed;
  }
}

String _statusValue(CoachClientCardData item) {
  final String explicitStatus = _normalizedExplicitStatus(item.progressStatus);
  if (explicitStatus.isNotEmpty) {
    return explicitStatus;
  }

  final bool hasRecentActivity = _hasRecentActivity(item.lastActivityDate) ||
      _hasRecentActivity(item.lastSessionDate);
  final bool hasAnyBehavioralActivity = item.lastActivityDate != null || item.lastSessionDate != null;
  final bool isNewClient = !item.onboardingCompleted && !hasAnyBehavioralActivity;

  if (isNewClient) {
    return 'onboarding';
  }

  if (!hasRecentActivity) {
    return 'inactive';
  }

  return 'engaged';
}

String _normalizedExplicitStatus(String status) {
  final String cleaned = _cleanVisibleText(status) ?? '';
  final String normalized = cleaned.toLowerCase();

  switch (normalized) {
    case 'engaged':
    case 'active':
      return 'engaged';
    case 'stable':
      return 'stable';
    case 'inconsistent':
    case 'stagnating':
      return 'inconsistent';
    case 'struggling':
      return 'struggling';
    case 'inactive':
      return 'inactive';
    case 'onboarding':
    case 'beginner':
      return 'onboarding';
    default:
      return '';
  }
}

bool _hasRecentActivity(DateTime? value) {
  if (value == null) {
    return false;
  }

  final DateTime now = DateTime.now();
  return now.difference(value).inDays < 7;
}

Widget? _buildMetaRow({
  required IconData icon,
  required String label,
  required String? value,
}) {
  final String trimmedValue = value?.trim() ?? '';
  if (trimmedValue.isEmpty) {
    return null;
  }

  return _CoachInfoRow(
    icon: icon,
    label: label,
    value: trimmedValue,
  );
}

String? _consistencyStreakLabelFor(CoachClientCardData item) {
  return null;
}

String _formatLastActivityLabel(DateTime? value) {
  if (value == null) {
    return '-';
  }

  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime activityDay = DateTime(value.year, value.month, value.day);
  final int dayDelta = today.difference(activityDay).inDays;

  if (dayDelta <= 0) {
    return 'сегодня';
  }

  if (dayDelta == 1) {
    return 'вчера';
  }

  return '${_daysAgoLabel(dayDelta)} назад';
}

String _daysAgoLabel(int days) {
  final int mod100 = days % 100;
  if (mod100 >= 11 && mod100 <= 14) {
    return '$days дней';
  }

  switch (days % 10) {
    case 1:
      return '$days день';
    case 2:
    case 3:
    case 4:
      return '$days дня';
    default:
      return '$days дней';
  }
}

String _statusLabelFor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'engaged':
    case 'active':
      return 'Вовлечён';
    case 'stable':
      return 'Стабильно';
    case 'inconsistent':
    case 'stagnating':
      return 'Нестабильно';
    case 'struggling':
      return 'Нужна поддержка';
    case 'inactive':
      return 'Пауза';
    case 'onboarding':
    case 'beginner':
      return 'Адаптация';
    default:
      return 'Адаптация';
  }
}

class _CoachInfoRow extends StatelessWidget {
  const _CoachInfoRow({
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          size: 16,
          color: colors.primary.withValues(alpha: 0.78),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '$label: ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _BehaviorSummaryBlock extends StatelessWidget {
  const _BehaviorSummaryBlock();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.insights_rounded,
            size: 18,
            color: colors.primary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Сводка по поведению',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Пока недостаточно данных',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachNoteBlock extends StatelessWidget {
  const _CoachNoteBlock({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.sticky_note_2_outlined,
                size: 18,
                color: colors.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 8),
              Text(
                'Заметка коуча',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            notes,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: colors.onSurface,
          backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.2),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.7)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          visualDensity: VisualDensity.compact,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.labelSmall?.copyWith(
          color: statusColors.text,
          fontWeight: FontWeight.w700,
        ),
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
  switch (status.trim().toLowerCase()) {
    case 'engaged':
    case 'active':
      return const _StatusColors(
        background: Color(0xFFE4F7ED),
        border: Color(0xFFB7E4CA),
        text: Color(0xFF166534),
      );
    case 'stable':
      return const _StatusColors(
        background: Color(0xFFE8F1FF),
        border: Color(0xFFC9D8FF),
        text: Color(0xFF1D4ED8),
      );
    case 'inconsistent':
    case 'stagnating':
      return const _StatusColors(
        background: Color(0xFFFFF3D9),
        border: Color(0xFFF2D08A),
        text: Color(0xFF9A6700),
      );
    case 'struggling':
      return const _StatusColors(
        background: Color(0xFFFFE8E8),
        border: Color(0xFFF5B5B5),
        text: Color(0xFFB42318),
      );
    case 'inactive':
      return const _StatusColors(
        background: Color(0xFFF3F4F6),
        border: Color(0xFFE5E7EB),
        text: Color(0xFF6B7280),
      );
    case 'onboarding':
    case 'beginner':
      return const _StatusColors(
        background: Color(0xFFF3E8FF),
        border: Color(0xFFE9D5FF),
        text: Color(0xFF7C3AED),
      );
    default:
      return const _StatusColors(
        background: Color(0xFFF3E8FF),
        border: Color(0xFFE9D5FF),
        text: Color(0xFF7C3AED),
      );
  }
}
