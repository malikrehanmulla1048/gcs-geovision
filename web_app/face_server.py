"""
GCS-GeoVision Face Recognition Server
FastAPI + InsightFace | Port 5002
Run: uvicorn face_server:app --host 0.0.0.0 --port 5002 --reload
"""

import asyncio
import base64
import io
import json
import os
import sqlite3
import time
import uuid
from datetime import datetime
from pathlib import Path
from typing import Optional

import cv2
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

# ─── InsightFace ──────────────────────────────────────────────────────────────
import insightface
from insightface.app import FaceAnalysis

app = FastAPI(title="GCS-GeoVision Face Server", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── PATHS ────────────────────────────────────────────────────────────────────
BASE_DIR       = Path(__file__).parent
DB_PATH        = BASE_DIR / "face_db.db"
EMBEDDINGS_DIR = BASE_DIR / "face_embeddings"
EMBEDDINGS_DIR.mkdir(exist_ok=True)

# ─── MODEL (loaded once at startup) ──────────────────────────────────────────
print("[GeoVision] Loading InsightFace model (buffalo_l)...")
face_app = FaceAnalysis(name="buffalo_l", providers=["CPUExecutionProvider"])
face_app.prepare(ctx_id=0, det_size=(640, 640))
print("[GeoVision] Model ready - OK")

# ─── SSE EVENT BUS ───────────────────────────────────────────────────────────
sse_clients: list[asyncio.Queue] = []

async def broadcast_event(event_type: str, data: dict):
    payload = json.dumps({"type": event_type, "data": data, "ts": datetime.now().isoformat()})
    dead = []
    for q in sse_clients:
        try:
            q.put_nowait(payload)
        except asyncio.QueueFull:
            dead.append(q)
    for q in dead:
        sse_clients.remove(q)

# ─── DATABASE ─────────────────────────────────────────────────────────────────
def get_db():
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS enrolled_users (
            id          TEXT PRIMARY KEY,
            name        TEXT NOT NULL,
            email       TEXT UNIQUE NOT NULL,
            dept        TEXT,
            student_id  TEXT,
            enrolled_at TEXT NOT NULL,
            embedding_path TEXT
        );

        CREATE TABLE IF NOT EXISTS recognition_events (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     TEXT,
            user_name   TEXT,
            timestamp   TEXT NOT NULL,
            camera      TEXT,
            confidence  REAL,
            event_type  TEXT  -- 'entry' | 'threat'
        );

        CREATE TABLE IF NOT EXISTS cctv_alerts (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            alert_id      TEXT UNIQUE,
            type          TEXT NOT NULL,
            severity      TEXT NOT NULL,
            confidence    REAL,
            detail        TEXT,
            camera        TEXT,
            zone          TEXT,
            timestamp     TEXT NOT NULL,
            snapshot_path TEXT,
            acknowledged  INTEGER DEFAULT 0
        );
    """)
    conn.commit()
    conn.close()

init_db()

# ─── GEOFENCING STUB ──────────────────────────────────────────────────────────
def get_geofenced_ids() -> list[str]:
    """
    STUB: Returns list of user IDs currently inside the geofenced area.
    Replace with real geofencing data source when available.
    Priority: geofenced users are compared FIRST in the recognition loop.
    """
    return []

# ─── HELPERS ──────────────────────────────────────────────────────────────────
def b64_to_cv2(b64_str: str) -> np.ndarray:
    """Decode base64 JPEG/PNG string → OpenCV BGR image."""
    if b64_str.startswith("data:"):
        b64_str = b64_str.split(",", 1)[1]
    img_bytes = base64.b64decode(b64_str)
    arr = np.frombuffer(img_bytes, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Could not decode image")
    return img

def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    a_n = a / (np.linalg.norm(a) + 1e-10)
    b_n = b / (np.linalg.norm(b) + 1e-10)
    return float(np.dot(a_n, b_n))

def load_all_embeddings(priority_ids: list[str] = None):
    """
    Load enrolled embeddings from disk.
    Returns list of (user_id, name, dept, student_id, embedding) tuples,
    with geofenced (priority) users first.
    """
    conn = get_db()
    users = conn.execute("SELECT id, name, dept, student_id, embedding_path FROM enrolled_users").fetchall()
    conn.close()

    priority_ids = priority_ids or []
    priority_users = [u for u in users if u["id"] in priority_ids]
    rest_users     = [u for u in users if u["id"] not in priority_ids]
    ordered_users  = priority_users + rest_users

    results = []
    for u in ordered_users:
        path = Path(u["embedding_path"]) if u["embedding_path"] else None
        if path and path.exists():
            emb = np.load(str(path))
            results.append((u["id"], u["name"], u["dept"] or "", u["student_id"] or "", emb))
    return results

# ─── PATHS: SNAPSHOTS ────────────────────────────────────────────────────────
SNAPSHOTS_DIR = BASE_DIR / "cctv_snapshots"
SNAPSHOTS_DIR.mkdir(exist_ok=True)

# ─── MODELS ───────────────────────────────────────────────────────────────────
class EnrollRequest(BaseModel):
    frames: list[str]          # list of base64 JPEG frames (up to 5)
    name: str
    email: str
    dept: Optional[str] = ""
    student_id: Optional[str] = ""

class RecognizeRequest(BaseModel):
    frame: str                 # base64 JPEG frame
    camera: Optional[str] = "Camera 0 — Live"

class VerifyLoginRequest(BaseModel):
    frame: str                 # base64 JPEG from student login
    email: str                 # email of the student attempting login

class CCTVAlertRequest(BaseModel):
    alert_id:   str
    type:       str
    severity:   str            # low | medium | high | critical
    confidence: Optional[float] = 0.0
    detail:     Optional[str]  = ""
    camera:     Optional[str]  = "Camera 0 — Live"
    zone:       Optional[str]  = "Campus"
    timestamp:  Optional[str]  = None
    snapshot:   Optional[str]  = None   # base64 JPEG

class RecognizeResponse(BaseModel):
    matched: bool
    user_id: Optional[str] = None
    name: Optional[str] = None
    dept: Optional[str] = None
    student_id: Optional[str] = None
    confidence: Optional[float] = None
    face_count: int = 0
    event_type: Optional[str] = None  # 'entry' | 'threat' | None
    bbox: Optional[list] = None       # [x1_norm, y1_norm, x2_norm, y2_norm] 0-1 range

# ─── ROUTES ───────────────────────────────────────────────────────────────────

@app.get("/")
async def root():
    return {"status": "GCS-GeoVision Face Server running", "port": 5002}


@app.post("/enroll")
async def enroll(req: EnrollRequest):
    """
    Enroll a user by extracting InsightFace embeddings from multiple frames
    and averaging them into a single robust embedding.
    """
    if not req.frames:
        raise HTTPException(400, "No frames provided")

    embeddings = []
    for i, b64 in enumerate(req.frames):
        try:
            img = b64_to_cv2(b64)
        except Exception as e:
            continue

        faces = face_app.get(img)
        if not faces:
            continue

        # Take the largest face (by bounding box area)
        face = max(faces, key=lambda f: (f.bbox[2]-f.bbox[0]) * (f.bbox[3]-f.bbox[1]))
        embeddings.append(face.normed_embedding)

    if not embeddings:
        raise HTTPException(422, "No face detected in any of the provided frames. Ensure good lighting and clear face visibility.")

    avg_embedding = np.mean(embeddings, axis=0)
    avg_embedding = avg_embedding / (np.linalg.norm(avg_embedding) + 1e-10)

    # Check if user already enrolled → update
    conn = get_db()
    existing = conn.execute("SELECT id FROM enrolled_users WHERE email=?", (req.email,)).fetchone()

    if existing:
        user_id = existing["id"]
    else:
        user_id = str(uuid.uuid4())

    emb_path = EMBEDDINGS_DIR / f"{user_id}.npy"
    np.save(str(emb_path), avg_embedding)

    conn.execute("""
        INSERT INTO enrolled_users (id, name, email, dept, student_id, enrolled_at, embedding_path)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(email) DO UPDATE SET
            name=excluded.name, dept=excluded.dept, student_id=excluded.student_id,
            enrolled_at=excluded.enrolled_at, embedding_path=excluded.embedding_path
    """, (user_id, req.name, req.email, req.dept, req.student_id, datetime.now().isoformat(), str(emb_path)))
    conn.commit()
    conn.close()

    await broadcast_event("enrolled", {
        "user_id": user_id,
        "name": req.name,
        "frames_used": len(embeddings),
        "total_frames": len(req.frames),
    })

    return {
        "success": True,
        "user_id": user_id,
        "frames_used": len(embeddings),
        "total_frames": len(req.frames),
        "message": f"Enrolled successfully using {len(embeddings)}/{len(req.frames)} frames."
    }


@app.post("/recognize", response_model=RecognizeResponse)
async def recognize(req: RecognizeRequest):
    """
    Recognize faces in a single frame against the enrolled database.
    Uses geofenced IDs as priority comparisons.
    """
    try:
        img = b64_to_cv2(req.frame)
    except Exception as e:
        raise HTTPException(400, f"Invalid image: {e}")

    faces = face_app.get(img)
    face_count = len(faces)

    if not faces:
        return RecognizeResponse(matched=False, face_count=0)

    # Take largest face
    face = max(faces, key=lambda f: (f.bbox[2]-f.bbox[0]) * (f.bbox[3]-f.bbox[1]))
    query_emb = face.normed_embedding

    # Normalize bbox to 0-1 range
    h, w = img.shape[0], img.shape[1]
    bbox_norm = [
        round(float(face.bbox[0]) / w, 4),
        round(float(face.bbox[1]) / h, 4),
        round(float(face.bbox[2]) / w, 4),
        round(float(face.bbox[3]) / h, 4),
    ]

    # Geofencing prioritization
    priority_ids  = get_geofenced_ids()
    enrolled      = load_all_embeddings(priority_ids=priority_ids)

    if not enrolled:
        # No one enrolled → unknown threat
        return RecognizeResponse(matched=False, face_count=face_count, event_type="threat")

    THRESHOLD = 0.45
    best_score  = -1.0
    best_user   = None

    for (uid, name, dept, student_id, emb) in enrolled:
        score = cosine_similarity(query_emb, emb)
        if score > best_score:
            best_score = score
            best_user  = (uid, name, dept, student_id)

    matched = best_score >= THRESHOLD

    if matched:
        uid, name, dept, student_id = best_user
        event_type = "entry"

        # Log to DB
        conn = get_db()
        conn.execute("""
            INSERT INTO recognition_events (user_id, user_name, timestamp, camera, confidence, event_type)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (uid, name, datetime.now().isoformat(), req.camera, best_score, event_type))
        conn.commit()
        conn.close()

        await broadcast_event("recognition", {
            "matched": True,
            "user_id": uid,
            "name": name,
            "dept": dept,
            "student_id": student_id,
            "confidence": round(best_score * 100, 1),
            "camera": req.camera,
            "event_type": event_type,
            "timestamp": datetime.now().isoformat(),
        })

        return RecognizeResponse(
            matched=True, user_id=uid, name=name, dept=dept, student_id=student_id,
            confidence=round(best_score * 100, 1),
            face_count=face_count, event_type=event_type,
            bbox=bbox_norm
        )
    else:
        event_type = "threat"

        conn = get_db()
        conn.execute("""
            INSERT INTO recognition_events (user_id, user_name, timestamp, camera, confidence, event_type)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (None, "UNKNOWN", datetime.now().isoformat(), req.camera, round(best_score * 100, 1), event_type))
        conn.commit()
        conn.close()

        await broadcast_event("recognition", {
            "matched": False,
            "confidence": round(best_score * 100, 1),
            "camera": req.camera,
            "event_type": event_type,
            "timestamp": datetime.now().isoformat(),
        })

        return RecognizeResponse(
            matched=False,
            confidence=round(best_score * 100, 1),
            face_count=face_count,
            event_type=event_type,
            bbox=bbox_norm
        )


@app.get("/enrolled-users")
async def get_enrolled_users():
    conn = get_db()
    users = conn.execute(
        "SELECT id, name, email, dept, student_id, enrolled_at FROM enrolled_users ORDER BY enrolled_at DESC"
    ).fetchall()
    conn.close()
    return {"users": [dict(u) for u in users], "count": len(users)}


@app.get("/face-db-stats")
async def face_db_stats():
    conn = get_db()
    enrolled_count = conn.execute("SELECT COUNT(*) FROM enrolled_users").fetchone()[0]
    entry_count    = conn.execute("SELECT COUNT(*) FROM recognition_events WHERE event_type='entry'").fetchone()[0]
    threat_count   = conn.execute("SELECT COUNT(*) FROM recognition_events WHERE event_type='threat'").fetchone()[0]
    conn.close()
    return {
        "enrolled": enrolled_count,
        "entries_logged": entry_count,
        "threats_logged": threat_count,
    }


@app.get("/events")
async def sse_events():
    """Server-Sent Events endpoint for real-time recognition pushes."""
    queue: asyncio.Queue = asyncio.Queue(maxsize=50)
    sse_clients.append(queue)

    async def event_generator():
        try:
            # Send initial heartbeat
            yield "data: {\"type\":\"connected\"}\n\n"
            while True:
                try:
                    payload = await asyncio.wait_for(queue.get(), timeout=25.0)
                    yield f"data: {payload}\n\n"
                except asyncio.TimeoutError:
                    yield ": heartbeat\n\n"
        except asyncio.CancelledError:
            pass
        finally:
            if queue in sse_clients:
                sse_clients.remove(queue)

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        }
    )


# ─── VERIFY LOGIN ─────────────────────────────────────────────────────────
@app.post("/verify-login")
async def verify_login(req: VerifyLoginRequest):
    """
    Student face-login verification.
    Uses a higher threshold (0.50) than surveillance recognition.
    Checks that the face matches the specific enrolled user by email.
    """
    try:
        img = b64_to_cv2(req.frame)
    except Exception as e:
        raise HTTPException(400, f"Invalid image: {e}")

    faces = face_app.get(img)
    if not faces:
        return {"verified": False, "reason": "no_face", "face_count": 0,
                "message": "No face detected in the captured frame."}

    if len(faces) > 1:
        return {"verified": False, "reason": "multiple_faces", "face_count": len(faces),
                "message": "Multiple faces detected. Please ensure only you are in frame."}

    face      = max(faces, key=lambda f: (f.bbox[2]-f.bbox[0]) * (f.bbox[3]-f.bbox[1]))
    query_emb = face.normed_embedding

    # Load only this user's embedding
    conn = get_db()
    user_row = conn.execute(
        "SELECT id, name, dept, student_id, embedding_path FROM enrolled_users WHERE email=?",
        (req.email,)
    ).fetchone()
    conn.close()

    if not user_row:
        return {"verified": False, "reason": "not_enrolled",
                "message": "No face enrolled for this account. Please enrol first."}

    emb_path = Path(user_row["embedding_path"]) if user_row["embedding_path"] else None
    if not emb_path or not emb_path.exists():
        return {"verified": False, "reason": "embedding_missing",
                "message": "Face data not found. Please re-enrol."}

    stored_emb = np.load(str(emb_path))
    score      = cosine_similarity(query_emb, stored_emb)
    LOGIN_THRESHOLD = 0.50  # Stricter than surveillance (0.45)

    if score >= LOGIN_THRESHOLD:
        conn = get_db()
        conn.execute("""
            INSERT INTO recognition_events (user_id, user_name, timestamp, camera, confidence, event_type)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (user_row["id"], user_row["name"], datetime.now().isoformat(),
              "Student Login Portal", round(score * 100, 1), "login"))
        conn.commit(); conn.close()

        await broadcast_event("login", {
            "user_id": user_row["id"], "name": user_row["name"],
            "confidence": round(score * 100, 1),
            "timestamp": datetime.now().isoformat()
        })

        return {
            "verified":   True,
            "user_id":    user_row["id"],
            "name":       user_row["name"],
            "dept":       user_row["dept"] or "",
            "student_id": user_row["student_id"] or "",
            "confidence": round(score * 100, 1),
            "message":    f"Face verified — Welcome, {user_row['name']}!",
        }
    else:
        return {
            "verified":   False,
            "reason":     "mismatch",
            "confidence": round(score * 100, 1),
            "message":    "Face does not match account. Please try again.",
        }


