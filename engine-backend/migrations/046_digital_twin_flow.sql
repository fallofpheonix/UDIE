ALTER TABLE city_grid_cells
  ADD COLUMN IF NOT EXISTS road_capacity DOUBLE PRECISION NOT NULL DEFAULT 250 CHECK (road_capacity > 0);

CREATE TABLE IF NOT EXISTS city_grid_edges (
  source_cell_id BIGINT NOT NULL REFERENCES city_grid_cells(cell_id) ON DELETE CASCADE,
  target_cell_id BIGINT NOT NULL REFERENCES city_grid_cells(cell_id) ON DELETE CASCADE,
  distance_k INT NOT NULL DEFAULT 1 CHECK (distance_k >= 1),
  directional_bias DOUBLE PRECISION NOT NULL DEFAULT 1.0 CHECK (directional_bias > 0),
  transfer_capacity DOUBLE PRECISION NOT NULL DEFAULT 120 CHECK (transfer_capacity > 0),
  PRIMARY KEY (source_cell_id, target_cell_id)
);

CREATE INDEX IF NOT EXISTS idx_city_grid_edges_target
  ON city_grid_edges (target_cell_id);

CREATE TABLE IF NOT EXISTS digital_twin_traffic_samples (
  id BIGSERIAL PRIMARY KEY,
  cell_id BIGINT NOT NULL REFERENCES city_grid_cells(cell_id) ON DELETE CASCADE,
  region_id BIGINT NOT NULL,
  city_id TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  traffic_density DOUBLE PRECISION NOT NULL CHECK (traffic_density >= 0),
  average_speed DOUBLE PRECISION NOT NULL CHECK (average_speed >= 0),
  vehicle_count INT NOT NULL CHECK (vehicle_count >= 0),
  disruption_weight DOUBLE PRECISION NOT NULL CHECK (disruption_weight >= 0),
  heading_degrees DOUBLE PRECISION,
  observed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_digital_twin_traffic_samples_cell_time
  ON digital_twin_traffic_samples (cell_id, observed_at DESC);

CREATE TABLE IF NOT EXISTS digital_twin_state_alerts (
  id BIGSERIAL PRIMARY KEY,
  cell_id BIGINT NOT NULL REFERENCES city_grid_cells(cell_id) ON DELETE CASCADE,
  region_id BIGINT NOT NULL,
  alert_type TEXT NOT NULL,
  severity INT NOT NULL CHECK (severity BETWEEN 1 AND 5),
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  detected_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_digital_twin_state_alerts_cell_time
  ON digital_twin_state_alerts (cell_id, detected_at DESC);

CREATE TABLE IF NOT EXISTS digital_twin_horizon_states (
  horizon_at TIMESTAMPTZ NOT NULL,
  cell_id BIGINT NOT NULL REFERENCES city_grid_cells(cell_id) ON DELETE CASCADE,
  region_id BIGINT NOT NULL,
  traffic_density DOUBLE PRECISION NOT NULL CHECK (traffic_density >= 0),
  average_speed DOUBLE PRECISION NOT NULL CHECK (average_speed >= 0),
  disruption_weight DOUBLE PRECISION NOT NULL CHECK (disruption_weight >= 0),
  risk_score DOUBLE PRECISION NOT NULL CHECK (risk_score >= 0 AND risk_score < 1),
  vehicle_count INT NOT NULL CHECK (vehicle_count >= 0),
  PRIMARY KEY (horizon_at, cell_id)
);

CREATE INDEX IF NOT EXISTS idx_digital_twin_horizon_states_cell_time
  ON digital_twin_horizon_states (cell_id, horizon_at DESC);

COMMENT ON TABLE city_grid_edges IS 'Directional transfer graph between neighboring H3 cells for traffic flow simulation.';
COMMENT ON TABLE digital_twin_traffic_samples IS 'Streaming traffic observations ingested into the digital twin.';
COMMENT ON TABLE digital_twin_state_alerts IS 'Sudden traffic-change detections derived from streaming twin updates.';
COMMENT ON TABLE digital_twin_horizon_states IS 'Rolling short-horizon projected twin states.';
