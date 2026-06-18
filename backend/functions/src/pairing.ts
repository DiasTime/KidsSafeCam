/**
 * Pairing logic (Step 4). A camera mints a short-lived, single-use code; the
 * parent claims it to create a device they own.
 *
 * Security properties (see docs/SECURITY.md, T2):
 *  - codes are high-entropy and short-lived (5 min)
 *  - codes are stored HASHED (peppered SHA-256) as the document id — a DB read
 *    never reveals an active code, and lookup stays O(1)
 *  - claiming is atomic + single-use (transaction marks the code consumed)
 *  - both minting and claiming are rate-limited per user
 *
 * The handlers pass in the Firestore instance so this logic is unit-testable
 * against the emulator without the callable wrapper.
 */
import { createHash, randomInt } from "crypto";
import {
  FieldValue,
  Firestore,
  Timestamp,
} from "firebase-admin/firestore";

// Readable alphabet (no 0/O/1/I/L) — ~40 bits of entropy over 8 chars.
const CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 8;
const CODE_TTL_MS = 5 * 60 * 1000;
const MAX_ACTIVE_CODES_PER_CAMERA = 3;
const MAX_CLAIM_FAILURES = 10;
const CLAIM_WINDOW_MS = 15 * 60 * 1000;

const PAIRING_CODES = "pairingCodes";
const PAIRING_ATTEMPTS = "pairingAttempts";
const DEVICES = "devices";

/** Error carrying a code that maps onto an HttpsError in the callable wrapper. */
export class PairingError extends Error {
  constructor(
    readonly code:
      | "resource-exhausted"
      | "not-found"
      | "failed-precondition"
      | "deadline-exceeded",
    message: string
  ) {
    super(message);
  }
}

export function generateCode(): string {
  let out = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    out += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  }
  return out;
}

/** Peppered hash so a leaked DB cannot be used to recover/guess active codes. */
export function hashCode(code: string): string {
  const pepper = process.env.PAIRING_PEPPER || "dev-pepper";
  return createHash("sha256")
    .update(`${pepper}:${code.trim().toUpperCase()}`)
    .digest("hex");
}

export interface RequestResult {
  code: string;
  expiresAt: number;
}

export async function requestPairingCodeLogic(
  db: Firestore,
  cameraUid: string,
  deviceName: string
): Promise<RequestResult> {
  const now = Date.now();

  // Rate limit: cap active (unconsumed, unexpired) codes per camera.
  const active = await db
    .collection(PAIRING_CODES)
    .where("cameraUid", "==", cameraUid)
    .where("consumed", "==", false)
    .where("expiresAt", ">", Timestamp.fromMillis(now))
    .get();
  if (active.size >= MAX_ACTIVE_CODES_PER_CAMERA) {
    throw new PairingError(
      "resource-exhausted",
      "Too many active pairing codes. Please wait and try again."
    );
  }

  const code = generateCode();
  await db
    .collection(PAIRING_CODES)
    .doc(hashCode(code))
    .set({
      cameraUid,
      deviceName: deviceName?.trim() || "Camera",
      consumed: false,
      createdAt: Timestamp.fromMillis(now),
      expiresAt: Timestamp.fromMillis(now + CODE_TTL_MS),
    });

  return { code, expiresAt: now + CODE_TTL_MS };
}

export interface ClaimResult {
  deviceId: string;
}

export async function claimPairingCodeLogic(
  db: Firestore,
  parentUid: string,
  code: string
): Promise<ClaimResult> {
  const now = Date.now();
  const attemptsRef = db.collection(PAIRING_ATTEMPTS).doc(parentUid);

  // Brute-force protection: reject if too many recent failures.
  const attempts = await attemptsRef.get();
  if (attempts.exists) {
    const d = attempts.data()!;
    const windowStart = (d.windowStart as Timestamp | undefined)?.toMillis() ?? 0;
    const failures = (d.failures as number) ?? 0;
    if (now - windowStart < CLAIM_WINDOW_MS && failures >= MAX_CLAIM_FAILURES) {
      throw new PairingError(
        "resource-exhausted",
        "Too many attempts. Please wait a few minutes and try again."
      );
    }
  }

  const ref = db.collection(PAIRING_CODES).doc(hashCode(code));

  try {
    const deviceId = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new PairingError("not-found", "Invalid pairing code.");
      }
      const data = snap.data()!;
      if (data.consumed === true) {
        throw new PairingError("failed-precondition", "This code was already used.");
      }
      if ((data.expiresAt as Timestamp).toMillis() < now) {
        throw new PairingError("deadline-exceeded", "This code has expired.");
      }

      const deviceRef = db.collection(DEVICES).doc();
      tx.set(deviceRef, {
        ownerId: parentUid,
        cameraUid: data.cameraUid,
        name: data.deviceName ?? "Camera",
        status: "offline",
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.update(ref, {
        consumed: true,
        consumedAt: FieldValue.serverTimestamp(),
        deviceId: deviceRef.id,
        claimedBy: parentUid,
      });
      return deviceRef.id;
    });

    // Success — reset the failure counter.
    await attemptsRef.set(
      { failures: 0, windowStart: Timestamp.fromMillis(now) },
      { merge: true }
    );
    return { deviceId };
  } catch (e) {
    if (e instanceof PairingError) {
      await recordFailure(attemptsRef, now);
    }
    throw e;
  }
}

async function recordFailure(
  attemptsRef: FirebaseFirestore.DocumentReference,
  now: number
): Promise<void> {
  await attemptsRef.firestore.runTransaction(async (tx) => {
    const snap = await tx.get(attemptsRef);
    const d = snap.exists ? snap.data()! : {};
    const windowStart = (d.windowStart as Timestamp | undefined)?.toMillis() ?? 0;
    const withinWindow = now - windowStart < CLAIM_WINDOW_MS;
    tx.set(
      attemptsRef,
      {
        failures: (withinWindow ? (d.failures as number) ?? 0 : 0) + 1,
        windowStart: withinWindow
          ? d.windowStart ?? Timestamp.fromMillis(now)
          : Timestamp.fromMillis(now),
      },
      { merge: true }
    );
  });
}
