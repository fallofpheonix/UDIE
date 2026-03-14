
# Future Scope

This document outlines potential extensions of UDIE beyond its current role as a disruption-aware routing engine.

These directions are  **contingent on the spatial core remaining validated, bounded, and reproducible** .

They must not be pursued until operational and scaling guarantees are demonstrated.

---

## Preconditions for Any Expansion

Future capabilities should only be explored once the system can:

* Sustain live ingestion without dataset inflation.
* Demonstrate stable query latency independent of historical size.
* Rebuild deterministically from `events_log`.
* Operate across multiple geographic regions without cross-coupling.
* Maintain a validated evaluation harness and model versioning discipline.

If these conditions are not met, expansion introduces risk without value.

---

## Technological Extensions (Post-Stability)

These represent architectural overlays, not replacements for the backend risk model.

---

### Edge-Assisted Evaluation (Not Full Edge Migration)

Selective computation may be performed on-device to reduce perceived latency, such as:

* interpolation between already-materialized risk cells
* visualization smoothing
* offline fallback behavior

**Constraint**

Authoritative risk computation must remain server-side to avoid logic drift across clients.

---

### Augmented Reality Visualization

Use the spatial risk surface as an input layer for AR navigation experiences.

Possible applications:

* projecting hazard zones into pedestrian view
* contextual overlays for construction, flooding, or closures

**Constraint**

AR consumes the risk surface; it does not generate or alter it.

---

### Infrastructure Integration (V2X / Smart City Feeds)

Direct ingestion from municipal infrastructure may improve signal quality:

* traffic controllers
* environmental sensors
* road maintenance systems

These become additional ingestion sources feeding `events_log`, not parallel systems.

---

## Data Expansion Opportunities

These extend observation fidelity while preserving lifecycle modeling.

---

### Civic Sensor Integration

IoT sources (e.g., water-level or environmental sensors) can produce structured signals.

These must still enter through the same ingestion pipeline:

<pre class="overflow-visible! px-0!" data-start="2477" data-end="2546"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>sensor</span><span> → normalization → events_log → lifecycle → aggregation
</span></span></code></div></div></pre>

No sensor may bypass deduplication or decay logic.

---

### Social Signal Weighting

Natural-language sources (e.g., public reports) may be used to influence confidence scoring.

This should adjust  **confidence reinforcement** , not directly alter spatial weights.

Model discipline must ensure:

* probabilistic signals remain bounded,
* noisy sources cannot permanently elevate risk.

---

## Ecosystem Applications

These describe downstream consumers of the spatial intelligence layer.

---

### Logistics Optimization

Fleet systems can query UDIE to:

* avoid infrastructure-heavy routes
* reduce vehicle wear and operational uncertainty

Use remains read-only against `/risk` or derived datasets.

---

### Civic Operations Dashboard

Aggregated spatial history can inform:

* maintenance prioritization
* infrastructure stress analysis
* emergency routing decisions

Such analytics must operate on replicated or exported datasets, not the live operational database.

---

## Non-Goals for Future Scope

The following are explicitly excluded unless the architecture is fundamentally revised:

* Client-side replication of the risk model.
* Real-time distributed consensus across cities.
* Replacement of SQL/PostGIS aggregation with opaque ML-only scoring.
* Any feature that removes the ability to deterministically recompute state.

---

## Summary

Future scope expands how the spatial intelligence layer is consumed, not how it is computed.

UDIE’s long-term value lies in maintaining a stable, continuously recomputed urban disruption field that other systems can safely depend on.
