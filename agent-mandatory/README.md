# Agent Mandatory Operating Rules

This folder is mandatory for all agents working in this repository.

## Mandatory Startup Sequence (No Exceptions)
1. Read `/Users/fallofpheonix/Project/UDIE/agent-mandatory/TASK_BOOTSTRAP_CHECKLIST.md`.
2. Read `/Users/fallofpheonix/Project/UDIE/agent-mandatory/DIAGNOSTIC_PROTOCOL.md`.
3. Validate runtime context before changes:
   - active routes (runtime logs)
   - API prefix (`/api` vs `/api/v1`)
   - required endpoint query contracts
   - container/image version drift
4. Record assumptions explicitly in response.
5. Execute minimal reproducible checks before proposing root cause.

## Mandatory Output Requirements
- Start with diagnosis or solution.
- Include concrete evidence (command result or log line class).
- Distinguish transport failure vs contract failure vs data-pipeline failure.
- If uncertain, state uncertainty and the next discriminating check.

## Prohibited Behavior
- Do not assume source code equals deployed runtime behavior.
- Do not classify validation `400` as connectivity failure.
- Do not report "connected" without proving data-path success.
- Do not recommend rewrites before isolating reproducible root cause.
