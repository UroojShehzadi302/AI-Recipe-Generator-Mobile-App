# AI Recipe Generator — Refactoring Implementation Plan

**Goal:** Transform the current beginner-level skeleton into a clean, scalable, production-ready foundation **without changing the visible look or breaking the app at any step.**
**Constraint:** Preserve branding — warm brown `#8B5E3C`, cream `#F6F2EE`, the logo, and the login design language become the *canonical* system.
**Method:** Small, compiling, verifiable slices. After every phase the app must build and the Splash → Login flow must look pixel-identical to today.

> Rule for every phase: **no visual change unless explicitly noted.** We are moving values into tokens, not redesigning. Where the current code disagrees with the docs (e.g. theme background `#FFF8F2` vs. brand `#F6F2EE`), we standardize on the **brand/doc value** and note it.

---

## Phase 0 — Safety Net (prerequisite, ~30 min)

Before touching code, make regressions visible.

1. Confirm a clean git baseline (repo has `.git`). Create branch `refactor/foundation`.
2. `flutter analyze` and record current warning count as the baseline.
3. `flutter run` once; screenshot Splash + Login as the visual reference.
4. Note current exact values to preserve:
   - Login background `#F6F2EE`, card radius `25`, elevation `5`.
   - Primary button height `55`, radius `16`, elevation `4`.
   - TextField radius `16`, grey `Colors.grey.shade300` border.
   - Brand brown `#8B5E3C`; secondary `#D6A46D`.

**Acceptance:** branch created, baseline screenshots saved, analyze count recorded.

---

## Phase 1 — Design System / Theme Tokens (Critical #1)

**Objective:** one source of truth for every UI value. No behavior change.

**Create `lib/core/theme/` and `lib/core/constants/`:**

| File | Contents (spec) |
|---|---|
| `app_colors.dart` | `primary #8B5E3C`, `secondary #D6A46D`, `background #F6F2EE`, `surface #FFFFFF`, `textPrimary #2E2E2E`, `textSecondary #7A7A7A`, `success` (soft green), `error` (soft red), `border Colors.grey.shade300`. |
| `app_dimensions.dart` | Spacing scale `xs 4 / s 8 / m 12 / l 16 / xl 22 / xxl 30`; radii `sm 12 / md 16 / lg 20 / xl 25`; button height `55`; field content padding `18`. |
| `app_text_styles.dart` | Poppins-based scale: `heading (28/bold)`, `title (20/w600)`, `subtitle (14/grey)`, `body (16)`, `button (16/bold/ls1)`, `caption (12)`. Mirror current literals so nothing shifts. |
| `app_durations.dart` | `splash 2s`, `short 200ms`, `medium 350ms` (for future animations). |
| `app_shadows.dart` | `card` (black12, soft), `button` (brown @ ~0.35). |
| `constants/app_assets.dart` | `logo = 'assets/images/logo.png'`, `googleIcon = 'assets/icons/google.png'`. |
| `constants/app_strings.dart` | Login copy + labels + button text currently hardcoded. |

**Do NOT yet** change screens. This phase only *adds* files.

**Acceptance:** app compiles; nothing references the new files yet; no visual change.

---

## Phase 2 — Reconcile `AppTheme` (Critical #2)

**Objective:** make `ThemeData` consume the tokens and become the single button/input spec, resolving the theme↔widget conflict.

Steps:
1. Move `utils/app_theme.dart` → `core/theme/app_theme.dart`; rebuild it from tokens.
2. Fix off-brand background: `#FFF8F2` → `#F6F2EE` (matches Login & docs). *This is the one deliberate visual correction — Splash/theme background aligns to Login.*
3. Set `elevatedButtonTheme` to the **CustomButton spec** (height 55, radius 16, elevation 4) so the theme and the widget finally match. Set `inputDecorationTheme` to the **CustomTextField spec** (radius 16, grey border) for the same reason.
4. Bundle Poppins as an asset and switch `GoogleFonts.poppins()` → bundled `TextTheme` (kills runtime font fetch). *Visual output identical.*
5. Update `main.dart` import path.

**Acceptance:** app looks identical except Splash background now matches Login (intended). `home_screen`'s raw `ElevatedButton.icon` now renders the *same* button as `CustomButton`.

---

## Phase 3 — Foundation Widgets & Validators (High #5, Medium #8)

**Objective:** reusable widgets + validation capability, all token-driven.

1. Extend `CustomTextField` → `AppTextField` in `core/widgets/`: add `validator`, `onChanged`, `textInputAction`, `focusNode`; source colors/radii from tokens. Keep default look identical.
2. `core/utils/validators.dart`: `email`, `password` (min length), `confirmPassword`, `requiredField`, `name`, `aiPrompt` (length bounds). Pure functions.
3. Extract from login into `core/widgets/`: `PrimaryButton` (consolidate `CustomButton`), `SocialButton`/`GoogleButton`, `OrDivider`, `SectionTitle`.
4. Add state widgets (spec/skeleton): `LoadingIndicator`, `EmptyState`, `AppErrorView`, `ProfileAvatar`.
5. Fix deprecated `withOpacity` → `withValues`; add `errorBuilder` to `Image.asset` for logo/google.

**Acceptance:** Login rebuilt from the new widgets renders identically; `flutter analyze` warnings drop.

---

## Phase 4 — App Structure: Providers, Repositories, Router (Critical #3, High #6)

**Objective:** the missing layers, wired but minimal. No feature logic yet.

