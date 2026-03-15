CREATE TABLE IF NOT EXISTS traffic_signal_states (
  intersection_id TEXT PRIMARY KEY,
  city_id TEXT NOT NULL,
  region_id BIGINT NOT NULL,
  controlled_cells BIGINT[] NOT NULL DEFAULT ARRAY[]::BIGINT[],
  controlled_cell_count INT NOT NULL DEFAULT 1,
  signal_phase TEXT NOT NULL DEFAULT 'NS_GREEN',
  phase_elapsed_seconds INT NOT NULL DEFAULT 0,
  phase_duration_seconds INT NOT NULL DEFAULT 30,
  min_phase_seconds INT NOT NULL DEFAULT 15,
  max_phase_seconds INT NOT NULL DEFAULT 90,
  yellow_seconds INT NOT NULL DEFAULT 3,
  queue_length DOUBLE PRECISION NOT NULL DEFAULT 0,
  avg_wait_seconds DOUBLE PRECISION NOT NULL DEFAULT 0,
  throughput_vehicles DOUBLE PRECISION NOT NULL DEFAULT 0,
  incoming_vehicle_count DOUBLE PRECISION NOT NULL DEFAULT 0,
  avg_speed DOUBLE PRECISION NOT NULL DEFAULT 0,
  nearby_congestion_index DOUBLE PRECISION NOT NULL DEFAULT 0,
  saturation_flow DOUBLE PRECISION NOT NULL DEFAULT 30,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_traffic_signal_states_city_updated
  ON traffic_signal_states (city_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS traffic_signal_episode_steps (
  episode_id TEXT NOT NULL,
  step_index INT NOT NULL,
  intersection_id TEXT NOT NULL REFERENCES traffic_signal_states(intersection_id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  reward DOUBLE PRECISION NOT NULL,
  state JSONB NOT NULL,
  next_state JSONB NOT NULL,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (episode_id, step_index, intersection_id)
);

CREATE INDEX IF NOT EXISTS idx_traffic_signal_episode_steps_created
  ON traffic_signal_episode_steps (created_at DESC);

COMMENT ON TABLE traffic_signal_states IS 'Traffic intersection control state used by the deterministic RL training environment.';
COMMENT ON TABLE traffic_signal_episode_steps IS 'Per-step transitions, actions, and rewards for traffic signal agent training/evaluation.';
