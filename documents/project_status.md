# CookMate AI — Project Status

**Last updated:** 2026-08-09
**Branch:** `main` (PR #1 merged 2026-08-04; `refactor/foundation` is no longer the working branch)
**Legend:** ✅ Done · ⚠️ Partial / in progress / caveat · ❌ Not started

> Rewritten 2026-08-09 against a verified source tree. The previous revision was dated
> 2026-07-10 and described the app as "~10% built" with Home / Profile / Recipe Detail /
> Favorites marked ❌. That was wrong on nearly every row. Every ✅ below was confirmed by
> opening the file named beside it, not by reading another document.
>
> `CLAUDE.md` at the repo root remains the authoritative narrative context. This file is the
> done/not-done tracker; where the two ever disagree, trust `CLAUDE.md` and fix this one.

---

## 1. Verification snapshot (2026-08-09)

| Check | Result |
|---|---|
| `flutter test` | **136 tests, all passing** (18 test files) |
| `flutter analyze` | **7 issues: 1 warning + 6 info.** See the caveat below. |
| Branch | `main` |

⚠️ **Analyze is NOT clean right now, and this is expected mid-session.** The single warning is
`unused_local_variable: shareService` at `lib/app/app.dart:53` — it comes from the Share feature
being built in this session (the provider is registered but `RecipeDetailScreen` has not yet been
switched onto it). The 6 info hints are the accepted `prefer_initializing_formals` entries in
`lib/repositories/auth_repository.dart` and `lib/repositories/chat_repository.dart`; note the
analyzer reports each of the 3 sites twice, so "3 known hints" in `CLAUDE.md` and "6 info" here
describe the same thing. Golden rule 5 (0 errors/warnings) is satisfied once the Share work lands.

---

## 2. Big picture

| Area | Status | Evidence |
|---|---|---|
| Design system / tokens | ✅ | `lib/core/theme/` — app_colors, app_dimensions, app_text_styles, app_durations, app_shadows, app_animations, app_scroll_behavior, app_theme |
| App architecture (DI, providers, router) | ✅ | `lib/app/app.dart`, `lib/routes/app_routes.dart`, 5 providers, 5 repositories, 10 services |
| Feature screens | ✅ | 19 screens in `lib/screens/` (see §5) |
| Firebase backend (Auth + Firestore, rules deployed) | ✅ | `firestore.rules`, `firestore.indexes.json`, `firebase.json` |
| AI (Gemini, generate + chat) | ✅ | `lib/services/gemini_direct_service.dart` |
| Cloud Functions | ❌ (deliberate) | Deferred to production per D7 — see §7 |
| Cross-cutting polish (offline, image caching) | ❌ | See §7 |
| Crash reporting | ❌ | See §7 |

**One-line summary:** the app is feature-complete for its documented scope on the free Firebase
tier. What remains is a short list of cross-cutting production concerns, not features.

---

## 3. Layers (all verified present)

| Layer | Files |
|---|---|
| Providers (5) | `auth_provider`, `recipe_provider`, `chat_provider`, `notification_provider`, `usage_provider` |
| Repositories (5) | `auth_repository`, `user_repository`, `recipe_repository`, `chat_repository`, `usage_repository` |
| Services (10) | `auth_service`, `firestore_service`, `meal_db_service`, `ai_service` (interface), `gemini_direct_service`, `unconfigured_ai_service`, `usage_sink`, `notification_service`, `notification_store`, `settings_store` |
| Models (7) | `recipe_model`, `user_model`, `chat_message`, `chat_session`, `app_notification`, `generation_entry`, `usage_entry` |
| Core widgets (17) | `lib/core/widgets/` — incl. `app_bottom_nav`, `favorite_button`, `recipe_opening_overlay`, `shimmer_loading`, `markdown_text`, `recipe_card`, `profile_avatar` |
| Core utils | `validators`, `responsive`, `image_source` |
| Core config | `ai_config` (Remote Config → env.json → --dart-define) |
| Core error | `failure`, `error_mapper` |

Architecture rule holds: services resolve `FirebaseAuth.instance` / `FirebaseFirestore.instance`
lazily via getters, which is what lets providers be constructed in unit tests without Firebase.

`lib/services/settings_store.dart` is new and untracked as of this writing — it belongs to the
Settings screen being built this session (see §6).

---

## 4. Routes — wired vs. placeholder

`lib/routes/app_routes.dart` declares 18 route constants. Verified against the `onGenerateRoute`
switch:

| Route | Wired? |
|---|---|
| `/` splash, `/login`, `/register`, `/forgot-password`, `/home` | ✅ |
| `/recipe` (typed `Recipe` arg), `/category` (typed `String` arg) | ✅ (falls back to placeholder on a wrong arg type — deliberate) |
| `/search`, `/edit-profile`, `/change-password`, `/delete-account`, `/history`, `/usage` | ✅ |
| `/favorites`, `/saved`, `/chat`, `/profile` | ⚠️ Declared with **no `case`** — but these are **tabs inside `MainShell`**, reached by tab index, not by name. Nothing navigates to them by route, so the missing cases are harmless, not a bug. |
| `/settings` | ⚠️ In progress this session — see §6 |

Anything unmatched falls through to the `_ComingSoon` placeholder rather than throwing.

---

## 5. Screens (19 files, all verified in `lib/screens/`)

| Screen | File | Status |
|---|---|---|
| Splash | `splash_screen.dart` | ✅ auth-state gate |
| Login | `login_screen.dart` | ✅ email + Google, device-verified |
| Register | `register_screen.dart` | ✅ |
| Forgot Password | `forgot_password_screen.dart` | ✅ |
| Main Shell (5-tab nav) | `main_shell.dart` | ✅ `extendBody: true`, lifecycle observer for notification refresh |
| Home | `home_screen.dart` | ✅ live catalog (3 rails), pull-to-refresh, notification inbox sheet |
| Recipe Detail | `recipe_detail_screen.dart` | ✅ full page, hero, favorite/save. Share = ⚠️ see §6 |
| AI Hub (Generate \| Chat) | `ai_hub_screen.dart` | ✅ both modes + chat history sheet |
| Favorites | `favorites_screen.dart` | ✅ |
| Saved | `saved_screen.dart` | ✅ search, 4-way sort, long-press delete |
| Search | `search_screen.dart` | ✅ |
| Category Results | `category_results_screen.dart` | ✅ |
| Profile | `profile_screen.dart` | ✅ live stat tiles, grouped menus, email-verification banner |
| Edit Profile | `edit_profile_screen.dart` | ✅ name + avatar |
| Avatar Crop | `avatar_crop_screen.dart` | ✅ circular pan/zoom, 384px export, no new dependency |
| Change Password | `change_password_screen.dart` | ✅ |
| Delete Account | `delete_account_screen.dart` | ✅ Play-compliant: confirm + re-auth, Firestore-then-auth order |
| Usage History | `history_screen.dart` | ✅ day grouping, prompt shown, swipe delete |
| Credit Usage | `usage_screen.dart` | ✅ token totals + per-feature breakdown |
| Settings | — | ⚠️ in progress this session — see §6 |

---

## 6. In progress (this session, 2026-08-09) — status intentionally not final

Two features are being built by other work in flight. Their status is changing as this is written,
so neither is marked done or not-done here. **Finalize these rows once the work lands.**

- **Settings screen** — ⚠️ In progress. `AppRoutes.settings` (`/settings`) is declared but currently
  has **no `case`** in `onGenerateRoute`, so it still resolves to `_ComingSoon`. Two pieces have
  already landed: `lib/services/settings_store.dart` (a `shared_preferences` seam built like
  `notification_store.dart`) and a Settings menu entry in `profile_screen.dart:247` that already
  calls `Navigator.pushNamed(context, AppRoutes.settings)`. **What it will change:** add the route
  case and the screen, turning that live Profile link from a placeholder into a real page
  (M11 specified notifications toggle / privacy / terms / about).
- **Share** — ⚠️ In progress. `recipe_detail_screen.dart:464` still shows a `'Share coming soon'`
  snackbar. The seam has landed ahead of the UI: `lib/services/share_service.dart` +
  `lib/services/platform_share_service.dart` exist and `app.dart:86` registers a
  `Provider<ShareService>`, but nothing consumes it yet — which is exactly why analyze reports the
  one `unused_local_variable` warning. **What it will change:** point the detail screen's share
  button at `ShareService`, retire the snackbar, and clear that warning. Note `share_plus` is
  **not** in `pubspec.yaml`; the implementation uses Flutter's built-in platform channel instead.

---

## 7. Genuinely not done

| Item | Status | Why |
|---|---|---|
| **M3 Cloud Functions / full backend** | ❌ **Deliberate, not an oversight** | D7 targets a Cloud Function for Gemini, but Functions require the Blaze (paid) plan. On a university/portfolio build the dev phase calls the free Gemini Developer API directly. The seam is preserved: `AiService` interface → `GeminiDirectService`; migrating is one line in `app/app.dart`. Same reasoning kills Cloud Storage — avatars are base64 in the Firestore user doc instead. |
| **Offline handling (M12)** | ❌ | No `connectivity_plus` in `pubspec.yaml`, no explicit Firestore persistence call (verified absent from `firestore_service.dart` and `main.dart`), no offline banner. AI calls fail with a generic error rather than "needs connection". |
| **Image caching** | ❌ | `cached_network_image` is not in `pubspec.yaml`. The `TODO(Phase 6)` at `lib/core/widgets/profile_avatar.dart:14` still stands. `RecipeCard` does set a `cacheWidth` from `LayoutBuilder` constraints, so decode size is controlled even without the package. |
| **Crashlytics (M14)** | ❌ | `_reportError` at `lib/main.dart:101` only calls `debugPrint`. It is deliberately a single funnel — `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError` all route through it, so adding a reporter is a one-line change. |
| **Folder migration (M2 / refactor phase 5)** | ❌ | `lib/screens/` is still flat, not feature-first. Cosmetic; no functional impact. |
| **App Check / rate limiting** | ❌ | Depends on M3. `firestore.rules` intentionally diverges from backend doc §8 until that infra lands. |
| **Prod Firebase project** | ❌ | `ai-recipe-generator-db27c` is treated as dev. |

---

## 8. Dependencies (actual `pubspec.yaml`, verified)

**Present:** `firebase_core ^4.0.0` · `firebase_auth ^6.0.0` · `cloud_firestore ^6.0.0` ·
`firebase_remote_config ^6.5.5` · `firebase_messaging ^16.4.3` · `google_sign_in ^7.2.0` ·
`http ^1.2.0` · `provider ^6.1.5` · `image_picker ^1.2.3` · `shared_preferences ^2.5.5` ·
`cupertino_icons`. Dev: `flutter_lints ^6.0.0`, `flutter_launcher_icons ^0.14.4`.

**Deliberately absent** (the old status file listed several of these as "needed" — they are not):

| Package | Why not |
|---|---|
| `google_fonts` | Removed. Fraunces (variable) + Inter (4 static) are bundled under `assets/fonts/`, so type is correct offline and at first paint. |
| `firebase_storage` | Storage now requires Blaze. Avatars are base64 in Firestore. |
| `cloud_functions`, `firebase_app_check` | Deferred with M3. |
| `flutter_markdown` | Replaced by the in-house `lib/core/widgets/markdown_text.dart` (headings/bold/italic/code/lists/blockquotes/pipe tables). |
| `share_plus` | Share is being implemented over Flutter's built-in platform channel — see §6. |
| `image_cropper` | Rejected: extra dependency, manifest entries, non-branded UI. `avatar_crop_screen.dart` replays the user's own transform matrix onto a canvas instead. |
| Shimmer package | In-house `lib/core/widgets/shimmer_loading.dart`. |
| `cached_network_image`, `connectivity_plus` | Genuinely missing — see §7. |

---

## 9. Tests (18 files, 136 passing)

| File | Covers |
|---|---|
| `widget_test.dart` | Core widget smoke tests |
| `ui_polish_test.dart` | Largest suite (~30KB): nav position/labels, button + field behavior, press/heart animation timing, hero-tag contract, avatar provider caching, grid overflow + the `cacheWidth` infinity case, type scale, and the `lib/`-walking scroll-physics guard |
| `recipe_detail_test.dart` | Detail renders its body (guards the old blank-body regression) |
| `auth_provider_google_test.dart` | Google sign-in + cancellation path |
| `gemini_direct_service_test.dart` | Gemini request/response handling |
| `ai_hub_screen_test.dart` | Generate \| Chat hub |
| `markdown_text_test.dart` | In-house renderer incl. malformed tables |
| `chat_provider_history_test.dart` | Session persistence |
| `home_catalog_test.dart` | Seed-then-upgrade rail loading |
| `responsive_shimmer_test.dart` | Breakpoints + skeletons |
| `notification_provider_test.dart` | Accumulate/dedupe/read/prune/persistence, no Firebase |
| `validators_password_test.dart` | Password policy (8+, letter + digit, max 128) |
| `desi_recipes_test.dart` | Curated desi catalog + image URLs |
| `meal_db_service_test.dart` | TheMealDB parsing |
| `search_test.dart`, `category_results_test.dart` | Discovery screens |
| `generation_entry_test.dart` | Usage History model |
| `usage_tracking_test.dart` | Token parsing/aggregation + service→sink seam (mocked Gemini response) |

⚠️ Per golden rule 9: a green suite says nothing about whether the UI is right. Several real
defects in this project passed analyze, tests, **and** a release build before the owner caught them
on a device. Anything visual still needs eyes on hardware.

---

## 10. Owner-side items

All previously tracked owner blockers are cleared: Firestore rules deployed (2026-07-29), Google
Sign-In device-verified (2026-08-04), push notifications device-verified (2026-07-29), signing
keystore + SHA-1 (2026-08-04), Privacy Policy + Terms hosted (2026-08-04), package renamed to
`com.urooj.cookmate` (2026-08-04), and the Cloud Console API-key restriction updated for the new
package (2026-08-09 — it had been breaking Google Sign-In and FCM together, since both authenticate
with the same `apiKey`).

**Still outstanding for the owner:**
- The **release keystore's SHA-1** must be added to the Cloud Console API-key restriction list
  before a Play upload. The debug SHA-1 is there; a debug-only entry works in `flutter run` and
  fails in release.
- Store-listing work: icon, feature graphic, screenshots, description, content rating, data-safety
  form. No code blocks a listing.

---

## 11. Open decisions

1. **Content source** — still open. Home/Search/Detail run on a TheMealDB + curated-desi blend until decided.
2. ~~Gemini platform~~ — ✅ resolved: free Gemini Developer API, called directly.
3. ~~Cloud Functions billing / Blaze~~ — ✅ resolved for dev: not used. Revisit for production per D7.
4. AI gating for unverified emails — open.
5. Nutrition accuracy (AI estimate vs. API) — open.
6. AI rate-limit numbers — open.
