-- Migration 044: Road Network Graph
-- Implements Prompts 1-4 (Road Network Model, OSM Ingestion, Graph Partitioning, Storage Engine)

-- Road nodes: intersections in the road network
CREATE TABLE IF NOT EXISTS road_nodes (
  id              BIGINT PRIMARY KEY,
  osm_id          BIGINT,
  geom            GEOGRAPHY(POINT, 4326) NOT NULL,
  h3_index        TEXT NOT NULL,
  h3_partition    TEXT NOT NULL,
  node_type       TEXT NOT NULL DEFAULT 'intersection',
  is_highway      BOOLEAN NOT NULL DEFAULT FALSE,
  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS road_nodes_geom_idx        ON road_nodes USING GIST (geom);
CREATE INDEX IF NOT EXISTS road_nodes_h3_idx          ON road_nodes (h3_index);
CREATE INDEX IF NOT EXISTS road_nodes_h3_partition_idx ON road_nodes (h3_partition);
CREATE INDEX IF NOT EXISTS road_nodes_highway_idx     ON road_nodes (is_highway) WHERE is_highway = TRUE;
CREATE INDEX IF NOT EXISTS road_nodes_osm_id_idx      ON road_nodes (osm_id) WHERE osm_id IS NOT NULL;

-- Road edges: directed road segments
CREATE TABLE IF NOT EXISTS road_edges (
  id                   BIGINT PRIMARY KEY,
  osm_id               BIGINT,
  source_node          BIGINT NOT NULL REFERENCES road_nodes(id),
  target_node          BIGINT NOT NULL REFERENCES road_nodes(id),
  length_m             DOUBLE PRECISION NOT NULL CHECK (length_m > 0),
  lanes                INT NOT NULL DEFAULT 1 CHECK (lanes >= 1),
  speed_limit_kmh      INT NOT NULL DEFAULT 50 CHECK (speed_limit_kmh > 0),
  road_type            TEXT NOT NULL DEFAULT 'residential',
  is_one_way           BOOLEAN NOT NULL DEFAULT FALSE,
  is_highway           BOOLEAN NOT NULL DEFAULT FALSE,
  geom                 GEOGRAPHY(LINESTRING, 4326) NOT NULL,
  -- Pre-computed cost components (updated by background materialization worker)
  base_travel_time_s   DOUBLE PRECISION NOT NULL DEFAULT 0,
  current_speed_kmh    DOUBLE PRECISION,
  vehicle_density      DOUBLE PRECISION NOT NULL DEFAULT 0,
  disruption_weight    DOUBLE PRECISION NOT NULL DEFAULT 1.0 CHECK (disruption_weight >= 0),
  risk_score           DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (risk_score >= 0 AND risk_score <= 1),
  effective_weight     DOUBLE PRECISION NOT NULL DEFAULT 1.0 CHECK (effective_weight >= 0),
  h3_partition         TEXT NOT NULL,
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS road_edges_source_idx        ON road_edges (source_node);
CREATE INDEX IF NOT EXISTS road_edges_target_idx        ON road_edges (target_node);
CREATE INDEX IF NOT EXISTS road_edges_geom_idx          ON road_edges USING GIST (geom);
CREATE INDEX IF NOT EXISTS road_edges_h3_partition_idx  ON road_edges (h3_partition);
CREATE INDEX IF NOT EXISTS road_edges_highway_idx       ON road_edges (is_highway) WHERE is_highway = TRUE;
CREATE INDEX IF NOT EXISTS road_edges_weight_idx        ON road_edges (effective_weight);
-- Adjacency list lookup: given a node, find all outgoing edges
CREATE INDEX IF NOT EXISTS road_edges_adj_idx           ON road_edges (source_node, effective_weight);

-- H3-based road network partitions for distributed routing
CREATE TABLE IF NOT EXISTS road_partitions (
  h3_index       TEXT PRIMARY KEY,
  h3_resolution  INT NOT NULL DEFAULT 4,
  node_count     INT NOT NULL DEFAULT 0,
  edge_count     INT NOT NULL DEFAULT 0,
  avg_risk_score DOUBLE PRECISION NOT NULL DEFAULT 0,
  traffic_state  JSONB NOT NULL DEFAULT '{}',
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Historical traffic patterns by time slot (Prompt 16)
CREATE TABLE IF NOT EXISTS historical_traffic (
  id                    BIGSERIAL PRIMARY KEY,
  edge_id               BIGINT NOT NULL REFERENCES road_edges(id) ON DELETE CASCADE,
  hour_of_day           INT NOT NULL CHECK (hour_of_day BETWEEN 0 AND 23),
  day_of_week           INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  avg_speed_kmh         DOUBLE PRECISION NOT NULL CHECK (avg_speed_kmh >= 0),
  congestion_frequency  DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (congestion_frequency BETWEEN 0 AND 1),
  incident_count        INT NOT NULL DEFAULT 0,
  sample_count          INT NOT NULL DEFAULT 1 CHECK (sample_count >= 1),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (edge_id, hour_of_day, day_of_week)
);

CREATE INDEX IF NOT EXISTS historical_traffic_edge_idx  ON historical_traffic (edge_id);
CREATE INDEX IF NOT EXISTS historical_traffic_slot_idx  ON historical_traffic (hour_of_day, day_of_week);

-- Vehicle telemetry stream (Prompt 25)
CREATE TABLE IF NOT EXISTS vehicle_telemetry (
  id           BIGSERIAL PRIMARY KEY,
  vehicle_id   TEXT NOT NULL,
  lat          DOUBLE PRECISION NOT NULL CHECK (lat BETWEEN -90 AND 90),
  lng          DOUBLE PRECISION NOT NULL CHECK (lng BETWEEN -180 AND 180),
  speed_kmh    DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (speed_kmh >= 0),
  heading      DOUBLE PRECISION CHECK (heading >= 0 AND heading < 360),
  edge_id      BIGINT REFERENCES road_edges(id),
  h3_index     TEXT NOT NULL,
  recorded_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS vehicle_telemetry_vehicle_idx  ON vehicle_telemetry (vehicle_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS vehicle_telemetry_h3_idx       ON vehicle_telemetry (h3_index, recorded_at DESC);
CREATE INDEX IF NOT EXISTS vehicle_telemetry_edge_idx     ON vehicle_telemetry (edge_id, recorded_at DESC) WHERE edge_id IS NOT NULL;
-- Retain only last 24 hours of raw telemetry
CREATE INDEX IF NOT EXISTS vehicle_telemetry_recorded_idx ON vehicle_telemetry (recorded_at);

-- Traffic incidents detected from telemetry (Prompt 26)
CREATE TABLE IF NOT EXISTS traffic_incidents (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_type  TEXT NOT NULL,
  severity       DOUBLE PRECISION NOT NULL CHECK (severity BETWEEN 0 AND 1),
  edge_id        BIGINT REFERENCES road_edges(id),
  h3_index       TEXT NOT NULL,
  geom           GEOGRAPHY(POINT, 4326) NOT NULL,
  detected_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at    TIMESTAMPTZ,
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  metadata       JSONB NOT NULL DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS traffic_incidents_h3_idx     ON traffic_incidents (h3_index) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS traffic_incidents_edge_idx   ON traffic_incidents (edge_id) WHERE edge_id IS NOT NULL AND is_active = TRUE;
CREATE INDEX IF NOT EXISTS traffic_incidents_active_idx ON traffic_incidents (detected_at) WHERE is_active = TRUE;

-- Road hazard predictions (Prompt 27)
CREATE TABLE IF NOT EXISTS road_hazards (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hazard_type   TEXT NOT NULL,
  probability   DOUBLE PRECISION NOT NULL CHECK (probability BETWEEN 0 AND 1),
  h3_index      TEXT NOT NULL,
  geom          GEOGRAPHY(POINT, 4326) NOT NULL,
  source        TEXT NOT NULL DEFAULT 'historical',
  valid_from    TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_until   TIMESTAMPTZ,
  metadata      JSONB NOT NULL DEFAULT '{}',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS road_hazards_h3_idx      ON road_hazards (h3_index);
CREATE INDEX IF NOT EXISTS road_hazards_active_idx  ON road_hazards (valid_from, valid_until) WHERE valid_until IS NULL OR valid_until > now();

-- Route cache for popular origin/destination pairs (Prompt 21)
CREATE TABLE IF NOT EXISTS route_cache (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  origin_h3       TEXT NOT NULL,
  destination_h3  TEXT NOT NULL,
  time_of_day     INT NOT NULL CHECK (time_of_day BETWEEN 0 AND 23),
  route_data      JSONB NOT NULL,
  hit_count       INT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at      TIMESTAMPTZ NOT NULL,
  UNIQUE (origin_h3, destination_h3, time_of_day)
);

CREATE INDEX IF NOT EXISTS route_cache_key_idx     ON route_cache (origin_h3, destination_h3, time_of_day);
CREATE INDEX IF NOT EXISTS route_cache_expiry_idx  ON route_cache (expires_at);

-- OSM ingestion log
CREATE TABLE IF NOT EXISTS osm_ingestion_log (
  id            BIGSERIAL PRIMARY KEY,
  region_code   TEXT NOT NULL,
  source_url    TEXT,
  nodes_loaded  INT NOT NULL DEFAULT 0,
  edges_loaded  INT NOT NULL DEFAULT 0,
  status        TEXT NOT NULL DEFAULT 'PENDING',
  started_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at  TIMESTAMPTZ,
  error_message TEXT
);
