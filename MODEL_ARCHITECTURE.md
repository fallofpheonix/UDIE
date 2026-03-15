# Model Architecture

UDIE uses a **Deterministic Spatial Model** to represent urban risks. It avoids stochastic black-box models in favor of verifiable spatiotemporal fields.

## 📐 Spatial Intelligence Model (SIM)

The core model treats disruption as a scalar field $R(s, t)$ defined over the H3 grid.

### 1. Discretization
Geography is discretized using the H3 Hierarchical Hexagonal Indexing system.
- **Resolution 9**: Primary cell size for risk evaluation.
- **Resolution 6**: Primary cell size for geographic sharding and partitioning.

### 2. Risk Evaluation Function
The risk at any point is the sum of weighted influences from proximate events:
$$R_{total} = \sum_{i \in \text{Events}} w_i \cdot K(d_i) \cdot e^{-(t-t_i)/\tau}$$
Where $K(d)$ is the spatial kernel and $\tau$ is the temporal decay constant.

### 3. Saturation Kernel
To ensure system stability, raw risk is saturated:
$$R_{saturated} = 1 - e^{-R_{total} / k}$$

## 🔮 Predictive Forecasting

Future risk ($T+X$) is projected by analyzing:
- **Diffusion Vectors**: How disruption energy is currently spreading between adjacent cells.
- **Historical Recurrence**: High-score periods observed in saved `risk_snapshots`.
- **Trend Gradients**: Recent growth or decay rates in cell weights.

## ⚖️ Stability Requirements

- **Convergence**: Replay from the same event log must always yield the same risk surface.
- **Consistency**: Adjacent partitions (Res 6) must maintain continuous fields across boundaries.
- **Verifiability**: Every risk score must be explainable via the contributing events and decay parameters.
