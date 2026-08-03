# AI Recipe Generator — Full Project Completion Plan

**Last updated:** 2026-07-10
**Purpose:** A single roadmap from the current state (clean foundation, ~10% built) to a production-ready, launchable app. Plan only — no code.
**Guiding rules:**
- Preserve branding (warm brown `#8B5E3C`, cream `#F6F2EE`, logo, login design language).
- Every screen consumes design tokens — no hardcoded UI values.
- No business logic in widgets — Providers → Repositories → Services.
- Each milestone leaves the app compiling and demoable.
- Resolve the 6 open decisions (see §Decision Gates) before the backend/AI milestones.

---

## 0. Where We Are

- ✅ **Foundation done:** design tokens, theme, reusable widgets, models, validators, error mapping (Phases 0–3). Verified: analyze clean (1 legacy warning), 3/3 tests pass.
- ⏳ **Not wired in yet:** the new widgets/models are additive; screens still use legacy code.
- ❌ **Not started:** app architecture (providers/router), all features, all backend/AI wiring.

The plan below continues from here.

---

## Milestone Map (overview)

| # | Milestone | Outcome | Depends on | Est. |
|---|---|---|---|---|
| M1 | App Architecture | Providers, router, repositories, DI wired | Foundation | 4–6h |
| M2 | Folder Migration & Deps | Production structure, all packages added | M1 | 3–4h |
| M3 | Backend Setup | Firebase rules/indexes/App Check deployed; Functions scaffolded | Decisions 2,3 | 6–10h |
| M4 | Authentication | Full email + Google auth, all flows | M1, M3 | 8–12h |
| M5 | Home Screen | Documented Home with real/curated content | M4, Decision 1 | 8–12h |
| M6 | AI Recipe Generator | Prompt → Gemini (via Function) → typed recipe | M3, M4 | 10–14h |
| M7 | Recipe Detail | Full detail screen + save/favorite/share | M5, M6 | 6–8h |
| M8 | Favorites & Saved | Both collections, list/search/filter/delete | M7 | 6–8h |
| M9 | AI Chat | Conversational assistant with history | M3, M6 | 8–10h |
| M10 | Search & Categories | Search + category browsing | M5 | 5–7h |
| M11 | Profile & Settings | Profile, edit, settings, account deletion | M4, M8 | 6–8h |
| M12 | Cross-cutting Polish | Offline, caching, a11y, performance, animations | M5–M11 | 8–12h |
| M13 | Testing & QA | Unit/widget/integration tests, device matrix | all | 10–14h |
| M14 | Production Readiness | Analytics, crash reporting, privacy, store assets | M13 | 8–12h |
| M15 | Launch | Signed release, Play Store submission | M14 | 4–6h |

**Rough total (post-foundation):** ~110–160 hours.

---

## M1 — App Architecture

**Goal:** stand up the layers so features have a home. No feature logic yet.

**Tasks**
- Create `app/app.dart` (move `RecipeGeneratorApp` out of `main.dart`); `main.dart` = bootstrap only.
- `app/router/app_router.dart` using `onGenerateRoute` with typed arguments; register all routes (splash, login, register, forgot-password, home, recipe detail, favorites, saved, chat, profile, settings).
- Providers: `AuthProvider`, `RecipeProvider`, `ChatProvider` (state + method stubs) registered via `MultiProvider`.
- Repositories (interfaces + impl stubs): `AuthRepository`, `RecipeRepository`, `ChatRepository`, `UserRepository`.
- Services: `AuthService`, `FirestoreService`, `GeminiService` (callable wrapper) — signatures only.
- Splash: replace fixed timer-to-login with auth-state gate (`authStateChanges`), `mounted`-guarded.
- Migrate Login & Register onto `AppTextField` / `PrimaryButton` / `GoogleButton` / `OrDivider`; wrap Login in a `Form` with validators.

**Acceptance:** app boots via new router + providers; logged-out user lands on Login exactly as before; legacy `custom_button`/`custom_textfield` + last `withOpacity` warning removed; analyze clean.

---

## M2 — Folder Migration & Dependencies

**Goal:** production structure + all packages present (no feature code).

**Tasks**
- Group screens into feature folders (`auth/`, `home/`, `recipe/`, `chat/`, `profile/`, `favorites/`, `splash/`).
- Remove legacy duplicates (`utils/validators.dart`, old widgets); fix imports.
- Add packages: `google_sign_in`, `cloud_functions`, `firebase_app_check`, `firebase_storage`, `cached_network_image`, `flutter_markdown`, `share_plus`, `shared_preferences`, `connectivity_plus`, `image_picker`.
- Bundle Poppins `.ttf` under `assets/fonts/`; switch off runtime font fetch.
- Add responsive helper (breakpoints + max content width).
- Tighten `analysis_options.yaml` (`use_build_context_synchronously`, const lints).

**Acceptance:** `flutter pub get` succeeds; app builds and looks identical; folder tree matches the target structure.

---

