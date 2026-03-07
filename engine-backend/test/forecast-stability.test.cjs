const test = require('node:test');
const assert = require('node:assert/strict');

function smooth(alpha, wNow, wPrev) {
  return Math.max(0, wNow * alpha + wPrev * (1 - alpha));
}

test('exponential smoothing remains bounded by latest neighborhood', () => {
  const alpha = 0.35;
  const points = [0.2, 0.4, 0.8, 0.6, 0.5];

  for (let i = 1; i < points.length; i += 1) {
    const s = smooth(alpha, points[i], points[i - 1]);
    const lo = Math.min(points[i], points[i - 1]);
    const hi = Math.max(points[i], points[i - 1]);
    assert.ok(s >= lo - 1e-12);
    assert.ok(s <= hi + 1e-12);
  }
});
