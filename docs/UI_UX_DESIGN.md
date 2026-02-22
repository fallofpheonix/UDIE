# UDIE UI/UX Design

## Scope
This UI spec covers the risk map and route planner surfaces:
- `/Users/fallofpheonix/Project/UDIE/UDIE/Features/Map/MapView.swift`
- `/Users/fallofpheonix/Project/UDIE/UDIE/Features/Route/RoutePlannerView.swift`

Architecture invariants are unchanged:
- Map UI is presentation-only.
- Route risk scoring remains backend-owned.
- API/DTO contracts are unchanged.

## Visual Anatomy
Layered composition in map screen:
1. `MapSurfaceView` (pure renderer)
2. Gradient and loading veil overlays
3. Top status strip (`StatusBadgeView`)
4. Mid route/risk instruction card (`RiskSummaryCard`)
5. Bottom event stack + floating controls (`EventCellView`, `FloatingButton`)

Route planner sheet composition:
1. Header copy
2. Origin/destination capsule inputs
3. Preset chips
4. Route readiness summary card
5. Fixed primary CTA

## Token System
Theme tokens live in `/Users/fallofpheonix/Project/UDIE/UDIE/UI/Theme/`.

### Color Tokens
- `appBackground`
- `surfacePrimary`, `surfaceSecondary`
- `surfaceTintedA`, `surfaceTintedB`, `surfaceTintedC`
- `cardStroke`
- `textPrimary`, `textSecondary`
- `controlFill`, `chipBackground`
- `mapFadeTop`, `mapFadeBottom`, `mapOverlaySoft`
- Risk semantic colors: `lowRisk`, `mediumRisk`, `highRisk`

### Light/Dark Matrix
| Token | Light | Dark |
| --- | --- | --- |
| `appBackground` | `#F4F7F8` | `#1C2328` |
| `surfacePrimary` | `#FFFFFF` | `#222A30` |
| `surfaceSecondary` | `#EEF3F5` | `#28323A` |
| `textPrimary` | `#17222A` | `#E7EEF3` |
| `textSecondary` | `#4E626E` | `#9FB0BA` |
| `controlFill` | `#F0F4F6` | `#2C373F` |

## Motion Rules
All component motion is `easeInOut` only.

| Interaction | Duration |
| --- | --- |
| Control press scale | `0.16s` |
| Card enter/exit transition | `0.20s` |
| Loading/risk state fade | `0.20s` |

Allowed transitions:
- `opacity`
- `move(edge:)` + `opacity`
- Press-scale to `0.98`

Forbidden transitions:
- spring animations
- map-camera-coupled custom motion

## UI Data Adapters
UI does not bind DTOs directly in list cards.

Adapter models:
- `EventListCardViewData` for event stack cells
- `RouteRiskViewData` for risk summary card

Adapter responsibilities:
- Formatting text labels for display
- Mapping event type to visual tint/surface
- Preserving domain invariants (no score calculation)

## Screenshot References
Reference visual direction sources:
- `https://miro.medium.com/v2/resize%3Afit%3A1400/1%2AwHceN8nQTtGFayZppmMOlA.jpeg`
- `https://cdn.sanity.io/images/9r24npb8/production/e528004ece9676f94544cd5ea9f04c5a533b8956-2400x1350.png?auto=format&fit=max&q=75&w=1200`
- `https://cdn.dribbble.com/userupload/16181250/file/original-98a2d4051e32b3075b4369cdfde603bf.jpg?resize=400x0`

## Non-goals
- No backend endpoint changes.
- No route scoring changes.
- No non-map tab redesign in this pass.
