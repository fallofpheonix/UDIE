# UDIE System Weaknesses & Technical Debt

This document brutally identifies the structural and mathematical flaws in UDIE. These are not "bugs"; they are architectural compromises that limit the system's accuracy and scaling ceiling.

## 1. Mathematical & Spatial Weaknesses

### 1.1 Linear Signal Aggregation
**The Flaw**: Risk weights are summed linearly ($Wc = \sum Se * Ce$).
**The Brutality**: The model assumes disruptions are independent. In reality, `flood + construction` has a combinatorial impact far greater than their sum. UDIE is blind to interaction effects, making it a "naive" accumulator rather than a true risk model.

### 1.2 Scalar Field Approximation
**The Flaw**: UDIE models disruption as a scalar field across H3 cells.
**The Brutality**: Transport disruptions are **network-constrained**, not field-continuous. A bridge closure is a binary gate on a graph, but UDIE models it as a "hot zone" in a hexagon. This introduces massive inaccuracy for routing engines that care about connectivity, not just proximity.

### 1.3 Fixed Resolution Artifacts
**The Flaw**: Hardcoded H3 Resolution 9 (~300m cells).
**The Brutality**: Large disruptions are "smeared" across cell boundaries, while micro-disruptions (a single pothole) occupy an entire 300m hexagon. This lack of adaptive resolution causes "risk cliffs" at cell boundaries and misrepresents the density of urban events.

### 1.4 Directional Blindness
**The Flaw**: Events have no orientation.
**The Brutality**: UDIE cannot distinguish between a blockage on the "Northbound" vs "Southbound" side of a highway. For a high-speed route, this renders the risk score potentially 50% irrelevant or dangerously misleading.

---

## 2. Architectural & Scaling Weaknesses

### 2.1 The PostgreSQL Bottleneck
**The Flaw**: Single-primary database architecture.
**The Brutality**: Despite "role separation," every signal eventually hits a single WAL (Write Ahead Log). At real urban scale (1M+ events/day), the primary will collapse under the weight of `events_log` writes and `risk_cells` materialization. UDIE is a "shared-disk" monolith pretending to be distributed.

### 2.2 Unbounded Rebuild Time
**The Flaw**: Rebuilds require replaying the entire `events_log`.
**The Brutality**: As time passes, the "Deterministic Rebuild" promise becomes an operational liability. Without partitioning or cold-storage snapshots, a multi-year rebuild will take days, rendering the "disposable derived state" claim practically false.

### 2.3 Parameter Calibration (The "Magic k" Problem)
**The Flaw**: Normalization depends on arbitrary constants (`SIGMOID_K`).
**The Brutality**: These constants are currently heuristics. Without a machine-learned ground truth backtest, `0.75` high risk is effectively a "gut feeling" codified into SQL. The system lacks a closed-loop feedback mechanism to tune these parameters against real outcomes.

### 2.4 Lack of Interaction Modeling
**The Flaw**: No cross-cell influence.
**The Brutality**: Risk is computed per-cell. A massive fire in cell A has zero impact on cell B until a point physically crosses the boundary. The "influence kernel" is localized to the route point sample, not the spatial field itself.

---

## 3. Immediate Technical Debt

- **No Multi-city Logic**: The `city_code` is present but partitioning logic is not enforced at the DB level.
- **Synchronous Ingestion**: Ingestion hits the DB directly; no message queue (Kafka/RabbitMQ) for spike absorption.
- **Weak Auth**: Identity management is a basic REST module, not a hardened OIDC/IAM integration.
- **Manual Calibration**: Every city requires a manual `SIGMOID_K` setting; there is no auto-leveling.
