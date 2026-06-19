# AI Baby Monitor (KidsSafeCam)

[![CI](https://github.com/DiasTime/KidsSafeCam/actions/workflows/ci.yml/badge.svg)](https://github.com/DiasTime/KidsSafeCam/actions/workflows/ci.yml)
[![CodeQL](https://github.com/DiasTime/KidsSafeCam/actions/workflows/codeql.yml/badge.svg)](https://github.com/DiasTime/KidsSafeCam/actions/workflows/codeql.yml)

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

Foundations through **Step 8 (two-way push-to-talk)** are implemented, plus the
**Steps 10–11 backend** (event→notification fan-out) and read layer + parent Activity UI.
The backend is emulator-verified and a GitHub Actions CI runs `flutter analyze`/tests plus
the emulator suites on every push. The remaining gaps are two-device media checks (no Android
SDK in the dev env), client FCM token registration, and the live Firebase bring-up. See the
[implementation plan](docs/IMPLEMENTATION_PLAN.md) for the per-step state and what's next
(Step 9 — background + auto-reconnect).

| Area | Done |
|---|---|
| Monorepo scaffold, Clean Architecture, Riverpod, theming | ✅ |
| Firebase init + email/password auth + auth-gated routing | ✅ |
| Firestore schema + ownership rules (**14 emulator tests**) | ✅ |
| Secure pairing functions (hashed, single-use, rate-limited; **7 tests**) | ✅ |
| WebRTC signaling client + ephemeral TURN credentials (**3 tests**) | ✅ |
| Video streaming (camera publishes, parent renders; full call lifecycle) | ✅ |
| Audio streaming + parent-side mute control (**+4 tests**) | ✅ |
| Two-way push-to-talk (parent → camera audio; **+4 tests**) | ✅ |
| Event→notification fan-out + history read layer/UI (**+8 tests**) | ✅ |
| Background/reconnect, client FCM registration, on-device AI | ⬜ upcoming |

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

## CI / CD

GitHub Actions run on every push and pull request:

- **CI** (`.github/workflows/ci.yml`) — four jobs:
  - *Flutter*: `dart format` gate, `flutter analyze`, shared unit tests **with
    coverage** (uploaded as an artifact + a step summary), and a `flutter build web`
    of both apps to catch build-time breakage.
  - *Firestore rules* and *Cloud Functions*: emulator-based test suites (JDK 21).
  - *npm audit*: fails on HIGH/CRITICAL advisories in the backend's production deps.
- **CodeQL** (`.github/workflows/codeql.yml`) — security/quality scanning of the
  backend TypeScript on push/PR to `main` and weekly.
- **Deploy** (`.github/workflows/deploy.yml`) — after CI passes on `main`, deploys
  Firestore rules/indexes + Cloud Functions to the live project. It is a safe no-op
  until the `FIREBASE_SERVICE_ACCOUNT` repo secret is set (see the workflow header).
- **Dependabot** (`.github/dependabot.yml`) — weekly grouped update PRs for the npm,
  pub, and GitHub Actions dependencies.
