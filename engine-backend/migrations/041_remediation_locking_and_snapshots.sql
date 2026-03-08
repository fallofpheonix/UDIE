-- Migration 041: Fix locking schema and missed snapshots
-- Re-ensures risk_snapshots table exists

CREATE TABLE IF NOT EXISTS risk_snapshots (
  snapshot_time TIMESTAMPTZ NOT NULL,
  h3_index BIGINT NOT NULL,
  risk_weight DOUBLE PRECISION NOT NULL,
  PRIMARY KEY (snapshot_time, h3_index)
);

CREATE INDEX IF NOT EXISTS idx_risk_snapshots_time_brin ON risk_snapshots USING brin(snapshot_time);
CREATE INDEX IF NOT EXISTS idx_risk_snapshots_h3 ON risk_snapshots (h3_index);

-- Correcting the acquire_worker_lock function to be robust
CREATE OR REPLACE FUNCTION acquire_worker_lock(p_worker_name text, p_timeout_seconds integer DEFAULT 300)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_last_heartbeat TIMESTAMPTZ;
BEGIN
    SELECT last_run INTO v_last_heartbeat FROM system_state WHERE key = p_worker_name;
    
    IF v_last_heartbeat IS NULL OR v_last_heartbeat < now() - (p_timeout_seconds || ' seconds')::interval THEN
        INSERT INTO system_state (key, value, last_run, updated_at)
        VALUES (p_worker_name, '{}'::jsonb, now(), now())
        ON CONFLICT (key) DO UPDATE SET last_run = now(), updated_at = now();
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$function$;
