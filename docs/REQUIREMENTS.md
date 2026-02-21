
# UDIE System Requirements

This document specifies the functional, performance, and operational constraints that define correct behavior of the UDIE spatial intelligence substrate.

These are system-level requirements.

Implementation details may change, but these properties must remain invariant.

---

## 1. Functional Requirements

### 1.1 Route Risk Evaluation

The system must compute a normalized risk score for arbitrary routes subject to bounded input constraints.

* Maximum supported route length: **50 km**
* Evaluation must operate exclusively on the materialized spatial surface (`risk_cells`).

---

### 1.2 Event Lifecycle Management

Disruption signals must evolve automatically through:

1. creation from observation,
2. reinforcement through repeated reports,
3. confidence decay over time,
4. expiry when below relevance threshold.

Manual lifecycle control is not permitted.

---

### 1.3 Immutable Ingestion Ledger

Every incoming observation must be written to the append-only log (`events_log`).

* No updates or deletions allowed.
* All derived state must be reconstructible from this ledger.

---

### 1.4 Spatial-Temporal Deduplication

Observations describing the same disruption must merge when they satisfy configured proximity constraints (e.g., ~25 m, ~30 min window).

This prevents duplicate amplification of risk.

---

### 1.5 Spatial Transparency

Risk evaluation must expose interpretable metadata, including:

* contributing spatial cells,
* contributing event counts,
* normalized score components.

The system must remain explainable without inspecting raw geometries.

---

## 2. Performance Requirements

### 2.1 Bounded Query Complexity

Request-time evaluation must scale with spatial scope only:

<pre class="overflow-visible! px-0!" data-start="1938" data-end="1983"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>Complexity</span><span> = O(number_of_route_cells)
</span></span></code></div></div></pre>

Latency must not grow with:

* total historical observations,
* size of `events_log`,
* cumulative active disruptions.

---

### 2.2 Refresh Completion Guarantee

Materialization cycles must complete within a bounded fraction of the refresh interval.

<pre class="overflow-visible! px-0!" data-start="2237" data-end="2287"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>refresh_duration</span><span> ≤ </span><span>0</span><span>.</span><span>25</span><span> × refresh_interval
</span></span></code></div></div></pre>

Failure indicates insufficient aggregation capacity.

---

### 2.3 Load Isolation

High ingestion rates must not materially degrade read-path latency.

Lifecycle processing, aggregation, and query serving must remain operationally isolated.

---

## 3. Operational Requirements

### 3.1 Deterministic Rebuild Capability

At any time, the system must be able to:

1. drop all derived tables,
2. replay `events_log`,
3. regenerate `events_active` and `risk_cells`,
4. produce equivalent evaluation outputs within defined tolerance.

---

### 3.2 Observability of Background Processes

All managed jobs must record execution metadata to `system_state`, including:

* last execution time,
* duration,
* status.

Unobservable background processing is not acceptable.

---

### 3.3 Geographic Scaling Axis

Horizontal scale must be achieved through spatial partitioning (H3 hierarchy), not through monolithic dataset growth.

Each region must be independently materializable and evaluable.

---

### 3.4 Input Safety Constraints

The system must enforce limits on request geometry to prevent pathological workloads.

Examples:

* maximum vertex count,
* maximum route length,
* bounded evaluation area.

---

## 4. Data Model Invariants

These invariants must always hold regardless of implementation changes.

---

### 4.1 Log Is the Sole Source of Truth

All derived tables are projections of `events_log` and may be dropped without data loss.

---

### 4.2 Confidence Is Temporally Bounded

No disruption remains permanently active without reinforcement.

Decay ensures the active dataset reflects current conditions.

---

### 4.3 Read Path Uses Aggregated Buckets Only

The request path must never evaluate raw geometries directly.

All joins occur against pre-aggregated spatial buckets (`risk_cells`).

---

## Summary

UDIE is defined not by its APIs or UI, but by these constraints:

* append-only ingestion,
* lifecycle-managed state,
* spatial aggregation before evaluation,
* bounded request-time complexity,
* deterministic rebuildability.

Any implementation that violates these properties is not a valid UDIE system.
