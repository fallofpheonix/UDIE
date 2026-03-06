-- Migration 032: Disruption Time-Lapse Visualization
-- Stores periodic snapshots of the risk surface for animated playback.

CREATE TABLE IF NOT EXISTS risk_snapshots (
  snapshot_time TIMESTAMPTZ NOT NULL,
  h3_index BIGINT NOT NULL,
  risk_weight DOUBLE PRECISION NOT NULL,
  PRIMARY KEY (snapshot_time, h3_index)
);

-- BRIN index for fast temporal range queries (efficient for append-only temporal data)
CREATE INDEX idx_risk_snapshots_time_brin ON risk_snapshots USING brin(snapshot_time);

-- Spatial index for regional filtering
CREATE INDEX idx_risk_snapshots_h3 ON risk_snapshots (h3_index);

COMMENT ON TABLE risk_snapshots IS 'Temporal state snapshots for disruption playback and historical analysis.';
