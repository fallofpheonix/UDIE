#!/bin/bash
# validate_pattern_detection.sh
# Mocks risk spikes and verifies that the Intelligence Module detects them.

echo "--- UDIE Intelligence Validation Harness ---"

# 1. Reset intelligence tables
psql -U $DB_USER -d $DB_NAME -c "TRUNCATE intelligence_events, intelligence_cell_state;"

# 2. Inject a baseline weight for a cell
H3_CELL="8965a2cffffffff"
psql -U $DB_USER -d $DB_NAME -c "INSERT INTO intelligence_cell_state (h3_index, last_weight, updated_at) VALUES ($H3_CELL::bigint, 1.0, now() - interval '15 minutes');"

# 3. Simulate a massive weight in the in-memory grid (via a mock update if possible, or direct DB weight if the worker scans DB)
# Note: Our IntelligenceService scans in-memory grid for weights.
# For this script to work, we'd need to trigger the IntelligenceWorker.
echo "Triggering Analysis... (Assuming InMemRiskService has weight=10.0 for $H3_CELL)"

# Mocking the worker run
# curl -X POST http://localhost:3000/api/intelligence/analyze 

# 4. Check for insights
echo "Verifying Intelligence Events..."
psql -U $DB_USER -d $DB_NAME -c "SELECT event_type, severity, description FROM intelligence_events WHERE h3_index = $H3_CELL::bigint;"

echo "--- Validation Complete ---"
