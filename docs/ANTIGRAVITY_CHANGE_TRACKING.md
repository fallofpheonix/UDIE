# Antigravity Change Tracking

This file defines how to track and record all changes contributed by Antigravity in UDIE.

## 1. Source of Truth for Change Records
Every Antigravity change must be recorded in these locations:

1. `/Users/fallofpheonix/Project/UDIE/docs/CHANGELOG.md`
- Record what changed and date/version.
- Use sections: `Added`, `Changed`, `Fixed`, `Removed`.

2. `/Users/fallofpheonix/Project/UDIE/docs/TASKS.md`
- Update task status (`[ ]` -> `[x]`) for completed work.
- Add new tasks for deferred follow-up.

3. Architecture-specific docs (when affected)
- `/Users/fallofpheonix/Project/UDIE/docs/ARCHITECTURE.md`
- `/Users/fallofpheonix/Project/UDIE/docs/GUARDRAILS.md`
- `/Users/fallofpheonix/Project/UDIE/docs/API_SPECIFICATION.md`
- `/Users/fallofpheonix/Project/UDIE/docs/UI_UX_DESIGN.md`
- `/Users/fallofpheonix/Project/UDIE/docs/BACKEND_WORKING.md`

4. PR safety checklist
- `/Users/fallofpheonix/Project/UDIE/.github/pull_request_template.md`
- Ensure all architecture invariant checkboxes are satisfied.

5. Architecture verification script
- `/Users/fallofpheonix/Project/UDIE/scripts/verify_architecture.sh`
- Run and keep output in PR description/notes.

---

## 2. Minimum Record Format Per Change
For each meaningful change, record:

- `Date` (YYYY-MM-DD)
- `Author` (Antigravity)
- `Area` (Backend / iOS / Docs / Infra)
- `Files touched`
- `Why` (problem solved)
- `What` (implementation summary)
- `Validation` (build/lint/tests/verification script)
- `Architecture impact` (None / Minor / Major)

---

## 3. Placement Rules (What goes where)

## Backend changes
Record in:
- `CHANGELOG.md`
- `BACKEND_WORKING.md` (if flow/logic changed)
- `API_SPECIFICATION.md` (if API behavior changed)
- `ARCHITECTURE.md` + `GUARDRAILS.md` (if invariants touched)

## iOS/UI changes
Record in:
- `CHANGELOG.md`
- `UI_UX_DESIGN.md`
- `TASKS.md`

## Infra / validation / scripts
Record in:
- `CHANGELOG.md`
- `CONTRIBUTING.md` (if contribution process changed)
- `scripts/verify_architecture.sh` output evidence in PR notes

---

## 4. Invariant Check (Must be explicit in every major update)
Before marking Antigravity work complete, confirm in notes:

- No request-time raw-event risk computation added.
- Writes enter through ingestion/log path.
- `/risk` still uses `risk_cells` path.
- No ORM introduced.
- Query complexity remains bounded by route cells.
- Rebuildability from `events_log` preserved.

---

## 5. Quick Workflow
1. Implement change.
2. Run validation (`build/lint/tests/verify_architecture.sh`).
3. Update `CHANGELOG.md` and `TASKS.md`.
4. Update domain docs only if behavior/invariants changed.
5. Add verification evidence to PR.

---

## 6. Current Owner Tag
Use this tag in changelog entries for traceability:
- `[owner: antigravity]`

Example entry line:
- `- [owner: antigravity] Hardened risk refresh lock handling and added system_state telemetry.`
