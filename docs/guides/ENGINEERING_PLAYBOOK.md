# UDIE Engineering Playbook

This document is the canonical engineering workflow guide.
It replaces the split across onboarding, SRE habits, distributed debugging, and fast-path diagnosis docs.

## Working Model

Treat UDIE as a live distributed system with multiple truth domains: client runtime, backend runtime, and database state.
Do not infer runtime behavior from source code alone.

## Mandatory First Steps

1. Confirm repository state and active branch.
2. Identify runtime context: simulator, physical device, local backend, Docker, or mixed.
3. Probe API namespace and health before touching application logic.
4. Collect logs before opening code.

## Diagnostic Order

1. Container/process existence and health
2. Transport reachability
3. API namespace and route contract
4. Database connectivity and schema state
5. Worker health and derived-state freshness
6. End-to-end feature validation with valid bounded inputs

## Engineering Habits

- Reproduce first.
- Use the smallest failing command.
- Distinguish transport from HTTP contract from backend/data failure.
- Prefer minimal, evidence-backed fixes over speculative rewrites.

## Change Discipline

- Preserve the laws and derived-state boundaries.
- Keep documentation aligned with runtime truth after changes.
- When changing contracts, update clients and verification commands in the same change.

## Device Debugging Rules

- Simulator `localhost` is not physical-device `localhost`.
- Physical-device backend access must use a reachable host interface.
- Connectivity status must not claim sync success without a completed health/sync path.