1. Create `app/app.dart` (move `RecipeGeneratorApp` out of `main.dart`); `main.dart` becomes bootstrap only.
2. `app/router/app_router.dart`: `onGenerateRoute` covering splash, login, register, home, **plus** profile, recipe (with typed args), history/favorites, chat, forgot-password. Replaces `routes/app_routes.dart`.
3. `providers/`: `AuthProvider`, `RecipeProvider`, `ChatProvider` (ChangeNotifiers, empty state + method stubs). Register via `MultiProvider` in `app.dart`.
4. `repositories/`: `AuthRepository`, `RecipeRepository`, `ChatRepository` (interfaces + Firebase-backed impls, method stubs).
5. `services/`: keep `AuthService`/`FirestoreService`; make `GeminiService` a `cloud_functions` callable wrapper (per backend doc D7). Repositories call services.
6. `models/recipe_model.dart`: implement `Recipe` (+ `fromJson`/`toJson`) matching backend doc §6.3 (title, ingredients[], instructions[], calories, time, difficulty, servings, nutrition{}, tips[], category, sourceType). Add `UserModel`, `ChatMessage`.
7. Splash: replace fixed `Timer→login` with **auth-state gate** (`AuthProvider`/`authStateChanges`), `mounted`-guarded. Falls back to Login when signed out (current behavior) so no visible change for a logged-out user.

**Acceptance:** app boots through the new router + providers; logged-out user still lands on Login exactly as before.

---

## Phase 5 — Folder Migration & Feature Grouping (Medium #13)

**Objective:** land the production structure now that layers exist.

1. Move screens into feature folders: `screens/auth/`, `screens/home/`, `screens/recipe/`, `screens/chat/`, `screens/profile/`, `screens/favorites/`, `screens/splash/`.
2. Delete the empty stubs that are being replaced by properly-placed files (or keep as placed empties ready to fill).
3. Update imports; remove dead `home_screen` import in `main.dart`.
4. Final target tree = the structure in the review §13.

**Acceptance:** `flutter analyze` clean; app builds; imports resolved; no visual change.

---

## Phase 6 — Add Dependencies & Config (High #7)

**Objective:** make the documented features *buildable* (no feature code yet).

1. `pubspec.yaml`: add `google_sign_in`, `cloud_functions`, `firebase_app_check`, `firebase_storage`, `cached_network_image`, `flutter_markdown`, `share_plus`, `shared_preferences`, `connectivity_plus`, `image_picker`. Pin versions; `flutter pub get`.
2. Bundle Poppins font files under `assets/fonts/` and declare in `pubspec`.
3. Add responsive helper (`core/utils/responsive.dart`) + max-content-width for tablets.
4. Tighten `analysis_options.yaml`: `use_build_context_synchronously`, `prefer_const_constructors`, etc.
5. Land `firestore.rules` / `storage.rules` / `firestore.indexes.json` from the backend doc (deploy to **dev** project).

**Acceptance:** `flutter pub get` succeeds; app still builds and looks identical; rules deployed to dev.

---

## Phase 7 — Verification & Guardrails

1. `flutter analyze` → target zero warnings.
2. Visual diff Splash + Login against Phase 0 screenshots — must match (except intended Splash bg).
3. Add a widget test that pumps `MaterialApp` and asserts Login renders (regression guard).
4. Grep guard: **no `Color(0x…)`, no raw asset path, no magic radius/size in `screens/`** — all via tokens.
5. Update `README`/docs to describe the new structure.

**Acceptance:** builds clean, looks the same, structure matches target, tokens enforced.

---

## Sequencing & Dependencies

```
Phase 0  (safety net)
   └─ Phase 1  (tokens)              ← additive, zero risk
        └─ Phase 2  (theme)          ← first intended visual reconciliation
             └─ Phase 3  (widgets + validators)
                  └─ Phase 4  (providers/repos/router/models/splash gate)
                       └─ Phase 5  (folder migration)
                            └─ Phase 6  (deps + rules + responsive)
                                 └─ Phase 7  (verify)
```

Each phase is independently committable and leaves a working app. **Stop points** after Phase 2 (design system done) and Phase 4 (architecture done) are natural review checkpoints.

---

## What This Plan Deliberately Does NOT Do (yet)

- No new features (auth logic, AI calls, Home rebuild, Recipe Detail) — those come *after* the foundation, filling the now-correct stubs.
- No redesign — only consolidation of existing values into tokens.
- No backend feature code — only rules/indexes/config from the backend doc.

---

## Effort Estimate (rough)

| Phase | Scope | Est. |
|---|---|---|
| 0 | Safety net | 0.5h |
| 1 | Tokens | 2–3h |
| 2 | Theme reconcile + font | 2h |
| 3 | Widgets + validators | 3–4h |
| 4 | Providers/repos/router/models/splash | 4–6h |
| 5 | Folder migration | 1–2h |
| 6 | Deps + rules + responsive | 2–3h |
| 7 | Verify + tests | 2h |
| **Total** | **Foundation only** | **~16–22h** |

After this, the 10 empty stubs get filled feature-by-feature (auth → home → AI generator → recipe detail → favorites/saved → profile → chat), each landing on a correct, consistent foundation.

---

## Open Items to Confirm Before Starting

1. **Splash background correction** to `#F6F2EE` (align to Login/brand) — OK? (Only intentional visual change.)
2. **Consolidate `CustomButton` → `PrimaryButton`** and route `home_screen`'s button through it — OK to unify the two button looks?
3. **Router choice:** `onGenerateRoute` (recommended, low churn) vs. `go_router`. Default: `onGenerateRoute`.
4. **Dependency versions:** pin latest stable at implementation time — any version constraints from your side?
