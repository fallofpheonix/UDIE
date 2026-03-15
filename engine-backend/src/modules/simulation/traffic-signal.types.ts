export const signalActions = [
  'extend_green',
  'switch_phase',
  'shorten_phase',
  'hold_phase',
] as const;

export type SignalAction = (typeof signalActions)[number];

export const signalPhases = ['NS_GREEN', 'EW_GREEN'] as const;

export type SignalPhase = (typeof signalPhases)[number];

export type IntersectionAgentState = {
  intersectionId: string;
  incomingVehicleCount: number;
  avgSpeed: number;
  signalPhase: SignalPhase;
  nearbyCongestionIndex: number;
  queueLength: number;
  avgWaitSeconds: number;
  throughputVehicles: number;
  phaseElapsedSeconds: number;
  phaseDurationSeconds: number;
  minPhaseSeconds: number;
  maxPhaseSeconds: number;
  yellowSeconds: number;
  saturationFlow: number;
  cityId: string;
  regionId: string;
  controlledCellCount: number;
};
