# 🧪 UDIE Mathematical Appendix (v2.0)
## Formal Derivations and Spatiotemporal Stability Analysis

This appendix provides the formal mathematical substrate for the **Urban Disruption Intelligence Engine (UDIE)**. It derives the stability conditions, convergence properties, and error bounds for the spatial risk model under continuous event ingestion.

---

### A. Spatial Decay Kernel Stability (Discrete Correction)

The disruption intensity $\Phi$ at point $P$ is the superposition of influences from discretized H3 cells $c \in \mathcal{C}$. Unlike continuous models, the bound must account for the local cell density $\rho_c \approx 1/A_{cell}$:

$$\Phi(P) = \sum_{c \in \mathcal{C}} W_c \cdot e^{-\frac{d(P,c)}{\lambda}}$$

Assuming a maximum cell weight $W_{max}$ and uniform cell density $\rho_c$, the field $\Phi$ is bounded by the integral:

$$\Phi(P) \le W_{max} \cdot \rho_c \int_{0}^{2\pi} \int_{0}^{\infty} r \cdot e^{-r/\lambda} dr d\theta = 2\pi W_{max} \rho_c \lambda^2$$

**Impact of Resolution**: Since $A_{cell}$ varies with H3 resolution (e.g., Res 9 $\approx 0.1 km^2$), the field magnitude is resolution-dependent. The system must normalize $W_{max}$ against $\rho_c$ to maintain consistent risk scales across resolutions.

---

### B. Normalization and Sensitivity Control

The mapping from raw risk $R_{raw}$ to the normalized score $R_{norm} \in [0, 1)$ is defined as:

$$R_{norm} = f(R_{raw}) = 1 - e^{-\frac{R_{raw}}{k}}$$

**1. Convergence & Range**: As $R_{raw} \to \infty$, $R_{norm} \to 1$. For $R_{raw} \ge 0$, the range is $[0, 1)$.
**2. Sensitivity Control ($k$)**: The parameter $k$ determines the risk saturation rate. The sensitivity at the origin is $f'(0) = 1/k$. 
   - **Small $k$**: High sensitivity; the field saturates quickly (useful for high-priority urban cores).
   - **Large $k$**: Lower sensitivity; prevents risk "bloat" in dense event environments.
   - **Calibration**: $k$ must be empirically tuned against historical incident frequency to ensure $R_{norm} \ge 0.8$ represents a statistically rare disruption.

---

### C. Gradient Estimation on Non-Uniform H3 Grids

The disruption gradient $\nabla \Phi$ at cell $c$ is estimated via its 6 neighbors $\{n_i\}_{i=1}^6$:

$$\nabla \Phi(c) \approx \frac{2}{3D} \sum_{i=1}^6 \Phi(n_i) \mathbf{u}_i$$

**Approximation Limits**: While the coefficient $2/(3D)$ assumes a regular hexagonal lattice, H3 cells exhibit minor geometric distortions (especially near pentagons and across resolution boundaries). This estimator is a **first-order approximation** valid for $D \ll \lambda$. For higher precision, the system employs least-squares plane fitting across the k-ring.

---

### D. Route Energy and Local Error Bounds

Route risk $E(\Gamma)$ is the line integral $\int_{\Gamma} \Phi(s) ds$, approximated by discrete sampling $\Delta s$:

$$\hat{E}(\Gamma) = \sum_{j} \Phi(P_j) \Delta s$$

**Curvature Bound**: For the exponential kernel, the second derivative $|\Phi''|$ is maximized at the source ($d=0$), where $|\Phi''| \le \Phi_{max}/\lambda^2$. 
**Local Error**: The cumulative approximation error $\mathcal{E}$ is bounded by:
$$\mathcal{E} \le \frac{L}{12} (\Delta s)^2 \cdot \max |\Phi''(s)| \approx \frac{L}{12} \left(\frac{\Delta s}{\lambda}\right)^2 \Phi_{max}$$
**Constraint**: Precision is guaranteed when $\Delta s \ll \lambda$. If a route passes within $d < \Delta s$ of an event center, the error increases locally; thus, the simplification threshold is strictly capped at the H3 cell diameter.

---

### E. Spatiotemporal Stability & the Arrival Rate Constraint

To ensure the system remains bounded under continuous signal ingestion, we define the **UDIE Spatiotemporal Stability Condition**. Unlike static models, a real-time field must balance incoming signals against temporal decay ($\tau$).

**1. The Time-Evolving Field**:
$$\Phi(x,t) = \sum_i W_i \cdot e^{-d(x,x_i)/\lambda} \cdot e^{-(t-t_i)/\tau}$$

**2. The Global Field Bound**:
For an event arrival rate $r$ (events/sec) and maximum intensity $W_{max}$, the worst-case field magnitude $\Phi_{max}$ accumulates to:
$$\Phi_{max} \le 2\pi \rho_c r W_{max} \lambda^2 \tau$$

**3. The Stability Constraint**:
The system is numerically stable only if $\Phi_{max}$ remains below the saturation threshold $\Phi_{sat}$:
$$r < \frac{\Phi_{sat}}{2\pi \rho_c W_{max} \lambda^2 \tau}$$

**Interpretation**: Stability couples four parameters. Increasing spatial influence ($\lambda$) or temporal memory ($\tau$) quadratically/linearly reduces the maximum sustainable ingestion rate ($r$).

---

### F. Dynamic Field Evolution & Design Requirements

The system's long-term behavior is governed by the source-decay equation:
$$\frac{\partial \Phi}{\partial t} = -\frac{\Phi}{\tau} + \sum_i W_i K_s(x-x_i)$$

To satisfy this stability condition, the UDIE Substrate enforces **four design mandates**:
1. **Mandatory Temporal Decay ($\tau$)**: Essential to prevent $\Phi \to \infty$ over time.
2. **Signal Aggregation**: Spatial clusters must be merged into single representative kernels to reduce the effective arrival rate $r$.
3. **Kernel Radius Capping**: $\lambda$ is strictly bounded to prevent quadratic instability.
4. **Weight Normalization**: $W_i$ are scaled to $[0, 1]$ before ingestion to prevent singular destabilizing events.

---

### G. Numerical Considerations
- **Superposition Stability**: A final sigmoid filter $\sigma(\Phi)$ caps the field before normalization to prevent floating-point overflow during catastrophic clustering.
- **Quantization Error**: H3 spatial discretization introduces a maximum positional error of $r_{cell}$, mitigated by $k \ge 3$ neighboring cell inclusion.

⸻

MIT © 2026 **UDIE Engineering Group**. 
"Stability is not a property of the data, but a constraint of the model."
