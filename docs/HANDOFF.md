# Handoff — continue AI Baby Monitor in an IDE with the Flutter SDK

Paste the prompt below as the first message to a Claude Code session running in a real IDE
(Flutter SDK installed). It hands off the in-progress work and sets the next tasks.

---

You're picking up an in-progress Flutter project, "AI Baby Monitor" (KidsSafeCam),
in a real IDE with the Flutter SDK installed. A previous session built the backend
and the Dart code but had NO Flutter SDK, so the Dart was never compiled, analyzed,
or run. Your job is to make it real on-device, then continue the roadmap.

## Repo & workflow
- Repo: DiasTime/KidsSafeCam. Work on branch `claude/ai-baby-monitor-setup-bwgqh9`
  (it already exists with all the work below). Commit logically and push to that branch.
- Do NOT open a PR unless asked. Never commit secrets (service-account keys, .env).
  A Firebase Admin key was exposed earlier and should already be rotated — don't re-add it.

## Read these first (they're accurate and current)
- docs/ARCHITECTURE.md   — system design, stack, data model, data flows
- docs/SECURITY.md       — threat model + per-threat implementation status
- docs/IMPLEMENTATION_PLAN.md — the 14-step roadmap; Steps 0–5 are done, Step 6 is next
- docs/FIREBASE_SETUP.md — Firebase project (kidssafecam) is configured; firebase_options.dart is committed

## Architecture & conventions (follow these)
- Monorepo: apps/camera_app, apps/parent_app, apps/shared (Dart package), backend/functions (TS), backend/firestore (rules+tests).
- Clean Architecture per feature: data / domain / presentation. Domain has no Flutter/Firebase imports.
- State mgmt: Riverpod. Routing: go_router (auth-gated). Reusable logic lives in apps/shared and is exported via lib/ai_baby_monitor_shared.dart.
- Backend is emulator-verified: `cd backend/firestore && npm test` (14 rules tests),
  `cd backend/functions && npm run test:emulator` (10 tests). Keep them green.

## What already exists (don't rebuild)
- Auth: shared `AuthRepository`/`FirebaseAuthRepository`, Riverpod `authControllerProvider`, shared `LoginPage`, auth-gated routers in both apps.
- Firestore: ownership rules in backend/firestore/firestore.rules; devices/events/notifications + cameraUid; `DeviceRepository` + `devicesProvider`; parent home renders the live device list.
- Pairing: Cloud Functions `requestPairingCode`/`claimPairingCode` (hashed, single-use, rate-limited); shared `FunctionsPairingRepository`; camera `/pair` page shows a code; parent "Add camera" dialog claims it.
- Signaling: shared `SignalingClient` (offer/answer + caller/callee ICE under devices/{id}/calls/{callId}); `getTurnCredentials` function (ephemeral coturn HMAC, STUN-only fallback); shared `iceConfigProvider`.

## TASK 1 — Make the Flutter code build & run (the previous env couldn't)
1. Generate native platform folders for both apps WITHOUT clobbering lib/:
   `cd apps/camera_app && flutter create --org com.kidssafecam --project-name camera_app .`
   `cd apps/parent_app && flutter create --org com.kidssafecam --project-name parent_app .`
   Verify the applicationId/bundleId end up as com.kidssafecam.camera and com.kidssafecam.parent
   (matching firebase_options.dart and the registered Firebase apps). Adjust if needed.
2. `dart pub global activate melos && melos bootstrap` (or `flutter pub get` in each package).
3. `flutter analyze` in shared, camera_app, parent_app. FIX every error/warning — the Dart was
   never analyzed, so expect import/type fixes. Run `melos run test` and fix failures.
4. Add runtime permissions to native config: camera + microphone (iOS Info.plist
   NSCameraUsageDescription / NSMicrophoneUsageDescription; Android CAMERA/RECORD_AUDIO + INTERNET).
5. For live testing you need (console, may be done already): Email/Password auth enabled,
   the Firestore database created, and functions deployed (Blaze). If not available, you can
   still run against the Firebase emulator suite.
6. Run both apps; confirm: sign up/in works, camera shows a pairing code, parent claims it,
   the device appears in the parent's list. Report what works and any fixes you made.

## TASK 2 — Step 6: Video streaming
Goal: the camera publishes its video (and audio) track; the parent sees live video via RTCVideoView.
- Build `WebRtcSession` in apps/shared (feature: streaming) on top of the existing `SignalingClient`
  and `iceConfigProvider`, using flutter_webrtc (already in shared pubspec).
- Roles per ARCHITECTURE.md §4.2: the PARENT is the caller (opens live view → creates the call doc
  + offer, listens for answer + callee ICE). The CAMERA is the callee: it listens for a new call/offer
  on its device's calls subcollection, getUserMedia(video+audio), addTrack, setRemoteDescription,
  createAnswer, write answer, listen for caller ICE.
- Camera side: a controller that keeps a foreground listener for incoming calls while the camera
  screen is active (full background service is Step 9). Render a local preview.
- Parent side: a live-view screen (route like /camera/:deviceId) with RTCVideoView showing the remote
  stream, a connection-status indicator, and a hang-up button that tears down the peer connection and
  cleans up the call doc (SignalingClient.deleteCall).
- Handle peer-connection state transitions and surface "connecting / connected / disconnected".
- Keep audio muted/secondary for now; mute toggle + push-to-talk are Steps 7–8.
- Update docs/IMPLEMENTATION_PLAN.md Step 6 status and commit.

Verify on two real devices/emulators (one camera, one parent) that the parent sees live video with
low latency. Note: the Firebase emulator works for signaling, but real STUN/TURN may be needed across
networks — set TURN_SHARED_SECRET/TURN_URLS for the function if testing across NATs.
