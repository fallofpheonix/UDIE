# Setup Guide

This guide ensures you have a stable environment for UDIE development.

## Prerequisites
- **macOS**: Required for iOS development and PostGIS Docker performance.
- **Xcode 15+**: For SwiftUI and MapKit.
- **Docker Desktop**: To host PostgreSQL, PostGIS, and Redis.
- **Node.js 20+**: For the NestJS backend.

## Environment Configuration

### Backend
1. Initialize `.env`:
   ```bash
   cp backend/.env.example backend/.env
   ```
2. Verify `DATABASE_URL` matches the Docker service names.

### iOS
1. Open `UDIE.xcodeproj`.
2. Ensure the `UDIE_API_BASE_URL` in `Info.plist` (or Environment variables) points to your backend.
   - Simulator: `http://127.0.0.1:3000`
   - Real Device: `http://<your-mac-ip>:3000`

## Troubleshooting

### 1. "Cannot connect to backend" (iOS)
- Ensure the backend is running: `curl http://localhost:3000/api/health`.
- If on a real device, ensure it's on the same Wi-Fi as your Mac.
- Check macOS firewall settings for port 3000.

### 2. PostGIS Error on Startup
- If Docker fails to start `postgres`, verify port 5432 isn't occupied by a local PostgreSQL instance.
- Run `docker compose down -v` to reset data if migrations are corrupted.

### 3. Apple Maps blank in Simulator
- Ensure the simulator has internet access.
- Check "Features > Location" in the Simulator menu to set a spoofed coordinate (e.g., Delhi: 28.6139, 77.2090).

## Advanced Build Commands
Inside `/backend`:
- **Start Full Stack**: `docker compose up --build -d`
- **Backend Build**: `npm run build`
- **Backend Lint**: `npm run lint`
- **Apply All Migrations**: `npm run migration:up`
- **Risk Unit Tests**: `npm run test:risk`
- **Rebuild Validation**: `npm run validate:rebuild`
- **Hot-Path Plan Validation**: `npm run validate:plan`
- **Database Reset**: `docker compose down -v && docker compose up --build -d`
