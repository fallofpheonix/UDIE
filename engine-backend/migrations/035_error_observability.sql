-- Migration 035: Error Observability Layer
-- Implements structured failure tracking and reliability modeling.

CREATE TABLE IF NOT EXISTS system_errors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    service TEXT NOT NULL,
    component TEXT NOT NULL,
    error_type TEXT NOT NULL,
    error_message TEXT,
    stack_hash TEXT UNIQUE, -- Fingerprint for deduplication
    severity INTEGER CHECK (severity BETWEEN 1 AND 5),
    probable_cause TEXT,
    occurrence_count INTEGER DEFAULT 1,
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_system_errors_timestamp ON system_errors (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_system_errors_service ON system_errors (service, error_type);

COMMENT ON TABLE system_errors IS 'Structured log of system failures used for reliability scoring and automated diagnostics.';
