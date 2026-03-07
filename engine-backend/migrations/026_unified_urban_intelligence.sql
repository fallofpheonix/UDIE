-- Migration 026: Unified Urban Intelligence
-- Purpose: Coherent schema for intelligence events, hotspots, and temporal state.

-- 1. Intelligence Events (Insights)
CREATE TABLE IF NOT EXISTS intelligence_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    h3_index BIGINT NOT NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('HOTSPOT', 'SUDDEN_SPIKE', 'RECURRING_DISRUPTION')),
    severity TEXT NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH')),
    score DOUBLE PRECISION NOT NULL,
    threshold DOUBLE PRECISION NOT NULL,
    description TEXT,
    event_count INT NOT NULL DEFAULT 0,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_intel_events_h3_type 
    ON intelligence_events (h3_index, event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_intel_events_created_at 
    ON intelligence_events (created_at DESC);

-- 2. Temporal Cell State (Internal for Spike Detection)
CREATE TABLE IF NOT EXISTS intelligence_cell_state (
    h3_index BIGINT PRIMARY KEY,
    last_weight DOUBLE PRECISION NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Unified Intelligence Parameters
INSERT INTO model_parameters (key, value, description)
VALUES 
    ('INTEL_HOTSPOT_THRESHOLD', 8.0, 'Min weight to consider a cell a hotspot candidate'),
    ('INTEL_SPIKE_MULTIPLIER', 3.0, 'Multiplier for sudden risk increase detection (>=3.0 means >200% increase)'),
    ('INTEL_RECURRING_WINDOW_HOURS', 24, 'Lookback window for recurring pattern detection'),
    ('INTEL_SCAN_LIMIT', 1000, 'Maximum cells scanned per intelligence cycle')
ON CONFLICT (key) DO UPDATE 
SET 
    value = EXCLUDED.value,
    description = EXCLUDED.description;
