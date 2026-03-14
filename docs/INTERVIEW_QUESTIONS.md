
# Interview Questions

These questions highlight architectural decisions behind UDIE.

They focus on system behavior, scaling guarantees, and lifecycle modeling rather than implementation details.

---

## Q1. Why is risk evaluation performed on the backend instead of the mobile client?

**Answer**

Risk evaluation depends on a continuously maintained spatial aggregation that must remain:

* deterministic,
* consistent across clients,
* independent of device capabilities.

The backend maintains lifecycle processing, spatial bucketing, and materialized aggregation (`risk_cells`).

Clients query this derived surface rather than recomputing risk locally.

Moving computation to the client would introduce:

* divergence in model behavior across platforms,
* inability to enforce decay and deduplication consistently,
* unbounded computation due to lack of controlled indexing and aggregation refresh.

The backend therefore acts as the authoritative spatial model.

---

## Q2. How does the client prevent excessive API calls during rapid map interaction?

**Answer**

The client treats event fetching as an interruptible operation.

When the visible region changes:

1. Any in-flight request is cancelled.
2. A debounce delay is applied before issuing the next request.
3. Only the final stabilized region triggers `/events`.

This ensures the backend receives queries proportional to user intent rather than gesture frequency, preventing unnecessary load amplification.

---

## Q3. What is the spatial risk model used by UDIE?

**Answer**

UDIE evaluates routes against a pre-aggregated spatial field rather than raw events.

At evaluation time:

<pre class="overflow-visible! px-0!" data-start="1870" data-end="1947"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>route → H3 cells → </span><span>join</span><span> risk_cells → apply distance decay → </span><span>normalize</span><span>
</span></span></code></div></div></pre>

Distance decay is applied to aggregated cell weights:

<pre class="overflow-visible! px-0!" data-start="2004" data-end="2068"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>score</span><span> = Σ(weight_cell × exp(-distance / decay_constant))
</span></span></code></div></div></pre>

Where `weight_cell` already represents merged severity and confidence contributions.

This separates expensive spatial aggregation (done asynchronously) from lightweight route evaluation (done per request).

---

## Q4. How is duplicate or noisy data handled during ingestion?

**Answer**

UDIE does not treat incoming observations as independent facts.

Instead, ingestion applies spatial-temporal merging rules:

<pre class="overflow-visible! px-0!" data-start="2485" data-end="2594"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>same </span><span>type</span><span>
</span><span>within</span><span> defined radius
</span><span>within</span><span></span><span>time</span><span></span><span>window</span><span>
→ reinforce existing event
</span><span>else</span><span> → </span><span>create</span><span></span><span>new</span><span> event
</span></span></code></div></div></pre>

This prevents duplicate reports from inflating risk artificially and allows confidence to evolve as reinforcement accumulates.

The append-only log preserves all observations, while the active projection represents the interpreted state.

---

## Q5. How does UDIE ensure the system remains scalable as data grows?

**Answer**

Scalability is achieved by shifting computation from request-time evaluation to continuous materialization.

Key mechanisms:

* Spatial bucketing using H3 to bound evaluation scope.
* Periodic aggregation into `risk_cells`.
* Query complexity proportional to route geometry, not dataset size.
* Geographic partitioning to isolate regional workloads.

This avoids the common failure mode where spatial queries degrade linearly with stored history.

---

## Q6. How can the system recover from failure or data corruption?

**Answer**

All derived state is disposable.

Recovery consists of:

1. Retaining `events_log` (append-only source).
2. Recomputing lifecycle projection (`events_active`).
3. Rebuilding aggregated surface (`risk_cells`).

Because evaluation depends only on derived tables, deterministic rebuild ensures recovery without manual reconciliation.

---

## Q7. Why is lifecycle decay necessary instead of keeping all historical disruptions active?

**Answer**

Urban disruptions are transient signals.

Without decay:

* stale events accumulate indefinitely,
* risk scores drift upward,
* dataset size becomes unbounded.

Lifecycle decay ensures the active dataset reflects current conditions while historical observations remain preserved in the log.

---

## Purpose of These Questions

These questions validate understanding of:

* why UDIE is modeled as a continuously re-materialized spatial system,
* how bounded evaluation is maintained,
* how lifecycle processing replaces naïve CRUD-style geospatial storage.

They are intended to test reasoning about system design rather than framework knowledge.
