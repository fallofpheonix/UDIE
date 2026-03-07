-- Phase G1. Parameterization Layer (Step 19-20)
-- Stores scoring constants in DB to prevent "hardcoded behavior" (Atomic Law 4).

CREATE TABLE IF NOT EXISTS model_parameters (
  key TEXT PRIMARY KEY,
  value DOUBLE PRECISION NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Initial Calibration (v2)
INSERT INTO model_parameters (key, value, description) VALUES
('SIGMOID_K', 20.0, 'Normalization constant for 1 - exp(-raw/k)'),
('DECAY_LAMBDA', 250.0, 'Distance decay rate in meters'),
('MAX_RADIUS', 500.0, 'Maximum spatial influence of an event in meters'),
('CONFIDENCE_DECAY_RATE', 0.97, 'Confidence multiplier per 15m maintenance cycle'),
('EXPIRY_CONVERSION_THRESHOLD', 0.25, 'Confidence level at which an active event is expired')
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = now();
