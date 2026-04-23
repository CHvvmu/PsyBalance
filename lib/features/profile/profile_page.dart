import 'package:flutter/material.dart';

import '../auth/auth_failure.dart';
import '../auth/auth_service.dart';
import '../auth/user_role.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.authService,
    required this.role,
  });

  final AuthService authService;
  final UserRole role;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _notificationsEnabled = true;
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final String email = widget.authService.currentUser?.email ?? 'anna.smith@example.com';
    final String displayName = _resolveDisplayName(role: widget.role);
    final String avatarUrl = _resolveAvatarUrl(role: widget.role);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _ProfileHeader(
                displayName: displayName,
                email: email,
                avatarUrl: avatarUrl,
                onEditPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Редактирование профиля появится позже.')),
                  );
                },
              ),
              const SizedBox(height: 24),
              if (_isClientOrCoach(widget.role)) ...<Widget>[
                Text(
                  'Детали аккаунта',
                  style: textTheme.titleLarge?.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  children: _buildAccountRows(role: widget.role),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                'Настройки',
                style: textTheme.titleLarge?.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                children: <Widget>[
                  _ProfileMenuRow(
                    icon: Icons.notifications_rounded,
                    label: 'Уведомления',
                    trailing: Switch.adaptive(
                      value: _notificationsEnabled,
                      activeThumbColor: colors.primary,
                      activeTrackColor: colors.primary.withValues(alpha: 0.35),
                      onChanged: (bool value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _ProfileMenuRow(
                    icon: Icons.security_rounded,
                    label: 'Безопасность и пароль',
                    trailing: Icon(Icons.chevron_right_rounded),
                  ),
                  const SizedBox(height: 12),
                  _ProfileMenuRow(
                    icon: Icons.language_rounded,
                    label: 'Язык',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Русский',
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _LogoutButton(
                isLoading: _isLoggingOut,
                onPressed: _logout,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAccountRows({required UserRole role}) {
    if (role == UserRole.client) {
      return const <Widget>[
        _ProfileMenuRow(
          icon: Icons.workspace_premium_rounded,
          label: 'Моя подписка',
          trailing: Icon(Icons.chevron_right_rounded),
        ),
        SizedBox(height: 12),
        _ProfileMenuRow(
          icon: Icons.person_rounded,
          label: 'Мой тренер',
          trailing: Icon(Icons.chevron_right_rounded),
        ),
      ];
    }

    return const <Widget>[
      _ProfileMenuRow(
        icon: Icons.groups_rounded,
        label: 'Управление клиентами',
        trailing: Icon(Icons.chevron_right_rounded),
      ),
      SizedBox(height: 12),
      _ProfileMenuRow(
        icon: Icons.bar_chart_rounded,
        label: 'Доход и статистика',
        trailing: Icon(Icons.chevron_right_rounded),
      ),
    ];
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await widget.authService.logout();
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  bool _isClientOrCoach(UserRole role) {
    return role == UserRole.client || role == UserRole.coach;
  }

  String _resolveDisplayName({required UserRole role}) {
    switch (role) {
      case UserRole.client:
        return 'Анна Смирнова';
      case UserRole.coach:
        return 'Михаил Волков';
      case UserRole.administrator:
        return 'Администратор PsyBalance';
    }
  }

  String _resolveAvatarUrl({required UserRole role}) {
    switch (role) {
      case UserRole.client:
        return 'https://dimg.dreamflow.cloud/v1/image/smiling+woman+professional+portrait';
      case UserRole.coach:
        return 'https://dimg.dreamflow.cloud/v1/image/professional+male+health+coach+smiling';
      case UserRole.administrator:
        return 'https://dimg.dreamflow.cloud/v1/image/professional+person+portrait';
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.onEditPressed,
  });

  final String displayName;
  final String email;
  final String avatarUrl;
  final VoidCallback onEditPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Column(
      children: <Widget>[
        Container(
          width: 120,
          height: 120,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surface,
            border: Border.all(color: colors.surface, width: 4),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext context, Object _, StackTrace? __) {
                return Container(
                  color: colors.primary.withValues(alpha: 0.2),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.person_rounded,
                    size: 48,
                    color: colors.onSurface,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: textTheme.headlineMedium?.copyWith(color: colors.onSurface),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onEditPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Редактировать профиль'),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: colors.onSurface),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
            ),
          ),
          IconTheme(
            data: IconThemeData(color: colors.onSurface),
            child: trailing,
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed, required this.isLoading});

  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    const Color logoutColor = Color(0xFFE57373);

    return InkWell(
      onTap: isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: logoutColor.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: <Widget>[
            if (isLoading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.logout_rounded, size: 22, color: logoutColor),
            const SizedBox(width: 12),
            const Text(
              'Выйти из аккаунта',
              style: TextStyle(
                color: logoutColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

