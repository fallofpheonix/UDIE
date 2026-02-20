CREATE INDEX IF NOT EXISTS idx_geo_events_geom
  ON geo_events USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_geo_events_city_code
  ON geo_events (city_code);

CREATE INDEX IF NOT EXISTS idx_geo_events_start_time
  ON geo_events (start_time);

CREATE INDEX IF NOT EXISTS idx_geo_events_end_time
  ON geo_events (end_time);

CREATE UNIQUE INDEX IF NOT EXISTS idx_geo_events_dedupe_key
  ON geo_events (dedupe_key)
  WHERE dedupe_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_raw_events_status
  ON raw_events (status);

DROP VIEW IF EXISTS active_geo_events;
CREATE VIEW active_geo_events AS
SELECT *
FROM geo_events
WHERE end_time IS NULL OR end_time >= now();
