# Architecture Reference

UDIE follows a **Log-Derived Pattern**. The system distinguishes strictly between the immutable source of truth and versioned projections.

## 🏗 System Philosophy

- **Events Log = Authoritative State**: Every derived grid or view can be replayed from the event log.
- **Bounded Request Logic**: Request-time logic is O(route\_cells), never O(historical\_events).
- **Spatial Sovereignty**: The backend owns all intelligence; clients are thin observers.

## 🧱 Core Subsystems

### 1. Ingestion Layer
Normalizes signals from REST, WebSocket, and Kafka. Signals are validated against geographic bounds and appended to the `events_log`.

### 2. Spatial Compute Engine
Uses Uber H3 resolution 9 as the primary indexing unit. Aggregates event weights into decayed risk scores across a materialized `risk_cells` surface.

### 3. Derived-State Workers
- **Projection Worker**: Translates log appends into spatial updates.
- **Lifecycle Worker**: Manages temporal decay and event expiration.
- **Snapshot Worker**: Captures periodic global grid states for analysis.

## 🚦 Architecture Decisions (ADRs)

- **ADR-001**: Event-Sourced Spatial Compute as the sole source of truth.
- **ADR-002**: H3 Standard for discretized spatial addressing.
- **ADR-003**: Precomputed Risk Surface to ensure sub-millisecond hot-path lookups.
- **ADR-004**: Thin Clients to centralize intelligence authority.
- **ADR-005**: Environment-Aware Base URL resolution for simulator vs physical device stability.

## ⚖️ Architectural Laws

All components must adhere to the **Laws of UDIE**, including:
- **Law of Deterministic Rebuild**: $\text{state} = f(\text{logs})$.
- **Law of Hot Path Isolation**: Evaluation cost $\perp$ event count.
- **Law of Derived-Status Purity**: No manual mutation of materialized tables.

Refer to [SYSTEM_DESIGN.md](file:///Users/fallofpheonix/Project/UDIE/SYSTEM_DESIGN.md) for detailed mathematical and theoretical foundations.
