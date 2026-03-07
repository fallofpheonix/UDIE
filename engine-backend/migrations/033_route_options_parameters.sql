INSERT INTO model_parameters (key, value, description)
VALUES
  ('ROUTE_UTILITY_TIME_WEIGHT', 1.0, 'Utility weight multiplier for travel time in minutes'),
  ('ROUTE_UTILITY_RISK_WEIGHT', 30.0, 'Utility weight multiplier for route risk score'),
  ('ASSUMED_SPEED_KMH', 32.0, 'Assumed urban speed for ETA estimation when no router is configured')
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = now();
