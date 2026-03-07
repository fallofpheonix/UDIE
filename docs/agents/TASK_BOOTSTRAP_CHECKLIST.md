# UDIE Task Bootstrap Checklist

Before starting any task in the UDIE codebase, complete this checklist to ensure the system is in a valid, functional state.

## 0. Mandatory Automated Bootstrap
- [ ] Run `./scripts/agent-bootstrap.sh`. This script handles the baseline verification of containers, API prefix, and database readiness.
- [ ] **Snapshot Record**: Copy the output of the bootstrap script into the task incident log for reproducibility.

---

## 1. Runtime & Build Verification

### Backend Build
```bash
npm install && npm run build
```
- [ ] Backend compiles without errors. This prevents runtime type failures.

### API Health
```bash
curl http://localhost:3000/api/v1/health
```
- [ ] Expected response: `{"status":"ok"}`. (Verify prefix if /api/v1 fails).

---

## 2. Environment Configuration

### API Base URL Validation
- [ ] **Simulator**: Uses `http://localhost:3000`.
- [ ] **Physical Device**: Uses host Mac LAN IP (e.g., `http://192.168.1.5:3000`).
- [ ] **Format**: Must NOT end with a trailing slash. Must NOT use `172.x.x.x`.

### Database & Workers
- [ ] `docker inspect` confirms Postgres is `healthy`.
- [ ] `docker logs udie-backend | grep MATERIALIZE` confirms workers are starting.

---

## 3. Codebase Integrity
- [ ] `npm run lint` passes.
- [ ] `npm run test` passes (or relevant subset for the task).

---

## 4. Repository Context
- [ ] Review `docs/incident_postmortem.md` for similar recent issues.
- [ ] Review `docs/agents/AGENTS.md` for governance changes.
- [ ] **AOS Compliance**: Review `docs/agents/AGENT_OPERATING_SYSTEM.md` and confirm adherence to the Standard Response Format.
- [ ] Ensure `CHANGELOG.md` is updated for the target work.
