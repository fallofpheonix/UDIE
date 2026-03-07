# 📊 UDIE Web Admin Dashboard

A high-density operational interface for monitoring nationwide disruption intelligence and managing the UDIE substrate.

⸻

## 🕹️ Capabilities
- **City Monitoring**: Real-time H3-integrated heatmaps of urban disruption fields.
- **System Health**: Visibility into materialization lag, worker heartbeats, and DB contention.
- **Scenario Simulation**: Request-time "What If?" simulations against the isolated `simulation_events` layer.
- **Analytics**: Historical playback of `risk_snapshots` for spatiotemporal trend analysis.

⸻

## 🚀 Local Access
The dashboard is a static web application that connects to the **UDIE Engine API**.

1. **Configure API**: Update `js/config.js` with your backend endpoint (Default: `http://localhost:3000/api/v1`).
2. **Serve**:
   ```bash
   npx serve .
   ```

⸻

## 🏛️ Integration
The dashboard consumes the following endpoints defined in the [**API Specification**](../docs/API.md):
- `GET /city-dashboard`
- `GET /health/ready`
- `GET /diagnostics/architecture`

⸻

MIT © 2026 **UDIE Engineering**. 
"Visibility is the first step toward stability."
