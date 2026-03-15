-- Migration 043: Allow protected deletes to return OLD rows.
-- The original trigger returned NEW for DELETE operations, which suppresses the delete.

CREATE OR REPLACE FUNCTION protect_derived_table()
RETURNS TRIGGER AS $$
BEGIN
    IF current_setting('udie.allow_derived_mutation', true) IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION 'Direct mutation of derived table % is prohibited by Architectural Law 5.', TG_TABLE_NAME;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
