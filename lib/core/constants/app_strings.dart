/// User-facing copy for the AI Recipe Generator.
///
/// Centralizing strings keeps wording consistent, makes copy edits trivial, and
/// is the prerequisite for the future "Language" setting (localization). Only
/// strings already present in the app are captured here; more are added as
/// screens are built.
class AppStrings {
  AppStrings._();

  // App
  static const String appName = 'AI Recipe Generator';
  static const String splashTagline = 'Cooking with AI 🍳';

  // Login
  static const String welcomeBack = 'Welcome Back';
  static const String loginSubtitle = 'Sign in to continue cooking with AI';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String rememberMe = 'Remember Me';
  static const String forgotPassword = 'Forgot Password?';
  static const String signIn = 'SIGN IN';
  static const String or = 'OR';
  static const String continueWithGoogle = 'Continue with Google';
  static const String noAccount = "Don't have an account?";
  static const String signUp = 'Sign Up';

  // Home
  static const String homeWelcome = '🍽️ Welcome';
  static const String homePrompt =
      'Enter your ingredients and let AI create a delicious recipe for you.';
  static const String ingredientsHint = 'Example: Chicken, Rice, Tomato';
  static const String generateRecipe = 'Generate Recipe';
}
