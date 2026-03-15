export type TwinCellState = {
  cellId: string;
  regionId: string;
  trafficDensity: number;
  averageSpeed: number;
  disruptionWeight: number;
  riskScore: number;
  vehicleCount: number;
  timestamp: string | null;
};
