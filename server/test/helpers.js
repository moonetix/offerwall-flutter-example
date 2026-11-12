'use strict';

const { createApp } = require('../src/server');
const { openStore } = require('../src/store');
const vectors = require('./fixtures/moonetix-vectors.json');

const config = {
  port: 0,
  host: '127.0.0.1',
  databasePath: ':memory:',
  currencyName: 'Coins',
  sessionDays: 30,
  apiKey: 'test_api_key_not_secret',
  postbackKey: vectors.postback_key,
};

// Stands in for api.moonetix.com. Records every call and answers like POST /v1/session.
function fakeMoonetix() {
  const calls = [];
  let next = { status: 201, body: { ok: true, token: 'sst_test_token_1', expires_in: 600 } };
  async function fetchImpl(url, init) {
    calls.push({ url, init, body: JSON.parse(init.body) });
    if (next === 'network') throw new TypeError('fetch failed');
    return new Response(JSON.stringify(next.body), { status: next.status, headers: { 'Content-Type': 'application/json' } });
  }
  return { calls, fetchImpl, answer(status, body) { next = { status, body }; }, failNetwork() { next = 'network'; } };
}

async function startServer() {
  const store = openStore(':memory:');
  const moonetix = fakeMoonetix();
  const logs = [];
  const server = createApp({ config, store, fetchImpl: moonetix.fetchImpl, log: (m, d) => logs.push([m, d]) });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  return {
    base,
    store,
    moonetix,
    logs,
    async close() {
      await new Promise((resolve) => server.close(resolve));
      store.close();
    },
    request(method, path, { body, token } = {}) {
      const headers = {};
      if (body !== undefined) headers['Content-Type'] = 'application/json';
      if (token) headers.Authorization = `Bearer ${token}`;
      return fetch(base + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
    },
    async register(email, password = 'correct horse battery') {
      const res = await this.request('POST', '/api/register', { body: { email, password, over16: true } });
      return (await res.json()).token;
    },
    // Sends a postback URL from the fixtures to this server.
    postback(url) {
      const u = new URL(url);
      return fetch(base + u.pathname + u.search);
    },
  };
}

module.exports = { config, vectors, startServer };
