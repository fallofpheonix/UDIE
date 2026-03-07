# 📉 UDIE Failure Log

This log tracks technical failures, root causes, and resolutions to prevent regression and inform future incident response.

---

## [2026-03-07] - Network Misdiagnosis (Simulator vs Physical Device)
- **Symptom**: `Cannot connect to backend http://172.25.214.59:3000` from physical iPhone.
- **Root Cause**: The use of Internal Docker Bridge IP (172.x.x.x) which is not routable outside the host Mac.
- **Resolution**: Updated `AGENTS.md` and `SYSTEM_ASSUMPTIONS.md` to mandate Host Mac LAN IP for physical device testing. Added dynamic API prefix discovery to `APIClient`.
- **Reference**: `docs/incidents/incident_postmortem.md`

---

## [2026-03-07] - Derived Table Corruption (Risk Grid Drift)
- **Symptom**: "Direct mutation prohibited" errors in worker logs.
- **Root Cause**: Attempts to manually update `risk_cells` without setting the `udie.allow_derived_mutation` flag.
- **Resolution**: Enforced the "Event Log is Truth" invariant. Rebuild logic now strictly re-projects from `events_log`. Added `scripts/agent-bootstrap.sh` to prevent unauthorized schema changes.

---

## [2026-03-08] - API Prefix Mismatch
- **Symptom**: `404 Not Found` for documented endpoints.
- **Root Cause**: Inconsistent use of `/api/v1` vs `/api` prefixes between local Dev and CI/Production.
- **Resolution**: Implemented dynamic prefix discovery in the `agent-bootstrap.sh` and updated `API.md` (v2.0) to standardize on `/api/v1` with a discovery fallback.

---

MIT © 2026 **UDIE Engineering Group**. 
"One failure, one lesson, one invariant."