## M3 — Backend Setup

**Goal:** the server-side foundation from the Backend Architecture doc.
**Requires decisions 2 (Gemini platform) & 3 (Blaze billing).**

**Tasks**
- Create **prod** Firebase project; designate existing as **dev**; add build flavors.
- Deploy `firestore.rules`, `storage.rules`, `firestore.indexes.json` (deny-by-default first).
- Enable App Check (debug in dev, Play Integrity in prod) on Firestore/Storage/Functions.
- Scaffold Cloud Functions: `onUserCreate`, `generateRecipe`, `chat`, `onFavoriteWrite`, `onGeneratedWrite`, `rebuildHomeFeed`, `deleteAccount`.
- Configure Gemini key in Function env/Secret Manager (never in app).
- Set per-user rate limits + quotas; billing budget alerts.

**Acceptance:** rules deployed to dev; a test Function callable succeeds with App Check; no key in the client.

---

## M4 — Authentication

**Goal:** complete, robust auth per backend doc §5.

**Tasks**
- `AuthRepository` + `AuthService`: email sign-in/up, Google sign-in, sign-out, password reset.
- `AuthProvider`: state (loading/authenticated/error), exposes actions to UI.
- Wire Login, Register, Forgot Password screens to the provider; full validation; loading + error states via `AppErrorView`/snackbars using `ErrorMapper`.
- Flows: email verification email on register; Google cancellation handling; account linking (`account-exists-with-different-credential`); re-auth; "Remember Me" email prefill.
- `onUserCreate` writes the user document; app reads `UserModel`.

**Acceptance:** a new user can register (email + Google), log in, reset password, and stay logged in across restarts; all error codes show friendly messages; Splash routes on real auth state.

---

## M5 — Home Screen

**Goal:** the documented Home (visual centerpiece).
**Requires decision 1 (content source).**

**Tasks**
- Build sections: greeting, search bar (entry point), AI Generator card (highlighted), categories, popular, trending, daily recommendation, featured.
- Consume the cached `home_feed` document (or chosen content source) via `RecipeProvider`.
- Skeleton loading states; empty/error states; pull-to-refresh.
- `rebuildHomeFeed` Function populates the feed (if curated content chosen).
- Bottom Navigation shell (5 tabs, AI tab highlighted) hosting Home/Favorites/AI/Saved/Profile.

**Acceptance:** Home renders from one feed read, all rails populated, responsive on phone/tablet, matches the design language.

---

## M6 — AI Recipe Generator (core feature)

**Goal:** prompt → typed recipe, safely.

**Tasks**
- AI Hub tab with Generate mode (segmented with Chat per decision D1).
- Input (ingredients or natural-language prompt) with `Validators.aiPrompt`.
- `RecipeRepository.generate()` calls the `generateRecipe` Function; returns a typed `Recipe`.
- Server: system prompt + JSON schema, food-safety guardrails, nutrition-as-estimate labeling, moderation, retry/validation, rate limits.
- UI: generating state, result rendered into Recipe Detail, error/retry/limit states.
- Save generated recipe to `generatedRecipes`.

**Acceptance:** a prompt reliably returns a structured recipe; malformed/blocked/timeout/limit cases show correct UX; no crash on unexpected AI output.

---

## M7 — Recipe Detail

**Goal:** full detail screen for curated and generated recipes.

**Tasks**
- Bind to the `Recipe` model: large image, title, time, difficulty, servings, calories, ingredients, instructions, nutrition, AI tips.
- Actions: Favorite (toggle), Save, Share (`share_plus`).
- Cached images (`cached_network_image`); image error fallback; responsive layout.
- Reachable via typed route args from Home/Search/Generator.

**Acceptance:** detail renders every documented field for both recipe sources; favorite/save/share work; no overflow on any device size.

---

## M8 — Favorites & Saved

**Goal:** both collections with management.

**Tasks**
- Favorites: embedded snapshot writes (per D4); list with `RecipeCard`; search, filter, delete; empty state.
- Saved (AI-generated): list of `generatedRecipes`; open/delete.
- Counters (`favoritesCount`/`generatedCount`) via Functions; Profile reads them.
- Offline read of favorites.

**Acceptance:** favoriting anywhere reflects in Favorites; saved generated recipes persist; both searchable/filterable; counts accurate.

---

## M9 — AI Chat

**Goal:** conversational cooking assistant.

**Tasks**
- Chat UI: user/model bubbles, typing indicator, auto-scroll, markdown rendering (`flutter_markdown`).
- `ChatRepository` + `chat` Function with system prompt + history window; message pagination.
- Persist `chats`/`messages`; chat history list; scope guardrails + moderation.
- Loading/error/limit states.

**Acceptance:** multi-turn cooking conversation works, history persists and paginates, off-topic prompts are politely declined, no crash on long histories.

---

## M10 — Search & Categories

**Goal:** discovery beyond Home.

