# Tasks

A high-level overview of pending and completed development tasks.

## Active
- [ ] Integrate authenticated live social feed provider adapters.
- [ ] Add end-to-end ingestion replay test against seeded container DB.

## Backlog
- [ ] Multi-region city support (auto-detecting city from coordinates).
- [ ] Push notifications for severe disruptions on saved routes.
- [ ] Voice guidance integration for high-risk zones.

## Completed
- [x] Implement LLM-based social event parser service with deterministic fallback.
- [x] Add unit tests for `RiskService` with mock database responses.
- [x] Add append-only `events_log` contract and ingestion idempotency keys.
- [x] Add `system_state` health telemetry for lifecycle and materialization jobs.
- [x] Add rebuild and query-plan validation scripts.
- [x] Initial full-stack scaffold.
- [x] PostGIS risk heuristic implementation.
- [x] iOS UI Modularization.
- [x] Comprehensive documentation suite.
- [x] Networking diagnostic layer.
