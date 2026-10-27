const MAX_RECOMMENDATIONS = 2;

/** Build dashboard suggestions from consumption values returned by the API. */
export function createConsumptionRecommendations({
  todayM3 = 0,
  weekM3 = 0,
  todayChangePercent = null,
  weekChangePercent = null,
}) {
  const suggestions = [];
  const today = Number(todayM3);
  const week = Number(weekM3);
  const toComparableChange = (value) =>
    value === null || value === undefined || value === '' || !Number.isFinite(Number(value))
      ? null
      : Number(value);
  const todayChange = toComparableChange(todayChangePercent);
  const weekChange = toComparableChange(weekChangePercent);

  if (week <= 0) {
    return [{ key: 'recommendationNoReadings', value: 0 }];
  }

  if (today > 0 && todayChange !== null && todayChange >= 25) {
    suggestions.push({
      key: 'recommendationTodayIncrease',
      percent: Math.round(todayChange),
      value: today,
    });
  }

  if (weekChange !== null && weekChange >= 15) {
    suggestions.push({
      key: 'recommendationWeekIncrease',
      percent: Math.round(weekChange),
      value: week,
    });
  } else if (weekChange !== null && weekChange <= -10) {
    suggestions.push({
      key: 'recommendationWeekDecrease',
      percent: Math.round(Math.abs(weekChange)),
      value: week,
    });
  } else if (weekChange !== null) {
    suggestions.push({ key: 'recommendationWeekStable', value: week });
  }

  if (!suggestions.length) {
    suggestions.push({ key: 'recommendationNeedMoreHistory', value: week });
  }

  return suggestions.slice(0, MAX_RECOMMENDATIONS);
}
