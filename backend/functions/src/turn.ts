/**
 * Ephemeral TURN credentials (Step 5).
 *
 * Long-lived TURN secrets must never ship in the app (docs/SECURITY.md, T5).
 * Instead a Cloud Function issues time-limited credentials using the coturn
 * "TURN REST API" scheme: the username is `<expiry-unix>:<uid>` and the
 * credential is base64(HMAC-SHA1(username, sharedSecret)). The TURN server is
 * configured with the same `static-auth-secret`, so it can verify without any
 * per-user state.
 *
 * Configure via env: TURN_SHARED_SECRET and TURN_URLS (comma-separated, e.g.
 * "turn:turn.example.com:3478?transport=udp,turns:turn.example.com:5349").
 * If unset (local dev), only public STUN is returned.
 */
import { createHmac } from "crypto";

export interface IceServer {
  urls: string | string[];
  username?: string;
  credential?: string;
}

export interface IceConfig {
  iceServers: IceServer[];
  ttl: number;
}

const DEFAULT_TTL_SECONDS = 12 * 60 * 60; // 12h
const STUN_SERVERS = ["stun:stun.l.google.com:19302"];

export function makeTurnCredential(
  uid: string,
  sharedSecret: string,
  ttlSeconds: number,
  now: number
): { username: string; credential: string; expiresAt: number } {
  const expiry = Math.floor(now / 1000) + ttlSeconds;
  const username = `${expiry}:${uid}`;
  const credential = createHmac("sha1", sharedSecret)
    .update(username)
    .digest("base64");
  return { username, credential, expiresAt: expiry };
}

/**
 * Build the ICE configuration for a user. Always includes STUN; adds TURN with
 * ephemeral credentials when a shared secret + URLs are configured.
 */
export function buildIceConfig(
  uid: string,
  opts: {
    sharedSecret?: string;
    turnUrls?: string;
    ttlSeconds?: number;
    now?: number;
  } = {}
): IceConfig {
  const ttl = opts.ttlSeconds ?? DEFAULT_TTL_SECONDS;
  const iceServers: IceServer[] = [{ urls: STUN_SERVERS }];

  const urls = (opts.turnUrls ?? "")
    .split(",")
    .map((u) => u.trim())
    .filter(Boolean);

  if (opts.sharedSecret && urls.length > 0) {
    const { username, credential } = makeTurnCredential(
      uid,
      opts.sharedSecret,
      ttl,
      opts.now ?? Date.now()
    );
    iceServers.push({ urls, username, credential });
  }

  return { iceServers, ttl };
}
