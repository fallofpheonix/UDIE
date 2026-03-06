-- Migration 019: Revoke Direct Writes
-- Enforces the architectural law that derived state must not be mutated directly.

CREATE OR REPLACE FUNCTION protect_derived_table()
RETURNS TRIGGER AS $$
BEGIN
    -- Only allow mutation if 'udie.allow_derived_mutation' is set to 'true'
    IF current_setting('udie.allow_derived_mutation', true) IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION 'Direct mutation of derived table % is prohibited by Architectural Law 5.', TG_TABLE_NAME;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_protect_geo_events ON geo_events;
CREATE TRIGGER trg_protect_geo_events
BEFORE INSERT OR UPDATE OR DELETE ON geo_events
FOR EACH ROW EXECUTE FUNCTION protect_derived_table();

DROP TRIGGER IF EXISTS trg_protect_risk_cells ON risk_cells;
CREATE TRIGGER trg_protect_risk_cells
BEFORE INSERT OR UPDATE OR DELETE ON risk_cells
FOR EACH ROW EXECUTE FUNCTION protect_derived_table();
