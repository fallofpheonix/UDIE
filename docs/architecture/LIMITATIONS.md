# 🚩 UDIE: System Boundaries & Limitations

Transparency on the current mathematical and technical horizons of the Urban Disruption Intelligence Engine.

⸻

## 1. Isotropic Spatial Decay
The current risk kernel assumes risk propagates equally in all directions (Euclidean decay).
- **Reality**: Does not yet account for urban morphology (buildings, wind direction, or topography).
- **Roadmap**: Integration of non-isotropic kernels and urban canyon models (Phase 3).

## 2. Scalar Field Discretization
Evaluation is constrained by the **H3 Resolution 9** grid size (~0.1 km²).
- **Reality**: Disruptions smaller than the cell area are treated as cell-wide averages.
- **Roadmap**: Dynamic resolution scaling (Res 10/11) for ultra-dense urban cores.

## 3. Network Topology Agnostic
Risk is currently modeled as a spatial field potential, not as a flow through a graph.
- **Reality**: Road closures affect their immediate spatial proximity but do not yet "flow" downstream along the street graph topology.
- **Roadmap**: OpenStreetMap graph-constrained risk propagation (Phase 4).

## 4. Passive Processing
The engine is currently reactive, processing signals as they manifest in the `events_log`.
- **Reality**: No proactive prediction of "developing anomalies" before they materialize.
- **Roadmap**: Predictive field evolution (T+60min) via temporal forecasting (Phase 5).

⸻

MIT © 2026 **UDIE Engineering**. 
"Boundaries are not barriers, they are the edges of the map we are drawing."
