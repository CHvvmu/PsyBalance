import 'package:flutter/material.dart';

import '../../features/admin/admin_page.dart';
import '../../features/auth/auth_page.dart';
import '../../features/auth/auth_service.dart';
import '../../features/auth/user_role.dart';
import '../../features/chat/chat_page.dart';
import '../../features/checkin/checkin_page.dart';
import '../../features/coach_panel/presentation/coach_client_details_page.dart';
import '../../features/coach_panel/presentation/coach_clients_page.dart';
import '../../features/content/knowledge_base_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/food_log/food_log_page.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/plan/plan_page.dart';
import '../../features/profile/profile_page.dart';

class AppRouter {
  AppRouter({required this.authService});

  final AuthService authService;

  static const String splash = '/splash';
  static const String auth = '/auth';
  static const String onboarding = '/onboarding';

  static const String clientDashboard = '/client/dashboard';
  static const String clientCheckIn = '/client/check-in';
  static const String clientFoodLog = '/client/food-log';
  static const String clientPlan = '/client/plan';
  static const String clientChat = '/client/chat';
  static const String clientKnowledgeBase = '/client/knowledge-base';
  static const String profile = '/profile';

  static const String coachPanel = '/coach/panel';
  static const String coachClientDetails = '/coach/client-details';
  static const String coachChat = '/coach/chat';
  static const String coachPlanEditor = '/coach/plan-editor';

  static const String adminPanel = '/admin/panel';

  static const Set<String> _authRoutes = <String>{
    splash,
    auth,
  };

  static const Set<String> _clientRoutes = <String>{
    clientDashboard,
    clientCheckIn,
    clientFoodLog,
    clientPlan,
    clientChat,
    clientKnowledgeBase,
    profile,
  };

  static const Set<String> _coachRoutes = <String>{
    coachPanel,
    coachClientDetails,
    coachChat,
    coachPlanEditor,
    profile,
  };

  static const Set<String> _adminRoutes = <String>{
    adminPanel,
    profile,
  };

  static final Set<String> _protectedRoutes = <String>{
    onboarding,
    ..._clientRoutes,
    ..._coachRoutes,
    ..._adminRoutes,
  };

  String homeRouteForRole(UserRole role) {
    switch (role) {
      case UserRole.client:
        return clientDashboard;
      case UserRole.coach:
        return coachPanel;
      case UserRole.administrator:
        return adminPanel;
    }
  }

  String entryRouteForRole(UserRole role) {
    if (role == UserRole.client && !authService.isOnboardingCompleted) {
      return onboarding;
    }
    return homeRouteForRole(role);
  }

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final String routeName = _normalizeRouteName(settings.name);
    final bool isAuthenticated = authService.currentUser != null;
    final UserRole? role = authService.cachedRole;
    print('ROUTE: $routeName role: $role');

    if (_authRoutes.contains(routeName)) {
      return _buildByRoute(routeName);
    }

    if (isAuthenticated && role == null) {
      return _buildLoadingRoute();
    }

    if (_protectedRoutes.contains(routeName) && !isAuthenticated) {
      return _buildAuthRoute();
    }

    if (role != null && !_isAllowedForRole(role: role, routeName: routeName)) {
      return _buildByRoute(homeRouteForRole(role));
    }

    if (role != null) {
      if (role == UserRole.client &&
          !authService.isOnboardingCompleted &&
          routeName != onboarding) {
        return _buildByRoute(onboarding);
      }
      if (authService.isOnboardingCompleted && routeName == onboarding) {
        return _buildByRoute(homeRouteForRole(role));
      }
    }

