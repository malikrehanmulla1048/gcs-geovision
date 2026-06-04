"""
GeoVision — InsightFace FR Service
- Geofence-prioritised matching: geofenced users are checked first
- Handles enrolment (multi-angle embedding averaging)
- Returns bounding boxes + names + confidence for CCTV overlay
"""

import cv2
import numpy as np
import insightface
from insightface.app import FaceAnalysis
import threading
import time
from pathlib import Path
from typing import Optional
import logging

logger = logging.getLogger("fr_service")

SCREENSHOTS_DIR = Path(__file__).parent / "screenshots"
SCREENSHOTS_DIR.mkdir(exist_ok=True)

# Similarity threshold: cosine similarity above this = match
MATCH_THRESHOLD = 0.45
# Minimum face size (pixels) — InsightFace handles small faces well with det_size
MIN_FACE_SIZE = 20

_app_lock = threading.Lock()
_app: Optional[FaceAnalysis] = None


def get_app() -> FaceAnalysis:
    global _app
    if _app is None:
        with _app_lock:
            if _app is None:
                logger.info("Loading InsightFace model (buffalo_sc for speed on CPU)...")
                app = FaceAnalysis(
                    name="buffalo_sc",  # lightweight model, good for small/blurry faces
                    providers=["CPUExecutionProvider"]
                )
                # det_size=320 captures smaller faces; increase to 640 for accuracy
                app.prepare(ctx_id=0, det_size=(320, 320))
                _app = app
                logger.info("InsightFace ready.")
    return _app


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    a_norm = a / (np.linalg.norm(a) + 1e-6)
    b_norm = b / (np.linalg.norm(b) + 1e-6)
    return float(np.dot(a_norm, b_norm))


def extract_embeddings_from_frame(frame_bgr: np.ndarray) -> list[dict]:
    """
    Returns list of detected faces with:
    - bbox: [x1,y1,x2,y2]
    - embedding: 512-dim list
    - pose: {yaw, pitch, roll}
    - det_score: detection confidence
    """
    app = get_app()
    faces = app.get(frame_bgr)
    result = []
    for face in faces:
        result.append({
            "bbox": [int(x) for x in face.bbox.tolist()],
            "embedding": face.embedding.tolist(),
            "pose": {
                "yaw":   float(face.pose[1]) if face.pose is not None else 0.0,
                "pitch": float(face.pose[0]) if face.pose is not None else 0.0,
                "roll":  float(face.pose[2]) if face.pose is not None else 0.0,
            },
            "det_score": float(face.det_score),
        })
    return result


def enrol_from_embeddings(raw_embeddings: list[list[float]]) -> list[float]:
    """Average multiple embeddings into one enrolled embedding."""
    arr = np.array(raw_embeddings)
    avg = arr.mean(axis=0)
    # L2-normalise
    avg = avg / (np.linalg.norm(avg) + 1e-6)
    return avg.tolist()


