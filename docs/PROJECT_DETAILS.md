
# Project Details

## Problem Statement

Most navigation systems optimize for travel time and treat disruptions as transient annotations rather than as a maintained spatial signal.

Urban conditions, however, change continuously:

* infrastructure failures appear and decay over time,
* multiple reports may describe the same physical disruption,
* the relevance of a disruption depends on both proximity and recency.

Without lifecycle modeling, routing systems cannot distinguish between:

* a stale report and an active hazard,
* isolated noise and reinforced disruption patterns,
* localized instability and city-wide conditions.

There is therefore no persistent, queryable disruption field that can be evaluated independently of routing heuristics.

---

## Solution Overview

UDIE introduces a backend-authoritative spatial model that continuously interprets disruption observations into a bounded, recomputable risk surface.

The system performs four core transformations:

1. **Observation Logging**

   All incoming signals are written to an append-only ledger (`events_log`).
2. **Lifecycle Projection**

   Observations are merged, reinforced, decayed, and expired to produce the current interpreted state (`events_active`).
3. **Spatial Aggregation**

   Active disruptions are discretized into H3-indexed buckets and materialized into a risk surface (`risk_cells`).
4. **Bounded Evaluation**

   Route evaluation queries this surface, ensuring computational cost depends on spatial scope rather than total data volume.

This separates continuous spatial maintenance from lightweight request-time evaluation.

---

## Design Principles

### Backend-Authoritative Computation

All lifecycle and aggregation logic is centralized to ensure:

* deterministic recomputation,
* consistent model behavior across clients,
* strict control over evaluation complexity.

Clients act only as consumers of evaluated results.

---

### Lifecycle-Driven Data Model

Disruptions are treated as evolving signals, not static records.

Each disruption:

* accumulates reinforcement,
* decays without updates,
* expires automatically.

This prevents permanent accumulation of stale data.

---

### Spatial Discretization for Bounded Cost

Continuous geography is mapped into discrete H3 cells, allowing:

* aggregation independent of raw geometry count,
* predictable query complexity,
* scalable regional partitioning.

---

## Key Functional Capabilities

* Continuous ingestion and reconciliation of disruption observations.
* Automatic aging and removal of stale signals.
* Pre-aggregated spatial risk field enabling efficient evaluation.
* Route risk scoring derived from localized spatial influence.
* Deterministic rebuild capability from historical logs.

---

## What UDIE Is Not

UDIE is not:

* a navigation engine,
* a traffic prediction system,
* a real-time GIS query service over raw geometries.

It is a maintained spatial intelligence layer designed to complement those systems.

---

## Summary

UDIE transforms fragmented disruption reports into a continuously recomputed spatial model that can be queried efficiently and reproduced deterministically, enabling disruption-aware analysis without incurring unbounded geospatial computation.
