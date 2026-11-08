import { test, mock } from 'node:test';
import assert from 'node:assert/strict';
import worker, { sanitizeFoods } from '../src/worker.js';

const env = { OPENAI_API_KEY: 'server-only-fake', PRIMAL_ACCESS_TOKEN: 'private-token' };
const imageBase64 = 'eA'.repeat(40);
const request = (body, token = 'private-token') => new Request('https://scanner.example/scan', {
  method: 'POST',
  headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
  body: JSON.stringify(body)
});

test('health is available', async () => {
  const r = await worker.fetch(new Request('https://scanner.example/health'), env);
  assert.equal(r.status, 200);
  assert.equal((await r.json()).ok, true);
});

test('missing token fails without calling AI', async () => {
  const r = await worker.fetch(request({ mode: 'food', imageBase64 }, 'wrong'), env);
  assert.equal(r.status, 401);
});

test('invalid scan mode fails', async () => {
  const r = await worker.fetch(request({ mode: 'invalid', imageBase64 }), env);
  assert.equal(r.status, 400);
});

test('sanitizeFoods constrains unsupported fields', () => {
  const r = sanitizeFoods([{ name: ' Porridge ', serving: '', calories: -4,
    proteinG: 11.348, carbsG: 30, fatG: Infinity, fiberG: 7, confidence: 'certain', notes: '' }]);
  assert.equal(r.length, 1);
  assert.equal(r[0].calories, 0);
  assert.equal(r[0].proteinG, 11.3);
  assert.equal(r[0].confidence, 'low');
});

test('authorised photo scan parses nutrition JSON', async () => {
  const original = globalThis.fetch;
  globalThis.fetch = async () => new Response(JSON.stringify({
    choices: [{ message: { content: JSON.stringify({
      foods: [{ name: 'Chicken bowl', serving: '1 bowl', calories: 500,
        proteinG: 45, carbsG: 48, fatG: 14, fiberG: 5,
        confidence: 'medium', notes: 'portion estimated' }],
      disclaimer: 'Portion estimated from image'
    }) } }]
  }), { status: 200, headers: { 'content-type': 'application/json' } });
  try {
    const r = await worker.fetch(request({ mode: 'food', imageBase64 }), env);
    assert.equal(r.status, 200);
    const body = await r.json();
    assert.equal(body.foods[0].proteinG, 45);
    assert.equal(body.foods[0].name, 'Chicken bowl');
  } finally { globalThis.fetch = original; }
});
