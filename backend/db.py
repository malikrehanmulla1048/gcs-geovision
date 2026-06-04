"""
GeoVision — SQLite Database Layer
Handles: users (bcrypt passwords), face embeddings, entry logs, threats, visitors, geofencing
"""

import sqlite3
import bcrypt
import json
import os
from datetime import datetime, timedelta
from pathlib import Path

DB_PATH = Path(__file__).parent / "geovision.db"


def get_conn():
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db():
    with get_conn() as conn:
        conn.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            email       TEXT PRIMARY KEY,
            password_hash TEXT NOT NULL,
            role        TEXT NOT NULL DEFAULT 'student',
            name        TEXT NOT NULL,
            student_id  TEXT,
            phone       TEXT,
            dept        TEXT,
            year        TEXT,
            face_enrolled INTEGER DEFAULT 0,
            is_geofenced  INTEGER DEFAULT 0,
            geofence_zone TEXT,
            is_blacklisted INTEGER DEFAULT 0,
            threat_level   TEXT DEFAULT 'none',
            joined_at   TEXT,
            pfp_base64  TEXT
        );

        CREATE TABLE IF NOT EXISTS face_embeddings (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_email  TEXT NOT NULL,
            embedding   TEXT NOT NULL,
            enrolled_at TEXT NOT NULL,
            FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS entry_logs (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_email  TEXT,
            user_name   TEXT,
            user_id     TEXT,
            dept        TEXT,
            gate        TEXT NOT NULL,
            type        TEXT NOT NULL,
            confidence  REAL,
            timestamp   TEXT NOT NULL,
            on_campus   INTEGER DEFAULT 1,
            snapshot_path TEXT
        );

        CREATE TABLE IF NOT EXISTS threats (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            threat_type TEXT NOT NULL,
            user_email  TEXT,
            user_name   TEXT,
            gate        TEXT NOT NULL,
            confidence  REAL,
            snapshot_path TEXT,
            status      TEXT DEFAULT 'active',
            detected_at TEXT NOT NULL,
            resolved_at TEXT
        );

        CREATE TABLE IF NOT EXISTS visitors (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT NOT NULL,
            phone       TEXT,
            purpose     TEXT,
            host        TEXT,
            dept        TEXT,
            id_number   TEXT,
            gate        TEXT,
            status      TEXT DEFAULT 'On Campus',
            checkin_at  TEXT,
            checkout_at TEXT
        );

        CREATE TABLE IF NOT EXISTS cameras (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT NOT NULL,
            source      TEXT NOT NULL,
            is_active   INTEGER DEFAULT 1,
            added_at    TEXT NOT NULL
        );
        """)

        # Seed admin user if not exists
        admin = conn.execute("SELECT email FROM users WHERE email = ?", ("admin@reva.edu.in",)).fetchone()
        if not admin:
            pw_hash = bcrypt.hashpw(b"Admin@GeoVision2025", bcrypt.gensalt()).decode()
            conn.execute("""
                INSERT INTO users (email, password_hash, role, name, face_enrolled, joined_at)
                VALUES (?, ?, 'admin', 'GeoVision Admin', 1, ?)
            """, ("admin@reva.edu.in", pw_hash, datetime.utcnow().isoformat()))

        # Seed default webcam camera if none exist
        cams = conn.execute("SELECT COUNT(*) as c FROM cameras").fetchone()
        if cams["c"] == 0:
            conn.execute("""
                INSERT INTO cameras (name, source, is_active, added_at)
                VALUES ('Main Gate — CAM-01', '0', 1, ?)
            """, (datetime.utcnow().isoformat(),))

        conn.commit()


# ── USERS ──────────────────────────────────────────────────────────────

def create_user(email: str, password: str, name: str, student_id: str,
                phone: str = None, dept: str = None, year: str = None) -> dict:
    pw_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    with get_conn() as conn:
        try:
            conn.execute("""
                INSERT INTO users (email, password_hash, role, name, student_id, phone, dept, year, joined_at)
                VALUES (?, ?, 'student', ?, ?, ?, ?, ?, ?)
            """, (email, pw_hash, name, student_id, phone, dept, year, datetime.utcnow().isoformat()))
            conn.commit()
            return {"ok": True}
        except sqlite3.IntegrityError:
            return {"ok": False, "error": "Email already registered."}


def authenticate(email: str, password: str) -> dict:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
        if not row:
            return {"ok": False, "error": "No account found with this email."}
        if not bcrypt.checkpw(password.encode(), row["password_hash"].encode()):
            return {"ok": False, "error": "Incorrect password."}
        return {"ok": True, "user": dict(row)}


def get_user(email: str) -> dict | None:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
        return dict(row) if row else None


def get_all_users() -> list:
    with get_conn() as conn:
        rows = conn.execute("SELECT * FROM users WHERE role != 'admin'").fetchall()
        return [dict(r) for r in rows]


def update_user_face_enrolled(email: str, enrolled: bool):
    with get_conn() as conn:
        conn.execute("UPDATE users SET face_enrolled = ? WHERE email = ?", (1 if enrolled else 0, email))
        conn.commit()


def update_user_profile(email: str, name: str, phone: str, dept: str, year: str):
    with get_conn() as conn:
        conn.execute("""
            UPDATE users SET name=?, phone=?, dept=?, year=? WHERE email=?
        """, (name, phone, dept, year, email))
        conn.commit()


def set_blacklisted(email: str, blacklisted: bool):
    with get_conn() as conn:
        conn.execute("UPDATE users SET is_blacklisted = ? WHERE email = ?",
                     (1 if blacklisted else 0, email))
        conn.commit()


def set_geofenced(email: str, geofenced: bool, zone: str = None):
    with get_conn() as conn:
        conn.execute("UPDATE users SET is_geofenced = ?, geofence_zone = ? WHERE email = ?",
                     (1 if geofenced else 0, zone, email))
        conn.commit()


def get_enrolled_users_with_embeddings() -> list:
    """Returns list of {email, name, is_geofenced, is_blacklisted, embeddings:[...]}"""
    with get_conn() as conn:
        users = conn.execute("SELECT * FROM users WHERE face_enrolled = 1").fetchall()
        result = []
        for u in users:
            embs = conn.execute(
                "SELECT embedding FROM face_embeddings WHERE user_email = ?", (u["email"],)
            ).fetchall()
            embeddings = [json.loads(e["embedding"]) for e in embs]
            if embeddings:
                result.append({
                    **dict(u),
                    "embeddings": embeddings,
                })
        return result


# ── FACE EMBEDDINGS ───────────────────────────────────────────────────

def save_face_embedding(user_email: str, embedding: list):
    with get_conn() as conn:
        # Remove old embeddings first
        conn.execute("DELETE FROM face_embeddings WHERE user_email = ?", (user_email,))
        conn.execute("""
            INSERT INTO face_embeddings (user_email, embedding, enrolled_at)
            VALUES (?, ?, ?)
        """, (user_email, json.dumps(embedding), datetime.utcnow().isoformat()))
        conn.execute("UPDATE users SET face_enrolled = 1 WHERE email = ?", (user_email,))
        conn.commit()


# ── ENTRY LOGS ────────────────────────────────────────────────────────

def add_entry_log(user_email: str, user_name: str, user_id: str, dept: str,
                  gate: str, log_type: str, confidence: float, snapshot_path: str = None):
    with get_conn() as conn:
        conn.execute("""
            INSERT INTO entry_logs (user_email, user_name, user_id, dept, gate, type, confidence, timestamp, snapshot_path)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (user_email, user_name, user_id, dept, gate, log_type, confidence,
              datetime.utcnow().isoformat(), snapshot_path))
        # Update on_campus flag
        if log_type == "entry":
            conn.execute("UPDATE entry_logs SET on_campus = 0 WHERE user_email = ? AND type = 'exit' AND on_campus = 1",
                         (user_email,))
        elif log_type == "exit":
            conn.execute("UPDATE entry_logs SET on_campus = 0 WHERE user_email = ? AND type = 'entry' AND on_campus = 1",
                         (user_email,))
        conn.commit()