# ─── CCTV ALERT PERSIST ───────────────────────────────────────────────────
@app.post("/cctv-alert")
async def create_cctv_alert(req: CCTVAlertRequest):
    """Persist a CCTV threat alert, optionally saving the snapshot to disk."""
    ts = req.timestamp or datetime.now().isoformat()

    snap_path = None
    if req.snapshot:
        try:
            img = b64_to_cv2(req.snapshot)
            fname = f"{req.alert_id}.jpg"
            snap_path = str(SNAPSHOTS_DIR / fname)
            cv2.imwrite(snap_path, img)
        except Exception:
            snap_path = None  # non-fatal

    conn = get_db()
    conn.execute("""
        INSERT OR IGNORE INTO cctv_alerts
          (alert_id, type, severity, confidence, detail, camera, zone, timestamp, snapshot_path)
        VALUES (?,?,?,?,?,?,?,?,?)
    """, (req.alert_id, req.type, req.severity, req.confidence,
          req.detail, req.camera, req.zone, ts, snap_path))
    conn.commit(); conn.close()

    await broadcast_event("cctv_alert", {
        "id": req.alert_id, "type": req.type, "severity": req.severity,
        "confidence": req.confidence, "camera": req.camera, "ts": ts
    })
    return {"saved": True, "snapshot_saved": snap_path is not None}


@app.get("/cctv-alerts")
async def get_cctv_alerts(limit: int = 50, severity: Optional[str] = None):
    """Retrieve recent CCTV alerts, optionally filtered by severity."""
    conn = get_db()
    if severity:
        rows = conn.execute(
            "SELECT * FROM cctv_alerts WHERE severity=? ORDER BY id DESC LIMIT ?",
            (severity, limit)
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT * FROM cctv_alerts ORDER BY id DESC LIMIT ?", (limit,)
        ).fetchall()
    conn.close()
    return {"alerts": [dict(r) for r in rows], "count": len(rows)}


@app.patch("/cctv-alert/{alert_id}/acknowledge")
async def acknowledge_alert(alert_id: str):
    """Mark a CCTV alert as acknowledged."""
    conn = get_db()
    conn.execute("UPDATE cctv_alerts SET acknowledged=1 WHERE alert_id=?", (alert_id,))
    conn.commit(); conn.close()
    return {"ok": True}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("face_server:app", host="0.0.0.0", port=5002, reload=True)
