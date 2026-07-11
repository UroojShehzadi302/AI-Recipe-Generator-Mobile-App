/// Form-field validators for the AI Recipe Generator app.
///
/// Every method is a `static` function returning a `String?`:
/// * `null`   -> the input is **valid**.
/// * `String` -> the input is **invalid**; the returned text is a
///   human-friendly message suitable for display beneath a `TextFormField`.
///
/// This signature matches Flutter's `FormFieldValidator<String>`, so the
/// methods can be passed directly to a `TextFormField`'s `validator`:
///
/// ```dart
/// TextFormField(
///   validator: Validators.email,
/// );
///
/// TextFormField(
///   validator: (value) => Validators.confirmPassword(value, _passwordCtrl.text),
/// );
/// ```
///
/// Inputs are trimmed before validation so that leading/trailing whitespace
/// never produces a false "valid" result (e.g. a password of only spaces).
library;

/// A collection of pure, null-safe validation helpers.
///
/// The class only exposes `static` members and is not meant to be
/// instantiated.
class Validators {
  const Validators._();

  /// Regular expression used by [email].
  ///
  /// This is a pragmatic ("RFC-ish") pattern: it accepts the vast majority of
  /// real-world addresses while rejecting obvious mistakes. It intentionally
  /// does not attempt full RFC 5322 compliance, which is impractical for form
  /// validation.
  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$",
  );

  /// Validates an email address.
  ///
  /// Rules:
  /// * Required (must not be empty after trimming).
  /// * Must match a standard email shape, e.g. `name@example.com`.
  ///
  /// ```dart
  /// Validators.email('me@example.com'); // null (valid)
  /// Validators.email('');               // 'Email is required'
  /// Validators.email('not-an-email');   // 'Enter a valid email address'
  /// ```
  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) {
      return 'Email is required';
    }
    if (!_emailRegExp.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Minimum number of characters required by [password].
  static const int passwordMinLength = 6;

  /// Validates a password.
  ///
  /// Rules:
  /// * Required (must not be empty after trimming).
  /// * Must be at least [passwordMinLength] characters long.
  ///
  /// ```dart
  /// Validators.password('secret123'); // null (valid)
  /// Validators.password('');          // 'Password is required'
  /// Validators.password('123');       // 'Password must be at least 6 characters'
  /// ```
  static String? password(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < passwordMinLength) {
      return 'Password must be at least $passwordMinLength characters';
    }
    return null;
  }

  /// Validates a password confirmation field against the [original] password.
  ///
  /// Rules:
  /// * Required (must not be empty after trimming).
  /// * Must exactly match [original] (compared after trimming both values).
  ///
  /// ```dart
  /// Validators.confirmPassword('abcdef', 'abcdef'); // null (valid)
  /// Validators.confirmPassword('', 'abcdef');       // 'Please confirm your password'
  /// Validators.confirmPassword('abcdeX', 'abcdef'); // 'Passwords do not match'
  /// ```
  static String? confirmPassword(String? v, String? original) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != (original?.trim() ?? '')) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Minimum number of characters required by [name].
  static const int nameMinLength = 2;

  /// Validates a display / full name.
  ///
  /// Rules:
  /// * Required (must not be empty after trimming).
  /// * Must be at least [nameMinLength] characters long.
  ///
  /// ```dart
  /// Validators.name('Ada');  // null (valid)
  /// Validators.name('');     // 'Name is required'
  /// Validators.name('A');    // 'Name must be at least 2 characters'
  /// ```
  static String? name(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) {
      return 'Name is required';
    }
    if (value.length < nameMinLength) {
      return 'Name must be at least $nameMinLength characters';
    }
    return null;
  }

  /// Validates that an arbitrary field is non-empty after trimming.
  ///
  /// Pass [fieldName] to customize the message (it is capitalized as provided).
  ///
  /// ```dart
  /// Validators.requiredField('hello');                 // null (valid)
  /// Validators.requiredField('   ');                   // 'This field is required'
  /// Validators.requiredField('', 'City');              // 'City is required'
  /// ```
  static String? requiredField(String? v, [String fieldName = 'This field']) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Minimum trimmed length allowed by [aiPrompt].
  static const int aiPromptMinLength = 3;

  /// Maximum trimmed length allowed by [aiPrompt].
  static const int aiPromptMaxLength = 500;

  /// Validates a user-supplied AI prompt (e.g. the recipe request text).
  ///
  /// Rules:
  /// * Required (must not be empty after trimming).
  /// * Trimmed length must be between [aiPromptMinLength] and
  ///   [aiPromptMaxLength] characters, inclusive.
  ///
  /// ```dart
  /// Validators.aiPrompt('Vegan pasta for two'); // null (valid)
  /// Validators.aiPrompt('');                    // 'Please enter a prompt'
  /// Validators.aiPrompt('hi');                  // 'Prompt must be at least 3 characters'
  /// Validators.aiPrompt('x' * 501);             // 'Prompt must be 500 characters or fewer'
  /// ```
  static String? aiPrompt(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) {
      return 'Please enter a prompt';
    }
    if (value.length < aiPromptMinLength) {
      return 'Prompt must be at least $aiPromptMinLength characters';
    }
    if (value.length > aiPromptMaxLength) {
      return 'Prompt must be $aiPromptMaxLength characters or fewer';
    }
    return null;
  }
}
