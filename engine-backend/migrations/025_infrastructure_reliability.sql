-- Migration 025: Infrastructure Reliability Index (IRI)
-- Implements long-term stability tracking for urban cells.

-- 1. Reliability State Table
-- This table stores the aggregated long-term metrics for every cell.
CREATE TABLE IF NOT EXISTS reliability_cells (
  h3_index BIGINT PRIMARY KEY, -- Resolution 9
  disruption_count INT DEFAULT 0,
  avg_severity DOUBLE PRECISION DEFAULT 0,
  avg_duration_hours DOUBLE PRECISION DEFAULT 0,
  reliability_score DOUBLE PRECISION DEFAULT 1.0,
  last_aggregated_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for spatial bounding box queries (H3 cell to parent resolution 6)
CREATE INDEX IF NOT EXISTS idx_reliability_parent ON reliability_cells ((h3_cell_to_parent(h3_index::h3index, 6)));

-- 2. Aggregation Logic Function
-- This function calculates the IRI for a given set of cells based on 30-day history.
CREATE OR REPLACE FUNCTION aggregate_cell_reliability(p_h3_index BIGINT, p_k DOUBLE PRECISION)
RETURNS VOID AS $$
DECLARE
    v_count INT;
    v_avg_sev DOUBLE PRECISION;
    v_avg_dur DOUBLE PRECISION;
    v_instability DOUBLE PRECISION;
    v_iri DOUBLE PRECISION;
BEGIN
    -- Aggregate from regional_events_log (Law 2: Truth is in the log)
    -- We assume the 'payload' contains 'severity_hint' and we derive duration from log lifecycle if available.
    -- For now, we use a simplified count-based model.
    SELECT 
        COUNT(*),
        COALESCE(AVG((payload->>'severity_hint')::double precision), 5.0)
    INTO v_count, v_avg_sev
    FROM regional_events_log
    WHERE (payload->>'h3_index')::bigint = p_h3_index
      AND created_at >= now() - interval '30 days'
      AND log_type = 'PROCESSED';

    -- Simplified duration (placeholder logic: assume average 4 hours per disruption if not tracked)
    v_avg_dur := 4.0;

    -- IRI Formula: exp(-instability / k)
    -- instability = count * avg_severity * avg_duration
    v_instability := v_count * v_avg_sev * v_avg_dur;
    v_iri := exp(-v_instability / NULLIF(p_k, 0));

    INSERT INTO reliability_cells (h3_index, disruption_count, avg_severity, avg_duration_hours, reliability_score, last_aggregated_at, updated_at)
    VALUES (p_h3_index, v_count, v_avg_sev, v_avg_dur, v_iri, now(), now())
    ON CONFLICT (h3_index) DO UPDATE SET
        disruption_count = EXCLUDED.disruption_count,
        avg_severity = EXCLUDED.avg_severity,
        avg_duration_hours = EXCLUDED.avg_duration_hours,
        reliability_score = EXCLUDED.reliability_score,
        last_aggregated_at = EXCLUDED.last_aggregated_at,
        updated_at = EXCLUDED.updated_at;
END;
$$ LANGUAGE plpgsql;

-- 3. Model Parameter for IRI Scaling
INSERT INTO model_parameters (key, value, description)
VALUES ('IRI_SCALING_K', 100.0, 'Scaling factor for Infrastructure Reliability Index calculation')
ON CONFLICT (key) DO NOTHING;
