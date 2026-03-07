-- Phase A. Data Model and Storage (Steps 1 to 15)
-- Consolidated migration for production structural foundation.

-- 1. Enable H3 and PostGIS (Validated in Dockerfile)
CREATE EXTENSION IF NOT EXISTS h3;
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Status Enum
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_status_enum') THEN
    CREATE TYPE event_status_enum AS ENUM (
      'ACTIVE',
      'DECAYED',
      'EXPIRED',
      'MERGED'
    );
  END IF;
END$$;

-- 3. Schema Expansion
ALTER TABLE geo_events 
  ADD COLUMN IF NOT EXISTS observed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS status event_status_enum NOT NULL DEFAULT 'ACTIVE',
  ADD COLUMN IF NOT EXISTS source_id TEXT,
  ADD COLUMN IF NOT EXISTS confidence DOUBLE PRECISION NOT NULL DEFAULT 0.5,
  ADD COLUMN IF NOT EXISTS h3_index BIGINT,
  ADD COLUMN IF NOT EXISTS merge_flag BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS last_observed TIMESTAMPTZ DEFAULT now();

-- 4. DB-Level Enforcement
ALTER TABLE geo_events ALTER COLUMN geom SET NOT NULL;

-- 5. Constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'check_lat_lng'
      AND conrelid = 'geo_events'::regclass
  ) THEN
    ALTER TABLE geo_events
      ADD CONSTRAINT check_lat_lng
      CHECK (ST_Y(geom::geometry) BETWEEN -90 AND 90 AND ST_X(geom::geometry) BETWEEN -180 AND 180);
  END IF;
END$$;

-- 6. Backfill Data
UPDATE geo_events
SET 
  observed_at = start_time,
  expires_at = end_time,
  source_id = source_ref,
  h3_index = h3_lat_lng_to_cell(point(ST_Y(geom::geometry), ST_X(geom::geometry)), 9)::bigint;

-- 7. Indices
CREATE INDEX IF NOT EXISTS idx_events_h3 ON geo_events(h3_index);
CREATE INDEX IF NOT EXISTS idx_events_active ON geo_events(expires_at) 
WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_events_geom_gist ON geo_events USING GIST(geom);

-- 8. Update Active View
DROP VIEW IF EXISTS active_geo_events;
CREATE VIEW active_geo_events AS
SELECT 
  id,
  event_type,
  severity,
  confidence,
  status,
  source_id,
  description,
  observed_at,
  expires_at,
  last_observed,
  h3_index,
  city_code,
  geom
FROM geo_events
WHERE status = 'ACTIVE' AND (expires_at IS NULL OR expires_at > now());

-- 9. Migration Version Table
CREATE TABLE IF NOT EXISTS migration_versions (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO migration_versions (version) VALUES ('007_phase_a_hardened') ON CONFLICT DO NOTHING;
