/**
 * Shared backend types. These mirror the Firestore data model documented in
 * docs/ARCHITECTURE.md. Keep them in sync with the Dart entities in apps/shared.
 */

export type DeviceStatus = "online" | "offline";

export type EventType =
  | "baby_cry"
  | "fall_detected"
  | "motion_detected"
  | "sound_detected"
  | "connection_lost";

export interface UserDoc {
  email: string;
  displayName?: string;
  createdAt: FirebaseFirestore.Timestamp;
  fcmTokens?: string[];
}

export interface DeviceSettings {
  nightMode: boolean;
  aiSensitivity: number; // 0.0 - 1.0
  notificationsEnabled: boolean;
}

export interface DeviceDoc {
  ownerId: string;
  name: string;
  status: DeviceStatus;
  lastSeenAt?: FirebaseFirestore.Timestamp;
  createdAt: FirebaseFirestore.Timestamp;
  settings?: DeviceSettings;
}

export interface EventDoc {
  deviceId: string;
  ownerId: string;
  type: EventType;
  timestamp: FirebaseFirestore.Timestamp;
  metadata?: Record<string, unknown>;
}

export interface NotificationDoc {
  userId: string;
  title: string;
  body: string;
  eventId?: string;
  read: boolean;
  createdAt: FirebaseFirestore.Timestamp;
}

/** Human-readable copy for each event type, used in push notifications. */
export const EVENT_NOTIFICATION_COPY: Record<EventType, { title: string; body: string }> = {
  baby_cry: { title: "Baby is crying", body: "Crying was detected on the camera." },
  fall_detected: { title: "Possible fall detected", body: "A possible fall was detected." },
  motion_detected: { title: "Motion detected", body: "Motion was detected on the camera." },
  sound_detected: { title: "Loud sound detected", body: "A loud sound was detected." },
  connection_lost: { title: "Camera offline", body: "Your camera went offline." },
};
