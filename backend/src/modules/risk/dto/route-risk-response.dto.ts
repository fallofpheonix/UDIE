export interface RouteRiskResponseDto {
  score: number;
  level: 'LOW' | 'MEDIUM' | 'HIGH';
  eventCount: number;
  modelVersion?: number;
  latencyMs?: number;
}
