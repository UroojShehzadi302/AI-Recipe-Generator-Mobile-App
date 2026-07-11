// Thin wrapper around [FirebaseAuth] for the AUTH vertical slice.
//
// This service is a *pure pass-through* over `FirebaseAuth.instance`: it does
// not map errors, translate codes, or touch Firestore. Error handling and
// domain mapping live one layer up in `AuthRepository`. Keeping this layer
// dumb makes it trivial to mock in tests and keeps Firebase specifics
// isolated to a single, easily-swappable seam.

import 'package:firebase_auth/firebase_auth.dart';

/// A minimal, testable facade over [FirebaseAuth].
///
/// Every method forwards directly to the underlying [FirebaseAuth] instance
/// and lets any [FirebaseAuthException] propagate unchanged for the caller to
/// map into a domain [Failure].
class AuthService {
  final FirebaseAuth? _injected;

  /// Creates an [AuthService].
  ///
  /// [firebaseAuth] is injectable for testing. The default
  /// `FirebaseAuth.instance` is resolved lazily on first use, so constructing
  /// this service never requires Firebase to be initialized.
  AuthService({FirebaseAuth? firebaseAuth}) : _injected = firebaseAuth;

  FirebaseAuth get _auth => _injected ?? FirebaseAuth.instance;

  /// Emits the current [User] on subscription and on every auth state change
  /// (sign-in, sign-out, token refresh). Emits `null` when signed out.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// The currently signed-in [User], or `null` if none.
  User? get currentUser => _auth.currentUser;

  /// Signs in with an email/password credential.
  ///
  /// Throws a [FirebaseAuthException] on failure (unmapped).
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Creates a new account with an email/password credential.
  ///
  /// Throws a [FirebaseAuthException] on failure (unmapped).
  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sends a password-reset email to [email].
  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Sends a verification email to the current user, if one is signed in.
  ///
  /// No-op when there is no signed-in user.
  Future<void> sendEmailVerification() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      await user.sendEmailVerification();
    }
  }

  /// Signs the current user out.
  Future<void> signOut() => _auth.signOut();

  /// Google sign-in placeholder.
  ///
  /// The `google_sign_in` package is not yet installed; this path is wired up
  /// in M2. Calling it now always throws.
  Future<UserCredential> signInWithGoogle() {
    throw UnimplementedError(
      'Google sign-in is wired in M2 once google_sign_in is added',
    );
  }
}
