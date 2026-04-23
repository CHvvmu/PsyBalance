import 'package:flutter/material.dart';

import '../../app/router/app_router.dart';
import 'auth_failure.dart';
import 'auth_service.dart';
import 'user_role.dart';
import 'password_reset_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoginMode = true;
  bool _isLoading = false;
  String _selectedRole = 'client';
  String? _feedbackMessage;
  bool _feedbackIsError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });

    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    try {
      if (_isLoginMode) {
        final LoginResult loginResult = await widget.authService.login(
          email: email,
          password: password,
        );

        if (!mounted) {
          return;
        }

        if (loginResult.hasSession) {
          await widget.authService.loadUserRole();
          final String targetRoute =
              AppRouter(authService: widget.authService).entryRouteForRole(
            loginResult.role,
          );
          debugPrint(
            'AuthPage: login session detected, waiting auth listener redirect to $targetRoute',
          );
          return;
        }

        _showFeedback(
          'Вход выполнен. Подтвердите email, если это требуется настройками проекта.',
          isError: false,
        );
        return;
      } else {
        final RegisterResult registerResult = await widget.authService.register(
          email: email,
          password: password,
          role: _selectedRole == 'coach' ? UserRole.coach : UserRole.client,
        );

        if (!mounted) {
          return;
        }

        if (registerResult.user == null) {
          _showFeedback(
            'Регистрация выполнена. Проверьте почту для подтверждения email.',
            isError: false,
          );
          return;
        }

        if (registerResult.hasSession) {
          await widget.authService.loadUserRole();
          final String targetRoute =
              AppRouter(authService: widget.authService).entryRouteForRole(
            registerResult.role,
          );
          debugPrint(
            'AuthPage: register session detected, waiting auth listener redirect to $targetRoute',
          );
          return;
        }

        _showFeedback(
          'Регистрация выполнена. Проверьте почту для подтверждения email.',
          isError: false,
        );
      }
    } on AuthFailure catch (e) {
      _showFeedback(e.message, isError: true);
    } catch (_) {
      _showFeedback('Произошла ошибка. Попробуйте еще раз.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 40,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('PsyBalance', style: textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Ваш путь к устойчивому похудению',
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text('Кто вы?', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _RoleCard(
                        title: 'Клиент',
                        icon: Icons.person_rounded,
                        selected: _selectedRole == 'client',
                        onTap: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _selectedRole = 'client';
                                });
                              },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RoleCard(
                        title: 'Тренер',
                        icon: Icons.psychology_rounded,
                        selected: _selectedRole == 'coach',
                        onTap: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _selectedRole = 'coach';
                                });
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'example@mail.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  validator: (String? value) {
                    final String input = (value ?? '').trim();
                    if (input.isEmpty || !_isValidEmail(input)) {
                      return 'Введите корректный email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    hintText: '••••••••',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                    suffixIcon: Icon(Icons.visibility_off_rounded),
                  ),
                  validator: (String? value) {
                    final String input = value ?? '';
                    if (input.isEmpty) {
                      return 'Введите пароль';
                    }
                    if (input.length < 6) {
                      return 'Минимум 6 символов';
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) {
                                  return PasswordResetPage(
                                    authService: widget.authService,
                                    initialEmail: _emailController.text.trim(),
                                  );
                                },
                              ),
                            );
                          },
                    child: const Text('Забыли пароль?'),
                  ),
                ),
                const SizedBox(height: 8),
                if (_feedbackMessage != null) ...<Widget>[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _feedbackIsError
                          ? Theme.of(context).colorScheme.error.withValues(alpha: 0.08)
                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _feedbackIsError
                            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.35)
                            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _feedbackMessage!,
                      style: textTheme.bodySmall?.copyWith(
                        color: _feedbackIsError
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isLoginMode ? 'Войти в аккаунт' : 'Зарегистрироваться'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('или', style: textTheme.labelSmall),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Google auth не подключен в MVP.'),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.g_mobiledata_rounded),
                        label: const Text('Google'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Apple auth не подключен в MVP.'),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.apple_rounded),
                        label: const Text('Apple'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      _isLoginMode ? 'Нет аккаунта?' : 'Уже есть аккаунт?',
                      style: textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isLoginMode = !_isLoginMode;
                              });
                            },
                      child: Text(
                        _isLoginMode ? 'Зарегистрироваться' : 'Войти',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isValidEmail(String value) {
    final RegExp emailRegex = RegExp(
      r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
    );
    return emailRegex.hasMatch(value);
  }

  void _showFeedback(String message, {required bool isError}) {
    if (!mounted) {
      return;
    }

    setState(() {
      _feedbackMessage = message;
      _feedbackIsError = isError;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).dividerColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon),
            const SizedBox(height: 8),
            Text(title),
          ],
        ),
      ),
    );
  }
}

