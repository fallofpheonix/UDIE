-- Migration 030: Event Identity & Disruption Registry
-- Enables tracking persistent incidents over time.

CREATE TABLE disruption_identities (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type text NOT NULL,
    h3_index bigint NOT NULL,
    h3_parent bigint NOT NULL,
    first_observed_at timestamp with time zone DEFAULT now(),
    last_observed_at timestamp with time zone DEFAULT now(),
    cumulative_severity double precision DEFAULT 0,
    observation_count int DEFAULT 1,
    is_active boolean DEFAULT true,
    metadata jsonb DEFAULT '{}'
) PARTITION BY LIST (h3_parent);

-- Index for spatial-temporal matching
CREATE INDEX idx_identities_matching ON disruption_identities (h3_index, event_type, is_active);

-- Link table: Many Logs -> One Identity
CREATE TABLE log_to_identity_map (
    log_id uuid,
    h3_parent bigint,
    identity_id uuid NOT NULL,
    PRIMARY KEY (log_id, h3_parent)
);