    return _buildByRoute(routeName);
  }

  String _normalizeRouteName(String? routeName) {
    if (routeName == null || routeName.isEmpty || routeName == '/') {
      return splash;
    }
    return routeName;
  }

  bool _isAllowedForRole({required UserRole role, required String routeName}) {
    if (routeName == onboarding) {
      return true;
    }

    switch (role) {
      case UserRole.client:
        return _clientRoutes.contains(routeName);
      case UserRole.coach:
        return _coachRoutes.contains(routeName);
      case UserRole.administrator:
        return _adminRoutes.contains(routeName);
    }
  }

  Route<dynamic> _buildByRoute(String routeName) {
    switch (routeName) {
      case splash:
        return _buildSplashRoute();
      case auth:
        return _buildAuthRoute();
      case onboarding:
        return _buildOnboardingRoute();
      case clientDashboard:
        return _buildClientDashboardRoute();
      case clientCheckIn:
        return _buildDailyCheckInRoute();
      case clientFoodLog:
        return _buildFoodLogRoute();
      case clientPlan:
        return _buildClientPlanRoute();
      case clientChat:
        return _buildCoachChatRoute(routeName: clientChat);
      case clientKnowledgeBase:
        return _buildKnowledgeBaseRoute();
      case profile:
        return _buildProfileRoute();
      case coachPanel:
        return _buildCoachClientsRoute();
      case coachClientDetails:
        return _buildCoachClientDetailsRoute();
      case coachChat:
        return _buildCoachChatRoute(routeName: coachChat);
      case coachPlanEditor:
        return _buildCoachPlanEditorRoute();
      case adminPanel:
        return _buildAdminPanelRoute();
      default:
        return _buildAuthRoute();
    }
  }

  MaterialPageRoute<dynamic> _buildSplashRoute() {
    return MaterialPageRoute<dynamic>(
      settings: const RouteSettings(name: splash),
      builder: (_) {
        return _SplashRedirectPage(
          authService: authService,
          resolveEntryRoute: entryRouteForRole,
        );
      },
    );
  }

  MaterialPageRoute<dynamic> _buildAuthRoute() {
    return MaterialPageRoute<dynamic>(
      settings: const RouteSettings(name: auth),
      builder: (_) => AuthPage(authService: authService),
    );
  }

  MaterialPageRoute<dynamic> _buildLoadingRoute() {
    return MaterialPageRoute<dynamic>(
      builder: (_) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  MaterialPageRoute<dynamic> _buildOnboardingRoute() {
    return MaterialPageRoute<dynamic>(
      settings: const RouteSettings(name: onboarding),
      builder: (BuildContext context) {
        return OnboardingPage(
          authService: authService,
          onCompleted: () {
            final UserRole? role = authService.cachedRole;
            final navigator = Navigator.of(context);
            navigator.pushNamedAndRemoveUntil(
              role != null ? homeRouteForRole(role) : auth,
              (Route<dynamic> route) => false,
            );
          },
        );
      },
    );
  }

  MaterialPageRoute<dynamic> _buildClientDashboardRoute() {
    return MaterialPageRoute<dynamic>(
      settings: const RouteSettings(name: clientDashboard),
      builder: (BuildContext context) {
        return ClientDashboardPage(
          onOpenFood: () => Navigator.of(context).pushNamed(clientFoodLog),
          onOpenStress: () => Navigator.of(context).pushNamed(clientCheckIn),
          onOpenSleep: () => Navigator.of(context).pushNamed(clientCheckIn),
          onOpenSport: () => Navigator.of(context).pushNamed(clientPlan),
          onOpenPlan: () => Navigator.of(context).pushNamed(clientPlan),
          onOpenKnowledgeBase: () =>
              Navigator.of(context).pushNamed(clientKnowledgeBase),
          onOpenChat: () => Navigator.of(context).pushNamed(clientChat),
          onAdd: () => Navigator.of(context).pushNamed(clientCheckIn),
          onOpenProfile: () => Navigator.of(context).pushNamed(profile),
        );
      },
    );
  }

  MaterialPageRoute<dynamic> _buildCoachClientsRoute() {
    return MaterialPageRoute<dynamic>(
      settings: const RouteSettings(name: coachPanel),
      builder: (BuildContext context) {
        return CoachClientsPage(
          onOpenClient: (_) => Navigator.of(context).pushNamed(coachClientDetails),
          onOpenChat: (_) => Navigator.of(context).pushNamed(coachChat),
          onCreateClient: () => Navigator.of(context).pushNamed(coachClientDetails),
          onOpenProfile: () => Navigator.of(context).pushNamed(profile),
        );
      },
    );
  }

  MaterialPageRoute<dynamic> _buildProfileRoute() {
    return MaterialPageRoute<dynamic>(
      settings: const RouteSettings(name: profile),
      builder: (_) {
        final UserRole role = authService.cachedRole ?? UserRole.client;
        return ProfilePage(authService: authService, role: role);
      },
    );
  }

  MaterialPageRoute<dynamic> _buildDailyCheckInRoute() {
    return MaterialPageRoute<dynamic>(
      settings: const RouteSettings(name: clientCheckIn),
      builder: (_) => const DailyCheckInPage(),
    );
  }

  MaterialPageRoute<dynamic> _buildCoachClientDetailsRoute() {
    return MaterialPageRoute<dynamic>(
      settings: const RouteSettings(name: coachClientDetails),
      builder: (BuildContext context) {
        return CoachClientDetailsPage(
          onBack: () => Navigator.of(context).maybePop(),
          onOpenCall: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Видеозвонок будет доступен позже.')),
            );
          },
          onOpenPlanEditor: () => Navigator.of(context).pushNamed(coachPlanEditor),
          onOpenChat: () => Navigator.of(context).pushNamed(coachChat),
        );
      },
    );
  }

  MaterialPageRoute<dynamic> _buildCoachChatRoute({required String routeName}) {
    return MaterialPageRoute<dynamic>(
      settings: RouteSettings(name: routeName),
      builder: (_) {
        return const CoachChatPage(
          peerName: 'Михаил Волков',
          avatarUrl:
              'https://dimg.dreamflow.cloud/v1/image/professional+male+health+coach+smiling',
        );
      },
    );
  }

  MaterialPageRoute<dynamic> _buildAdminPanelRoute() {
    return MaterialPageRoute<dynamic>(
      settings: const RouteSettings(name: adminPanel),
      builder: (_) => const AdminPanelPage(),
    );
  }

  MaterialPageRoute<dynamic> _buildFoodLogRoute() {
    return MaterialPageRoute<dynamic>(
      settings: const RouteSettings(name: clientFoodLog),
      builder: (_) => const FoodLogPage(),
    );
  }

  MaterialPageRoute<dynamic> _buildClientPlanRoute() {
    return MaterialPageRoute<dynamic>(
      settings: const RouteSettings(name: clientPlan),
      builder: (_) => const ActivityPlanPage(title: 'План активности'),
    );
  }

  MaterialPageRoute<dynamic> _buildCoachPlanEditorRoute() {
    return MaterialPageRoute<dynamic>(
      settings: const RouteSettings(name: coachPlanEditor),
      builder: (_) => const ActivityPlanPage(title: 'Редактор плана клиента'),
    );
  }

  MaterialPageRoute<dynamic> _buildKnowledgeBaseRoute() {
    return MaterialPageRoute<dynamic>(
      settings: const RouteSettings(name: clientKnowledgeBase),
      builder: (_) => const KnowledgeBasePage(),
    );
  }

}

