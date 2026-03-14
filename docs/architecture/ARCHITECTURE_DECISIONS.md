# UDIE Architecture Decisions

This document is the canonical record of major architectural decisions for UDIE.
It replaces the older split between ADRS and decision-log style documents.

## Decision Format

Each entry captures:

1. Context
2. Decision
3. Consequences
4. Constraints introduced

## ADR-001: Event-Sourced Spatial Compute

### Context
Urban disruption state is noisy, overlapping, and time-variant.
Point-in-time CRUD tables cannot guarantee deterministic rebuilds or bounded evaluation cost.

### Decision
Use an append-only event/log model as the sole persistent source of truth.
All risk grids, snapshots, views, and intelligence outputs are derived projections.

### Consequences
- Replay and rebuild remain possible.
- Derived-state mutation must be explicitly guarded.
- Worker correctness becomes as important as API correctness.

## ADR-002: H3 as the Universal Spatial Index

### Context
Route risk, neighborhood lookup, and partitioning require a consistent discrete spatial key.

### Decision
Standardize on H3 for spatial discretization, partitioning, adjacency, and route-cell coverage.

### Consequences
- All core APIs and models operate in terms of cell coverage.
- PostGIS remains the geographic execution layer, but H3 is the dominant addressing layer.

## ADR-003: Precomputed Risk Surface over Request-Time Aggregation

### Context
Request-time scans across full event history do not scale and violate bounded-latency goals.

### Decision
Maintain a materialized risk surface and in-memory risk grid for evaluation paths.

### Consequences
- Worker health and materialization freshness are first-class production concerns.
- Health endpoints must expose stale-surface conditions explicitly.

## ADR-004: Mobile Clients Stay Thin

### Context
Mobile devices cannot be the authoritative location for high-volume spatial aggregation or replay semantics.

### Decision
Keep route risk, city dashboards, and intelligence generation on the backend.
Clients render, cache lightly, and report explicit sync/connectivity state.

### Consequences
- API contract stability is critical.
- Device-side failures must distinguish transport, contract, and backend/data degradation.

## ADR-005: Physical Device Connectivity Requires Explicit Host Routing

### Context
`localhost` is valid in simulator contexts and invalid on physical iPhones for host-Mac services.

### Decision
Backend base URL must be injected through environment/configuration and validated against the runtime environment.

### Consequences
- Shared schemes must not be treated as a durable source of truth.
- Documentation and diagnostics must always distinguish simulator vs physical device behavior.

## ADR-006: Agent Workflows Must Follow Runtime-First Diagnostics

### Context
This repository mixes iOS, Flutter, NestJS, FastAPI, Docker, and database state.
Code-first diagnosis consistently leads to false conclusions.

### Decision
Require agents to execute bootstrap and diagnostic protocols before making changes.

### Consequences
- Agent documentation is part of repository governance, not optional prose.
- Duplicated diagnostic docs must be eliminated to preserve one protocol.
