# AI Recipe Generator — Project Context

> Persistent context for this Flutter app. Read this first each session.
> Last updated: 2026-07-12.

## What this is
A production-intent **Flutter (Android-first) AI recipe app**: Firebase backend + Google Gemini. Premium **warm-brown / cream** brand. Users register, browse recipes, generate recipes with AI, chat with an AI cooking assistant, favorite/save recipes, and manage a profile. **Dev phase calls the Gemini Developer API directly** from the app; Cloud Functions is the production target (see D7).

Design docs live in `documents/`: `prd.pdf`, `trd.pdf`, `afd.pdf`, `ui_ux design.pdf`, plus the authored `backend_architecture.md` (the real backend spec — the PDF named "backend artcitecture" is a mislabeled duplicate of the UI/UX brief), `refactoring_plan.md`, `completion_plan.md` (M1–M15 roadmap), and `project_status.md` (done/not-done tracker).

## Golden rules (do not violate)
1. **Design tokens only** — no hardcoded colors, font sizes, radii, or asset paths in screens/widgets. Use `AppColors`, `AppDimensions`, `AppTextStyles`, `AppShadows`, `AppDurations`, `AppAssets`, `AppStrings`.
2. **No business logic in widgets.** Flow is **Widget → Provider → Repository → Service (SDK)**. Widgets never touch `FirebaseAuth`/`Firestore`/`Functions` directly.
3. **Preserve branding** — warm brown `#8B5E3C`, cream `#F6F2EE`, the logo, and the Login design language. Don't restyle to a different look.
4. Use `withValues(alpha:)` (never deprecated `withOpacity`), wildcard params `(_, _, _)`, `const` where possible.
5. **After every change:** `flutter analyze` must stay at 0 errors/warnings (3 known `prefer_initializing_formals` info hints are accepted), and `flutter test` must pass.
6. State management is **Provider** (mandated by the docs).

## Tech stack
Flutter 3.x / Dart, Material 3, Provider, Firebase (Auth, Firestore, **Storage** via `firebase_storage` for avatars), **Google Sign-In** (`google_sign_in ^7.2.0`), **image_picker** (avatar gallery pick), **Google Gemini via the free Developer API called directly over `http`** (dev phase — Cloud Functions is the production target, see D7). Chat markdown uses a small in-house renderer (`markdown_text.dart`, no package) — supports headings/bold/italic/code/lists **plus blockquotes and pipe tables** (defensive: malformed tables degrade to text, never throw). Fonts: **Poppins bundled locally** as assets (`assets/fonts/`, weights 400/500/600/700; family `'Poppins'` referenced by `AppTextStyles` + `ThemeData.fontFamily`). `google_fonts` **removed** — no runtime font fetch. (Editing bundled fonts needs a full stop+run, not hot reload.)

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
    config/   ai_config                # Gemini key+model; AiConfig.load() reads bundled env.json at RUNTIME
    utils/    validators, responsive   # responsive = AppBreakpoints + BuildContext ext (grid cols, page padding, rail sizes)
    error/    failure, error_mapper
    widgets/  primary_button, app_text_field, google_button, or_divider, section_title,
              loading_indicator, empty_state, app_error_view, profile_avatar,
              category_chip, recipe_card, ai_assistant_card, markdown_text,
              shimmer_loading   # in-house shimmer + RecipeCard/Rail/Grid skeletons (no package)
  models/       recipe_model (Recipe/Nutrition/Ingredient), user_model, chat_message, chat_session
  services/     auth_service, firestore_service, storage_service (avatar upload),
                meal_db_service (TheMealDB catalog), ai_service (interface),
                gemini_direct_service (dev Gemini impl),
                unconfigured_ai_service (no-key no-op)            # thin SDK seams; Firebase resolved LAZILY
  repositories/ auth_repository, user_repository, recipe_repository, chat_repository
  providers/    auth_provider, recipe_provider, chat_provider     # ChangeNotifiers
  screens/      splash, login, register, forgot_password, main_shell, home,
                recipe_detail, favorites, saved, profile, edit_profile,
                search, category_results, ai_hub (Generate|Chat)
test/           widget_test, recipe_detail_test, auth_provider_google_test,
                gemini_direct_service_test, ai_hub_screen_test, markdown_text_test,
                chat_provider_history_test
