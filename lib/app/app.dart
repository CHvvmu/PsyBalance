import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/auth_failure.dart';
import '../features/auth/auth_service.dart';
import '../features/auth/user_role.dart';
import 'router/app_router.dart';

class PsyBalanceApp extends StatefulWidget {
  const PsyBalanceApp({super.key});

  @override
  State<PsyBalanceApp> createState() => _PsyBalanceAppState();
}

class _PsyBalanceAppState extends State<PsyBalanceApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AuthService _authService;
  late final AppRouter _appRouter;

  StreamSubscription<AuthState>? _authSubscription;
  bool _isResolvingRole = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _appRouter = AppRouter(authService: _authService);

    _authSubscription = _authService.authStateChanges.listen(
      _handleAuthStateChange,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapNavigation();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _handleAuthStateChange(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.initialSession:
        if (_authService.currentUser == null) {
          _goTo(AppRouter.auth);
        } else {
          _resolveRoleAndRedirect(forceRefresh: false);
        }
        break;
      case AuthChangeEvent.signedIn:
        _resolveRoleAndRedirect(forceRefresh: true);
        break;
      case AuthChangeEvent.signedOut:
        _authService.clearRoleCache();
        _goTo(AppRouter.auth);
        break;
      default:
        break;
    }
  }

  Future<void> _bootstrapNavigation() async {
    if (_authService.currentUser == null) {
      _goTo(AppRouter.auth);
      return;
    }

    await _resolveRoleAndRedirect(forceRefresh: true);
  }

  Future<void> _resolveRoleAndRedirect({required bool forceRefresh}) async {
    if (_isResolvingRole) {
      return;
    }

    _isResolvingRole = true;
    try {
      final UserRole role = await _authService.getUserRole(
        forceRefresh: forceRefresh,
      );
      _goTo(_appRouter.entryRouteForRole(role));
    } on AuthFailure {
      try {
        await _authService.logout();
      } catch (_) {}
      _goTo(AppRouter.auth);
    } finally {
      _isResolvingRole = false;
    }
  }

  void _goTo(String routeName) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    navigator.pushNamedAndRemoveUntil(
      routeName,
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      initialRoute: AppRouter.splash,
      onGenerateRoute: _appRouter.onGenerateRoute,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
    );
  }
}

