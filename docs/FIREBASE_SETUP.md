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

## 2. Generate per-app Firebase config

`firebase_options.dart` is per-app, so run `flutterfire configure` **once in each app
directory**:

```bash
cd apps/parent_app
flutterfire configure --project=kidssafecam

cd ../camera_app
flutterfire configure --project=kidssafecam
```

This registers the platform apps and writes `lib/firebase_options.dart`. That file is
git-ignored; `lib/firebase_options.dart.example` documents its shape. (These client values
aren't true secrets — they ship in the binary — but if you'd rather commit the generated
file for reproducible CI builds, remove the `**/firebase_options.dart` line from
`.gitignore`. Security is enforced by Firestore rules + App Check, not by hiding them.)

`Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` is already wired
in each app's `main.dart`.

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

## 4. Required Firebase products

Enable in the console for `kidssafecam`:

- **Authentication** → Email/Password (Step 2)
- **Firestore Database** → in production mode; rules deploy from `backend/firestore`
- **Cloud Functions** (Blaze plan required)
- **Cloud Messaging** (Step 10)
- **App Check** (recommended before any production traffic)

## 5. If a credential leaks

1. Google Cloud Console → **IAM & Admin → Service Accounts**
2. Open the affected account → **Keys** → delete the exposed key id
3. Generate a new key only if a script genuinely needs one; store it in Secret Manager, not
   in the repo
4. Review **Firebase Console → Usage** and audit logs for unexpected activity
