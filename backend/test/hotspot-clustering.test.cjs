const test = require('node:test');
const assert = require('node:assert/strict');
const h3 = require('../node_modules/h3-js');

function cluster(cellsByWeight, threshold) {
  const byCell = new Map([...cellsByWeight.entries()].filter(([, w]) => w >= threshold));
  const visited = new Set();
  const clusters = [];

  for (const cell of byCell.keys()) {
    if (visited.has(cell)) continue;
    const q = [cell];
    visited.add(cell);
    let sum = 0;
    let count = 0;

    while (q.length) {
      const c = q.shift();
      sum += byCell.get(c) || 0;
      count += 1;
      for (const n of h3.gridDisk(c, 1)) {
        if (byCell.has(n) && !visited.has(n)) {
          visited.add(n);
          q.push(n);
        }
      }
    }

    clusters.push({ sum, count });
  }

  return clusters.sort((a, b) => b.sum - a.sum);
}

test('adjacent high-risk cells form one hotspot cluster', () => {
  const center = h3.latLngToCell(28.6139, 77.209, 9);
  const neighbors = h3.gridDisk(center, 1).slice(0, 3);

  const m = new Map();
  m.set(center, 10);
  m.set(neighbors[0], 9);
  m.set(neighbors[1], 8);
  m.set(h3.latLngToCell(28.70, 77.30, 9), 11); // isolated hotspot

  const out = cluster(m, 8);
  assert.equal(out.length, 2);
  assert.ok(out[0].count >= 2);
  assert.ok(out[0].sum > out[1].sum);
});
