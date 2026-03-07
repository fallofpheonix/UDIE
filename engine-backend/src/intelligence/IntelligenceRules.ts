import { IntelligenceInsight, IntelligenceRuleConfig, InsightSeverity } from './IntelligenceTypes';

export function toSeverity(weight: number, hotspotThreshold: number): InsightSeverity {
  if (weight >= hotspotThreshold * 2) return 'HIGH';
  if (weight >= hotspotThreshold * 1.2) return 'MEDIUM';
  return 'LOW';
}

export function hotspotInsight(
  h3Index: string,
  weight: number,
  highRiskNeighbors: number,
  config: IntelligenceRuleConfig,
): IntelligenceInsight | null {
  if (weight <= config.hotspotThreshold || highRiskNeighbors <= config.hotspotNeighborCount) {
    return null;
  }

  return {
    h3Index,
    type: 'HOTSPOT',
    severity: toSeverity(weight, config.hotspotThreshold),
    description: `Hotspot cluster detected: weight=${weight.toFixed(2)}, high-risk neighbors=${highRiskNeighbors}`,
  };
}

export function spikeInsight(
  h3Index: string,
  previousWeight: number | null,
  currentWeight: number,
  config: IntelligenceRuleConfig,
): IntelligenceInsight | null {
  if (previousWeight === null || previousWeight <= 0) {
    return null;
  }

  const ratio = currentWeight / previousWeight;
  if (ratio <= config.spikeMultiplier) {
    return null;
  }

  const increasePct = ((ratio - 1) * 100).toFixed(0);
  return {
    h3Index,
    type: 'SUDDEN_SPIKE',
    severity: ratio >= config.spikeMultiplier * 2 ? 'HIGH' : 'MEDIUM',
    description: `Risk spike detected: +${increasePct}% within ${config.spikeWindowMinutes}m`,
  };
}

export function recurringInsight(
  h3Index: string,
  recurringCount24h: number,
  config: IntelligenceRuleConfig,
): IntelligenceInsight | null {
  if (recurringCount24h <= config.recurringThreshold24h) {
    return null;
  }

  return {
    h3Index,
    type: 'RECURRING_EVENT',
    severity: recurringCount24h >= config.recurringThreshold24h * 2 ? 'HIGH' : 'MEDIUM',
    description: `Recurring disruption detected: ${recurringCount24h} events in 24h`,
  };
}
