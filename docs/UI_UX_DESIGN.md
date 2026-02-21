# UDIE UI/UX Design

## Design Goal
UDIE iOS is a risk-visualization shell over a geospatial risk engine. Map and risk decisions remain backend-owned.

## Visual Rules
- Semantic risk colors only: `LOW #34C759`, `MEDIUM #FF9F0A`, `HIGH #FF3B30`
- Rounded card surfaces: 16-24 pt radius
- Low visual density; map-first hierarchy
- Animation: `easeInOut` in `150-220ms`

## UI Hierarchy
- `MapSurfaceView`
- Floating controls (`FloatingButton`)
- Route sheet (`RouteInputSheet`)
- Risk summary (`RiskSummaryCard`)
- Event stack (`EventCellView` list)
- Detail modal (`EventDetailModal`)

## Module Structure
- `UDIE/UI/MapSurface/`
- `UDIE/UI/Components/`
- `UDIE/UI/Sheets/`
- `UDIE/UI/Modals/`
- `UDIE/UI/Theme/`

## State Boundary
UI consumes `MapUIState` and display models only.
No direct SQL, DTO, or scoring logic in views.

## Presentation Contract
`MapPresentationLogic`
- `requestRoute()`
- `refreshRisk()`

## Theme Tokens
- `ThemeManager`
- `ColorTokens`
- `SpacingScale`
- `ElevationTokens`

## Replaceability
UI layer can be replaced without backend, schema, or risk function changes.
