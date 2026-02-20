-- Execution hardening migration.
-- Enforces append-only ingestion log, restart-safe job state, DB-owned constants,
-- and deterministic rebuild semantics for derived state.

CREATE TABLE IF NOT EXISTS events_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  log_type TEXT NOT NULL CHECK (log_type IN ('INGESTED', 'PROCESSED', 'FAILED')),
  source source_type_enum NOT NULL,
  source_ref TEXT,
  parent_log_id UUID REFERENCES events_log(id) ON DELETE SET NULL,
  idempotency_key TEXT,
  payload JSONB NOT NULL,
  error_message TEXT,
  ingested_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_events_log_ingested_idempotency
ON events_log(idempotency_key)
WHERE log_type = 'INGESTED' AND idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_events_log_ingested_at
ON events_log(ingested_at DESC);

CREATE INDEX IF NOT EXISTS idx_events_log_type_time
ON events_log(log_type, ingested_at DESC);

-- Backfill from legacy raw_events table when present.
INSERT INTO events_log (log_type, source, source_ref, payload, error_message, ingested_at)
SELECT
  CASE
    WHEN status = 'PROCESSED' THEN 'PROCESSED'
    WHEN status = 'FAILED' THEN 'FAILED'
    ELSE 'INGESTED'
  END,
  source,
  source_ref,
  payload,
  error_message,
  ingested_at
FROM raw_events r
WHERE NOT EXISTS (
  SELECT 1
  FROM events_log e
  WHERE e.source_ref = r.source_ref
    AND e.payload = r.payload
    AND e.ingested_at = r.ingested_at
);

CREATE TABLE IF NOT EXISTS system_state (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION set_system_state(p_key TEXT, p_value JSONB)
RETURNS VOID AS $$
BEGIN
  INSERT INTO system_state(key, value, updated_at)
  VALUES (p_key, p_value, now())
  ON CONFLICT (key)
  DO UPDATE SET value = EXCLUDED.value, updated_at = EXCLUDED.updated_at;
END;
$$ LANGUAGE plpgsql;

-- Ensure runtime constants are DB-owned.
INSERT INTO model_parameters (key, value, description) VALUES
('MAX_ROUTE_VERTICES', 1000.0, 'Maximum vertices accepted by /risk route payload'),
('MAX_ROUTE_DISTANCE_KM', 50.0, 'Maximum route distance accepted by /risk'),
('MATERIALIZATION_STALE_SECONDS', 300.0, 'Max age allowed for risk surface freshness in health checks')
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = now();

-- Deterministic rebuild: derive geo_events and risk_cells from append-only INGESTED log.
CREATE OR REPLACE FUNCTION rebuild_derived_state_from_log()
RETURNS VOID AS $$
DECLARE
  rec RECORD;
BEGIN
  TRUNCATE TABLE geo_events RESTART IDENTITY CASCADE;
  TRUNCATE TABLE risk_cells;

  FOR rec IN
    SELECT source, payload
    FROM events_log
    WHERE log_type = 'INGESTED'
    ORDER BY ingested_at ASC, id ASC
  LOOP
    PERFORM * FROM upsert_geo_event_v2(
      (rec.payload->>'event_type')::event_type_enum,
      COALESCE((rec.payload->>'severity_hint')::INT, 1),
      0.7,
      ST_SetSRID(
        ST_MakePoint(
          (rec.payload->>'lng')::DOUBLE PRECISION,
          (rec.payload->>'lat')::DOUBLE PRECISION
        ),
        4326
      )::geography,
      COALESCE(rec.payload->>'city_code', 'DEL'),
      COALESCE(rec.payload->>'source_id', 'UNKNOWN'),
      rec.payload->>'text',
      rec.source
    );
  END LOOP;

  PERFORM run_lifecycle_maintenance();
  PERFORM refresh_risk_surface();
END;
$$ LANGUAGE plpgsql;
