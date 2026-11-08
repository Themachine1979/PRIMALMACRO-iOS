import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import worker, { sanitizeFoods, ScanState, analyze } from '../src/worker.js';
import { accountToken, bundleID, checkEntitlement } from '../src/access.js';

function fixture(limits = {}) {
  const db = new DatabaseSync(':memory:');
  const storage = {
    sql: {
      exec(query, ...args) {
        const stmt = db.prepare(query);
        if (!query.startsWith('SELECT') && !query.includes('RETURNING')) stmt.run(...args);
        return { toArray: () => stmt.all(...args) };
      }
    },
    transactionSync(callback) {
      db.exec('BEGIN');
      try {
        const result = callback();
        db.exec('COMMIT');
        return result;
      } catch (error) {
        db.exec('ROLLBACK');
        throw error;
      }
    }
  };
  const env = {
    OPENAI_API_KEY: 'test-only',
    SESSION_SECRET: 'test-only'.repeat(6),
    SCANS_ENABLED: 'true',
    APP_STORE_ENVIRONMENT: 'Sandbox',
    APP_STORE_ISSUER_ID: 'test-issuer',
    APP_STORE_KEY_ID: 'test-key',
    APP_STORE_PRIVATE_KEY: 'configured',
    SCAN_RATE_LIMIT: { limit: async () => ({ success: true }) },
    SCAN_USER_DAILY_LIMIT: '1',
    SCAN_DAILY_LIMIT: '2',
    SCAN_TOTAL_LIMIT: '3',
    ...limits
  };
  const state = new ScanState({ storage }, env);
  env.SCAN_STATE = {
    idFromName: name => name,
    get: () => ({ fetch: (url, init) => state.fetch(new Request(url, init)) })
  };
  return { env, db, state };
}

const request = (route, body, token) => new Request('https://scanner.example/' + route, {
  method: 'POST',
  headers: { 'content-type': 'application/json', ...(token ? { authorization: 'Bearer ' + token } : {}) },
  body: body ? JSON.stringify(body) : undefined
});
const imageBase64 = '/9j/' + 'aAAA'.repeat(20);
const scan = { mode: 'food', imageBase64, transactionID: '123' };
const b64 = value => Buffer.from(value).toString('base64url');
const segment = value => b64(JSON.stringify(value));

test('health works with the scanner off', async () => {
  assert.equal((await worker.fetch(new Request('https://scanner.example/health'), {})).status, 200);
});
test('disabled or missing bindings fail closed', async () => {
  const { env, db } = fixture();
  assert.equal((await worker.fetch(request('scan', scan), { ...env, SCANS_ENABLED: 'false' })).status, 503);
  assert.equal((await worker.fetch(request('scan', scan), { ...env, SCAN_STATE: undefined })).status, 503);
  db.close();
});
test('startup failure diagnostics are safe and distinguish missing configuration categories', async t => {
  const { env, db } = fixture();
  t.after(() => db.close());
  for (const [override, expected] of [
    [{ SCANS_ENABLED: 'false' }, 'CONFIG_DISABLED'],
    [{ OPENAI_API_KEY: undefined }, 'CONFIG_OPENAI_KEY'],
    [{ SESSION_SECRET: 'short' }, 'CONFIG_SESSION_SECRET'],
    [{ APP_STORE_KEY_ID: undefined }, 'CONFIG_APP_STORE_KEYS'],
    [{ APP_STORE_ENVIRONMENT: 'invalid' }, 'CONFIG_APP_STORE_ENV'],
    [{ SCAN_RATE_LIMIT: undefined }, 'CONFIG_RATE_LIMIT_BINDING'],
    [{ SCAN_STATE: undefined }, 'CONFIG_STATE_BINDING']
  ]) {
    const response = await worker.fetch(request('challenge'), { ...env, ...override });
    assert.equal(response.status, 503);
    const output = await response.json();
    assert.equal(output.code, expected);
    assert.equal(JSON.stringify(output).includes(env.OPENAI_API_KEY), false);
    assert.equal(JSON.stringify(output).includes(env.SESSION_SECRET), false);
  }
  const unavailable = { ...env, SCAN_RATE_LIMIT: { limit: async () => { throw new Error('internal'); } } };
  const response = await worker.fetch(request('challenge'), unavailable);
  assert.equal(response.status, 503);
  assert.equal((await response.json()).code, 'RATE_LIMIT_UNAVAILABLE');
});

