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
/// Set explicitly rather than left empty. Relying on the generated resource is
/// the documented happy path, but it fails silently when it doesn't materialise
/// — `authenticate()` returns an account with a **null `idToken`**, which
/// surfaces to the user as a generic "something went wrong" with nothing in the
/// logs pointing at OAuth config. Naming it here removes that failure mode.
///
/// This is the **web** client (`client_type: 3`) from `google-services.json` —
/// NOT the Android client (`client_type: 1`). Using the Android one yields the
/// same null-token failure. It is project-wide, so it survived the
/// com.urooj.cookmate rename; re-check it only if the Firebase project changes.
const String kGoogleServerClientId =
    '845885648760-hl2qrl11b3i1hclclrk7kdcitha1a93u.apps.googleusercontent.com';

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

  /// Re-fetches the signed-in user from the server.
  ///
  /// `emailVerified` is baked into the cached ID token, so it stays stale after
  /// the user clicks the link in their inbox until the token is refreshed. This
  /// is what makes "I verified, why is it still asking me?" go away.
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  /// Whether the signed-in user has an email/password credential.
  ///
  /// Drives how re-authentication is done before a destructive action:
  /// password-backed accounts prompt for the password, Google-only accounts
  /// re-run the Google flow.
  bool get hasPasswordProvider =>
      _auth.currentUser?.providerData
          .any((UserInfo p) => p.providerId == 'password') ??
      false;

  /// Re-authenticates a password-backed account with [password].
  ///
  /// Firebase requires a recent login before deleting an account or changing a
  /// password. Throws a [FirebaseAuthException] (`wrong-password`) on mismatch.
  Future<void> reauthenticateWithPassword(String password) async {
    final User? user = _auth.currentUser;
    final String? email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in email account to re-authenticate.',
      );
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  /// Re-authenticates a Google-backed account by re-running the Google flow.
  Future<void> reauthenticateWithGoogle() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in account to re-authenticate.',
      );
    }

    final GoogleSignIn googleSignIn = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await googleSignIn.initialize(
        serverClientId:
            kGoogleServerClientId.isEmpty ? null : kGoogleServerClientId,
      );
      _googleInitialized = true;
    }

    final GoogleSignInAccount account = await googleSignIn.authenticate();
    final String? idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google did not return an ID token.',
      );
    }
    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  /// Updates the signed-in user's password. Requires a recent login.
  Future<void> updatePassword(String newPassword) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in account.',
      );
    }
    await user.updatePassword(newPassword);
  }

  /// Permanently deletes the signed-in Firebase Auth account.
  ///
  /// Throws `requires-recent-login` when the session is stale — callers must
  /// re-authenticate first. Deleting the user's Firestore data is the caller's
  /// job (see `AuthRepository.deleteAccount`).
  Future<void> deleteAccount() async {
    final User? user = _auth.currentUser;
    if (user == null) return;
    await user.delete();
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
