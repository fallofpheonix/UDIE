# Frontend Architecture

UDIE features a multi-platform operational interface designed for real-time spatial visibility and thin-client execution.

## 📱 Mobile Clients

### 1. Native iOS (Swift/SwiftUI)
- **Repo Location**: `/UDIE`
- **Core Principle**: Centralized state management via `MapViewModel`.
- **Sync Engine**: Implements the `BackendSyncState` machine (`connecting`, `syncing`, `synced`, `error`).
- **Resilience**: Features dynamic API prefix resolution and LAN IP fallback for physical device testing.

### 2. Cross-Platform Mobile (Flutter)
- **Repo Location**: `/udie_mobile`
- **Features**: Radius-based event fetching, area news filtering (construction/safety/VIP), and route risk evaluation.
- **Routing**: Clean separation between UI layers and the `APIClient` substrate.

## 📊 Admin Dashboard (React/NextJS)
- **Repo Location**: `/dashboard-admin`
- **Focus**: City-level operations, snapshot inspection, and system health monitoring.
- **Visuals**: Leverages H3-indexed heatmaps and real-time WebSocket streams for disruption visualization.

## 🎨 Interface System Rules

- **Map-First Experience**: Actionable spatial intelligence must be the primary view.
- **Explicit State**: Connectivity, freshness, and sync status must always be visible and never implied.
- **Design Consistency**: Severity, confidence, and risk colors must remain consistent across all platforms.

## 🚫 Anti-Patterns

- **Local Intelligence**: Frontend must never calculate risk scores; it is strictly an observer.
- **Deep Navigation**: UI hierarchy must remain shallow to support high-pressure operational use.
- **Raw-Event Bloat**: Clients should only fetch viewport-bounded data to maintain performance.
