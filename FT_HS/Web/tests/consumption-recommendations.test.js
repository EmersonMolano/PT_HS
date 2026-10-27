import test from 'node:test';
import assert from 'node:assert/strict';
import { createConsumptionRecommendations } from '../src/features/dashboard/consumption-recommendations.js';

test('asks for readings when the API reports no consumption for the week', () => {
  assert.deepEqual(createConsumptionRecommendations({ todayM3: 0, weekM3: 0 }), [
    { key: 'recommendationNoReadings', value: 0 },
  ]);
});

test('uses the API daily and weekly increases to generate specific suggestions', () => {
  assert.deepEqual(
    createConsumptionRecommendations({
      todayM3: 0.8,
      weekM3: 4.2,
      todayChangePercent: 32,
      weekChangePercent: 20,
    }),
    [
      { key: 'recommendationTodayIncrease', percent: 32, value: 0.8 },
      { key: 'recommendationWeekIncrease', percent: 20, value: 4.2 },
    ]
  );
});

test('reports a falling weekly trend from API values', () => {
  assert.deepEqual(
    createConsumptionRecommendations({ weekM3: 2.4, weekChangePercent: -14 }),
    [{ key: 'recommendationWeekDecrease', percent: 14, value: 2.4 }]
  );
});

test('does not invent a trend when there is no comparable previous period', () => {
  assert.deepEqual(
    createConsumptionRecommendations({ weekM3: 1.75, weekChangePercent: null }),
    [{ key: 'recommendationNeedMoreHistory', value: 1.75 }]
  );
});
