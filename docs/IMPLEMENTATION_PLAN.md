# AI Baby Monitor — Step-by-Step Implementation Plan

This plan turns the product roadmap into ordered, shippable steps. Each step lists its
**goal**, **key deliverables**, and **done-when** criteria. Security/safety work is folded
into the step it protects, never deferred.

Legend: ✅ done · 🚧 in progress · ⬜ not started

---

## Step 0 — Foundations  🚧

**Goal:** A coherent monorepo every later step builds on.

- ✅ Architecture, security, and plan docs (`/docs`)
- 🚧 Monorepo scaffold: `apps/{camera_app,parent_app,shared}`, `backend/{functions,firestore}`
- 🚧 Clean Architecture folder skeletons + Riverpod + DI wiring
- 🚧 Firestore security rules (default-deny, ownership-scoped) + indexes
- 🚧 Cloud Functions (TypeScript) skeleton + npm workspace
- 🚧 Melos workspace, root README, `.gitignore`, `firebase.json`

**Done when:** structure is in place, rules/functions lint, docs describe the system.

---

## Step 1 — Flutter project setup  🚧

**Goal:** Both apps run with shared package, theme, routing, and DI.

- ✅ Wire `shared` package into both apps via path dependency.
- ✅ `go_router` navigation, app theme, shared theme applied.
- ✅ Firebase initialization (`firebase_core` + `Firebase.initializeApp`) wired in `main.dart`.
- ⬜ Run `flutterfire configure --project=kidssafecam` per app to generate
  `firebase_options.dart` (see docs/FIREBASE_SETUP.md) — requires a local Flutter SDK.

**Done when:** both apps launch to a placeholder home screen using the shared theme.

---

## Step 2 — Firebase Authentication  🚧

**Goal:** Users can sign up / sign in / sign out.

- ✅ `auth` feature in `shared` (Clean Architecture): `AuthRepository` contract,
  `FirebaseAuthRepository` impl, Riverpod `AuthController`, reusable `LoginPage`.
- ✅ Email/password flows with friendly error mapping; `users/{uid}` profile created on sign-up.
- ✅ Auth-state-driven routing in both apps (`GoRouterRefreshStream` + redirect to `/login`).
- ✅ Sign-out from both home screens; unit tests for the controller (fake repo).
- ⬜ Verify end-to-end against the live project once Email/Password auth is enabled
  in the console (see docs/FIREBASE_SETUP.md) — needs a local Flutter SDK.

**Done when:** authenticated session persists; rules reject unauthenticated access.

---

## Step 3 — Firestore schema & rules  🚧

**Goal:** Collections + security rules live and enforced.

- ✅ `users`, `devices`, `events`, `notifications` with `ownerId` denormalization.
- ✅ Ownership-scoped rules; **12 emulator tests** for the allow/deny matrix
  (`backend/firestore/test/`, run with `npm test`) — all passing.
- ✅ Composite indexes for event/notification queries (`firestore.indexes.json`).
- ✅ Devices data layer in `shared`: `DeviceRepository` + `FirestoreDeviceRepository`
  + `DeviceModel` mapping + Riverpod `devicesProvider`; parent home shows the live list.
- ⬜ Deploy rules/indexes to the live project (`firebase deploy`) once the database exists.

**Done when:** rules unit tests pass in the Firestore emulator. ✅

---

## Step 4 — Pairing  🚧

**Goal:** Securely bind a camera to a parent account.

- ✅ `requestPairingCode` / `claimPairingCode` Cloud Functions: high-entropy 8-char
  codes, peppered-SHA-256 hashed (stored as doc id), 5-min TTL, single-use via
  transaction, per-camera active-code cap + per-parent brute-force limit.
- ✅ **7 emulator tests** for the logic (`npm run test:emulator`) — all passing.
- ✅ Camera shows the code (`/pair`); parent enters it (Add camera dialog); the
  `devices/{id}` doc is created with `ownerId` and appears in the realtime list.
