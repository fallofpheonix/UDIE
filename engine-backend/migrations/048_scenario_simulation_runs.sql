CREATE TABLE IF NOT EXISTS simulation_runs (
  run_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_id TEXT NOT NULL,
  scenario_type TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('QUEUED', 'COMPLETED', 'FAILED')),
  requested_horizons JSONB NOT NULL DEFAULT '[]'::jsonb,
  bounds JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_simulation_runs_scenario_time
  ON simulation_runs (scenario_id, created_at DESC);

CREATE TABLE IF NOT EXISTS simulation_run_outputs (
  run_id UUID NOT NULL REFERENCES simulation_runs(run_id) ON DELETE CASCADE,
  output_type TEXT NOT NULL CHECK (output_type IN ('RISK_SURFACE', 'HORIZON_OUTPUTS')),
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (run_id, output_type)
);

CREATE INDEX IF NOT EXISTS idx_simulation_run_outputs_created
  ON simulation_run_outputs (created_at DESC);

COMMENT ON TABLE simulation_runs IS 'Operator-triggered city simulation runs.';
COMMENT ON TABLE simulation_run_outputs IS 'Persisted outputs for simulation runs, including risk predictions.';
