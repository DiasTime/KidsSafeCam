// Emulator tests for the event → notification fan-out (Step 11). Run with:
//   cd backend/functions && npm run test:emulator
const { test, before, beforeEach } = require("node:test");
const assert = require("node:assert");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { fanOutEventNotification } = require("../lib/notifications.js");

const PROJECT = "kidssafecam-test";
let db;

before(() => {
  initializeApp({ projectId: PROJECT });
  db = getFirestore();
});

async function clearFirestore() {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(
    `http://${host}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
    { method: "DELETE" }
  );
}
beforeEach(clearFirestore);

// Collects the messages a real FCM sender would have multicast.
function recordingSender() {
  const sent = [];
  const send = async (message) => {
    sent.push(message);
    return { successCount: message.tokens.length };
  };
  return { sent, send };
}

const cryEvent = (ownerId = "parent1") => ({
  deviceId: "dev1",
  ownerId,
  type: "baby_cry",
  timestamp: new Date(),
});

test("writes an in-app notification with the event's copy", async () => {
  const { send, sent } = recordingSender();

  const result = await fanOutEventNotification(db, "evt1", cryEvent(), send);

  assert.equal(result.notified, true);
  const notes = await db
    .collection("notifications")
    .where("userId", "==", "parent1")
    .get();
  assert.equal(notes.size, 1);
  const note = notes.docs[0].data();
  assert.equal(note.title, "Baby is crying");
  assert.equal(note.eventId, "evt1");
  assert.equal(note.read, false);
  assert.equal(sent.length, 0, "no tokens registered → no push");
});

test("pushes to all of the owner's registered FCM tokens", async () => {
  await db
    .collection("users")
    .doc("parent1")
    .set({ email: "p@x.com", fcmTokens: ["tok-a", "tok-b"] });
  const { send, sent } = recordingSender();

  const result = await fanOutEventNotification(db, "evt2", cryEvent(), send);

  assert.equal(result.pushTokens, 2);
  assert.equal(sent.length, 1);
  assert.deepEqual(sent[0].tokens, ["tok-a", "tok-b"]);
  assert.equal(sent[0].notification.title, "Baby is crying");
  assert.equal(sent[0].data.eventId, "evt2");
  assert.equal(sent[0].data.type, "baby_cry");
});

test("ignores an unknown event type (no notification, no push)", async () => {
  const { send, sent } = recordingSender();

  const result = await fanOutEventNotification(
    db,
    "evt3",
    { deviceId: "dev1", ownerId: "parent1", type: "not_a_real_type" },
    send
  );

  assert.equal(result.notified, false);
  assert.equal(result.skippedReason, "unknown-type");
  const notes = await db.collection("notifications").get();
  assert.equal(notes.size, 0);
  assert.equal(sent.length, 0);
});

test("notifies in-app even when the owner has no tokens", async () => {
  await db.collection("users").doc("parent1").set({ email: "p@x.com" });
  const { send, sent } = recordingSender();

  const result = await fanOutEventNotification(db, "evt4", cryEvent(), send);

  assert.equal(result.notified, true);
  assert.equal(result.pushTokens, 0);
  assert.equal(sent.length, 0);
});
