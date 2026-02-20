# ⚠️ UDIE Critical Warnings & Fatal Errors

This document lists actions that will **break or degrade** the UDIE spatial intelligence engine. Refer to `GUARDRAILS.md` for the underlying laws.

## 🛑 DANGER: Fatal Architectural Errors (Do Not Commit)

### 1. Direct Writes to `geo_events`
- **Violation**: Manually inserting rows into `geo_events` or bypassing `events_log`.
- **Consequence**: Total loss of determinism; system cannot be rebuilt from logs.
- **Rule**: All data MUST flow through `IngestionService` -> `upsert_geo_event_v2`.

### 2. Sequential Scans in Hot Path
- **Violation**: Changing the risk query to scan raw event geometries without H3 cell joins.
- **Consequence**: Latency explosion as dataset grows ($O(N)$ vs $O(Cells)$).
- **Rule**: `/risk` must touch only pre-aggregated `risk_cells`.

### 3. Hardcoding Model Constants
- **Violation**: Writing $\lambda$, $R$, or $k$ constants directly into code.
- **Consequence**: Loss of reproducibility and inability to tune without a full deploy.
- **Rule**: Fetch all math parameters from the `model_parameters` table.

---

## ⚠️ WARNING: Risky Behaviors (Requires Review)

### 1. Casual Resolution Shifts
- **Warning**: Changing H3 resolution (e.g. Res 9 to 10) without a full rebuild plan.
- **Impact**: All historical risk scores and materialized aggregates become mathematically incompatible.

### 2. Analytical Leakage
- **Warning**: Running complex `GROUP BY` or `COUNT(*)` on the primary database during ingestion spikes.
- **Impact**: Starves the IOPS required for real-time risk scoring and WAL flushing.

### 3. Masking via Caching
- **Warning**: Treating Redis as the "source of truth" to hide slow DB performance.
- **Impact**: Redis is disposable. If the system fails without it, the architecture is broken.

---

## 👩‍💻 Developer Checklist
- [ ] Did I add any hardcoded math? (Reject)
- [ ] Does this change increase rows scanned per route? (Stop)
- [ ] Is input complexity bounded ($MAX\_VERTICES$)? (Check)
