export type ConsumptionRecommendation = {
  key: string;
  percent?: number;
  value: number;
};

export function createConsumptionRecommendations(input: {
  todayM3?: number;
  weekM3?: number;
  todayChangePercent?: number | null;
  weekChangePercent?: number | null;
}): ConsumptionRecommendation[];
