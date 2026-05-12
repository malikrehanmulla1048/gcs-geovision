from fastapi import FastAPI, File, UploadFile, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, List
import numpy as np
import cv2
import base64
import io
import time
import random
import json
from datetime import datetime
from PIL import Image

app = FastAPI(title="CCTV Analytics Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class AnalyticsResult(BaseModel):
    visitor_count: int
    confidence: float
    timestamp: str
    camera_id: str
    detections: List[dict]
    heatmap_data: Optional[List[List[float]]] = None
    alert: Optional[str] = None
    processing_time_ms: float

class FrameRequest(BaseModel):
    frame_base64: str
    camera_id: str
    threshold: float = 0.5

def decode_base64_image(base64_str: str):
    """Decode base64 image string to numpy array."""
    if "," in base64_str:
        base64_str = base64_str.split(",")[1]
    img_bytes = base64.b64decode(base64_str)
    img_array = np.frombuffer(img_bytes, dtype=np.uint8)
    img = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
    return img

def simulate_person_detection(img: np.ndarray, camera_id: str):
    """
    Simulates person detection. In production, replace with:
    - YOLOv8: from ultralytics import YOLO
    - OpenCV HOG: hog.detectMultiScale()
    - TensorFlow/PyTorch models
    """
    h, w = img.shape[:2]

    # Simulate detections based on image content
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    mean_brightness = np.mean(gray)

    # Simulate between 0-8 visitors based on image characteristics
    base_count = int((mean_brightness / 255) * 6)
    noise = random.randint(-1, 2)
    visitor_count = max(0, min(8, base_count + noise))

    detections = []
    for i in range(visitor_count):
        x = random.randint(0, w - 80)
        y = random.randint(0, h - 150)
        bw = random.randint(40, 80)
        bh = random.randint(100, 150)
        confidence = round(random.uniform(0.65, 0.98), 2)
        detections.append({
            "id": i + 1,
            "bbox": [x, y, bw, bh],
            "confidence": confidence,
            "class": "person",
            "track_id": random.randint(100, 999)
        })

    # Generate heatmap
    heatmap = np.zeros((10, 10), dtype=float)
    for det in detections:
        hx = min(9, int((det["bbox"][0] / w) * 10))
        hy = min(9, int((det["bbox"][1] / h) * 10))
        heatmap[hy][hx] += 1.0

    # Normalize heatmap
    if heatmap.max() > 0:
        heatmap = heatmap / heatmap.max()

    return visitor_count, detections, heatmap.tolist()

def check_alerts(visitor_count: int, camera_id: str) -> Optional[str]:
    """Generate alerts based on visitor count."""
    if visitor_count >= 7:
        return f"HIGH OCCUPANCY ALERT: {visitor_count} visitors detected on {camera_id}"
    elif visitor_count == 0:
        return None
    return None

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "CCTV Analytics", "timestamp": datetime.now().isoformat()}

@app.post("/analyze/frame", response_model=AnalyticsResult)
async def analyze_frame(request: FrameRequest):
    """Analyze a single video frame for visitor detection."""
    start_time = time.time()
    try:
        img = decode_base64_image(request.frame_base64)
        if img is None:
            raise HTTPException(status_code=400, detail="Invalid image data")

        visitor_count, detections, heatmap = simulate_person_detection(img, request.camera_id)
        alert = check_alerts(visitor_count, request.camera_id)
        processing_time = (time.time() - start_time) * 1000

        return AnalyticsResult(
            visitor_count=visitor_count,
            confidence=round(sum(d["confidence"] for d in detections) / max(len(detections), 1), 2),
            timestamp=datetime.now().isoformat(),
            camera_id=request.camera_id,
            detections=detections,
            heatmap_data=heatmap,
            alert=alert,
            processing_time_ms=round(processing_time, 2)
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/analyze/upload")
async def analyze_upload(file: UploadFile = File(...), camera_id: str = "CAM-01"):
    """Analyze an uploaded image file."""
    start_time = time.time()
    contents = await file.read()
    img_array = np.frombuffer(contents, dtype=np.uint8)
    img = cv2.imdecode(img_array, cv2.IMREAD_COLOR)

    if img is None:
        raise HTTPException(status_code=400, detail="Could not decode image")

    visitor_count, detections, heatmap = simulate_person_detection(img, camera_id)
    alert = check_alerts(visitor_count, camera_id)
    processing_time = (time.time() - start_time) * 1000

    return {
        "visitor_count": visitor_count,
        "confidence": round(sum(d["confidence"] for d in detections) / max(len(detections), 1), 2),
        "timestamp": datetime.now().isoformat(),
        "camera_id": camera_id,
        "detections": detections,
        "heatmap_data": heatmap,
        "alert": alert,
        "processing_time_ms": round(processing_time, 2)
    }

@app.get("/stats/summary")
async def get_summary():
    """Get summary statistics (mock data - connect to DB in production)."""
    return {
        "total_visitors_today": random.randint(120, 450),
        "peak_hour": f"{random.randint(9, 17)}:00",
        "average_dwell_time": f"{random.randint(3, 15)} mins",
        "active_cameras": 4,
        "alerts_today": random.randint(0, 5)
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001, reload=True)