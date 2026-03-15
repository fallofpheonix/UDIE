# Performance & Scaling

UDIE is optimized for real-time spatial evaluation at nationwide scale with deterministic latency.

## 🏎 Performance Targets (SLA)

| Operation | P99 Target | Law Enforced | Mechanism |
| :--- | :--- | :--- | :--- |
| **Cell Risk Lookup** | < 0.1 ms | Law 8 | Redis in-memory lookup. |
| **Route Evaluation** | < 5.0 ms | Law 2 | Sampled route-cell lookup. |
| **Grid Materialization** | < 500 ms | Law 1 | Async projection workers. |
| **State Rebuild** | < 30 s | Law 1 | PG/PostGIS optimized replay. |

## 📈 Scaling Strategies

### 1. Horizontal Spatial Sharding
The system scales by partitioning the globe into **H3 Resolution 6** shards. Each shard is an independent compute unit, allowing linear horizontal scaling without global lock contention.

### 2. Execution Isolation
- **Read Shards**: Dedicated to high-concurrency API evaluation using mirrored in-memory caches.
- **Write Shards**: Dedicated to ingestion normalization and authoritative log commits.

### 3. Query Optimization
Request-time logic is strictly constrained to prevent "Request-time aggregation" (Law of Hot Path Isolation). Complex spatial joins are performed during materialization, not during API requests.

## 📉 Known Bottlenecks

- **High-Density Saturation**: Extremely dense event clusters can increase materialization lag; mitigated by nonlinear saturation functions.
- **Cold Boot Latency**: Large regions require log replay to prime in-memory caches upon node startup.
