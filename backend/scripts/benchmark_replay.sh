#!/bin/bash
# UDIE Benchmark Replay Script (Sprint 1)

set -e

DB_URL=${DATABASE_URL:-"postgresql://postgres:postgres@localhost:5432/udie"}

echo "🚀 Starting UDIE Benchmark Replay..."

# 1. Ensure minimum benchmark schema exists
echo "Step 1: Ensuring benchmark schema..."
psql "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS h3;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_status_enum') THEN
    CREATE TYPE event_status_enum AS ENUM ('ACTIVE', 'RESOLVED', 'DISMISSED', 'EXPIRED', 'MERGED');
  END IF;
END$$;

ALTER TABLE geo_events
  ADD COLUMN IF NOT EXISTS observed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS h3_index BIGINT,
  ADD COLUMN IF NOT EXISTS status event_status_enum NOT NULL DEFAULT 'ACTIVE';

CREATE TABLE IF NOT EXISTS model_parameters (
  key TEXT PRIMARY KEY,
  value DOUBLE PRECISION NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO model_parameters (key, value, description) VALUES
('SIGMOID_K', 20.0, 'Normalization constant'),
('DECAY_LAMBDA', 250.0, 'Distance decay rate in meters'),
('MAX_RADIUS', 500.0, 'Maximum spatial influence in meters')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();

CREATE TABLE IF NOT EXISTS risk_cells (
  h3_index BIGINT PRIMARY KEY,
  weight DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE OR REPLACE FUNCTION refresh_risk_surface()
RETURNS VOID AS $$
BEGIN
  INSERT INTO risk_cells (h3_index, weight, updated_at)
  SELECT h3_index, SUM(severity * confidence), now()
  FROM geo_events
  WHERE status = 'ACTIVE'
    AND h3_index IS NOT NULL
    AND (expires_at IS NULL OR expires_at > now())
  GROUP BY h3_index
  ON CONFLICT (h3_index) DO UPDATE
  SET weight = EXCLUDED.weight, updated_at = EXCLUDED.updated_at;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_route_risk_v3(
  p_route_geog geography,
  p_lambda_meters FLOAT DEFAULT NULL,
  p_max_radius_meters FLOAT DEFAULT NULL
)
RETURNS TABLE (raw_risk_score DOUBLE PRECISION, cell_count INT) AS $$
DECLARE
  v_lambda FLOAT;
  v_radius FLOAT;
BEGIN
  SELECT value INTO v_lambda FROM model_parameters WHERE key = 'DECAY_LAMBDA';
  SELECT value INTO v_radius FROM model_parameters WHERE key = 'MAX_RADIUS';
  v_lambda := COALESCE(p_lambda_meters, v_lambda, 250.0);
  v_radius := COALESCE(p_max_radius_meters, v_radius, 500.0);

  RETURN QUERY
  WITH route_cells AS (
    SELECT DISTINCT h3_latlng_to_cell(point(ST_Y(d.geom), ST_X(d.geom)), 9)::bigint AS cell
    FROM ST_DumpPoints(p_route_geog::geometry) AS d
  ),
  neighbor_cells AS (
    SELECT DISTINCT k.cell::bigint AS cell
    FROM route_cells rc
    CROSS JOIN LATERAL h3_grid_disk(rc.cell::h3index, 1) AS k(cell)
  )
  SELECT
    COALESCE(
      SUM(
        rc.weight *
        exp(-ST_Distance(
          ST_SetSRID(
            ST_MakePoint(
              (h3_cell_to_latlng(rc.h3_index::h3index))[1],
              (h3_cell_to_latlng(rc.h3_index::h3index))[0]
            ),
            4326
          )::geography,
          p_route_geog
        ) / v_lambda)
      ),
      0
    ) AS raw_risk_score,
    COUNT(rc.h3_index)::INT AS cell_count
  FROM neighbor_cells nc
  JOIN risk_cells rc ON rc.h3_index = nc.cell
  WHERE ST_DWithin(
    ST_SetSRID(
      ST_MakePoint(
        (h3_cell_to_latlng(rc.h3_index::h3index))[1],
        (h3_cell_to_latlng(rc.h3_index::h3index))[0]
      ),
      4326
    )::geography,
    p_route_geog,
    v_radius
  );
END;
$$ LANGUAGE plpgsql;
SQL

# 2. Schema Reset (Derived Layers Only)
echo "Step 2: Resetting Materialized Layers..."
psql "$DB_URL" -c "TRUNCATE geo_events, risk_cells CASCADE;"

# 3. Load Benchmark Log (Simulated Ingestion Replay)
echo "Step 3: Replaying Ingestion Log..."
# For now, we use generate_series for scale testing
psql "$DB_URL" -c "
INSERT INTO geo_events (
    event_type, severity, confidence, source, geom, city_code,
    start_time, end_time, status, h3_index, observed_at
)
SELECT 
    'CONSTRUCTION',
    GREATEST(1, LEAST(5, floor(random() * 5 + 1)::int)),
    0.7,
    'NEWS',
    ST_SetSRID(ST_MakePoint(p.lng, p.lat), 4326)::geography,
    'DEL',
    now(),
    now() + interval '4 hour',
    'ACTIVE',
    h3_latlng_to_cell(point(p.lat, p.lng), 9)::bigint,
    now()
FROM (
  SELECT
    28.6 + (random() - 0.5) * 0.2 AS lat,
    77.2 + (random() - 0.5) * 0.2 AS lng
  FROM generate_series(1, 10000)
) p;
"

# 4. Refresh Surface
echo "Step 4: Materializing Risk Surface..."
time psql "$DB_URL" -c "SELECT refresh_risk_surface();"

# 5. Execute Test Route (Verification Trial)
echo "Step 5: Running Verification Trial..."
psql "$DB_URL" -c "
EXPLAIN ANALYZE 
SELECT * FROM calculate_route_risk_v3(
    ST_GeogFromText('LINESTRING(77.2090 28.6139, 77.2150 28.6200)')
);
"

echo "✅ Benchmark Replay Complete."
