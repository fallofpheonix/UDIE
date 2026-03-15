CREATE TABLE IF NOT EXISTS simulation_disruptions (
  id UUID PRIMARY KEY,
  disruption_type TEXT NOT NULL CHECK (
    disruption_type IN ('ACCIDENT', 'ROAD_CLOSURE', 'CONSTRUCTION', 'EVENT_CONGESTION')
  ),
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  h3_index BIGINT NOT NULL,
  region_id BIGINT NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  severity INT NOT NULL CHECK (severity BETWEEN 1 AND 5),
  estimated_duration_minutes INT NOT NULL CHECK (estimated_duration_minutes > 0),
  affected_roads JSONB NOT NULL DEFAULT '[]'::jsonb,
  kernel TEXT NOT NULL CHECK (kernel IN ('EXPONENTIAL', 'GAUSSIAN')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_simulation_disruptions_region_time
  ON simulation_disruptions (region_id, start_time DESC);

CREATE TABLE IF NOT EXISTS disruption_influence_cells (
  disruption_id UUID NOT NULL REFERENCES simulation_disruptions(id) ON DELETE CASCADE,
  cell_id BIGINT NOT NULL,
  region_id BIGINT NOT NULL,
  distance_k INT NOT NULL CHECK (distance_k >= 0),
  influence_weight DOUBLE PRECISION NOT NULL CHECK (influence_weight >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (disruption_id, cell_id)
);

CREATE INDEX IF NOT EXISTS idx_disruption_influence_cells_cell
  ON disruption_influence_cells (cell_id, updated_at DESC);

COMMENT ON TABLE simulation_disruptions IS 'Structured disruption events used by the digital twin for propagated impact simulation.';
COMMENT ON TABLE disruption_influence_cells IS 'Per-cell propagated influence of active simulation disruptions.';
