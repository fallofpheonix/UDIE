-- STEP 12: Introduce an Append-Only History Table
CREATE TABLE IF NOT EXISTS event_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL,
  observed_at TIMESTAMPTZ NOT NULL,
  confidence DOUBLE PRECISION NOT NULL,
  severity INT NOT NULL,
  geom GEOGRAPHY(POINT, 4326) NOT NULL,
  snapshot_at TIMESTAMPTZ DEFAULT now()
);

-- Trigger to automatically record history on every update to geo_events
CREATE OR REPLACE FUNCTION record_event_history()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO event_history (event_id, observed_at, confidence, severity, geom)
  VALUES (NEW.id, NEW.observed_at, NEW.confidence, NEW.severity, NEW.geom);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_record_event_history ON geo_events;
CREATE TRIGGER trg_record_event_history
AFTER INSERT OR UPDATE ON geo_events
FOR EACH ROW EXECUTE FUNCTION record_event_history();

-- STEP 11: Add Confidence Decay (Events Must Fade If Not Reobserved)
-- This logic should ideally be triggered by a cron job (pg_cron or external)
-- Every hour: reduce confidence by 2%, expire if below 0.2
CREATE OR REPLACE FUNCTION run_confidence_decay()
RETURNS VOID AS $$
BEGIN
  -- Decay confidence for all active events
  UPDATE geo_events
  SET 
    confidence = confidence * 0.98,
    updated_at = now()
  WHERE status = 'ACTIVE';

  -- Automatically expire events with low confidence
  UPDATE geo_events
  SET 
    status = 'EXPIRED',
    updated_at = now()
  WHERE status = 'ACTIVE' AND confidence < 0.2;
END;
$$ LANGUAGE plpgsql;
