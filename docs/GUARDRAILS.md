# UDIE Architectural Guardrails (The 20 Atomic Laws)

To maintain a stable spatial risk field, these 20 laws are non-negotiable.

## 1. Hot-Path Intelligence
- **Law 1**: Never calculate risk from raw events at request time. Use `risk_cells`.
- **Law 2**: Queries must use H3 cell intersection, never raw geometry overlap.
- **Law 3**: Latency must stay flat as history grows (O(cells)).

## 2. Ingestion & Truth
- **Law 4**: Ingestion is append-only into `events_log`.
- **Law 5**: State is a derived projection. Never write direct to `active` tables.
- **Law 6**: No data source may bypass the ingestion contract.

## 3. Lifecycle & Aging
- **Law 7**: Every event must decay and expire automatically.
- **Law 8**: No permanent noise. Confidence must trend down without reinforcement.
- **Law 9**: Expiry must be asynchronous (Maintenance Job).

## 4. Scaling Axis
- **Law 10**: Scale by geography (H3 partitions), not by monolith size.
- **Law 11**: Maintain Region-Independence; load in A must not affect B.
- **Law 12**: Materialize surfaces locally per region.

## 5. Mathematical Integrity
- **Law 13**: No hardcoded math constants. Use `model_parameters`.
- **Law 14**: Determinism: Rebuilds from log must produce identical results.
- **Law 15**: Version all model parameters.

## 6. Safety & Isolation
- **Law 16**: Bounding input: Max 50km routes, 1000 vertices.
- **Law 17**: OLTP and Analytics separation (Read replicas).
- **Law 18**: Freshness SLA: Aggregation must finish before next cycle.

## 7. Observability
- **Law 19**: Visibility is part of the product. No blind jobs.
- **Law 20**: Truth lives in logs; derived layers are disposable.

"If a change increases data touched per query, it is wrong."
