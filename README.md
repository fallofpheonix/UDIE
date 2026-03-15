# UDIE: Universal Disruption Intelligence Engine

UDIE is a spatial intelligence system designed to convert volatile, multi-source urban disruption signals into a stable operational risk view. It leverages H3 spatial indexing, event-sourced persistence, and deterministic materialization to provide high-performance route risk evaluation and city-level intelligence.

## 🚀 Quick Links

- [PROJECT_OVERVIEW.md](./PROJECT_OVERVIEW.md) - Goals, use cases, and requirements.
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System philosophy and core subsystems.
- [INSTALLATION.md](./INSTALLATION.md) - Setup guides for backend, mobile, and dashboard.
- [DEVELOPER_GUIDE.md](./DEVELOPER_GUIDE.md) - Engineering playbook and diagnostic protocols.
- [API_REFERENCE.md](./API_REFERENCE.md) - Backend HTTP contract.

## 🌲 Core Subsystems

1.  **Ingestion Substrate**: Normalizes and appends raw signals to the authoritative event log.
2.  **Spatial Compute**: Performs H3-indexed aggregation and risk field evaluation.
3.  **Projections & Workers**: Materializes derived states (risk cells, hotspots) for high-performance querying.
4.  **Operational Interface**: Thin mobile and web clients for real-time visualization.

## 🛠 Tech Stack

- **Backend**: NestJS (TypeScript), Python (Spatial Utils).
- **Persistence**: PostgreSQL + PostGIS (Authoritative), Redis (Hot-path caching).
- **Mobile**: Swift (iOS Native), Flutter (Cross-platform).
- **Indexing**: H3 (Uber's Hexagonal Hierarchical Spatial Index).

## ⚖️ License

MIT © 2026 **UDIE Engineering Group**. "Stability is the foundation of intelligence."
