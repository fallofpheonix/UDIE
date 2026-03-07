# ⚙️ UDIE Engine Core (Backend)

The authoritative spatial orchestration layer for the **Urban Disruption Intelligence Engine**. A NestJS ecosystem designed for high-concurrency "Weather Model" simulation and deterministic spatial evaluation.

⸻

## 💎 Atomic Features
- **Hardened Ingestion**: Immutable signal log with spatial deduplication and idempotency.
- **Materialized Surface**: Disruption intensity pre-computed into `risk_cells` for $O(1)$ lookup.
- **Architecture Integrity**: Automated enforcement of architecture invariants (e.g., **Law 2**).
- **Physical Kernels**: Geometric decay and temporal dissipation of disruption signals.

⸻

## 🚀 Quick Initiation

1. **Install Dependencies**:
   ```bash
   npm install
   ```
2. **Boot Substrate**:
   ```bash
   docker compose up -d --build
   ```
3. **Align Schema**:
   ```bash
   npm run migration:up
   ```
4. **Integrity Pass**:
   ```bash
   npm run test:risk        # Physics Validation
   npm run validate:plan    # Architecture Check
   ```

⸻

## 📖 Intelligence Registry
For deep architectural details, see the **[Master README](../README.md)** or explore:
- [**Core Architecture**](../docs/ARCHITECTURE.md)
- [**Model Physics**](../docs/WHITEPAPER.md)
- [**API Specification**](../docs/API.md)

⸻

MIT © 2026 **UDIE Engineering**. 
"Deterministic computation is the shadow of a predictable city."
