# System Design & Theoretical Model

UDIE represents urban disruption as a spatiotemporal scalar field over a discretized hexagonal grid.

## 🧠 Core Theoretical Model

### 1. Spatial Discretization
Geography is partitioned into H3 cells (typically resolution 9). This converts continuous geographic coordinates into discrete, addressable units, enabling $O(1)$ lookups and consistent adjacency operations.

### 2. Risk Field Dynamics
- **Signal Injection**: Occurs when events are appended to the log.
- **Distance Decay**: Influence of an event follows a kernel function; proximate cells receive higher weight.
- **Temporal Decay**: Risk values decay exponentially over time: $R(t) = R_0 \cdot e^{-t/\tau}$.
- **Saturation**: To keep risk between $[0, 1)$, we apply $R_{norm} = 1 - e^{-R_{raw}/k}$.

## 🏗 Agent Runtime Architecture

UDIE employs a conceptual Agent System for internal diagnostics and forecasting:

- **Diagnostic Agents**: Audit system invariants, query plan safety, and data-plane health.
- **Forecasting Agents**: Compute T+X risk projections using historical snapshots.
- **Runtime Execution**: Agents are treated as stateless compute workers operating within a deterministic execution graph (DAG).

## 🔒 Security & Governance

- **Law of Simulation Isolation**: Simulation traffic is physically or logically separated from production ingestion.
- **Execution Jails**: Forecasting and diagnostic logic run in sandboxed adapters to prevent side-channel mutations.
- **Signal Invariants**: MITM or signal spam is mitigated through multi-source reinforcement and credibility decay.

## 📊 Modeling Boundaries

Current kernels prioritize operational speed over complex urban morphology (e.g., building-level occlusion). Stability and rebuildability are the primary engineering constraints.
