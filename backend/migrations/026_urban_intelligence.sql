-- Migration 026: Urban Pattern Intelligence
-- Stores derived intelligence events and temporal cell state.

-- 1. Intelligence Events (Insights)
-- Note: Named 'intelligence_events' per user request, aliased from 'insights'.
CREATE TABLE IF NOT EXISTS intelligence_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    h3_index BIGINT NOT NULL, -- Res 9
    event_type TEXT NOT NULL, -- HOTSPOT, SPIKE, RECURRING
    severity TEXT NOT NULL,   -- LOW, MEDIUM, HIGH
    description TEXT,
    metadata JSONB,           -- Debug info: weights, neighbor counts
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_intel_h3 ON intelligence_events (h3_index);
CREATE INDEX IF NOT EXISTS idx_intel_type ON intelligence_events (event_type);

-- 2. Temporal Cell State
-- Stores snapshots of risk for spike detection.
CREATE TABLE IF NOT EXISTS intelligence_cell_state (
    h3_index BIGINT PRIMARY KEY,
    last_weight DOUBLE PRECISION,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Model Parameters for Intelligence
INSERT INTO model_parameters (key, value, description)
VALUES 
    ('INTEL_HOTSPOT_THRESHOLD', 8.0, 'Min weight to consider a cell a hotspot candidate'),
    ('INTEL_SPIKE_THRESHOLD', 3.0, 'Multiplier for sudden risk increase detection'),
    ('INTEL_RECURRING_WINDOW_HOURS', 24, 'Lookback window for recurring pattern detection')
ON CONFLICT (key) DO NOTHING;
