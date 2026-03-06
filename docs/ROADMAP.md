# UDIE Technical Roadmap

UDIE is a continuously updated spatial risk field approximation. This roadmap defines the path to a high-scale, production-ready spatial substrate.

## The Goal
A deterministic pipeline that turns noisy urban signals into a stable, queryable spatial layer with bounded compute cost and automatic data aging.

## Phase I: Structural Foundation (7 Days) - [COMPLETED]
Establish the immutable log of truth and the decaying spatial state.
- **Milestones**: H3 Bucketing, Lifecycle maintenance, Risk materialization.

## Phase II: Architectural Verification (10 Days) - [COMPLETED]
Prove the model's fidelity and performance scaling properties.
- **Milestones**: Scale Proof ($O(route)$), Ground Truth correlation, Rebuild determinism.

## Phase III: Operational Stabilization & Platformization (14 Days) - [IN PROGRESS]
Transform the engine into a unified City Intelligence Platform.
- **Milestones**: 
  - [x] Architecture Simplification (Log-to-Grid)
  - [x] Spatial Density Amplification
  - [x] In-Memory Risk Grid (<1ms latency)
  - [x] Time-Lapse Snapshot Engine
  - [/] City Intelligence Dashboard UI/UX
  - [/] Cell Intelligence Explainability API
  - [x] Route Options (Multi-Route Utility Scoring)
  - [ ] Causal Correlation Engine
  - [x] Predictive Forecast Surface (`forecast_cells`)
  - [x] Self-Diagnosis Foundation (ArchitectureAuditService + QueryPlanMonitor + RiskModelMonitor)
  - [x] Performance Sentinel
  - [x] Simulation Service (isolated synthetic stream)

## Phase IV: Scaling Readiness (14 Days)
Partition the spatial workload by geography.
- **Milestones**: Geographic partitioning, Localized materialization.

## Phase IV.1: Autonomous Guardrails (7 Days) - [IN PROGRESS]
Automate invariant enforcement and regression detection.
- **Milestones**:
  - [x] `verify:architecture` script
  - [x] scheduled architecture audit worker
  - [ ] query-plan baseline diff persistence
  - [ ] partition auto-scaling (`detectHotRegion`, split/rebalance)

## Phase V: Multi-Node Expansion (14 Days)
Distribute node roles (Ingest, Materialize, Read) while maintaining PostgreSQL authority.
- **Milestones**: Role separation, Advisory lock coordination, Read isolation.

## Phase VI: Saturation Analysis (14 Days)
Identify physical bottlenecks (CPU/IO/WAL) before any further architectural escalation.
- **Milestones**: Load staircase, 72-hour soak test, Saturation report.

---

## Architectural Invariants
1. **Query Cost O(cells)**: Flat latency regardless of history size.
2. **Log-Rebuildability**: System state can be 100% regenerated from logs.
3. **Decay First**: Data ages and disappears automatically via confidence decay.
4. **Geography-First Scaling**: Scale by adding regions, not just resizing a monolith.
