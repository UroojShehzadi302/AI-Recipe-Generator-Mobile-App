/// Domain-level failure types for the AI Recipe Generator app.
///
/// These are plain, package-free Dart classes used to represent errors as
/// values (rather than thrown exceptions) as they bubble up from the data /
/// repository layer to the UI. Each carries a human-friendly [Failure.message]
/// that is safe to display to the user.
///
/// Example:
/// ```dart
/// Failure result = const NetworkFailure();
/// showSnackBar(result.message);
/// ```
library;

/// Base type for all recoverable failures in the app.
///
/// Modeled as a "sealed-style" hierarchy: pattern-match on the concrete
/// subtype when you need to react differently per category, or just read
/// [message] when you only need to show text.
///
/// ```dart
/// final Failure f = someRepositoryCall();
/// switch (f) {
///   case NetworkFailure():
///     retry();
///   default:
///     showError(f.message);
/// }
/// ```
class Failure {
  /// A user-friendly description of what went wrong.
  final String message;

  /// Creates a failure with the given [message].
  const Failure(this.message);

  @override
  String toString() => '$runtimeType(message: $message)';
}

/// Connectivity / transport problems (no internet, timeouts at the socket
/// level, DNS failures, etc.).
class NetworkFailure extends Failure {
  /// Creates a [NetworkFailure] with an optional custom [message].
  const NetworkFailure([
    super.message = 'No internet connection. Please check your network.',
  ]);
}

/// Authentication / authorization problems (sign-in, sign-up, tokens, etc.).
class AuthFailure extends Failure {
  /// Creates an [AuthFailure] with an optional custom [message].
  const AuthFailure([
    super.message = 'Authentication failed. Please try again.',
  ]);
}

/// Failures originating from the AI / generation service (Gemini, Cloud
/// Functions wrapping the model, quota limits, blocked content, etc.).
class AiFailure extends Failure {
  /// Creates an [AiFailure] with an optional custom [message].
  const AiFailure([
    super.message = 'The AI service is unavailable right now. Please try again.',
  ]);
}

/// Failures from Cloud Firestore reads/writes (permissions, unavailable,
/// document not found, etc.).
class FirestoreFailure extends Failure {
  /// Creates a [FirestoreFailure] with an optional custom [message].
  const FirestoreFailure([
    super.message = 'Could not access your data. Please try again.',
  ]);
}

/// Input validation problems surfaced as a failure value (as opposed to an
/// inline form validator message).
class ValidationFailure extends Failure {
  /// Creates a [ValidationFailure] with an optional custom [message].
  const ValidationFailure([
    super.message = 'Some of the information provided is invalid.',
  ]);
}

/// Catch-all for anything not covered by a more specific failure type.
class UnknownFailure extends Failure {
  /// Creates an [UnknownFailure] with an optional custom [message].
  const UnknownFailure([
    super.message = 'Something went wrong. Please try again.',
  ]);
}
