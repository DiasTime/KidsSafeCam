# AI Baby Monitor (KidsSafeCam)

Turn an old smartphone into a secure, AI-assisted baby monitor.

Two Flutter apps — a **Camera App** (runs on a spare phone near the baby) and a **Parent
App** — connected by **peer-to-peer WebRTC** for low-latency, encrypted audio/video, with a
**Firebase** backend for auth, pairing, signaling, notifications, and event history.
On-device AI (YAMNet for cry detection, MediaPipe Pose for fall detection) keeps raw media
on the device — only events leave the phone.

## Repository layout

```
/apps
  /camera_app   Flutter app for the baby-side device
  /parent_app   Flutter app for the parent
  /shared       Shared Dart package (entities, clients, theme, utils)
/backend
  /functions    Cloud Functions (TypeScript)
  /firestore    Security rules + indexes
/docs           Architecture, security, implementation plan
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — system design, stack, data flows, data model
- [Security & Privacy](docs/SECURITY.md) — threat model, encryption, child-data protection
- [Implementation Plan](docs/IMPLEMENTATION_PLAN.md) — step-by-step roadmap & current focus
- [Firebase Setup](docs/FIREBASE_SETUP.md) — connecting the apps/backend to `kidssafecam`

## Status

Foundations through **Step 5 (WebRTC signaling)** are implemented. The backend is
emulator-verified; the Flutter code is written but not yet run through `flutter analyze`
(no SDK in CI yet). See the [implementation plan](docs/IMPLEMENTATION_PLAN.md) for the
per-step state and what's next (Step 6 — video streaming).

| Area | Done |
|---|---|
| Monorepo scaffold, Clean Architecture, Riverpod, theming | ✅ |
| Firebase init + email/password auth + auth-gated routing | ✅ |
| Firestore schema + ownership rules (**14 emulator tests**) | ✅ |
| Secure pairing functions (hashed, single-use, rate-limited; **7 tests**) | ✅ |
| WebRTC signaling client + ephemeral TURN credentials (**3 tests**) | ✅ |
| Video/audio streaming, two-way talk, notifications, AI | ⬜ upcoming |

## Getting started

Prerequisites: Flutter SDK (3.x), Dart, Node 22+, the Firebase CLI, and Melos
(`dart pub global activate melos`).

```bash
# Install Dart workspace deps across all packages
melos bootstrap

# Backend functions
cd backend/functions && npm install

# Run an app (Firebase is already configured — see docs/FIREBASE_SETUP.md)
cd apps/parent_app && flutter run
```

### Tests

```bash
# Firestore security-rules tests (Firestore emulator)
cd backend/firestore && npm install && npm test

# Cloud Functions tests (pairing + TURN; uses the emulator)
cd backend/functions && npm install && npm run test:emulator

# Dart/Flutter unit tests
melos run test
```

Firebase is configured for the `kidssafecam` project; `firebase_options.dart` is committed
(client config, not a secret). The native `google-services.json` / `GoogleService-Info.plist`
are generated locally. See [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md).
