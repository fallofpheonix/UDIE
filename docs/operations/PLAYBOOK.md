# 📖 UDIE Operational Playbook (v2.0)

This playbook provides standard operating procedures (SOPs) for maintaining, scaling, and troubleshooting the UDIE system.

---

## 🛠️ 1. Infrastructure Management

### 1.1 Scaling the Event Bus
To increase ingestion throughput for high-intensity urban events:
```bash
# Scale NATS/Kafka workers
docker-compose up -d --scale ingestion-worker=3
```

### 1.2 Resource Pruning
Prune legacy disruption events that have decayed below the significance threshold ($\epsilon = 0.15$):
```bash
# Manually trigger pruning script
./scripts/ops/prune-decayed-events.sh
```

---

## 🏥 2. Emergency Recovery

### 2.1 Deterministic Grid Rebuild
If the Redis Spatial Cache becomes corrupted or falls out of sync with the Event Log:
```bash
# 1. Flush Redis cache
docker exec udie-redis redis-cli FLUSHALL

# 2. Trigger rebuild from authoritative PostGIS events_log
curl -X POST http://localhost:3000/api/v1/ops/rebuild-grid
```

### 2.2 Database Migration Rollback
In case of a faulty schema update:
```bash
# Rollback last migration
npm run migration:revert
```

---

## 🧪 3. Diagnostic Procedures

### 3.1 Schema Integrity Check
Verify that the current database schema matches the v2.0 specification:
```bash
./scripts/diagnostics/check-schema.sh
```

### 3.2 Connectivity Audit
Audit the networking path from the physical device through the host Mac to the Docker bridge:
```bash
./scripts/diagnostics/network-audit.sh
```

---

## 📈 4. Performance Tuning

### 4.1 Adjusting Decay Constants
To slow down risk dissipation during prolonged crises:
1. Update `model_parameters` table:
   ```sql
   UPDATE model_parameters SET value = 1.5 WHERE key = 'temporal_decay_tau';
   ```
2. Notify the Invalidation Worker:
   ```bash
   curl -X POST http://localhost:3000/api/v1/ops/reload-parameters
   ```

---

MIT © 2026 **UDIE Engineering Group**. 
"Operational excellence is a prerequisite for system stability."
