# AI Recipe Generator — Backend Architecture Document

**Version:** 1.0 (initial draft)
**Status:** Design — pre-implementation. No application code should be written until §17 open decisions are signed off.
**Scope:** Firebase (Auth, Firestore, Storage, App Check, Cloud Functions) + Google Gemini integration for a Flutter (Android-first) client.

> This document fills the gap identified in the pre-implementation review: the file previously named `backend artcitecture.pdf` was a duplicate of the UI/UX brief, so no backend architecture existed. This is the real one. It is the single source of truth for data modeling, security, the AI path, cost control, and offline behavior. Where the PRD/TRD/AFD/UX conflict, **this document wins for backend concerns.**

---

## 1. Design Principles

1. **The Gemini key never ships in the app.** All AI calls go through a trusted server (Cloud Functions). The client holds no third-party secret.
2. **Least-privilege data access.** A user can read/write only their own data. Rules enforce this server-side; the client is never trusted.
3. **The database can hold everything the UI displays.** The schema is derived from the screens, not the other way around.
4. **Typed, contract-based AI.** Gemini returns validated JSON, never free text the app has to scrape.
5. **Bounded cost.** Every AI call and every hot query has a ceiling (rate limits, quotas, cached feeds).
6. **Offline-tolerant reads.** Saved/favorited content is available without a connection; only generation requires the network, and that boundary is explicit.
7. **Snapshots over joins.** Firestore has no joins; we denormalize deliberately and document every counter.

---

## 2. Resolved Decisions (previously ambiguous across documents)

These resolve the contradictions found in the review. Each is a **recommended default** — change before implementation if you disagree, but do not leave them open.

| # | Ambiguity | Decision | Rationale |
|---|---|---|---|
| D1 | AI tab = Chat or Generator? | The bottom-nav **AI tab opens an "AI Hub"** with two segmented modes: **Generate** (structured recipe) and **Chat** (free conversation). One tab, two modes. | Satisfies both PRD §11 and §12 without a 6th tab; keeps the "AI is the centerpiece" mandate. |
| D2 | Favorites vs. Saved | **Favorite** = a bookmark toggle on *any* recipe (curated or generated). **Saved** = recipes the user *generated with AI* and explicitly kept. Both live under the user; a recipe can be both. | Gives each tab a distinct, explainable purpose. |
| D3 | Where do generated recipes live? | In the user's **`generatedRecipes` subcollection only** (private). They are **not** written to the global `recipes` collection. | Avoids polluting curated content with unvetted AI output and avoids moderation of a public corpus in v1. |
| D4 | Favorite referencing a recipe that may not exist | A favorite stores a **full embedded snapshot** of the recipe, not just an ID. | Works offline, survives deletion of the source, no dangling references, no join. |
| D5 | Home content source (Popular/Trending/Featured/Daily) | A **single cached `home_feed` document** per locale, rebuilt on a schedule by a Cloud Function from the curated `recipes` collection. | Bounds Home to ~1 read per open instead of 6+ live queries; consistent and cacheable. |
| D6 | Recipe images | Curated recipe images are **URLs** (from a copyright-free source, stored as a field). Only **profile photos** use Firebase Storage in v1. | Keeps Storage surface tiny; avoids hosting a food-image library in v1. |
| D7 | Gemini access path | **Client → Callable Cloud Function → Gemini.** App Check required. | Only way to hide the key, rate-limit per user, and moderate. |

---

## 3. High-Level Architecture

```
┌─────────────────────────────────────────────┐
│              Flutter Android App             │
│  Screens → Providers → Repositories          │
│         (no Firebase/Gemini SDK in widgets)  │
└───────┬───────────────┬─────────────┬────────┘
        │ Auth SDK      │ Firestore   │ HTTPS Callable
        │               │ SDK (rules) │ (+App Check token)
        ▼               ▼             ▼
┌──────────────┐ ┌──────────────┐ ┌───────────────────────┐
│ Firebase     │ │  Cloud       │ │  Cloud Functions       │
│ Auth         │ │  Firestore   │ │  - generateRecipe()    │
│ (Email,      │ │  (+ rules,   │ │  - chat()              │
│  Google)     │ │   indexes)   │ │  - onRecipeCounters()  │
└──────────────┘ └──────────────┘ │  - rebuildHomeFeed()   │
                 ┌──────────────┐ │  - onUserCreate()      │
                 │ Firebase     │ └──────────┬────────────┘
                 │ Storage      │            │ server-side key
                 │ (avatars)    │            ▼
                 └──────────────┘   ┌──────────────────┐
                                     │  Gemini API      │
                                     │ (Vertex/AI Studio)│
                                     └──────────────────┘
```

