# Firebase Setup

How to connect the apps and backend to the `kidssafecam` Firebase project. These steps run
on a developer machine with the Flutter SDK installed — they can't run in CI or the
scaffolding environment.

> ⚠️ **Never commit secrets.** No service-account JSON keys, `.env` files, or
> `firebase_options.dart` belong in git. They are git-ignored on purpose. If a key is ever
> exposed (e.g. pasted into a chat, log, or PR), **revoke and rotate it immediately** in the
> Google Cloud Console (IAM & Admin → Service Accounts → Keys). Production code uses
> Application Default Credentials and needs no key file.

---

## 1. Prerequisites

```bash
# Flutter SDK 3.22+ (https://docs.flutter.dev/get-started/install)
flutter --version

# Firebase CLI + login
npm install -g firebase-tools
firebase login

# FlutterFire CLI
dart pub global activate flutterfire_cli
```

## 2. Per-app Firebase config — ALREADY DONE ✅

Both apps are already registered with the `kidssafecam` project and their
`lib/firebase_options.dart` files are generated and committed:

| App | Android | iOS | Web |
|---|---|---|---|
| `parent_app` | `com.kidssafecam.parent` | `com.kidssafecam.parent` | ✓ |
| `camera_app` | `com.kidssafecam.camera` | `com.kidssafecam.camera` | ✓ |

These files hold **client** config (api keys, app ids) that ships in the app binary — not
secrets. They are committed so the project builds reproducibly; security is enforced by
Firestore rules + App Check, never by hiding them.

`Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` is already wired
in each app's `main.dart`.

To regenerate or add platforms later (e.g. after `flutter create` adds native folders), run
in each app directory:

```bash
flutterfire configure --project=kidssafecam
```

## 3. Backend (Cloud Functions + rules)

Functions use **Application Default Credentials** — no key file:

```bash
cd backend/functions && npm install

# From the repo root, run the emulator suite:
firebase emulators:start --only functions,firestore,auth
```

For local Admin SDK access against the real project (rarely needed), use your own ADC
rather than a downloaded key:

```bash
gcloud auth application-default login
```

Deploy rules, indexes, and functions:

```bash
firebase deploy --only firestore:rules,firestore:indexes,functions
```

## 4. Required Firebase products — remaining manual steps

Still to enable for `kidssafecam` (these mutate the live project and were intentionally
left for you to confirm):

- **Authentication** → enable **Email/Password** (Console → Authentication → Sign-in
  method). Needed for Step 2.
- **Firestore Database** → create the database. ⚠️ **The location is permanent** — pick a
  region close to your users (e.g. `eur3` for Europe, `nam5` for the US) **before** creating.
- **Cloud Functions** → requires the **Blaze** (pay-as-you-go) plan.
- **Cloud Messaging** → used in Step 10.
- **App Check** → register providers before any production traffic.

After the database exists, deploy rules + indexes:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

## 5. If a credential leaks

1. Google Cloud Console → **IAM & Admin → Service Accounts**
2. Open the affected account → **Keys** → delete the exposed key id
3. Generate a new key only if a script genuinely needs one; store it in Secret Manager, not
   in the repo
4. Review **Firebase Console → Usage** and audit logs for unexpected activity
