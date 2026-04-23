import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/services/supabase_service.dart';
import 'auth_failure.dart';
import 'user_role.dart';

class RegisterResult {
  const RegisterResult({
    required this.user,
    required this.session,
    required this.role,
  });

  final User? user;
  final Session? session;
  final UserRole role;

  bool get hasSession => session != null;
}

class LoginResult {
  const LoginResult({
    required this.session,
    required this.role,
  });

  final Session? session;
  final UserRole role;

  bool get hasSession => session != null;
}

class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;
  UserRole? _cachedRole;
  bool? _cachedOnboardingCompleted;

  User? get currentUser => _client.auth.currentUser;
  UserRole? get cachedRole => _cachedRole;
  bool get isOnboardingCompleted {
    if (_cachedOnboardingCompleted != null) {
      return _cachedOnboardingCompleted!;
    }

    _cachedOnboardingCompleted = _readOnboardingCompletedFromCurrentUser();
    return _cachedOnboardingCompleted!;
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  void clearRoleCache() {
    _cachedRole = null;
    _cachedOnboardingCompleted = null;
  }

  void hydrateFromCurrentUser() {
    _cachedOnboardingCompleted = _readOnboardingCompletedFromCurrentUser();
  }

  Future<UserRole> getUserRole({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedRole != null) {
      return _cachedRole!;
    }

    final User? user = currentUser;
    if (user == null) {
      throw AuthFailure('Unauthenticated');
    }

    try {
      final UserRole? roleFromTable = await _tryReadRoleFromUsersTable(
        userId: user.id,
      );
      if (roleFromTable != null) {
        _setRoleCache(roleFromTable);
        return roleFromTable;
      }

      final UserRole? roleFromMetadata = _readRoleFromCurrentUserMetadata();
      if (roleFromMetadata != null) {
        await _persistUserRoleSilently(userId: user.id, role: roleFromMetadata);
        _setRoleCache(roleFromMetadata);
        return roleFromMetadata;
      }

      const UserRole fallbackRole = UserRole.client;
      await _persistUserRoleSilently(userId: user.id, role: fallbackRole);
      _setRoleCache(fallbackRole);
      return fallbackRole;
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw AuthFailure('Network error. Please try again.');
    }
  }

  Future<void> completeOnboarding({
    required String goal,
    double? currentWeightKg,
    double? targetWeightKg,
    int? heightCm,
    List<String>? difficulties,
  }) async {
    try {
      final Map<String, dynamic> data = <String, dynamic>{
        'onboarding_completed': true,
        'onboarding_goal': goal,
      };

      if (currentWeightKg != null) {
        data['onboarding_current_weight_kg'] = currentWeightKg;
      }
      if (targetWeightKg != null) {
        data['onboarding_target_weight_kg'] = targetWeightKg;
      }
      if (heightCm != null) {
        data['onboarding_height_cm'] = heightCm;
      }
      if (difficulties != null && difficulties.isNotEmpty) {
        data['onboarding_difficulties'] = difficulties;
      }

      await _client.auth.updateUser(
        UserAttributes(
          data: data,
        ),
      );
      _cachedOnboardingCompleted = true;
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (_) {
      throw AuthFailure('Network error. Please try again.');
    }
  }

  Future<RegisterResult> register({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final String normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw AuthFailure('Заполните email и пароль.');
    }
    if (!_isValidEmail(normalizedEmail)) {
      throw AuthFailure('Введите корректный email.');
    }
    if (password.length < 6) {
      throw AuthFailure('Пароль должен содержать минимум 6 символов.');
    }

    print(
      'SIGNUP REQUEST: email=${_maskEmail(normalizedEmail)}, '
      'SUPABASE_URL=${AppConfig.supabaseUrl}, '
      'ANON_KEY_PRESENT=${AppConfig.supabaseAnonKey.isNotEmpty}',
    );

    try {
      final AuthResponse response;
      try {
        response = await _client.auth.signUp(
          email: normalizedEmail,
          password: password,
          data: <String, dynamic>{
            'role': role.value,
            'onboarding_completed': false,
          },
        );
        print(
          'SIGNUP RESPONSE: userId=${response.user?.id}, '
          'session=${response.session != null}, '
          'emailConfirmedAt=${response.user?.emailConfirmedAt}',
        );
        print('SIGNUP SUCCESS: ${response.user?.id}');
      } catch (e, stack) {
        print('SIGNUP ERROR: $e');
        print(stack);
        rethrow;
      }

      final UserRole resolvedRole = await _resolveAndCacheRoleAfterAuth(
        fallbackRole: role,
        explicitUserId: response.user?.id,
      );

      return RegisterResult(
        user: response.user,
        session: response.session,
        role: resolvedRole,
      );
    } on AuthException catch (e) {
      throw AuthFailure(_mapSignUpError(e));
    } catch (_) {
      throw AuthFailure('Network error. Please try again.');
    }
  }

  Future<LoginResult> login({required String email, required String password}) async {
    final String normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw AuthFailure('Заполните email и пароль.');
    }
    if (!_isValidEmail(normalizedEmail)) {
      throw AuthFailure('Введите корректный email.');
    }
    if (password.length < 6) {
      throw AuthFailure('Пароль должен содержать минимум 6 символов.');
    }

    try {
      final AuthResponse response = await _client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
      final UserRole resolvedRole = await _resolveAndCacheRoleAfterAuth(
        fallbackRole: UserRole.client,
        explicitUserId: response.user?.id,
      );

      return LoginResult(
        session: response.session,
        role: resolvedRole,
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (_) {
      throw AuthFailure('Network error. Please try again.');
    }
  }

  Future<void> logout() async {
    try {
      await _client.auth.signOut();
      clearRoleCache();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  Future<void> resetPassword({required String email}) async {
    final String normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw AuthFailure('Введите email.');
    }
    if (!_isValidEmail(normalizedEmail)) {
      throw AuthFailure('Введите корректный email.');
    }

    try {
      await _client.auth.resetPasswordForEmail(normalizedEmail);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (_) {
      throw AuthFailure('Network error. Please try again.');
    }
  }

  bool _readOnboardingCompletedFromCurrentUser() {
    final dynamic raw = currentUser?.userMetadata?['onboarding_completed'];
    if (raw is bool) {
      return raw;
    }
    if (raw is String) {
      return raw.toLowerCase() == 'true';
    }
    return false;
  }

  UserRole? _readRoleFromCurrentUserMetadata() {
    final dynamic raw = currentUser?.userMetadata?['role'];
    if (raw is String) {
      return UserRoleMapper.fromValue(raw);
    }
    return null;
  }

  Future<UserRole?> _tryReadRoleFromUsersTable({required String userId}) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return UserRoleMapper.fromValue(row?['role'] as String?);
    } on PostgrestException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<UserRole?> _fetchRoleFromUsersTableByAuthUid() async {
    final String? authUserId = currentUser?.id;
    if (authUserId == null) {
      return null;
    }

    return _tryReadRoleFromUsersTable(userId: authUserId);
  }

  Future<UserRole> _resolveAndCacheRoleAfterAuth({
    required UserRole fallbackRole,
    String? explicitUserId,
  }) async {
    final UserRole? roleFromAuthUid = await _fetchRoleFromUsersTableByAuthUid();
    if (roleFromAuthUid != null) {
      _setRoleCache(roleFromAuthUid);
      return roleFromAuthUid;
    }

    final String? userId = explicitUserId ?? currentUser?.id;
    if (userId != null) {
      final UserRole? roleFromTable = await _tryReadRoleFromUsersTable(
        userId: userId,
      );
      if (roleFromTable != null) {
        _setRoleCache(roleFromTable);
        return roleFromTable;
      }
    }

    final UserRole? roleFromMetadata = _readRoleFromCurrentUserMetadata();
    if (roleFromMetadata != null) {
      if (userId != null) {
        await _persistUserRoleSilently(userId: userId, role: roleFromMetadata);
      }
      _setRoleCache(roleFromMetadata);
      return roleFromMetadata;
    }

    if (userId != null) {
      await _persistUserRoleSilently(userId: userId, role: fallbackRole);
    }
    _setRoleCache(fallbackRole);
    return fallbackRole;
  }

  void _setRoleCache(UserRole role) {
    _cachedRole = role;
    _cachedOnboardingCompleted = _readOnboardingCompletedFromCurrentUser();
  }

  Future<void> _persistUserRoleSilently({
    required String userId,
    required UserRole role,
  }) async {
    try {
      await _client.from('users').upsert(
        <String, dynamic>{
          'id': userId,
          'role': role.value,
        },
        onConflict: 'id',
      );
    } on PostgrestException {
      return;
    } catch (_) {
      return;
    }
  }

  String _mapSignUpError(AuthException exception) {
    final String raw = exception.message;
    final String normalized = raw.toLowerCase();

    if (normalized.contains('rate limit') ||
        normalized.contains('too many requests')) {
      return 'Слишком много попыток регистрации. Попробуйте позже.';
    }

    if (normalized.contains('invalid email') ||
        normalized.contains('email address')) {
      return 'Введите корректный email.';
    }

    if (normalized.contains('already registered') ||
        normalized.contains('user already registered')) {
      return 'Пользователь с таким email уже зарегистрирован.';
    }

    return raw;
  }

  bool _isValidEmail(String value) {
    final RegExp emailRegex = RegExp(
      r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
    );
    return emailRegex.hasMatch(value);
  }

  String _maskEmail(String email) {
    final List<String> parts = email.split('@');
    if (parts.length != 2) {
      return '***';
    }

    final String local = parts[0];
    final String domain = parts[1];
    if (local.length <= 2) {
      return '${local[0]}***@$domain';
    }

    return '${local[0]}***${local[local.length - 1]}@$domain';
  }
}

