-- STEP 3 & 4: Replace Radius Scan With H3 Neighborhood Query & Set-Based aggregation
-- Removes procedural loops and uses set-based distance decay.

CREATE OR REPLACE FUNCTION calculate_route_risk_v2(
  route_geom GEOGRAPHY,
  p_lambda_meters FLOAT DEFAULT 250.0,
  p_max_radius_meters FLOAT DEFAULT 500.0
)
RETURNS TABLE (
  raw_risk_score DOUBLE PRECISION,
  event_count INT
)
AS $$
BEGIN
  RETURN QUERY
  WITH route_cells AS (
    -- Convert route to H3 cells at res 9
    SELECT DISTINCT h3_lat_lng_to_cell(point(ST_Y(p::geometry), ST_X(p::geometry)), 9) as cell
    FROM ST_DumpPoints(route_geom::geometry) AS d(p)
  ),
  neighbor_cells AS (
    -- Get immediate neighbors to cover the search radius
    SELECT DISTINCT h3_grid_disk(cell, 1) as cell
    FROM route_cells
  ),
  filtered_events AS (
    -- Join events by H3 neighborhood (ignoring stale data)
    SELECT e.*
    FROM geo_events e
    INNER JOIN neighbor_cells nc ON e.h3_index = nc.cell
    WHERE e.status = 'ACTIVE'
      AND (e.expires_at IS NULL OR e.expires_at > now())
  )
  SELECT
    COALESCE(
      SUM(
        severity * confidence *
        exp(-ST_Distance(geom, route_geom) / p_lambda_meters)
      ),
      0
    ) AS raw_risk_score,
    COUNT(*)::INT AS event_count
  FROM filtered_events
  WHERE ST_DWithin(geom, route_geom, p_max_radius_meters);
END;
$$ LANGUAGE plpgsql;
