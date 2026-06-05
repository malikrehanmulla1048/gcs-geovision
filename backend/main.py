"""
GeoVision — FastAPI Backend
Endpoints: auth, enrolment, FR recognition, CCTV stream, threats, entry logs, visitors, cameras, health
"""

import asyncio
import base64
import io
import json
import logging
import os
import threading
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

import cv2
import numpy as np
import psutil
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, UploadFile, File, Form, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from pydantic import BaseModel

import db
from fr_service import (
    GeofencedMatcher, extract_embeddings_from_frame, enrol_from_embeddings,
    get_head_pose, process_frame, save_screenshot
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("main")

app = FastAPI(title="GeoVision Backend", version="2.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Globals ──────────────────────────────────────────────────────────
matcher = GeofencedMatcher()
_matcher_lock = threading.Lock()

# ─── RECOGNITION EVENT COOLDOWN ───────────────────────────────────────────────
# Prevents flooding the DB with one row per recognition tick.
# Stores { key -> last_logged_timestamp }. key = user_id or 'unknown_camera_id'.
_recog_cooldown: dict[str, float] = {}
RECOG_COOLDOWN_MATCH_S   = 30   # seconds between DB writes for a known user
RECOG_COOLDOWN_UNKNOWN_S = 10   # seconds between DB writes for unknown faces

def _should_log_event(key: str, cooldown_s: int) -> bool:
    """Return True (and arm the cooldown) if this event should be persisted."""
    now = time.time()
    last = _recog_cooldown.get(key, 0)
    if now - last >= cooldown_s:
        _recog_cooldown[key] = now
        return True
    return False


def reload_matcher():
    enrolled = db.get_enrolled_users_with_embeddings()
    matcher.reload(enrolled)


@app.on_event("startup")
async def startup():
    db.init_db()
    # Load FR model in background thread so startup is fast
    loop = asyncio.get_event_loop()
    loop.run_in_executor(None, reload_matcher)
    # Schedule screenshot cleanup daily
    asyncio.create_task(_daily_cleanup())
    logger.info("GeoVision backend started.")


async def _daily_cleanup():
    while True:
        await asyncio.sleep(86400)  # 24 hours
        db.delete_old_screenshots()


# ── HEALTH ──────────────────────────────────────────────────────────

@app.get("/health")
def health():
    db_path = Path(__file__).parent / "geovision.db"
    db_size_mb = round(db_path.stat().st_size / 1024 / 1024, 1) if db_path.exists() else 0
    cameras   = db.get_cameras()
    active_cams = [c for c in cameras if c["is_active"]]
    return {
        "ok":           True,
        "cpu_percent":  psutil.cpu_percent(interval=0.1),
        "ram_percent":  psutil.virtual_memory().percent,
        "db_size_mb":   db_size_mb,
        "cameras_total":  len(cameras),
        "cameras_active": len(active_cams),
        "uptime_seconds": int(time.time() - psutil.boot_time()),
    }


# ── AUTH ─────────────────────────────────────────────────────────────

class LoginReq(BaseModel):
    email: str
    password: str

class RegisterReq(BaseModel):
    email: str
    password: str
    name: str
    student_id: str
    phone: Optional[str] = None
    dept: Optional[str] = None
    year: Optional[str] = None


@app.post("/auth/login")
def login(req: LoginReq):
    result = db.authenticate(req.email, req.password)
    if not result["ok"]:
        raise HTTPException(400, result["error"])
    u = result["user"]
    return {
        "ok": True,
        "user": {
            "email":         u["email"],
            "name":          u["name"],
            "role":          u["role"],
            "student_id":    u["student_id"],
            "phone":         u["phone"],
            "dept":          u["dept"],
            "year":          u["year"],
            "face_enrolled": bool(u["face_enrolled"]),
            "is_geofenced":  bool(u["is_geofenced"]),
            "is_blacklisted": bool(u["is_blacklisted"]),
            "joined_at":     u["joined_at"],
        }
    }


@app.post("/auth/register")
def register(req: RegisterReq):
    result = db.create_user(
        email=req.email, password=req.password, name=req.name,
        student_id=req.student_id, phone=req.phone, dept=req.dept, year=req.year
    )
    if not result["ok"]:
        raise HTTPException(400, result["error"])
    u = db.get_user(req.email)
    return {"ok": True, "user": u}


@app.get("/auth/user/{email}")
def get_user(email: str):
    u = db.get_user(email)
    if not u:
        raise HTTPException(404, "User not found")
    return u


@app.put("/auth/user/{email}/profile")
def update_profile(email: str, body: dict = Body(...)):
    db.update_user_profile(
        email=email,
        name=body.get("name", ""),
        phone=body.get("phone", ""),
        dept=body.get("dept", ""),
        year=body.get("year", ""),
    )
    return {"ok": True}


# ── FACE ENROLMENT ───────────────────────────────────────────────────

@app.post("/enrol/frame")
async def enrol_frame(
    email: str = Form(...),
    step:  str = Form(...),   # 'front' | 'left' | 'right'
    image: UploadFile = File(...)
):
    """
    Check head pose for current step.
    Returns {ok, pose, message, frame_accepted}
    """
    data  = await image.read()
    arr   = np.frombuffer(data, np.uint8)
    frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)

    if frame is None:
        raise HTTPException(400, "Could not decode image")
    
    import time
    cv2.imwrite(f"debug_frame_{int(time.time())}.jpg", frame)

    pose = get_head_pose(frame)
    if not pose:
        return {"ok": False, "message": "No face detected. Please centre your face.", "frame_accepted": False}

    yaw = pose["yaw"]
    accepted = False
    message  = ""

    if step == "front":
        if -15 <= yaw <= 15:
            accepted = True
            message  = "Good — front captured."
        else:
            message = "Please look straight at the camera."

    elif step == "left":
        if yaw < -18:
            accepted = True
            message  = "Good — left captured."
        else:
            message = "Please turn your head to the LEFT."

    elif step == "right":
        if yaw > 18:
            accepted = True
            message  = "Good — right captured."
        else:
            message = "Please turn your head to the RIGHT."

    return {
        "ok":             True,
        "pose":           pose,
        "frame_accepted": accepted,
        "message":        message,
    }


@app.post("/enrol/submit")
async def enrol_submit(
    email:  str = Form(...),
    front:  UploadFile = File(...),
    left:   UploadFile = File(...),
    right:  UploadFile = File(...)
):
    """Extract embeddings from 3 frames and store enrolled embedding."""
    frames_raw  = [await f.read() for f in [front, left, right]]
    embeddings  = []

    for raw in frames_raw:
        arr   = np.frombuffer(raw, np.uint8)
        frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if frame is None:
            raise HTTPException(400, "Could not decode one of the images")
        faces = extract_embeddings_from_frame(frame)
        if not faces:
            raise HTTPException(400, "No face detected in one of the submitted frames")
        embeddings.append(faces[0]["embedding"])

    final_emb = enrol_from_embeddings(embeddings)
    db.save_face_embedding(email, final_emb)

    # Reload matcher so the new user is immediately recognisable
    reload_matcher()

    return {"ok": True, "message": "Face enrolled successfully."}


@app.post("/enrol/pose_check")
async def pose_check(image: UploadFile = File(...)):
    """Quick pose check — returns yaw/pitch/roll and face bbox."""
    data  = await image.read()
    arr   = np.frombuffer(data, np.uint8)
    frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if frame is None:
        return {"face": False}
    pose = get_head_pose(frame)
    if not pose:
        return {"face": False}
    return {"face": True, **pose}


# ── CCTV / RECOGNITION ───────────────────────────────────────────────

@app.post("/recognize")
async def recognize(
    gate:  str = Form("Main Gate"),
    image: UploadFile = File(...)
):
    """Run FR on a single frame. Returns detections + threat info."""
    data  = await image.read()
    arr   = np.frombuffer(data, np.uint8)
    frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if frame is None:
        raise HTTPException(400, "Could not decode image")

    result = process_frame(frame, matcher, gate)

    # Log recognised entries and threats
    for det in result["detections"]:
        if det["email"]:
            db.add_entry_log(
                user_email=det["email"],
                user_name=det["name"],
                user_id=det["student_id"] or "",
                dept=det["dept"] or "",
                gate=gate,
                log_type="entry",
                confidence=det["confidence"],
            )
        if det["threat_type"]:
            snap_path = None
            if det["threat_type"] in ("blacklisted", "unidentified"):
                snap_path = save_screenshot(frame, det["threat_type"])
            db.add_threat(
                threat_type=det["threat_type"],
                gate=gate,
                user_email=det["email"],
                user_name=det["name"],
                confidence=det["confidence"],
                snapshot_path=snap_path,
            )

    return result


# ── WEBSOCKET CAMERA STREAM ──────────────────────────────────────────

active_cameras: dict[int, cv2.VideoCapture] = {}

def get_capture(camera_id: int) -> Optional[cv2.VideoCapture]:
    cameras = db.get_cameras()
    cam = next((c for c in cameras if c["id"] == camera_id), None)
    if not cam:
        return None
    source_str = cam["source"]
    # Convert to int if it's a digit (webcam index)
    source = int(source_str) if source_str.isdigit() else source_str
    if camera_id not in active_cameras or not active_cameras[camera_id].isOpened():
        cap = cv2.VideoCapture(source)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        active_cameras[camera_id] = cap
    return active_cameras[camera_id]


@app.websocket("/ws/camera/{camera_id}")
async def camera_ws(websocket: WebSocket, camera_id: int):
    """
    Streams JPEG frames as base64 JSON over WebSocket.
    Each message: {frame_b64, detections, has_threat, timestamp}
    FR runs every 5th frame to reduce CPU load.
    """
    await websocket.accept()
    cap = get_capture(camera_id)

    if not cap or not cap.isOpened():
        await websocket.send_json({"error": "Camera not available"})
        await websocket.close()
        return

    frame_count = 0
    gate_name   = "Main Gate"
    cameras = db.get_cameras()
    cam = next((c for c in cameras if c["id"] == camera_id), None)
    if cam:
        gate_name = cam["name"]

    last_detections = []

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                await asyncio.sleep(0.1)
                continue

            frame_count += 1

            # Run FR every 5th frame
            if frame_count % 5 == 0:
                result = process_frame(frame, matcher, gate_name)
                last_detections = result["detections"]

                # Auto-log and save threats
                for det in last_detections:
                    if det["threat_type"]:
                        if _should_log_event(f"threat:{gate_name}", RECOG_COOLDOWN_UNKNOWN_S):
                            snap_path = save_screenshot(frame, det["threat_type"])
                            db.add_threat(
                                threat_type=det["threat_type"],
                                gate=gate_name,
                                user_email=det.get("email"),
                                user_name=det.get("name"),
                                confidence=det.get("confidence"),
                                snapshot_path=snap_path,
                            )
                    if det["email"] and not det["threat_type"]:
                        if _should_log_event(f"entry:{det['email']}:{gate_name}", RECOG_COOLDOWN_MATCH_S):
                            db.add_entry_log(
                                user_email=det["email"],
                                user_name=det["name"],
                                user_id=det.get("student_id") or "",
                                dept=det.get("dept") or "",
                                gate=gate_name,
                                log_type="entry",
                                confidence=det["confidence"],
                            )

            # Draw overlay on frame
            annotated = frame.copy()
            for det in last_detections:
                x1, y1, x2, y2 = det["bbox"]
                color = tuple(det["color"])
                cv2.rectangle(annotated, (x1, y1), (x2, y2), color, 2)
                label = f"{det['name']} {det['confidence']:.0f}%"
                cv2.rectangle(annotated, (x1, y1 - 22), (x1 + len(label) * 9, y1), color, -1)
                cv2.putText(annotated, label, (x1 + 2, y1 - 6),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1)

            # Encode to JPEG
            _, buf = cv2.imencode(".jpg", annotated, [cv2.IMWRITE_JPEG_QUALITY, 75])
            b64 = base64.b64encode(buf.tobytes()).decode()

            msg = {
                "frame_b64":  b64,
                "detections": last_detections,
                "has_threat": any(d["threat_type"] for d in last_detections),
                "timestamp":  datetime.utcnow().isoformat(),
            }
            await websocket.send_json(msg)
            await asyncio.sleep(0.033)  # ~30 FPS cap

    except WebSocketDisconnect:
        logger.info(f"Camera {camera_id} WebSocket disconnected")
    except Exception as e:
        logger.error(f"Camera stream error: {e}")


# ── STATS ────────────────────────────────────────────────────────────

@app.get("/stats")
def stats():
    return db.get_stats_today()


@app.get("/on_campus")
def on_campus():
    return db.get_on_campus_users()


# ── ENTRY LOGS ───────────────────────────────────────────────────────

@app.get("/entry_logs")
def entry_logs(
    limit:  int = 100,
    offset: int = 0,
    type_filter: str = "all",
    gate_filter: str = "all",
    search: str = ""
):
    return db.get_entry_logs(limit, offset, type_filter, gate_filter, search or None)


@app.get("/entry_logs/user/{email}")
def user_entry_logs(email: str):
    return db.get_entry_logs_for_user(email)


@app.post("/entry_logs/exit")
def log_exit(body: dict = Body(...)):
    """Manually log an exit for a user."""
    db.add_entry_log(
        user_email=body.get("email"),
        user_name=body.get("name", ""),
        user_id=body.get("student_id", ""),
        dept=body.get("dept", ""),
        gate=body.get("gate", "Main Gate"),
        log_type="exit",
        confidence=100.0,
    )
    return {"ok": True}


# ── THREATS ──────────────────────────────────────────────────────────

@app.get("/threats")
def get_threats(status: str = None):
    return db.get_threats(status)


@app.post("/threats/{threat_id}/resolve")
def resolve_threat(threat_id: int):
    db.resolve_threat(threat_id)
    return {"ok": True}


@app.get("/threats/screenshot/{filename}")
def get_screenshot(filename: str):
    path = Path(__file__).parent / "screenshots" / filename
    if not path.exists():
        raise HTTPException(404, "Screenshot not found")
    return FileResponse(str(path))


# ── CAMERAS ──────────────────────────────────────────────────────────

@app.get("/cameras")
def get_cameras():
    return db.get_cameras()


class AddCameraReq(BaseModel):
    name:   str
    source: str   # "0", "1", or RTSP URL

@app.post("/cameras")
def add_camera(req: AddCameraReq):
    cam_id = db.add_camera(req.name, req.source)
    return {"ok": True, "id": cam_id}


@app.delete("/cameras/{camera_id}")
def delete_camera(camera_id: int):
    if camera_id in active_cameras:
        active_cameras[camera_id].release()
        del active_cameras[camera_id]
    db.delete_camera(camera_id)
    return {"ok": True}


# ── USERS / PROFILES ─────────────────────────────────────────────────

@app.get("/users")
def get_users():
    return db.get_all_users()


@app.post("/users/{email}/blacklist")
def blacklist_user(email: str, body: dict = Body(...)):
    db.set_blacklisted(email, body.get("blacklisted", True))
    reload_matcher()
    return {"ok": True}


@app.post("/users/{email}/geofence")
def geofence_user(email: str, body: dict = Body(...)):
    db.set_geofenced(email, body.get("geofenced", True), body.get("zone"))
    reload_matcher()
    return {"ok": True}


@app.post("/fr/reload")
def reload_fr():
    reload_matcher()
    return {"ok": True, "enrolled_count": len(db.get_enrolled_users_with_embeddings())}


# ── VISITORS ─────────────────────────────────────────────────────────

@app.get("/visitors")
def get_visitors():
    return db.get_visitors()


class AddVisitorReq(BaseModel):
    name:      str
    phone:     str
    purpose:   str
    host:      str
    dept:      str
    id_number: str
    gate:      str

@app.post("/visitors")
def add_visitor(req: AddVisitorReq):
    vid = db.add_visitor(req.name, req.phone, req.purpose, req.host, req.dept, req.id_number, req.gate)
    return {"ok": True, "id": vid}


@app.post("/visitors/{vid}/checkout")
def checkout_visitor(vid: int):
    db.checkout_visitor(vid)
    return {"ok": True}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
