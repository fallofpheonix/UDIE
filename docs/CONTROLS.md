
# UDIE Engineering Discipline

UDIE requires continuous validation to prevent degradation of spatial correctness and performance over time.

These checks are mandatory operational routines.

They verify that the system still satisfies its core architectural guarantees.

Failure to execute these checks regularly will result in silent model drift, dataset inflation, or loss of bounded query cost.

---

## Weekly Verification Checklist

All three procedures must be executed at least once per week in a controlled environment.

---

## 1. Query Plan Audit

Validate that request-time evaluation remains bounded and does not regress into raw spatial scanning.

### Procedure

Run:

<pre class="overflow-visible! px-0!" data-start="882" data-end="949"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre! language-sql"><span><span>EXPLAIN (ANALYZE, BUFFERS)
</span><span>-- representative /risk query</span><span>
</span></span></code></div></div></pre>

### Requirements

* No sequential scan on `events_active` (or equivalent active-state table).
* Join operations must target `risk_cells` via indexed lookup.
* Query must not invoke repeated `ST_Distance`, `ST_DWithin`, or other geometry functions against the active dataset.
* Rows examined must scale with route complexity, not table size.

### Failure Indicators

* Appearance of `Seq Scan` in execution plan.
* Geometry calculations inside nested loops.
* Increase in scanned rows proportional to dataset growth.

These indicate regression toward an unbounded GIS query model.

---

## 2. Deterministic Rebuild Replay

Validate that derived spatial state remains reproducible from append-only history.

### Procedure

1. Drop derived tables:

<pre class="overflow-visible! px-0!" data-start="1697" data-end="1756"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre! language-sql"><span><span>DROP</span><span></span><span>TABLE</span><span> events_active;
</span><span>DROP</span><span></span><span>TABLE</span><span> risk_cells;
</span></span></code></div></div></pre>

2. Reconstruct state from `events_log`.
3. Re-run canonical route evaluations.
4. Compare outputs to pre-rebuild baseline.

### Requirements

* Rebuilt risk values must match baseline within defined tolerance.
* Row counts and spatial distribution must remain consistent.
* No manual correction steps allowed during rebuild.

### Failure Indicators

* Divergent risk scores.
* Missing or duplicated events.
* Rebuild requiring intervention.

These indicate loss of determinism or corruption of lifecycle logic.

---

## 3. Lifecycle Drift Audit (Confidence Decay Validation)

Ensure that temporal decay continues to bound dataset size and prevent stale accumulation.

### Procedure

Select sample events with no recent reinforcement and evaluate:

<pre class="overflow-visible! px-0!" data-start="2506" data-end="2545"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>confidence</span><span>(t+Δ) < </span><span>confidence</span><span>(t)
</span></span></code></div></div></pre>

Compute system-level metrics:

<pre class="overflow-visible! px-0!" data-start="2578" data-end="2674"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>active_events</span><span> / total_logged_events
average_confidence_trend
risk_distribution_over_time
</span></span></code></div></div></pre>

### Requirements

* Confidence must monotonically decrease for unreinforced events.
* Expiry transitions must occur without manual cleanup.
* Active dataset size must remain stable relative to ingestion volume.

### Failure Indicators

* Events persisting indefinitely.
* Gradual rise in average risk during low-activity periods.
* Increasing active dataset without proportional new ingestion.

These indicate lifecycle decay or expiry enforcement failure.

---

## Operational Interpretation

UDIE is not a static system.

It is a continuously re-materialized approximation of disruption state.

Correctness is maintained through disciplined recomputation and verification, not through immutability of derived data.

---

## Summary of Invariants Being Protected

These checks collectively ensure:

1. Request-time computation remains bounded.
2. Derived state remains reproducible from logs.
3. Temporal decay prevents dataset inflation.
4. Spatial aggregation remains the dominant evaluation mechanism.

If any of these invariants fail, the system must be corrected before new development proceeds.
