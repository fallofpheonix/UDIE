# UDIE Interface System

This is the canonical UI and interaction document.
It replaces the split across spatial interaction, interface architecture, and UI specification docs.

## Interface Philosophy

UDIE is an operational intelligence interface, not a decorative dashboard.
The system should prioritize immediate spatial visibility, bounded interaction cost, and unambiguous state.

## Primary Experience

### Map-First
The user should reach actionable map intelligence immediately.

### Spatial Layers
Events, hotspots, route risk, and snapshots must be composable but visually ordered.

### Explicit State
Connectivity, freshness, and sync state must be surfaced clearly and never implied.

## Structural Rules

- Navigation hierarchy must remain shallow.
- The map is the primary operational surface.
- Dashboards and analytics remain secondary views over the same intelligence substrate.

## Design-System Rules

- Components must reflect severity, confidence, and risk clearly.
- Typography, tokens, and component behavior should remain consistent across clients.
- Performance constraints are part of the interface contract, especially for map rendering.

## Anti-Patterns to Avoid

- Hidden sync/failure state
- Over-deep navigation
- Full-surface rerenders for localized map changes
- Decorative UI that obscures operational priority
