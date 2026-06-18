# AI Baby Monitor — Security, Privacy & Safety

A baby monitor is one of the most sensitive devices a family can own: a live audio/video
feed of a child inside the home. Security and privacy are **first-class requirements**, not
an afterthought. This document defines the threat model and the controls that mitigate it.

---

## 1. Threat Model

| # | Threat | Impact | Primary mitigation |
|---|---|---|---|
| T1 | Unauthorized viewing of a stream | Severe privacy breach | Firebase Auth + Firestore rules + App Check; media only between paired, authenticated peers |
| T2 | Stolen / replayed pairing code | Stranger pairs to a camera | Short-lived, single-use, hashed codes; rate limiting |
| T3 | Media interception on the network | Eavesdropping | Mandatory DTLS-SRTP; optional insertable-stream E2E frame encryption |
| T4 | Compromised TURN relay reading media | Eavesdropping via relay | Media is encrypted end-to-end of the WebRTC session; TURN sees only ciphertext |
| T5 | Leaked long-lived secrets in the app binary | Backend abuse | No static TURN/admin secrets in apps; ephemeral credentials via Cloud Functions |
| T6 | Token theft from device storage | Account takeover | `flutter_secure_storage` (Keychain/Keystore); short-lived ID tokens |
| T7 | Malicious / fake app instance hammering backend | Abuse, cost, DoS | Firebase App Check on all callable functions and Firestore |
| T8 | Excessive data retention of child media/audio | Privacy / regulatory | On-device AI only; no raw media stored by default; retention limits on events |
| T9 | Account enumeration / brute force | Credential attacks | Firebase Auth throttling; generic error messages; rate-limited functions |

---

## 2. Authentication & Authorization

- **Firebase Authentication** for all users (email/password in MVP; Google/Apple later).
- Every Firestore access and callable Cloud Function requires a valid, unexpired ID token.
- **Authorization is ownership-based**: a user may only read/write devices, events, and
  notifications where `ownerId == request.auth.uid`. Enforced in Firestore security rules
  (`/backend/firestore/firestore.rules`) — the rules are the source of truth, not the app.
- The camera device authenticates as its own identity and may only write to its own device
  document and signaling subcollection.

## 3. Pairing Security

- Pairing codes are **single-use** and **short-lived** (≈5 minutes).
- Codes are stored **hashed** (never in plaintext) so a database read cannot reveal active
  codes.
- `claimPairingCode` is **rate-limited** per user/IP and atomically marks the code consumed
  to prevent races and replay.
- Pairing binds `ownerId` server-side; the client cannot self-assign ownership.

## 4. Media Encryption

- WebRTC mandates **DTLS-SRTP**: all audio/video/data-channel traffic is encrypted in
  transit by default. There is no unencrypted media path.
- A **TURN relay**, when used, forwards only already-encrypted SRTP packets — it cannot
  decrypt content.
- **Roadmap — true E2E:** WebRTC *insertable streams* allow encrypting media frames with a
  key derived from the secure pairing channel, so even a fully-compromised SFU/relay cannot
  view content. Tracked for the streaming milestone.

## 5. Backend Hardening

- **Firebase App Check** gates callable functions and Firestore against non-genuine clients.
- **Ephemeral TURN credentials**: a Cloud Function issues time-limited HMAC TURN
  credentials per session; no static relay secret ships in the app.
- **Least-privilege rules**: default-deny Firestore; every collection has explicit,
  ownership-scoped allow rules. Signaling subcollections are readable/writable only by the
  device owner and the camera identity.
- **Input validation** on all callable functions; structured, generic error responses.

## 6. Privacy & Child-Data Protection

- **On-device AI only**: cry/fall detection runs locally (TFLite/MediaPipe). Raw audio and
  video are **never** uploaded for inference — only derived events leave the device.
- **Data minimization**: we store events and small metadata, not media, in the MVP. Cloud
  recording (Phase 4) is **opt-in**, owner-scoped, encrypted at rest, and retention-bounded.
- **Regulatory posture**: designed with **COPPA** (US) and **GDPR / GDPR-K** (EU) in mind —
  lawful basis, parental control, data export/deletion, and explicit retention windows.
  (Formal compliance review required before public launch.)
- **Transparency**: the camera app shows a clear "streaming/recording" indicator; access
  events are auditable via the events log.

## 7. Operational Security

- Secrets via Firebase environment config / Secret Manager — never committed. `.env` files
  are git-ignored.
- Dependency and secret scanning in CI.
- Crash/error reporting (Crashlytics) scrubbed of PII.
- Principle: **fail closed** — if authorization is uncertain, deny.

---

## 8. Safety (child-safety, not just infosec)

- **Reliability over features**: connection-loss and offline-camera notifications are
  treated as safety-critical paths and tested accordingly. A baby monitor that silently
  stops working is dangerous.
- **No false sense of security**: AI cry/fall detection is an *assistive* signal with
  configurable sensitivity, never a guarantee — documented clearly in-app.
- **Auto-reconnect + heartbeats** ensure the parent is alerted when monitoring degrades.
- **Local alarms**: critical alerts surface even if push delivery is delayed.

> This document is reviewed at each phase. Security controls are implemented alongside the
> features they protect, not retrofitted.