**Tasks**
- Search screen: by recipe/ingredient; recent + popular searches; debounced queries; results → Recipe Detail.
- Categories browsing (breakfast/lunch/dinner/desserts/snacks/healthy/vegan/drinks) → filtered list.
- Empty/no-results and error states.

**Acceptance:** search returns relevant results with proper states; each category lists recipes; navigation into detail works.

---

## M11 — Profile & Settings

**Goal:** account management per docs + store requirements.

**Tasks**
- Profile: avatar (`ProfileAvatar` + `image_picker` upload to Storage), name, email, saved/generated counts.
- Edit profile, change password, change photo.
- Settings: notifications toggle, language (reserved), privacy policy, terms, about; dark mode reserved.
- **Account deletion** (re-auth → `deleteAccount` Function → sign out).
- Logout (clears providers, back stack).

**Acceptance:** profile shows real data + counts; avatar upload works; account can be deleted end-to-end; logout returns to Login with cleared stack.

---

## M12 — Cross-cutting Polish

**Goal:** production quality across all screens.

**Tasks**
- Offline: Firestore persistence, cached favorites, "needs connection" gating for AI, offline banner (`connectivity_plus`).
- Caching: images + home feed; bundle fonts (if not already).
- Accessibility: verified contrast ratios, 48dp targets, `Semantics` labels on icon-only buttons, text scaling.
- Performance: extract large build methods, `const`, list virtualization/pagination, image `cacheWidth`, minimize rebuilds.
- Animations: fade/slide/hero/page transitions/button press/loading/typing per docs (subtle, non-distracting).
- Responsive pass: small/medium/large phones + tablets; zero overflow.

**Acceptance:** smooth on low-end devices, no overflow anywhere, a11y checks pass, consistent motion.

---

## M13 — Testing & QA

**Goal:** confidence before release.

**Tasks**
- Unit tests: validators, model `fromJson`/`toJson`, error mapper, repositories (mocked).
- Widget tests: key screens (auth, home, recipe detail, chat) render + states.
- Integration test: core journey (login → generate → save → view → logout).
- Manual device matrix (small phone → tablet); edge cases from the review (bad AI output, offline, empty states).
- Token-enforcement guard (no hardcoded colors/paths in screens).

**Acceptance:** test suite green in CI; device matrix passes; known edge cases handled.

---

## M14 — Production Readiness

**Goal:** everything a real launch needs beyond features.

**Tasks**
- Crashlytics + Analytics (screen views, AI generations, saves, errors).
- Dev↔prod separation verified; secrets only server-side.
- Force-update / min-version check.
- Privacy Policy + Terms content (required: accounts + AI); GDPR data export/delete.
- Play Store assets: icon, feature graphic, screenshots, description; content rating; data-safety form.
- Final security review (rules, App Check, rate limits).

**Acceptance:** analytics/crash reporting live; legal pages published; store listing complete; security review signed off.

---

## M15 — Launch

**Goal:** ship.

**Tasks**
- Signed release build (Android App Bundle); ProGuard/R8 config verified.
- Internal → closed → open testing tracks; smoke test the release build.
- Submit to Play Store; monitor first-day crash/error dashboards.
- Tag release; update docs/README.

**Acceptance:** app live on Play Store; monitoring green.

---

## Decision Gates (must resolve before dependent milestones)

| # | Decision | Blocks |
|---|---|---|
| 1 | Curated content source (seed vs. API vs. AI-only) | M5, M7, M10 |
| 2 | Gemini platform (Vertex AI vs. Developer API) | M3, M6, M9 |
| 3 | Cloud Functions billing (Blaze plan) | M3 onward |
| 4 | AI gating for unverified emails | M4, M6 |
| 5 | Nutrition accuracy (AI estimate vs. nutrition API) | M6, M7 |
| 6 | AI rate-limit numbers | M3, M6, M9 |

---

## Cross-cutting Workstreams (run continuously)

- **Design-system fidelity:** every new screen uses tokens; periodic grep guard.
- **Error/empty/loading states:** every async surface gets all three (per backend doc §13).
- **Security:** rules updated as collections evolve; App Check always on.
- **Docs:** keep `project_status.md` updated per milestone.

---

## Suggested Build Order (critical path)

```
Foundation ✅ → M1 → M2 → M3 → M4 → M5 → M6 → M7 → M8 → M11
                                      ↘ M9 (after M6) ↘ M10 (after M5)
→ M12 → M13 → M14 → M15
```

M9 (Chat) and M10 (Search/Categories) can run in parallel with later feature milestones once their dependencies are met.

---

## Definition of Done (whole project)

- All documented screens implemented, responsive, token-driven, with loading/empty/error states.
- Auth (email + Google) + AI generation + AI chat working end-to-end via secure Functions.
- Firestore rules + App Check + rate limits enforced; no secrets in client.
- Offline-tolerant reads; cached images; bundled fonts.
- Analytics + crash reporting live; privacy/terms published; account deletion works.
- Test suite green; device matrix passes.
- Signed release on Play Store with monitoring.
