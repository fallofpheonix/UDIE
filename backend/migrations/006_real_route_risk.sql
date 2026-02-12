CREATE OR REPLACE FUNCTION calculate_route_risk(
  route_geom GEOGRAPHY,
  city TEXT
)
RETURNS TABLE (
  risk_score DOUBLE PRECISION,
  event_count INT
)
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(
      SUM(
        severity * confidence *
        exp(-ST_Distance(geom, route_geom) / 200)
      ),
      0
    ) AS risk_score,
    COUNT(*)::INT AS event_count
  FROM geo_events
  WHERE
    city_code = city
    AND (end_time IS NULL OR end_time >= now())
    AND ST_DWithin(geom, route_geom, 500);
END;
$$ LANGUAGE plpgsql;
