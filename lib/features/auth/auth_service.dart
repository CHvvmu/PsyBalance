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

  Future<void> loadUserRole() async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      print('ROLE LOAD: skipped, user is null');
      return;
    }

    try {
      final Map<String, dynamic>? response = await _client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final UserRole? roleFromTable = UserRoleMapper.fromValue(
        response?['role'] as String?,
      );

      if (roleFromTable != null) {
        _setRoleCache(roleFromTable);
        print('ROLE LOAD: loaded role=${roleFromTable.value} from users table');
        return;
      }

      final UserRole? roleFromMetadata = _readRoleFromCurrentUserMetadata();
      if (roleFromMetadata != null) {
        _setRoleCache(roleFromMetadata);
        print('ROLE LOAD: fallback to metadata role=${roleFromMetadata.value}');
        return;
      }

      print('ROLE LOAD: role is still null after users lookup');
    } on PostgrestException catch (error) {
      print('ROLE LOAD ERROR: ${error.message}');
    } catch (error) {
      print('ROLE LOAD ERROR: $error');
    }
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
        await _persistUserRoleSilently(
          userId: user.id,
          role: roleFromMetadata,
          email: user.email,
        );
        _setRoleCache(roleFromMetadata);
        return roleFromMetadata;
      }

      const UserRole fallbackRole = UserRole.client;
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
    final String? userId = currentUser?.id;
    if (userId == null) {
      throw AuthFailure('Unauthenticated');
    }

    try {
      final String normalizedGoal = goal.trim();
      final List<String> normalizedDifficulties =
          (difficulties ?? <String>[])
              .map((String item) => item.trim())
              .where((String item) => item.isNotEmpty)
              .toList();

      final bool isCompleted =
          normalizedGoal.isNotEmpty &&
          currentWeightKg != null &&
          currentWeightKg > 0 &&
          targetWeightKg != null &&
          targetWeightKg > 0 &&
          heightCm != null &&
          heightCm > 0 &&
          normalizedDifficulties.isNotEmpty;

      final Map<String, dynamic> data = <String, dynamic>{
        'onboarding_completed': isCompleted,
      };

      if (normalizedGoal.isNotEmpty) {
        data['onboarding_goal'] = normalizedGoal;
      }

      if (currentWeightKg != null) {
        data['onboarding_current_weight_kg'] = currentWeightKg;
      }
      if (targetWeightKg != null) {
        data['onboarding_target_weight_kg'] = targetWeightKg;
      }
      if (heightCm != null) {
        data['onboarding_height_cm'] = heightCm;
      }
      if (normalizedDifficulties.isNotEmpty) {
        data['onboarding_difficulties'] = normalizedDifficulties;
      }

      await _persistOnboardingDataToUsersTable(
        userId: userId,
        onboardingCompleted: isCompleted,
        onboardingGoal: normalizedGoal.isEmpty ? null : normalizedGoal,
        currentWeightKg: currentWeightKg,
        targetWeightKg: targetWeightKg,
        heightCm: heightCm,
        difficulties: normalizedDifficulties,
      );

      await _client.auth.updateUser(
        UserAttributes(
          data: data,
        ),
      );
      _cachedOnboardingCompleted = isCompleted;
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (_) {
      throw AuthFailure('Network error. Please try again.');
    }
  }

  Future<void> _persistOnboardingDataToUsersTable({
    required String userId,
    required bool onboardingCompleted,
    String? onboardingGoal,
    double? currentWeightKg,
    double? targetWeightKg,
    int? heightCm,
    required List<String> difficulties,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'id': userId,
      'onboarding_completed': onboardingCompleted,
      'onboarding_goal': onboardingGoal,
      'onboarding_current_weight_kg': currentWeightKg,
      'onboarding_target_weight_kg': targetWeightKg,
      'onboarding_height_cm': heightCm,
      'onboarding_difficulties': difficulties,
    };

    await _client.from('users').upsert(payload, onConflict: 'id');
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
        explicitEmail: normalizedEmail,
        persistFallbackRoleToUsersTable: true,
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
        explicitEmail: normalizedEmail,
        persistFallbackRoleToUsersTable: false,
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
    final bool flag;
    if (raw is bool) {
      flag = raw;
    } else if (raw is String) {
      flag = raw.toLowerCase() == 'true';
    } else {
      flag = false;
    }

    if (!flag) {
      return false;
    }

    return _hasRequiredOnboardingData(currentUser?.userMetadata);
  }

  bool _hasRequiredOnboardingData(Map<String, dynamic>? metadata) {
    if (metadata == null) {
      return false;
    }

    final String? goal = metadata['onboarding_goal'] as String?;
    final num? currentWeight = metadata['onboarding_current_weight_kg'] as num?;
    final num? targetWeight = metadata['onboarding_target_weight_kg'] as num?;
    final num? height = metadata['onboarding_height_cm'] as num?;
    final List<dynamic>? difficulties = metadata['onboarding_difficulties'] as List<dynamic>?;

    return goal != null &&
        goal.trim().isNotEmpty &&
        currentWeight != null &&
        currentWeight > 0 &&
        targetWeight != null &&
        targetWeight > 0 &&
        height != null &&
        height > 0 &&
        difficulties != null &&
        difficulties.any((dynamic item) => item is String && item.trim().isNotEmpty);
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
    String? explicitEmail,
    required bool persistFallbackRoleToUsersTable,
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
        await _persistUserRoleSilently(
          userId: userId,
          role: roleFromMetadata,
          email: explicitEmail,
        );
      }
      _setRoleCache(roleFromMetadata);
      return roleFromMetadata;
    }

    if (persistFallbackRoleToUsersTable && userId != null) {
      await _persistUserRoleSilently(
        userId: userId,
        role: fallbackRole,
        email: explicitEmail,
      );
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
    String? email,
  }) async {
    try {
      final String? resolvedEmail = _resolveEmailForUsersTable(email: email);
      if (resolvedEmail == null) {
        await _client
            .from('users')
            .update(<String, dynamic>{'role': role.value})
            .eq('id', userId);
        return;
      }

      await _client.from('users').upsert(
        <String, dynamic>{
          'id': userId,
          'email': resolvedEmail,
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

  String? _resolveEmailForUsersTable({String? email}) {
    final String? raw = email ?? currentUser?.email;
    if (raw == null) {
      return null;
    }

    final String normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
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

