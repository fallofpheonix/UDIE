CREATE TABLE IF NOT EXISTS simulation_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  severity INT NOT NULL CHECK (severity BETWEEN 1 AND 5),
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_simulation_events_scenario_time
  ON simulation_events (scenario_id, created_at DESC);

COMMENT ON TABLE simulation_events IS 'Isolated synthetic disruption stream for diagnostics/testing. Not used by production risk pipeline.';
