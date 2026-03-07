# 🛠️ UDIE Core Standard Tool Interfaces (STI)

This document defines the machine-readable JSON schemas for the core UDIE tools, as mandated by the [Agent Execution Protocol](file:///Users/fallofpheonix/Project/UDIE/docs/agents/AGENT_EXECUTION_PROTOCOL.md).

---

## 1. `query_spatial_grid`
Used by **Diagnostic** and **Architect** agents to inspect the derived risk field.

### Input Schema
```json
{
  "h3_index": "string (Res 9)",
  "k_ring": "number (0-10, optional)",
  "include_metadata": "boolean"
}
```

### Output Schema
```json
{
  "cells": [
    {
      "h3_index": "string",
      "risk_value": "float",
      "last_updated": "ISO8601"
    }
  ],
  "mean_risk": "float"
}
```

---

## 2. `ingest_disruption_event`
Used by **Patch** agents to simulate or insert authoritative events.

### Input Schema
```json
{
  "lat": "number",
  "lng": "number",
  "weight": "number (0.0 - 1.0)",
  "source": "string",
  "ttl_seconds": "number"
}
```

### Output Schema
```json
{
  "event_id": "UUID",
  "status": "QUEUED | PROCESSED",
  "affected_h3_count": "number"
}
```

---

## 3. `audit_system_integrity`
Used by **Verify** agents to perform 4-layer health checks.

### Input Schema
```json
{
  "layers": ["BUILD", "DATA", "OPERATIONS", "DETERMINISM"],
  "verbose": "boolean"
}
```

### Output Schema
```json
{
  "integrity_score": "number (0-100)",
  "failed_invariants": [
    {
      "layer": "string",
      "error": "string",
      "remediation": "string"
    }
  ]
}
```

---

## 4. `rebuild_risk_projection`
Used for recovery from **SCHEMA_DRIFT** or **DATA_SATURATION**.

### Input Schema
```json
{
  "strategy": "KDE_RECOMPUTE | CACHE_RESET",
  "scope": "ALL | GEOGRAPHIC_BOUND"
}
```

### Output Schema
```json
{
  "status": "COMPLETED | IN_PROGRESS",
  "startTime": "ISO8601",
  "estimatedTimeRemaining": "number (seconds)"
}
```

---

MIT © 2026 **UDIE Engineering Group**. 
"Schemas define reality; protocols enforce it."
