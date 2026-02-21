
# Risk Register

This register tracks risks that could violate UDIE’s core guarantees: bounded evaluation, deterministic rebuild, and lifecycle stability.

| Risk ID | Description                                                                                            | Impact | Probability | Mitigation Strategy                                                                                  |
| ------- | ------------------------------------------------------------------------------------------------------ | ------ | ----------- | ---------------------------------------------------------------------------------------------------- |
| R-001   | Request-path regression introduces raw spatial scans, causing latency to scale with dataset size.      | High   | Medium      | Enforce query-plan audits (`EXPLAIN ANALYZE`) and reject any sequential scans in `/risk`path.    |
| R-002   | Lifecycle decay fails or is misconfigured, allowing stale events to accumulate indefinitely.           | High   | Medium      | Monitor active-to-log ratio and enforce automated expiry validation checks.                          |
| R-003   | Ingestion spikes overwhelm WAL/index throughput, degrading aggregation cadence.                        | Medium | Medium      | Batch ingestion commits and isolate write-heavy processing to ingestion node.                        |
| R-004   | Materialization refresh exceeds its interval, producing stale risk surfaces.                           | High   | Low         | Track refresh duration; scale materializer workers or partition regions when SLA is exceeded.        |
| R-005   | Model parameters changed without versioning, breaking reproducibility of historical evaluations.       | High   | Low         | Store all parameters in `model_parameters`with explicit version tracking and audit logs.           |
| R-006   | Duplicate or adversarial reports inflate confidence in localized areas ("signal flooding").            | Medium | High        | Apply spatial-temporal deduplication and hotspot collapse logic during lifecycle processing.         |
| R-007   | Replica lag exceeds refresh interval, serving outdated risk data to API consumers.                     | Medium | Medium      | Monitor replication delay and enforce lag < refresh interval threshold.                              |
| R-008   | Derived tables become coupled to manual fixes, preventing deterministic rebuild from `events_log`.   | High   | Low         | Enforce rebuild drills and prohibit manual edits to derived state.                                   |
| R-009   | Analytical workloads executed on primary database interfere with lifecycle and ingestion throughput.   | Medium | Medium      | Route analytics to replicas or exported datasets only.                                               |
| R-010   | Client-side feature creep attempts to replicate backend scoring, causing logic drift across platforms. | Medium | Medium      | Maintain backend-authoritative computation and restrict client to visualization and transport roles. |

---

## Risk Interpretation

The primary threats to UDIE are not UI bugs or framework issues.

They are architectural regressions that:

* increase data touched per request,
* break lifecycle decay assumptions,
* or destroy reproducibility.

Operational discipline is therefore the main mitigation mechanism.
