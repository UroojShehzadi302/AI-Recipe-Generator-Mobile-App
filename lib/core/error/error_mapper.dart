/// Translates raw error codes/objects into friendly, user-facing messages.
///
/// The codes handled here typically originate from **Firebase Auth**
/// (`FirebaseAuthException.code`) and **Cloud Functions** callable errors
/// (`FirebaseFunctionsException.code`) that are caught in the repository /
/// service layer. To keep this file dependency-free (Firebase is not
/// referenced directly), callers should extract the plain `code` string at the
/// call site and pass it in:
///
/// ```dart
/// try {
///   await auth.signInWithEmailAndPassword(email: e, password: p);
/// } on FirebaseAuthException catch (e) {
///   throw AuthFailure(ErrorMapper.authMessage(e.code));
/// }
/// ```
///
/// All returned strings are safe to display directly to users; raw error
/// details and stack traces are never surfaced.
library;

/// Maps low-level error codes/objects to human-friendly messages.
///
/// Exposes only `static` members; not intended to be instantiated.
class ErrorMapper {
  const ErrorMapper._();

  /// Default message used when a code is unrecognized.
  static const String _fallback = 'Something went wrong. Please try again.';

  /// Translates a Firebase Auth error [code] into a friendly message.
  ///
  /// Recognized codes include `invalid-email`, `user-not-found`,
  /// `wrong-password`, `email-already-in-use`, `weak-password`,
  /// `network-request-failed`, `user-disabled`, `too-many-requests`, and
  /// `account-exists-with-different-credential`. Unknown codes fall back to a
  /// generic message.
  ///
  /// ```dart
  /// ErrorMapper.authMessage('wrong-password'); // 'Incorrect password. Please try again.'
  /// ErrorMapper.authMessage('mystery-code');   // 'Something went wrong. Please try again.'
  /// ```
  static String authMessage(String code) {
    switch (code.trim()) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Your password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support for help.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'operation-not-allowed':
      case 'admin-restricted-operation':
      case 'configuration-not-found':
        return 'Email sign-up is not enabled for this app yet. '
            'Enable Email/Password in the Firebase console.';
      default:
        return _fallback;
    }
  }

  /// Translates an AI / Cloud Functions error [code] into a friendly message.
  ///
  /// Recognized codes include `deadline-exceeded`/`timeout`,
  /// `resource-exhausted`, `invalid-response`, `unavailable`, and `blocked`.
  /// Unknown codes fall back to a generic message.
  ///
  /// ```dart
  /// ErrorMapper.aiMessage('resource-exhausted'); // "You've reached today's AI limit. Try again later."
  /// ```
  static String aiMessage(String code) {
    switch (code.trim()) {
      case 'deadline-exceeded':
      case 'timeout':
        return 'The AI took too long to respond. Please try again.';
      case 'resource-exhausted':
        return "You've reached today's AI limit. Try again later.";
      case 'invalid-response':
        return 'The AI returned an unexpected result. Please try again.';
      case 'unavailable':
        return 'The AI service is temporarily unavailable. Please try again shortly.';
      case 'blocked':
        return 'Your request was blocked for safety reasons. Try rephrasing it.';
      default:
        return _fallback;
    }
  }

  /// Produces a safe, friendly fallback message for any [error] object.
  ///
  /// Use this as a last resort when no specific code is available. The raw
  /// error/stack trace is never exposed to the user.
  ///
  /// ```dart
  /// } catch (e) {
  ///   showError(ErrorMapper.generic(e));
  /// }
  /// ```
  static String generic(Object error) {
    return _fallback;
  }
}
