/**
 * GeoVision — CCTV Threat Evaluation Module
 * js/cctvThreat.js
 *
 * Evaluates InsightFace recognition results for security threats.
 * Handles: unknown face, multi-person, loitering, repeated failures,
 * spoof attempts, restricted zone, suspicious presence.
 * Includes confidence scoring, severity mapping, and cooldown throttling.
 */
const CCTVThreat = (() => {

  // ── CONFIG ───────────────────────────────────────────────────────────────
  const CFG = {
    UNKNOWN_CONF_THRESHOLD:   45,    // % similarity; below → unknown
    LOITER_UNKNOWN_MS:     20_000,   // 20 s for unknown person
    LOITER_KNOWN_MS:       60_000,   // 60 s for known person (unusual lingering)
    FAIL_MEDIUM:               3,    // consecutive fails → medium
    FAIL_HIGH:                 5,    // → high
    FAIL_CRITICAL:             8,    // → critical / spoof
    MULTI_PERSON_EXPECTED:     1,    // expected persons per frame
    COOLDOWN: {                      // ms per severity
      low: 20_000, medium: 10_000, high: 5_000, critical: 0
    },
    MAX_ALERTS: 200,
  };

  // ── SEVERITY / TYPES ─────────────────────────────────────────────────────
  const SEV   = { LOW:'low', MED:'medium', HIGH:'high', CRIT:'critical' };
  const TTYPE = {
    UNKNOWN:     'Unknown Face',
    MULTI:       'Multi-Person Intrusion',
    LOITER:      'Loitering Detected',
    SPOOF:       'Spoof / Tamper Attempt',
    REPEAT_FAIL: 'Repeated Failed Attempts',
    SUSPICIOUS:  'Suspicious Presence',
    RESTRICTED:  'Restricted Zone Entry',
  };

  // ── STATE ─────────────────────────────────────────────────────────────────
  let _alerts        = [];
  let _presenceMap   = new Map();   // key → { firstSeen, lastSeen }
  let _failedStreak  = 0;
  let _cooldownMap   = new Map();   // type → lastAlertTs
  let _listeners     = [];

  // ── HELPERS ───────────────────────────────────────────────────────────────
  function _throttled(type, severity) {
    const cd  = CFG.COOLDOWN[severity] ?? 10_000;
    const last = _cooldownMap.get(type) || 0;
    return (Date.now() - last) < cd;
  }
  function _arm(type) { _cooldownMap.set(type, Date.now()); }

  function _confToSev(conf) {
    if (conf < 20) return SEV.CRIT;
    if (conf < 35) return SEV.HIGH;
    if (conf < CFG.UNKNOWN_CONF_THRESHOLD) return SEV.MED;
    return SEV.LOW;
  }

  // ── PRESENCE / LOITERING ──────────────────────────────────────────────────
  function _trackPresence(key) {
    const now = Date.now();
    if (!_presenceMap.has(key)) { _presenceMap.set(key, { firstSeen: now, lastSeen: now }); return 0; }
    const p = _presenceMap.get(key);
    p.lastSeen = now;
    return now - p.firstSeen;
  }
  function _clearPresence(key) { _presenceMap.delete(key); }
  function _gcPresence() {
    const cutoff = Date.now() - 120_000;
    for (const [k, v] of _presenceMap) if (v.lastSeen < cutoff) _presenceMap.delete(k);
  }

  // ── CREATE ALERT OBJECT ───────────────────────────────────────────────────
  function _makeAlert(type, severity, confidence, detail, ctx, snapshotUrl = null) {
    return {
      id:         crypto.randomUUID ? crypto.randomUUID() : String(Date.now() + Math.random()),
      type,
      severity,
      confidence: Math.round(confidence),
      detail,
      camera:     ctx.camera || 'Camera 0 — Live',
      zone:       ctx.zone   || 'Campus',
      timestamp:  new Date().toISOString(),
      snapshot:   snapshotUrl,
      acknowledged: false,
    };
  }

  // ── MAIN EVALUATE ─────────────────────────────────────────────────────────
  /**
   * Evaluate a /recognize response for threats.
   * @param {Object} result   - { matched, face_count, confidence, user_id, name, dept }
   * @param {Object} ctx      - { camera, zone, snapshotUrl, restrictedZone }
   * @returns {Array}         - array of alert objects (may be empty)
   */
  function evaluate(result, ctx = {}) {
    _gcPresence();
    const alerts = [];
    const { matched, face_count = 0, confidence = 0, user_id, name } = result;

    if (face_count === 0) {
      _clearPresence('unknown');
      _failedStreak = 0;
      return alerts;
    }

    // A. MULTI-PERSON
    if (face_count > CFG.MULTI_PERSON_EXPECTED) {
      const sev = face_count >= 3 ? SEV.HIGH : SEV.MED;
      if (!_throttled(TTYPE.MULTI, sev)) {
        alerts.push(_makeAlert(TTYPE.MULTI, sev, 70,
          `${face_count} persons in frame (expected ${CFG.MULTI_PERSON_EXPECTED})`, ctx, ctx.snapshotUrl));
        _arm(TTYPE.MULTI);
      }
    }

    // B. UNKNOWN FACE
    if (!matched) {
      _failedStreak++;
      const sev = _confToSev(confidence);
      if (!_throttled(TTYPE.UNKNOWN, sev)) {
        alerts.push(_makeAlert(TTYPE.UNKNOWN, sev, confidence,
          `Unrecognized person (similarity ${confidence.toFixed(1)}%)`, ctx, ctx.snapshotUrl));
        _arm(TTYPE.UNKNOWN);
      }

      // B1. LOITERING — unknown
      const elapsed = _trackPresence('unknown');
      if (elapsed >= CFG.LOITER_UNKNOWN_MS && !_throttled(TTYPE.LOITER, SEV.MED)) {
        const loiterSev = elapsed >= 60_000 ? SEV.HIGH : SEV.MED;
        alerts.push(_makeAlert(TTYPE.LOITER, loiterSev, 75,
          `Unknown person present for ${Math.round(elapsed / 1000)}s`, ctx, ctx.snapshotUrl));
        _arm(TTYPE.LOITER);
      }

      // B2. REPEATED FAILURES / SPOOF
      if (_failedStreak >= CFG.FAIL_CRITICAL && !_throttled(TTYPE.SPOOF, SEV.CRIT)) {
        alerts.push(_makeAlert(TTYPE.SPOOF, SEV.CRIT, 88,
          `${_failedStreak} consecutive failed recognition attempts — possible spoof`, ctx, ctx.snapshotUrl));
        _arm(TTYPE.SPOOF);
      } else if (_failedStreak >= CFG.FAIL_HIGH && !_throttled(TTYPE.REPEAT_FAIL, SEV.HIGH)) {
        alerts.push(_makeAlert(TTYPE.REPEAT_FAIL, SEV.HIGH, 72,
          `${_failedStreak} failed attempts in this session`, ctx, ctx.snapshotUrl));
        _arm(TTYPE.REPEAT_FAIL);
      } else if (_failedStreak >= CFG.FAIL_MEDIUM && !_throttled(TTYPE.REPEAT_FAIL, SEV.MED)) {
        alerts.push(_makeAlert(TTYPE.REPEAT_FAIL, SEV.MED, 58,
          `${_failedStreak} failed recognition attempts`, ctx, ctx.snapshotUrl));
        _arm(TTYPE.REPEAT_FAIL);
      }

    } else {
      // Known person — reset unknown streak
      _failedStreak = 0;
      _clearPresence('unknown');

      // B3. RESTRICTED ZONE
      if (ctx.restrictedZone) {
        const rzKey = `rz_${user_id}`;
        if (!_throttled(TTYPE.RESTRICTED, SEV.HIGH)) {
          alerts.push(_makeAlert(TTYPE.RESTRICTED, SEV.HIGH, 90,
            `${name || user_id} entered restricted zone: ${ctx.zone}`, ctx, ctx.snapshotUrl));
          _arm(TTYPE.RESTRICTED);
        }
      }

      // B4. LOITERING — known
      const elapsed = _trackPresence(user_id || name || 'known');
      if (elapsed >= CFG.LOITER_KNOWN_MS && !_throttled(TTYPE.LOITER, SEV.LOW)) {
        alerts.push(_makeAlert(TTYPE.LOITER, SEV.LOW, 60,
          `${name || 'Known person'} present for ${Math.round(elapsed / 1000)}s`, ctx, ctx.snapshotUrl));
        _arm(TTYPE.LOITER);
      }
    }

    // Store alerts
    for (const a of alerts) _storeAlert(a);
    return alerts;
  }

  // ── ALERT STORE ───────────────────────────────────────────────────────────
  function _storeAlert(alert) {
    _alerts.unshift(alert);
    if (_alerts.length > CFG.MAX_ALERTS) _alerts.pop();
    for (const fn of _listeners) { try { fn(alert); } catch(_) {} }
  }

  function getAlerts(limit = 50)      { return _alerts.slice(0, limit); }
  function acknowledgeAlert(id)        { const a = _alerts.find(x => x.id === id); if (a) a.acknowledged = true; }
  function clearAlerts()               { _alerts = []; }
  function onAlert(fn)                 { _listeners.push(fn); }
  function removeListener(fn)          { _listeners = _listeners.filter(x => x !== fn); }
  function resetFailedStreak()         { _failedStreak = 0; }

  // ── SEVERITY UTILS ────────────────────────────────────────────────────────
  function severityColor(sev) {
    return { low:'#6366f1', medium:'#f59e0b', high:'#dc2626', critical:'#7c3aed' }[sev] || '#888';
  }
  function severityBgClass(sev) {
    return { low:'sev-low', medium:'sev-medium', high:'sev-high', critical:'sev-critical' }[sev] || '';
  }
  function severityIcon(sev) {
    return { low:'🔵', medium:'🟡', high:'🔴', critical:'🚨' }[sev] || '⚠️';
  }

  return {
    evaluate, getAlerts, acknowledgeAlert, clearAlerts,
    onAlert, removeListener, resetFailedStreak,
    severityColor, severityBgClass, severityIcon,
    TTYPE, SEV, CFG,
  };
})();
