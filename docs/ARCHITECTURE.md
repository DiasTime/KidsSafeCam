# AI Baby Monitor — Architecture

> Turn an old smartphone into a secure, AI-assisted baby monitor.
> Two Flutter apps (Camera + Parent), a Firebase backend, peer-to-peer WebRTC media,
> and on-device AI for cry/fall detection.

---

## 1. System Overview

```
                        ┌─────────────────────────────┐
                        │        Firebase Cloud         │
                        │                               │
   ┌──────────────┐     │  Auth   Firestore   FCM       │     ┌──────────────┐
   │  Camera App   │◄───►│  Cloud Functions   Storage    │◄───►│  Parent App   │
   │ (old phone)   │     │  App Check  Crashlytics       │     │ (parent phone)│
   └──────┬───────┘     └─────────────┬───────────────┘     └──────┬───────┘
          │                            │                            │
          │            1. Auth + pairing + signaling (via Firestore)│
          │            2. Notifications (via FCM)                   │
          │                                                         │
          │   3. Direct encrypted media (WebRTC P2P, DTLS-SRTP)     │
          └─────────────────────────────────────────────────────────┘
                         (TURN relay only when P2P fails)
```

- **Control plane** (auth, pairing, signaling, notifications, event history) runs through
  Firebase. It is low-bandwidth and globally scalable.
- **Data plane** (audio/video/two-way talk) is **peer-to-peer WebRTC**. Media never
  transits our servers in the MVP; a TURN server only relays encrypted packets when a
  direct connection is impossible. This keeps latency low (<500 ms target) and cost flat.
- **AI** (cry detection via YAMNet, fall detection via MediaPipe Pose) runs **on-device on
  the camera app**. Raw audio/video never leaves the phone for inference — only the
  resulting *event* (`baby_cry`, `fall_detected`, …) is written to Firestore.

---

## 2. Technology Stack

| Layer | Choice | Rationale |
|---|---|---|
| Mobile framework | **Flutter** (Android + iOS) | Single codebase, native performance, mature WebRTC/TFLite plugins |
| State management | **Riverpod** | Compile-safe DI, testable, no `BuildContext` coupling — scales cleanly |
| Architecture | **Clean Architecture** (presentation / domain / data) per feature | Testable, swappable data sources, scales to large teams |
| Auth | **Firebase Authentication** | Email/password + (later) Google/Apple sign-in |
| Database | **Cloud Firestore** | Realtime listeners power signaling + device status + events |
| Serverless | **Cloud Functions (Node 22 / TypeScript)** | Pairing tokens, TURN credentials, notification fan-out, event triggers |
| Push | **Firebase Cloud Messaging** | Cross-platform notifications |
| Media | **WebRTC** via `flutter_webrtc` | Low-latency P2P audio/video + data channel |
| NAT traversal | **STUN** (Google) + **TURN** (coturn / Twilio / Xirsys) | Connectivity behind CGNAT/firewalls |
| Cry detection | **TensorFlow Lite + YAMNet** | On-device audio classification |
| Fall detection | **MediaPipe Pose + TFLite** | On-device pose/motion analysis |
| Secure storage | `flutter_secure_storage` | Keychain / Keystore-backed token storage |
| Abuse protection | **Firebase App Check** | Blocks requests from non-genuine app instances |
| Monorepo tooling | **Melos** (Dart) + **npm workspaces** (functions) | Manage multiple packages with shared CI |

---

## 3. Monorepo Layout

```
/apps
  /camera_app      # Flutter app for the baby-side device
  /parent_app      # Flutter app for the parent
  /shared          # Dart package: entities, Firebase/WebRTC clients, theme, utils
/backend
  /functions       # Cloud Functions (TypeScript)
  /firestore       # security rules + composite indexes
/docs              # architecture, plan, security
melos.yaml         # Dart workspace
firebase.json      # Firebase project config
```

Each Flutter feature follows Clean Architecture:

```
/lib
  /core                     # cross-cutting: di, router, errors, constants, theme
  /features
    /<feature>
      /data
        /datasources        # remote (Firestore/WebRTC) + local
        /models             # DTOs <-> JSON
        /repositories       # repository implementations
      /domain
        /entities           # pure business objects
        /repositories       # abstract repository contracts
        /usecases           # single-responsibility business actions
      /presentation
        /controllers        # Riverpod notifiers / view-models
        /pages              # screens
        /widgets            # feature widgets
  main.dart
```

The dependency rule points **inward**: `presentation → domain ← data`. The domain layer
depends on nothing Flutter- or Firebase-specific.

---

## 4. Core Data Flows

