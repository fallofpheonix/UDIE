-- STEP 1: Fix Data Model (Temporal & H3)
-- Requires H3 extension for Postgres
CREATE EXTENSION IF NOT EXISTS h3;

-- Status Enum
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_status_enum') THEN
    CREATE TYPE event_status_enum AS ENUM (
      'ACTIVE',
      'RESOLVED',
      'DISMISSED',
      'EXPIRED',
      'MERGED'
    );
  END IF;
END$$;

-- Add production columns to geo_events
ALTER TABLE geo_events 
  ADD COLUMN IF NOT EXISTS observed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS source_id TEXT,
  ADD COLUMN IF NOT EXISTS h3_index BIGINT,
  ADD COLUMN IF NOT EXISTS status event_status_enum NOT NULL DEFAULT 'ACTIVE';

-- Backward compatibility for prior smallint status deployments.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'geo_events'
      AND column_name = 'status'
      AND udt_name = 'int2'
  ) THEN
    ALTER TABLE geo_events
      ALTER COLUMN status TYPE event_status_enum
      USING CASE status
        WHEN 1 THEN 'ACTIVE'::event_status_enum
        WHEN 2 THEN 'EXPIRED'::event_status_enum
        WHEN 3 THEN 'MERGED'::event_status_enum
        ELSE 'ACTIVE'::event_status_enum
      END;
  END IF;
END$$;

-- Update existing rows with H3 indices
UPDATE geo_events
SET h3_index = h3_lat_lng_to_cell(point(ST_Y(geom::geometry), ST_X(geom::geometry)), 9)::bigint
WHERE h3_index IS NULL;

-- Create production indices
CREATE INDEX IF NOT EXISTS idx_events_h3 ON geo_events(h3_index);
CREATE INDEX IF NOT EXISTS idx_events_active ON geo_events(expires_at)
WHERE status = 'ACTIVE';

-- GIST fallback for non-bucketed queries
CREATE INDEX IF NOT EXISTS idx_events_geom_active ON geo_events USING GIST(geom)
WHERE status = 'ACTIVE';

-- STEP 23: Versioned Risk Configuration
CREATE TABLE IF NOT EXISTS risk_config (
  version INT PRIMARY KEY,
  decay_constant_lambda DOUBLE PRECISION NOT NULL,
  search_radius_meters DOUBLE PRECISION NOT NULL,
  normalization_k DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Insert Model v1 parameters (λ=250m, R=500m, k=20)
INSERT INTO risk_config (version, decay_constant_lambda, search_radius_meters, normalization_k)
VALUES (1, 250.0, 500.0, 20.0)
ON CONFLICT (version) DO UPDATE SET
  decay_constant_lambda = EXCLUDED.decay_constant_lambda,
  search_radius_meters = EXCLUDED.search_radius_meters,
  normalization_k = EXCLUDED.normalization_k;

-- STEP 5: Risk Baseline table
CREATE TABLE IF NOT EXISTS risk_baseline (
  city TEXT PRIMARY KEY,
  p95 DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);