test('throttles before processing and rejects missing and forged sessions', async () => {
  const { env, db } = fixture();
  const throttled = { ...env, SCAN_RATE_LIMIT: { limit: async () => ({ success: false }) } };
  assert.equal((await worker.fetch(request('scan', scan), throttled)).status, 429);
  assert.equal((await worker.fetch(request('scan', scan), env)).status, 401);
  assert.equal((await worker.fetch(request('scan', scan, 'forged.session'), env)).status, 401);
  db.close();
});

test('sanitizeFoods constrains unsupported fields', () => {
  const [food] = sanitizeFoods([{ name: ' Porridge ', serving: '', calories: -4,
    proteinG: 11.348, carbsG: 30, fatG: Infinity, fiberG: 7, confidence: 'certain' }]);
  assert.equal(food.name, 'Porridge');
  assert.equal(food.calories, 0);
  assert.equal(food.proteinG, 11.3);
  assert.equal(food.confidence, 'low');
});

test('atomic reservations enforce per-user, daily and lifetime budgets', async () => {
  const { db, state } = fixture();
  const reserve = async subject => (await (await state.fetch(request('state',
    { operation: 'reserve', subject }))).json()).allowed;
  const sameUser = await Promise.all(Array.from({ length: 10 }, () => reserve('a')));
  assert.equal(sameUser.filter(Boolean).length, 1);
  assert.equal(await reserve('b'), true);
  assert.equal(await reserve('c'), false);
  db.exec("UPDATE quota SET key = REPLACE(key, 'day:', 'day:2000-01-01:') WHERE key LIKE 'day:%'");
  assert.equal(await reserve('a'), true);
  assert.equal(await reserve('b'), false);
  assert.equal(db.prepare("SELECT count FROM quota WHERE key = 'total'").get().count, 3);
  db.close();
});

test('failed Apple public-key lookup returns a safe diagnostic without leaking tokens', async t => {
  const { env, db } = fixture();
  t.after(() => db.close());
  const started = await worker.fetch(request('challenge'), env);
  assert.equal(started.status, 200);
  const { nonce } = await started.json();
  const iat = Math.floor(Date.now() / 1000);
  const unverifiedToken = segment({ alg: 'RS256', kid: 'diagnostic-test' }) + '.' +
    segment({ iss: 'https://appleid.apple.com', aud: bundleID, sub: 'test',
      iat, exp: iat + 300, nonce }) + '.AAAA';
  t.mock.method(globalThis, 'fetch', async url => {
    assert.equal(url, 'https://appleid.apple.com/auth/keys');
    return new Response('unavailable', { status: 503 });
  });
  const r = await worker.fetch(request('session',
    { identityToken: unverifiedToken, nonce }), env);
  assert.equal(r.status, 503);
  const details = await r.json();
  assert.equal(details.code, 'APPLE_KEYS_UNAVAILABLE');
  assert.equal(JSON.stringify(details).includes(unverifiedToken), false);
});

test('Apple public-key HTTP failure reports status only, never response body or credentials', async t => {
  const { env, db } = fixture();
  t.after(() => db.close());
  const warningLines = [];
  t.mock.method(console, 'warn', line => warningLines.push(line));
  const started = await worker.fetch(request('challenge'), env);
  const { nonce } = await started.json();
  const iat = Math.floor(Date.now() / 1000);
  const identityToken = segment({ alg: 'RS256', kid: 'unknown' }) + '.' +
    segment({ iss: 'https://appleid.apple.com', aud: bundleID, sub: 'test',
      iat, exp: iat + 300, nonce }) + '.AAAA';
  t.mock.method(globalThis, 'fetch', async () =>
    new Response('SECRET_BODY_NOT_FOR_LOGS', { status: 403 }));
  const reply = await worker.fetch(request('session', { nonce, identityToken }), env);
  assert.equal(reply.status, 503);
  assert.equal((await reply.json()).code, 'APPLE_KEYS_UNAVAILABLE');
  assert.deepEqual(warningLines, [
    'PM_APPLE_KEYS_DETAIL: HTTP_403',
    'PM_SESSION_STAGE: APPLE_PUBLIC_KEYS'
  ]);
  assert.equal(JSON.stringify(warningLines).includes(identityToken), false);
  assert.equal(JSON.stringify(warningLines).includes('SECRET_BODY_NOT_FOR_LOGS'), false);
});

