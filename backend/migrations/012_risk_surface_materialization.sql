-- STEP 17: Materialize a Risk Surface
-- This table stores pre-aggregated weights per H3 cell to prevent recomputing from raw events.

CREATE TABLE IF NOT EXISTS risk_cells (
  h3_index BIGINT PRIMARY KEY,
  weight DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Procedure to refresh risk_cells layer
CREATE OR REPLACE FUNCTION refresh_risk_surface()
RETURNS VOID AS $$
BEGIN
  INSERT INTO risk_cells (h3_index, weight, updated_at)
  SELECT
    h3_index,
    SUM(severity * confidence) as weight,
    now()
  FROM geo_events
  WHERE status = 'ACTIVE'
    AND (expires_at IS NULL OR expires_at > now())
  GROUP BY h3_index
  ON CONFLICT (h3_index)
  DO UPDATE SET
    weight = EXCLUDED.weight,
    updated_at = EXCLUDED.updated_at;
    
  -- Optional: Delete stale cells (weight = 0 or no active events)
  DELETE FROM risk_cells WHERE h3_index NOT IN (
    SELECT DISTINCT h3_index FROM geo_events WHERE status = 'ACTIVE'
  );
END;
$$ LANGUAGE plpgsql;

-- STEP 18: Rewrite Risk Query to Use risk_cells
-- This query computes route risk by aggregating pre-computed cell weights.

CREATE OR REPLACE FUNCTION calculate_route_risk_v3(
  p_route_geog geography,
  p_lambda_meters FLOAT DEFAULT NULL,
  p_max_radius_meters FLOAT DEFAULT NULL
)
RETURNS TABLE (
  raw_risk_score DOUBLE PRECISION,
  cell_count INT
)
AS $$
DECLARE
  v_lambda FLOAT;
  v_radius FLOAT;
BEGIN
  -- Fetch parameters from DB if NULL (Atomic Law #4)
  SELECT value INTO v_lambda FROM model_parameters WHERE key = 'DECAY_LAMBDA';
  SELECT value INTO v_radius FROM model_parameters WHERE key = 'MAX_RADIUS';
  
  v_lambda := COALESCE(p_lambda_meters, v_lambda, 250.0);
  v_radius := COALESCE(p_max_radius_meters, v_radius, 500.0);

  RETURN QUERY
  WITH route_cells AS (
    -- Convert route to H3 coverage at res 9 (approximate via points)
    SELECT DISTINCT h3_latlng_to_cell(point(ST_Y(d.geom), ST_X(d.geom)), 9)::bigint AS cell
    FROM ST_DumpPoints(p_route_geog::geometry) AS d
  ),
  neighbor_cells AS (
    -- Get neighborhood to cover the search radius
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
