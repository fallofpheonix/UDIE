# Glossary

Definitions of domain-specific terms used throughout the UDIE project.

## Spatial Terms
- **PostGIS**: An external spatial database management system for PostgreSQL. It allows for advanced geographic analysis.
- **GEOGRAPHY**: A PostgreSQL type that treats coordinates as spherical (ellipsoidal) for high-precision distance calculation over long distances.
- **Distance Decay**: A mathematical concept where the influence of an event decreases as the distance from the point increases.
- **Bounding Box**: A rectangular area defined by `minLat`, `maxLat`, `minLng`, and `maxLng` used for regional event fetching.

## Domain Terms
- **GeoEvent**: A structured data point representing an urban disruption (e.g., a pothole or accident).
- **Severity**: A numerical score (1-5) representing the physical impact of a disruption on travel.
- **Confidence**: A probability score (0.0-1.0) representing the reliability of the disruption report source.
- **Risk Score**: A normalized value (0-1) representing the combined threat level of a route.
- **City Code**: A 3-letter identifier (e.g., DEL for Delhi) used to shard event data and optimize query performance.

## iOS Components
- **Clustered Markers**: A map visualization technique that merges nearby pins into a single count marker to reduce visual noise.
- **Risk Card**: The UI element displaying the final route intelligence to the end-user.
