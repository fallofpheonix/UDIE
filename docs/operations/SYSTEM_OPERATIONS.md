# UDIE System Operations

This is the canonical operations manual.
It replaces the older split across operations manual, playbook, troubleshooting, monitoring, and saturation-planning documents.

## Operational Scope

UDIE operations cover service startup, health verification, worker supervision, incident response, and controlled load validation.

## Daily Operating Model

### Health
- Verify API readiness and diagnostics.
- Confirm database reachability and worker heartbeat state.

### Freshness
- Check risk-surface staleness and snapshot generation.
- Treat stale derived state as a degraded operational condition.

### Contracts
- Verify the active API namespace and feature endpoints with valid bounded parameters.
- Confirm client configuration matches the intended runtime context.

## Incident Response

### Classification
- Transport failure
- API contract failure
- Schema drift
- Worker/data-plane degradation

### First Response
Gather logs, health state, endpoint behavior, and recent schema/runtime changes before patching code.

## Monitoring Expectations

At minimum, operators must observe:
- health/readiness status
- worker success/failure state
- materialization freshness
- query-plan regressions on hot paths
- rebuild/diagnostic status

## Troubleshooting Order

1. Process/container status
2. Listening ports and routing
3. API prefix and endpoint behavior
4. Database and migration integrity
5. Derived-state workers
6. Client runtime configuration

## Saturation and Scale

Load testing must identify the first failing subsystem rather than assume architectural changes are needed.
Scaling actions should follow measured bottlenecks in ingestion, DB, worker throughput, or query paths.
