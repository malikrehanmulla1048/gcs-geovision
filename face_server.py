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

class RecognizeResponse(BaseModel):
    matched: bool
    user_id: Optional[str] = None
    name: Optional[str] = None
    dept: Optional[str] = None
    student_id: Optional[str] = None
    confidence: Optional[float] = None
    face_count: int = 0
    event_type: Optional[str] = None  # 'entry' | 'threat' | None

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
            face_count=face_count, event_type=event_type
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
            event_type=event_type
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


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("face_server:app", host="0.0.0.0", port=5002, reload=True)
