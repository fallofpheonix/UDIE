# UDIE Interface Architecture (v1.0)

This document defines the structural layout, navigation hierarchy, and operator workflows for the **Universal Disruption Intelligence Engine (UDIE)**.

---

## 1. Application Layout & Surfaces

UDIE follows a **Tactical Command Center** layout, optimized for high data density and low latency interaction.

### 1.1 The Primary Canvas (Map)
The map is a multi-layered vector engine with explicit priority and blending rules.

#### Legend & Layer Priority (Top to Bottom)
| Layer | Name | Blending | Rendering Rules |
| :--- | :--- | :--- | :--- |
| **L6** | System HUD | SVG | Max priority; Z-Index 1000. |
| **L5** | Tactical Markers | Symbol | Pulse Red for critical incidents; No occlusion. |
| **L4** | Alerts & Overlays | Multiply | Neon glow intensity = Risk Severity. |
| **L3** | Agent trajectories | Additative | Glow paths; Pulse animation at impact nodes. |
| **L1** | H3 Risk Surface | Overlay | 70% Base Opacity; `opacity = confidence_score`. |
| **L0** | Basemap | Vector Tile | Dark Material base. |

### 1.1.1 H3 Resolution & LOD Mapping
To maintain 60FPS performance, H3 resolution scales dynamically.

| Zoom | H3 Res | Interaction Model |
| :--- | :--- | :--- |
| **4–6** | Res 4 | Macromap view; Grid aggregation. |
| **7-9** | Res 6 | Tactical view; Regional clusters. |
| **10-12**| Res 7 | Operational view; Neighborhood detail. |
| **13+** | Res 8+ | Forensic view; Cell-level drilldown. |
*   **Global Sidebar (Left)**: Collapsible navigation (Dashboard, Events, Intelligence, Simulation, Health).
*   **Operator Console (Bottom)**: Real-time ReAct stream and system telemetry.
*   **Inspector Panel (Right)**: Detail view for selected H3 cells or Event entities.

---

## 2. Navigation Hierarchy

```
Home (Tactical Map)
├── Dashboard (City-wide Health Metrics)
├── Insight Hub (Agent-generated reports)
├── Simulation Lab (Scenario Builder)
│   ├── Active Scenarios
│   └── Historical Playbacks
└── System Ops (Health, Logs, AOS Config)
```

---

## 3. Operator Workflows

### 3.1 Workflow: Incident Triage
1.  **Detection**: High-severity event appears on Map with "Pulse Red" glow.
2.  **Selection**: Operator clicks Event Marker; Inspector Panel opens.
3.  **Analysis**: Inspector shows "Projected Spread" (diffusion forecast) and "Agent Reasoning".
4.  **Mitigation**: Operator triggers Simulation poke to test mitigation strategies.

### 3.2 Workflow: Intelligence Review
1.  **Notification**: "Cyber Blue" badge on Insight Hub sidebar icon.
2.  **Drill-down**: Operator selects most recent Anomaly report.
3.  **Validation**: UI highlights affected H3 cells on primary map.

---

---

## 4. Map Interaction Model (Operational)

| Trigger | Action | Operational Result |
| :--- | :--- | :--- |
| **Hover (Cell)** | HUD Update | Shows cell H3 index and current Weight. |
| **Click (Cell)** | Drill-down | Inspector Panel opens to show time-series risk. |
| **Shift + Drag**| Multi-select | Enters Comparison Mode across bounding box. |
| **Long-press** | Poke Tool | Opens scenario injection widget at coordinates. |
| **Scroll** | Smooth Zoom | Scales H3 resolution (LOD transition). |

---

## 5. Temporal Navigation Layer
Operators must navigate time to understand evolution and forecast impact.

### 5.1 Temporal Scrubber (History)
*   **Range**: `-24h` to `Present`.
*   **Interaction**: Map state updates to "Snapshot" of selected timestamp.
*   **Visualization**: Desaturated risk surface to indicate "Historical Mode".

### 5.2 Forecast Slider (Future)
*   **Range**: `Present` to `+60m`.
*   **Source**: Driven by `forecast_cells` and agent trajectories.
*   **Visualization**: Neon "Pulse" effect on predicted disruption paths.

---

## 6. Alert Escalation & Visualization
Operational tools require clear escalation patterns to reduce cognitive load.

| State | Visual Trigger | Trigger Condition | UI Response |
| :--- | :--- | :--- | :--- |
| **Info** | Cyber Blue border | Normal deviation. | Log only. |
| **Warning** | Orange Pulse | Anomaly threshold > 2σ. | Auto-open Inspector on hover. |
| **Critical** | Pulse Red + Glow | Risk > 0.8 / Forecast Impact. | Flash Sidebar; Force focus. |
| **Failure** | Muted Noise | System delay > 10s. | Crosshatch pattern over H3 Grid. |

---

## 7. Agent Console (ReAct Stream) UI
The Agent Console is a persistent bottom drawer.
*   **Thought**: Text in standard body type, slightly faded.
*   **Action**: Monospace block (Bash/SQL/Tool Call).
*   **Observation**: Resulting data in a tabular or sparkline format.
*   **State**: Pulsating icon (Thinking 🌀, Acting ⚙️, Idle 💤).

---

## 8. Data Confidence & Reliability
Visualization of prediction trust.
*   **Transparency Mapping**: `cell.opacity = confidence_score`.
*   **Confidence Bands**: Trajectories include a "Gaussian Blur" width representing uncertainty.
