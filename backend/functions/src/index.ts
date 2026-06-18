/**
 * AI Baby Monitor — Cloud Functions entrypoint.
 *
 * Step 0 scaffold: function signatures and wiring are in place; business logic is
 * implemented in the steps that own each feature (see docs/IMPLEMENTATION_PLAN.md).
 * Each handler validates auth + App Check and fails closed.
 */

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import { EVENT_NOTIFICATION_COPY, EventDoc } from "./types";
import {
  claimPairingCodeLogic,
  PairingError,
  requestPairingCodeLogic,
} from "./pairing";

initializeApp();
const db = getFirestore();

// Reject any callable request without a verified App Check token or auth.
function requireAuth(auth: { uid: string } | undefined): string {
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  return auth.uid;
}

// Map a domain PairingError onto the matching HttpsError code.
function toHttpsError(e: unknown): HttpsError {
  if (e instanceof PairingError) {
    return new HttpsError(e.code, e.message);
  }
  if (e instanceof HttpsError) return e;
  logger.error("Unexpected pairing error", e);
  return new HttpsError("internal", "Something went wrong. Please try again.");
}

/**
 * Step 4 — Pairing. Mint a short-lived, single-use, hashed pairing code for a camera.
 */
export const requestPairingCode = onCall({ enforceAppCheck: true }, async (request) => {
  const uid = requireAuth(request.auth);
  const deviceName = (request.data?.deviceName as string | undefined) ?? "Camera";
  try {
    return await requestPairingCodeLogic(db, uid, deviceName);
  } catch (e) {
    throw toHttpsError(e);
  }
});

/**
 * Step 4 — Pairing. Claim a pairing code and bind the device to the parent account.
 */
export const claimPairingCode = onCall({ enforceAppCheck: true }, async (request) => {
  const uid = requireAuth(request.auth);
  const code = (request.data?.code as string | undefined)?.trim();
  if (!code) {
    throw new HttpsError("invalid-argument", "A pairing code is required.");
  }
  try {
    return await claimPairingCodeLogic(db, uid, code);
  } catch (e) {
    throw toHttpsError(e);
  }
});

/**
 * Step 5 — Signaling. Issue ephemeral, time-limited TURN credentials per session so no
 * static relay secret ships in the app.
 * TODO(step-5): compute HMAC TURN username/credential from TURN_SHARED_SECRET.
 */
export const getTurnCredentials = onCall({ enforceAppCheck: true }, async (request) => {
  requireAuth(request.auth);
  throw new HttpsError("unimplemented", "TURN credentials are implemented in Step 5.");
});

/**
 * Step 11 — Event history & notifications. On a new event, fan out an FCM push to the
 * owner's registered devices and write a notification document for in-app history.
 */
export const onEventCreated = onDocumentCreated("events/{eventId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data() as EventDoc;

  const copy = EVENT_NOTIFICATION_COPY[data.type];
  if (!copy) {
    logger.warn("Unknown event type", { type: data.type });
    return;
  }

  // Look up the owner's FCM tokens.
  const userSnap = await db.collection("users").doc(data.ownerId).get();
  const tokens: string[] = userSnap.get("fcmTokens") ?? [];

  // Persist an in-app notification.
  await db.collection("notifications").add({
    userId: data.ownerId,
    title: copy.title,
    body: copy.body,
    eventId: event.params.eventId,
    read: false,
    createdAt: new Date(),
  });

  if (tokens.length === 0) {
    logger.info("No FCM tokens for owner", { ownerId: data.ownerId });
    return;
  }

  await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title: copy.title, body: copy.body },
    data: { eventId: event.params.eventId, type: data.type, deviceId: data.deviceId },
  });

  logger.info("Notification fanned out", { ownerId: data.ownerId, type: data.type });
});
