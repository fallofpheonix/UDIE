-- Migration 020: Refined Risk Calculation
-- Addresses spatial bias by segmentizing routes and implementing length-based normalization.

CREATE OR REPLACE FUNCTION calculate_route_risk_v4(
  p_route_geog geography,
  p_lambda_meters FLOAT DEFAULT NULL,
  p_max_radius_meters FLOAT DEFAULT NULL
)
RETURNS TABLE (
  raw_risk_score DOUBLE PRECISION,
  cell_count INT,
  route_length_meters DOUBLE PRECISION
)
AS $$
DECLARE
  v_lambda FLOAT;
  v_radius FLOAT;
  v_route_len FLOAT;
BEGIN
  SELECT value INTO v_lambda FROM model_parameters WHERE key = 'DECAY_LAMBDA';
  SELECT value INTO v_radius FROM model_parameters WHERE key = 'MAX_RADIUS';
  
  v_lambda := COALESCE(p_lambda_meters, v_lambda, 250.0);
  v_radius := COALESCE(p_max_radius_meters, v_radius, 500.0);
  v_route_len := ST_Length(p_route_geog);

  RETURN QUERY
  WITH segmentized AS (
    -- Ensure route points are dense enough to hit all relevant H3 cells (approx 50m res)
    SELECT ST_Segmentize(p_route_geog::geometry, 50)::geography as geom
  ),
  route_cells AS (
    SELECT DISTINCT h3_latlng_to_cell(point(ST_Y(d.geom), ST_X(d.geom)), 9)::bigint AS cell
    FROM ST_DumpPoints((SELECT geom FROM segmentized)::geometry) AS d
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
    COUNT(rc.h3_index)::INT AS cell_count,
    v_route_len AS route_length_meters
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
