-- Add status enum
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_status_enum') THEN
    CREATE TYPE event_status_enum AS ENUM (
      'ACTIVE',
      'RESOLVED',
      'DISMISSED',
      'EXPIRED'
    );
  END IF;
END$$;

-- Add temporal and spatial indexing columns
ALTER TABLE geo_events 
  ADD COLUMN IF NOT EXISTS observed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS h3_index BIGINT,
  ADD COLUMN IF NOT EXISTS status event_status_enum NOT NULL DEFAULT 'ACTIVE';

-- Add partial index for active performance
CREATE INDEX IF NOT EXISTS idx_geo_events_active 
  ON geo_events USING GIST(geom) 
  WHERE status = 'ACTIVE';

-- Add H3 index for fast grid-based aggregation
CREATE INDEX IF NOT EXISTS idx_geo_events_h3 
  ON geo_events (h3_index) 
  WHERE status = 'ACTIVE';

-- Update the risk function to follow versioned model
CREATE OR REPLACE FUNCTION calculate_route_risk_v1(
  route_geom GEOGRAPHY,
  lambda_meters FLOAT DEFAULT 250.0,
  max_radius_meters FLOAT DEFAULT 500.0
)
RETURNS TABLE (
  raw_risk_score DOUBLE PRECISION,
  event_count INT
)
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(
      SUM(
        severity * confidence *
        exp(-ST_Distance(geom, route_geom) / lambda_meters)
      ),
      0
    ) AS raw_risk_score,
    COUNT(*)::INT AS event_count
  FROM geo_events
  WHERE
    status = 'ACTIVE'
    AND (expires_at IS NULL OR expires_at > now())
    AND ST_DWithin(geom, route_geom, max_radius_meters);
END;
$$ LANGUAGE plpgsql;
