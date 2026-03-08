-- Migration 043: Restore regional_geo_events_v compatibility after phase-31 drop.
-- This reintroduces the append-only regional event projection consumed by read APIs.

CREATE TABLE IF NOT EXISTS regional_geo_events_v (
  event_id UUID NOT NULL,
  version INT NOT NULL DEFAULT 1,
  h3_parent BIGINT NOT NULL,
  h3_index BIGINT NOT NULL,
  event_type TEXT NOT NULL,
  severity INT,
  confidence DOUBLE PRECISION,
  geom GEOGRAPHY,
  status TEXT DEFAULT 'ACTIVE',
  observed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (event_id, version, h3_parent)
) PARTITION BY LIST (h3_parent);

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT DISTINCT h3_parent FROM spatial_regions
    UNION
    SELECT DISTINCT h3_parent FROM regional_events_log
  ) LOOP
    PERFORM create_spatial_partition(r.h3_parent);
  END LOOP;
END $$;

CREATE INDEX IF NOT EXISTS idx_regional_geo_events_v_h3_parent
  ON regional_geo_events_v (h3_parent);

CREATE INDEX IF NOT EXISTS idx_regional_geo_events_v_h3_index
  ON regional_geo_events_v (h3_index);

CREATE INDEX IF NOT EXISTS idx_regional_geo_events_v_observed_at
  ON regional_geo_events_v (observed_at DESC);

CREATE INDEX IF NOT EXISTS idx_regional_geo_events_v_status
  ON regional_geo_events_v (status);

CREATE INDEX IF NOT EXISTS idx_regional_geo_events_v_geom
  ON regional_geo_events_v USING GIST (geom);

WITH normalized AS (
  SELECT
    l.id AS event_id,
    1 AS version,
    l.h3_parent,
    COALESCE(
      NULLIF(l.payload->>'h3_index', '')::bigint,
      h3index_to_bigint(
        h3_latlng_to_cell(
          point((l.payload->>'lat')::double precision, (l.payload->>'lng')::double precision),
          9
        )
      )
    ) AS h3_index,
    COALESCE(NULLIF(upper(l.payload->>'event_type'), ''), 'UNKNOWN') AS event_type,
    GREATEST(1, LEAST(5, COALESCE((l.payload->>'severity_hint')::int, 1))) AS severity,
    GREATEST(0, LEAST(1, COALESCE((l.payload->>'confidence_hint')::double precision, l.reliability_score, 1.0))) AS confidence,
    ST_SetSRID(
      ST_MakePoint((l.payload->>'lng')::double precision, (l.payload->>'lat')::double precision),
      4326
    )::geography AS geom,
    'ACTIVE'::text AS status,
    COALESCE((l.payload->>'observed_at')::timestamptz, l.created_at) AS observed_at
  FROM regional_events_log l
  WHERE l.log_type IN ('INGESTED', 'PROCESSED')
    AND (l.payload->>'lat') ~ '^-?[0-9]+(\\.[0-9]+)?$'
    AND (l.payload->>'lng') ~ '^-?[0-9]+(\\.[0-9]+)?$'
)
INSERT INTO regional_geo_events_v (
  event_id,
  version,
  h3_parent,
  h3_index,
  event_type,
  severity,
  confidence,
  geom,
  status,
  observed_at
)
SELECT
  event_id,
  version,
  h3_parent,
  h3_index,
  event_type,
  severity,
  confidence,
  geom,
  status,
  observed_at
FROM normalized
ON CONFLICT (event_id, version, h3_parent) DO NOTHING;
