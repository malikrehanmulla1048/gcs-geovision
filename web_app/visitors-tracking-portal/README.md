# VIGIA — CCTV AI Dashboard

A full-stack visitor tracking portal with AI-powered analytics, persistent history, and role-based access control.

## Tech Stack
- **Frontend**: React 18 + Vite + Recharts
- **Backend**: Node.js + Express + SQLite (better-sqlite3)
- **Analytics Service**: Python FastAPI + OpenCV
- **Auth**: JWT (8h sessions, persisted in localStorage)

## Quick Start

### 1. Clone & Setup
```bash
git clone https://github.com/YOUR_USERNAME/cctv-ai-dashboard.git
cd cctv-ai-dashboard
```

### 2. Analytics Service (Python)
```bash
cd analytics_service
pip install -r requirements.txt
python main.py
# Runs on http://localhost:8001
```

### 3. Backend (Node.js)
```bash
cd backend
npm install
npm run dev
# Runs on http://localhost:3001
# Creates SQLite DB automatically
```

### 4. Frontend (React)
```bash
cd frontend
npm install
npm run dev
# Opens http://localhost:5173
```

## Default Login
| Username | Password | Role  |
|----------|----------|-------|
| admin    | admin123 | Admin |

## Features
- 🔐 Login/Logout with JWT (session persists on refresh)
- 📊 Dashboard with live stats & charts
- 📹 Live camera monitor (4 cameras)
- 🤖 AI frame analysis with visitor detection
- 💾 Persistent SQLite database — history survives restarts
- 🔔 Alert system for high occupancy
- 📋 Full visitor log history with filters
- 📈 Analytics with hourly & camera-level charts
- 👥 User management (admin only)

## Push to GitHub
```bash
git init
git add .
git commit -m "feat: initial VIGIA CCTV AI dashboard"
git remote add origin https://github.com/YOUR_USERNAME/cctv-ai-dashboard.git
git branch -M main
git push -u origin main
```

## Project Structure
```
cctv-ai-dashboard/
├── analytics_service/   # Python FastAPI + OpenCV
├── backend/             # Node.js + Express + SQLite
├── frontend/            # React + Vite
└── README.md
```

## Replace with Real AI (Production)
In `analytics_service/main.py`, replace `simulate_person_detection()` with:
- **YOLOv8**: `pip install ultralytics`
- **OpenCV HOG**: `cv2.HOGDescriptor`
- **RTSP streams**: Replace mock frame with `cv2.VideoCapture("rtsp://...")`