-- STEP 6: Synthetic Load Generator
-- Populates geo_events with 50,000 synthetic disruptions around a center point (e.g., Delhi)

INSERT INTO geo_events (
  event_type,
  severity,
  confidence,
  geom,
  observed_at,
  expires_at,
  city_code,
  status,
  h3_index
)
SELECT
  (ARRAY['ACCIDENT', 'CONSTRUCTION', 'WATER_LOGGING', 'PROTEST'])[floor(random()*4)+1]::event_type_enum,
  (random()*5)::int,
  random(),
  ST_SetSRID(ST_MakePoint(77.1 + (random()-0.5)*0.2, 28.6 + (random()-0.5)*0.2), 4326)::geography,
  now() - (random() * interval '2 hour'),
  now() + (random() * interval '4 hour'),
  'DEL',
  1,
  h3_lat_lng_to_cell(point(28.6 + (random()-0.5)*0.2, 77.1 + (random()-0.5)*0.2), 9)::bigint
FROM generate_series(1, 50000);

-- Analyze to ensure statistics are fresh for planner
ANALYZE geo_events;
