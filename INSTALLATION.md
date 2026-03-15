# Installation Guide

Follow these steps to set up the UDIE ecosystem for local development and verification.

## 📦 Prerequisites

- **Docker & Docker Compose**
- **Node.js v18+ & npm**
- **Python 3.10+** (pyenv recommended)
- **Flutter SDK** (for mobile)
- **PostgreSQL / PostGIS** (if running outside Docker)

## 🚀 1. Backend Substrate (NestJS)

```bash
cd engine-backend
npm install
# Configure .env (see CONFIGURATION.md)
npm run db:migrate
npm run dev
```

## 🐍 2. Spatial Metrics Backend (Python)

```bash
cd udie_backend_py
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python main.py
```

## 📱 3. Mobile Clients

### iOS (Swift)
```bash
cd UDIE
open UDIE.xcodeproj
# Select Simulator/Device and Run
```

### Flutter (Cross-platform)
```bash
cd udie_mobile
flutter pub get
flutter run
```

## 📊 4. Admin Dashboard

```bash
cd dashboard-admin
npm install
npm run dev
```

## 🐳 5. Full Stack (Docker)

```bash
cd infra
docker-compose up --build
```

Refer to [DEPLOYMENT_GUIDE.md](file:///Users/fallofpheonix/Project/UDIE/DEPLOYMENT_GUIDE.md) for production environment setup.
