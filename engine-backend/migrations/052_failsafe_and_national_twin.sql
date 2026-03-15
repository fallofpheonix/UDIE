CREATE TABLE IF NOT EXISTS traffic_signal_fail_safe_profiles (
  intersection_id TEXT PRIMARY KEY,
  schedule_name TEXT NOT NULL,
  action TEXT NOT NULL,
  phase_duration_seconds INT NOT NULL DEFAULT 45,
  min_phase_seconds INT NOT NULL DEFAULT 20,
  max_phase_seconds INT NOT NULL DEFAULT 60,
  manual_override_enabled BOOLEAN NOT NULL DEFAULT true,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO traffic_signal_fail_safe_profiles (
  intersection_id,
  schedule_name,
  action,
  phase_duration_seconds,
  min_phase_seconds,
  max_phase_seconds,
  manual_override_enabled
)
VALUES ('*', 'default_safe_cycle', 'hold_phase', 45, 20, 60, true)
ON CONFLICT (intersection_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS traffic_signal_control_modes (
  intersection_id TEXT PRIMARY KEY,
  city_id TEXT,
  mode TEXT NOT NULL,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  activated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS national_region_registry (
  region_id BIGINT PRIMARY KEY,
  region_name TEXT NOT NULL,
  cluster_endpoint TEXT NOT NULL,
  city_id TEXT,
  min_lat DOUBLE PRECISION NOT NULL,
  min_lng DOUBLE PRECISION NOT NULL,
  max_lat DOUBLE PRECISION NOT NULL,
  max_lng DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_traffic_signal_control_modes_city
  ON traffic_signal_control_modes (city_id, activated_at DESC);

CREATE INDEX IF NOT EXISTS idx_national_region_registry_updated
  ON national_region_registry (updated_at DESC);

COMMENT ON TABLE traffic_signal_fail_safe_profiles IS 'Predefined signal schedules used when AI control fails.';
COMMENT ON TABLE traffic_signal_control_modes IS 'Current control mode per intersection: AI, predefined schedule, or manual.';
COMMENT ON TABLE national_region_registry IS 'Regional compute-cluster registry for nationwide H3 res6 transportation digital twin shards.';
