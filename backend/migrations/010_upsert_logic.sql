-- STEP 10: Implement Spatial-Temporal Deduplication (Database-Level)
-- Merges new reports into existing active events if they are spatially (25m) 
-- and temporally (30min) aligned, strengthening confidence.

CREATE OR REPLACE FUNCTION upsert_geo_event(
  p_event_type event_type_enum,
  p_severity INT,
  p_confidence DOUBLE PRECISION,
  p_geom GEOGRAPHY,
  p_city_code TEXT,
  p_source source_type_enum,
  p_source_ref TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL
)
RETURNS TABLE (
  event_id UUID,
  op_type TEXT
) AS $$
DECLARE
  v_existing_id UUID;
BEGIN
  -- Search for an existing active event of the same type within 25 meters and 30 minutes
  SELECT id INTO v_existing_id
  FROM geo_events
  WHERE event_type = p_event_type
    AND status = 'ACTIVE' -- ACTIVE
    AND ST_DWithin(geom, p_geom, 25)
    AND abs(EXTRACT(EPOCH FROM (observed_at - now()))) < 1800
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    -- Update existing event: boost confidence and update observation time
    UPDATE geo_events
    SET
      confidence = LEAST(confidence + 0.1, 1.0),
      observed_at = now(),
      last_observed = now(),
      severity = GREATEST(severity, p_severity)
    WHERE id = v_existing_id;
    
    RETURN QUERY SELECT v_existing_id, 'UPDATE';
  ELSE
    -- Insert new event
    INSERT INTO geo_events (
      event_type, severity, confidence, source, geom, city_code,
      source_id, description, h3_index,
      start_time, end_time,
      observed_at, expires_at, status
    )
    VALUES (
      p_event_type, p_severity, p_confidence, p_source, p_geom, p_city_code,
      p_source_ref, p_description,
      h3_lat_lng_to_cell(point(ST_Y(p_geom::geometry), ST_X(p_geom::geometry)), 9)::bigint,
      now(), now() + interval '4 hours',
      now(), now() + interval '4 hours', 'ACTIVE'
    )
    RETURNING id INTO v_existing_id;
    
    RETURN QUERY SELECT v_existing_id, 'INSERT';
  END IF;
END;
$$ LANGUAGE plpgsql;
