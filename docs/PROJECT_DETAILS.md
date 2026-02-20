# Project Details

## Problem Statement
Standard navigation focuses on the **fastest** route, often ignoring the **disruption landscape**. Urban environments are volatile: a road that was clear an hour ago could now be underwater or blocked by a protest. There is a lack of a unified, real-time "risk layer" that integrates with routing engines.

## Solution: UDIE
UDIE (Urban Disruption Intelligence Engine) solves this by:
1. **Intelligence over Speed**: Prioritizing disruption-aware routes.
2. **Server-Side Spatial Computing**: Using PostGIS to calculate proximity risk instead of taxing the mobile device.
3. **High-Fidelity UI**: Providing a premium mobile experience that visualizes risk levels (Low, Medium, High).

## Key Features
- **Spatial Proximity Risk**: Exponential distance decay ensures only nearby events impact the score.
- **Dynamic Normalization**: Heuristics that scale raw spatial weights into a human-readable 0-1 score.
- **Clustered Markers**: Clean map visualization even with hundreds of active events.
- **Backend-Native**: Single source of truth for risk logic across potentially multiple clients (iOS, Web, Android).
