CREATE TABLE IF NOT EXISTS digital_twin_state_snapshots (
  snapshot_at TIMESTAMPTZ NOT NULL,
  cell_id BIGINT NOT NULL REFERENCES city_grid_cells(cell_id) ON DELETE CASCADE,
  region_id BIGINT NOT NULL,
  traffic_density DOUBLE PRECISION NOT NULL CHECK (traffic_density >= 0),
  average_speed DOUBLE PRECISION NOT NULL CHECK (average_speed >= 0),
  disruption_weight DOUBLE PRECISION NOT NULL CHECK (disruption_weight >= 0),
  risk_score DOUBLE PRECISION NOT NULL CHECK (risk_score >= 0 AND risk_score < 1),
  vehicle_count INT NOT NULL CHECK (vehicle_count >= 0),
  PRIMARY KEY (snapshot_at, cell_id)
);

CREATE INDEX IF NOT EXISTS idx_digital_twin_state_snapshots_cell_time
  ON digital_twin_state_snapshots (cell_id, snapshot_at DESC);

CREATE INDEX IF NOT EXISTS idx_digital_twin_state_snapshots_region_time
  ON digital_twin_state_snapshots (region_id, snapshot_at DESC);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'timescaledb') THEN
    BEGIN
      EXECUTE 'CREATE EXTENSION IF NOT EXISTS timescaledb';
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
      BEGIN
        EXECUTE $sql$
          SELECT create_hypertable(
            'digital_twin_state_snapshots',
            'snapshot_at',
            if_not_exists => TRUE,
            migrate_data => TRUE
          )
        $sql$;
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
    END IF;
  END IF;
END $$;

COMMENT ON TABLE digital_twin_state_snapshots IS 'Periodic persisted snapshots of digital twin states; promoted to Timescale hypertable when available.';