test('Apple key endpoint redirects are rejected and are never followed', async t => {
  const { env, db } = fixture();
  t.after(() => db.close());
  const started = await worker.fetch(request('challenge'), env);
  const { nonce } = await started.json();
  const iat = Math.floor(Date.now() / 1000);
  const token = segment({ alg: 'RS256', kid: 'test' }) + '.' +
    segment({ iss: 'https://appleid.apple.com', aud: bundleID, sub: 'test',
      iat, exp: iat + 300, nonce }) + '.AAAA';
  let requests = 0;
  t.mock.method(console, 'warn', () => {});
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    requests++;
    assert.equal(url, 'https://appleid.apple.com/auth/keys');
    assert.equal(options.redirect, 'manual');
    return new Response(null, { status: 302, headers: { location: 'https://untrusted.example/key' } });
  });
  const reply = await worker.fetch(request('session', { nonce, identityToken: token }), env);
  assert.equal(reply.status, 503);
  assert.equal((await reply.json()).code, 'APPLE_KEYS_UNAVAILABLE');
  assert.equal(requests, 1);
});

test('Apple signature, nonce, replay, live entitlement and quotas gate the only OpenAI call', async t => {
  const { env, db } = fixture();
  t.after(() => db.close());
  const signingAlgorithm = { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' };
  const apple = await crypto.subtle.generateKey(signingAlgorithm, true, ['sign', 'verify']);
  const jwk = { ...await crypto.subtle.exportKey('jwk', apple.publicKey), kid: 'test', use: 'sig', alg: 'RS256' };
  const appStoreKey = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  env.APP_STORE_PRIVATE_KEY = Buffer.from(await crypto.subtle.exportKey('pkcs8', appStoreKey.privateKey)).toString('base64');

  const subject = 'apple-test-user';
  const tokenForUser = await accountToken(subject);
  assert.equal(tokenForUser, 'fa8fd582-3ac7-8104-9c95-7ecf950ef18e');
  const tx = {
    bundleId: bundleID, environment: 'Sandbox', originalTransactionId: '123',
    productId: bundleID + '.monthly', appAccountToken: tokenForUser, inAppOwnershipType: 'PURCHASED',
    expiresDate: Date.now() + 60000
  };
  let status = 1;
  let storeHTTPStatus = 200;
  let aiCalls = 0;
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    if (url === 'https://appleid.apple.com/auth/keys') {
      assert.equal(options.redirect, 'manual'); // Cloudflare Workers cannot use "error".
      return Response.json({ keys: [jwk] });
    }
    if (url === 'https://api.storekit-sandbox.apple.com/inApps/v1/subscriptions/123') {
      assert.equal(options.redirect, 'manual');
      if (storeHTTPStatus !== 200) return new Response('do not expose App Store API response', { status: storeHTTPStatus });
      const [header, claims, signature] = options.headers.authorization.slice(7).split('.');
      assert.equal(JSON.parse(Buffer.from(claims, 'base64url')).bid, bundleID);
      assert.equal(await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, appStoreKey.publicKey,
        Buffer.from(signature, 'base64url'), Buffer.from(header + '.' + claims)), true);
      return Response.json({ bundleId: bundleID, environment: 'Sandbox', data: [{ lastTransactions: [{
        status, originalTransactionId: '123', signedTransactionInfo: 'stub.' + segment(tx) + '.stub'
      }] }] });
    }
    assert.equal(url, 'https://api.openai.com/v1/chat/completions');
    assert.equal(options.redirect, 'manual');
    aiCalls++;
    return Response.json({ choices: [{ message: { content: JSON.stringify({
      foods: [{ name: 'Chicken bowl', calories: 500, proteinG: 45 }], disclaimer: 'Portion estimated'
    }) } }] });
  });
  const challenge = await worker.fetch(request('challenge'), env);
  assert.equal(challenge.status, 200);
  const { nonce } = await challenge.json();
  const iat = Math.floor(Date.now() / 1000);
  const claims = { iss: 'https://appleid.apple.com', aud: bundleID, sub: subject, iat, exp: iat + 300, nonce };
  async function jwt(overrides) {
    const unsigned = segment({ alg: 'RS256', kid: 'test' }) + '.' + segment({ ...claims, ...overrides });
    const signature = await crypto.subtle.sign(signingAlgorithm.name, apple.privateKey, Buffer.from(unsigned));
    return unsigned + '.' + b64(signature);
  }
  for (const overrides of [{ nonce: 'wrong' }, { aud: 'wrong' }, { exp: iat - 1 }]) {
    assert.equal((await worker.fetch(request('session', { nonce, identityToken: await jwt(overrides) }), env)).status, 401);
  }
  const identityToken = await jwt();
  assert.equal((await worker.fetch(request('session', {
    nonce, identityToken: identityToken.replace(/\.[^.]+$/, '.AAAA')
  }), env)).status, 401);
  // An unavailable Durable Object must fail closed and report only a fixed,
  // non-sensitive stage label. The nonce must remain reusable after recovery.
  const savedState = env.SCAN_STATE;
  const warnings = [];
  const warn = t.mock.method(console, 'warn', message => warnings.push(message));
  env.SCAN_STATE = { ...savedState, get: () => ({
    fetch: async () => { throw new Error('fake internal storage failure'); }
  }) };
  const unavailable = await worker.fetch(request('session', { nonce, identityToken }), env);
  assert.equal(unavailable.status, 503);
  assert.equal((await unavailable.json()).code, 'QUOTA_STORAGE_UNAVAILABLE');
  assert.deepEqual(warnings, ['PM_SESSION_STAGE: NONCE_STORAGE']);
  assert.equal(JSON.stringify(warnings).includes(identityToken), false);
  env.SCAN_STATE = savedState;
  warn.mock.restore();
  const login = await worker.fetch(request('session', { nonce, identityToken }), env);
  assert.equal(login.status, 200);
  const { token, expiresAt } = await login.json();
  // Secure sessions stay available without another Apple prompt every day.
  // The actual subscription entitlement is still checked on every scan.
  assert.ok(expiresAt > Math.floor(Date.now() / 1000) + 29 * 86_400);
  assert.ok(expiresAt < Math.floor(Date.now() / 1000) + 31 * 86_400);
  assert.equal((await worker.fetch(request('session', { nonce, identityToken }), env)).status, 401);
  assert.equal((await worker.fetch(request('scan', { ...scan, mode: 'invalid' }, token), env)).status, 400);
  assert.equal((await worker.fetch(request('scan', { ...scan, imageBase64: 'x'.repeat(2_801_025) }, token), env)).status, 413);
  // Fail closed with a safe, fixed diagnostic when a malformed App Store key
  // or an upstream HTTP error prevents subscription verification.
  const diagnosticWarnings = [];
  const diagnosticMock = t.mock.method(console, 'warn', line => diagnosticWarnings.push(line));
  const originalPrivateKey = env.APP_STORE_PRIVATE_KEY;
  env.APP_STORE_PRIVATE_KEY = 'not-a-valid-p8-key';
  const badKey = await worker.fetch(request('scan', scan, token), env);
  assert.equal(badKey.status, 503);
  assert.equal((await badKey.json()).code, 'SCANNER_SERVICE_UNAVAILABLE');
  assert.deepEqual(diagnosticWarnings, ['PM_SCAN_STAGE: APP_STORE_JWT_SIGNING']);
  assert.equal(JSON.stringify(diagnosticWarnings).includes(env.APP_STORE_PRIVATE_KEY), false);
  env.APP_STORE_PRIVATE_KEY = originalPrivateKey;
  diagnosticWarnings.length = 0;
  storeHTTPStatus = 401;
  const badHTTP = await worker.fetch(request('scan', scan, token), env);
  assert.equal(badHTTP.status, 503);
  assert.equal((await badHTTP.json()).code, 'SCANNER_SERVICE_UNAVAILABLE');
  assert.deepEqual(diagnosticWarnings, ['PM_SCAN_STAGE: APP_STORE_HTTP_401']);
  assert.equal(JSON.stringify(diagnosticWarnings).includes('do not expose App Store'), false);
  storeHTTPStatus = 200;
  diagnosticMock.mock.restore();
  assert.equal(aiCalls, 0);
  tx.appAccountToken = await accountToken('another-user');
  assert.equal((await worker.fetch(request('scan', scan, token), env)).status, 403);
  tx.appAccountToken = tokenForUser;
  tx.revocationDate = Date.now();
  assert.equal((await worker.fetch(request('scan', scan, token), env)).status, 403);
  delete tx.revocationDate;
  status = 2;
  assert.equal((await worker.fetch(request('scan', scan, token), env)).status, 403);
  assert.equal(aiCalls, 0);
  status = 1;
  const valid = await worker.fetch(request('scan', scan, token), env);
  assert.equal(valid.status, 200);
  assert.equal((await valid.json()).foods[0].proteinG, 45);
  assert.equal((await worker.fetch(request('scan', scan, token), env)).status, 429);
  assert.equal(aiCalls, 1);
});


