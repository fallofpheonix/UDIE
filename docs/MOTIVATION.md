
# Motivation

## Problem Statement

Conventional navigation systems optimize primarily for travel time.

They treat disruptions as transient traffic signals rather than structured, lifecycle-managed phenomena.

This leads to several limitations:

* Infrastructure disruptions (construction, flooding, protests, closures) are modeled inconsistently.
* Signals are not maintained as a persistent spatial field.
* Historical and reinforcement patterns are not used to shape current evaluations.
* Users receive ETA optimization without understanding environmental risk exposure.

The absence of a maintained disruption model makes it difficult to reason about route reliability beyond congestion.

---

## Design Objective

UDIE introduces a dedicated spatial layer that models  **urban disruption as a continuously evolving signal** .

Instead of reacting to individual reports, the system:

1. Ingests observations into an append-only log.
2. Applies spatial-temporal merging and lifecycle decay.
3. Aggregates disruptions into a materialized spatial surface.
4. Evaluates routes against this surface using bounded-cost queries.

This approach treats disruption not as isolated events, but as a time-decaying field that can be recomputed deterministically.

---

## Why a Backend-Authoritative Model

Maintaining a consistent disruption model requires:

* centralized lifecycle processing,
* reproducible aggregation,
* strict control over spatial evaluation cost.

Distributing this logic across clients would introduce divergence, inconsistent decay behavior, and unbounded computation.

The backend therefore serves as the authoritative interpreter of disruption signals.

---

## Goals

### 1. Model Disruption as Structured Data

Represent infrastructure instability as a lifecycle-managed dataset rather than ad-hoc annotations.

---

### 2. Maintain Deterministic Spatial State

Ensure the disruption field can be rebuilt from raw observations, allowing reproducibility and validation.

---

### 3. Provide Bounded, Explainable Route Evaluation

Enable route analysis whose computational cost depends on spatial scope, not accumulated history.

---

### 4. Enable Extensible Ingestion Without Architectural Drift

Allow integration of new signal sources (municipal data, sensors, public reports) without bypassing lifecycle or aggregation rules.

---

## Non-Goal

UDIE does not attempt to replace navigation engines or traffic prediction models.

It provides an orthogonal layer focused on disruption exposure rather than travel-time optimization.

---

## Summary

The motivation behind UDIE is to establish a reproducible, lifecycle-driven spatial model of urban disruption that can be queried efficiently and extended safely, rather than treating disruptions as ephemeral annotations.

---
