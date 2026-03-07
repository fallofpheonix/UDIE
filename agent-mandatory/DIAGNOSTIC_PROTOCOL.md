# Diagnostic Protocol (Mandatory)

## Objective
Prevent false diagnosis by enforcing deterministic triage order.

## Step 1: Route Namespace Discovery
Run both probes and record status/body:
- `GET /api/health`
- `GET /api/v1/health`

Decision:
- If one is 200/JSON and the other is 404 -> namespace mismatch, not transport issue.

## Step 2: Contract-Valid Endpoint Probe
Use required query parameters for endpoints that require them.
Example for events:
- `minLat,maxLat,minLng,maxLng,city`

Decision:
- `400` with validation details -> contract failure, connectivity is present.

## Step 3: Worker/Data-Plane Health
Inspect logs for periodic worker failures, trigger errors, DB lock contention.
Classify recurring failures separately from API namespace issues.

## Step 4: State Semantics Audit
UI should represent:
- DISCONNECTED
- CONNECTING
- CONNECTED_UNSYNCED
- SYNCED
- ERROR

Never collapse into a single boolean for production diagnostics.

## Step 5: Fix Sequencing
1. Restore API compatibility (prefix and base URL reachability).
2. Restore backend worker correctness (DB guardrails, flags, transactions).
3. Align UI state model with observed backend/data reality.
4. Add runtime fallback or discovery where version drift is possible.

## Step 6: Verification Matrix
- [ ] Health endpoint works at resolved namespace.
- [ ] One contract-valid business endpoint returns 200.
- [ ] Worker loop runs without repeated fatal error.
- [ ] UI transitions to `SYNCED` after data fetch.
