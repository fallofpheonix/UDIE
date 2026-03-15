# Testing Strategy

UDIE employs a multi-tier validation strategy to ensure spatial correctness, API stability, and deterministic state recovery.

## 🧪 Testing Tiers

### 1. Unit Tests
- **Location**: `engine-backend/test/unit`, `UDIE/CoreTests`, `udie_mobile/test`.
- **Focus**: Risk kernels, spatial math (H3), normalization logic, and individual UI components.

### 2. Integration Tests
- **Location**: `engine-backend/test/integration`.
- **Focus**: Module-to-module contracts, database reachability, and API response schemas.

### 3. Rebuild & Determinism Tests
- **Location**: `engine-backend/test/rebuild`.
- **Focus**: Verifying the **Law of Deterministic Rebuild**. These tests replay a set of event logs and verify that the resulting `risk_cells` surface matches a known-good baseline.

### 4. End-to-End (E2E) & Simulator Tests
- **Location**: `udie_mobile/integration_test`.
- **Focus**: Full-stack flows from signal ingestion to mobile rendering using the simulation environment.

## 🚦 Verification Protocols

### Mandatory Diagnostic Protocol
Before any deployment or major change, the following must be verified:
1.  **API Namespace Discovery**: Verify `/api/v1` vs `/api` responsiveness.
2.  **Contract Validity**: Test endpoints with valid query parameters (not empty defaults).
3.  **Data-Plane Health**: Confirm `risk_cells` is non-empty and freshness is within bounds.

## 🛠 Tooling

- **NestJS**: `jest` for unit and integration tests.
- **Swift**: `XCTest` for iOS logic.
- **Flutter**: `flutter test` for cross-platform components.
- **Postgres**: Custom SQL scripts in `engine-backend/scripts/diagnostics` for schema audits.

## 🚫 Anti-Patterns

- **Mocking Spatial Kernels**: Core H3 logic must be tested against real coordinates, not shallow mocks.
- **Ignoring Worker Failures**: API success is irrelevant if the background projection workers are failing.
- **Hard-coded Paths**: Tests must remain machine-agnostic.
