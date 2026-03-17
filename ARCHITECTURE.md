# Architecture Reference

UDIE follows a log-derived pattern. The system distinguishes strictly between the immutable source of truth and versioned projections.

## System Philosophy

- **Events log = authoritative state.** Every derived grid or view can be replayed from the event log.
- **Bounded request logic.** Request-time logic is O(route\_cells), never O(historical\_events).
- **Spatial sovereignty.** The backend owns all intelligence; clients are thin observers.

## Core Subsystems

### 1. Ingestion Layer
Normalizes signals from REST and WebSocket transports. Signals are validated against geographic bounds and appended to the `events_log`.

### 2. Spatial Compute Engine
Uses Uber H3 resolution 9 as the primary indexing unit. Aggregates event weights into decayed risk scores across a materialized `risk_cells` surface.

### 3. Derived-State Workers
- **Projection Worker**: Translates log appends into spatial updates.
- **Lifecycle Worker**: Manages temporal decay and event expiration.
- **Snapshot Worker**: Captures periodic global grid states for analysis.

## Architecture Decision Records

- **ADR-001**: Event-sourced spatial compute as the sole source of truth.
- **ADR-002**: H3 standard for discretized spatial addressing.
- **ADR-003**: Precomputed risk surface to ensure sub-millisecond hot-path lookups.
- **ADR-004**: Thin clients to centralize intelligence authority.
- **ADR-005**: Environment-aware base URL resolution for simulator vs physical device stability.

## Architectural Constraints

- **Deterministic rebuild**: `state = f(logs)`. All derived state must be reproducible from the event log alone.
- **Hot path isolation**: Evaluation cost must be independent of total event volume.
- **Derived-state purity**: No manual mutation of materialized tables.
