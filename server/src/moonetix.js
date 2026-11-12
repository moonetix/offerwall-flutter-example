'use strict';

const crypto = require('node:crypto');

const SESSION_URL = 'https://api.moonetix.com/v1/session';
const USER_ID_RE = /^[A-Za-z0-9._@:+-]{1,100}$/;
const SUB_ID_RE = /^[A-Za-z0-9._~:@+-]{1,100}$/;
const AMOUNT_RE = /^(\d{1,9})(?:\.(\d{1,6}))?$/;

// Units of 1/1,000,000 coin. Integers keep balances exact.
const MICRO = 1000000;

// Asks Moonetix for a single-use offerwall session for one of YOUR account IDs.
// The token works once and for 10 minutes. Server side only: it needs the API key.
// Returns { ok: true, token } or { ok: false, status, error }.
async function createSession({ apiKey, userId, subs = {}, fetchImpl = fetch, timeoutMs = 10000 }) {
  const uid = String(userId);
  if (!USER_ID_RE.test(uid)) throw new Error('user_id must be 1 to 100 characters from A-Z a-z 0-9 . _ @ : + -');
  const body = { user_id: uid };
  for (const [key, value] of Object.entries(subs)) {
    if (/^sub[1-5]$/.test(key) && SUB_ID_RE.test(String(value))) body[key] = String(value);
  }

  let res;
  try {
    res = await fetchImpl(SESSION_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch {
    return { ok: false, status: 0, error: 'network' };
  }
  const data = await res.json().catch(() => ({}));
  if (res.status === 201 && typeof data.token === 'string' && data.token.startsWith('sst_')) {
    return { ok: true, token: data.token };
  }
  return { ok: false, status: res.status, error: String(data.error || 'unexpected_response') };
}

function postbackHash(postbackKey, tx, userId, reward, status) {
  return crypto.createHmac('sha256', postbackKey).update(`${tx}:${userId}:${reward}:${status}`).digest('hex');
}

function safeEqual(given, expected) {
  const a = Buffer.from(String(given));
  const b = Buffer.from(String(expected));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

// "150" -> 150000000, "0.75" -> 750000. Returns null for anything else.
function parseAmount(value) {
  const m = AMOUNT_RE.exec(String(value));
  if (!m) return null;
  return Number(m[1]) * MICRO + Number((m[2] || '').padEnd(6, '0'));
}

function formatAmount(micro) {
  const sign = micro < 0 ? '-' : '';
  const abs = Math.abs(micro);
  const whole = Math.floor(abs / MICRO);
  const frac = String(abs % MICRO).padStart(6, '0').replace(/0+$/, '');
  return sign + whole + (frac ? '.' + frac : '');
}

module.exports = { SESSION_URL, createSession, postbackHash, safeEqual, parseAmount, formatAmount };