class GeofencedMatcher:
    """
    Maintains a live database of enrolled face embeddings.
    Geofenced users are always checked first before the rest.
    """

    def __init__(self):
        self._lock = threading.RLock()
        self._geofenced: list[dict] = []   # {email, name, student_id, dept, embedding}
        self._others:    list[dict] = []   # same structure, non-geofenced
        self._blacklist: list[dict] = []   # blacklisted users

    def reload(self, enrolled_users: list[dict]):
        """
        enrolled_users: list of dicts with keys:
          email, name, student_id, dept, is_geofenced, is_blacklisted, embeddings (list of lists)
        """
        geo, others, bl = [], [], []
        for u in enrolled_users:
            embs = u.get("embeddings", [])
            if not embs:
                continue
            # Average all stored embeddings for this user
            avg_emb = np.array(embs).mean(axis=0)
            avg_emb = avg_emb / (np.linalg.norm(avg_emb) + 1e-6)
            entry = {
                "email":      u["email"],
                "name":       u.get("name", "Unknown"),
                "student_id": u.get("student_id", ""),
                "dept":       u.get("dept", ""),
                "embedding":  avg_emb,
                "is_geofenced":  bool(u.get("is_geofenced")),
                "is_blacklisted": bool(u.get("is_blacklisted")),
            }
            if u.get("is_blacklisted"):
                bl.append(entry)
            elif u.get("is_geofenced"):
                geo.append(entry)
            else:
                others.append(entry)

        with self._lock:
            self._geofenced  = geo
            self._others     = others
            self._blacklist  = bl

        logger.info(f"Matcher reloaded: {len(geo)} geofenced, {len(others)} others, {len(bl)} blacklisted")

    def match(self, query_embedding: list[float]) -> dict:
        """
        Returns best match dict:
        {
          matched: bool,
          email, name, student_id, dept,
          confidence: float (0-100),
          is_blacklisted: bool,
          threat_type: None | 'unverified' | 'unidentified' | 'blacklisted'
        }
        """
        q = np.array(query_embedding)
        q = q / (np.linalg.norm(q) + 1e-6)

        best_score = -1.0
        best_user  = None

        with self._lock:
            # Priority 1: Blacklisted
            for u in self._blacklist:
                s = cosine_similarity(q, u["embedding"])
                if s > best_score:
                    best_score = s
                    best_user  = u

            # If we already have a strong blacklist match, return immediately
            if best_user and best_score >= MATCH_THRESHOLD:
                return {
                    "matched":        True,
                    "email":          best_user["email"],
                    "name":           best_user["name"],
                    "student_id":     best_user["student_id"],
                    "dept":           best_user["dept"],
                    "confidence":     round(best_score * 100, 1),
                    "is_blacklisted": True,
                    "threat_type":    "blacklisted",
                }

            # Priority 2: Geofenced users
            for u in self._geofenced:
                s = cosine_similarity(q, u["embedding"])
                if s > best_score:
                    best_score = s
                    best_user  = u

            # Priority 3: Others
            for u in self._others:
                s = cosine_similarity(q, u["embedding"])
                if s > best_score:
                    best_score = s
                    best_user  = u

        if best_user and best_score >= MATCH_THRESHOLD:
            return {
                "matched":        True,
                "email":          best_user["email"],
                "name":           best_user["name"],
                "student_id":     best_user["student_id"],
                "dept":           best_user["dept"],
                "confidence":     round(best_score * 100, 1),
                "is_blacklisted": False,
                "threat_type":    None,  # legitimate entry
            }

        # No match found above threshold
        return {
            "matched":        False,
            "email":          None,
            "name":           "Unknown",
            "student_id":     None,
            "dept":           None,
            "confidence":     round(best_score * 100, 1) if best_score > 0 else 0.0,
            "is_blacklisted": False,
            "threat_type":    "unidentified",
        }


def process_frame(frame_bgr: np.ndarray, matcher: GeofencedMatcher,
                  gate_name: str = "Main Gate") -> dict:
    """
    Full FR pipeline for one frame.
    Returns:
    {
      detections: [{bbox, name, email, confidence, threat_type, color}],
      has_threat: bool,
      threat_type: str|None,
    }
    """
    app   = get_app()
    faces = app.get(frame_bgr)

    detections  = []
    has_threat  = False
    threat_type = None

    for face in faces:
        bbox      = [int(x) for x in face.bbox.tolist()]
        det_score = float(face.det_score)

        if det_score < 0.3:
            continue  # skip very low confidence detections

        result = matcher.match(face.embedding.tolist())

        # Determine overlay colour
        if result["threat_type"] == "blacklisted":
            color = [255, 0, 0]    # red
            has_threat  = True
            threat_type = "blacklisted"
        elif not result["matched"]:
            color = [0, 165, 255]  # orange
            has_threat  = True
            threat_type = threat_type or "unidentified"
        else:
            color = [0, 255, 0]    # green

        detections.append({
            "bbox":        bbox,
            "name":        result["name"],
            "email":       result["email"],
            "student_id":  result["student_id"],
            "dept":        result["dept"],
            "confidence":  result["confidence"],
            "threat_type": result["threat_type"],
            "is_blacklisted": result["is_blacklisted"],
            "color":       color,
        })

    return {
        "detections": detections,
        "has_threat": has_threat,
        "threat_type": threat_type,
    }


def save_screenshot(frame_bgr: np.ndarray, label: str = "") -> str:
    ts = int(time.time())
    fname = f"threat_{ts}_{label}.jpg"
    path  = SCREENSHOTS_DIR / fname
    cv2.imwrite(str(path), frame_bgr)
    return str(path)


def get_head_pose(frame_bgr: np.ndarray) -> dict | None:
    """
    Returns head pose from the first detected face, or None if no face.
    {yaw, pitch, roll} — yaw >20 = looking right, <-20 = looking left
    """
    app   = get_app()
    faces = app.get(frame_bgr)
    if not faces:
        return None
    face = faces[0]
    if face.pose is None:
        return None
    return {
        "yaw":   float(face.pose[1]),
        "pitch": float(face.pose[0]),
        "roll":  float(face.pose[2]),
        "det_score": float(face.det_score),
        "bbox":  [int(x) for x in face.bbox.tolist()],
    }
