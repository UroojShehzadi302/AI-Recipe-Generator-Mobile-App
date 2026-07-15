// Thin wrapper around [FirebaseAuth] for the AUTH vertical slice.
//
// This service is a *pure pass-through* over `FirebaseAuth.instance`: it does
// not map errors, translate codes, or touch Firestore. Error handling and
// domain mapping live one layer up in `AuthRepository`. Keeping this layer
// dumb makes it trivial to mock in tests and keeps Firebase specifics
// isolated to a single, easily-swappable seam.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// OAuth 2.0 **Web** client ID from the Firebase console
/// (Authentication → Sign-in method → Google → *Web SDK configuration*).
///
/// On Android, `google_sign_in` v7 needs this to mint a Firebase-compatible ID
/// token, **unless** a `google-services.json` that contains a web OAuth client
/// is present in the Android project — that file makes the Gradle plugin emit a
/// `default_web_client_id` resource which the plugin reads automatically. Leave
/// this empty to rely on that resource; set it to override.
///
/// Until the owner enables the Google provider in the console (and adds the
/// debug SHA-1), Google sign-in will surface a configuration error on-device.
const String kGoogleServerClientId = '';

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

  /// Signs the current user out of both Firebase and Google.
  Future<void> signOut() async {
    // Best-effort Google sign-out so the account chooser reappears next time.
    // Never let a Google disconnect failure block the Firebase sign-out.
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Ignore — the user may never have signed in with Google.
    }
    await _auth.signOut();
  }

  /// Latch so the global [GoogleSignIn] singleton is initialized exactly once.
  static bool _googleInitialized = false;

  /// Runs the interactive Google sign-in flow and exchanges the resulting
  /// Google ID token for a Firebase [UserCredential].
  ///
  /// Uses `google_sign_in` v7: [GoogleSignIn.initialize] (once) then
  /// [GoogleSignIn.authenticate]. Propagates:
  /// - a [GoogleSignInException] (e.g. `code == canceled`) when the user
  ///   dismisses the sheet or the platform is misconfigured, and
  /// - a [FirebaseAuthException] when Firebase rejects the credential
  ///   (e.g. `account-exists-with-different-credential`).
  ///
  /// Both are mapped to domain failures one layer up in `AuthRepository`.
  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn.instance;

    if (!_googleInitialized) {
      await googleSignIn.initialize(
        serverClientId:
            kGoogleServerClientId.isEmpty ? null : kGoogleServerClientId,
      );
      _googleInitialized = true;
    }

    if (!googleSignIn.supportsAuthenticate()) {
      throw UnsupportedError(
        'Google sign-in via authenticate() is not supported on this platform.',
      );
    }

    final GoogleSignInAccount account = await googleSignIn.authenticate();
    final String? idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google did not return an ID token. Check the Google '
            'provider configuration (Web client ID / SHA-1).',
      );
    }

    final OAuthCredential credential =
        GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }
}
