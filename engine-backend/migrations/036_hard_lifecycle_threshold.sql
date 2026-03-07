-- Migration: 036_hard_lifecycle_threshold.sql
-- Implements Law 7: Time-Bounded Lifecycle Law
-- Enforces hard threshold epsilon for event removal.

CREATE OR REPLACE FUNCTION run_lifecycle_maintenance()
RETURNS VOID AS $$
DECLARE
  v_epsilon DOUBLE PRECISION;
BEGIN
  -- Load epsilon from model_parameters or default to 0.15 for aggressive cleanup
  SELECT COALESCE((SELECT value FROM model_parameters WHERE key = 'LIFECYCLE_EPSILON'), 0.15) INTO v_epsilon;

  -- 1. Marking stale events as EXPIRED (Step 16)
  UPDATE geo_events
  SET status = 'EXPIRED', updated_at = now()
  WHERE status = 'ACTIVE' 
    AND expires_at IS NOT NULL 
    AND expires_at < now();

  -- 2. Confidence Decay (Step 17)
  -- 3% decay per cycle
  UPDATE geo_events
  SET 
    confidence = confidence * 0.97,
    updated_at = now()
  WHERE status = 'ACTIVE';

  -- 3. Hard threshold removal (Law 7)
  -- Any event below epsilon is purged from the active field immediately.
  UPDATE geo_events
  SET status = 'EXPIRED', updated_at = now()
  WHERE status = 'ACTIVE' AND confidence < v_epsilon;
  
  -- 4. Delete logically expired events older than 7 days to keep source purity
  DELETE FROM geo_events 
  WHERE status = 'EXPIRED' AND updated_at < now() - interval '7 days';
END;
$$ LANGUAGE plpgsql;
