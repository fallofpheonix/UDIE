# UDIE Spatial Intelligence Model

This is the canonical theory document for UDIE.
It consolidates the whitepaper, mathematical appendix, and intelligence-model overview.

## Core Model

UDIE represents disruption as a spatiotemporal scalar field over a discretized H3 grid.
Signals inject weighted energy into space, and the system derives stable route and area risk from the resulting field.

## Mathematical Basis

### Spatial Representation
- Geography is discretized into H3 cells.
- Aggregation occurs over cells rather than arbitrary raw coordinates.

### Risk Propagation
- Events contribute local weight.
- Risk diffuses and decays according to bounded kernels rather than unbounded request-time scans.

### Temporal Evolution
- Signals age, decay, and are maintained by lifecycle workers.
- Snapshots provide a time-indexed history of field evolution.

## Intelligence Layer

The intelligence subsystem consumes risk surfaces and historical state to produce higher-order insights such as hotspots, spikes, and recurring disruption patterns.

## Stability Requirements

- Replay from authoritative input must converge on the same derived surface.
- Evaluation cost must scale with route/cell coverage rather than total historical volume.
- Materialized surfaces must remain fresh enough for operational use.

## Modeling Boundaries

- Current kernels remain simplified relative to full urban morphology.
- Intelligence quality depends on projection correctness, schema integrity, and worker health.

## Related Documents

- `docs/architecture/LIMITATIONS.md`
- `docs/architecture/PERFORMANCE.md`
- `docs/architecture/UDIE_EVENT_SCHEMA_SPATIAL_MODEL.md`