def get_entry_logs(limit: int = 100, offset: int = 0,
                   type_filter: str = None, gate_filter: str = None,
                   search: str = None) -> list:
    with get_conn() as conn:
        q = "SELECT * FROM entry_logs WHERE 1=1"
        params = []
        if type_filter and type_filter != "all":
            q += " AND type = ?"; params.append(type_filter)
        if gate_filter and gate_filter != "all":
            q += " AND gate = ?"; params.append(gate_filter)
        if search:
            q += " AND (user_name LIKE ? OR user_id LIKE ?)"; params += [f"%{search}%", f"%{search}%"]
        q += " ORDER BY timestamp DESC LIMIT ? OFFSET ?"
        params += [limit, offset]
        rows = conn.execute(q, params).fetchall()
        return [dict(r) for r in rows]


def get_entry_logs_for_user(user_email: str) -> list:
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT * FROM entry_logs WHERE user_email = ? ORDER BY timestamp DESC LIMIT 50",
            (user_email,)
        ).fetchall()
        return [dict(r) for r in rows]


def get_on_campus_users() -> list:
    """Users with an entry log today that have no matching exit."""
    today = datetime.utcnow().date().isoformat()
    with get_conn() as conn:
        rows = conn.execute("""
            SELECT DISTINCT user_email, user_name, user_id, dept, gate, MAX(timestamp) as last_entry
            FROM entry_logs
            WHERE type = 'entry' AND date(timestamp) = ? AND user_email IS NOT NULL
              AND user_email NOT IN (
                  SELECT user_email FROM entry_logs
                  WHERE type = 'exit' AND date(timestamp) = ?
              )
            GROUP BY user_email
            ORDER BY last_entry DESC
        """, (today, today)).fetchall()
        return [dict(r) for r in rows]


