# 📜 UDIE Agent Execution Protocol (v1.0)

This document defines the **Semantic Protocol** for agent reasoning and tool interaction. It ensures that the LLM behaves as a deterministic component within the [Agent Runtime Architecture](file:///Users/fallofpheonix/Project/UDIE/docs/agents/AGENT_RUNTIME_ARCHITECTURE.md).

---

## 🧠 1. Reasoning Format: Thought-to-Action
Agents must follow a strict **ReAct (Reasoning + Acting)** cycle. Every response must contain a structured bridge between raw observation and system mutation.

### The Reasoning Loop:
1. **THOUGHT**: Analyze the current task state and previous tool outputs.
2. **EVIDENCE**: Cite specific log lines, SQL results, or file paths.
3. **TOOL CALL**: Invoke a Standard Tool Interface (STI) with validated JSON.
4. **OBSERVATION**: Process the tool's raw result and determine if the goal is met.

---

## 🛠️ 2. Tool Invocation Protocol
Agents never "guess" parameters. They must adhere to the defined **JSON Schema** for every tool.

### Deterministic Call Syntax:
```json
{
  "call": "tool_name",
  "arguments": {
    "arg1": "value",
    "arg2": "value"
  },
  "rationale": "Brief engineering justification for this specific call"
}
```
*Any call missing the `rationale` or violating the `arguments` schema is rejected by the Runtime Gateway.*

---

## 📁 3. Artifact Creation Protocol
Every file mutation or investigative report must be stored as a **Signed Artifact**.

- **Investigation Artifacts**: Must include the environment hash and `agent-bootstrap.sh` pulse.
- **Implementation Artifacts**: Must include the `Diff` and the related `DocSync` update.
- **Verification Artifacts**: Must include the reproduction logs proving the fix works.

---

## 🔄 4. Error Recovery & Backtracking
If a tool fails (e.g., `TIMEOUT`, `PERMISSION_DENIED`, `NOT_FOUND`), the agent must follow the **Recovery Protocol**:

1. **Classify the Failure**: Identify if it's a `RUNTIME` error or a `LOGIC` error.
2. **Branch Analysis**: Do not repeat the same failing command. Pivot the investigation.
3. **Escalation**: If 3 consecutive recoveries fail, the agent must transition to `DEAD_LETTER` state and request human intervention.

---

## 🚦 5. Governance Constraints
- **Chain Depth**: Max 10 reasoning steps per sub-task.
- **Context Management**: Agents must proactively summarize context when token usage exceeds 80% of the window.
- **Identity Pinning**: Agents must declare their role (`Diagnostic`, `Patch`, etc.) in every header to maintain consistency.

---

## 💎 6. Output Schema: The "Final Report"
The task only moves to `COMPLETED` if the final output matches this schema:

```json
{
  "task_id": "UUID",
  "problem_classification": "FAILURE_CLASS",
  "proven_root_cause": "string",
  "patch_summary": "string",
  "verification_artifacts": ["path/to/log1", "path/to/log2"],
  "documentation_sync_status": "COMPLETED"
}
```

---

MIT © 2026 **UDIE Engineering Group**. 
"Precision in reasoning, determinism in action."
