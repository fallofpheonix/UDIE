# UDIE Mobile (Flutter)

Cross-platform app for iOS + Android with map intelligence, area news, route risk, and source diagnostics.

## Features
- Interactive map with radius-based event fetch (1-20 km).
- Area News section with category filters (construction/accident/safety/VIP/hazard where available).
- Route Risk evaluator with deterministic scoring contract.
- Explicit sync states: `DISCONNECTED`, `CONNECTING`, `CONNECTED_UNSYNCED`, `SYNCED`, `ERROR`.

## Run
```bash
cd udie_mobile
flutter pub get
flutter run
```

## Backend URL Defaults
- iOS simulator: `http://127.0.0.1:8000`
- Android emulator: `http://10.0.2.2:8000`

Change backend/city/radius from the **Sources** tab.
