-- Migration: 037_sandbox_isolation.sql
-- Implements Physical Simulation Isolation (Phase 14)

-- 1. Create Simulation Events Log
CREATE TABLE IF NOT EXISTS simulation_events (
    LIKE geo_events INCLUDING ALL
);

-- 2. Create Simulation Risk Grid
CREATE TABLE IF NOT EXISTS simulation_risk_cells (
    LIKE risk_cells INCLUDING ALL
);

-- 3. Add explicit check to prevent manual cross-contamination
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_enum e ON e.enumtypid = t.oid
        WHERE t.typname = 'event_status_enum'
          AND e.enumlabel = 'SIMULATION'
    ) AND NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'check_not_simulation'
    ) THEN
        ALTER TABLE geo_events ADD CONSTRAINT check_not_simulation CHECK (status != 'SIMULATION');
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_enum e ON e.enumtypid = t.oid
        WHERE t.typname = 'event_status_enum'
          AND e.enumlabel = 'SIMULATION'
    ) AND NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'check_is_simulation'
    ) THEN
        ALTER TABLE simulation_events ADD CONSTRAINT check_is_simulation CHECK (status = 'SIMULATION');
    END IF;
END $$;

-- 4. Registry for Simulation State
INSERT INTO system_state (key, value)
VALUES ('sandbox_status', '{"ready": true, "isolated": true}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();
