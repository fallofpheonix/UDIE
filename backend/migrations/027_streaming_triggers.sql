-- Migration 027: Streaming Risk Triggers
-- Enables real-time reactivity for the AggregationWorker.

-- 1. Notify Function
CREATE OR REPLACE FUNCTION notify_risk_event()
RETURNS TRIGGER AS $$
BEGIN
    -- Emit notification to 'risk_update' channel
    -- Payload contains region (h3_parent) and log id
    PERFORM pg_notify(
        'risk_update',
        json_build_object(
            'id', NEW.id,
            'h3_parent', NEW.h3_parent::text
        )::text
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Trigger on Log Insertion
-- Law: Updates are triggered by immutable log entries.
CREATE TRIGGER trg_risk_log_notify
AFTER INSERT ON regional_events_log
FOR EACH ROW
EXECUTE FUNCTION notify_risk_event();

-- 3. Optimization: Ensure we only notify for 'INGESTED' logs that need projection
-- (Self-correction: The worker will filter if needed, but trigger-level filtering is better)
DROP TRIGGER IF EXISTS trg_risk_log_notify ON regional_events_log;

CREATE TRIGGER trg_risk_log_notify
AFTER INSERT ON regional_events_log
FOR EACH ROW
WHEN (NEW.log_type = 'INGESTED')
EXECUTE FUNCTION notify_risk_event();
