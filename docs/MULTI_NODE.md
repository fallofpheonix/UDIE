
# UDIE Multi-Node Expansion Requirements

This document defines how UDIE scales beyond a single host while preserving PostgreSQL as the authoritative computation layer.

The objective is  **role isolation** , not distributed consensus.

All nodes operate against the same primary database and must not introduce divergent state.

---

## 1. Role Separation (Operational Trinity Model)

System responsibilities are divided into independent execution roles.

| Node Role         | Responsibilities                                                                | Characteristics          |
| ----------------- | ------------------------------------------------------------------------------- | ------------------------ |
| Ingestion Node    | Accept observations, append to `events_log`, perform merge, decay, and expiry | Write-heavy workload     |
| Materializer Node | Aggregate `events_active`into `risk_cells`per region                        | CPU-bound batch workload |
| Read API Node     | Serve `/risk`and `/events`using materialized surface                        | Read-only workload       |

This separation prevents lifecycle and aggregation activity from degrading query latency.

---

## 2. Coordinated Materialization (Advisory Lock Control)

Materialization must be globally coordinated to prevent concurrent aggregation of the same region.

### Mechanism

Use PostgreSQL advisory locks:

<pre class="overflow-visible! px-0!" data-start="1387" data-end="1437"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre! language-sql"><span><span>SELECT</span><span> pg_try_advisory_lock(region_id);
</span></span></code></div></div></pre>

Only the worker holding the lock may process that region.

### Execution Model

Workers operate in a pull-based loop:

<pre class="overflow-visible! px-0!" data-start="1558" data-end="1635"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>request assignment → acquire region </span><span>lock</span><span> → materialize → </span><span>release</span><span></span><span>lock</span><span>
</span></span></code></div></div></pre>

Cron-driven independent refresh is not permitted, as it risks overlapping work.

---

## 3. Mandatory Write Isolation

All UPDATE-intensive lifecycle operations must terminate on the ingestion node.

These include:

* spatial-temporal merge updates
* confidence decay adjustments
* expiry transitions
* projection maintenance of `events_active`

Read API nodes must execute  **no writes whatsoever** .

This prevents MVCC churn and buffer invalidation from impacting query-serving processes.

---

## 4. Streaming Replica Integration

Read scalability is achieved using PostgreSQL streaming replicas.

### Usage Model

* Primary database handles ingestion and lifecycle updates.
* Replicas serve `/risk` and `/events` queries.
* Materialization may run against the primary or a controlled write-capable node.

### Constraint

Replication delay must satisfy:

<pre class="overflow-visible! px-0!" data-start="2494" data-end="2548"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>replication_lag</span><span> < aggregation_refresh_interval
</span></span></code></div></div></pre>

This ensures users never observe risk surfaces older than one refresh cycle.

---

## 5. Failure Detection and Recovery

Materialization must be restart-safe.

If a worker crashes mid-refresh:

* Region lock is released automatically by PostgreSQL.
* Another worker may resume safely.
* Aggregation must be idempotent (re-running produces identical result).

No manual cleanup should be required after failure.

---

## 6. Definition of a Scale Unit

UDIE scales by replicating a standardized deployment unit.

### A Single Unit Contains

* 1 × Ingestion worker (write authority)
* 1 × Materialization worker (aggregation executor)
* 1 × Read replica (query-serving)
* N × Spatial partitions assigned to that unit

Scaling consists of adding additional units and assigning regions accordingly.

---

## 7. Explicit Non-Goals of This Phase

This architecture intentionally avoids:

* distributed PostgreSQL clusters
* multi-primary writes
* cross-node joins
* external stream-processing dependencies

These introduce coordination complexity before saturation justifies them.

---

## Summary

Multi-node expansion in UDIE is achieved through  **functional isolation and regional partitioning** , not by distributing state ownership.

The database remains the single authoritative system.

Nodes distribute workload, not truth.
