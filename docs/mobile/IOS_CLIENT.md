# 📱 UDIE iOS Intelligence Client

A high-performance mobile interface providing real-time disruption intelligence and predictive routing for field operations.

⸻

## 💎 Mobile Features
- **Spatial Heatmaps**: Metal-accelerated rendering of H3 multi-resolution risk surfaces.
- **Predictive Pathing**: Real-time route evaluation against the materialized risk field.
- **Client-Side Diagnostics**: On-device monitoring of backend reliability and materialization freshness.

⸻

## 🛠️ Technical Substrate
- **Language**: Swift 6.0 (Concurrency Safe)
- **UI Framework**: SwiftUI + MapKit
- **Architecture**: Inward-pointing clean architecture with explicit Domain/Infrastructure boundaries.

⸻

## 🚀 Development Setup
1. Open `UDIE.xcodeproj` in **Xcode 16+**.
2. Configure `UDIE_API_BASE_URL` in `Info.plist` (or via Scheme → Run → Environment Variables; env wins).
3. Build and run on **Simulator** or **Physical Device**.

### Backend connectivity (physical device)
On **Simulator**, `http://localhost:3000` is correct. On a **physical device**, `localhost` is the phone, so the app cannot reach your Mac.

1. **Get your Mac’s LAN IP**: `ifconfig | grep "inet "` (e.g. `192.168.1.7`).
2. **Override the URL** (no code change):
   - **Xcode** → Product → Scheme → Edit Scheme… → **Run** → **Arguments** → **Environment Variables**.
   - Add: `UDIE_API_BASE_URL` = `http://YOUR_IP:3000` (e.g. `http://192.168.1.7:3000`).
3. **Clean and rebuild**: Product → Clean Build Folder (⇧⌘K), then Build (⌘R).
4. Ensure **engine-backend** is running and bound to `0.0.0.0` (it is in `engine-backend/src/main.ts`).
5. Same Wi‑Fi for Mac and phone.

If the app still shows `Cannot connect to backend at http://localhost:3000`, the binary was not rebuilt with the new URL—clean and run again.

⸻

MIT © 2026 **UDIE Engineering**. 
"Intelligence in the palm of your hand, grounded in geometry."
