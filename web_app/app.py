from flask import Flask, request, jsonify
from flask_cors import CORS
import sqlite3

app = Flask(__name__)
CORS(app)

# ---------------- DATABASE SETUP ----------------
def init_db():
    conn = sqlite3.connect("users.db")
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        email TEXT UNIQUE,
        password TEXT,
        role TEXT,
        id_number TEXT
    )
    """)

    conn.commit()
    conn.close()

init_db()

# ---------------- HOME ----------------
@app.route("/")
def home():
    return "Server running 🚀"

# ---------------- SIGNUP ----------------
@app.route("/signup", methods=["POST"])
def signup():
    data = request.get_json()

    name = data.get("name")
    email = data.get("email")
    password = data.get("password")
    role = data.get("role")
    id_number = data.get("id_number")

    conn = sqlite3.connect("users.db")
    cursor = conn.cursor()

    try:
        cursor.execute("""
        INSERT INTO users (name, email, password, role, id_number)
        VALUES (?, ?, ?, ?, ?)
        """, (name, email, password, role, id_number))

        conn.commit()
    except:
        return jsonify({"success": False, "message": "User already exists ❌"})

    conn.close()

    return jsonify({"success": True, "message": "Signup successful 🎉"})

# ---------------- LOGIN ----------------
@app.route("/login", methods=["POST"])
def login():
    data = request.get_json()

    email = data.get("email")
    password = data.get("password")

    conn = sqlite3.connect("users.db")
    cursor = conn.cursor()

    cursor.execute("""
    SELECT name, email, role, id_number FROM users
    WHERE email=? AND password=?
    """, (email, password))

    user = cursor.fetchone()
    conn.close()

    if user:
        return jsonify({
            "success": True,
            "name": user[0],
            "email": user[1],
            "role": user[2],
            "id": user[3]
        })
    else:
        return jsonify({"success": False})

# ---------------- RUN ----------------
if __name__ == "__main__":
    app.run(debug=True, port=5001)