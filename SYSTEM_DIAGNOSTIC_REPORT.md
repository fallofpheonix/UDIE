# UDIE System Diagnostic Report

Generated: 2026-03-11T10:15:38Z

## Summary

| Check | Status |
|---|---|
| Build | PASS |
| Risk tests | PASS |
| Docker daemon | PASS |
| Containers | PASS |
| Database connectivity | PASS |
| Migrations | PASS |
| Rebuild validation | PASS |
| Query plan validation | PASS |
| Health endpoint | PASS |
| Architecture diagnostics endpoint | PASS |
| City dashboard endpoint | PASS |

## Endpoints

- Health: http://localhost:3000/api/v1/health
- Architecture diagnostics: http://localhost:3000/api/v1/diagnostics/architecture
- City dashboard: http://localhost:3000/api/v1/city-dashboard?minLat=28.60&maxLat=28.70&minLng=77.10&maxLng=77.30

## Notes

- This report fails-fast during execution; a missing PASS indicates where execution stopped.
- DATABASE_URL used: postgresql://udie:udie@localhost:5432/udie
