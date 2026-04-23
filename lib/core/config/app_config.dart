import 'dart:convert';

import 'env_keys.dart';

class AppConfig {
  AppConfig._();

  // =========================
  // DEV FALLBACK VALUES
  // =========================

  static const String _defaultSupabaseUrl =
      'https://hxgynzqihkwirkdkbyhu.supabase.co';

  static const String _defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh4Z3luenFpaGt3aXJrZGtieWh1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY4NzI0MjcsImV4cCI6MjA5MjQ0ODQyN30.D8n7DbMbO93kFiP8Sjlz62iqhpwNK31un1KTgOhZUl0';

  // =========================
  // ENV VALUES (dart-define)
  // =========================

  static const String _supabaseUrl =
      String.fromEnvironment(EnvKeys.supabaseUrl);

  static const String _supabaseAnonKey =
      String.fromEnvironment(EnvKeys.supabaseAnonKey);

  // =========================
  // PUBLIC ACCESSORS
  // =========================

  static String get supabaseUrl =>
      _resolve(_supabaseUrl, _defaultSupabaseUrl, EnvKeys.supabaseUrl);

  static String get supabaseAnonKey =>
      _resolve(_supabaseAnonKey, _defaultSupabaseAnonKey, EnvKeys.supabaseAnonKey);

  // =========================
  // VALIDATION (SAFE)
  // =========================

  static void validate() {
    final String url = supabaseUrl;
    final String anonKey = supabaseAnonKey;

    _validateSupabaseUrl(url);
    _validateAnonKey(anonKey);
  }

  // =========================
  // CORE RESOLVER
  // =========================

  static String _resolve(
    String value,
    String fallback,
    String key,
  ) {
    if (value.isNotEmpty) return value;

    // DEV MODE fallback
    if (_isDevMode) return fallback;

    throw StateError('Missing required environment variable: $key');
  }

  static bool get _isDevMode {
    return const bool.fromEnvironment('dart.vm.product') == false;
  }

  static void _validateSupabaseUrl(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      throw StateError(
        'SUPABASE_URL has invalid format. Expected: https://<project-ref>.supabase.co',
      );
    }

    if (url.contains('/rest/v1')) {
      throw StateError(
        'SUPABASE_URL must not contain /rest/v1. Use the project URL only.',
      );
    }
  }

  static void _validateAnonKey(String key) {
    final List<String> parts = key.split('.');
    if (parts.length < 2) {
      throw StateError(
        'SUPABASE_ANON_KEY has invalid JWT format.',
      );
    }

    final Map<String, dynamic>? payload = _tryDecodeJwtPayload(parts[1]);
    if (payload == null) {
      return;
    }

    final String role = (payload['role'] ?? '').toString();
    if (role == 'service_role') {
      throw StateError(
        'SUPABASE_ANON_KEY must be anon key, not service_role.',
      );
    }
  }

  static Map<String, dynamic>? _tryDecodeJwtPayload(String payloadPart) {
    try {
      final String normalized = base64Url.normalize(payloadPart);
      final String decoded = utf8.decode(base64Url.decode(normalized));
      final Object? json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) {
        return json;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
