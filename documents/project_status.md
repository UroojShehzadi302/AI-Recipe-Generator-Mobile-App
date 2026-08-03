# AI Recipe Generator — Project Status

**Last updated:** 2026-07-10
**Branch:** `refactor/foundation`
**Legend:** ✅ Done · 🟡 Partial / in progress · ❌ Not started

> This file tracks what is completed vs. pending. It is a status report only — no code.

---

## 1. Big Picture

| Area | Status | Notes |
|---|---|---|
| Planning & documentation | ✅ | All design docs present + backend + refactor plan written. |
| Codebase foundation (design system, widgets, models) | ✅ | Built and verified; **not yet wired into the app**. |
| App architecture (providers, router, repositories) | ❌ | Phase 4 — not started. |
| Actual features (auth, AI, home, recipes, etc.) | ❌ | Screens are mostly empty stubs. |
| Backend (Firebase rules, Cloud Functions, Gemini) | ❌ | Designed on paper; nothing deployed or coded. |

**One-line summary:** The foundation is clean and production-grade, but the app itself is still ~10% built — one polished Login UI, a working Splash, and a solid set of reusable building blocks that nothing uses yet.

---

## 2. Documentation

| Document | Status | Notes |
|---|---|---|
| PRD | ✅ | Provided. |
| TRD | ✅ | Provided. |
| AFD (flows) | ✅ | Provided. |
| UI/UX Design Brief | ✅ | Provided. |
| Backend Architecture | ✅ | **Was missing** (old PDF was a duplicate of UI/UX); rewritten as `backend_architecture.md`. |
| Refactoring Plan | ✅ | `refactoring_plan.md`. |
| Full architecture review | ✅ | Delivered in chat (not a file). |
| Code review | ✅ | Delivered in chat (not a file). |

---

## 3. Refactoring Progress (foundation)

| Phase | Description | Status |
|---|---|---|
| 0 | Safety net (branch, baseline, analyzer count) | ✅ |
| 1 | Design tokens (colors, dimensions, text styles, durations, shadows, assets, strings) | ✅ |
| 2 | `AppTheme` rebuilt from tokens; Splash + main.dart rewired; background aligned to `#F6F2EE` | ✅ |
| 3 | Reusable widgets + models + validators + error mapping (built by 4 parallel agents) | ✅ |
| 4 | Providers + Router + Repositories + Splash auth gate + migrate Login/Register to new widgets | ✅ (= completion-plan M1; compiles + tests pass; runtime not device-verified) |
| 5 | Folder migration (feature-first grouping) | ❌ |
| 6 | Add dependencies, responsive helper, stricter lints, deploy Firebase rules to dev | ❌ |
| 7 | Full verification, token-enforcement guard, regression tests | 🟡 (foundation smoke tests done) |

**Verification of completed work:** `flutter analyze` → 1 issue (pre-existing `withOpacity` in legacy `custom_button.dart`, removed during Phase 4). `flutter test` → 3/3 pass.

---

## 4. Foundation Files Built (Phases 1–3)

| Category | Status | Files |
|---|---|---|
| Color/spacing/type tokens | ✅ | `core/theme/app_colors`, `app_dimensions`, `app_text_styles`, `app_durations`, `app_shadows` |
| Constants | ✅ | `core/constants/app_assets`, `app_strings` |
| Theme | ✅ | `core/theme/app_theme` |
| Action widgets | ✅ | `core/widgets/primary_button`, `app_text_field`, `google_button`, `or_divider`, `section_title` |
| Feedback widgets | ✅ | `core/widgets/loading_indicator`, `empty_state`, `app_error_view`, `profile_avatar` |
| Models | ✅ | `models/recipe_model` (Recipe/Nutrition/Ingredient), `user_model`, `chat_message` |
| Validation & errors | ✅ | `core/utils/validators`, `core/error/failure`, `core/error/error_mapper` |
| Foundation tests | ✅ | `test/widget_test.dart` |

> These are all **additive** — no screen imports them yet, so the app still runs exactly as before.

---

## 5. Screens Status

