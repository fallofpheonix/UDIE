# UDIE Data Pipeline & Spatial Intelligence Backend (v1.0)

This document defines the **data ingestion, processing, aggregation, and streaming architecture** powering the Universal Disruption Intelligence Engine.

---

## 1. System Architecture Overview

UDIE utilizes a **Stream-Processing Architecture** optimized for high-throughput spatial telemetry.

### 1.1 The Pipeline
`Data Sources` → `Ingestion Layer` → `Normalization` → `H3 Aggregator` → `Prediction Agents` → `Tile Generator` → `WebSocket Streams`.

---

## 2. Ingestion & Normalization

### 2.1 Ingestion Layer
*   **Protocols**: REST API (POST `/events`), WebSocket (WSS), and Kafka consumers.
*   **Validation**: Strict JSON schema enforcement with WGS84 coordinate normalization.
*   **Deduplication**: Bloom filter-based state tracking to prevent duplicate ingestion of sensor spikes.

### 2.2 Severity & Reliability
Each event is assigned:
*   **Severity Score [0-1]**: Based on event type and historical weighting.
*   **Confidence Score [0-1]**: Based on source reliability and sensor age.

---

## 3. H3 Spatial Aggregation Engine

Aggregation occurs on a rolling window using **Uber H3 hexagonal grids**.

### 3.1 Resolving Resolutions
*   **Active Resolutions**: Res 6 through Res 9.
*   **Metrics**: Event density, moving average risk, and agent activity flags.
*   **Partitioning**: Data is partitioned by H3 index prefix to allow horizontal scaling of aggregation workers.

---

## 4. Real-time Delivery & Storage

### 4.1 Storage Tiers
| Tier | Technology | Usage |
| :--- | :--- | :--- |
| **Hot** | Redis | Live cell metrics & active trajectories. |
| **Warm** | Postgres (PostGIS) | Relational event log & system state. |
| **Cold** | Object Storage (S3) | Historical event archives for model training. |

### 4.2 Streaming Architecture
*   **Risk Surface Stream**: Incremental H3 updates every 5 seconds.
*   **Forecast Stream**: Agent-computed vectors every 10 seconds.
*   **Event Stream**: Zero-latency marker injection for critical disruptions.

---

## 5. Performance Invariants
*   **End-to-End Latency**: < 5 seconds from ingestion to UI render.
*   **Inference Latency**: < 200ms per agent forecast batch.
*   **Aggregation Speed**: Millions of spatial updates processed per hour through optimized SQL diffusion kernels.
