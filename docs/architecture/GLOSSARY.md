# 📚 UDIE Glossary

This glossary defines the core terminology used across the UDIE spatial intelligence platform. Definitions reflect the system's spatial modelling, not generic GIS terminology.

⸻

## 🗺️ Spatial Terms

### H3 Index
A hierarchical hexagonal spatial index. In UDIE, H3 provides spatial discretization, geographic partitioning, and neighborhood queries. All evaluation operates on H3 cells.

### Spatial Bucket
A discrete H3 cell representing a geographic region where disruption influence is aggregated.

### Materialized Risk Surface
The derived `risk_cells` table. It represents disruption intensity aggregated across buckets, refreshed periodically and loaded into the in-memory grid.

### Distance Decay
A spatial weighting function: $\text{weight} = \text{base\_weight} \cdot \exp(-\text{distance} / \lambda)$. Prevents localized disruptions from influencing distant routes.

⸻

## 💾 Data Model Terms

### events_log
The immutable, append-only ingestion ledger. The source of truth for all derived system state and deterministic rebuilds.

### Lifecycle Processing
A scheduled transformation (temporal weighting, reinforcement, decay, pruning) that maintains signal relevance without accumulating historical noise.

### Materialization
The aggregation process: $\text{events\_log} \rightarrow \text{aggregation} \rightarrow \text{risk\_cells}$. Collapses signals into fixed spatial buckets.

⸻

## 🧠 Domain Terms

### GeoEvent
A processed disruption signal contributing to the spatial field, interpreted from raw observations.

### Severity
A magnitude representing the impact (e.g., accident, road block), defining the maximum potential influence of a signal.

### Confidence
A dynamic weighting factor representing signal reliability, evolved through reinforcement and temporal decay.

### Risk Score
The normalized disruption exposure calculated for a route: $\text{risk} = f(\text{cell\_weights}, \text{decay}, \text{normalization})$.

⸻

## ⚙️ System Behavior Terms

### Deterministic Rebuild
The ability to reconstruct system state from `events_log` and `model_parameters` with 1:1 parity results.

### Bounded Query Cost
Guarantee that request-time complexity depends only on route geometry: $O(\text{number\_of\_route\_cells})$. It does not scale with dataset size.

⸻

MIT © 2026 **UDIE Engineering**. 
"Precise language is the precursor to precise code."
