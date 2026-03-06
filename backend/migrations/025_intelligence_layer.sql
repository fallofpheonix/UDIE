-- Migration 025: Intelligence Layer
-- Adds read-model insights generated from risk_cells outside request hot paths.

CREATE TABLE IF NOT EXISTS intelligence_insights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  h3_index BIGINT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('HOTSPOT', 'RECURRING_EVENT', 'SUDDEN_SPIKE')),
  severity TEXT NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH')),
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (h3_index, type, description)
);

CREATE INDEX IF NOT EXISTS idx_intelligence_insights_created_at
  ON intelligence_insights(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_intelligence_insights_h3_type
  ON intelligence_insights(h3_index, type);

-- Internal state table for spike detection (comparison baseline).
CREATE TABLE IF NOT EXISTS intelligence_cell_state (
  h3_index BIGINT PRIMARY KEY,
  last_weight DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_intelligence_cell_state_updated_at
  ON intelligence_cell_state(updated_at DESC);

INSERT INTO model_parameters (key, value, description)
VALUES
  ('INTEL_HOTSPOT_THRESHOLD', 8.0, 'Risk cell weight threshold for hotspot detection'),
  ('INTEL_HOT_NEIGHBORS_MIN', 3.0, 'Minimum neighboring high-risk cells for hotspot flag'),
  ('INTEL_RECURRING_EVENTS_24H', 5.0, '24h event count threshold for recurring event insight'),
  ('INTEL_SPIKE_MULTIPLIER', 3.0, 'Risk spike ratio threshold (3.0 = 200% increase)'),
  ('INTEL_SPIKE_WINDOW_MINUTES', 10.0, 'Window for spike comparison in minutes'),
  ('INTEL_SCAN_LIMIT', 500.0, 'Maximum risk cells scanned per intelligence cycle')
ON CONFLICT (key) DO NOTHING;
