CREATE TABLE IF NOT EXISTS forecast_cells (
  h3_index BIGINT PRIMARY KEY,
  forecast_30m DOUBLE PRECISION NOT NULL,
  forecast_60m DOUBLE PRECISION NOT NULL,
  source_points INT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_forecast_cells_updated_at
  ON forecast_cells (updated_at DESC);

INSERT INTO model_parameters (key, value, description)
VALUES
  ('FORECAST_ALPHA', 0.35, 'Exponential smoothing alpha for short-horizon risk forecasting')
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = now();
