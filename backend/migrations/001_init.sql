CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_type_enum') THEN
    CREATE TYPE event_type_enum AS ENUM (
      'ACCIDENT',
      'CONSTRUCTION',
      'METRO_WORK',
      'WATER_LOGGING',
      'PROTEST',
      'HEAVY_TRAFFIC',
      'ROAD_BLOCK'
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'source_type_enum') THEN
    CREATE TYPE source_type_enum AS ENUM (
      'TWITTER',
      'NEWS',
      'GOV_PORTAL',
      'ADMIN',
      'CROWD'
    );
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS geo_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type event_type_enum NOT NULL,
  severity INT NOT NULL CHECK (severity BETWEEN 1 AND 5),
  confidence DOUBLE PRECISION NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
  source source_type_enum NOT NULL,
  description TEXT,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  geom GEOGRAPHY(POINT, 4326) NOT NULL,
  city_code TEXT NOT NULL,
  source_ref TEXT,
  dedupe_key TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (end_time IS NULL OR end_time >= start_time)
);

CREATE TABLE IF NOT EXISTS raw_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source source_type_enum NOT NULL,
  source_ref TEXT,
  payload JSONB NOT NULL,
  ingested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'PENDING',
  error_message TEXT
);
