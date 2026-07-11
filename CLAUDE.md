# AI Recipe Generator — Project Context

> Persistent context for this Flutter app. Read this first each session.
> Last updated: 2026-07-11.

## What this is
A production-intent **Flutter (Android-first) AI recipe app**: Firebase backend + Google Gemini (via Cloud Functions). Premium **warm-brown / cream** brand. Users register, browse recipes, generate recipes with AI, chat with an AI cooking assistant, favorite/save recipes, and manage a profile.

Design docs live in `documents/`: `prd.pdf`, `trd.pdf`, `afd.pdf`, `ui_ux design.pdf`, plus the authored `backend_architecture.md` (the real backend spec — the PDF named "backend artcitecture" is a mislabeled duplicate of the UI/UX brief), `refactoring_plan.md`, `completion_plan.md` (M1–M15 roadmap), and `project_status.md` (done/not-done tracker).

## Golden rules (do not violate)
1. **Design tokens only** — no hardcoded colors, font sizes, radii, or asset paths in screens/widgets. Use `AppColors`, `AppDimensions`, `AppTextStyles`, `AppShadows`, `AppDurations`, `AppAssets`, `AppStrings`.
2. **No business logic in widgets.** Flow is **Widget → Provider → Repository → Service (SDK)**. Widgets never touch `FirebaseAuth`/`Firestore`/`Functions` directly.
3. **Preserve branding** — warm brown `#8B5E3C`, cream `#F6F2EE`, the logo, and the Login design language. Don't restyle to a different look.
4. Use `withValues(alpha:)` (never deprecated `withOpacity`), wildcard params `(_, _, _)`, `const` where possible.
5. **After every change:** `flutter analyze` must stay at 0 errors/warnings (3 known `prefer_initializing_formals` info hints are accepted), and `flutter test` must pass.
6. State management is **Provider** (mandated by the docs).

## Tech stack
Flutter 3.x / Dart, Material 3, Provider, Firebase (Auth, Firestore, Storage-planned), Google Gemini (via Cloud Functions — planned). Fonts: Poppins via `google_fonts` (runtime fetch; bundling as assets is a TODO).

## Architecture / folders
```
lib/
  main.dart                      # bootstrap: Firebase.initializeApp + runApp
  firebase_options.dart          # generated (Android). apiKey is a public client id, not a secret
  app/app.dart                   # RecipeGeneratorApp: builds DI graph + MultiProvider + MaterialApp
  routes/app_routes.dart         # onGenerateRoute + route constants (typed args, e.g. Recipe)
  core/
    theme/    app_colors, app_dimensions, app_text_styles, app_durations, app_shadows, app_theme
    constants/ app_assets, app_strings, sample_recipes   # sample_recipes = placeholder data (TODO: real feed M5)
    utils/    validators
    error/    failure, error_mapper
    widgets/  primary_button, app_text_field, google_button, or_divider, section_title,
              loading_indicator, empty_state, app_error_view, profile_avatar,
              category_chip, recipe_card, ai_assistant_card
  models/       recipe_model (Recipe/Nutrition/Ingredient), user_model, chat_message (defensive fromJson)
  services/     auth_service, firestore_service, gemini_service   # thin SDK wrappers; Firebase resolved LAZILY
  repositories/ auth_repository, user_repository, recipe_repository, chat_repository
  providers/    auth_provider, recipe_provider, chat_provider     # ChangeNotifiers
  screens/      splash, login, register, forgot_password, main_shell, home,
                recipe_detail, favorites, saved, profile
test/           widget_test (foundation smoke), recipe_detail_test (render guard)
```
Services resolve `FirebaseAuth.instance` / `FirebaseFirestore.instance` **lazily** (getters, not constructors) so providers are constructible in unit tests without Firebase.

## Design tokens (values)
- Colors: `primary #8B5E3C`, `primaryDark #5E3D26`, `primarySoft #EDE3DA`, `secondary #D6A46D`, `background #F6F2EE`, `surface #FFFFFF`, `textPrimary #2E2E2E`, `textSecondary #7A7A7A`, `border #E0E0E0`, `success` soft green, `error` soft red.
- Radii: sm 12 / md 16 (buttons+fields) / lg 20 / xl 25 (cards). Button height 55. Field padding 18.
- Text: Poppins — heading 28/bold, title 20/w600, subtitle 14, body 16, button 16/bold, caption 12.

