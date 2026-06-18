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

**Step 0 — Foundations** (monorepo scaffold). See the implementation plan for what's next.

## Getting started

Prerequisites: Flutter SDK (3.x), Dart, Node 22+, the Firebase CLI, and Melos
(`dart pub global activate melos`).

```bash
# Install Dart workspace deps across all packages
melos bootstrap

# Backend functions
cd backend/functions && npm install

# Run an app (after Firebase is configured — see docs)
cd apps/parent_app && flutter run
```

Firebase is configured per environment with `flutterfire configure`; the generated
`firebase_options.dart` and platform config files are git-ignored.
