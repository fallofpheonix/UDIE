CREATE TABLE IF NOT EXISTS risk_snapshots (
  snapshot_time TIMESTAMPTZ NOT NULL,
  h3_index BIGINT NOT NULL,
  risk_weight DOUBLE PRECISION NOT NULL,
  PRIMARY KEY (snapshot_time, h3_index)
);

CREATE INDEX IF NOT EXISTS idx_risk_snapshots_h3_time
  ON risk_snapshots (h3_index, snapshot_time DESC);

CREATE INDEX IF NOT EXISTS idx_risk_snapshots_time
  ON risk_snapshots (snapshot_time DESC);
