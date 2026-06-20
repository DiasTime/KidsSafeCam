# Platform status — running camera + parent on Android, iOS, web

What is wired in code vs. what still needs a console / account / Mac action to get
both apps **fully authorized and running** on each platform. App Check is enforced
on every callable (`enforceAppCheck: true`), so each platform must attest.

## Matrix

| | Android | Web | iOS |
|---|---|---|---|
| **camera_app** | ✅ builds, runs, perms ✓, App Check (PlayIntegrity/debug) | ⚠️ not a real target; App Check wired (reCAPTCHA) if built | 🍎 code-ready; needs Mac + Apple setup |
| **parent_app** | ✅ builds, runs, mic perm ✓, App Check | ✅ runs; App Check (reCAPTCHA) — needs real site key | 🍎 code-ready; needs Mac + Apple setup |

## Done in code (this branch)
- Auth: fixed `Future already completed` on sign-in/up (AutoDispose guard).
- Firestore: added `devices` + `pairingCodes` composite indexes (deployed live).
- App Check wired for **all platforms** in both apps:
  - Android — `AndroidPlayIntegrityProvider` (release) / `AndroidDebugProvider` (debug)
  - iOS — `AppleDeviceCheckProvider` (release) / `AppleDebugProvider` (debug)
  - Web — `ReCaptchaV3Provider` (key via `--dart-define=RECAPTCHA_V3_SITE_KEY`)
- Camera release signing config (`android/key.properties`, git-ignored).
- iOS build CI (`.github/workflows/ios-build.yml`) — compile-verifies iOS on a
  macOS runner without a local Mac.

## Manual steps remaining (only you can do these)

### Android — both apps
- [ ] Firebase Console → Project Settings → each Android app → add **release SHA-256**
      `4F:9A:0A:35:20:81:51:68:04:09:BA:AD:A1:94:1F:BD:F8:38:0B:2C:06:BF:68:2E:26:ED:AD:2E:CA:FE:E8:FE`
      (camera). (Debug SHA `F8:C9:…:9D` already used for `flutter run` debug.)
- [ ] App Check → each Android app → register **Play Integrity**; enable the
      **Play Integrity API** in Google Cloud.
- [ ] For `flutter run` (debug) on a new device/install: allow-list the printed
      App Check debug token (per device — unavoidable for debug builds).

### Web — parent
- [ ] App Check → register the **web app** → reCAPTCHA v3 → copy site key.
- [ ] reCAPTCHA admin → add allowed domains (deploy domain + `localhost`).
- [ ] Build/run with `--dart-define=RECAPTCHA_V3_SITE_KEY=<key>`.
- [ ] Remove the `FIREBASE_APPCHECK_DEBUG_TOKEN` line from `web/index.html` before
      production.

### iOS — both apps (needs macOS + Apple Developer account)
- [ ] A **Mac with Xcode** (or cloud Mac) — iOS cannot build on Windows. The CI
      workflow build-verifies; running on a device needs the steps below.
- [ ] **Apple Developer account** ($99/yr) for signing + device provisioning.
- [ ] Register each iOS app in Firebase (bundle ids `com.kidssafecam.camera` /
      `…parent`); download the real `GoogleService-Info.plist` into
      `apps/<app>/ios/Runner/` (git-ignored).
- [ ] App Check → register each iOS app with **DeviceCheck** (and/or App Attest).
- [ ] On a Mac: `cd apps/<app> && flutter run --release -d <ios-device>`.

### Cross-cutting (affects "perfectly run")
- [ ] **TURN server**: `getTurnCredentials` needs a provisioned TURN backend (env
      config in the function) for streaming across different networks. Same-LAN
      works via STUN without it.
- [ ] **Push notifications (FCM)**: client FCM token registration is **not yet
      implemented** (see IMPLEMENTATION_PLAN). Event → notification fan-out exists
      server-side, but devices won't receive pushes until the client registers a
      token. Needed on all platforms; iOS additionally needs an **APNs key**.

## TL;DR
- **Android**: works now; do the Play Integrity SHA + API to make `--release`
  fully authorized.
- **Web (parent)**: works now on localhost; add the real reCAPTCHA site key +
  domains for deploy.
- **iOS**: code is ready and CI compile-checks it, but you need a Mac + Apple
  Developer account to actually run it on a device.
