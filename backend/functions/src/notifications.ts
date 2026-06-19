/**
 * Event → notification fan-out (Step 11). When the camera (or backend) writes an
 * `events` document, this turns it into an in-app `notifications` record and a
 * push to the owner's registered devices.
 *
 * The Firestore instance and the FCM sender are passed in so the logic is
 * unit-testable against the emulator without the trigger wrapper (FCM is mocked
 * — the emulator has no Cloud Messaging).
 */
import { Firestore, FieldValue } from "firebase-admin/firestore";
import { EVENT_NOTIFICATION_COPY, EventDoc } from "./types";

/** Sends a multicast push; mirrors `getMessaging().sendEachForMulticast`. */
export type PushSender = (message: {
  tokens: string[];
  notification: { title: string; body: string };
  data: Record<string, string>;
}) => Promise<unknown>;

export interface FanOutResult {
  /** Whether a notification document was written. */
  notified: boolean;
  /** How many FCM tokens the push targeted (0 when none were registered). */
  pushTokens: number;
  /** Set when the event was ignored (e.g. an unknown type). */
  skippedReason?: string;
}

/**
 * Writes the in-app notification and pushes to the owner's devices for one
 * created event. Returns a summary so callers/tests can assert the outcome.
 */
export async function fanOutEventNotification(
  db: Firestore,
  eventId: string,
  data: EventDoc,
  send: PushSender
): Promise<FanOutResult> {
  const copy = EVENT_NOTIFICATION_COPY[data.type];
  if (!copy) {
    return { notified: false, pushTokens: 0, skippedReason: "unknown-type" };
  }

  // Look up the owner's FCM tokens.
  const userSnap = await db.collection("users").doc(data.ownerId).get();
  const tokens: string[] = userSnap.get("fcmTokens") ?? [];

  // Persist an in-app notification for the history list.
  await db.collection("notifications").add({
    userId: data.ownerId,
    title: copy.title,
    body: copy.body,
    eventId,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  if (tokens.length === 0) {
    return { notified: true, pushTokens: 0 };
  }

  await send({
    tokens,
    notification: { title: copy.title, body: copy.body },
    data: { eventId, type: data.type, deviceId: data.deviceId },
  });

  return { notified: true, pushTokens: tokens.length };
}
