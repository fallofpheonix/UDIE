-- Computes a risk score for a given route based on proximity to active geo-events.
-- Score = SUM(severity * confidence * exp(-distance / decay_constant))
-- Only events within 500m of the route are considered.
CREATE OR REPLACE FUNCTION calculate_route_risk(
  route_geom GEOGRAPHY,
  city TEXT
)
RETURNS TABLE (
  risk_score DOUBLE PRECISION,
  event_count INT
)
AS $$
DECLARE
  decay_constant_meters FLOAT := 250.0;
  search_radius_meters FLOAT := 500.0;
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(
      SUM(
        severity * confidence *
        exp(-ST_Distance(geom, route_geom) / decay_constant_meters)
      ),
      0
    ) AS risk_score,
    COUNT(*)::INT AS event_count
  FROM geo_events
  WHERE
    city_code = city
    AND (end_time IS NULL OR end_time >= now())
    AND ST_DWithin(geom, route_geom, search_radius_meters);
END;
$$ LANGUAGE plpgsql;
