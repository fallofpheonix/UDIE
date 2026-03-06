-- Script: load_test_events.sql
-- Generates 100,000 synthetic events for saturation analysis and scaling benchmarks.

DO $$
DECLARE
    i INT;
    v_h3_del BIGINT := 617316715112103935; -- Delhi res 9 example
    v_event_types TEXT[] := ARRAY['CONSTRUCTION', 'ACCIDENT', 'FLOOD', 'PROTEST', 'WEATHER'];
BEGIN
    RAISE NOTICE 'Starting synthetic ingestion of 100k events...';
    
    FOR i IN 1..100000 LOOP
        INSERT INTO events_log (
            event_type, 
            severity, 
            confidence, 
            location, 
            city_code, 
            source_id, 
            observed_at,
            metadata
        ) VALUES (
            v_event_types[1 + floor(random()*5)],
            (random() * 5 + 1)::INT,
            random(),
            ST_SetSRID(ST_MakePoint(77.1025 + (random()-0.5)*0.1, 28.7041 + (random()-0.5)*0.1), 4326)::geography,
            'DEL',
            'synth_' || i,
            now(),
            jsonb_build_object('synthetic', true, 'batch', 1)
        );
        
        -- Commit in batches if needed, but DO block is atomic. 
        -- For real scale in psql CLI, it's better to use generate_series.
    END LOOP;
    
    RAISE NOTICE 'Ingestion complete.';
END $$;

-- Faster version using generate_series for future use:
-- INSERT INTO events_log (event_type, severity, confidence, location, city_code, source_id, observed_at, metadata)
-- SELECT 
--     (ARRAY['CONSTRUCTION', 'ACCIDENT', 'FLOOD', 'PROTEST', 'WEATHER'])[1 + floor(random()*5)],
--     (random() * 5 + 1)::INT,
--     random(),
--     ST_SetSRID(ST_MakePoint(77.1025 + (random()-0.5)*0.1, 28.7041 + (random()-0.5)*0.1), 4326)::geography,
--     'DEL',
--     'synth_' || g,
--     now(),
--     '{"synthetic": true}'::jsonb
-- FROM generate_series(1, 100000) g;
