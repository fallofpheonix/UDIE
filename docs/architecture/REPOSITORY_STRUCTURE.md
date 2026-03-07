# 📁 UDIE Repository Structure Specification (v2.0)

This document defines the authoritative architecture for the UDIE repository. It ensures that compute, client, and contract layers remain decoupled and maintainable as the system scales.

---

## 🌲 Technical Hierarchy

```text
UDIE/
├── engine-backend/          # [Substrate] Spatial Compute & API
│   ├── src/
│   │   ├── modules/         # Domain-Driven Design Modules
│   │   │   ├── ingestion/   # Signal capture & normalization
│   │   │   ├── events/      # Authoritative append-only log
│   │   │   ├── risk/        # Field weight & kernel evaluation
│   │   │   ├── spatial/     # H3 index & PostGIS geometry
│   │   │   ├── forecasting/ # Predictive T+X projections
│   │   │   └── observability/ # Monitoring, metrics & tracing
│   │   ├── common/          # Interceptors, Filters, Guards
│   │   └── database/        # Data Layer Specification
│   │       ├── migrations/  # DDL versioning
│   │       ├── views/       # Spatial aggregations & projections
│   │       └── schemas/     # Static table definitions
│   ├── scripts/             # Operational Automation
│   │   ├── dev/            # Local environment management
│   │   ├── ops/            # Grid rebuilds & cache pruning
│   │   └── diagnostics/    # Schema & connectivity audits
│   └── test/                # Multi-Tier Validation
│       ├── unit/           # Logic & kernel testing
│       ├── integration/    # Module-to-Module contracts
│       └── rebuild/        # Determinism & state recovery
│
├── UDIE/                    # [Client] Swift Operational Interface
│   ├── Core/                # Domain Logic Substrate
│   │   ├── Networking/      # API prefix resolution & resilience
│   │   ├── State/           # Synchronization state machine
│   │   └── Models/          # DTOs & Domain entities
│   ├── Features/            # Feature-centric VM/View pairs
│   └── UI/                  # Shared design system (Atoms/Molecules)
│
├── docs/                    # [Contract] System Specifications
│   ├── architecture/        # Laws, ADRs, & Whitepapers
│   ├── agents/              # Mandatory agent governance
│   ├── operations/          # Playbooks & setup guides
│   └── incidents/           # Postmortems & failure analysis
│
├── infra/                   # [Infrastructure] Global Orchestration
│   ├── docker-compose.yml   # Multi-service runtime
│   ├── postgres/           # Custom PG/PostGIS configuration
│   └── monitoring/          # Prometheus & Grafana configs
│
└── CHANGELOG.md             # Version-tracked system evolution
```

---

## ⚖️ Ownership & Architectural Laws

### 1. The Invariant of Truth
**Events Log = Authoritative State.** The `risk_cells` and in-memory grids are **derived states**. The repository structure protects the Event Log from direct mutation outside the Ingestion module.

### 2. Single Source of Risk
The **Backend owns all spatial risk computation**. The iOS Client is strictly an observer and evaluator of backend-provided scores. Local "approximate" risk kernels are forbidden.

### 3. Data Privacy
Direct database access (raw SQL) is prohibited outside the `database/` module or specialized `Repository` classes. Every query must pass through defined service interfaces.

### 4. Infrastructure Isolation
Infrastructure configurations in `infra/` must be agnostic to application logic. They define the "room" the system lives in, not the system itself.

---

## 🚫 Forbidden Structural Patterns

- **Path Coupling**: Never use machine-specific absolute paths in scripts or configurations.
- **Leaky UI**: State logic (syncing, connectivity) must reside in `Core/State/`, not inside SwiftUI Views.
- **Dependency Inversion Violation**: Core modules should not depend on Feature-level implementations.
- **Doc Decay**: A feature is not "Done" until the relevant `docs/` contract is updated.

---

MIT © 2026 **UDIE Engineering Group**. 
"Stability is a function of structure. Intelligence is a function of stability."
