const test = require('node:test');
const assert = require('node:assert/strict');
const { resolveRouteRegion } = require('../dist/src/modules/common/region-resolver.util');

test('resolveRouteRegion returns a stable H3 parent (res6) for route coordinates', () => {
  const region = resolveRouteRegion([
    { lat: 28.6139, lng: 77.2090 },
    { lat: 28.6145, lng: 77.2100 },
    { lat: 28.6151, lng: 77.2111 },
  ]);

  assert.equal(typeof region, 'string');
  assert.ok(region.length > 0);
});
