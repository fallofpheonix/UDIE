-- Migration 029: Qualitative Intelligence & Source Credibility
-- Adds source weighting and event correlation weights.

-- 1. Source Types & Weights
-- Law: Official sensors have 2x weight over social reports.
CREATE TABLE source_definitions (
    source_type text PRIMARY KEY,
    base_weight double precision DEFAULT 1.0,
    is_official boolean DEFAULT false
);

INSERT INTO source_definitions (source_type, base_weight, is_official) VALUES
('IOT_SENSOR', 1.0, true),
('TRAFFIC_CAMERA', 0.9, true),
('MUNICIPAL_FEED', 0.85, true),
('USER_REPORT', 0.6, false),
('SOCIAL_MEDIA', 0.4, false);

-- 2. Update Events Log Schema (Metadata only for now)
ALTER TABLE regional_events_log ADD COLUMN IF NOT EXISTS source_type text REFERENCES source_definitions(source_type);
ALTER TABLE regional_events_log ADD COLUMN IF NOT EXISTS reliability_score double precision DEFAULT 1.0;

-- 3. Event Correlation Weights
CREATE TABLE event_correlations (
    cause_type text,
    effect_type text,
    correlation_weight double precision,
    PRIMARY KEY (cause_type, effect_type)
);

INSERT INTO event_correlations (cause_type, effect_type, correlation_weight) VALUES
('CONSTRUCTION', 'TRAFFIC', 0.7),
('ACCIDENT', 'TRAFFIC', 0.8),
('WEATHER_STORM', 'FLOOD', 0.6);
