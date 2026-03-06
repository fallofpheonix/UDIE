-- Migration 022: Robust Locking
-- Implements helper functions for worker-level soft locking with heartbeat-based expiration.

CREATE OR REPLACE FUNCTION acquire_worker_lock(p_worker_name TEXT, p_timeout_seconds INT DEFAULT 300)
RETURNS BOOLEAN AS $$
DECLARE
    v_last_heartbeat TIMESTAMPTZ;
BEGIN
    SELECT last_run INTO v_last_heartbeat FROM system_state WHERE key = p_worker_name;
    
    IF v_last_heartbeat IS NULL OR v_last_heartbeat < now() - (p_timeout_seconds || ' seconds')::interval THEN
        INSERT INTO system_state (key, last_run)
        VALUES (p_worker_name, now())
        ON CONFLICT (key) DO UPDATE SET last_run = now();
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;
