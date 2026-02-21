
# Glossary

This glossary defines terms used throughout the UDIE system.

Definitions reflect how the system  **actually models and processes spatial data** , not generic GIS meanings.

---

## Spatial Terms

**PostGIS**

Extension to PostgreSQL providing spatial types, indexing (GIST/SP-GIST), and geodesic functions used for ingestion validation and aggregation preparation.

In UDIE, PostGIS supports lifecycle processing but is not used for heavy request-time computation.

---

**GEOGRAPHY (PostgreSQL Type)**

A coordinate type that models positions on an ellipsoidal Earth (WGS84).

Used for accurate distance-aware preprocessing before aggregation into spatial buckets.

---

**H3 Index**

Hierarchical hexagonal spatial index used to discretize continuous geography into stable cells.

Forms the basis of aggregation, partitioning, and bounded-cost queries.

---

**Spatial Bucket**

A discrete H3 cell representing an area over which disruption influence is aggregated.

All request-time evaluation operates on buckets rather than raw geometries.

---

**Materialized Risk Surface**

The continuously refreshed table (`risk_cells`) representing disruption intensity across spatial buckets.

This surface is the primary dataset queried by the API.

---

**Distance Decay**

A weighting function applied during evaluation to reduce an event’s influence as route distance from its bucket increases.

Ensures localized disruptions do not globally distort risk.

---

**Bounding Box (BBOX)**

A rectangular geographic filter defined by:

<pre class="overflow-visible! px-0!" data-start="1766" data-end="1804"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>minLat, maxLat, minLng, maxLng
</span></span></code></div></div></pre>

Used only for visualization queries.

Risk evaluation does not rely on bounding-box scanning.

---

## Data Lifecycle Terms

**events_log**

Append-only ingestion ledger containing every observed signal.

This table is immutable and serves as the system’s historical ground truth.

---

**events_active**

Derived working-state projection representing currently relevant disruptions after merge, decay, and expiry processing.

---

**Lifecycle Processing**

Scheduled transformation that:

1. merges duplicate observations
2. updates confidence
3. applies temporal decay
4. expires stale disruptions

Maintains a bounded active dataset.

---

**Materialization**

Aggregation step converting `events_active` into spatial weights stored in `risk_cells`.

---

## Domain Terms

**GeoEvent**

A lifecycle-managed disruption instance derived from one or more observations.

Not a raw report. Represents the system’s interpreted state.

---

**Severity**

Domain-defined magnitude of physical impact.

Represents how disruptive an event is when fully trusted.

---

**Confidence**

Dynamic trust weight reflecting reinforcement or decay over time.

Not a probability. It is a lifecycle-managed signal strength.

---

**Risk Score**

Normalized evaluation output for a specific route:

<pre class="overflow-visible! px-0!" data-start="3106" data-end="3178"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>risk</span><span> = f(aggregated cell weights, distance decay, normalization)
</span></span></code></div></div></pre>

Represents relative disruption exposure, not safety certification.

---

**City / Region Identifier**

Logical routing label used by the API to select geographic partitions.

Not a physical shard key. Spatial partitioning is derived from H3 hierarchy.

---

## System Behavior Terms

**Deterministic Rebuild**

Ability to reconstruct `events_active` and `risk_cells` solely from `events_log` and model parameters, producing equivalent outputs.

---

**Bounded Query Cost**

Guarantee that request evaluation complexity depends on:

<pre class="overflow-visible! px-0!" data-start="3713" data-end="3742"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>number_of_route_cells</span><span>
</span></span></code></div></div></pre>

and not total stored events.

---

**Spatial Efficiency**

Operational metric:

<pre class="overflow-visible! px-0!" data-start="3824" data-end="3868"><div class="contain-inline-size rounded-2xl corner-superellipse/1.1 relative bg-token-sidebar-surface-primary"><div class="sticky top-[calc(var(--sticky-padding-top)+9*var(--spacing))]"><div class="absolute end-0 bottom-0 flex h-9 items-center pe-2"><div class="bg-token-bg-elevated-secondary text-token-text-secondary flex items-center gap-4 rounded-sm px-2 font-sans text-xs"></div></div></div><div class="overflow-y-auto p-4" dir="ltr"><code class="whitespace-pre!"><span><span>events_considered</span><span> / events_available
</span></span></code></div></div></pre>

Measures how effectively aggregation reduces per-query workload.

---

## iOS Client Terms

**Clustered Markers**

Visualization technique grouping nearby disruptions to reduce render density.

Purely presentational. Does not affect backend aggregation.

---

**Risk Card**

UI component displaying evaluated route metrics returned by `/risk`.

Contains no independent computation logic.

---

## Clarification

UDIE terminology distinguishes between:

* **observations** (raw signals in `events_log`)
* **events** (lifecycle-managed state in `events_active`)
* **risk surface** (aggregated spatial model in `risk_cells`)

Confusing these layers leads to incorrect system design decisions.
