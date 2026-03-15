CREATE TABLE IF NOT EXISTS intersection_graph_edges (
  source_intersection_id TEXT NOT NULL,
  target_intersection_id TEXT NOT NULL,
  city_id TEXT NOT NULL,
  region_id BIGINT NOT NULL,
  capacity DOUBLE PRECISION NOT NULL,
  length_meters DOUBLE PRECISION NOT NULL,
  speed_limit DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (source_intersection_id, target_intersection_id)
);

CREATE TABLE IF NOT EXISTS intersection_state_estimates (
  intersection_id TEXT PRIMARY KEY,
  city_id TEXT NOT NULL,
  region_id BIGINT NOT NULL,
  queue_length DOUBLE PRECISION NOT NULL,
  vehicle_count DOUBLE PRECISION NOT NULL,
  arrival_rate DOUBLE PRECISION NOT NULL,
  average_speed DOUBLE PRECISION NOT NULL,
  congestion_index DOUBLE PRECISION NOT NULL,
  estimated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS traffic_sensor_stream_events (
  id BIGSERIAL PRIMARY KEY,
  topic TEXT NOT NULL,
  partition_id INT NOT NULL DEFAULT 0,
  source_type TEXT NOT NULL,
  city_id TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  payload JSONB NOT NULL,
  observed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS traffic_signal_control_commands (
  id BIGSERIAL PRIMARY KEY,
  intersection_id TEXT NOT NULL,
  city_id TEXT,
  command_action TEXT NOT NULL,
  payload JSONB NOT NULL,
  dispatched_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_intersection_graph_edges_city
  ON intersection_graph_edges (city_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_intersection_state_estimates_city
  ON intersection_state_estimates (city_id, estimated_at DESC);

CREATE INDEX IF NOT EXISTS idx_traffic_sensor_stream_events_topic
  ON traffic_sensor_stream_events (topic, observed_at DESC);

CREATE INDEX IF NOT EXISTS idx_traffic_signal_control_commands_intersection
  ON traffic_signal_control_commands (intersection_id, dispatched_at DESC);

COMMENT ON TABLE intersection_graph_edges IS 'Intersection-level directed graph derived from road segments and H3 cell adjacency.';
COMMENT ON TABLE intersection_state_estimates IS 'Rolling per-intersection traffic state estimates derived from recent sensor streams.';
COMMENT ON TABLE traffic_sensor_stream_events IS 'Kafka-style sensor stream ledger for loop, camera, telemetry, and GPS ingestion.';
COMMENT ON TABLE traffic_signal_control_commands IS 'Dispatched real-time signal timing commands emitted by the coordination engine.';
