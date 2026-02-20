# Interview Questions

Preparing for technical deep-dives? Here are the core challenges tackled in UDIE.

### Q1: Why perform risk calculation on the backend instead of the mobile client?
**Answer**: Two main reasons:
1. **Scalability**: Proximity checks against 10k+ events require spatial indexing (GIST) found in PostGIS. Mobile clients lack efficient native spatial databases for this scale.
2. **Consistency**: By centralizing logic in NestJS, any client (iOS, Web, etc.) gets the exact same risk assessment, preventing "logic drift."

### Q2: How do you handle rapid map movements in SwiftUI without crashing the API?
**Answer**: We use **Task Cancellation** and **Debouncing**. In `MapViewModel`, when `loadEvents` is called, any previous `fetchTask` is cancelled immediately. We also apply a `nanoseconds` sleep (debounce) to ensure the map has settled before firing the network request.

### Q3: Explain the spatial risk formula used in UDIE.
**Answer**: We use an **Exponential Distance Decay** formula: `Score = SUM(severity * confidence * exp(-distance / decay_constant))`.
- **Severity**: Impact magnitude.
- **Confidence**: Reliability of report.
- **e^-d**: Ensures that as distance from the route increases, the impact on the score drops off exponentially, not linearly.

### Q4: How is data integrity maintained in the ingestion pipeline?
**Answer**: We implement a **Unique Deduplication Key**. Every event is assigned a hash (e.g., `source + timestamp + rounded_coord`). The PostgreSQL unique index on `dedupe_key` prevents the same disruption from being mapped multiple times.
