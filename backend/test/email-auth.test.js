import { test } from 'node:test';
import assert from 'node:assert/strict';
import { emailSession, accountToken } from '../src/access.js';

const projectID = 'primalmacro-test';
const env = { SESSION_SECRET: 'test-only-secret-'.repeat(5), FIREBASE_PROJECT_ID: projectID };
const segment = value => Buffer.from(JSON.stringify(value)).toString('base64url');
const now = () => Math.floor(Date.now() / 1000);

test('Email sign-in is disabled without configured Firebase and rejects malformed tokens', async () => {
  await assert.rejects(emailSession({ SESSION_SECRET: env.SESSION_SECRET }, { idToken: 'bad' }),
    error => error.status === 503);
  await assert.rejects(emailSession(env, { idToken: 'bad' }), error => error.status === 400);
});

test('Email scanner sessions require a signed, email-verified Firebase ID token', async t => {
  const algo = { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' };
  const pair = await crypto.subtle.generateKey(algo, true, ['sign', 'verify']);
  const jwk = { ...await crypto.subtle.exportKey('jwk', pair.publicKey), kid: 'firebase-test', use: 'sig', alg: 'RS256' };
  let publicKeyQueries = 0;
  t.mock.method(globalThis, 'fetch', async (url, init) => {
    assert.equal(url, 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com');
    assert.equal(init.redirect, 'manual');
    publicKeyQueries++;
    return Response.json({ keys: [jwk] });
  });
  const issuedAt = now();
  const base = {
    iss: 'https://securetoken.google.com/' + projectID,
    aud: projectID,
    sub: 'firebase-test-uid',
    iat: issuedAt,
    auth_time: issuedAt,
    exp: issuedAt + 1800,
    email_verified: true
  };
  const token = async claims => {
    const unsigned = segment({ alg: 'RS256', kid: jwk.kid }) + '.' + segment({ ...base, ...claims });
    const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', pair.privateKey,
      Buffer.from(unsigned));
    return unsigned + '.' + Buffer.from(signature).toString('base64url');
  };
  for (const override of [
    { email_verified: false },
    { aud: 'another-firebase-project' },
    { iss: 'https://evil.example' },
    { exp: issuedAt - 1 },
    { sub: '' },
    { iat: issuedAt - 7200 }
  ]) {
    await assert.rejects(emailSession(env, { idToken: await token(override) }),
      error => error.status === 401);
  }
  const validIDToken = await token({});
  const result = await emailSession(env, { idToken: validIDToken });
  assert.ok(result.expiresAt <= issuedAt + 1800);
  const claims = JSON.parse(Buffer.from(result.token.split('.')[0], 'base64url'));
  assert.equal(claims.sub, 'email:firebase-test-uid');
  assert.equal(claims.purpose, 'session');
  assert.ok(publicKeyQueries >= 1);
  const changed = validIDToken.slice(0, -2) + 'ZZ';
  await assert.rejects(emailSession(env, { idToken: changed }), error => error.status === 401);
  const account = await accountToken('email:firebase-test-uid');
  assert.match(account, /^[0-9a-f]{8}-[0-9a-f]{4}-8[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
});
