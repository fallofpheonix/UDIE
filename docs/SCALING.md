
# UDIE Scaling Readiness Requirements

Scaling must occur through clean geographic partitioning of workload while preserving a single authoritative database.

The objective is to ensure that spatial regions behave as independent computational domains.

---

## 1. Spatial Partitioning Strategy

Core tables must be partitioned using a stable geographic key derived from the H3 hierarchy.

### Partition Key

Use a coarse H3 parent index (e.g., Resolution 6):

<pre class="overflow-visible! px-0!" data-start="671" data-end="716"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>h3_parent</span><span> = h3_to_parent(h3_index, </span><span>6</span><span>)
</span></span></code></div></div></pre>

### Tables Requiring Partitioning

* `events_log`
* `events_active`

### Implementation Model

<pre class="overflow-visible! px-0!" data-start="813" data-end="854"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre! language-sql"><span><span>PARTITION</span><span></span><span>BY</span><span> LIST (h3_parent);
</span></span></code></div></div></pre>

### Purpose

* Enables partition pruning during queries.
* Restricts lifecycle and aggregation work to region-local data.
* Prevents global index growth.

---

## 2. Localized Risk Materialization

Risk aggregation must occur per geographic partition, not globally.

Each partition maintains its own derived surface:

<pre class="overflow-visible! px-0!" data-start="1174" data-end="1201"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span><span class="language-xml">risk_cells_<region</span></span><span>>
</span></span></code></div></div></pre>

### Benefits

* Independent refresh scheduling.
* Parallel materialization without cross-region contention.
* Predictable aggregation cost per region.

---

## 3. Read Isolation via Replication

Introduce read replicas early to separate evaluation workloads from write-heavy lifecycle processing.

| Role    | Allowed Operations                                 |
| ------- | -------------------------------------------------- |
| Primary | Ingestion, lifecycle updates, materialization      |
| Replica | `/events`,`/risk`reads, diagnostics, analytics |

Replicas must not execute lifecycle or aggregation writes.

---

## 4. Geographic Request Scoping

Every API request must resolve its geographic partition before executing database queries.

### Required Flow

<pre class="overflow-visible! px-0!" data-start="1891" data-end="2006"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>incoming request
→ derive H3 parent region
→ route query </span><span>to</span><span> scoped </span><span>partition</span><span>
→ </span><span>execute</span><span></span><span>partition</span><span>-pruned </span><span>SQL</span><span>
</span></span></code></div></div></pre>

Unscoped spatial queries are prohibited because they defeat partition pruning.

---

## 5. Cross-Partition Independence Validation

Simulated heavy activity in one region must not impact others.

### Validation Test

* Apply ingestion + query load to Region A.
* Measure latency, refresh duration, and buffer usage in Region B.

### Acceptance Condition

No measurable degradation outside the stressed region.

---

## 6. Region-Aware Caching Discipline

Any caching layer must include region identity in cache keys.

Example:

<pre class="overflow-visible! px-0!" data-start="2536" data-end="2567"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>risk:{region}:{cell_id}
</span></span></code></div></div></pre>

This prevents cache pollution and maintains partition independence.

Caches remain disposable and must not contain authoritative state.

---

## 7. Region as the Unit of Scale

Scaling is defined by adding geographic regions, not enlarging shared infrastructure.

Each region must have bounded operational characteristics:

* maximum active events
* maximum refresh duration
* maximum concurrent evaluations

### Expansion Model

<pre class="overflow-visible! px-0!" data-start="2999" data-end="3092"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>add</span><span> region
→ </span><span>allocate</span><span> worker capacity
→ </span><span>begin</span><span> independent lifecycle </span><span>+</span><span> materialization
</span></span></code></div></div></pre>

No global reconfiguration should be required.

---

## Acceptance Condition for “Scaling Ready”

The system is considered scaling-ready when:

1. Queries consistently prune to a single geographic partition.
2. Materialization can run concurrently across regions.
3. Resource usage scales with region count, not total dataset size.
4. Regions can be added without modifying existing partitions.

---

## Intent

Scaling readiness ensures that UDIE expands by replication of bounded spatial units rather than by increasing the complexity of a shared monolith.
