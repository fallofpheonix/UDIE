# Data Pipeline

The UDIE Data Pipeline is a stream-processing architecture optimized for real-time spatial telemetry.

## 🌊 Pipeline Overview

1.  **Ingestion Layer**: REST API and WebSocket listeners capture raw disruption signals.
2.  **Normalization**: Signals are validated against JSON schemas and mapped to H3 resolution 9 cells.
3.  **Authoritative Log**: Normalized events are appended to the immutable `events_log`.
4.  **Projection Workers**: Async workers detect log appends and refresh the `risk_cells` surface using spatial diffusion kernels.
5.  **Lifecycle Maintenance**: Temporal decay and signal expiration are applied periodically to maintain field freshness.
6.  **Hot-Path Delivery**: Live cell scores are streamed via WebSockets or exposed via $O(1)$ API lookups from Redis.

## ⚙️ Ingestion Components

- **Validation Engine**: Enforces geographic bounds (Law of Bounded Input).
- **Deduplicator**: Prevents duplicate ingestion of sensor spikes using Bloom filters.
- **Weighting Filter**: Assigns Severity and Confidence scores based on source reliability.

## 📊 Processing Kernels

- **Spatial Diffusion**: Influence of a disruption decays according to a distance-weighted kernel (Law of Spatial Locality).
- **Temporal Decay**: Signal strength decays exponentially in the absence of reinforcement (Law of Temporal Dissipation).
- **Saturation**: Final risk values are normalized to $[0, 1)$ to prevent scale-out.

## ⏱ Performance Invariants

- **End-to-End Latency**: < 5 seconds from sensor ingestion to UI render.
- **Aggregation Throughput**: Millions of spatial updates processed per hour via optimized PG/PostGIS kernels.
