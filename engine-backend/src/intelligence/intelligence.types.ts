export type InsightType = 'HOTSPOT' | 'RECURRING_EVENT' | 'SUDDEN_SPIKE';
export type InsightSeverity = 'LOW' | 'MEDIUM' | 'HIGH';

export interface RiskCell {
  h3_index: string;
  weight: number;
  updated_at: Date;
}

export interface IntelligenceRuleConfig {
  hotspotThreshold: number;
  hotspotNeighborCount: number;
  recurringThreshold24h: number;
  spikeMultiplier: number;
  spikeWindowMinutes: number;
  scanLimit: number;
}

export interface IntelligenceInsight {
  h3Index: string;
  type: InsightType;
  severity: InsightSeverity;
  description: string;
}

export interface IntelligenceQuery {
  regionId?: string;
  limit?: number;
}
