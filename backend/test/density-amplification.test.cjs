const test = require('node:test');
const assert = require('node:assert/strict');

function densityFactor(alpha, neighborCount, cap = 3) {
  const raw = 1 + alpha * Math.log(1 + neighborCount);
  return Math.min(cap, raw);
}

test('density factor is deterministic and bounded', () => {
  const alpha = 0.3;
  const samples = [0, 1, 3, 10, 100, 1000];

  let prev = 1;
  for (const n of samples) {
    const df = densityFactor(alpha, n, 3);
    assert.ok(df >= 1, 'must be >= 1');
    assert.ok(df <= 3, 'must be capped');
    assert.ok(df >= prev, 'must be monotonic');
    prev = df;
  }
});
