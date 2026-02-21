
# UDIE Architectural Guardrails (20 System Laws)

These laws define the non-negotiable invariants required to keep UDIE computationally bounded, reproducible, and scalable.

They are not guidelines.

They are constraints that must hold for the architecture to remain valid.

Any change violating these laws must be rejected or treated as an architectural redesign.

---

## I. Hot-Path Evaluation Constraints

These laws protect bounded request-time complexity.

**Law 1 — No Raw Event Evaluation**

Risk must never be computed directly from `events_active` or `events_log` during API requests.

All evaluation must use the materialized surface (`risk_cells`).

**Law 2 — Bucket-Based Intersection Only**

Queries must operate on H3 cell mappings, not geometric overlap functions (`ST_Intersects`, `ST_DWithin`, etc.) in the hot path.

**Law 3 — Latency Independence from History**

Request latency must remain approximately constant as total stored history grows.

Evaluation complexity must scale with:

<pre class="overflow-visible! px-0!" data-start="1238" data-end="1267"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>number_of_route_cells</span><span>
</span></span></code></div></div></pre>

---

## II. Ingestion and Source-of-Truth Discipline

These laws preserve determinism and replayability.

**Law 4 — Append-Only Ingestion**

All incoming observations must be written to `events_log` (formerly `raw_events`).

Updates and deletes are prohibited.

**Law 5 — Active State Is Derived**

`events_active` is a projection computed from the log.

Direct mutation outside lifecycle processing is forbidden.

**Law 6 — No Bypass Paths**

Every data source must follow the ingestion contract.

No external system may insert directly into derived tables.

---

## III. Lifecycle and Temporal Integrity

These laws prevent dataset inflation and stale-state accumulation.

**Law 7 — Mandatory Temporal Decay**

Every event must lose confidence over time unless reinforced.

**Law 8 — No Permanent Signals**

Confidence must trend downward in the absence of new observations.

Persistent influence requires repeated reinforcement.

**Law 9 — Asynchronous Expiry Enforcement**

Expiry must occur via scheduled lifecycle processing, not request-time filtering.

---

## IV. Scaling Model (Geography-First)

These laws define how the system grows.

**Law 10 — Scale by Spatial Partitioning**

Growth must occur through geographic segmentation (H3 hierarchy), not monolithic expansion.

**Law 11 — Region Independence**

Workload in one region must not materially affect latency or refresh behavior in another.

**Law 12 — Localized Materialization**

Each region materializes its own risk surface.

Global aggregation is prohibited.

---

## V. Mathematical Integrity and Reproducibility

These laws ensure the model remains auditable and stable.

**Law 13 — No Hardcoded Parameters**

Decay rates, normalization constants, and thresholds must be stored in configuration tables (`model_parameters`).

**Law 14 — Deterministic Rebuild Requirement**

Replaying `events_log` must reproduce equivalent `risk_cells` output within defined tolerance.

**Law 15 — Versioned Model Semantics**

Any change to scoring behavior requires explicit parameter versioning.

---

## VI. Safety and Workload Isolation

These laws bound computational exposure and protect operational stability.

**Law 16 — Bounded Input Geometry**

Requests must enforce limits on route length and vertex count to prevent adversarial workloads.

**Law 17 — Operational vs Analytical Separation**

OLTP workloads must remain isolated from analytical queries through replicas or exports.

**Law 18 — Refresh Must Complete Within Cycle**

Aggregation must consistently finish before the next scheduled refresh.

If refresh overlaps, scaling discipline is broken.

---

## VII. Observability and State Ownership

These laws ensure the system remains inspectable and recoverable.

**Law 19 — Operational Visibility Is Mandatory**

Lifecycle, aggregation, and ingestion jobs must expose metrics and execution state.

Silent background work is not allowed.

**Law 20 — Logs Are Truth; Everything Else Is Rebuildable**

Only `events_log` is authoritative.

All derived layers (`events_active`, `risk_cells`, caches) must be disposable and reconstructible.

---

## Design Heuristic (Derived From All Laws)

If a proposed change increases the amount of data touched per request, it is architecturally incorrect.

---

## Purpose of These Guardrails

These constraints prevent UDIE from devolving into an unbounded geospatial query system and ensure it remains:

* computationally predictable
* reproducible from history
* spatially partitionable
* operationally maintainable
