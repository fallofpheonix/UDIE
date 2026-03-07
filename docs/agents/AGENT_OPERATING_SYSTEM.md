# 🤖 UDIE Agent Operating System (v3.0)

This document defines the high-level operational model for the UDIE Agent OS. It bridges engineering policy with the functional **Agent Runtime Architecture**.

---

## 🏗️ 1. Orchestrated Worker Model
Agents in UDIE are **Stateful Orchestrated Workers**. Unlike conversational assistants, they operate within a defined **Runtime Sandbox** and follow a strict **Task State Machine**.

### 1.1 The Runtime Substrate
Execution is managed by the [UDIE Agent Runtime](file:///Users/fallofpheonix/Project/UDIE/docs/agents/AGENT_RUNTIME_ARCHITECTURE.md).
- **Orchestrator**: Manages task queuing and resource allocation.
- **DAG Engine**: Enforces the execution order of investigative and elective steps.
- **Artifact Store**: Persists evidence, logs, and patches for every task ID.

---

## 🚦 2. Runtime Task Lifecycle
All agent activities must transition through the authoritative **Task State Machine**:

1. **EVIDENCE**: Collection of logs, CLI results, and system state.
2. **REPRODUCED**: Verification of the issue in a sandboxed environment.
3. **IMPACT**: Determination of the architectural and spatial blast radius.
4. **MUTATION**: Implementation of the fix + **Mandatory Doc Sync**.
5. **VALIDATION**: Proof of work via automated test suites.

---

## 🛠️ 3. **Standard Tool Interfaces (STI)**: Agents interact with the substrate only through STI-compliant tools. Tools are governed by the [Execution Protocol](file:///Users/fallofpheonix/Project/UDIE/docs/agents/AGENT_EXECUTION_PROTOCOL.md) to prevent hallucination.
- **Strict Input/Output Schemas**: Refer to [CORE_STI_SCHEMAS.md](file:///Users/fallofpheonix/Project/UDIE/docs/agents/CORE_STI_SCHEMAS.md) for tool definitions.
- **Sandboxed Execution**: Destructive tools (write, run) are jailed within reproduction containers.
- **Capability Routing**: Agents are assigned roles (Diagnostic, Architect, Patch) with specific tool permissions.

---

## 📜 4. Governance & The "First Idea" Invariant
UDIE maintains the principle of **Intentional Engineering**:
- **Documentation is the Intent**: The [Specifications](file:///Users/fallofpheonix/Project/UDIE/docs/architecture/README.md) define what the code *should* do.
- **Zero-Drift Law**: Agents MUST update documentation whenever code is changed. The spec is updated to reflect the new reality, and the code is verified against the updated spec.
- **Reproduction Mandate**: No code mutation is permitted without a recorded reproduction artifact in the `Task Store`.

---

## 🛡️ 5. Safety & Authority Gates
- **Human-In-The-Loop (HITL)**: Transitions to the `COMPLETED` state require manual verification of the Evidence Chain.
- **Token Quotas**: Hard limits on token usage and step counts to prevent runaway loops.
- **Isolation Layers**: Network and filesystem jails protect the host environment.

---

MIT © 2026 **UDIE Engineering Group**. 
"Standardization is the prerequisite for automation."
