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

## 2. ✅ DONE — Firestore security rules deployed (2026-07-29)

The rules in `firestore.rules` are **live**; the open test-mode rules are gone.
Posture: owner-only `users/{uid}/**`, read-only `/recipes` + `/home_feed`,
deny-by-default.

Redeploy after any edit to `firestore.rules`:
```bash
firebase deploy --only firestore:rules,firestore:indexes --project ai-recipe-generator-db27c
```

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

## 5. ✅ DONE — Release signing key generated (2026-08-16)

> ⚠️ An earlier version of this file recorded this step as done on 2026-08-04.
> That was **false** — no keystore had ever been generated, and every "release"
> build until 2026-08-16 was silently signed `CN=Android Debug`, which Play
> rejects outright. Verify with the `keytool -printcert` command below rather
> than trusting a checkbox.

The key now exists and is in use:

- Keystore: `C:\Users\Urooj Shehzadi\cookmate-upload.jks` (JKS, alias `upload`,
  valid to 2054). **Not in the repo and never committed** — `android/.gitignore`
  covers `key.properties`, `*.jks`, `*.keystore`.
- Certificate: `CN=Urooj Shehzadi, OU=CookMate AI, O=CookMate AI, L=Rawalpindi`
- **SHA-1: `F0:B8:34:EB:68:A2:E4:0E:D3:F7:B7:6F:4B:9F:74:3A:99:AC:EA:20`**
- ⚠️ The store password and key password are **different**. Both live in the
  owner's password manager and in `android/key.properties` only.

`android/key.properties` (git-ignored — **never commit it**) points at it:

```properties
storePassword=<keystore password>
keyPassword=<key password — NOT the same one>
keyAlias=upload
storeFile=C:/Users/Urooj Shehzadi/cookmate-upload.jks
```

⚠️ `storeFile` needs **forward slashes** on Windows; backslashes fail in Gradle.

`android/app/build.gradle.kts` picks it up automatically; with the file absent it
silently falls back to debug signing so local `flutter run --release` keeps
working — which is exactly how the 2026-08-04 gap went unnoticed for months.

**Verify any bundle before uploading** — this is the only reliable check:

```bash
flutter build appbundle --release
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

It must print `Owner: CN=Urooj Shehzadi …`. If it says `CN=Android Debug`,
`key.properties` is missing or unreadable and Play will reject the upload.
(`keytool` exits 255 while printing a JKS warning — harmless, read the output.)

### If this clone is replaced

`key.properties` and the `.jks` live only on the owner's machine. A fresh clone
builds fine but reverts to debug signing until both are restored.

> ⚠️ Remaining: the SHA-1 above must be added in **two** places — Firebase
> (Project settings → Android app → Add fingerprint, then re-download
> `google-services.json`) **and** the Google Cloud Console API-key restriction
> (see "Renaming the Android package" below). Google Sign-In is bound to the
> signing certificate, so a release build without both is dead on sign-in *and*
> FCM, with error messages that never mention the key.

---

## Renaming the Android package — the 4-place checklist

The app ships as **`com.urooj.cookmate`** (renamed 2026-08-04). If it ever has to
change again, the name lives in **four** places. Miss one and the app still
builds, still runs, and then fails at sign-in — which is exactly what happened
during the 2026-08-04 rename.

| # | Where | What to change |
|---|---|---|
| 1 | `android/app/build.gradle.kts` | `namespace` + `applicationId` |
| 2 | `android/app/google-services.json` | Register the new app in Firebase, add **both** SHA-1s, re-download |
| 3 | `lib/firebase_options.dart` | `appId` — it is **per Android app**, so a rename invalidates it |
| 4 | **Google Cloud Console → API key restriction** | Add the new package + SHA-1 to the key's *Android apps* list |

**#4 is the one that gets missed** — it is not a Firebase setting, it is not in
`firebase-tools`, and nothing in the repo points at it. It cost a full debugging
session on 2026-08-04.

- **Symptom:** Google Sign-In fails with
  `An internal error has occurred. [ Requests from this Android client application com.urooj.cookmate are blocked. ]`
  and FCM logs `FCM Registration failed!`. **Both at once**, because both
  authenticate with the same `apiKey` from `firebase_options.dart`.
- **Neither message names the API key**, which is what makes it hard to find.
- **Fix:** [console.cloud.google.com/apis/credentials](https://console.cloud.google.com/apis/credentials?project=ai-recipe-generator-db27c)
  → the key whose *Restrictions* column reads **"Android apps"** (the other keys
  have no app restriction and cannot cause this) → **Application restrictions →
  Android apps → ADD AN ITEM** → package name + SHA-1 → **SAVE**. Add, don't
  replace. Allow ~5 minutes to propagate. No rebuild needed.
- Add the **release** keystore's SHA-1 there too, or release builds hit the same
  wall after debug builds work.

Two more consequences of any rename:

- **Old FCM tokens die.** The token is per app install, and Android treats a new
  package as a different app. Grab a fresh one from logcat; console sends to a
  stale token fail silently.
- **No in-place update** from an old install — uninstall/reinstall on test
  devices. Firestore data and accounts are unaffected (they are project-level).

---

## Notes / deferred (not blocking)

- **Cloud Storage**: intentionally **not used** (Firebase now needs Blaze for it).
  Avatars are stored as base64 in Firestore — free, no action needed.
- **Package name**: ✅ renamed to `com.urooj.cookmate` (2026-08-04) off the
  `com.example.` default, which Play will not accept. Done — see the rename
  checklist below if it ever has to change again.
- **M3 / Cloud Functions** is the production path (App Check, rate limits, key never
  ships) — deferred; dev deliberately avoids Blaze.
- **Privacy Policy + Terms URLs** are still needed for the Play Store listing (any
  app that collects an email address must link a privacy policy). Nothing in the
  code blocks on this; it is a store-listing field. Host a page anywhere public
  (GitHub Pages works) and paste the URL into the Play Console.
- **Crash reporting** is not wired. All uncaught errors funnel through
  `_reportError` in `lib/main.dart`, which currently logs — adding Crashlytics
  later is a one-line change there.
