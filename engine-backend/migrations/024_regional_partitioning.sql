-- Migration 024: Nationwide Scaling (H3 Res 6) + MVCC Bloat Protection
-- Converts tables to declarative partitioning + Append-Only Versioning.

-- 1. Region Registry
CREATE TABLE IF NOT EXISTS spatial_regions (
  h3_parent BIGINT PRIMARY KEY, -- H3 Resolution 6
  region_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  last_streaming_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT TRUE
);

-- 2. Partitioned Append-Only Log
-- Each event observation is an immutable log entry.
CREATE TABLE IF NOT EXISTS regional_events_log (
  id UUID NOT NULL,
  h3_parent BIGINT NOT NULL, -- PARTITION KEY (Res 6)
  log_type TEXT NOT NULL, -- INGESTED, PROCESSED, ERROR
  source TEXT,
  source_ref TEXT,
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (id, h3_parent)
) PARTITION BY LIST (h3_parent);

-- 3. Partitioned Append-Only Active State (Fixes MVCC Bloat)
-- Instead of UPDATE, we INSERT new versions for every change (projection, decay).
CREATE TABLE IF NOT EXISTS regional_geo_events_v (
  event_id UUID NOT NULL,
  version INT NOT NULL DEFAULT 1,
  h3_parent BIGINT NOT NULL, -- PARTITION KEY (Res 6)
  h3_index BIGINT NOT NULL, -- Res 9
  event_type TEXT NOT NULL,
  severity INT,
  confidence DOUBLE PRECISION,
  geom GEOGRAPHY,
  status TEXT DEFAULT 'ACTIVE',
  observed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (event_id, version, h3_parent)
) PARTITION BY LIST (h3_parent);

-- 4. Partitioned Append-Only Risk Grid
-- Precomputed risk surface, updated incrementally.
CREATE TABLE IF NOT EXISTS regional_risk_grid_v (
  h3_index BIGINT NOT NULL, -- Res 9
  h3_parent BIGINT NOT NULL, -- PARTITION KEY (Res 6)
  version BIGINT NOT NULL, -- Global Sequence
  weight DOUBLE PRECISION DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (h3_index, version, h3_parent)
) PARTITION BY LIST (h3_parent);

-- 5. Partition Automation
CREATE OR REPLACE FUNCTION create_spatial_partition(p_h3_parent BIGINT)
RETURNS VOID AS $$
BEGIN
    -- Log Partition
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS events_log_reg_%s PARTITION OF regional_events_log FOR VALUES IN (%s)',
        p_h3_parent, p_h3_parent
    );
    
    -- Versioned Events Partition
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS geo_events_v_reg_%s PARTITION OF regional_geo_events_v FOR VALUES IN (%s)',
        p_h3_parent, p_h3_parent
    );

    -- Versioned Risk Partition
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS risk_grid_v_reg_%s PARTITION OF regional_risk_grid_v FOR VALUES IN (%s)',
        p_h3_parent, p_h3_parent
    );
    
    -- Optimized Index for Latest Lookup (Law 5)
    EXECUTE format(
        'CREATE INDEX IF NOT EXISTS idx_risk_grid_v_latest_%s ON risk_grid_v_reg_%s (h3_index, version DESC)',
        p_h3_parent, p_h3_parent
    );

    INSERT INTO spatial_regions (h3_parent) VALUES (p_h3_parent) ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql;
