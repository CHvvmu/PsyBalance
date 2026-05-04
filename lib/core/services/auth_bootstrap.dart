import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AuthBootstrap {
  AuthBootstrap._();

  static StreamSubscription<AuthState>? _subscription;
  static Completer<void>? _initialSessionCompleter;
  static Completer<void>? _pendingTransitionCompleter;
  static bool _initialSessionReady = false;

  static Future<void> ensureReady() async {
    _ensureListener();

    if (!_initialSessionReady) {
      _initialSessionCompleter ??= Completer<void>();
      await _initialSessionCompleter!.future;
    }

    final Completer<void>? pendingTransition = _pendingTransitionCompleter;
    if (pendingTransition != null && !pendingTransition.isCompleted) {
      await pendingTransition.future;
    }
  }

  static void beginPendingTransition() {
    _ensureListener();

    if (_pendingTransitionCompleter == null || _pendingTransitionCompleter!.isCompleted) {
      _pendingTransitionCompleter = Completer<void>();
    }
  }

  static void cancelPendingTransition() {
    _ensureListener();

    _completeCompleter(_pendingTransitionCompleter);
    _pendingTransitionCompleter = null;
  }

  static Future<T> safeQuery<T>(Future<T> Function(SupabaseClient client) query) async {
    await ensureReady();
    return query(SupabaseService.client);
  }

  static void _ensureListener() {
    _subscription ??= SupabaseService.client.auth.onAuthStateChange.listen(
      _handleAuthStateChange,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('AUTH BOOTSTRAP LISTENER ERROR: $error');
      },
    );
  }

  static void _handleAuthStateChange(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.initialSession:
        _initialSessionReady = true;
        _completeCompleter(_initialSessionCompleter);
        break;
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.signedOut:
        _completeCompleter(_pendingTransitionCompleter);
        _pendingTransitionCompleter = null;
        break;
      default:
        break;
    }
  }

  static void _completeCompleter(Completer<void>? completer) {
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}