**Layering rule (client):** Widgets never touch `FirebaseFirestore`, `FirebaseAuth`, or HTTP directly. `Providers` hold UI state; `Repositories` wrap the SDKs; `Services` are thin SDK clients. This satisfies PRD §22 ("no setState for business logic") and makes the AI path swappable.

---

## 4. Firebase Project & Environment Strategy

- **Two Firebase projects:** `ai-recipe-generator-dev` and `ai-recipe-generator-prod`. The repo currently has one (`ai-recipe-generator-db27c`); designate it **dev** and create prod before launch.
- Flutter build flavors (`dev`, `prod`) select the matching `firebase_options.dart` / `google-services.json`.
- Gemini key, quotas, and Function config differ per environment and live in **Function environment config / Secret Manager**, never in the repo.
- **App Check:** Play Integrity provider enabled in prod; debug provider in dev. Enforced on Firestore, Storage, and all Callable Functions.

---

## 5. Authentication Architecture

**Providers:** Email/Password, Google.

**Flows the client must implement (many missing from the AFD):**

| Flow | Behavior |
|---|---|
| Register (email) | Create account → **send verification email** → allow app use but show an unverified banner; gate nothing hard in v1 except (optionally) AI generation. |
| Login (email) | Standard; map Firebase error codes to friendly messages (§13). |
| Google sign-in | Handle **user cancellation** (no error toast) and **`account-exists-with-different-credential`** → prompt to link. |
| Account linking | Email account + later Google with same address → `linkWithCredential`. |
| Forgot password | `sendPasswordResetEmail` → success snackbar → back to login. |
| Re-authentication | Required before change-password, change-email, **delete account**. |
| Delete account | Re-auth → delete Firestore user tree (Function, §11) → delete Storage avatar → `user.delete()`. **Play Store requires this.** |
| Logout | `signOut()` → clear providers → Login; back stack cleared. |
| "Remember Me" | Firebase persists sessions by default. "Remember Me" only controls whether we **pre-fill the email** via `shared_preferences`; it does **not** change session persistence. |

**On first sign-in** a Cloud Function (`onUserCreate`) writes the `/users/{uid}` document (§6).

---

## 6. Firestore Data Model

Notation: `/collection/{docId}`. Subcollections nest under a document. All timestamps are Firestore `Timestamp` (server-set).

### 6.1 `/users/{uid}`
```
uid: string            // == auth uid
name: string
email: string
photoUrl: string|null
provider: string       // 'password' | 'google'
emailVerified: bool
createdAt: timestamp
updatedAt: timestamp
// denormalized counters (maintained by Functions, §7)
favoritesCount: number
generatedCount: number
// preferences
settings: {
  notificationsEnabled: bool
  language: string      // 'en' (v1 is en-only; field reserved)
  darkMode: bool        // reserved for future; UI stays light in v1
}
```

**Subcollections of a user (all private to that user):**

#### `/users/{uid}/favorites/{favoriteId}`
Embedded snapshot (D4):
```
favoriteId: string
recipe: Recipe          // full embedded object, see 6.3
sourceType: string      // 'curated' | 'generated'
sourceRecipeId: string|null  // reference back if curated
createdAt: timestamp
```

#### `/users/{uid}/generatedRecipes/{genId}`
```
genId: string
recipe: Recipe          // full embedded object
prompt: string          // the user prompt that produced it
model: string           // e.g. 'gemini-2.x'
chatId: string|null     // if produced inside a chat
createdAt: timestamp
```

#### `/users/{uid}/chats/{chatId}`
```
chatId: string
title: string           // derived from first user message
createdAt: timestamp
updatedAt: timestamp
messageCount: number
```

#### `/users/{uid}/chats/{chatId}/messages/{messageId}`
```
messageId: string
role: string            // 'user' | 'model'
text: string            // markdown allowed for model
createdAt: timestamp
tokens: number|null     // for cost tracking
```
Messages are **paginated** (page size 30, ordered by `createdAt`).

