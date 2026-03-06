-- Migration 031: Unified Streaming Architecture & Density Amplification
-- 1. Metadata: Add Density Alpha
INSERT INTO model_parameters (key, value, description)
VALUES ('ALPHA_DENSITY', 0.15, 'Multiplicative factor for spatial clustering: 1 + alpha * log(1 + count)')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- 2. Performance: Composite index for sliding-window aggregation
-- Enables O(window_size) lookup of active logs within a region.
CREATE INDEX IF NOT EXISTS idx_regional_logs_active_window 
ON regional_events_log (h3_parent, created_at DESC) 
WHERE log_type = 'PROCESSED';

-- 3. Cleanup: Remove Redundant Projection Layer
-- We no longer need regional_geo_events_v as we compute current state from logs.
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE tablename LIKE 'geo_events_v_reg_%') LOOP
        EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP;
END $$;

DROP TABLE IF EXISTS regional_geo_events_v CASCADE;

-- 4. Simplified Aggregator: Direct Log-to-Grid
-- Logic: weight = SUM(severity * exp(-decay * age)) * density_factor
CREATE OR REPLACE FUNCTION reaggregate_region_risk(p_h3_parent BIGINT)
RETURNS VOID AS $$
DECLARE
    v_alpha DOUBLE PRECISION;
    v_window_hours INT := 6;
BEGIN
    SELECT value INTO v_alpha FROM model_parameters WHERE key = 'ALPHA_DENSITY';
    
    -- Clear current region weights (Rebuildable state)
    DELETE FROM risk_cells WHERE (h3_index::h3index)::bigint IN (
        SELECT h3_index FROM regional_risk_grid_v WHERE h3_parent = p_h3_parent
    );

    -- Unified Aggregation:
    -- 1. Filter logs in window (6h)
    -- 2. Compute log-reinforcement + temporal decay
    -- 3. Apply Density Factor: 1 + alpha * log(1 + neighbor_count)
    INSERT INTO risk_cells (h3_index, weight, updated_at)
    SELECT 
        (h3_index::h3index)::bigint,
        SUM(weighted_severity) * (1 + v_alpha * ln(1 + COUNT(*))) as final_weight,
        now()
    FROM (
        SELECT 
            (payload->>'h3_index')::bigint as h3_index,
            (payload->>'severity_hint')::double precision * 
            EXP(-0.1 * EXTRACT(EPOCH FROM (now() - created_at))/3600) as weighted_severity
        FROM regional_events_log
        WHERE h3_parent = p_h3_parent 
          AND log_type = 'PROCESSED'
          AND created_at > now() - (v_window_hours || ' hours')::interval
    ) t
    GROUP BY h3_index
    ON CONFLICT (h3_index) DO UPDATE SET
        weight = EXCLUDED.weight,
        updated_at = now();
END;
$$ LANGUAGE plpgsql;
