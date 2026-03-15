CREATE TABLE IF NOT EXISTS traffic_signal_training_runs (
  run_id UUID PRIMARY KEY,
  algorithm TEXT NOT NULL,
  config JSONB NOT NULL,
  metrics JSONB NOT NULL,
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_traffic_signal_training_runs_created
  ON traffic_signal_training_runs (created_at DESC);

COMMENT ON TABLE traffic_signal_training_runs IS 'Training runs and model artifacts for traffic signal RL optimization.';
