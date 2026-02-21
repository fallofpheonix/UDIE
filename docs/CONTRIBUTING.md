
# Contributing

Contributions to the **Urban Disruption Intelligence Engine (UDIE)** must preserve the system’s spatial computation guarantees.

UDIE is not a general web application.

Changes that violate lifecycle modeling, aggregation discipline, or bounded query cost will be rejected regardless of code quality.

---

## Contribution Principles

All contributions must respect these invariants:

1. Risk evaluation must operate on materialized spatial state (`risk_cells`), not raw events.
2. Active disruption data must remain lifecycle-managed (merge → decay → expire).
3. The system must remain fully rebuildable from the append-only log (`events_log`).
4. Query cost must scale with spatial scope, not total dataset size.
5. No feature may introduce unbounded spatial scans or ad-hoc analytics on operational tables.

If a change increases per-request data access or bypasses aggregation layers, it is architecturally invalid.

---

## Development Workflow

1. **Fork** the repository.
2. **Clone** :

<pre class="overflow-visible! px-0!" data-start="1247" data-end="1306"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre! language-bash"><span><span>git </span><span>clone</span><span> https://github.com/fallofpheonix/UDIE
</span></span></code></div></div></pre>

3. **Create a feature branch** :

<pre class="overflow-visible! px-0!" data-start="1341" data-end="1396"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre! language-bash"><span><span>git checkout -b feature/<short-description>
</span></span></code></div></div></pre>

4. **Develop against documented architecture**

All changes must align with `docs/ARCHITECTURE.md`.

Do not introduce alternate data paths or bypass lifecycle processing.

5. **Validate behavior**

You must demonstrate that your change does not alter:

* query plan structure
* lifecycle decay behavior
* aggregation boundaries

This can be done through tests, explain-plan output, or benchmark comparison.

6. **Submit Pull Request**

Include:

* description of change
* architectural impact (if any)
* validation performed

---

## Required Validation for Non-Trivial Changes

Any modification touching SQL, lifecycle logic, or risk computation must include:

* `EXPLAIN ANALYZE` output before and after (showing no new sequential scans)
* Confirmation that derived tables can still be rebuilt from logs
* Evidence that request latency does not scale with dataset size

PRs without validation will not be reviewed.

---

## Code Standards

### Swift (iOS Client)

* Use SwiftUI exclusively for UI composition.
* Keep view logic declarative. Do not embed networking or spatial logic inside views.
* Client must treat backend as authoritative and must not replicate risk computation locally.

---

### TypeScript (Backend)

* Use strict mode.
* Favor deterministic logic over abstraction-heavy patterns.
* Avoid hidden async behavior in lifecycle or aggregation code paths.
* All database access must be explicit and observable.

---

### SQL / PostGIS

* Use parameterized queries only.
* Avoid per-row procedural loops inside PL/pgSQL.
* Prefer set-based operations aligned with spatial bucketing.
* Never introduce runtime spatial joins in request paths.

---

### Documentation

Documentation is part of the system contract.

Any change affecting:

* schema
* lifecycle behavior
* scoring logic
* scaling model

must update the relevant files under `docs/`.

Outdated documentation is treated as a defect.

---

## What Not to Contribute

The following will not be accepted unless preceded by architectural review:

* Client-side risk computation.
* Direct CRUD APIs over disruption tables.
* Predictive or ML features without validated historical modeling.
* Infrastructure scaling (Kubernetes, sharding) without measured saturation evidence.

---

## Review Philosophy

UDIE favors correctness, determinism, and bounded complexity over rapid feature growth.

A smaller, predictable system is preferred to a larger but opaque one.
