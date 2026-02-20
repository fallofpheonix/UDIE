-- Phase 0: Ingestion Metrics Tracking
-- Records every ingestion attempt to derive production requirements (arrival/dupe rates).

CREATE TABLE IF NOT EXISTS ingestion_metrics (
  id BIGSERIAL PRIMARY KEY,
  observed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  source_id TEXT,
  event_type TEXT,
  op_type TEXT, -- INSERT or UPDATE
  latency_ms FLOAT,
  city_code TEXT
);

-- Index for temporal analytics
CREATE INDEX IF NOT EXISTS idx_ingestion_metrics_time ON ingestion_metrics(observed_at);
