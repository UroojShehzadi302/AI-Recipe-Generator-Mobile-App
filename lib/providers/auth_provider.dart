// Presentation-layer state holder for the AUTH slice.
//
// A [ChangeNotifier] the UI listens to. It drives [AuthRepository], exposes a
// simple [AuthStatus] state machine plus the current [UserModel] and an
// optional user-facing [errorMessage], and never throws to the UI — repository
// [Failure]s are caught and surfaced as state.

import 'package:flutter/foundation.dart';

import '../core/error/failure.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

/// High-level authentication state for the UI to render against.
enum AuthStatus {
  /// No operation in flight and no user signed in.
  idle,

  /// An auth operation is in progress.
  loading,

  /// A user is signed in; see [AuthProvider.user].
  authenticated,

  /// The last operation failed; see [AuthProvider.errorMessage].
  error,
}

/// Exposes authentication actions and state to the widget tree.
class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.idle;
  UserModel? _user;
  String? _errorMessage;

  /// Creates an [AuthProvider] backed by [repository].
  AuthProvider(AuthRepository repository) : _repository = repository;

  /// The current auth state.
  AuthStatus get status => _status;

  /// The signed-in user, or `null` when not authenticated.
  UserModel? get user => _user;

  /// A user-friendly message describing the last failure, or `null`.
  String? get errorMessage => _errorMessage;

  /// The current signed-in user's uid, or null when signed out. Used to scope
  /// per-user data (favorites, saved recipes, chat).
  String? get uid => _repository.currentUid;

  /// Signs in with email/password.
  ///
  /// Returns `true` on success (state becomes [AuthStatus.authenticated]),
  /// `false` on failure (state becomes [AuthStatus.error]).
  Future<bool> signIn(String email, String password) {
    return _run(() => _repository.signIn(email, password));
  }

  /// Registers a new email/password account.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> register(String name, String email, String password) {
    return _run(() => _repository.register(name, email, password));
  }

  /// Sends a password-reset email.
  ///
  /// On failure, sets [AuthStatus.error] and [errorMessage].
  Future<void> sendPasswordReset(String email) async {
    _setLoading();
    try {
      await _repository.sendPasswordReset(email);
      // A password reset does not change the signed-in state; return to a
      // neutral state, preserving any existing authenticated user.
      _status =
          _user != null ? AuthStatus.authenticated : AuthStatus.idle;
      _errorMessage = null;
    } on Failure catch (f) {
      _setError(f.message);
    } catch (e) {
      _setError('Something went wrong. Please try again.');
    }
    notifyListeners();
  }

  /// Google sign-in entry point.
  ///
  /// Currently unimplemented (wired in M2). Surfaces the resulting error as
  /// state rather than throwing to the UI.
  Future<void> signInWithGoogle() async {
    _setLoading();
    try {
      _user = await _repository.signInWithGoogle();
      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } on Failure catch (f) {
      _setError(f.message);
    } catch (e) {
      _setError('Google sign-in is not available yet.');
    }
    notifyListeners();
  }

  /// Signs the current user out and returns to [AuthStatus.idle].
  Future<void> signOut() async {
    _setLoading();
    try {
      await _repository.signOut();
      _user = null;
      _status = AuthStatus.idle;
      _errorMessage = null;
    } on Failure catch (f) {
      _setError(f.message);
    } catch (e) {
      _setError('Something went wrong. Please try again.');
    }
    notifyListeners();
  }

  /// App-launch gate: reports whether a session already exists.
  ///
  /// Called from the Splash screen to decide between Home and Login. On an
  /// existing session the status becomes [AuthStatus.authenticated] (the full
  /// [UserModel] is loaded lazily by the first screen that needs it).
  Future<bool> restoreSession() async {
    try {
      final bool hasSession = await _repository.hasActiveSession();
      if (hasSession) {
        _user = await _repository.loadCurrentUser();
        _status = AuthStatus.authenticated;
        notifyListeners();
      }
      return hasSession;
    } catch (_) {
      return false;
    }
  }

  /// Clears any error state, returning to a neutral status.
  void clearError() {
    if (_status == AuthStatus.error) {
      _status =
          _user != null ? AuthStatus.authenticated : AuthStatus.idle;
    }
    _errorMessage = null;
    notifyListeners();
  }

  /// Shared runner for operations that resolve to a [UserModel].
  Future<bool> _run(Future<UserModel> Function() action) async {
    _setLoading();
    notifyListeners();
    try {
      _user = await action();
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on Failure catch (f) {
      _setError(f.message);
      notifyListeners();
      return false;
    } catch (e) {
      _setError('Something went wrong. Please try again.');
      notifyListeners();
      return false;
    }
  }

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
  }
}