### 6.2 `/recipes/{recipeId}` (curated, global, read-only to clients)
```
recipeId: string
title: string
description: string
imageUrl: string
category: string        // 'breakfast'|'lunch'|... (enum, §6.4)
cookingTimeMinutes: number
difficulty: string      // 'easy'|'medium'|'hard'
servings: number
calories: number
nutrition: { protein: number, carbs: number, fat: number, fiber: number }  // grams
ingredients: [ { name: string, quantity: string } ]
instructions: [ string ]
tips: [ string ]
tags: [ string ]
popularityScore: number   // drives "Popular"
trendingScore: number     // time-decayed, drives "Trending"
isFeatured: bool
createdAt: timestamp
updatedAt: timestamp
```
Written only by admins/seed scripts/Functions — **never by the client** (enforced in rules).

### 6.3 `Recipe` (embedded shape)
The object embedded in favorites/generated recipes uses the **same field set as 6.2** minus the ranking fields (`popularityScore`, `trendingScore`, `isFeatured`). This is the **canonical shape the Recipe Detail screen binds to**, and it now contains difficulty, nutrition, servings, and tips — the fields the review flagged as missing from the old model.

### 6.4 `/home_feed/{locale}` (D5)
```
locale: string            // 'en'
popular:   [ RecipeRef ]  // ordered
trending:  [ RecipeRef ]
featured:  [ RecipeRef ]
daily:     RecipeRef       // daily recommendation
categories:[ { key, label, iconKey } ]
rebuiltAt: timestamp
```
`RecipeRef` = a lightweight card projection `{ recipeId, title, imageUrl, cookingTimeMinutes, calories, category }` so Home renders from one document without reading each full recipe.

### 6.5 Enums (documented, validated in rules where cheap)
- `category`: `breakfast, lunch, dinner, desserts, snacks, healthy, vegan, drinks`
- `difficulty`: `easy, medium, hard`
- `sourceType`: `curated, generated`
- `role`: `user, model`

---

## 7. Relationships, Counters & Consistency

- **No client-side counting.** `favoritesCount` / `generatedCount` on `/users/{uid}` are maintained by Firestore-triggered Functions (`onFavoriteWrite`, `onGeneratedWrite`) so the Profile screen reads one document, not a `count()` over a subcollection.
- **Favorite ↔ recipe:** favorites embed a snapshot (D4). If a curated recipe changes later, existing favorites keep the snapshot they were saved with (acceptable and expected for a bookmark).
- **Generated ↔ chat:** a generated recipe optionally carries `chatId` linking back to the conversation that produced it.
- **Account deletion** cascades via a Function that recursively deletes the user's subcollections (Firestore does not cascade automatically).

---

## 8. Security Rules (`firestore.rules`)

