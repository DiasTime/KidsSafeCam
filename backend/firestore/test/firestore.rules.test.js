// Firestore security-rules unit tests. Run against the emulator with:
//   cd backend/firestore && npm install && npm test
// (npm test wraps these in `firebase emulators:exec`.)
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { before, after, beforeEach, test } = require('node:test');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

let testEnv;

const ALICE = 'alice';
const BOB = 'bob';

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'kidssafecam-test',
    firestore: {
      rules: readFileSync(join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// Helpers
const db = (uid) =>
  uid
    ? testEnv.authenticatedContext(uid).firestore()
    : testEnv.unauthenticatedContext().firestore();

async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

// ── users ──────────────────────────────────────────────────
test('users: a user can create and read their own profile', async () => {
  const d = db(ALICE);
  await assertSucceeds(
    d.collection('users').doc(ALICE).set({ email: 'a@x.com', createdAt: new Date() })
  );
  await assertSucceeds(d.collection('users').doc(ALICE).get());
});

test('users: a user cannot read someone else\'s profile', async () => {
  await seed((d) => d.collection('users').doc(BOB).set({ email: 'b@x.com' }));
  await assertFails(db(ALICE).collection('users').doc(BOB).get());
});

test('users: create requires the doc id to equal the uid', async () => {
  await assertFails(
    db(ALICE).collection('users').doc(BOB).set({ email: 'a@x.com' })
  );
});

// ── devices ────────────────────────────────────────────────
test('devices: owner can create a device owned by self', async () => {
  await assertSucceeds(
    db(ALICE).collection('devices').doc('d1').set({
      ownerId: ALICE,
      name: 'Nursery',
      status: 'offline',
      createdAt: new Date(),
    })
  );
});

test('devices: cannot create a device owned by someone else', async () => {
  await assertFails(
    db(ALICE).collection('devices').doc('d1').set({
      ownerId: BOB,
      name: 'Nursery',
    })
  );
});

test('devices: non-owner cannot read the device', async () => {
  await seed((d) =>
    d.collection('devices').doc('d1').set({ ownerId: ALICE, name: 'Nursery' })
  );
  await assertFails(db(BOB).collection('devices').doc('d1').get());
  await assertSucceeds(db(ALICE).collection('devices').doc('d1').get());
});

test('devices: ownership cannot be reassigned on update', async () => {
  await seed((d) =>
    d.collection('devices').doc('d1').set({ ownerId: ALICE, name: 'Nursery' })
  );
  await assertFails(
    db(ALICE).collection('devices').doc('d1').update({ ownerId: BOB })
  );
  await assertSucceeds(
    db(ALICE).collection('devices').doc('d1').update({ name: 'Bedroom' })
  );
});

// ── signaling subcollection ────────────────────────────────
test('calls: only the device owner can write signaling data', async () => {
  await seed((d) =>
    d.collection('devices').doc('d1').set({ ownerId: ALICE, name: 'Nursery' })
  );
  await assertSucceeds(
    db(ALICE).collection('devices').doc('d1').collection('calls').doc('c1')
      .set({ offer: { sdp: 'x', type: 'offer' } })
  );
  await assertFails(
    db(BOB).collection('devices').doc('d1').collection('calls').doc('c1')
      .set({ offer: { sdp: 'x', type: 'offer' } })
  );
});

test('calls: the paired camera can also exchange signaling', async () => {
  await seed((d) =>
    d.collection('devices').doc('d1')
      .set({ ownerId: ALICE, cameraUid: 'cam', name: 'Nursery' })
  );
  await assertSucceeds(
    db('cam').collection('devices').doc('d1').collection('calls').doc('c1')
      .set({ answer: { sdp: 'y', type: 'answer' } })
  );
  await assertFails(
    db(BOB).collection('devices').doc('d1').collection('calls').doc('c1')
      .set({ answer: { sdp: 'y', type: 'answer' } })
  );
});

test('devices: paired camera can read and heartbeat but not rename', async () => {
  await seed((d) =>
    d.collection('devices').doc('d1')
      .set({ ownerId: ALICE, cameraUid: 'cam', name: 'Nursery', status: 'offline' })
  );
  await assertSucceeds(db('cam').collection('devices').doc('d1').get());
  await assertSucceeds(
    db('cam').collection('devices').doc('d1')
      .update({ status: 'online', lastSeenAt: new Date() })
  );
  // camera cannot change non-heartbeat fields
  await assertFails(
    db('cam').collection('devices').doc('d1').update({ name: 'Hijacked' })
  );
  // unrelated users still cannot read
  await assertFails(db(BOB).collection('devices').doc('d1').get());
});

// ── events ─────────────────────────────────────────────────
test('events: owner can create a self-owned event but cannot mutate it', async () => {
  const d = db(ALICE);
  await assertSucceeds(
    d.collection('events').doc('e1').set({
      ownerId: ALICE,
      deviceId: 'd1',
      type: 'baby_cry',
      timestamp: new Date(),
    })
  );
  await assertFails(d.collection('events').doc('e1').update({ type: 'fall_detected' }));
  await assertFails(d.collection('events').doc('e1').delete());
});

test('events: cannot read another user\'s events', async () => {
  await seed((d) =>
    d.collection('events').doc('e1').set({ ownerId: ALICE, deviceId: 'd1', type: 'baby_cry' })
  );
  await assertFails(db(BOB).collection('events').doc('e1').get());
});

// ── notifications ──────────────────────────────────────────
test('notifications: clients cannot create (Cloud Functions only) but owner can mark read', async () => {
  await seed((d) =>
    d.collection('notifications').doc('n1').set({
      userId: ALICE,
      title: 'Baby is crying',
      body: 'x',
      read: false,
      createdAt: new Date(),
    })
  );
  // client create is denied
  await assertFails(
    db(ALICE).collection('notifications').doc('n2').set({ userId: ALICE, read: false })
  );
  // owner can mark their own as read
  await assertSucceeds(
    db(ALICE).collection('notifications').doc('n1').update({ read: true })
  );
  // other users cannot
  await assertFails(
    db(BOB).collection('notifications').doc('n1').update({ read: true })
  );
});

// ── unauthenticated ────────────────────────────────────────
test('unauthenticated access is denied everywhere', async () => {
  const d = db(null);
  await assertFails(d.collection('users').doc(ALICE).get());
  await assertFails(d.collection('devices').doc('d1').get());
  await assertFails(d.collection('events').doc('e1').get());
});
