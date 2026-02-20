-- Phase B. Event Lifecycle (Steps 16 to 25)
-- Logic for confidence decay, expiry management, and spatial-temporal merging.

-- 1. Spatial-Temporal Merge Function (Step 21-22)
-- Radius 25m, Window 30min
CREATE OR REPLACE FUNCTION upsert_geo_event_v2(
  p_event_type event_type_enum,
  p_severity INT,
  p_confidence DOUBLE PRECISION,
  p_geom GEOGRAPHY,
  p_city_code TEXT,
  p_source_id TEXT,
  p_description TEXT DEFAULT NULL,
  p_source source_type_enum DEFAULT 'NEWS'
)
RETURNS TABLE (
  event_id UUID,
  op_type TEXT
) AS $$
DECLARE
  v_existing_id UUID;
BEGIN
  -- Search for existing active event within 25m and 30min
  SELECT id INTO v_existing_id
  FROM geo_events
  WHERE event_type = p_event_type
    AND status = 'ACTIVE'
    AND ST_DWithin(geom, p_geom, 25)
    AND abs(EXTRACT(EPOCH FROM (observed_at - now()))) < 1800
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    -- Strengthening logic: increase confidence, update last_observed, set merge flag
    UPDATE geo_events
    SET
      confidence = LEAST(confidence + 0.1, 1.0),
      last_observed = now(),
      updated_at = now(),
      severity = GREATEST(severity, p_severity),
      merge_flag = TRUE
    WHERE id = v_existing_id;
    
    RETURN QUERY SELECT v_existing_id, 'MERGE';
  ELSE
    -- New insertion
    INSERT INTO geo_events (
      event_type, severity, confidence, source, geom, city_code,
      source_id, description, h3_index,
      start_time, end_time,
      observed_at, expires_at, status
    )
    VALUES (
      p_event_type, p_severity, p_confidence, p_source, p_geom, p_city_code,
      p_source_id, p_description,
      h3_lat_lng_to_cell(point(ST_Y(p_geom::geometry), ST_X(p_geom::geometry)), 9)::bigint,
      now(), now() + interval '4 hours',
      now(), now() + interval '4 hours', 'ACTIVE'
    )
    RETURNING id INTO v_existing_id;
    
    RETURN QUERY SELECT v_existing_id, 'INSERT';
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 2. Confidence Decay Job (Step 17-18)
-- Auto-expire events below 0.25 (User Step 18)
CREATE OR REPLACE FUNCTION run_lifecycle_maintenance()
RETURNS VOID AS $$
BEGIN
  -- 1. Marking stale events as EXPIRED (Step 16)
  UPDATE geo_events
  SET status = 'EXPIRED', updated_at = now()
  WHERE status = 'ACTIVE' 
    AND expires_at IS NOT NULL 
    AND expires_at < now();

  -- 2. Confidence Decay (Step 17)
  UPDATE geo_events
  SET 
    confidence = confidence * 0.97, -- 3% decay
    updated_at = now()
  WHERE status = 'ACTIVE';

  -- 3. Auto-expire below threshold (Step 18)
  UPDATE geo_events
  SET status = 'EXPIRED', updated_at = now()
  WHERE status = 'ACTIVE' AND confidence < 0.25;
END;
$$ LANGUAGE plpgsql;
