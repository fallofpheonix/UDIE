-- Migration 045: Road Network Model Parameters
-- Default parameters for routing cost model, traffic thresholds, and ETA computation

INSERT INTO model_parameters (key, value, description) VALUES
('ROUTING_TIME_WEIGHT',         1.0,  'Weight for travel time in multi-criteria cost function'),
('ROUTING_DISTANCE_WEIGHT',     0.5,  'Weight for distance in multi-criteria cost function'),
('ROUTING_RISK_WEIGHT',         2.0,  'Weight for risk score in multi-criteria cost function'),
('ROUTING_MAX_CANDIDATES',      5.0,  'Maximum candidate routes to generate (k-shortest paths)'),
('ROUTING_HIGHWAY_SPEED_KMH',   100.0,'Assumed speed on highway segments (km/h)'),
('ROUTING_URBAN_SPEED_KMH',     40.0, 'Assumed speed in urban areas (km/h)'),
('TRAFFIC_CONGESTION_THRESHOLD',0.7,  'Vehicle density above which edge is considered congested'),
('TRAFFIC_SPEED_DROP_THRESHOLD',0.4,  'Speed ratio below which edge is penalized for congestion'),
('TRAFFIC_UPDATE_INTERVAL_S',   10.0, 'Background traffic weight update interval in seconds'),
('INCIDENT_BRAKING_THRESHOLD',  15.0, 'Sudden speed drop (km/h) to flag braking event'),
('INCIDENT_CLUSTER_RADIUS_M',   200.0,'Radius in meters for clustering telemetry incidents'),
('ETA_HISTORICAL_WEIGHT',       0.4,  'Weight of historical delay patterns in ETA'),
('ETA_LIVE_WEIGHT',             0.6,  'Weight of live traffic conditions in ETA'),
('HAZARD_PREDICTION_HORIZON_H', 24.0, 'Hours ahead for road hazard prediction'),
('GRAPH_PARTITION_RESOLUTION',  4.0,  'H3 resolution level for graph partitioning'),
('ROUTE_CACHE_TTL_MIN',         15.0, 'Route cache TTL in minutes'),
('TELEMETRY_RETENTION_H',       24.0, 'Hours to retain raw telemetry data')
ON CONFLICT (key) DO UPDATE SET
  value       = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at  = now();