| Screen | UI | Logic | Status |
|---|---|---|---|
| Splash | ✅ | ✅ (auth-state gate → Home/Login) | ✅ |
| Login | ✅ | ✅ (Form + validators, wired to AuthProvider; email auth live) | ✅ (Google = friendly stub until M2) |
| Register | ✅ (real screen) | ✅ (wired to AuthProvider.register) | ✅ (Google = friendly stub until M2) |
| Forgot Password | ❌ | ❌ | ❌ |
| Home | 🟡 (basic stub) | ❌ | ❌ Doesn't match documented Home |
| AI Recipe Generator | ❌ | ❌ | ❌ |
| AI Chat | ❌ | ❌ | ❌ |
| Recipe Detail | ❌ (empty file) | ❌ | ❌ |
| Favorites | ❌ (empty file) | ❌ | ❌ |
| Saved Recipes | ❌ | ❌ | ❌ |
| Profile | ❌ (empty file) | ❌ | ❌ |
| Search | ❌ | ❌ | ❌ |
| Categories | ❌ | ❌ | ❌ |
| Settings | ❌ | ❌ | ❌ |
| Bottom Navigation | ❌ | ❌ | ❌ |

---

## 6. Backend & Integrations Status

| Item | Status | Notes |
|---|---|---|
| Firebase project (dev) | ✅ | Wired (`firebase_options.dart`). |
| Firebase project (prod) | ❌ | Not created. |
| Firebase Auth wiring | ✅ | `AuthService` → `AuthRepository` → `AuthProvider` built. |
| Email/password login | 🟡 | Coded + compiles; needs Email/Password enabled in console + device to verify. |
| Google Sign-In | ❌ | Package not added yet (M2); friendly stub in place. |
| Firestore wiring | 🟡 | `FirestoreService` + repositories built; not device-verified. |
| Firestore security rules | ❌ | Designed in backend doc; not deployed. |
| Firestore indexes | ❌ | Designed; not created. |
| Storage (avatars) | ❌ | Package not added. |
| Gemini AI (recipe generation) | ❌ | `gemini_service.dart` empty. |
| Gemini AI (chat) | ❌ | Not implemented. |
| Cloud Functions (AI proxy, counters, feed) | ❌ | Designed; not coded. |
| App Check / rate limiting | ❌ | Designed; not implemented. |

---

## 7. Dependencies

| Package | In pubspec? | Needed for |
|---|---|---|
| firebase_core / firebase_auth / cloud_firestore | ✅ | Core Firebase |
| provider | ✅ | State management (not used yet) |
| google_fonts | ✅ | Poppins (runtime fetch; bundle in Phase 6) |
| google_sign_in | ❌ | Google auth |
| cloud_functions | ❌ | Gemini proxy |
| firebase_app_check | ❌ | Abuse prevention |
| firebase_storage | ❌ | Profile photos |
| cached_network_image | ❌ | Recipe/image caching |
| flutter_markdown | ❌ | AI chat rendering |
| share_plus | ❌ | Share recipe |
| shared_preferences | ❌ | Remember-me prefill |
| connectivity_plus | ❌ | Offline handling |
| image_picker | ❌ | Avatar upload |

---

## 8. Known Cleanup Items (pending Phase 4/5)

- Legacy `lib/utils/validators.dart` (empty) duplicates canonical `lib/core/utils/validators.dart`.
- Legacy `lib/widgets/custom_button.dart` + `custom_textfield.dart` still power Login (replaced during migration).
- Last `withOpacity` deprecation lives in legacy `custom_button.dart`.
- `routes/app_routes.dart` is partial (missing profile/recipe/history/forgot) → replaced by `app_router` in Phase 4.

---

## 9. Open Decisions (still need owner sign-off)

From the backend doc §17 and refactor plan:
1. Curated content source (seed data vs. recipe API vs. AI-only).
2. Gemini platform (Vertex AI vs. Developer API).
3. Cloud Functions billing (Blaze plan required).
4. AI gating for unverified emails.
5. Nutrition accuracy (AI estimate vs. nutrition API).
6. AI rate-limit numbers.

---

## 10. Recommended Next Steps

1. Decide whether to proceed to **Phase 4** (providers + router + repositories + migrate Login).
2. Commit the current foundation checkpoint (branch `refactor/foundation`).
3. Resolve the 6 open decisions in §9 before backend feature work.
4. Then build features in order: Auth → Home → AI Generator → Recipe Detail → Favorites/Saved → Profile → Chat.
