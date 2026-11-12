'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createSession, postbackHash, safeEqual, parseAmount, formatAmount, SESSION_URL } = require('../src/moonetix');
const { vectors } = require('./helpers');

test('postback hash matches a postback signed by Moonetix', () => {
  const u = new URL(vectors.postbacks.credit_150);
  const p = u.searchParams;
  assert.equal(postbackHash(vectors.postback_key, p.get('tx'), p.get('user'), p.get('reward'), p.get('status')), p.get('hash'));
});

test('safeEqual compares strings of any length without throwing', () => {
  assert.equal(safeEqual('abc', 'abc'), true);
  assert.equal(safeEqual('abc', 'abd'), false);
  assert.equal(safeEqual('abc', 'abcd'), false);
  assert.equal(safeEqual('', 'a'), false);
});

test('amounts are parsed into exact integers', () => {
  assert.equal(parseAmount('150'), 150000000);
  assert.equal(parseAmount('0.75'), 750000);
  assert.equal(parseAmount('1.23456'), 1234560);
  for (const bad of ['', '-1', '1e3', '1.1234567', 'abc', '1.']) assert.equal(parseAmount(bad), null, bad);
  assert.equal(formatAmount(151984560), '151.98456');
  assert.equal(formatAmount(-750000), '-0.75');
  assert.equal(formatAmount(0), '0');
});

test('createSession sends the documented request and returns only the token', async () => {
  let seen;
  const fetchImpl = async (url, init) => {
    seen = { url, init };
    return new Response(JSON.stringify({ ok: true, token: 'sst_abc', expires_in: 600 }), { status: 201 });
  };
  const result = await createSession({ apiKey: 'k_test', userId: 42, subs: { sub1: 'home', sub9: 'x', sub2: 'bad value!' }, fetchImpl });
  assert.deepEqual(result, { ok: true, token: 'sst_abc' });
  assert.equal(seen.url, SESSION_URL);
  assert.equal(seen.url, 'https://api.moonetix.com/v1/session');
  assert.equal(seen.init.method, 'POST');
  assert.equal(seen.init.headers.Authorization, 'Bearer k_test');
  assert.deepEqual(JSON.parse(seen.init.body), { user_id: '42', sub1: 'home' });
});

test('createSession reports errors instead of throwing', async () => {
  const answer = (status, body) => async () => new Response(JSON.stringify(body), { status });
  assert.deepEqual(await createSession({ apiKey: 'k', userId: 1, fetchImpl: answer(403, { error: 'user_blocked' }) }),
    { ok: false, status: 403, error: 'user_blocked' });
  assert.deepEqual(await createSession({ apiKey: 'k', userId: 1, fetchImpl: answer(201, { token: 'not-a-token' }) }),
    { ok: false, status: 201, error: 'unexpected_response' });
  assert.deepEqual(await createSession({ apiKey: 'k', userId: 1, fetchImpl: async () => { throw new TypeError('fetch failed'); } }),
    { ok: false, status: 0, error: 'network' });
  await assert.rejects(createSession({ apiKey: 'k', userId: 'bad id', fetchImpl: answer(201, {}) }));
});
