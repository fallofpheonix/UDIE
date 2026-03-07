# Incident Postmortem: UDIE Synchronization & Connectivity Failure (March 2026)

## 📋 Executive Summary
Between March 7 and March 8, 2026, the UDIE mobile application experienced persistent synchronization failures ("Connected • Not synced yet") and connectivity errors. The root cause was a combination of network misconfiguration (Docker/WSL bridge IPs), UI state-machine flaws, and API version drift between the client and backend.

---

## 🕒 Timeline & Phases

### Phase 1: Network Misdiagnosis
- **Symptom**: App UI reported `Cannot connect to backend http://172.25.214.59:3000`.
- **Root Cause**: The app was configured with a Docker bridge internal IP, which is not routable from outside the host machine.
- **Fix**: Updated `APIClient` to point to the host machine's LAN IP.

### Phase 2: UI State Logic Failures
- **Symptom**: The app showed "Connected" prematurely even when data fetching failed.
- **Root Cause**: The connection state was tied to the initialization of the `APIClient` rather than a successful server handshake.
- **Fix**: Introduced a granular `BackendSyncState` enum (`connecting`, `connected`, `syncing`, `synced`, `error`) and refactored `MapViewModel` to transition only on successful responses.

### Phase 3: API Route Version Drift
- **Symptom**: Health checks returned 404 errors.
- **Evidence**: Backend logs showed routes mapped to `/api/*`, while client expected `/api/v1/*`.
- **Root Cause**: Version mismatch in production deployments versus local development logic.
- **Fix**: Implemented `resolveAPIPrefix()` in `APIClient.swift` to dynamically probe both `/api/v1` and `/api` endpoints and cache the working result.

---

## 🛠 Root Cause Analysis: The Layered Failure
The March 2026 incident was not a single-point failure but a **Layered Failure** where multiple subsystems drifted or failed simultaneously:

1.  **Transport Layer (Network)**: Non-routable Docker bridge IPs were used instead of host LAN IPs.
2.  **API Contract Layer**: A version drift (`/api/v1` vs `/api`) caused 404s on reachable hosts.
3.  **Schema Layer**: Column mismatches (`last_run` vs `updated_at`) and missing tables prevented data materialization.
4.  **Worker Layer**: Mutation permissions (`allow_derived_mutation`) were not handled by background processors.
5.  **Startup Layer**: Workers attempted to connect to Postgres before the `condition: service_healthy` state was reached.

---

## 🏗 Mandatory Agent Diagnostic Architecture
To prevent this entire class of failure in the future, a mandatory diagnostic folder was established in `docs/agents/`. Agents must now verify the **Discovery -> Transport -> Contract -> Database -> Schema -> Worker** hierarchy before proposing code changes.

---

## 📝 Key Lessons
- **Verify the Transport Layer First**: Ensure the host is reachable before debugging application code.
- **Don't Assume Versioning**: Always probe for API capability if version drift is possible.
- **State Matters**: Never report "Connected" until the first successful data sync is confirmed.
