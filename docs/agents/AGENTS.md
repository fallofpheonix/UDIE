# UDIE Agent Protocol: Mandatory Diagnostic Process

This document defines the mandatory protocol for any AI agent or engineer tasked with debugging or extending the UDIE system. Failure to follow these steps leads to misdiagnosis and configuration drift.

---

## 🚀 1. The Mandatory Bootstrap
Before modifying ANY code or performing any diagnosis, agents must run the following command to verify the runtime environment:
```bash
./scripts/agent-bootstrap.sh
```
This script validates container health, API availability, and database migration status. If this script fails, the agent must resolve the environment issue before proceeding with any application logic changes.

---

## 🔍 2. Diagnostic Command Hierarchy (Mandatory Order)
If an issue is reported, execute in this exact order:

1. **Container Runtime**: Verify existence and `healthy` status.
2. **Transport Layer**: Verify listening socket and port mapping.
3. **API Contract Layer**: Detect active API prefix (`/api/v1` vs `/api`).
4. **Database Connectivity**: Check for backend-to-db errors and startup races.
5. **Schema Integrity**: Verify tables and migration history.
6. **Worker Layer**: Verify background job logs (Materialization, Projection, Lifecycle).
7. **Spatial Integrity**: Check PostGIS, H3 resolutions, and data counts.
8. **Mutation Permissions**: Check for "Direct mutation" session blocks.
9. **Functional API Validation**: Verify end-to-end event retrieval.

---

## 🛡 3. Development Invariants
1. **Never assume API prefix**: Always probe for the active version.
2. **Never assume DB schema version**: Always verify the current state of tables.
3. **Workers must tolerate DB startup race**: Implement retry mechanisms and handle missing tables gracefully.
4. **No Localhost in Binaries**: Use environment variables for all backend URLs.
5. **Client sync state integrity**: Never report "Connected" without a successful health handshake and initial sync.

---

## 📂 4. Protocol Reference
- `docs/agents/AGENT_OPERATING_SYSTEM.md`: **The Authoritative Agent OS Guide.**
- `agent-mandatory/DIAGNOSTIC_PROTOCOL.md`: Canonical troubleshooting guide.
- `agent-mandatory/TASK_BOOTSTRAP_CHECKLIST.md`: Verification required before starting work.
- `docs/agents/FAILURE_CLASSES.md`: Categorization of layered system failures.
- `docs/agents/SYSTEM_ASSUMPTIONS.md`: Environment constraints and networking rules.

---

## 📜 5. Documentation Immutable Law (Mandatory)
**Documentation is the "First Idea" and the absolute source of truth for the UDIE system.**

1. **No Unauthorized Mutations**: Agents must NOT alter ANY documentation files (`docs/`, `README.md`, `CONTRIBUTING.md`) unless explicitly commanded by the user.
2. **Mandatory Documentation Sync**: Agents MUST update any related documentation whenever they work or make changes to ensure the code never drifts from the specifications.
3. **Strict Adherence**: Agents must work strictly according to established documentation.
4. **Engineering Excellence**: Agents are expected to follow `docs/guides/ENGINEERING_PLAYBOOK.md`.
5. **Structured Response**: Every concluding report must follow the [Agent Execution Protocol](file:///Users/fallofpheonix/Project/UDIE/docs/agents/AGENT_EXECUTION_PROTOCOL.md) and the format defined in `AGENT_OPERATING_SYSTEM.md`.
6. **Evidence-Based Reasoning**: No decision or conclusion will be accepted without provided evidence (logs, code, CLI output).
