# Risk Register

| Risk ID | Description | Impact | Probability | Mitigation Strategy |
| :--- | :--- | :--- | :--- | :--- |
| R-001 | Spatial query latency increases with data volume. | High | Medium | Implement GIST partitioning and read-replicas for PostgreSQL. |
| R-002 | Crowdsourced data contains malicious or fake reports. | High | High | Implement a "Confidence" aging system; requiring multiple reports for high severity. |
| R-003 | iOS app battery drain due to constant GPS updates. | Medium | Medium | Use significant-location-change instead of continuous GPS when app is in background. |
| R-004 | API server downtime blocks routing intelligence. | High | Low | Deploy on multi-region Docker clusters with localized failover. |
| R-005 | PostGIS logic complexity makes debugging difficult. | Low | Low | maintain detailed logging in the `calculate_route_risk` function and NestJS service. |
| R-006 | API Contract mismatch during development. | Medium | Medium | Strict DTO validation and shared TypeScript interfaces (via private npm pkg or monorepo). |
