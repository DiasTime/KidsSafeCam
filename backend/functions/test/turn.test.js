// Unit tests for TURN credential logic (no emulator needed). Run after build:
//   npm run build && node --test test/turn.test.js
const { test } = require("node:test");
const assert = require("node:assert");
const { createHmac } = require("node:crypto");
const { makeTurnCredential, buildIceConfig } = require("../lib/turn.js");

const NOW = 1_700_000_000_000; // fixed clock

test("makeTurnCredential uses the coturn REST scheme", () => {
  const { username, credential, expiresAt } = makeTurnCredential(
    "alice",
    "s3cret",
    3600,
    NOW
  );
  const expectedExpiry = Math.floor(NOW / 1000) + 3600;
  assert.equal(expiresAt, expectedExpiry);
  assert.equal(username, `${expectedExpiry}:alice`);

  const expectedCred = createHmac("sha1", "s3cret")
    .update(username)
    .digest("base64");
  assert.equal(credential, expectedCred);
});

test("buildIceConfig returns STUN-only when TURN is unconfigured", () => {
  const cfg = buildIceConfig("alice", { now: NOW });
  assert.equal(cfg.iceServers.length, 1);
  assert.ok(cfg.iceServers[0].urls[0].startsWith("stun:"));
  assert.equal(cfg.iceServers[0].username, undefined);
});

test("buildIceConfig adds TURN with ephemeral credentials when configured", () => {
  const cfg = buildIceConfig("alice", {
    sharedSecret: "s3cret",
    turnUrls: "turn:turn.example.com:3478?transport=udp, turns:turn.example.com:5349",
    ttlSeconds: 3600,
    now: NOW,
  });
  assert.equal(cfg.iceServers.length, 2);
  const turn = cfg.iceServers[1];
  assert.deepEqual(turn.urls, [
    "turn:turn.example.com:3478?transport=udp",
    "turns:turn.example.com:5349",
  ]);
  assert.ok(turn.username.endsWith(":alice"));
  assert.ok(turn.credential.length > 0);
});