## Backend decisions (from backend_architecture.md — authoritative)
- **D1** AI tab = "AI Hub" with two modes (Generate + Chat).
- **D2** Favorite = bookmark any recipe; Saved = AI-generated recipes the user kept.
- **D3** Generated recipes are private (`users/{uid}/generatedRecipes`), not in global `/recipes`.
- **D4** Favorites store a **full embedded Recipe snapshot** (offline-safe, no dangling refs).
- **D5** Home reads a single cached `home_feed/{locale}` doc (built by a Function).
- **D6** Curated images = URLs; only avatars use Storage.
- **D7** **Gemini is called via a Cloud Function** (App Check + rate limits). The key never ships in the app. `gemini_service.dart` is a stub throwing `UnimplementedError` until wired.
- Firestore schema, complete `firestore.rules`, indexes, and Functions are specified in `backend_architecture.md` §6–§12.

## Build status (see project_status.md for detail)
- ✅ Foundation (tokens, theme, widgets, models, validators, error mapping)
- ✅ M1 Architecture (providers/repos/services/router/DI)
- ✅ M4 (partial): email register/login + **forgot password** work. Google Sign-In NOT done (needs `google_sign_in` pkg + SHA-1 in console).
- ✅ M5 Home (redesigned; **placeholder sample data** via `SampleRecipes`, images from TheMealDB CDN)
- ✅ M7 Recipe Detail (full page; a prior blank-body bug from a greedy `Center` in the bottom bar is fixed + guarded by test)
- ✅ M8 Favorites & Saved (real Firestore reads/writes; hearts on Home + Detail; Favorites/Saved tabs)
- ✅ Profile tab with working Logout; session-restore loads the user model
- ⛔ M3 Backend, M6 AI Generate, M9 AI Chat — BLOCKED on decisions below

## Firebase console state
- Project: `ai-recipe-generator-db27c` (treat as **dev**; prod not created yet).
- ✅ Email/Password auth enabled (the earlier `CONFIGURATION_NOT_FOUND` was this being off).
- ✅ Firestore created — region `asia-south1` (Mumbai), **test mode** rules (`allow read, write: if request.auth != null`). Real rules from backend doc not deployed yet.
- API key: advised to restrict in Google Cloud Console (Android app + SHA-1). It's a client identifier, not a real secret; GitHub secret-scan alert is a false positive for Firebase client keys.
- Android package name: `com.example.ai_recipe_generator` (still the default `com.example` — must change before publishing).
- Debug SHA-1: `C1:0E:2C:BE:D8:F4:4D:4D:71:3E:93:E0:ED:D9:68:C0:58:F3:3A:53` (needed for Google Sign-In + key restriction).

## OPEN DECISIONS (blockers — need the owner)
1. **Content source** — seed curated recipes vs. recipe API vs. AI-only (drives Home/Search/Detail real data).
2. **Gemini platform** — Vertex AI vs. Gemini Developer API.
3. **Cloud Functions billing** — requires the **Blaze (pay-as-you-go)** plan. Needed for M3+.
4. AI gating for unverified emails? 5. Nutrition accuracy (AI estimate vs. API)? 6. AI rate-limit numbers.

## TEMPORARY diagnostics to REVERT once auth is confirmed stable
- `core/error/error_mapper.dart`: `authMessage` default returns `'Auth error (code: $code)'` and `generic()` returns `'Unexpected error: $error'` — revert both to the friendly `_fallback`.
- `repositories/auth_repository.dart`: `debugPrint('[AUTH] ...')` logging in signIn/register catch blocks — remove.

## Git / workflow
- Working branch: **`refactor/foundation`**. **Nothing committed yet** this whole effort (user hasn't asked to commit).
- Don't commit unless asked. When committing, end messages with the Co-Authored-By line.

## Running & testing
- Run: `flutter run` (needs an Android device/emulator; internet for Firebase + TheMealDB images).
- New screens/routes require a **full restart** (`R` / stop+run), not hot reload.
- `flutter analyze` and `flutter test` before considering work done. The assistant cannot run the app on the device — the user verifies UI; ask for the exact on-screen/console text when debugging.

## Next unblocked work
Google Sign-In (M4, needs SHA-1 in Firebase console) or Search & Categories (M10, UI). The core **AI generation/chat** cannot start until decisions 2 & 3 are made.