test('OpenAI diagnostic stages distinguish HTTP, network, and malformed responses without disclosing secrets', async t => {
  const { env, db } = fixture();
  t.after(() => db.close());
  env.OPENAI_API_KEY = 'PRIVATE_TEST_KEY';
  const warnings = [];
  t.mock.method(console, 'warn', message => warnings.push(message));
  let scenario = 'http';
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    assert.equal(url, 'https://api.openai.com/v1/chat/completions');
    assert.equal(options.redirect, 'manual');
    assert.equal(options.headers.authorization, 'Bearer PRIVATE_TEST_KEY');
    if (scenario === 'http') return new Response('PRIVATE_ERROR_BODY', { status: 401 });
    if (scenario === 'network') throw new Error('PRIVATE_NETWORK_DETAILS');
    if (scenario === 'bad') return new Response('not JSON', { status: 200 });
    return Response.json({ choices: [{ message: { content:
      '{"foods":[{"name":"Soup","calories":150}],"disclaimer":"Estimated"}' } }] });
  });
  const input = { mode: 'food', imageBase64 };
  assert.equal((await analyze(input, env)).status, 502);
  scenario = 'network';
  assert.equal((await analyze(input, env)).status, 502);
  scenario = 'bad';
  assert.equal((await analyze(input, env)).status, 502);
  scenario = 'ok';
  const valid = await analyze(input, env);
  assert.equal(valid.status, 200);
  assert.equal((await valid.json()).foods[0].name, 'Soup');
  assert.deepEqual(warnings, [
    'PM_AI_STAGE: OPENAI_HTTP_401',
    'PM_AI_STAGE: OPENAI_NETWORK_OR_TIMEOUT',
    'PM_AI_STAGE: OPENAI_BAD_RESPONSE'
  ]);
  assert.equal(JSON.stringify(warnings).includes('PRIVATE_TEST_KEY'), false);
  assert.equal(JSON.stringify(warnings).includes('PRIVATE_ERROR_BODY'), false);
  assert.equal(JSON.stringify(warnings).includes('PRIVATE_NETWORK_DETAILS'), false);
});


