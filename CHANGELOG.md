# 📜 UDIE Changelog

All notable changes to the Urban Disruption Intelligence Engine (UDIE) are documented in this file.

This project follows:
- **Keep a Changelog**
- **Semantic Versioning**

⸻

## [1.1.0] — 2026-03-08

⸻

### Added

#### Documentation
- Created `docs/system_workflow.md`: Comprehensive documentation of the end-to-end request lifecycle and data flow, bridging the iOS client and NestJS backend.
- Created `docs/production_architecture.md`: Definitive blueprint for the production-grade UDIE substrate, incorporating event streams (NATS/Kafka), spatial caching (Redis), and real-time distribution (WebSockets).

⸻

### Changed

#### iOS Synchronization & Networking
- Refactored `MapViewModel.swift` to implement a granular synchronization state machine (`connecting`, `connected`, `syncing`, `synced`, `error`) for more accurate status reporting.
- Updated `StatusBadgeView.swift` with improved iconography, clearer status labels, and a spinning animation for active data fetching.
- **Networking Resilience**:
    - Implemented `resolveAPIPrefix()` in `APIClient.swift` to dynamically detect backend endpoints (`/api/v1` vs `/api`).
    - Added a **Localhost Warning** for physical devices to prevent common connectivity misconfigurations.
    - Enhanced `APIClient.swift` to utilize the `/health/ready` endpoint for comprehensive readiness checks.
    - Included target `baseURL` in error reports to assist in local network troubleshooting.

⸻

## [1.0.0] — 2026-03-07

Initial production-ready release of UDIE with deterministic spatial risk modeling and multi-node operational architecture.

⸻

### Added

#### Core Architecture
- Implemented **Risk Model v2** using continuous spatial influence kernels.
- Added **density amplification** for disruption clustering.
- Added **exponential saturation normalization** for stable risk scoring in $[0, 1)$.
- Introduced **memory-resident risk grid** for constant-time evaluation.

⸻

#### Simulation Engine
- Added a **sandbox environment** for hypothetical disruptions.
- New table: `simulation_events`.
- Simulation execution is isolated from production data.

⸻

#### Error Observability
- Introduced a structured **system error tracking layer**.
- Components: `ErrorLogService`, `system_errors` table, and error fingerprint tracking.
- Enables probabilistic reliability scoring and failure analysis.

⸻

#### Architecture Monitoring
- Added automated **architecture validation**.
- New endpoint: `GET /api/v1/diagnostics/architecture`.
- Capabilities: query plan verification, risk model health monitoring, and worker state inspection.
- Nightly rebuild verification is executed through `ArchitectureAuditService`.

⸻

#### Performance
- Introduced **in-memory risk grid** for sub-millisecond route evaluation.
- Removed request-path spatial joins and event scans.
- Evaluation complexity: $O(\text{route\_cells})$, independent of dataset size.

⸻

#### Security
- Introduced request validation through `SpatialValidationGuard`.
- Constraints: **500 vertices / 100 km limit**.
- Prevents computational amplification and denial-of-service attacks.

⸻

#### Database
- New tables: `simulation_events`, `system_errors`, `model_parameters`, and `risk_snapshots`.
- Added deterministic rebuild procedure: `rebuild_derived_state_from_log()`.
- Guarantees reproducibility of derived spatial state.

⸻

#### Infrastructure
- Added system observability and reliability scoring.
- New components: `ArchitectureAuditService`, `ErrorLogService`, and `PerformanceSentinel`.
- Continuous monitoring of system invariants and performance metrics.

⸻

### Changed

#### API Namespace
- Unified API routing under a versioned prefix: `/api/v1/*`.
- Affected systems: iOS client, Web admin interface, and backend controllers.

⸻

#### Lifecycle Engine
- Implemented a hard confidence threshold: $\epsilon = 0.15$.
- Signals below this threshold are immediately removed from the active dataset.

⸻

#### Repository Structure
- Repository cleanup: Archived obsolete documentation, removed duplicate docs, and flattened client structure.

⸻

### Fixed
- Circular dependency issues between backend service modules.
- Type errors in `ArchitectureAuditService`.
- Kernel implementation inconsistencies between aggregation and evaluation layers.
- API namespace mismatch causing client-side 404 errors.

⸻

## [0.4.0] — 2026-02-20

⸻

### Added

#### Event Ingestion System
- Introduced append-only ingestion log: `events_log`.
- Idempotency enforcement and immutable event history.

⸻

#### System Telemetry
- Added infrastructure telemetry: `system_state`.
- Provides operational visibility for background workers.

⸻

#### Deterministic Rebuild
- Added rebuild procedure: `rebuild_derived_state_from_log()`.
- Ensures derived state can be regenerated from the ingestion log.

⸻

#### Signal Parsing
- Added LLM-assisted signal interpretation with deterministic fallback parsing.

⸻

#### Infrastructure
- Introduced advisory locks for lifecycle and aggregation workers to ensure restart-safe execution.

⸻

#### Validation
- Added automated validation scripts: `test:risk`, `validate:rebuild`, and `validate:plan`.

⸻

### Changed
- Moved risk model configuration parameters to `model_parameters` table.
- Updated risk evaluation endpoint to `POST /api/v1/risk`.

⸻

### Fixed
- DTO validation errors in TypeScript builds.
- Database migration conflicts involving status enums.
- Incorrect iOS `APIClient` URL configuration.

⸻

## [0.3.0] — 2026-02-18

⸻

### Added

#### Structural Foundation
- Implemented the **Weather Model Architecture**: `events_log` → `events_active` → `risk_cells`.
- Separation of ingestion, lifecycle processing, and evaluation.

⸻

#### Spatial Engine
- Added H3 spatial indexing at **Resolution 9**.
- New table: `risk_cells` for pre-aggregated spatial disruption intensity.

⸻

#### Benchmark Harness
- Added evaluation benchmarks: `benchmarks/spatial_baseline_v1`.

⸻

### Changed
- Replaced request-time event scanning with materialized spatial aggregation, dramatically reducing latency.

⸻

### Fixed
- Excessive map request spam caused by UI movement.
- Network diagnostics inconsistencies in the client.

⸻

## [0.1.0] — 2026-02-12

⸻

### Added
- Initial project scaffolding.
- NestJS backend, PostGIS database, and SwiftUI client with MapKit integration.

---

## Summary
UDIE has evolved from a geospatial routing prototype into a deterministic spatial intelligence platform featuring:
- **Append-only ingestion**
- **Lifecycle-managed events**
- **Materialized spatial risk surfaces**
- **Memory-resident evaluation engine**

The system is now ready for production-scale urban disruption analysis.
