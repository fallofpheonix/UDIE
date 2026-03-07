# UDIE Disruption Intelligence Models (v1.0)

This document defines the **statistical and machine learning models** used by the Universal Disruption Intelligence Engine to detect disruptions, forecast spread, and support tactical decision-making.

---

## 1. Intelligence Model Stack

UDIE uses a multi-layer intelligence system that transforms spatial telemetry into actionable insights.

### 1.1 The Pipeline
`Raw Events` → `Spatial Aggregation (H3)` → `Anomaly Detection` → `Risk Scoring` → `Spread Prediction` → `Simulation Engine` → `Decision Support`.

---

## 2. Anomaly Detection Models

### 2.1 Z-Score Baseline (Law 1)
Identifies deviations from historical norms using standard deviation thresholds.
*   **Moderate Anomaly**: $|z| > 2.0$
*   **Severe Anomaly**: $|z| > 3.0$

### 2.2 Spatial Cluster Detection (DBSCAN)
Groups localized events to identify emerging disruption epicenters.
*   **Parameters**: `eps` (radius in meters), `min_samples` (minimum events to form a cluster).

---

## 3. Spatial Diffusion Model (Law 5)

Disruptions propagate through the H3 grid based on physical adjacency and temporal momentum.

### 3.1 Diffusion Kernel
The risk in cell $c$ at time $t+1$ is modeled as:
$$R_{c, t+1} = R_{c, t} + \alpha \sum_{n \in N(c)} (R_{n, t} - R_{c, t}) - \lambda R_{c, t}$$
Where:
*   $\alpha$ is the diffusion constant (spread rate).
*   $\lambda$ is the decay constant (dissipation).

---

## 4. Operational Prediction & Simulation

### 4.1 Trajectory Prediction
Directional vectors based on event momentum and road network connectivity.
*   **Visual Encoding**: Line thickness = Probability; Glow = Severity.

### 4.2 Simulation Engine (Pokes)
Allows operators to inject "Hypothetical Disruptions" and observe predicted spread before deploying resources.
*   **Latency Target**: Simulation results rendered in < 500ms.

---

## 5. Model Confidence & Safety
Every prediction must include a **Confidence Score** [0.0 - 1.0].
*   **Constraint**: Never suppress confirmed incidents, regardless of model confidence.
*   **Fallback**: In cases of low data density, the system defaults to conservative "High Alert" states.
