-- Migration 028: Disruption Forecasting
-- Stores historical probability density for disruption events.

CREATE TABLE IF NOT EXISTS regional_disruption_forecasts (
    h3_index bigint NOT NULL,
    h3_parent bigint NOT NULL,
    day_of_week int NOT NULL, -- 0-6
    hour_of_day int NOT NULL, -- 0-23
    probability double precision DEFAULT 0,
    observation_count int DEFAULT 0,
    last_updated_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (h3_index, day_of_week, hour_of_day, h3_parent)
) PARTITION BY LIST (h3_parent);

COMMENT ON TABLE regional_disruption_forecasts IS 'Spatial-temporal risk baseline derived from history';

-- Index for fast lookup by time
CREATE INDEX IF NOT EXISTS idx_forecast_temporal ON regional_disruption_forecasts (day_of_week, hour_of_day);
