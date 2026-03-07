-- Migration: 037_sandbox_isolation.sql
-- Implements Physical Simulation Isolation (Phase 14)

-- 1. Create Simulation Events Log
CREATE TABLE simulation_events (
    LIKE geo_events INCLUDING ALL
);

-- 2. Create Simulation Risk Grid
CREATE TABLE simulation_risk_cells (
    LIKE risk_cells INCLUDING ALL
);

-- 3. Add explicit check to prevent manual cross-contamination
ALTER TABLE geo_events ADD CONSTRAINT check_not_simulation CHECK (status != 'SIMULATION');
ALTER TABLE simulation_events ADD CONSTRAINT check_is_simulation CHECK (status = 'SIMULATION');

-- 4. Registry for Simulation State
INSERT INTO system_state (key, state) VALUES ('sandbox_status', '{"ready": true, "isolated": true}'::jsonb)
ON CONFLICT (key) DO UPDATE SET state = EXCLUDED.state;
