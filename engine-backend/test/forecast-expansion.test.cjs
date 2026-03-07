const test = require('node:test');
const assert = require('node:assert/strict');

function calculateForecasts(alpha, wNow, wPrev) {
    const s = Math.max(0, wNow * alpha + wPrev * (1 - alpha));
    return {
        forecast_15m: s,
        forecast_30m: s * 1.10,
        forecast_60m: s * 1.25,
    };
}

test('forecast expansion calculates consistent horizons', () => {
    const alpha = 0.35;
    const wNow = 0.8;
    const wPrev = 0.4;

    const forecasts = calculateForecasts(alpha, wNow, wPrev);

    assert.equal(forecasts.forecast_15m, 0.8 * 0.35 + 0.4 * 0.65); // 0.28 + 0.26 = 0.54
    assert.ok(forecasts.forecast_30m > forecasts.forecast_15m);
    assert.ok(forecasts.forecast_60m > forecasts.forecast_30m);
    assert.equal(forecasts.forecast_30m, forecasts.forecast_15m * 1.10);
    assert.equal(forecasts.forecast_60m, forecasts.forecast_15m * 1.25);
});

test('anomaly detection logic (simulation)', () => {
    const currentWeight = 1.5;
    const avgWeight = 0.5;
    const stddevWeight = 0.1;

    // Spike Threshold: Current weight > (Mean + 2 * StdDev) OR Current weight > 2.0 * Mean
    const isAnomaly = (currentWeight > (avgWeight + 2 * stddevWeight)) || (currentWeight > (2.0 * avgWeight));

    assert.ok(isAnomaly, 'Should detect anomaly when current is 3x average');

    const normalWeight = 0.55;
    const isNormal = (normalWeight > (avgWeight + 2 * stddevWeight)) || (normalWeight > (2.0 * avgWeight));
    assert.ok(!isNormal, 'Should not detect anomaly for normal fluctuation');
});
