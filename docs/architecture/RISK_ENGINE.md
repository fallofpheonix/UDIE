# 🧠 UDIE Risk Computation Engine: Optimal Architecture

This document defines the internal mechanics of the UDIE Risk Engine, optimized for $O(\text{route\_cells})$ query evaluation regardless of historical event volume.

---

## 🏛️ 1. Core Design Invariant
To maintain planetary scale, the system enforces a strict separation between **Signal Ingestion** and **Risk Evaluation**.

- **Authoritative Ledger**: `events_log` (PostGIS).
- **Derived Projection**: `Redis Spatial Cache` (H3 discretized).
- **Query Path**: Reads ONLY from the Redis project. Projections are NEVER recomputed at query time.

---

## 🗺️ 2. Spatial Discretization (H3)
UDIE uses the **H3 Hierarchical Indexing System** to represent the urban risk field.
- **Resolution 9** (~0.17 km diameter) is used for the active risk grid.
- **Resolution 6** (~20 km diameter) is used for geographic sharding and bus partitioning.

### In-Memory Grid Model
Each cell in Redis is stored as a scalar Float32 representing the normalized risk weight.
- **Key**: `udie:risk:v1:<h3_index>`
- **Value**: `0.0 - 1.0` (Normalized Risk Intensity).

---

## 🔄 3. Update Pipeline (KDE Ingestion)

When a signal arrives, the **Risk Computation Engine** performs a Signal-to-Heat transformation:

1. **Geo-to-H3**: Convert signal $(lat, lng, W)$ to a center H3 cell.
2. **K-Ring Expansion**: Identify all cells within the signal's influence radius (e.g., $k=3$ rings).
3. **Radial Kernel Weighting**: For each cell $i$ in the ring, apply the decay kernel:
   $$Risk_i += W \cdot e^{-d(center, i) / \lambda}$$
4. **Atomic Materialization**: Update the Redis cache using pipelined atomic increments.

---

## ⏳ 4. Temporal Decay & Diffusion

Disruptions are not permanent. The engine maintains field stability through periodic pulses:

### 4.1 Temporal Decay
Every $T$ seconds, a background worker applying a global decay factor:
$$Risk(t + \Delta t) = Risk(t) \cdot e^{-\Delta t / \tau}$$
This ensures the field naturally returns to a zero-risk base state without manual intervention.

### 4.2 Spatial Diffusion
To smooth discontinuities, a smoothing pulse is applied:
$$Risk_{smooth} = (1 - \alpha) \cdot Risk_{center} + \alpha \cdot \text{avg}(Neighbors)$$

---

## 🛣️ 5. Route Evaluation Strategy ($O(N)$)

API queries for route risk are deterministic and bounded:

1. **Polyline Coverage**: Convert the route polyline into a list of traversed H3 cells.
2. **Parallel Lookup**: Batch read the risk scalars for all $N$ cells from Redis.
3. **Aggregate**: Sum or average the risk scalars.
4. **Complexity**: Total cost is $O(\text{route\_cells})$, completely independent of the millions of events stored in the `events_log`.

---

MIT © 2026 **UDIE Engineering Group**. 
"One grid, one truth, sub-millisecond intelligence."
