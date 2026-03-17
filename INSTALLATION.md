# Installation Guide

Follow these steps to set up the UDIE ecosystem for local development and verification.

## Prerequisites

- Docker & Docker Compose
- Node.js v18+ & npm
- Python 3.10+ (pyenv recommended)
- Flutter SDK (for mobile)
- PostgreSQL / PostGIS (if running outside Docker)

## 1. Backend (NestJS)

```bash
cd engine-backend
npm install
cp .env.example .env   # edit as needed
npm run db:migrate
npm run dev
```

## 2. Spatial Metrics Backend (Python)

```bash
cd udie_backend_py
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## 3. Mobile Clients

### iOS (Swift)
```bash
open UDIE/UDIE.xcodeproj
# Select Simulator/Device and Run
```

### Flutter (Cross-platform)
```bash
cd udie_mobile
flutter pub get
flutter run
```

## 4. Admin Dashboard

Open `dashboard-admin/index.html` directly in a browser or serve with any static file server.

## 5. Full Stack (Docker)

```bash
cd infra
docker compose up --build
```

See [CONFIGURATION.md](./CONFIGURATION.md) for environment variable reference.
