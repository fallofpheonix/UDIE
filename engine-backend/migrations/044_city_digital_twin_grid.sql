CREATE TABLE IF NOT EXISTS city_grid_cells (
  cell_id BIGINT PRIMARY KEY,
  city_id TEXT NOT NULL DEFAULT 'default',
  region_id BIGINT NOT NULL,
  resolution INT NOT NULL CHECK (resolution = 9),
  center_lat DOUBLE PRECISION NOT NULL,
  center_lng DOUBLE PRECISION NOT NULL,
  road_segments JSONB NOT NULL DEFAULT '[]'::jsonb,
  intersection_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  metadata_updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_city_grid_cells_city_region
  ON city_grid_cells (city_id, region_id);

CREATE TABLE IF NOT EXISTS digital_twin_cell_states (
  cell_id BIGINT PRIMARY KEY REFERENCES city_grid_cells(cell_id) ON DELETE CASCADE,
  region_id BIGINT NOT NULL,
  traffic_density DOUBLE PRECISION NOT NULL CHECK (traffic_density >= 0),
  average_speed DOUBLE PRECISION NOT NULL CHECK (average_speed >= 0),
  disruption_weight DOUBLE PRECISION NOT NULL CHECK (disruption_weight >= 0),
  risk_score DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (risk_score >= 0 AND risk_score < 1),
  vehicle_count INT NOT NULL CHECK (vehicle_count >= 0),
  timestamp TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_digital_twin_cell_states_region_time
  ON digital_twin_cell_states (region_id, timestamp DESC);

CREATE TABLE IF NOT EXISTS digital_twin_cell_state_history (
  id BIGSERIAL PRIMARY KEY,
  cell_id BIGINT NOT NULL REFERENCES city_grid_cells(cell_id) ON DELETE CASCADE,
  region_id BIGINT NOT NULL,
  traffic_density DOUBLE PRECISION NOT NULL CHECK (traffic_density >= 0),
  average_speed DOUBLE PRECISION NOT NULL CHECK (average_speed >= 0),
  disruption_weight DOUBLE PRECISION NOT NULL CHECK (disruption_weight >= 0),
  risk_score DOUBLE PRECISION NOT NULL CHECK (risk_score >= 0 AND risk_score < 1),
  vehicle_count INT NOT NULL CHECK (vehicle_count >= 0),
  timestamp TIMESTAMPTZ NOT NULL,
  ingested_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_digital_twin_cell_history_cell_time
  ON digital_twin_cell_state_history (cell_id, timestamp DESC);

COMMENT ON TABLE city_grid_cells IS 'Street-scale res9 H3 grid metadata for city digital twin simulations.';
COMMENT ON TABLE digital_twin_cell_states IS 'Latest dynamic traffic state per city H3 cell.';
COMMENT ON TABLE digital_twin_cell_state_history IS 'Append-only history of digital twin cell state updates.';
