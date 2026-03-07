# 🏛️ UDIE Architecture Decision Records (ADR)

This document records the fundamental architectural decisions governing the UDIE spatial intelligence system. ADR entries capture the problem context, chosen decision, alternatives considered, and architectural invariants.

---

## 🌩️ ADR 001: Adoption of the Weather Model Architecture
**Status**: `Accepted` | **Date**: 2026-02-18 | **Scope**: Core System Architecture

### Context
Urban disruption data is noisy, overlapping, and decays over time. Traditional CRUD systems treat events as static rows, which leads to unbounded query complexity and impossible determinism.

### Decision
UDIE adopts a **Weather Model** architecture where disruptions are signals in a continuously evolving spatial field.
- **Pipeline**: `events_log` (immutable) → lifecycle aggregation → `risk_cells` (materialized) → In-memory Risk Grid.
- **Key Principle**: Ingestion is immutable; active state is derived; evaluation is bounded.

### Alternatives
- **CRUD Event Table**: Rejected due to $O(N)$ query scaling and stale event accumulation.
- **Real-Time Spatial Joins**: Rejected due to unpredictable PostGIS performance under load.

### Consequences
- Deterministic rebuild from `events_log`.
- Bounded query complexity independent of signal volume.
- **Invariants**: Derived tables are drop-rebuildable; request path never reads raw geometries.

---

## 📍 ADR 002: H3 Resolution 9 Spatial Discretization
**Status**: `Accepted` | **Date**: 2026-02-20 | **Scope**: Spatial Modeling Layer

### Context
UDIE requires a spatial index with uniform global coverage, hierarchical scaling, and predictable memory consumption. Lat/Long grids introduce unacceptable distortion.

### Decision
UDIE standardizes on the **H3 hierarchical hexagonal indexing** system at **Resolution 9** (~0.1 km² cell area). All signals are mapped into H3 cells during aggregation.

### Alternatives
- **Geohash**: Rejected due to rectangular distortion and inconsistent neighbor relationships.
- **Raw PostGIS Geometry**: Rejected due to expensive spatial joins and $O(N)$ lookup costs.

### Consequences
- Consistent spatial indexing and sub-millisecond neighbor queries.
- **Invariant**: All request-path spatial evaluation must operate exclusively on H3 cells.

---

## ⚡ ADR 003: Memory-Resident Risk Grid
**Status**: `Accepted` | **Date**: 2026-02-24 | **Scope**: Request-Path Performance

### Context
Route evaluation must be sub-millisecond. Direct database queries introduce network and disk latency that fail the 100ms routing budget.

### Decision
UDIE maintains a memory-resident risk grid built from the `risk_cells` table using a high-performance hash map for $O(1)$ cell lookup.

### Alternatives
- **Database Query per Route**: Rejected due to unpredictable latency and DB bottlenecks.
- **Redis Risk Surface**: Rejected as an unnecessary infrastructure dependency for a grid that fits in RAM.

### Consequences
- Sub-millisecond route evaluation regardless of total system load.
- **Invariant**: The `/risk` endpoint must never query raw event tables.

---

MIT © 2026 **UDIE Engineering**. 
"Architecture is the sum of our decisions, held together by invariants."