class _SplashRedirectPage extends StatefulWidget {
  const _SplashRedirectPage({
    required this.authService,
    required this.resolveEntryRoute,
  });

  final AuthService authService;
  final String Function(UserRole role) resolveEntryRoute;

  @override
  State<_SplashRedirectPage> createState() => _SplashRedirectPageState();
}

class _SplashRedirectPageState extends State<_SplashRedirectPage> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _scheduleRedirect();
  }

  Future<void> _scheduleRedirect() async {
    await Future<void>.delayed(const Duration(milliseconds: 380));

    if (!mounted || _hasNavigated) {
      return;
    }

    final DateTime startedAt = DateTime.now();
    while (mounted &&
        !_hasNavigated &&
        DateTime.now().difference(startedAt) < const Duration(seconds: 2)) {
      final String? targetRoute = _resolveTargetRoute();
      if (targetRoute != null) {
        _navigate(targetRoute);
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    _navigate(AppRouter.auth);
  }

  String? _resolveTargetRoute() {
    final bool isAuthenticated = widget.authService.currentUser != null;
    if (!isAuthenticated) {
      return AppRouter.auth;
    }

    final UserRole? role = widget.authService.cachedRole;
    if (role == null) {
      return null;
    }

    return widget.resolveEntryRoute(role);
  }

  void _navigate(String targetRoute) {
    if (!mounted || _hasNavigated) {
      return;
    }

    final String? currentRouteName = ModalRoute.of(context)?.settings.name;
    if (currentRouteName != AppRouter.splash) {
      return;
    }

    final String routeToOpen =
        targetRoute == AppRouter.splash ? AppRouter.auth : targetRoute;
    _hasNavigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final String? routeName = ModalRoute.of(context)?.settings.name;
      if (routeName != AppRouter.splash) {
        debugPrint(
          'SplashRedirect: skip navigation to $routeToOpen, current route: $routeName',
        );
        return;
      }

      debugPrint('SplashRedirect: navigate to $routeToOpen');
      Navigator.of(context).pushReplacementNamed(routeToOpen);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.favorite_rounded,
                size: 38,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'PsyBalance',
              style: textTheme.headlineMedium?.copyWith(
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const LinearProgressIndicator(minHeight: 3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

