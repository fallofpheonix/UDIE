# 📜 UDIE Decision Log (ADRs)

This document tracks significant architectural decisions for the Urban Disruption Intelligence Engine. Each entry represents a non-trivial choice that shapes the system's long-term stability and scaling.

---

## [ADR-001] Spatial Indexing: H3 over S2/Geohash
- **Date**: 2026-02-15
- **Status**: `ACCEPTED`
- **Context**: Need a discrete global grid for risk evaluation that supports efficient neighborhood lookup.
- **Decision**: Use Uber's H3 indexing due to its hexagonal grid properties, which provide uniform neighbor distances and minimize orientation bias compared to square-based grids (S2).
- **Impact**: All evaluation kernels must operate on H3 cell IDs.

---

## [ADR-002] State Authority: Event Log as Truth
- **Date**: 2026-03-07
- **Status**: `ACCEPTED`
- **Context**: Direct mutation of derived tables (`risk_cells`) led to state drift and non-deterministic behavior.
- **Decision**: Mandate "Spatial Event Sourcing." The `events_log` is the only persistent authority. All grids and caches must be derived from it.
- **Impact**: Introduced a 4-layer integrity model and deterministic rebuild tests.

---

## [ADR-003] Communication: Asynchronous Event Bus (NATS/Kafka)
- **Date**: 2026-03-08
- **Status**: `ACCEPTED`
- **Context**: Tight coupling between ingestion and query evaluation limited scalability during high-intensity signal bursts.
- **Decision**: Decouple modules using an asynchronous event bus. Ingestion workers publish raw signals; materialization workers subscribe to update grids.
- **Impact**: Improved ingestion throughput; enabled real-time Redis spatial caching.

---

MIT © 2026 **UDIE Engineering Group**. 
"Architecture is the sum of its decisions."
