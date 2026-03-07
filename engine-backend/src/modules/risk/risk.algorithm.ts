export function classifyRiskLevel(score: number): 'LOW' | 'MEDIUM' | 'HIGH' {
  if (score < 0.33) return 'LOW';
  if (score < 0.66) return 'MEDIUM';
  return 'HIGH';
}

export function distanceDecay(distanceMeters: number): number {
  return Math.exp(-distanceMeters / 200);
}
