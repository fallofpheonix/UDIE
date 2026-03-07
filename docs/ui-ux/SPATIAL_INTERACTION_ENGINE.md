# UDIE Spatial Interaction Engine (v1.0)

This document defines the **rendering pipeline, interaction mechanics, and performance constraints** for the spatial intelligence interface of the Universal Disruption Intelligence Engine.

---

## 1. Spatial Rendering Pipeline

The map uses a **Layered Vector Pipeline** with strict priority and blending rules.

### 1.1 Layer Hierarchy (Top to Bottom)
| Layer | Name | Type | Blending | Rendering Rules |
| :--- | :--- | :--- | :--- | :--- |
| **L5** | Interaction HUD | SVG/Web | N/A | Highest priority; mouse/touch targets. |
| **L4** | Simulation Overlays | GeoJSON | Multiply | Blue tint over affected hexes. |
| **L3** | Agent Trajectories | LineString | Add | Glow intensity = probability. |
| **L2** | Tactical Markers | Symbol | N/A | Severity-based scaling; pulse animations. |
| **L1** | H3 Risk Surface | Hex Grid | Overlay (70%) | H3 grid encoded by Risk Score. |
| **L0** | Basemap | Vector Tile | N/A | Dark Material base. |

### 1.2 Blending Rules
*   **Tactical Markers** must always remain above the H3 Risk Surface.
*   **Trajectories** use additive blending to highlight "hot" paths without obscuring underlying cell IDs.
*   **H3 Surface** opacity is dynamic: `opacity = confidence_score * 0.8`.

---

## 2. H3 Resolution & LOD Mapping

To maintain 60FPS, H3 resolution scales dynamically based on Mapbox zoom levels.

| Zoom Level | H3 Resolution | Cell Count (Avg) | Optimization |
| :--- | :--- | :--- | :--- |
| **0 - 5** | Res 4 | ~100 | Full grid update. |
| **6 - 8** | Res 6 | ~1,000 | Vector tile tiling. |
| **9 - 11** | Res 7 | ~10,000 | Frustum culling enabled. |
| **12 - 14**| Res 8 | ~50,000 | WebGL Instanced Rendering. |
| **15+** | Res 9+ | Variable | Detail-on-demand (LOD). |

---

## 3. Map Interaction Model (Operational)

Operational analysts require comparison and multi-scale tools.

### 3.1 Multi-Selection (Shift + Drag)
*   Enables **Comparison Mode** in the Inspector Panel.
*   Aggregates metrics across the selected bounding box.
*   Triggers "Regional Anomaly" check.

### 3.2 Temporal Scrubbing
*   A persistent slider at the bottom mapped to `EventsService` projections.
*   **Horizon**: `-24h` (History) to `+1h` (Forecast).
*   **Interaction**: Changing time-t updates H3 Risk Surface and Trajectory layers in real-time.

---

## 4. Performance & Rendering Constraints
*   **Frame Budget**: < 16.6ms (60 FPS target).
*   **Max Polygons**: 100k polygons per view layer.
*   **GPU Shader**: H3 colorization (Risk Score → Color) must be handled by the GPU fragment shader, not the JS main thread.
*   **Tile Loading**: Use `h3-js` on-client for Res 9+ to avoid network bloat for local detail.
