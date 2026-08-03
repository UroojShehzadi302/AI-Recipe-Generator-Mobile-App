/// Type-safe asset paths for the AI Recipe Generator.
///
/// Referencing assets through these constants avoids duplicated magic strings
/// (the logo and Google icon paths were previously repeated across screens),
/// which turn into runtime crashes if a file is renamed.
class AppAssets {
  AppAssets._();

  static const String logo = 'assets/images/logo.png';
  static const String googleIcon = 'assets/icons/google.png';
}