def get_stats_today() -> dict:
    today = datetime.utcnow().date().isoformat()
    with get_conn() as conn:
        entries  = conn.execute("SELECT COUNT(*) as c FROM entry_logs WHERE type='entry'  AND date(timestamp)=?", (today,)).fetchone()["c"]
        exits    = conn.execute("SELECT COUNT(*) as c FROM entry_logs WHERE type='exit'   AND date(timestamp)=?", (today,)).fetchone()["c"]
        denied   = conn.execute("SELECT COUNT(*) as c FROM entry_logs WHERE type='denied' AND date(timestamp)=?", (today,)).fetchone()["c"]
        threats  = conn.execute("SELECT COUNT(*) as c FROM threats WHERE status='active'").fetchone()["c"]
        profiles = conn.execute("SELECT COUNT(*) as c FROM users").fetchone()["c"]
        on_camp  = len(get_on_campus_users())
        avg_conf_row = conn.execute(
            "SELECT AVG(confidence) as a FROM entry_logs WHERE date(timestamp)=? AND confidence IS NOT NULL", (today,)
        ).fetchone()
        avg_conf = round(avg_conf_row["a"] or 0, 1)
        return {
            "entries_today": entries,
            "exits_today": exits,
            "denied_today": denied,
            "active_threats": threats,
            "registered_profiles": profiles,
            "on_campus_count": on_camp,
            "avg_confidence": avg_conf,
        }


# ── THREATS ───────────────────────────────────────────────────────────

def add_threat(threat_type: str, gate: str, user_email: str = None, user_name: str = None,
               confidence: float = None, snapshot_path: str = None):
    with get_conn() as conn:
        conn.execute("""
            INSERT INTO threats (threat_type, user_email, user_name, gate, confidence, snapshot_path, detected_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (threat_type, user_email, user_name, gate, confidence, snapshot_path,
              datetime.utcnow().isoformat()))
        conn.commit()


def get_threats(status: str = None) -> list:
    with get_conn() as conn:
        q = "SELECT * FROM threats WHERE 1=1"
        params = []
        if status:
            q += " AND status = ?"; params.append(status)
        q += " ORDER BY detected_at DESC LIMIT 100"
        rows = conn.execute(q, params).fetchall()
        return [dict(r) for r in rows]


def resolve_threat(threat_id: int):
    with get_conn() as conn:
        conn.execute("UPDATE threats SET status='resolved', resolved_at=? WHERE id=?",
                     (datetime.utcnow().isoformat(), threat_id))
        conn.commit()


# ── CAMERAS ───────────────────────────────────────────────────────────

def get_cameras() -> list:
    with get_conn() as conn:
        rows = conn.execute("SELECT * FROM cameras ORDER BY id").fetchall()
        return [dict(r) for r in rows]


def add_camera(name: str, source: str) -> int:
    with get_conn() as conn:
        cur = conn.execute("""
            INSERT INTO cameras (name, source, is_active, added_at) VALUES (?, ?, 1, ?)
        """, (name, source, datetime.utcnow().isoformat()))
        conn.commit()
        return cur.lastrowid


def delete_camera(camera_id: int):
    with get_conn() as conn:
        conn.execute("DELETE FROM cameras WHERE id = ?", (camera_id,))
        conn.commit()


# ── VISITORS ──────────────────────────────────────────────────────────

def get_visitors() -> list:
    with get_conn() as conn:
        rows = conn.execute("SELECT * FROM visitors ORDER BY id DESC").fetchall()
        return [dict(r) for r in rows]


def add_visitor(name: str, phone: str, purpose: str, host: str, dept: str,
                id_number: str, gate: str) -> int:
    with get_conn() as conn:
        cur = conn.execute("""
            INSERT INTO visitors (name, phone, purpose, host, dept, id_number, gate, status, checkin_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'On Campus', ?)
        """, (name, phone, purpose, host, dept, id_number, gate, datetime.utcnow().isoformat()))
        conn.commit()
        return cur.lastrowid


def checkout_visitor(visitor_id: int):
    with get_conn() as conn:
        conn.execute("UPDATE visitors SET status='Exited', checkout_at=? WHERE id=?",
                     (datetime.utcnow().isoformat(), visitor_id))
        conn.commit()


# ── SCREENSHOT CLEANUP ────────────────────────────────────────────────

def delete_old_screenshots():
    """Delete threat screenshots older than 15 days."""
    cutoff = datetime.utcnow() - timedelta(days=15)
    with get_conn() as conn:
        old = conn.execute(
            "SELECT snapshot_path FROM threats WHERE detected_at < ? AND snapshot_path IS NOT NULL",
            (cutoff.isoformat(),)
        ).fetchall()
        for row in old:
            path = row["snapshot_path"]
            if path and os.path.exists(path):
                os.remove(path)
        conn.execute("UPDATE threats SET snapshot_path=NULL WHERE detected_at < ?", (cutoff.isoformat(),))
        conn.commit()
