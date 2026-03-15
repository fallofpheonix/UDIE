# Developer Guide

Welcome to the UDIE project. This guide outlines the engineering playbook, diagnostic protocols, and contribution standards.

## 🧠 Engineering Playbook

### 1. Evidence-First Diagnosis
Do not propose code changes without concrete evidence (logs, command results, or SQL traces).
- Use `scripts/diagnostics/audit.sh` to verify system health.
- Distinguish between **Transport**, **Contract**, and **Data-Plane** failures.

### 2. Boundary Integrity
Every query or update must respect the **Laws of UDIE**.
- Never mutate derived state manually.
- Never add request-time scans to the evaluation path.

## 🚦 Mandatory Diagnostic Protocol

All developers and agents must follow this hierarchy before making changes:

1.  **Discovery**: Probe `/api/health` and `/api/v1/health` to resolve the active namespace.
2.  **Transport**: Verify the host is reachable from the specific client environment (Simulator vs physical device).
3.  **Contract**: Probe business endpoints with required query parameters.
4.  **Database/Schema**: Verify migrations are current and partitions exist.
5.  **Worker Health**: Inspect logs for materialization lag or "Direct mutation prohibited" errors.

## 🛠 Development Workflow

1.  **Sync**: Ensure your local database is primed with recent event logs.
2.  **Branch**: follow `feature/` or `fix/` naming conventions.
3.  **Verify**: Run `npm test` and `flutter test` before submitting PRs.
4.  **Document**: Update the relevant canonical documentation file if your change affects the system contract or architecture.

## 📚 Glossary & Context

- **H3**: Uber's hierarchical hexagonal spatial index.
- **Risk Surface**: The materialized field of decayed disruption weights.
- **Law of Bounded Input**: The requirement that all inputs have explicit computational limits.
- **Event-Sourced**: Rebuilding state by replaying an immutable log of events.

MIT © 2026 **UDIE Engineering Group**. "Precision in reasoning, determinism in action."
