# Project Overview

UDIE (Universal Disruption Intelligence Engine) treats urban disruption as a continuously evolving spatial field. Conventional systems treat disruptions as shallow annotations; UDIE treats them as weighted energy injected into a spatiotemporal grid.

## 🎯 Product Goals

1.  **Deterministic Risk Evaluation**: provide route risk scores backed by verifiable spatial computation.
2.  **Operational Intelligence**: Surface area-level hotspots and trend summaries for city operations.
3.  **Thin-Client Architecture**: Keep client applications focused on visualization while maintaining intelligence authority on the backend.

## 📋 Primary Use Cases

- **Tactical Navigation**: Evaluating route exposure to current disruptions (accidents, VIP movements, hazards).
- **City Operations Dashboard**: Monitoring regional risk density and data freshness across a city.
- **Intelligence snapshots**: Analyzing temporal changes in urban risk fields for planning and response.

## 🏗 Requirements Summary

### Functional
- Bounded spatial queries for events and risk cells.
- Deterministic rebuildability of all derived states from the event log.
- Explicit synchronization and connectivity state reporting.

### Non-Functional
- **Latency**: < 5ms for route evaluation, < 100ms for cell lookups.
- **Integrity**: Direct mutation of derived tables is prohibited.
- **Observability**: Continuous auditing of worker health and data freshness.

## 🗺 Roadmap

1.  **Phase 1: Substrate Stability**: Secure the event-sourced persistence and H3 aggregation kernels. (COMPLETED)
2.  **Phase 2: Mobile Integration**: Align iOS and Flutter clients with the authoritative backend risk model. (IN PROGRESS)
3.  **Phase 3: Intelligence Scaling**: Implement predictive forecasting and nationwide horizontal sharding. (PLANNED)
