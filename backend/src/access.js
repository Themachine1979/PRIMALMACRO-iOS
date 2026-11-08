const encoder = new TextEncoder();
const decoder = new TextDecoder();
export const bundleID = 'uk.themachine1979.primalmacro';
const products = new Set([bundleID + '.monthly', bundleID + '.yearly']);
const now = () => Math.floor(Date.now() / 1000);
const appleIssuer = 'https://appleid.apple.com';

export class AccessError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function encode(bytes) {
  return btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}
function decode(value) {
  if (!/^[\w-]+$/.test(value)) throw new Error('Invalid base64url');
  return Uint8Array.from(atob(value.replaceAll('-', '+').replaceAll('_', '/')), c => c.charCodeAt(0));
}
function parse(value) {
  return JSON.parse(decoder.decode(decode(value)));
}
function segment(value) {
  return encode(encoder.encode(JSON.stringify(value)));
}
async function hmac(env) {
  return crypto.subtle.importKey('raw', encoder.encode(env.SESSION_SECRET),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}
async function seal(env, claims) {
  const payload = segment(claims);
  const signature = await crypto.subtle.sign('HMAC', await hmac(env), encoder.encode(payload));
  return payload + '.' + encode(new Uint8Array(signature));
}
async function unseal(env, token, purpose) {
  try {
    const parts = token.split('.');
    if (parts.length !== 2 || !await crypto.subtle.verify('HMAC', await hmac(env),
      decode(parts[1]), encoder.encode(parts[0]))) throw new Error();
    const claims = parse(parts[0]);
    if (claims.purpose !== purpose || !Number.isSafeInteger(claims.exp) || claims.exp <= now()) throw new Error();
    return claims;
  } catch {
    throw new AccessError(401, 'Please confirm your Apple sign-in.');
  }
}

export async function challenge(env) {
  const nonce = await seal(env, { purpose: 'challenge', id: crypto.randomUUID(), exp: now() + 300 });
  return { nonce };
}

let appleKeys;
async function appleKey(kid) {
  if (!appleKeys || appleKeys.expires < now()) {
    // Apple publishes the signing public keys at this documented URL.
    // A transient upstream failure must not weaken signature validation.
    let response;
    try {
      response = await fetch(appleIssuer + '/auth/keys', {
        headers: { accept: 'application/json' },
        redirect: 'manual',
        signal: AbortSignal.timeout(10000)
      });
    } catch {
      // Fixed stage only: never log tokens, key IDs, key values or request data.
      console.warn('PM_APPLE_KEYS_DETAIL: NETWORK_OR_TIMEOUT');
      throw new Error('Apple keys unavailable');
    }
    if (!response.ok) {
      // HTTP status is not private; it distinguishes Apple 403/429/5xx from
      // networking faults without exposing the body or identity data.
      console.warn('PM_APPLE_KEYS_DETAIL: HTTP_' + response.status);
      throw new Error('Apple keys unavailable');
    }
    let payload;
    try {
      payload = await response.json();
    } catch {
      console.warn('PM_APPLE_KEYS_DETAIL: INVALID_JSON');
      throw new Error('Apple keys unavailable');
    }
    if (!Array.isArray(payload?.keys) || !payload.keys.every(
      key => key && typeof key.kid === 'string' && typeof key.kty === 'string'
    )) {
      console.warn('PM_APPLE_KEYS_DETAIL: INVALID_KEYSET');
      throw new Error('Apple keys unavailable');
    }
    appleKeys = { keys: payload.keys, expires: now() + 300 };
  }
  return appleKeys.keys.find(key => key.kid === kid && key.kty === 'RSA' &&
    key.alg === 'RS256' && key.use === 'sig');
}

export async function session(env, input, state) {
  const token = input?.identityToken;
  const nonce = input?.nonce;
  if (typeof token !== 'string' || typeof nonce !== 'string') {
    throw new AccessError(400, 'Missing Apple sign-in details.');
  }
  const pending = await unseal(env, nonce, 'challenge');
  let claims, keyID, signed, signature;
  try {
    const parts = token.split('.');
    if (parts.length !== 3) throw new Error();
    const header = parse(parts[0]);
    claims = parse(parts[1]);
    if (header.alg !== 'RS256' || typeof header.kid !== 'string' ||
        claims.iss !== appleIssuer || claims.aud !== bundleID ||
        !Number.isSafeInteger(claims.exp) || claims.exp <= now() ||
        !Number.isSafeInteger(claims.iat) || claims.iat > now() + 30 || claims.iat < now() - 330 ||
        claims.nonce !== nonce || typeof claims.sub !== 'string' || !claims.sub || claims.sub.length > 255) {
      throw new Error();
    }
    keyID = header.kid;
    signed = encoder.encode(parts.slice(0, 2).join('.'));
    signature = decode(parts[2]);
  } catch {
    throw new AccessError(401, 'Apple sign-in could not be verified.');
  }
  let jwk;
  try {
    jwk = await appleKey(keyID);
  } catch (error) {
    // Only output a fixed stage identifier; never log identity tokens,
    // credential claims, signature contents or the originating IP.
    console.warn('PM_SESSION_STAGE: APPLE_PUBLIC_KEYS');
    throw error;
  }
  if (!jwk) throw new AccessError(401, 'Apple sign-in could not be verified.');
  const algorithm = { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' };
  let validSignature;
  try {
    const importedKey = await crypto.subtle.importKey('jwk', jwk, algorithm, false, ['verify']);
    validSignature = await crypto.subtle.verify(algorithm, importedKey, signature, signed);
  } catch {
    console.warn('PM_SESSION_STAGE: APPLE_SIGNATURE_ENGINE');
    throw new Error('Apple signature verification unavailable');
  }
  if (!validSignature) throw new AccessError(401, 'Apple sign-in could not be verified.');
  let consumed;
  try {
    consumed = await state.consume(pending.id, pending.exp);
  } catch {
    console.warn('PM_SESSION_STAGE: NONCE_STORAGE');
    throw new Error('Scan state unavailable');
  }
  if (!consumed) {
    throw new AccessError(401, 'Please confirm your Apple sign-in again.');
  }
  // Keep the verified scanner session for 30 days on this iPhone instead of
  // re-requesting a new Apple identity token every day. Apple discourages
  // frequent re-authentication; subscription status is checked per scan.
  // Sign out clears the iOS Keychain session; rotating SESSION_SECRET revokes
  // all server sessions if needed.
  const exp = now() + 30 * 86_400;
  try {
    return { token: await seal(env, { purpose: 'session', sub: claims.sub, exp }), expiresAt: exp };
  } catch {
    console.warn('PM_SESSION_STAGE: SESSION_SIGNING');
    throw new Error('Session signing unavailable');
  }
}

export async function authenticate(env, request) {
  const bearer = request.headers.get('authorization')?.match(/^Bearer ([\w.-]{1,2048})$/);
  if (!bearer) throw new AccessError(401, 'Please confirm your Apple sign-in.');
  return (await unseal(env, bearer[1], 'session')).sub;
}

export async function accountToken(subject) {
  const bytes = new Uint8Array(await crypto.subtle.digest('SHA-256',
    encoder.encode('primalmacro.storekit.v1:' + subject))).slice(0, 16);
  bytes[6] = (bytes[6] & 15) | 128; // Application-defined UUID version 8.
  bytes[8] = (bytes[8] & 63) | 128;
  const hex = Array.from(bytes, byte => byte.toString(16).padStart(2, '0')).join('');
  return [hex.slice(0, 8), hex.slice(8, 12), hex.slice(12, 16), hex.slice(16, 20), hex.slice(20)].join('-');
}

async function storeAPIJWT(env) {
  try {
    const pem = env.APP_STORE_PRIVATE_KEY.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
    const algorithm = { name: 'ECDSA', namedCurve: 'P-256' };
    const key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(atob(pem), c => c.charCodeAt(0)),
      algorithm, false, ['sign']);
    const unsigned = segment({ alg: 'ES256', kid: env.APP_STORE_KEY_ID, typ: 'JWT' }) + '.' +
      segment({ iss: env.APP_STORE_ISSUER_ID, iat: now(), exp: now() + 120, aud: 'appstoreconnect-v1', bid: bundleID });
    const signature = await crypto.subtle.sign({ ...algorithm, hash: 'SHA-256' }, key, encoder.encode(unsigned));
    return unsigned + '.' + encode(new Uint8Array(signature));
  } catch {
    // Deliberately no credential values, token contents or exception details.
    console.warn('PM_SCAN_STAGE: APP_STORE_JWT_SIGNING');
    throw new Error('Apple subscription JWT unavailable');
  }
}

export async function checkEntitlement(env, subject, transactionID) {
  if (typeof transactionID !== 'string' || !/^\d{1,24}$/.test(transactionID)) {
    throw new AccessError(400, 'Missing subscription information.');
  }
  // Auto is for public release: Apple recommends production first and sandbox
  // fallback ONLY for production TransactionIdNotFoundError (4040010).
  // Sandbox and Production modes remain available for isolated testing.
  const environments = env.APP_STORE_ENVIRONMENT === 'Auto'
    ? ['Production', 'Sandbox']
    : [env.APP_STORE_ENVIRONMENT];
  const jwt = await storeAPIJWT(env);
  const expected = await accountToken(subject);

  for (const environment of environments) {
    const host = environment === 'Sandbox'
      ? 'api.storekit-sandbox.apple.com'
      : 'api.storekit.apple.com';
    let response;
    try {
      response = await fetch('https://' + host + '/inApps/v1/subscriptions/' + transactionID, {
        headers: { authorization: 'Bearer ' + jwt },
        redirect: 'manual', signal: AbortSignal.timeout(8000)
      });
    } catch {
      console.warn('PM_SCAN_STAGE: APP_STORE_NETWORK_OR_TIMEOUT');
      throw new Error('Apple subscription lookup unavailable');
    }
    if (response.status === 401 && env.APP_STORE_ENVIRONMENT === 'Auto' &&
        environment === 'Production') {
      // Before the first public App Store release, Apple's production Server
      // API can return 401 even for a valid IAP API key. A sandbox lookup may
      // proceed, but ONLY a separately verified, linked Apple entitlement
      // in that sandbox response can unlock scanning.
      // Keep this signal visible: after launch it can indicate a production
      // credentials problem that needs immediate investigation.
      console.warn('PM_SCAN_STAGE: PRODUCTION_401_SANDBOX_FALLBACK');
      continue;
    }
    if (response.status === 404) {
      if (env.APP_STORE_ENVIRONMENT !== 'Auto' || environment !== 'Production') return false;
      let errorCode;
      try {
        const error = await response.json();
        errorCode = error?.errorCode;
      } catch {
        return false;
      }
      // Do not fall back for an unknown app/account error or malformed response.
      if (errorCode === 4040010) continue;
      return false;
    }
    if (!response.ok) {
      // Never log Apple's response body, JWT or transaction details.
      console.warn('PM_SCAN_STAGE: APP_STORE_HTTP_' + response.status);
      throw new Error('Apple subscription lookup unavailable');
    }
    let status;
    try {
      status = await response.json();
      if (!status || !Array.isArray(status.data)) throw new Error();
    } catch {
      console.warn('PM_SCAN_STAGE: APP_STORE_BAD_RESPONSE');
      throw new Error('Apple subscription lookup unavailable');
    }
    if (status.bundleId !== bundleID || status.environment !== environment) return false;
    try {
      return status.data.some(group => group.lastTransactions.some(entry => {
        // This payload comes directly from the fixed Apple API origin over TLS.
        // Client-supplied StoreKit JWS and entitlement claims are never accepted.
        if (entry.status !== 1 || entry.originalTransactionId !== transactionID) return false;
        const parts = entry.signedTransactionInfo.split('.');
        if (parts.length !== 3) return false;
        const tx = parse(parts[1]);
        return tx.bundleId === bundleID && tx.environment === environment &&
          tx.originalTransactionId === transactionID && products.has(tx.productId) &&
          tx.appAccountToken?.toLowerCase() === expected && tx.inAppOwnershipType === 'PURCHASED' &&
          tx.revocationDate == null && tx.isUpgraded !== true &&
          Number.isSafeInteger(tx.expiresDate) && tx.expiresDate > Date.now();
      }));
    } catch {
      console.warn('PM_SCAN_STAGE: APP_STORE_TRANSACTION_PARSE');
      throw new Error('Apple subscription lookup unavailable');
    }
  }
  return false;
}
