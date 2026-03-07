-- Migration 023: Batch Projection Logic
-- Decouples raw signal ingestion from spatial projection using set-based batch updates.

CREATE OR REPLACE FUNCTION process_observation_batch(p_log_ids UUID[])
RETURNS TABLE (
  processed_count INT,
  merged_count INT,
  inserted_count INT
) AS $$
DECLARE
    v_processed INT := 0;
    v_merged INT := 0;
    v_inserted INT := 0;
BEGIN
    -- 1. Create a working set of normalized observations
    -- We use a CTE to extract and normalize data from the logs
    WITH raw_observations AS (
        SELECT 
            id as log_id,
            (payload->>'event_type')::event_type_enum as event_type,
            (payload->>'severity_hint')::INT as severity,
            COALESCE((payload->>'confidence')::DOUBLE PRECISION, 0.7) as confidence,
            ST_SetSRID(ST_Point((payload->>'lng')::FLOAT, (payload->>'lat')::FLOAT), 4326)::geography as geom,
            COALESCE(payload->>'city_code', 'DEL') as city_code,
            source_ref as source_id,
            payload->>'text' as description,
            COALESCE((payload->>'observed_at')::TIMESTAMPTZ, now()) as observed_at
        FROM events_log
        WHERE id = ANY(p_log_ids)
          AND log_type = 'INGESTED'
    ),
    -- 2. Deduplicate within the batch itself (keep latest/highest severity)
    deduped_batch AS (
        SELECT DISTINCT ON (event_type, h3_latlng_to_cell(point(ST_Y(geom::geometry), ST_X(geom::geometry)), 9))
            *
        FROM raw_observations
        ORDER BY event_type, h3_latlng_to_cell(point(ST_Y(geom::geometry), ST_X(geom::geometry)), 9), observed_at DESC
    ),
    -- 3. Perform the mass UPSERT into geo_events
    -- This uses the same 25m/30min logic as upsert_geo_event_v2 but optimized for batch
    upserts AS (
        INSERT INTO geo_events (
            event_type, severity, confidence, source, geom, city_code,
            source_id, description, h3_index,
            start_time, end_time,
            observed_at, expires_at, status
        )
        SELECT 
            event_type, severity, confidence, 'NEWS', geom, city_code,
            source_id, description, 
            h3_latlng_to_cell(point(ST_Y(geom::geometry), ST_X(geom::geometry)), 9)::bigint,
            now(), now() + interval '4 hours',
            observed_at, now() + interval '4 hours', 'ACTIVE'
        FROM deduped_batch
        ON CONFLICT (event_type, h3_index) WHERE status = 'ACTIVE'
        DO UPDATE SET
            confidence = LEAST(geo_events.confidence + 0.1, 1.0),
            observed_at = EXCLUDED.observed_at,
            last_observed = now(),
            updated_at = now(),
            severity = GREATEST(geo_events.severity, EXCLUDED.severity),
            merge_flag = TRUE
        RETURNING id, (xmax = 0) as is_insert
    )
    SELECT 
        (SELECT COUNT(*) FROM deduped_batch)::INT,
        (SELECT COUNT(*) FROM upserts WHERE is_insert = FALSE)::INT,
        (SELECT COUNT(*) FROM upserts WHERE is_insert = TRUE)::INT
    INTO v_processed, v_merged, v_inserted;

    -- 4. Mark logs as PROCESSED by inserting child entries
    INSERT INTO events_log (log_type, source, source_ref, parent_log_id, payload)
    SELECT 
        'PROCESSED', 
        'SYSTEM', 
        'BATCH_PROJECTION', 
        id, 
        jsonb_build_object('processed_at', now(), 'batch_id', p_log_ids[1])
    FROM raw_observations;

    RETURN QUERY SELECT v_processed, v_merged, v_inserted;
END;
$$ LANGUAGE plpgsql;
