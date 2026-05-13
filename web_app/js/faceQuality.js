/**
 * GeoVision — Face Quality Scoring Module
 * js/faceQuality.js
 *
 * Client-side face quality assessment using pixel analysis.
 * Works before and independently of InsightFace backend.
 * All thresholds are configurable via FaceQuality.CFG.
 */
const FaceQuality = (() => {

  // ── CONFIGURABLE THRESHOLDS ──────────────────────────────────────────────
  const CFG = {
    BRIGHTNESS_MIN:        50,    // 0-255; below → "Lighting too low"
    BRIGHTNESS_MAX:       220,    // above → overexposed/backlit
    BRIGHTNESS_IDEAL_MIN:  80,
    BRIGHTNESS_IDEAL_MAX: 180,

    BLUR_THRESHOLD:        60,    // Laplacian variance; below → "Blurry"

    FACE_SIZE_MIN:        0.07,   // fraction of frame area; below → "Move closer"
    FACE_SIZE_MAX:        0.65,   // above → "Move slightly back"
    FACE_SIZE_IDEAL_MIN:  0.14,
    FACE_SIZE_IDEAL_MAX:  0.50,

    CENTER_TOLERANCE:     0.28,   // fraction of frame dimension off-center

    YAW_MAX:              30,     // degrees
    PITCH_MAX:            25,
    ROLL_MAX:             20,

    MIN_SCORE:            65,     // 0-100; below → capture not allowed
  };

  // ── INTERNAL CANVAS FOR PIXEL OPS ───────────────────────────────────────
  const _sc = document.createElement('canvas');
  const _sx = _sc.getContext('2d');

  function _sample(videoEl, w = 80, h = 60) {
    _sc.width = w; _sc.height = h;
    _sx.drawImage(videoEl, 0, 0, w, h);
    return _sx.getImageData(0, 0, w, h);
  }

  // ── BRIGHTNESS (Rec.709 luminance) ───────────────────────────────────────
  function measureBrightness(videoEl) {
    const d = _sample(videoEl).data;
    let t = 0;
    const n = d.length / 4;
    for (let i = 0; i < d.length; i += 4)
      t += 0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2];
    return t / n; // 0-255
  }

  // ── SHARPNESS (approximate Laplacian variance) ───────────────────────────
  function measureSharpness(videoEl) {
    const W = 80, H = 60;
    const d = _sample(videoEl, W, H).data;
    const g = new Float32Array(W * H);
    for (let i = 0; i < W * H; i++)
      g[i] = 0.299 * d[i * 4] + 0.587 * d[i * 4 + 1] + 0.114 * d[i * 4 + 2];
    let sum = 0, cnt = 0;
    for (let y = 1; y < H - 1; y++) {
      for (let x = 1; x < W - 1; x++) {
        const lap = -4 * g[y * W + x]
          + g[(y - 1) * W + x] + g[(y + 1) * W + x]
          + g[y * W + x - 1]   + g[y * W + x + 1];
        sum += lap * lap; cnt++;
      }
    }
    return cnt ? sum / cnt : 0;
  }

  // ── BACKLIGHT DETECTION ──────────────────────────────────────────────────
  function detectBacklight(videoEl) {
    const W = 80, H = 60;
    const d = _sample(videoEl, W, H).data;
    let cL = 0, eL = 0, cn = 0, en = 0;
    for (let y = 0; y < H; y++) {
      for (let x = 0; x < W; x++) {
        const i = (y * W + x) * 4;
        const l = 0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2];
        const center = x > W * 0.25 && x < W * 0.75 && y > H * 0.25 && y < H * 0.75;
        if (center) { cL += l; cn++; } else { eL += l; en++; }
      }
    }
    return en > 0 && cn > 0 && (eL / en) > (cL / cn) * 1.6;
  }

  // ── MAIN EVALUATE ────────────────────────────────────────────────────────
  /**
   * Score a video frame for face capture quality.
   * @param {HTMLVideoElement} videoEl
   * @param {Object|null} faceResult - optional /recognize response {face_count, bbox?, pose?}
   * @returns {{ score:number, ready:boolean, message:string, icon:string, level:string, checks:{} }}
   */
  function evaluate(videoEl, faceResult = null) {
    if (!videoEl || !videoEl.videoWidth)
      return _fail(0, 'Camera not ready', '📷');

    const VW = videoEl.videoWidth, VH = videoEl.videoHeight;
    let score = 100;
    const checks = {};

    // 1. FACE COUNT
    if (faceResult !== null) {
      const fc = faceResult.face_count ?? 0;
      checks.faceCount = fc;
      if (fc === 0) return _fail(0, 'No face detected', '👤');
      if (fc > 1)   return _fail(0, 'Multiple faces detected', '👥');
    }

    // 2. BRIGHTNESS
    const br = measureBrightness(videoEl);
    checks.brightness = Math.round(br);
    if (br < CFG.BRIGHTNESS_MIN)
      return _fail(score - 50, 'Lighting too low — move to a brighter area', '💡');
    if (br > CFG.BRIGHTNESS_MAX) {
      if (detectBacklight(videoEl))
        return _fail(score - 45, 'Too much backlight — face the light source', '☀️');
      return _fail(score - 35, 'Image overexposed — reduce direct light', '🔆');
    }
    if (br < CFG.BRIGHTNESS_IDEAL_MIN || br > CFG.BRIGHTNESS_IDEAL_MAX) score -= 8;
    checks.brightnessOk = true;

    // 3. SHARPNESS
    const sh = measureSharpness(videoEl);
    checks.sharpness = Math.round(sh);
    if (sh < CFG.BLUR_THRESHOLD)
      return _fail(score - 40, 'Image is blurry — hold still', '🌫️');
    checks.sharpnessOk = true;

    // 4. FACE SIZE + CENTERING (if bbox provided by server)
    if (faceResult && faceResult.bbox) {
      const [x1, y1, x2, y2] = faceResult.bbox;
      const frac = ((x2 - x1) * (y2 - y1)) / (VW * VH);
      checks.faceFraction = +frac.toFixed(3);
      if (frac < CFG.FACE_SIZE_MIN)
        return _fail(score - 35, 'Move closer to the camera', '🔍');
      if (frac > CFG.FACE_SIZE_MAX)
        return _fail(score - 25, 'Move slightly back', '↩️');
      if (frac < CFG.FACE_SIZE_IDEAL_MIN) score -= 8;

      const cx = (x1 + x2) / 2, cy = (y1 + y2) / 2;
      const dx = Math.abs(cx - VW / 2) / VW;
      const dy = Math.abs(cy - VH / 2) / VH;
      checks.centering = { dx: +dx.toFixed(3), dy: +dy.toFixed(3) };

      if (dx > CFG.CENTER_TOLERANCE || dy > CFG.CENTER_TOLERANCE) {
        const dir = dx > dy
          ? (cx < VW / 2 ? 'move right' : 'move left')
          : (cy < VH / 2 ? 'move down'  : 'move up');
        return _fail(score - 30, `Center your face — ${dir}`, '🎯');
      }
      if (dx > CFG.CENTER_TOLERANCE * 0.6 || dy > CFG.CENTER_TOLERANCE * 0.6) score -= 8;
      checks.centeringOk = true;
    }

    // 5. HEAD POSE (if InsightFace returns pose)
    if (faceResult && faceResult.pose) {
      const [pitch, yaw, roll] = faceResult.pose;
      checks.pose = { pitch: Math.round(pitch), yaw: Math.round(yaw), roll: Math.round(roll) };
      if (Math.abs(yaw)   > CFG.YAW_MAX)
        return _fail(score - 25, yaw > 0 ? 'Turn left slightly' : 'Turn right slightly', '↔️');
      if (Math.abs(pitch) > CFG.PITCH_MAX)
        return _fail(score - 20, pitch > 0 ? 'Lower your chin' : 'Raise your chin', '↕️');
      if (Math.abs(roll)  > CFG.ROLL_MAX)
        return _fail(score - 15, 'Keep your head straight', '🔄');
      if (Math.abs(yaw) > 15 || Math.abs(pitch) > 15) score -= 5;
      checks.poseOk = true;
    }

    // 6. FINAL
    score = Math.max(0, Math.min(100, score));
    const ready = score >= CFG.MIN_SCORE;
    return {
      score, ready, checks,
      message: ready ? (score >= 90 ? 'Face capture ready ✓' : 'Face detected — ready') : 'Hold still — validating',
      icon:    ready ? '✅' : '🟡',
      level:   ready ? 'ok' : 'warning',
    };
  }

  function _fail(rawScore, message, icon) {
    return { score: Math.max(0, rawScore), ready: false, message, icon, level: 'error', checks: {} };
  }

  // ── BEST FRAME PICKER ────────────────────────────────────────────────────
  function pickBestFrame(frames) {
    // frames: [{dataUrl, score}]
    if (!frames.length) return null;
    return frames.reduce((best, f) => f.score > best.score ? f : best, frames[0]);
  }

  // ── AUDIT LOG ────────────────────────────────────────────────────────────
  function log(event, details = {}) {
    const entry = { ts: new Date().toISOString(), event, ...details };
    console.info('[FaceQuality]', entry);
    try {
      const log = JSON.parse(sessionStorage.getItem('gv_fq_log') || '[]');
      log.push(entry);
      if (log.length > 100) log.shift();
      sessionStorage.setItem('gv_fq_log', JSON.stringify(log));
    } catch (_) {}
  }

  return { evaluate, measureBrightness, measureSharpness, detectBacklight, pickBestFrame, log, CFG };
})();