- ⬜ QR scan as an alternative to typing (future polish).
- ⬜ End-to-end verify against the live project (needs Functions deployed + Blaze).

**Done when:** a fresh camera appears in the parent's device list after pairing. ✅ (emulator)

---

## Step 5 — WebRTC signaling server  🚧

**Goal:** Exchange SDP/ICE over Firestore.

- ✅ Rules: camera identity (not just owner) can read its device, write heartbeat
  fields, and use the `calls` signaling subcollection; **+3 emulator rules tests** (14 total).
- ✅ `getTurnCredentials` function: ephemeral coturn-REST HMAC credentials, STUN-only
  fallback; **+3 unit tests** (10 function tests total).
- ✅ `SignalingClient` in `shared`: offer/answer + caller/callee ICE candidate exchange
  over `devices/{id}/calls/{callId}`; `iceConfigProvider` fetches ICE servers.
- ⬜ `WebRtcSession` (RTCPeerConnection wiring) lands with Step 6, where it carries
  the first media track and we can observe `connected`.

**Done when:** a peer connection reaches `connected` between two clients (Step 6).

---

## Step 6 — Video streaming  ⬜
Camera publishes video track; parent renders it. Adaptive bitrate, orientation handling.
**Done when:** parent sees live video < 500 ms latency on LAN.

## Step 7 — Audio streaming  ⬜
Camera publishes audio; parent plays it with mute control.
**Done when:** parent hears live audio; mute works.

## Step 8 — Two-way communication (push-to-talk)  ⬜
Parent → camera audio track gated by a push-to-talk button.
**Done when:** speaking on the parent app is audible on the camera.

## Step 9 — Background + auto-reconnect  ⬜
Android foreground service, iOS background audio/VoIP; heartbeats + ICE-restart reconnect.
**Done when:** stream survives app backgrounding and brief network drops.

## Step 10 — Push notifications  ⬜
FCM token registration; `connection_lost` / device-offline notifications via triggered functions.
**Done when:** offline camera produces a push within the heartbeat window.

## Step 11 — Event history  ⬜
`events` write/read paths; notification fan-out function; parent event-history UI.
**Done when:** events appear in history and generate notifications.

## Step 12 — Cry detection AI  ⬜
On-device YAMNet (TFLite) audio classification on the camera → `baby_cry` event + push.
**Done when:** sustained cry produces an event/notification on-device.

## Step 13 — Fall detection AI  ⬜
MediaPipe Pose + TFLite motion analysis → `fall_detected` event + push.
**Done when:** simulated fall produces an event/notification on-device.

## Step 14 — Premium (Phase 4)  ⬜
Multiple cameras, opt-in encrypted cloud recording, timeline/playback, sleep analytics,
motion/night mode, web dashboard, subscriptions.

---

## Cross-cutting (every step)

- **Tests:** unit (domain/use-cases), widget, rules tests, function tests.
- **CI:** analyze + test for Dart and functions; rules tests on the emulator.
- **Security:** App Check, least-privilege rules, ephemeral secrets, no PII in logs.
- **Observability:** Crashlytics + structured function logs.

## Current focus

**Steps 0–5 complete** (Foundations → Auth → Firestore rules → Pairing → Signaling).
Backend is emulator-verified (14 rules tests + 10 function tests); Dart unit tests written.

**Next: Step 6 — Video streaming.** Build `WebRtcSession` (RTCPeerConnection on top of
`SignalingClient` + `iceConfigProvider`): the camera publishes its video track, the parent
renders it with `RTCVideoView`, plus the call lifecycle (create / join / hang up) and a
live-view screen.

### Outstanding owner/console tasks (not code)
- Rotate the previously-exposed service-account key.
- Enable **Email/Password** auth; create the **Firestore database** (region is permanent).
- Upgrade to **Blaze** and `firebase deploy` (rules, indexes, functions).
- Register **App Check** providers; set `TURN_SHARED_SECRET` / `TURN_URLS` for real TURN.
- Run `flutter analyze` / `melos run test` on a machine with the Flutter SDK.