Complete starting rule set. This is the security posture the review found entirely absent.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() { return request.auth != null; }
    function isOwner(uid) { return isSignedIn() && request.auth.uid == uid; }
    function appCheckOk() { return request.app != null; } // App Check enforced

    // Curated recipes: readable by any signed-in user, never client-writable.
    match /recipes/{recipeId} {
      allow read: if isSignedIn() && appCheckOk();
      allow write: if false; // only Admin SDK / Functions
    }

    // Home feed: read-only to clients.
    match /home_feed/{locale} {
      allow read: if isSignedIn() && appCheckOk();
      allow write: if false;
    }

    // User document.
    match /users/{uid} {
      allow read: if isOwner(uid) && appCheckOk();
      // Client may update only profile/settings fields; counters are Function-only.
      allow update: if isOwner(uid) && appCheckOk()
        && !request.resource.data.diff(resource.data).affectedKeys()
             .hasAny(['favoritesCount','generatedCount','createdAt','uid','email']);
      allow create: if false; // created by onUserCreate Function
      allow delete: if false; // deletion handled by Function

      match /favorites/{favId} {
        allow read, write: if isOwner(uid) && appCheckOk();
      }
      match /generatedRecipes/{genId} {
        allow read: if isOwner(uid) && appCheckOk();
        allow write: if false; // written only by generateRecipe Function
      }
      match /chats/{chatId} {
        allow read, create, update, delete: if isOwner(uid) && appCheckOk();
        match /messages/{msgId} {
          allow read: if isOwner(uid) && appCheckOk();
          // user messages client-writable; model messages Function-only.
          allow create: if isOwner(uid) && appCheckOk()
                        && request.resource.data.role == 'user';
          allow update, delete: if false;
        }
      }
    }
  }
}
```

Notes:
- Generated recipes and model chat messages are **Function-written** so unvetted/AI content cannot be forged client-side.
- Counters are explicitly excluded from client updates.
- Every rule requires App Check, blocking scripted abuse of the database.

---

## 9. Storage Layout & Rules (`storage.rules`)

Only user avatars in v1 (D6).

```
avatars/{uid}/profile.jpg
```

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /avatars/{uid}/{file} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.auth.uid == uid
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

Client uploads via `image_picker` → resize client-side → upload → put resulting URL in `users/{uid}.photoUrl`.

---

## 10. Required Indexes

| Query | Index |
|---|---|
| Chats by recency | `chats`: `createdAt desc` (single-field, automatic) |
| Messages paginated | `messages`: `createdAt asc` (automatic) |
| Favorites by recency | `favorites`: `createdAt desc` (automatic) |
| Generated by recency | `generatedRecipes`: `createdAt desc` (automatic) |
| Curated recipes by category + popularity (admin/feed builder) | composite: `recipes` `category asc, popularityScore desc` |
| Trending feed builder | composite: `recipes` `trendingScore desc, updatedAt desc` |

Client Home reads the prebuilt `home_feed` doc, so it needs **no** composite indexes — the composites are only for the server-side feed builder. Commit `firestore.indexes.json` to the repo.

---

## 11. Cloud Functions

All Callable Functions **enforce App Check and auth**, and rate-limit per user.

| Function | Trigger | Responsibility |
|---|---|---|
| `onUserCreate` | Auth `onCreate` | Create `/users/{uid}` with defaults + zeroed counters. |
| `generateRecipe` | HTTPS Callable | Validate prompt → call Gemini (JSON mode) → validate output → moderate → write to `/users/{uid}/generatedRecipes` → return typed recipe. |
| `chat` | HTTPS Callable | Append user msg (client already wrote it) → call Gemini with system prompt + history window → write `model` message → return text. |
| `onFavoriteWrite` | Firestore trigger on `favorites/{id}` | Increment/decrement `favoritesCount`. |
| `onGeneratedWrite` | Firestore trigger on `generatedRecipes/{id}` | Maintain `generatedCount`. |
| `rebuildHomeFeed` | Scheduled (e.g. hourly) | Recompute `popularityScore`/`trendingScore`, rebuild `/home_feed/{locale}`. |
| `deleteAccount` | HTTPS Callable | Recursively delete user subtree + avatar after re-auth. |

**Rate limiting:** maintain a per-user rolling counter (Firestore doc or Redis/Memorystore if scale demands) — e.g. **20 AI calls/hour, 200/day**. Exceed → return `resource-exhausted`; client shows a friendly limit message.

---

## 12. Gemini Integration Contract

### 12.1 Model & config
- Model: pin an explicit current Gemini model id in Function config (do not hardcode "Gemini API" — pin the version so behavior is reproducible; upgrade deliberately).
- `responseMimeType: application/json` + response schema (JSON mode).
- `timeout`: 20s; **retry** once on 5xx with exponential backoff; surface `deadline-exceeded` otherwise.

### 12.2 System prompt (server-side, never client-editable)
> "You are a professional cooking assistant for the AI Recipe Generator app. You ONLY help with cooking, recipes, ingredients, nutrition estimates, and meal planning. If asked anything outside cooking, politely decline. Never give unsafe food advice; when relevant, note food-safety cautions (e.g., safe internal temperatures) and allergen warnings. Nutrition values are ESTIMATES. Respond in the required JSON schema."

### 12.3 Recipe JSON schema (what `generateRecipe` returns)
Matches the embedded `Recipe` shape (§6.3): `title, description, imageUrl(optional/null), category, cookingTimeMinutes, difficulty, servings, calories, nutrition{protein,carbs,fat,fiber}, ingredients[], instructions[], tips[]`. The Function **rejects and retries once** if Gemini output fails schema validation; on second failure returns `invalid-response` (client shows retry, §13).

### 12.4 Chat
Free-form markdown text response, constrained by the same system prompt. History window: last N messages (e.g. 12) to bound tokens.

---

## 13. Error Handling Matrix

Every async surface maps a failure to a defined user experience.

| Source | Condition | Client behavior |
|---|---|---|
| Network | No connectivity | Offline banner; cached favorites/saved still viewable; AI disabled with "needs connection." |
| Auth | wrong-password / user-not-found / weak-password / email-already-in-use / invalid-email | Field-level or snackbar friendly message; never raw Firebase codes. |
| Auth | Google canceled | Silent, no error. |
| Firestore | permission-denied / unavailable | "Something went wrong" + retry; log to Crashlytics. |
| Gemini | timeout / deadline-exceeded | Retry button; keep prompt. |
| Gemini | resource-exhausted (rate limit / quota) | "You've reached today's AI limit" message. |
| Gemini | invalid-response (schema fail) | "Couldn't build that recipe — try rephrasing," retry. |
| Gemini | blocked (safety/off-topic) | Show the model's polite decline; no crash. |
| Storage | upload failed / too large / wrong type | Inline error on avatar picker. |

Per-screen **loading / empty / error / success** states must be defined for every screen in a companion UI-states matrix (owned by the UI/UX doc; referenced here as a dependency).

---

## 14. Offline & Caching Strategy

- **Firestore offline persistence:** enabled (default on mobile). Favorites, saved recipes, profile, and last chats are readable offline.
- **Images:** `cached_network_image` with disk cache; request downsized images via `cacheWidth`.
- **Home feed:** cached document + client memory cache; show last-known feed offline with a "last updated" note.
- **Writes offline:** favorites toggles queue and sync (Firestore handles this); AI generation/chat require connectivity and are gated with a clear message.
- **Fonts:** bundle Poppins as an asset (do not runtime-fetch via `google_fonts`) to protect cold-start and offline launch.

---

## 15. Cost, Abuse & Observability

- **App Check** on Firestore/Storage/Functions blocks non-app clients.
- **Per-user AI rate limits + daily quotas** (§11) cap Gemini spend.
- **Home feed** caps Firestore reads at ~1/open regardless of user count.
- **Crashlytics** + **Analytics** (screen views, AI generations, saves, errors) for production visibility.
- **Budget alerts** on the Gemini/GCP billing account.
- Log AI token usage per call (`tokens` fields) for cost attribution.

---

## 16. New Dependencies Implied by This Architecture

The current `pubspec.yaml` cannot perform Google auth or AI calls. This architecture requires adding (exact versions chosen at implementation time):

`google_sign_in`, `cloud_functions` (Callable), `firebase_app_check`, `firebase_storage`, `cached_network_image`, `flutter_markdown` (chat), `share_plus` (Share), `shared_preferences` (Remember-Me prefill), `connectivity_plus` (offline), `image_picker` (avatar). Gemini is called **server-side**, so no Gemini client package is needed in the Flutter app — a deliberate consequence of D7.

---

## 17. Open Decisions Requiring Owner Sign-Off

These I could not responsibly default; they change scope or cost:

1. **Curated content source.** Seed a hand-authored `recipes` set, pull from a licensed recipe API, or launch AI-only (Home shows generated/sample content)? Affects whether §6.2 and the feed builder are needed for v1.
2. **Gemini platform.** Vertex AI (GCP-native, enterprise quotas) vs. Gemini Developer API (simpler). Affects auth/config in Functions.
3. **Cloud Functions billing.** Functions require the Blaze (pay-as-you-go) plan. Confirm budget.
4. **AI gating for unverified emails.** Allow AI generation before email verification, or require it? (Anti-abuse vs. friction.)
5. **Nutrition accuracy.** Ship AI-estimated nutrition (labeled) for v1, or integrate a nutrition API later? Item flagged in the review for food/fitness users.
6. **Rate-limit numbers.** The 20/hour, 200/day defaults are placeholders — confirm against expected usage and budget.

---

## 18. Build Order (backend)

1. Provision prod project + App Check + Blaze; designate dev.
2. Land `firestore.rules`, `storage.rules`, `firestore.indexes.json` (deny-by-default first).
3. `onUserCreate` + user document shape.
4. `generateRecipe` + `chat` Functions with the Gemini contract (§12) and rate limiting.
5. Counter + feed-builder Functions.
6. Seed/curate `recipes` (pending decision #1).
7. Client repositories/providers wire to the above.

---

*End of Backend Architecture v1.0. This document should be reviewed alongside the PRD/TRD/AFD/UX and the open decisions in §17 resolved before backend implementation begins.*
