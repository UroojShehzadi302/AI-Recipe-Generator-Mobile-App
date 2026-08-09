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

  // ---- Settings ----
  static const String settings = 'Settings';
  static const String settingsPreferences = 'Preferences';
  static const String settingsAboutGroup = 'About';
  static const String settingsAccountGroup = 'Account';
  static const String notifications = 'Notifications';

  /// Deliberately precise. The app is receive-only and cannot unsubscribe from
  /// FCM, so the switch controls the in-app inbox — claiming it stops every
  /// notification would be a lie the Android tray immediately exposes.
  static const String notificationsSubtitle =
      'Collect pushed messages in your in-app inbox and badge the bell. System '
      'tray notifications are controlled by your Android settings.';
  // Appearance / theme.
  static const String appearance = 'Appearance';
  static const String themeSystem = 'System';
  static const String themeLight = 'Light';
  static const String themeDark = 'Dark';
  static const String themeSystemSubtitle = 'Match my device';
  static const String themeLightSubtitle = 'Always light';
  static const String themeDarkSubtitle = 'Always dark';

  // Text size / accessibility.
  static const String textSize = 'Text Size';
  static const String textSizeSmall = 'Small';
  static const String textSizeMedium = 'Medium';
  static const String textSizeLarge = 'Large';

  /// The subtitles say what each step does *relative to the phone's own font
  /// setting*, because that is exactly what they do — this preference is
  /// applied on top of the system size, not instead of it. A user who has
  /// already enlarged text device-wide would otherwise reasonably read
  /// "Medium" as "shrink me back to normal".
  static const String textSizeSmallSubtitle = 'Slightly smaller than your '
      'device setting';
  static const String textSizeMediumSubtitle = 'Match your device setting';
  static const String textSizeLargeSubtitle = 'Easier to read';

  /// Shown under the picker title. Sets the expectation that a user already at
  /// their phone's maximum font size may see little change — the combined size
  /// is capped so the layout stays usable.
  static const String textSizeDialogNote =
      'Applied on top of your device font size.';

  static const String privacyPolicy = 'Privacy Policy';
  static const String termsOfService = 'Terms of Service';
  static const String aboutApp = 'About $appName';

  /// Shown when a link cannot be opened for the user (no `url_launcher`
  /// dependency in this build — see [privacyPolicyUrl]).
  static const String linkDialogBody =
      'Open this link in your browser:';
  static const String linkCopy = 'Copy link';
  static const String linkCopied = 'Link copied';

  // ---- External URLs ----
  // Served by GitHub Pages from `docs/` on the default branch. The pages live
  // in this repo (docs/privacy-policy.html, docs/terms.html) so the text and
  // the app ship together and cannot drift apart.
  //
  // ⚠️ OWNER: these resolve only once GitHub Pages is switched on —
  // repo → Settings → Pages → Source: "Deploy from a branch", branch `main`,
  // folder `/docs`. Play requires a REACHABLE Privacy Policy URL for any app
  // that collects an email address, so verify both open in a browser before
  // submitting the listing. If the repo is ever renamed or moved, these two
  // strings must move with it.
  static const String privacyPolicyUrl =
      'https://uroojshehzadi302.github.io/AI-Recipe-Generator-Mobile-App/privacy-policy.html';

  static const String termsUrl =
      'https://uroojshehzadi302.github.io/AI-Recipe-Generator-Mobile-App/terms.html';

  // ---- Share ----
  // Section labels for the plain-text recipe built by `RecipeShareText`.
  // These end up in someone else's messaging app, so they are written to read
  // as a message rather than as UI chrome.
  static const String share = 'Share';
  static const String shareUntitledRecipe = 'Untitled recipe';
  static const String shareTimeLabel = 'Time';
  static const String shareMinutesSuffix = 'min';
  static const String shareServesLabel = 'Serves';
  static const String shareCaloriesLabel = 'Calories';
  static const String shareIngredientsHeading = 'Ingredients';
  static const String shareInstructionsHeading = 'Instructions';

  /// Closing line on every shared recipe — what makes a forwarded message
  /// traceable back to the app.
  static const String shareAttribution = 'Shared from $appName — $tagline';

  /// Confirmation shown when the OS share sheet could not be opened and the
  /// recipe was put on the clipboard instead. Worded so the user knows exactly
  /// where the text went rather than assuming the share failed outright.
  static const String shareCopiedToClipboard = 'Recipe copied to clipboard';
  static const String shareFailed = 'Could not share this recipe';

  // ---- Offline / connectivity ----
  // Worded as an observation, not an accusation or an instruction. The app
  // cannot tell WHY the connection is gone (Wi-Fi off, no signal, DNS blocked),
  // so telling the user to "check your Wi-Fi" would be a guess.

  /// The persistent strip shown while the app has confirmed it is offline.
  static const String offlineBanner = "You're offline — some features are limited";

  /// Replaces a generic AI error when the failure happened while offline.
  /// Says only what is actually known: the request needed a connection and
  /// there wasn't one.
  static const String offlineAiError =
      'No internet connection. Reconnect to use AI features.';

  // ---- Generic actions ----
  static const String cancel = 'Cancel';
  static const String close = 'Close';
  static const String delete = 'Delete';
  static const String retry = 'Retry';
  static const String save = 'Save';
  static const String remove = 'Remove';
  static const String clear = 'Clear';
}
