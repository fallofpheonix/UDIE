# ONBOARDING — Start Here

This file tells you how to work on UDIE without breaking it.

Read this before opening the code.

---

## Required Mental Model

UDIE is  **not CRUD over geospatial tables** .

It is a pipeline:

```
events_log (truth)
    ↓
derived lifecycle state
    ↓
materialized spatial field
    ↓
bounded evaluation
```

You never compute risk from raw events.
You never edit derived tables manually.
You never bypass ingestion.

If you do, you destroy determinism and scaling guarantees.

---

## What Is Authoritative

| Layer         | Authority              |
| ------------- | ---------------------- |
| events_log    | Source of truth        |
| events_active | Rebuildable projection |
| risk_cells    | Query surface          |
| Redis/cache   | Disposable             |

If it cannot be rebuilt from `events_log`, it does not belong.

---

## First Commands To Run

Start the stack:

```bash
cd backend
docker compose up --build
```

Verify system:

```bash
curl http://localhost:3000/api/health
```

Check tables exist:

```bash
docker exec -it <postgres> psql -U udie -d udie
\dt
```

---

## First Files To Read In Codebase

Start here. Do not jump randomly.

1. Lifecycle SQL / materialization logic
   This defines the actual system behavior.
2. Risk evaluation query
   Shows bounded cell-based evaluation.
3. Ingestion service
   Demonstrates append-only contract.

Only after that read controllers or UI.

---

## Development Workflow

When adding anything:

1. Does it write to `events_log` only?
2. Is derived state rebuildable?
3. Does it avoid request-time spatial scans?
4. Does query complexity remain O(route_cells)?

If any answer is “no”, redesign.

---

## Common Mistakes (Do Not Make These)

### ❌ Running ST_Distance in API Queries

That reintroduces O(N) scans and kills scalability.

Use pre-aggregated cells only.

---

### ❌ Updating events_active Directly

Lifecycle owns that table. Manual edits break replayability.

---

### ❌ Adding ORM Abstractions Over Spatial Logic

You must see and control the SQL plan. Hidden queries cause regressions.

---

### ❌ Treating Redis as Storage

Cache is optional. The database must work without it.

---

### ❌ Adding Features Before Verification

The evaluation harness must pass before expanding functionality.

---

## How To Know You Didn’t Break It

Run the benchmark replay:

```
benchmarks/benchmark_replay.sh
```

If results drift or latency scales with dataset size, your change is wrong.

---

## Guiding Principle

UDIE is maintained, not “finished”.

You are modifying a continuously recomputed model, not an application backend.
