-- Migration 026: Intelligence Event Stream
-- Purpose: append-only intelligence detection events for deterministic replay and auditing.

CREATE TABLE IF NOT EXISTS intelligence_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  h3_index BIGINT NOT NULL,
  pattern_type TEXT NOT NULL CHECK (pattern_type IN ('HOTSPOT', 'SUDDEN_SPIKE', 'RECURRING_DISRUPTION')),
  severity TEXT NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH')),
  score DOUBLE PRECISION NOT NULL,
  threshold DOUBLE PRECISION NOT NULL,
  window_minutes INT NOT NULL,
  event_count INT NOT NULL DEFAULT 0,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_intelligence_events_created_at
  ON intelligence_events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_intelligence_events_h3_type
  ON intelligence_events(h3_index, pattern_type, created_at DESC);

INSERT INTO model_parameters (key, value, description)
VALUES
  ('INTEL_HOTSPOT_THRESHOLD', 8.0, 'Cell weight threshold for hotspot detection'),
  ('INTEL_HOT_NEIGHBORS_MIN', 3.0, 'Minimum neighboring high-risk cells for hotspot classification'),
  ('INTEL_SPIKE_MULTIPLIER', 3.0, 'Spike ratio threshold (>=3 means >200% increase)'),
  ('INTEL_SPIKE_WINDOW_MINUTES', 10.0, 'Spike detection comparison window in minutes'),
  ('INTEL_RECURRING_EVENTS_24H', 5.0, 'Recurring event threshold in 24-hour window'),
  ('INTEL_SCAN_LIMIT', 500.0, 'Maximum cells scanned per intelligence cycle')
ON CONFLICT (key) DO UPDATE
SET
  value = EXCLUDED.value,
  description = EXCLUDED.description;
