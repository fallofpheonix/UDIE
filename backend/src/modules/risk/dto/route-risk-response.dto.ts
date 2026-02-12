export interface RouteRiskResponseDto {
  score: number;
  level: 'LOW' | 'MEDIUM' | 'HIGH';
  eventCount: number;
}
