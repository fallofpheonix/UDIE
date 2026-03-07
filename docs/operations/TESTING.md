# 🧪 UDIE Testing Strategy

This document defines the testing methodology used to verify the correctness, stability, and scalability of the UDIE spatial intelligence platform. The testing strategy enforces both software correctness and architectural invariants.

⸻

## 🧪 Coverage Requirements

Minimum coverage targets:

| Component | Coverage Target |
| :--- | :--- |
| Risk model kernels | 100% |
| Spatial aggregation logic | 100% |
| Backend API layer | ≥ 80% |
| Lifecycle workers | ≥ 80% |
| iOS client state logic | ≥ 75% |

The following modules must always maintain **full coverage**: `RiskGridService`, risk model kernels, distance decay functions, normalization functions, and density amplification.

⸻

## 🛠️ Test Categories

UDIE uses multiple layers of tests to validate the system.

### 1. Unit Tests
Verifies isolated computational components.
- **Backend (Vitest)**: `npm run test`
  - Targets: `RiskGridService`, decay kernels, normalization, amplification, H3 mapping.
- **iOS Client (XCTest)**: Coordinate math, route sampling, state reducers, DTO decoding.

### 2. Integration Tests
Verifies correct interaction between components (PostGIS, ingestion, lifecycle, materialization).
- Enforces the pipeline flow: `events_log` → `events_active` → `risk_cells`.

### 3. Deterministic Rebuild Tests
Enforces the **Law of Deterministic Rebuild**.
1. Load test dataset into `events_log`.
2. Materialize derived state.
3. Drop and rebuild using `rebuild_derived_state_from_log()`.
4. Result must satisfy: `rebuild_output == original_output`.

### 4. API Contract Tests
Ensures response stability for client compatibility across critical endpoints: `/risk`, `/events`, `/city-dashboard`, `/diagnostics/architecture`.

### 5. Performance Tests
Ensures latency invariants are maintained. 
- **Targets**: Route evaluation < 5ms, H3 lookup < 1ms, Materialization < 100ms / 100k events.
- **Tool**: `benchmarks/spatial_baseline_v1`.

### 6. Architecture Integrity Tests
Enforces the **16 Laws of UDIE** via `ArchitectureAuditService`.
- Verifies bounded complexity, memory residency, and query plan safety.
- **Command**: `npm run verify:architecture`

### 7. Simulation Isolation Tests
Enforces the **Law of Simulation Isolation**. Verifies that `simulation_events` never contaminate production tables.

⸻

## 🚀 Execution Guide

### Backend
```bash
# Run unit & integration tests
npm run test

# Run architecture audit
npm run verify:architecture

# Run rebuild verification
npm run validate:rebuild
```

### iOS Client
- Run tests in Xcode using `Cmd + U`.
- Suites: `location_math_tests`, `route_sampling_tests`, `api_dto_tests`.

⸻

## 🔄 CI/CD Pipeline
1. Lint → 2. Unit Tests → 3. Integration Tests → 4. Architecture Verification → 5. Performance Benchmarks → 6. Build.
*Failure at any stage blocks deployment.*

⸻

MIT © 2026 **UDIE Engineering**. 
"If it isn't tested, it's broken by design."
