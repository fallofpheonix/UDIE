
# User Guide

This guide explains how to interact with the UDIE iOS client.

The application visualizes disruption intelligence computed by the backend. It does not perform risk analysis locally.

---

## 1. Viewing the Map

When the app opens, it displays your current location and nearby disruptions retrieved from the backend.

### Location Indicator

* Your position appears as a blue marker provided by iOS location services.

### Disruption Markers

Markers represent lifecycle-managed disruptions currently active in the system:

| Icon          | Meaning                                           |
| ------------- | ------------------------------------------------- |
| ⚠️ Triangle | High-impact disruption (e.g., accident, blockage) |
| 🚧 Barrier    | Construction or infrastructure work               |
| 💧 Drop       | Water-logging or flooding-related signal          |

Markers are derived from aggregated backend data, not individual user reports.

### Marker Clustering

At lower zoom levels, nearby disruptions are grouped into clusters to reduce visual overload.

* Tap a cluster or zoom in to view individual disruptions.
* Clustering is a visualization feature only and does not affect risk computation.

---

## 2. Requesting a Route Evaluation

To analyze a path:

1. Long-press a destination on the map.
2. The device generates a route using MapKit.
3. The route geometry is sent to the UDIE backend.
4. The backend evaluates disruption exposure and returns a risk score.

The client does not calculate risk locally.

---

## 3. Interpreting the Risk Card

After evaluation, a Risk Card appears summarizing backend results.

### Risk Classification

| Color     | Level  | Meaning                                     |
| --------- | ------ | ------------------------------------------- |
| 🟢 Green  | LOW    | Minimal disruption exposure detected.       |
| 🟠 Orange | MEDIUM | Noticeable disruptions along or near route. |
| 🔴 Red    | HIGH   | Concentrated disruption signals present.    |

This classification is derived from the normalized score returned by `/risk`.

### Additional Information

* Distance and duration are provided by MapKit routing.
* The progress bar visualizes relative disruption intensity along the evaluated path.

These values are descriptive, not predictive guarantees.

---

## 4. Connectivity Status

A status badge indicates whether the client is successfully retrieving live data.

| Status            | Meaning                                                                       |
| ----------------- | ----------------------------------------------------------------------------- |
| Backend Connected | Requests are reaching the UDIE API and data is current.                       |
| Sync Error        | The app cannot reach the backend. Displayed data may be stale or unavailable. |

If disconnected:

* Verify network connectivity.
* Ensure the backend service is running and reachable.

---

## Important Notes

* UDIE evaluates disruption exposure, not travel-time optimization.
* Results depend on available observations and lifecycle processing.
* The system is advisory and should be interpreted as environmental context rather than navigation instruction.
