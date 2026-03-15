export interface RouteRiskResponseDto {
  riskScore: number;
  riskLevel: 'LOW' | 'MEDIUM' | 'HIGH';
  explanation: string;
  contributingEvents: number;
  segments: Array<{
    h3Index: string;
    cellRisk: number;
    eventCount: number;
    hazardTypes: string[];
  }>;
  classification: 'LOW' | 'MEDIUM' | 'HIGH';
  evalLatencyMs: number;
  score: number;
  level: 'LOW' | 'MEDIUM' | 'HIGH';
  eventCount: number;
  riskDensity: number;
  routeLengthKm: number;
  cellCount: number;
  modelVersion?: number;
  latencyMs?: number;
}
