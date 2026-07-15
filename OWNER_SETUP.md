# Owner Setup & Deployment Steps

Console/CLI tasks only the project owner can do. The **code is done** for all of
these — these steps just flip the Firebase console switches.

Firebase project: **`ai-recipe-generator-db27c`** · console: <https://console.firebase.google.com>

---

## 1. Gemini API key → Remote Config (so AI works from the cloud)

Without this, the app falls back to the local `env.json` key (fine for dev, but
not for a deployed build). You can reuse the **same key value** that's already in
your local `env.json` — no need to generate a new one.

1. Firebase console → your project → left menu **Run → Remote Config**.
2. **Add parameter**:
   - Parameter key: `gemini_api_key`
   - Default value: *(paste your Gemini key — same one from `env.json`)*
3. (Optional) Add another parameter:
   - Parameter key: `gemini_model`
   - Default value: `gemini-flash-latest`   ← do **not** use `gemini-2.0-flash` (0 free quota)
4. Click **Publish changes** (top right).
5. Relaunch the app. It fetches on the next cycle (min interval 1h), then uses the
   cloud key. **To change the key later: just edit + Publish — no rebuild needed.**

> Gemini key kahan se? Google AI Studio → <https://aistudio.google.com/apikey> → *Get API key*.

---

## 2. Deploy Firestore security rules (⚠️ security — currently open test-mode)

The real rules are authored in `firestore.rules` but **not deployed** — the DB is
still on open test-mode (anyone can read/write). Two ways:

**Option A — Firebase CLI (deploys rules + indexes):**
```bash
npm install -g firebase-tools          # once
firebase login                         # opens browser, sign in
cd d:/MyProjects/ai_recipe_generator
firebase deploy --only firestore:rules,firestore:indexes --project ai-recipe-generator-db27c
```

**Option B — Console (rules only, no CLI):**
1. Console → **Firestore Database → Rules** tab.
2. Open `firestore.rules` from the repo, copy everything, paste it in.
3. Click **Publish**.

---

## 3. Test FCM push notifications (free — no Blaze)

1. Run the app on a **real Android device** (emulators usually can't receive FCM).
2. In the run logs / logcat find the line: `FCM token: <long token>` — copy it.
3. Console → **Run → Messaging** → **Create your first campaign** → *Firebase
   Notification messages* → or use **Send test message**.
4. Type a Title + Body → **Send test message** → paste the FCM token → **Test**.
5. Expected:
   - App in **background/closed** → notification appears in the system tray.
   - App in **foreground** → the Home **bell** badge increments; tap it to see the
     message in the in-app inbox.

> Sending is free from the console. No server / Cloud Functions / Blaze needed —
> the app only *receives*.

---

## 4. Test Google Sign-In on device

Console side is already done (Google enabled, SHA-1 added, `google-services.json`
in `android/app/`). Just verify on-device:

1. Run the app on a device/emulator with Google Play services.
2. On Login or Register, tap **Continue with Google**.
3. Pick a Google account → the app should land on Home.
4. If it fails with a config error: re-check the debug **SHA-1** in Firebase
   (`C1:0E:2C:BE:D8:F4:4D:4D:71:3E:93:E0:ED:D9:68:C0:58:F3:3A:53`) and that the
   latest `google-services.json` is in `android/app/`.

---

## Notes / deferred (not blocking)

- **Cloud Storage**: intentionally **not used** (Firebase now needs Blaze for it).
  Avatars are stored as base64 in Firestore — free, no action needed.
- **Package name** is still the default `com.example.ai_recipe_generator`. Do **not**
  rename now — it would break the `google-services.json` / Google Sign-In. Rename
  only at a real production cutover (new Firebase app + SHA-1 + re-download config).
- **M3 / Cloud Functions** is the production path (App Check, rate limits, key never
  ships) — deferred; dev deliberately avoids Blaze.
