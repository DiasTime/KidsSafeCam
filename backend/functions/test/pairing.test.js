// Emulator tests for pairing logic. Run with:
//   cd backend/functions && npm run test:emulator
// (builds, then wraps `node --test` in `firebase emulators:exec`.)
const { test, before, beforeEach } = require("node:test");
const assert = require("node:assert");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const {
  requestPairingCodeLogic,
  claimPairingCodeLogic,
  hashCode,
  generateCode,
} = require("../lib/pairing.js");

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

test("generateCode produces an 8-char code", () => {
  assert.equal(generateCode().length, 8);
});

test("request then claim creates a device owned by the parent", async () => {
  const { code } = await requestPairingCodeLogic(db, "cam1", "Nursery");
  assert.equal(code.length, 8);

  const { deviceId } = await claimPairingCodeLogic(db, "parent1", code);
  const dev = (await db.collection("devices").doc(deviceId).get()).data();
  assert.equal(dev.ownerId, "parent1");
  assert.equal(dev.cameraUid, "cam1");
  assert.equal(dev.name, "Nursery");
  assert.equal(dev.status, "offline");
});

test("a code is single-use", async () => {
  const { code } = await requestPairingCodeLogic(db, "cam1", "Nursery");
  await claimPairingCodeLogic(db, "parent1", code);
  await assert.rejects(
    () => claimPairingCodeLogic(db, "parent2", code),
    /already used/
  );
});

test("an unknown code is rejected", async () => {
  await assert.rejects(
    () => claimPairingCodeLogic(db, "parent1", "ZZZZZZZZ"),
    /Invalid pairing code/
  );
});

test("an expired code is rejected", async () => {
  const code = "ABCDEFGH";
  await db.collection("pairingCodes").doc(hashCode(code)).set({
    cameraUid: "cam1",
    deviceName: "X",
    consumed: false,
    createdAt: Timestamp.fromMillis(Date.now() - 1_000_000),
    expiresAt: Timestamp.fromMillis(Date.now() - 1_000),
  });
  await assert.rejects(
    () => claimPairingCodeLogic(db, "parent1", code),
    /expired/
  );
});

test("a camera cannot mint more than 3 active codes", async () => {
  for (let i = 0; i < 3; i++) {
    await requestPairingCodeLogic(db, "cam1", "X");
  }
  await assert.rejects(
    () => requestPairingCodeLogic(db, "cam1", "X"),
    /Too many active/
  );
});

test("claims are rate-limited after repeated failures", async () => {
  for (let i = 0; i < 10; i++) {
    await assert.rejects(() => claimPairingCodeLogic(db, "brute", `NOPE${i}AA`));
  }
  await assert.rejects(
    () => claimPairingCodeLogic(db, "brute", "NOPEXXAA"),
    /Too many attempts/
  );
});
