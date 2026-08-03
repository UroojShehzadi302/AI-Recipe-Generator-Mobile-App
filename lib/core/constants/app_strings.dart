/// User-facing copy for CookMate AI.
///
/// Centralizing strings keeps wording consistent, makes copy edits trivial, and
/// is the prerequisite for the future "Language" setting (localization).
class AppStrings {
  AppStrings._();

  // ---- Brand ----
  static const String appName = 'CookMate AI';
  static const String tagline = 'Your Smart AI Cooking Companion';
  static const String splashTagline = tagline;

  // ---- Auth ----
  static const String welcomeBack = 'Welcome Back';
  static const String loginSubtitle = 'Sign in to continue cooking with AI';
  static const String createAccount = 'Create Account';
  static const String registerSubtitle =
      'Join CookMate AI and start cooking smarter';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String rememberMe = 'Remember Me';
  static const String forgotPassword = 'Forgot Password?';
  static const String signIn = 'Sign In';
  static const String or = 'OR';
  static const String continueWithGoogle = 'Continue with Google';
  static const String noAccount = "Don't have an account?";
  static const String signUp = 'Sign Up';
  static const String haveAccount = 'Already have an account?';

  // ---- Home ----
  static const String homeWelcome = 'Welcome';
  static const String homePrompt =
      'Enter your ingredients and let AI create a delicious recipe for you.';
  static const String ingredientsHint = 'Example: Chicken, Rice, Tomato';
  static const String generateRecipe = 'Generate Recipe';

  // ---- Tabs ----
  static const String tabHome = 'Home';
  static const String tabFavorites = 'Favorites';
  static const String tabAi = 'Ask AI';
  static const String tabSaved = 'Saved';
  static const String tabProfile = 'Profile';

  // ---- Profile ----
  static const String profile = 'Profile';
  static const String myFavorites = 'My Favorites';
  static const String savedRecipes = 'Saved Recipes';
  static const String usageHistory = 'Usage History';
  static const String editProfile = 'Edit Profile';
  static const String changePassword = 'Change Password';
  static const String about = 'About';
  static const String deleteAccount = 'Delete Account';
  static const String logOut = 'Log Out';
  static const String aboutBody =
      'Discover, generate, and save recipes with an AI cooking assistant.';

  // ---- Saved ----
  static const String searchSavedHint = 'Search saved recipes';
  static const String sortBy = 'Sort by';
  static const String sortNewest = 'Newest first';
  static const String sortOldest = 'Oldest first';
  static const String sortTitleAz = 'Title (A–Z)';
  static const String sortTitleZa = 'Title (Z–A)';
  static const String noSavedRecipes = 'No saved recipes';
  static const String noSavedRecipesBody =
      'Recipes you generate with AI and save will appear here.';
  static const String noSavedMatches = 'No matches';
  static const String noSavedMatchesBody =
      'No saved recipe matches that search. Try a different word.';

  // ---- History ----
  static const String historyTitle = 'Usage History';
  static const String historyEmpty = 'Nothing here yet';
  static const String historyEmptyBody =
      'Recipes you generate with AI will be listed here so you can reopen them '
      'any time.';
  static const String statusSaved = 'Saved';
  static const String statusGenerated = 'Generated';

  // ---- Credit usage ----
  static const String usageTitle = 'Credit Usage';
  static const String usageMenuLabel = 'Credit Usage';
  static const String usageMenuSubtitle = 'See how many AI tokens you have used';
  static const String usageEmpty = 'No AI usage yet';
  static const String usageEmptyBody =
      'Generate a recipe or chat with the assistant, and the tokens each '
      'request uses will be tracked here.';
  static const String usageTotalLabel = 'Total tokens used';
  static const String usageInputLabel = 'Input';
  static const String usageOutputLabel = 'Output';
  static const String usageRequestsLabel = 'Requests';
  static const String usageBreakdownTitle = 'Where they went';
  static const String usageRecentTitle = 'Recent activity';
  static const String usageClear = 'Clear usage log';
  static const String usageClearConfirmTitle = 'Clear usage log?';
  static const String usageClearConfirmBody =
      'Your recorded token usage will be permanently deleted. This does not '
      'affect your recipes or chats.';
  /// Shown under the headline number so the figure is not mistaken for money.
  static const String usageDisclaimer =
      'Tokens are how AI requests are measured. Longer prompts and longer '
      'replies use more. Counts come from the AI provider and are for your '
      'reference only.';

  // ---- Generic actions ----
  static const String cancel = 'Cancel';
  static const String close = 'Close';
  static const String delete = 'Delete';
  static const String retry = 'Retry';
  static const String save = 'Save';
  static const String remove = 'Remove';
  static const String clear = 'Clear';
}
