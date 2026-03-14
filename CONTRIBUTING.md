# 🤝 Contributing to UDIE (v2.0)

Contributions to the Urban Disruption Intelligence Engine (UDIE) must preserve the system’s deterministic spatial computation guarantees. UDIE is a geospatial computation substrate designed for maximum determinism and bounded query cost.

---

## Core Contribution Principles

### 1. The Invariant of Truth
**Events Log = Authoritative State.** All risk grids and materialized views are derived. Contributions must never allow direct mutation of derived state outside authoritative workers.

### 2. Aggregation Discipline
Risk evaluation must operate only on materialized spatial state (Redis Spatial Cache / PostGIS `risk_cells`). Request-time evaluation must never scan the `events_log`.

### 3. Bounded Query Cost
Query complexity must scale with spatial scope, not dataset size. 
$$\text{evaluation\_cost} \propto \text{route\_cells}$$

---

## Development Workflow

1. **Setup Substrate**: Follow [Setup & Onboarding](docs/operations/SETUP.md).
2. **Develop Against Architecture**: Review [System Architecture](docs/architecture/SYSTEM_ARCHITECTURE.md) and [Spatial Intelligence Model](docs/theory/SPATIAL_INTELLIGENCE_MODEL.md).
3. **Mandatory Local Validation**:
   ```bash
   # 1. Run full system integrity audit
   ./scripts/verify-full-system-integrity.sh

   # 2. Run unit & integration tests
   npm run test
   ```
4. **Agent Workflow**: If using autonomous agents, run `./scripts/agent-bootstrap.sh` before starting any task.

---

## Required Validation (Non-Trivial Changes)

PRs affecting SQL, lifecycle workers, risk kernels, or aggregation logic must include:
- **4-Layer Integrity Verification**: Output from `verify-full-system-integrity.sh`.
- **Query Plan Verification**: `EXPLAIN ANALYZE` output demonstrating no sequential scans on request-critical tables.
- **Deterministic Rebuild Test**: Evidence that derived state remains reconstructible from the `events_log`.

---

## Code Standards

### Substrate (Backend)
- **Domain Separation**: All new logic must reside in a relevant domain module (e.g., `ingestion/`, `forecasting/`).
- **Database Access**: Avoid raw SQL outside `Repository` classes or the `database/` module.

### Client (iOS)
- **State Decoupling**: Connectivity and sync logic must reside in `Core/State/`.
- **Observer Role**: The client observes risk scores; it never computes them.

---

## Documentation Standards
A feature is not "Done" until the relevant contracts in `docs/` are updated. Outdated documentation is treated as a high-severity defect.

---

MIT © 2026 **UDIE Engineering Group**. 
"Stability is non-negotiable."
