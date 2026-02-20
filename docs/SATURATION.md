# UDIE Saturation Analysis Requirements

Scaling decisions must be based on identified physical bottlenecks, not architectural guesswork.

## 1. Controlled Load Staircase
The system must be subjected to linear increases in load until saturation is reached.
- **Axes**: Ingestion Rate, Concurrent Queries, Region Count.
- **Monitoring**: Identify which resource fails first (CPU, Memory, IO, Locks, WAL).

## 2. Metric Specification
- **CPU Intensity**: Track actual CPU ms consumed per `/risk` request, isolated from IO wait.
- **WAL Throughput**: Monitor WAL generation rate (MB/min) and checkpoint frequency during ingestion bursts.
- **Memory Residency**: Maintain `shared_buffers` hit ratio > 95% for `risk_cells`. Spilling to disk is a failure condition.

## 3. Independence Validation (Stress Test)
Intense load in one geographic region (Region A) must not affect query latency or refresh performance in another (Region B).
- **Hidden Coupling**: Analyze for shared indexes, global locks, or buffer cache thrashing.

## 4. Refresh Scalability Curve
Plot the relationship between the number of active regions and materialization refresh duration.
- **Goal**: Linear growth is acceptable; superlinear indicates an aggregation bottleneck.

## 5. Stability Soak Test (72-Hour)
Continuous operation under sustained load to detect slow-rolling degradation.
- **Audit**: Index bloat, vacuum lag, refresh drift, and memory leakage.

## 6. The Saturation Report (The Scaling Blueprint)
The conclusive document that determines the next scaling phase:
- **Case A: CPU Saturated** -> Redesign math or scale out computation nodes.
- **Case B: IO/WAL Saturated** -> Redesign storage layer or implement further write-batching.
- **Case C: Locks Saturated** -> Redesign transaction scope or partition model.

"You only shard when the CPU is saturated and the workload is already perfectly bounded."
