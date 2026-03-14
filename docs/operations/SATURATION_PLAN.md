
# UDIE Saturation Analysis Requirements

Scaling actions must be driven by observed physical limits, not speculative architecture changes.

This phase identifies which subsystem constrains throughput once the model is already computationally bounded.

---

## 1. Controlled Load Staircase

Apply incremental load increases to isolate the first failing resource.

### Load Dimensions

* **Ingestion Rate** (events/sec)
* **Concurrent `/risk` Queries**
* **Active Region Count**

Each dimension must be increased independently before testing combined pressure.

### Measurement Goal

Determine which resource saturates first:

* CPU
* Memory
* Disk I/O
* WAL bandwidth
* Lock contention

Scaling decisions must map directly to the first observed constraint.

---

## 2. Metric Collection Requirements

All measurements must be captured using database-native statistics and system-level telemetry.

### CPU Cost per Evaluation

Measure actual CPU time consumed per `/risk` request, excluding I/O wait.

Purpose: verify evaluation cost remains proportional to route complexity.

---

### WAL Throughput Under Ingestion

Track:

<pre class="overflow-visible! px-0!" data-start="1327" data-end="1380"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>WAL MB/min
</span><span>checkpoint</span><span> frequency
fsync latency
</span></span></code></div></div></pre>

During ingestion bursts, WAL growth must remain smooth rather than spiky.

---

### Memory Residency of Aggregated Surface

`risk_cells` must remain memory-resident under normal operation.

Target:

<pre class="overflow-visible! px-0!" data-start="1581" data-end="1619"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>shared_buffers hit ratio ≥ </span><span>95</span><span>%</span><span>
</span></span></code></div></div></pre>

Frequent disk reads indicate aggregation size has exceeded working memory assumptions.

---

## 3. Regional Independence Validation

Stress a single geographic region while observing unaffected regions.

### Test Condition

Apply heavy ingestion and evaluation load to **Region A** while measuring:

* query latency in Region B
* refresh duration in Region B
* buffer churn across partitions

### Failure Indicators

* shared index contention
* global lock amplification
* cache eviction affecting unrelated regions

Regions must behave as isolated workloads.

---

## 4. Refresh Scalability Characterization

Measure how aggregation time changes as the number of active regions increases.

Plot:

<pre class="overflow-visible! px-0!" data-start="2319" data-end="2360"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>refresh_duration</span><span> vs. region_count
</span></span></code></div></div></pre>

### Expected Behavior

Linear growth indicates correct partition-local aggregation.

Superlinear growth indicates shared-resource coupling or inefficient aggregation logic.

---

## 5. Stability Soak Test (72 Hours)

Run sustained mixed workload to detect gradual degradation not visible in short tests.

### Monitor For

* Index bloat growth
* Autovacuum lag
* Refresh interval drift
* Memory fragmentation
* Increasing WAL replay delay on replicas

The goal is to detect slow failure modes.

---

## 6. Saturation Report (Decision Artifact)

The final output of this phase is an evidence-based scaling plan.

It must identify:

* first saturated subsystem,
* utilization curve approaching saturation,
* safe operating envelope,
* recommended scaling action tied directly to observed constraint.

No architectural change should be proposed without this report.

---

## Interpretation Principle

Scaling should only be introduced after confirming that:

1. The workload is already computationally bounded.
2. A specific physical resource is demonstrably exhausted.
3. The bottleneck cannot be resolved through tuning or partitioning.

Premature distribution increases complexity without improving capacity.
