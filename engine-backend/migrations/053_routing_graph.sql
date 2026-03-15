CREATE TABLE IF NOT EXISTS road_graph_nodes (
  cell_id BIGINT PRIMARY KEY REFERENCES city_grid_cells(cell_id) ON DELETE CASCADE,
  city_id TEXT NOT NULL,
  region_id BIGINT NOT NULL,
  center_lat DOUBLE PRECISION NOT NULL,
  center_lng DOUBLE PRECISION NOT NULL,
  road_segments TEXT[] NOT NULL DEFAULT '{}'::text[],
  intersection_ids TEXT[] NOT NULL DEFAULT '{}'::text[],
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_road_graph_nodes_city_region
  ON road_graph_nodes (city_id, region_id);

CREATE TABLE IF NOT EXISTS road_graph_edges (
  source_cell_id BIGINT NOT NULL REFERENCES road_graph_nodes(cell_id) ON DELETE CASCADE,
  target_cell_id BIGINT NOT NULL REFERENCES road_graph_nodes(cell_id) ON DELETE CASCADE,
  city_id TEXT NOT NULL,
  region_id BIGINT NOT NULL,
  length_meters DOUBLE PRECISION NOT NULL CHECK (length_meters > 0),
  lanes INT NOT NULL DEFAULT 1 CHECK (lanes > 0),
  speed_limit DOUBLE PRECISION NOT NULL DEFAULT 40 CHECK (speed_limit > 0),
  road_type TEXT NOT NULL DEFAULT 'URBAN',
  geometry geometry(LineString, 4326),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (source_cell_id, target_cell_id)
);

CREATE INDEX IF NOT EXISTS idx_road_graph_edges_region
  ON road_graph_edges (region_id, source_cell_id);

CREATE INDEX IF NOT EXISTS idx_road_graph_edges_target
  ON road_graph_edges (target_cell_id);

CREATE INDEX IF NOT EXISTS idx_road_graph_edges_geometry
  ON road_graph_edges USING GIST (geometry);

CREATE TABLE IF NOT EXISTS routing_edge_weights (
  source_cell_id BIGINT NOT NULL,
  target_cell_id BIGINT NOT NULL,
  city_id TEXT NOT NULL,
  region_id BIGINT NOT NULL,
  distance_meters DOUBLE PRECISION NOT NULL CHECK (distance_meters > 0),
  base_travel_time_sec DOUBLE PRECISION NOT NULL CHECK (base_travel_time_sec > 0),
  current_speed_kmh DOUBLE PRECISION NOT NULL CHECK (current_speed_kmh > 0),
  traffic_density DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (traffic_density >= 0),
  disruption_weight DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (disruption_weight >= 0),
  risk_score DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (risk_score >= 0 AND risk_score < 1),
  road_capacity DOUBLE PRECISION NOT NULL DEFAULT 1 CHECK (road_capacity > 0),
  lanes INT NOT NULL DEFAULT 1 CHECK (lanes > 0),
  speed_limit DOUBLE PRECISION NOT NULL DEFAULT 40 CHECK (speed_limit > 0),
  road_type TEXT NOT NULL DEFAULT 'URBAN',
  dominant_hazard TEXT,
  hazard_count INT NOT NULL DEFAULT 0 CHECK (hazard_count >= 0),
  edge_cost DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (edge_cost >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (source_cell_id, target_cell_id),
  CONSTRAINT fk_routing_edge_weights_graph_edge
    FOREIGN KEY (source_cell_id, target_cell_id)
    REFERENCES road_graph_edges(source_cell_id, target_cell_id)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_routing_edge_weights_region
  ON routing_edge_weights (region_id, source_cell_id);

CREATE INDEX IF NOT EXISTS idx_routing_edge_weights_cost
  ON routing_edge_weights (edge_cost);

CREATE TABLE IF NOT EXISTS historical_traffic_edges (
  source_cell_id BIGINT NOT NULL,
  target_cell_id BIGINT NOT NULL,
  day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  hour_of_day SMALLINT NOT NULL CHECK (hour_of_day BETWEEN 0 AND 23),
  avg_speed_kmh DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (avg_speed_kmh >= 0),
  congestion_frequency DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (congestion_frequency >= 0),
  incident_frequency DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (incident_frequency >= 0),
  sample_count INT NOT NULL DEFAULT 0 CHECK (sample_count >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (source_cell_id, target_cell_id, day_of_week, hour_of_day),
  CONSTRAINT fk_historical_traffic_edges_graph_edge
    FOREIGN KEY (source_cell_id, target_cell_id)
    REFERENCES road_graph_edges(source_cell_id, target_cell_id)
    ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS route_cache_entries (
  cache_key TEXT PRIMARY KEY,
  payload JSONB NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_route_cache_entries_expires
  ON route_cache_entries (expires_at);

COMMENT ON TABLE road_graph_nodes IS 'Routing graph nodes derived from H3 city grid cells.';
COMMENT ON TABLE road_graph_edges IS 'Directional routing graph edges derived from neighboring H3 grid cells.';
COMMENT ON TABLE routing_edge_weights IS 'Precomputed edge weights for low-latency routing over the road graph.';
COMMENT ON TABLE historical_traffic_edges IS 'Historical edge traffic profiles keyed by weekday/hour for ETA adjustment.';