(root)          env.json (git-ignored key, bundled as asset) + env.example.json,
                firestore.rules, firestore.indexes.json, firebase.json,
                .vscode/launch.json (AI-enabled run configs)
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
- **D7** *(production target)* Gemini via a Cloud Function (App Check + rate limits); key never ships in the app. **⚠️ OVERRIDDEN for the dev phase (2026-07-11):** to avoid Blaze/Cloud Functions cost on this university/portfolio build, dev calls the **free Gemini Developer API directly** from the app. Clean seam preserved: `AiService` interface → `GeminiDirectService` (dev) / future Cloud-Functions impl. Migration = swap one line in `app/app.dart`; repos/providers/UI untouched. Key lives in git-ignored `env.json`, **bundled as an asset and read at runtime by `AiConfig.load()`** (so plain `flutter run` works — no build flag; `--dart-define-from-file` is a fallback). **Model = `gemini-flash-latest`** (the pinned `gemini-2.0-flash` returns HTTP 429 `limit: 0` — zero free-tier quota on this project). The key is extractable from the APK — accepted for dev (the reason prod still moves to D7).
- Firestore schema, complete `firestore.rules`, indexes, and Functions are specified in `backend_architecture.md` §6–§12.

## Build status (see project_status.md for detail)
- ✅ Foundation (tokens, theme, widgets, models, validators, error mapping)
- ✅ M1 Architecture (providers/repos/services/router/DI)
- ✅ M4 (partial): email register/login + **forgot password** work. **Google Sign-In wired in code** (`google_sign_in ^7.2.0`, v7 API: `initialize`→`authenticate`→Firebase credential; cancel handled silently). Not device-verified — owner must finish console setup (see below).
- ✅ M5 Home (redesigned; now on **live catalog** — `RecipeProvider.loadHomeCatalog` drives three rails: **Popular** (live TheMealDB Dinner/Beef), **Pakistani Favourites** (curated `DesiRecipes`), **Quick & Easy** (live TheMealDB Breakfast), with pull-to-refresh and resolve-partial-card-on-tap. **Load is seed-then-upgrade** so Home is never empty/stuck: phase 1 seeds instantly (desi = local, Popular/Quick = `SampleRecipes` fallback) and marks loaded; phase 2 upgrades Popular/Quick to live TheMealDB in the background, silently keeping the seed on any network failure/timeout. `SampleRecipes` now backs only the category-chip labels, the Recipe Detail placeholder, and the offline seed. Test: `test/home_catalog_test.dart`.)
  - **Desi images fixed:** the 10 `DesiRecipes` reused ~5 mismatched TheMealDB URLs (Kheer showed biryani, Karahi showed fish, etc.). TheMealDB has no Pakistani dishes, so images now come from **Wikimedia Commons** (dish-accurate, free-licensed, 500px thumbnails). Two are close approximations (Chana Daal → dal-makhani photo, Chana Chaat → chana-masala photo) — no exact Wikipedia image exists for those Pakistani preparations.
  - **Build-blocker fixed:** `pubspec.yaml` had lost its `google_sign_in ^7.2.0` + `http` deps (imports failed → app wouldn't compile) and never listed `env.json` as an asset (AI silently fell back to "coming soon" on plain `flutter run`). All three restored.
- ✅ M7 Recipe Detail (full page; a prior blank-body bug from a greedy `Center` in the bottom bar is fixed + guarded by test)
- ✅ M8 Favorites & Saved (real Firestore reads/writes; hearts on Home + Detail; Favorites/Saved tabs)
- ✅ Responsive UI + shimmer loading — `core/utils/responsive.dart` (breakpoints 600/1024; grids go 2→3→4 columns, page padding + rail card/height scale up on wider screens) applied to Home, Search, Categories, Favorites, Saved. Loading states use a dependency-free shimmer (`core/widgets/shimmer_loading.dart`: `Shimmer` + `RecipeCardSkeleton`/`RecipeRailSkeleton`/`RecipeGridSkeleton`) instead of plain spinners on Home rails, Search, and Categories. Tests: `test/responsive_shimmer_test.dart`.
- ✅ Profile tab — full page: avatar (tap → Edit Profile) + name + email, tappable **Favorites/Saved** stat cards showing **live counts** (from the loaded `RecipeProvider.favorites`/`saved` lists, since the server-maintained `UserModel` counters stay 0 until Cloud Functions land), a menu section (My Favorites / Saved Recipes / Ask AI switch tabs via `onNavigateTab` from `MainShell`; **Edit Profile** → real screen; **About** = custom dialog, no "view licenses"), **Log Out with a confirm dialog**, app-version footer. Responsive (centered, `maxContentWidth`).
- ✅ **Edit Profile (M11)** — `screens/edit_profile_screen.dart`: change display name + **upload avatar** (gallery via `image_picker`). Flow: `AuthProvider.updateProfile(name, avatarFile)` → `AuthRepository.updateProfile` → `StorageService.uploadAvatar` (Cloud Storage `avatars/{uid}.jpg`) + FirebaseAuth `updateDisplayName`/`updatePhotoURL` + Firestore `/users/{uid}` upsert. New `StorageFailure` type. Name edit works today; **avatar upload needs Cloud Storage enabled + `storage.rules` deployed** (see Firebase console state).
- ✅ M6 AI Generate & M9 AI Chat — **implemented end-to-end** (backend + UI). Service: `GeminiDirectService` (direct Gemini REST over `http`); recipe generation uses JSON-mode (`responseSchema` → `Recipe`), chat scoped to cooking; verified live. UI: `screens/ai_hub_screen.dart` = the "Ask AI" tab (index 2 in `main_shell`), a segmented **Generate | Chat** hub (per D1). Generate → prompt → `RecipeProvider.generate` → `RecipeDetailScreen` → Save. Chat → bubbles + typing dots + composer → `ChatProvider.sendMessage`. AI replies render markdown via `core/widgets/markdown_text.dart` (headings/bold/italic/code/lists — a lightweight token-styled renderer, no external package); the user's own bubbles stay plain text. **Chat history:** header has **New chat** + **History** actions; conversations persist per-user to `users/{uid}/chats/{chatId}` (+ `messages` subcollection) via `ChatRepository` (createChat/touchChat/getChats/getMessages/deleteChat/generateTitle) and `ChatProvider` (newChat/openChat/loadSessions/deleteSession); history shown in a bottom sheet (`_HistorySheet`). **Titles are AI-generated:** a new chat gets a provisional truncated-prompt title, then `AiService.generateTitle` (extra Gemini call, `_titleSystemPrompt`) upgrades it from the first exchange — runs *after* the reply is shown so it adds no perceived latency; best-effort (keeps provisional title on failure). Persistence is best-effort and requires sign-in (uid); signed-out chat still works but isn't saved. `ChatSession` model = `models/chat_session.dart`. Key in git-ignored `env.json`; **model = `gemini-flash-latest`** (pinned `gemini-2.0-flash` has **zero free-tier quota** on this project — use the `-latest` alias). M3 (full backend/Functions) deferred to production.

## Firebase console state
- Project: `ai-recipe-generator-db27c` (treat as **dev**; prod not created yet).
- ✅ Email/Password auth enabled (the earlier `CONFIGURATION_NOT_FOUND` was this being off).
- ✅ Firestore created — region `asia-south1` (Mumbai). **Real rules authored** in `firestore.rules` (+ `firestore.indexes.json`, wired via `firebase.json`): owner-only `users/{uid}/**` (covers favorites / generatedRecipes / chats / messages), read-only `/recipes` + `/home_feed`, deny-by-default. **⚠️ NOT deployed yet** — still live on open **test-mode** rules. Owner deploys with: `firebase login && firebase deploy --only firestore:rules,firestore:indexes --project ai-recipe-generator-db27c`. (Rules intentionally diverge from backend doc §8 — no App Check / Functions-only writes — until that infra lands; see the header comment in `firestore.rules`.)
- ⚠️ **Cloud Storage NOT enabled yet** — needed for **avatar upload** (Edit Profile). Owner: Firebase console → **Storage → Get started**, then deploy the authored `storage.rules` (owner-writable `avatars/{uid}.jpg`, public read) via `firebase deploy --only storage --project ai-recipe-generator-db27c`. Until then, avatar upload throws a `StorageFailure` ("Couldn't upload your photo") — name editing still works.
- API key: advised to restrict in Google Cloud Console (Android app + SHA-1). It's a client identifier, not a real secret; GitHub secret-scan alert is a false positive for Firebase client keys.
- Android package name: `com.example.ai_recipe_generator` (still the default `com.example` — must change before publishing).
- Debug SHA-1: `C1:0E:2C:BE:D8:F4:4D:4D:71:3E:93:E0:ED:D9:68:C0:58:F3:3A:53` (needed for Google Sign-In + key restriction).

## OPEN DECISIONS (blockers — need the owner)
1. **Content source** — seed curated recipes vs. recipe API vs. AI-only (drives Home/Search/Detail real data).
2. ~~**Gemini platform**~~ ✅ **RESOLVED (dev):** free **Gemini Developer API**, called directly (no Vertex).
3. ~~**Cloud Functions billing / Blaze**~~ ✅ **RESOLVED (dev):** not using Cloud Functions or Blaze during development. (Revisit for production per D7.)
4. AI gating for unverified emails? 5. Nutrition accuracy (AI estimate vs. API)? 6. AI rate-limit numbers.

## Git / workflow
- Working branch: **`refactor/foundation`**. **Nothing committed yet** this whole effort (user hasn't asked to commit).
- Don't commit unless asked. When committing, end messages with the Co-Authored-By line.

## Running & testing
- Run: plain `flutter run` (or the IDE ▶ button) — **the flag is no longer needed**. `AiConfig.load()` reads the git-ignored `env.json` **bundled as an asset** at runtime (see `pubspec.yaml assets`), so AI works with any launch method as long as `env.json` exists locally with a valid key. (`--dart-define-from-file=env.json` still works as a fallback; the `.vscode/launch.json` config keeps it too.) If `env.json` is missing/keyless, AI degrades to "coming soon". Needs an Android device/emulator; internet for Firebase + TheMealDB images + Gemini. **Editing `env.json` requires a full stop+run** (assets are bundled at build, not hot-reloaded).
- New screens/routes require a **full restart** (`R` / stop+run), not hot reload.
- `flutter analyze` and `flutter test` before considering work done. The assistant cannot run the app on the device — the user verifies UI; ask for the exact on-screen/console text when debugging.
- **Build gotcha (fixed):** on this Kotlin 2.3.20 / Gradle 9.1.0 toolchain, compiling `google_sign_in_android` failed with *"Could not close incremental caches … is already registered"*. Fixed by `kotlin.incremental=false` in `android/gradle.properties`. `flutter build apk --debug` succeeds (compiles the Kotlin modules without a device — use it to verify Android builds). Don't remove that flag until the toolchain is upgraded.

## Google Sign-In — console setup DONE (2026-07-15)
The code stack is complete (`services/auth_service.dart` `signInWithGoogle` + `kGoogleServerClientId`, `repositories/auth_repository.dart`, `providers/auth_provider.dart`, Login/Register handlers navigate on success) AND the owner has completed the console side: Google enabled, debug SHA-1 added, and the **new `google-services.json` (with `oauth_client` entries) is in `android/app/`**. Should now work on-device — **owner to smoke-test the button and confirm** (ask for the exact on-screen/console text if it errors). Cancellation returns `null` from the repo → provider stays idle, no error snackbar.

## Next unblocked work
Foundation, M1, M4 (Google Sign-In console now done — owner to smoke-test), M5 Home (now live), M6/M9 AI, M7 Detail, M8 Favorites/Saved, M10 Search & Categories, plus responsive UI + shimmer loading are all **done**. `flutter analyze` = 0 (3 accepted hints), `flutter test` = **60 pass**. Remaining:

**Owner-only (blockers, not code):**
- **Deploy** the authored `firestore.rules` (see Firebase console state) — the app stays on open **test-mode** until then. ⚠️ security gap. `firebase login && firebase deploy --only firestore:rules,firestore:indexes --project ai-recipe-generator-db27c`.
- **Enable Cloud Storage + deploy `storage.rules`** so avatar upload (Edit Profile) works: console → Storage → Get started, then `firebase deploy --only storage --project ai-recipe-generator-db27c`.
- **Smoke-test Google Sign-In** on-device (console setup + `google-services.json` are now in place).
- Verify TheMealDB reachability on the device: if Home's Popular/Quick rails only ever show the `SampleRecipes` seed (never live dishes), the device/emulator can't reach `themealdb.com` — network/emulator issue, not app logic.

**Code-only, unblocked (lower priority / polish):**
- ✅ Poppins fonts bundled locally (google_fonts removed); ✅ markdown blockquotes + tables; ✅ all 10 desi images now exact Wikimedia matches (incl. Chana Daal / Chana Chaat).
- ⚠️ Do NOT change the package name off `com.example.ai_recipe_generator` — the owner's `google-services.json` is registered to it; renaming would break Firebase + Google Sign-In. Defer to a deliberate prod rename (new Firebase app + SHA-1 + re-download).
- Optional: tighten rules toward §8 when App Check + Functions land.

**Deferred to production:** M3 (Cloud Functions / full backend) per D7. Real content-source decision (Open Decision 1) — Home/Search/Detail run on the TheMealDB + curated-desi blend until then.

**Uncommitted:** everything this session (pubspec fix, live Home rails, desi images, seed-then-upgrade loader) is on `refactor/foundation`, not committed.
