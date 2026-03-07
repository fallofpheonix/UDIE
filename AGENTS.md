# AGENTS.md

## Mandatory Policy
All agents MUST read the following before any analysis, diagnosis, or code changes:
1. `/Users/fallofpheonix/Project/UDIE/agent-mandatory/README.md`
2. `/Users/fallofpheonix/Project/UDIE/agent-mandatory/TASK_BOOTSTRAP_CHECKLIST.md`
3. `/Users/fallofpheonix/Project/UDIE/agent-mandatory/DIAGNOSTIC_PROTOCOL.md`

If these files are not read first, the task is considered non-compliant.

## Enforcement Requirements
- Never assume source and runtime are identical.
- Always detect API namespace at runtime (`/api` vs `/api/v1`) before concluding connectivity failure.
- Always differentiate transport, HTTP contract, and backend worker/data failures.
- For required-query endpoints, test with valid query parameters only.
- Use explicit state semantics for connectivity/sync reporting.

## Incident Reference
For full details of the March 2026 connectivity + synchronization incident:
- `/Users/fallofpheonix/Project/UDIE/docs/incident_postmortem.md`
