# UDIE Failure Classification

When diagnosing a system failure, agents must classify the issue into one or more of the following categories. Failure to correctly classify often leads to red-herring debugging.

| Class | Description | Indicators |
| :--- | :--- | :--- |
| **NETWORK** | Connectivity between client and backend. | `ECONNREFUSED`, `ETIMEDOUT`, unreachable non-routable IPs. |
| **API CONTRACT** | Mismatch in routes or version prefixes. | `404 Not Found` for documented endpoints. |
| **CONFIG DRIFT** | Environment variable mismatch. | `localhost` on physical device, incorrect `PORT` or `DATABASE_URL`. |
| **SCHEMA DRIFT** | Code vs DB schema mismatch. | `relation "X" does not exist`, `column "Y" does not exist`. |
| **MIGRATION FAIL** | Partial or inconsistent migrations. | Inconsistent `migration_versions` table state. |
| **WORKER FAIL** | Background process crashes. | "Direct mutation prohibited", ingestion log stalls. |
| **STARTUP RACE** | Timing issues during container boot. | `ECONNREFUSED` on port 5432 during the first 10s of startup. |
| **QUERY LOGIC** | Incorrect SQL or type handling. | Invalid type casting, SQL syntax errors, `timestamp - text` errors. |
| **PROJECTION LAG** | Delay in grid materialization. | `materialization_lag > 1000ms`, risk cells out-of-sync with event log. |
| **IDEMPOTENCY FAIL** | Duplicate event processing. | Spikes in risk weight for single events, audit log double-entries. |
| **PARTITION DRIFT** | Inconsistent regional state. | H3 cell $A$ healthy in shard $X$ but stale in shard $Y$. |

> [!IMPORTANT]
> **Layered Failure Detection**: A single incident often spans multiple classes. For example, resolving a **NETWORK** issue might immediately reveal an underlying **API CONTRACT** drift or **SCHEMA DRIFT**.
