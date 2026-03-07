# 🚀 UDIE Deployment Procedure

UDIE follows a **Spatial Sharding** deployment model to ensure nationwide stability and deterministic performance.

⸻

## 🏗️ Production Substrate

- **Cloud Architecture**: AWS / Terraform-provisioned infrastructure.
- **Database**: RDS Aurora (Postgres 16) with PostGIS and H3 extensions.
- **Compute**: EKS (Elastic Kubernetes Service) with node affinity for regional **H3 Res 6** partitions.
- **Cache**: In-memory `RiskGrid` resident on evaluation nodes for $O(1)$ cell lookup.

⸻

## 🔄 CI/CD Orchestration

1. **Static Audit**: Linting and forbidden ORM scans to enforce **Law 2** (Minimal Persistence Knowledge).
2. **Physics Validation**: Automated `rebuild_drill` to ensure 1:1 parity between `events_log` and the materialized surface.
3. **Containerization**: Multistage Docker builds for the Engine runtime.
4. **Blue/Green Shift**: Traffic shifted only after the new region has fully materialized its risk surface in memory.

⸻

## 🚑 Emergency Disaster Recovery

- **Rollback**: Instant revert to specific Docker digests.
- **Point-in-Time Restore**: RDS PITR for the canonical `events_log` (the absolute source of truth).
- **Reprojection**: Automated reconstruction of `risk_cells` from the log using the `rebuild_derived_state` protocol.

⸻

MIT © 2026 **UDIE Engineering**. 
"Deploy with confidence, scale with geometry."