### 4.1 Pairing (camera ⇄ parent)

1. Camera app authenticates, then calls `requestPairingCode` Cloud Function.
2. Function mints a short-lived (e.g. 5-min), single-use code and stores a hashed record.
3. Parent enters the code; parent app calls `claimPairingCode`.
4. Function verifies, creates/links the `devices` document with `ownerId = parentUid`,
   and returns the `deviceId`. The camera begins reporting `status` heartbeats.

Pairing codes are never long-lived, never reusable, and are stored hashed — see SECURITY.md.

### 4.2 WebRTC signaling (Firestore-based)

Signaling is serverless: SDP offers/answers and ICE candidates are exchanged via a
short-lived subcollection under the device document.

```
devices/{deviceId}/calls/{callId}
  ├─ offer:  { sdp, type }
  ├─ answer: { sdp, type }
  ├─ callerCandidates/*   (ICE)
  └─ calleeCandidates/*   (ICE)
```

- Parent (caller) writes the offer; camera (callee) listens, sets remote description,
  writes the answer; both stream ICE candidates. Security rules restrict read/write to the
  device owner and the paired camera identity.
- TURN credentials are **ephemeral**, issued per-session by a Cloud Function so long-lived
  secrets never ship in the app.

### 4.3 Events & notifications

1. On-device AI (camera) detects `baby_cry` / `fall_detected`, or backend detects
   `connection_lost` (heartbeat timeout) → writes an `events` document.
2. A Firestore-triggered Cloud Function fans out an FCM push to the owner's devices and
   writes a `notifications` document for in-app history.

---

## 5. Data Model (Firestore)

```
users/{uid}
  email, displayName, createdAt, fcmTokens[]

devices/{deviceId}
  ownerId, cameraUid, name, status (online|offline), lastSeenAt, createdAt,
  settings { nightMode, aiSensitivity, notificationsEnabled }

devices/{deviceId}/calls/{callId}        # ephemeral signaling
  offer {sdp,type}, answer {sdp,type}
  callerCandidates/*, calleeCandidates/* # ICE

events/{eventId}
  deviceId, ownerId, type, timestamp, metadata

notifications/{notificationId}
  userId, title, body, eventId, read, createdAt

# Backend-only (Admin SDK writes; default-deny to clients)
pairingCodes/{sha256(pepper:code)}       # cameraUid, deviceName, consumed, createdAt, expiresAt
pairingAttempts/{uid}                    # failures, windowStart (brute-force throttle)
```

`ownerId` is denormalized onto `events` so security rules and queries stay O(1) without
joins. `cameraUid` records the paired camera identity so the signaling rules can admit both
peers. Pairing codes are stored **hashed** as the document id (never plaintext). Composite
indexes are declared in `/backend/firestore`.

---

## 6. Non-Functional Targets

| Requirement | Approach |
|---|---|
| Latency < 500 ms | P2P WebRTC, regional STUN/TURN, no media through app servers |
| Auto-reconnect | Exponential-backoff reconnection on both apps; ICE restart on failure |
| Background execution | Android foreground service + iOS background audio/VoIP entitlement |
| Battery optimization | Adaptive bitrate, frame-rate capping, AI duty-cycling, wake-lock scoping |
| Secure media | WebRTC mandatory DTLS-SRTP; optional insertable-stream frame encryption (E2E) |
| Scale to millions | Stateless functions, Firestore sharding via per-device subcollections, FCM fan-out |

See **SECURITY.md** for the threat model and the encryption/privacy design in full.

---

## 7. Implementation Status

| Layer | State |
|---|---|
| Monorepo, Clean Architecture, Riverpod, theme, routing | ✅ implemented |
| Auth (email/password, auth-gated routing, `users/{uid}` provisioning) | ✅ implemented |
| Firestore ownership rules + indexes | ✅ implemented, 14 emulator tests |
| Pairing (`requestPairingCode` / `claimPairingCode`) | ✅ implemented, 7 tests |
| Signaling (`SignalingClient`) + ephemeral TURN (`getTurnCredentials`) | ✅ implemented, 3 tests |
| WebRTC peer connection + media tracks/rendering | ✅ implemented (Step 6); two-device latency check pending |
| Audio streaming + parent-side mute control | ✅ implemented (Step 7); two-device audible check pending |
| Two-way talk, notifications, event history, on-device AI, premium | ⬜ later phases |

Backend logic is verified against the Firebase emulator. The Flutter layer is written to
the same contracts but still needs a `flutter analyze` / device pass (no SDK in CI yet).
See **IMPLEMENTATION_PLAN.md** for the live per-step checklist.