test('Auto mode validates production and TestFlight transactions without unsafe fallback', async t => {
  const { env, db } = fixture({ APP_STORE_ENVIRONMENT: 'Auto' });
  t.after(() => db.close());
  const keyPair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  env.APP_STORE_PRIVATE_KEY = Buffer.from(await crypto.subtle.exportKey('pkcs8', keyPair.privateKey)).toString('base64');
  const subject = 'auto-mode-test-user';
  const linkedAccount = await accountToken(subject);
  const originalID = '123';
  const uri = environment => environment === 'Production'
    ? 'https://api.storekit.apple.com/inApps/v1/subscriptions/123'
    : 'https://api.storekit-sandbox.apple.com/inApps/v1/subscriptions/123';
  const makeStatus = (environment, overrides = {}) => {
    const payload = {
      bundleId: bundleID, environment, originalTransactionId: originalID,
      productId: bundleID + '.monthly', appAccountToken: linkedAccount,
      inAppOwnershipType: 'PURCHASED', expiresDate: Date.now() + 60_000,
      ...overrides
    };
    return Response.json({
      bundleId: bundleID, environment,
      data: [{ lastTransactions: [{
        status: 1, originalTransactionId: originalID,
        signedTransactionInfo: 'stub.' + segment(payload) + '.stub'
      }] }]
    });
  };
  let scenario = 'production';
  let calls = [];
  const warnings = [];
  t.mock.method(console, 'warn', line => warnings.push(line));
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    calls.push(url);
    assert.equal(options.redirect, 'manual');
    assert.equal(options.headers.authorization.startsWith('Bearer '), true);
    if (url === uri('Production')) {
      if (scenario === 'sandbox') return Response.json({ errorCode: 4040010 }, { status: 404 });
      if (scenario === 'unknown404') return Response.json({ errorCode: 4040005 }, { status: 404 });
      if (['unauthorized', 'unauthorizedBadSandbox', 'unauthorizedSandbox401'].includes(scenario)) {
        return new Response('NO_SECRET_LEAK', { status: 401 });
      }
      if (scenario === 'badEnv') return makeStatus('Sandbox');
      if (scenario === 'badAccount') return makeStatus('Production', { appAccountToken: await accountToken('someone-else') });
      return makeStatus('Production');
    }
    if (url === uri('Sandbox')) {
      if (scenario === 'unauthorizedBadSandbox') {
        return makeStatus('Sandbox', { appAccountToken: await accountToken('another-apple-id') });
      }
      if (scenario === 'unauthorizedSandbox401') {
        return new Response('PRIVATE_APPLE_BODY', { status: 401 });
      }
      return makeStatus('Sandbox');
    }
    throw new Error('Unexpected Apple API host');
  });

  assert.equal(await checkEntitlement(env, subject, originalID), true);
  assert.deepEqual(calls, [uri('Production')]);
  scenario = 'sandbox'; calls = [];
  assert.equal(await checkEntitlement(env, subject, originalID), true);
  assert.deepEqual(calls, [uri('Production'), uri('Sandbox')]);
  scenario = 'unknown404'; calls = [];
  assert.equal(await checkEntitlement(env, subject, originalID), false);
  assert.deepEqual(calls, [uri('Production')]);
  // Before first public release, Apple may reject production access with 401,
  // while a genuine sandbox transaction still verifies successfully.
  scenario = 'unauthorized'; calls = [];
  assert.equal(await checkEntitlement(env, subject, originalID), true);
  assert.deepEqual(calls, [uri('Production'), uri('Sandbox')]);
  assert.deepEqual(warnings, ['PM_SCAN_STAGE: PRODUCTION_401_SANDBOX_FALLBACK']);
  assert.equal(JSON.stringify(warnings).includes('NO_SECRET_LEAK'), false);
  // A 401 fallback must never unlock scanning without a valid linked sandbox transaction.
  scenario = 'unauthorizedBadSandbox'; calls = [];
  assert.equal(await checkEntitlement(env, subject, originalID), false);
  assert.deepEqual(calls, [uri('Production'), uri('Sandbox')]);
  scenario = 'unauthorizedSandbox401'; calls = [];
  await assert.rejects(checkEntitlement(env, subject, originalID), /unavailable/);
  assert.deepEqual(calls, [uri('Production'), uri('Sandbox')]);
  assert.equal(warnings.includes('PM_SCAN_STAGE: APP_STORE_HTTP_401'), true);
  assert.equal(JSON.stringify(warnings).includes('PRIVATE_APPLE_BODY'), false);
  scenario = 'badEnv'; calls = [];
  assert.equal(await checkEntitlement(env, subject, originalID), false);
  assert.deepEqual(calls, [uri('Production')]);
  scenario = 'badAccount'; calls = [];
  assert.equal(await checkEntitlement(env, subject, originalID), false);
  assert.deepEqual(calls, [uri('Production')]);

  // Preserve isolated Sandbox mode as the current TestFlight configuration.
  env.APP_STORE_ENVIRONMENT = 'Sandbox';
  scenario = 'sandbox'; calls = [];
  assert.equal(await checkEntitlement(env, subject, originalID), true);
  assert.deepEqual(calls, [uri('Sandbox')]);
  // An isolated sandbox authentication failure must not fall back to production.
  scenario = 'unauthorizedSandbox401'; calls = [];
  await assert.rejects(checkEntitlement(env, subject, originalID), /unavailable/);
  assert.deepEqual(calls, [uri('Sandbox')]);
  // Explicit Production mode must remain fail-closed for a 401.
  env.APP_STORE_ENVIRONMENT = 'Production';
  scenario = 'unauthorized'; calls = [];
  await assert.rejects(checkEntitlement(env, subject, originalID), /unavailable/);
  assert.deepEqual(calls, [uri('Production')]);
});

test('optional lifetime scan cap never disables daily limits or malformed-config protection', async t => {
  const { db, state } = fixture({
    SCAN_TOTAL_LIMIT: '0', SCAN_USER_DAILY_LIMIT: '2', SCAN_DAILY_LIMIT: '5'
  });
  t.after(() => db.close());
  const reserve = async subject => (await (await state.fetch(request('state',
    { operation: 'reserve', subject }))).json()).allowed;
  assert.equal(await reserve('a'), true);
  assert.equal(await reserve('a'), true);
  assert.equal(await reserve('a'), false); // 2 per day, per user
  assert.equal(await reserve('b'), true);
  assert.equal(await reserve('b'), true);
  assert.equal(await reserve('c'), true);
  assert.equal(await reserve('d'), false); // 5 per day globally
  assert.equal(db.prepare("SELECT count FROM quota WHERE key = 'total'").get(), undefined);

  const invalid = fixture({ SCAN_TOTAL_LIMIT: '-1' });
  t.after(() => invalid.db.close());
  const result = await invalid.state.fetch(request('state', { operation: 'reserve', subject: 'a' }));
  assert.equal((await result.json()).allowed, false);
});
