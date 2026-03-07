-- Migration 040: Expand Forecast Horizons
-- Adds a 15-minute forecast horizon to the urban intelligence layer.

ALTER TABLE forecast_cells 
ADD COLUMN IF NOT EXISTS forecast_15m DOUBLE PRECISION NOT NULL DEFAULT 0.0;

COMMENT ON COLUMN forecast_cells.forecast_15m IS 'Short-term predictive risk for T+15m horizon.';
