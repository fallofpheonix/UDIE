# Changelog

## [0.4.0] - 2026-02-20
### Added
- `events_log` append-only ingestion table with idempotency key enforcement.
- `system_state` telemetry table + `set_system_state` function for background worker observability.
- `rebuild_derived_state_from_log()` deterministic rebuild function.
- `SocialEventParserService` (LLM path + deterministic heuristic fallback).
- Automated checks:
  - `npm run test:risk`
  - `npm run validate:rebuild`
  - `npm run validate:plan`

### Changed
- `/risk` controller is now exposed only at `POST /api/risk`.
- `RiskService` now reads normalization and route-bound constants from `model_parameters`.
- Lifecycle/materialization workers now use advisory locks for restart-safe idempotency.
- iOS `APIClient` now includes retry + cancellation-aware request handling.
- UI: Risk and status cards polished for clearer state signaling.

### Fixed
- TypeScript build breaks in DTO validation and ingestion module imports.
- Multiple migration incompatibilities around `status` enum vs numeric status.
- iOS `APIClient` Info.plist URL parsing compile failure.

## [0.3.0] - 2026-02-20
### Added
- **Sprint 0: Structural Foundation** complete.
- **Append-Only Log**: Implemented append-only event log as the system's source of truth.
- **Lifecycle Engine**: Automated 3% confidence decay and event expiry logic.
- **Materialized Risk Surface**: Added `risk_cells` for $O(route)$ query complexity.
- **H3 Spatial Bucketing**: Enforced Resolution 9 spatial indices for all active events.
- **Geometric Guards**: Implemented vertex (1000) and distance (50km) bounding on route requests.
- **Evaluation Harness**: Setup benchmarking scripts and initial spatial dataset.

### Changed
- Shifted architecture to the **Weather Model** (Log -> Active -> Materialized).
- Updated `calculate_route_risk_v3` to use pre-aggregated spatial weights.
- Formalized 6-Sprint Roadmap for production scaling.

### Fixed
- Debounced map movement to reduce API request spam.
- Unified networking diagnostics in `APIClient`.
- Cleaned up redundant files from root directory.

## [0.1.0] - 2026-02-12
### Added
- Initial project structure.
- NestJS API with PostGIS integration.
- MapKit basic implementation.
- Basic routing and polyline rendering.
