-- Migration 018: Parameter Versioning
-- Introduces versioning for model parameters to ensure reproducibility.

ALTER TABLE model_parameters ADD COLUMN IF NOT EXISTS version INT DEFAULT 1;
ALTER TABLE model_parameters ADD COLUMN IF NOT EXISTS effective_from TIMESTAMPTZ DEFAULT now();

-- Create a history table for parameters
CREATE TABLE IF NOT EXISTS model_parameters_history (
    id SERIAL PRIMARY KEY,
    key TEXT NOT NULL,
    value DOUBLE PRECISION NOT NULL,
    version INT NOT NULL,
    effective_from TIMESTAMPTZ NOT NULL,
    archived_at TIMESTAMPTZ DEFAULT now()
);

-- Trigger to archive old parameters on update
CREATE OR REPLACE FUNCTION archive_model_parameter()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.value IS DISTINCT FROM NEW.value) THEN
        INSERT INTO model_parameters_history (key, value, version, effective_from)
        VALUES (OLD.key, OLD.value, OLD.version, OLD.effective_from);
        NEW.version := OLD.version + 1;
        NEW.effective_from := now();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_archive_model_parameter ON model_parameters;
CREATE TRIGGER tr_archive_model_parameter
BEFORE UPDATE ON model_parameters
FOR EACH ROW
EXECUTE FUNCTION archive_model_parameter();
