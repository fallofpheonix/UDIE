-- Migration 021: Log Retention Policy
-- Implements a policy to prune old events from the log to prevent unbounded growth.

CREATE OR REPLACE FUNCTION purge_archived_events(p_retention_days INT DEFAULT 90)
RETURNS INT AS $$
DECLARE
    v_deleted_count INT;
BEGIN
    -- Delete events that are EXPIRED and older than the retention threshold
    DELETE FROM events_log
    WHERE ingested_at < now() - (p_retention_days || ' days')::interval
      AND id IN (
          SELECT id FROM geo_events WHERE status = 'EXPIRED' OR expires_at < now()
      );
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Trigger or scheduled job can call this. For now, we expose it for the application.
