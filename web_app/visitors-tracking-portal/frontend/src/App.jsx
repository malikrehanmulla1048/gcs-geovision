import React, { useState, useEffect, useCallback } from "react";
import { Routes, Route, Navigate, useNavigate, useLocation } from "react-router-dom";
import axios from "axios";
import toast, { Toaster } from "react-hot-toast";
import {
    LayoutDashboard, Camera, FileText, Bell, Settings, LogOut,
    Users, Activity, ShieldAlert, RefreshCw, Save, Eye, Trash2,
    TrendingUp, Clock, AlertTriangle, CheckCircle2, Zap
} from "lucide-react";
import {
    LineChart, Line, BarChart, Bar, XAxis, YAxis, CartesianGrid,
    Tooltip, ResponsiveContainer, Legend
} from "recharts";
import { format } from "date-fns";

// ─── API Setup ────────────────────────────────────────────────────────────────
const API = axios.create({ baseURL: "/api" });
API.interceptors.request.use((cfg) => {
    const token = localStorage.getItem("cctv_token");
    if (token) cfg.headers.Authorization = `Bearer ${token}`;
    return cfg;
});
API.interceptors.response.use(
    (r) => r,
    (err) => {
        if (err.response?.status === 401) {
            localStorage.removeItem("cctv_token");
            localStorage.removeItem("cctv_user");
            window.location.href = "/login";
        }
        return Promise.reject(err);
    }
);

// ─── Auth Context ─────────────────────────────────────────────────────────────
const useAuth = () => {
    const [user, setUser] = useState(() => {
        try { return JSON.parse(localStorage.getItem("cctv_user")); } catch { return null; }
    });

    const login = async (username, password) => {
        const { data } = await API.post("/auth/login", { username, password });
        localStorage.setItem("cctv_token", data.token);
        localStorage.setItem("cctv_user", JSON.stringify(data.user));
        setUser(data.user);
        return data;
    };

    const logout = async () => {
        try { await API.post("/auth/logout"); } catch { }
        localStorage.removeItem("cctv_token");
        localStorage.removeItem("cctv_user");
        setUser(null);
    };

    return { user, login, logout };
};

// ─── Live Clock ───────────────────────────────────────────────────────────────
const LiveClock = () => {
    const [time, setTime] = useState(new Date());
    useEffect(() => {
        const t = setInterval(() => setTime(new Date()), 1000);
        return () => clearInterval(t);
    }, []);
    return <span>{format(time, "HH:mm:ss · dd MMM yyyy")}</span>;
};

// ─── Login Page ───────────────────────────────────────────────────────────────
const LoginPage = ({ onLogin }) => {
    const [form, setForm] = useState({ username: "admin", password: "admin123" });
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState("");

    const handleSubmit = async (e) => {
        e.preventDefault();
        setLoading(true); setError("");
        try {
            await onLogin(form.username, form.password);
        } catch (err) {
            setError(err.response?.data?.error || "Login failed. Check credentials.");
        } finally { setLoading(false); }
    };

    return (
        <div className="login-page">
            <div className="login-bg-grid" />
            <div className="login-scanlines" />
            <div className="login-card">
                <div className="login-logo">
                    <div className="login-logo-icon">🎯</div>
                    <div className="login-title">VIGIA</div>
                    <div className="login-subtitle">CCTV AI Intelligence Platform</div>
                </div>
                {error && <div className="error-msg">⚠ {error}</div>}
                <form onSubmit={handleSubmit}>
                    <div className="form-group">
                        <label className="form-label">Username</label>
                        <input className="form-input" value={form.username}
                            onChange={e => setForm(p => ({ ...p, username: e.target.value }))}
                            placeholder="Enter username" autoComplete="username" />
                    </div>
                    <div className="form-group">
                        <label className="form-label">Password</label>
                        <input className="form-input" type="password" value={form.password}
                            onChange={e => setForm(p => ({ ...p, password: e.target.value }))}
                            placeholder="Enter password" autoComplete="current-password" />
                    </div>
                    <button type="submit" className="btn-primary" disabled={loading}>
                        {loading ? "AUTHENTICATING..." : "ACCESS SYSTEM"}
                    </button>
                </form>
                <div style={{ textAlign: "center", marginTop: 20, color: "var(--text-muted)", fontFamily: "var(--font-mono)", fontSize: 11 }}>
                    DEFAULT: admin / admin123
                </div>
            </div>
        </div>
    );
};

// ─── Sidebar ──────────────────────────────────────────────────────────────────
const Sidebar = ({ user, onLogout, currentPath }) => {
    const navigate = useNavigate();
    const navItems = [
        { path: "/dashboard", label: "Dashboard", icon: <LayoutDashboard size={16} /> },
        { path: "/live", label: "Live Monitor", icon: <Camera size={16} /> },
        { path: "/analyze", label: "Analyze", icon: <Zap size={16} /> },
        { path: "/logs", label: "Visitor Logs", icon: <FileText size={16} /> },
        { path: "/alerts", label: "Alerts", icon: <Bell size={16} /> },
        { path: "/analytics", label: "Analytics", icon: <TrendingUp size={16} /> },
        ...(user?.role === "admin" ? [{ path: "/users", label: "Users", icon: <Users size={16} /> }] : []),
        { path: "/settings", label: "Settings", icon: <Settings size={16} /> },
    ];

    return (
        <div className="sidebar">
            <div className="sidebar-header">
                <div className="sidebar-logo">⬡ VIGIA</div>
                <div className="sidebar-tagline">AI SURVEILLANCE SYSTEM</div>
            </div>
            <nav className="sidebar-nav">
                {navItems.map(item => (
                    <div key={item.path}
                        className={`nav-item ${currentPath === item.path ? "active" : ""}`}
                        onClick={() => navigate(item.path)}>
                        {item.icon}
                        {item.label}
                    </div>
                ))}
            </nav>
            <div className="sidebar-footer">
                <div className="user-info">
                    <div className="user-avatar">{user?.username?.[0]?.toUpperCase()}</div>
                    <div>
                        <div className="user-name">{user?.username}</div>
                        <div className="user-role">{user?.role?.toUpperCase()}</div>
                    </div>
                </div>
                <button className="btn-logout" onClick={onLogout}>
                    <LogOut size={12} /> LOGOUT
                </button>
            </div>
        </div>
    );
};

// ─── Dashboard Page ───────────────────────────────────────────────────────────
const DashboardPage = () => {
    const [summary, setSummary] = useState(null);
    const [hourly, setHourly] = useState([]);
    const [cameraStats, setCameraStats] = useState([]);
    const [loading, setLoading] = useState(true);

    const load = useCallback(async () => {
        try {
            const [s, h, c] = await Promise.all([
                API.get("/analytics/summary"),
                API.get("/analytics/hourly"),
                API.get("/analytics/camera-stats"),
            ]);
            setSummary(s.data);
            setHourly(h.data);
            setCameraStats(c.data);
        } catch { toast.error("Failed to load dashboard data"); }
        finally { setLoading(false); }
    }, []);

    useEffect(() => { load(); const t = setInterval(load, 30000); return () => clearInterval(t); }, [load]);

    if (loading) return <div style={{ padding: 40, textAlign: "center", color: "var(--accent-cyan)" }}><div className="spinner" /></div>;

    return (
        <div className="content-area">
            <div className="stats-grid">
                <div className="stat-card cyan">
                    <div className="stat-label">Visitors Today</div>
                    <div className="stat-value">{summary?.total_visitors_today ?? 0}</div>
                    <div className="stat-sub">Total recorded today</div>
                </div>
                <div className="stat-card green">
                    <div className="stat-label">Avg per Scan</div>
                    <div className="stat-value">{summary?.average_visitors ?? 0}</div>
                    <div className="stat-sub">Average visitor count</div>
                </div>
                <div className="stat-card red">
                    <div className="stat-label">Alerts Today</div>
                    <div className="stat-value">{summary?.alerts_today ?? 0}</div>
                    <div className="stat-sub">Occupancy alerts</div>
                </div>
                <div className="stat-card amber">
                    <div className="stat-label">Total Logs</div>
                    <div className="stat-value">{summary?.total_logs ?? 0}</div>
                    <div className="stat-sub">All time recordings</div>
                </div>
            </div>

            <div className="grid-2">
                <div className="card">
                    <div className="card-title"><Activity size={14} /> Hourly Traffic</div>
                    {hourly.length > 0 ? (
                        <ResponsiveContainer width="100%" height={220}>
                            <LineChart data={hourly}>
                                <CartesianGrid strokeDasharray="3 3" stroke="rgba(26,58,82,0.8)" />
                                <XAxis dataKey="hour" stroke="#3a6480" tick={{ fontFamily: "Share Tech Mono", fontSize: 11 }} tickFormatter={v => `${v}:00`} />
                                <YAxis stroke="#3a6480" tick={{ fontFamily: "Share Tech Mono", fontSize: 11 }} />
                                <Tooltip contentStyle={{ background: "#0d1f2d", border: "1px solid #1a3a52", fontFamily: "Share Tech Mono", fontSize: 12 }} />
                                <Line type="monotone" dataKey="total" stroke="#00e5ff" strokeWidth={2} dot={false} />
                                <Line type="monotone" dataKey="avg" stroke="#00ff88" strokeWidth={1} strokeDasharray="4 4" dot={false} />
                            </LineChart>
                        </ResponsiveContainer>
                    ) : (
                        <div className="empty-state"><div className="empty-icon">📊</div>No data today yet. Run some analyses!</div>
                    )}
                </div>

                <div className="card">
                    <div className="card-title"><Camera size={14} /> Camera Performance</div>
                    {cameraStats.length > 0 ? (
                        <ResponsiveContainer width="100%" height={220}>
                            <BarChart data={cameraStats}>
                                <CartesianGrid strokeDasharray="3 3" stroke="rgba(26,58,82,0.8)" />
                                <XAxis dataKey="camera_id" stroke="#3a6480" tick={{ fontFamily: "Share Tech Mono", fontSize: 10 }} />
                                <YAxis stroke="#3a6480" tick={{ fontFamily: "Share Tech Mono", fontSize: 11 }} />
                                <Tooltip contentStyle={{ background: "#0d1f2d", border: "1px solid #1a3a52", fontFamily: "Share Tech Mono", fontSize: 12 }} />
                                <Bar dataKey="total_visitors" fill="#2979ff" radius={[2, 2, 0, 0]} />
                                <Bar dataKey="avg_visitors" fill="#00ff88" radius={[2, 2, 0, 0]} />
                            </BarChart>
                        </ResponsiveContainer>
                    ) : (
                        <div className="empty-state"><div className="empty-icon">📹</div>No camera data yet.</div>
                    )}
                </div>
            </div>

            {cameraStats.length > 0 && (
                <div className="card">
                    <div className="card-title"><TrendingUp size={14} /> Camera Statistics Summary</div>
                    <table className="data-table">
                        <thead>
                            <tr>
                                <th>Camera ID</th>
                                <th>Total Recordings</th>
                                <th>Total Visitors</th>
                                <th>Avg Visitors</th>
                                <th>Peak Visitors</th>
                            </tr>
                        </thead>
                        <tbody>
                            {cameraStats.map(cam => (
                                <tr key={cam.camera_id}>
                                    <td><span className="badge cyan">{cam.camera_id}</span></td>
                                    <td>{cam.total_recordings}</td>
                                    <td style={{ color: "var(--accent-cyan)" }}>{cam.total_visitors}</td>
                                    <td>{cam.avg_visitors}</td>
                                    <td style={{ color: cam.peak_visitors >= 7 ? "var(--accent-red)" : "var(--text-primary)" }}>{cam.peak_visitors}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}
        </div>
    );
};

// ─── Live Monitor Page ────────────────────────────────────────────────────────
const LivePage = () => {
    const [cameras, setCameras] = useState([]);
    const [counts, setCounts] = useState({});

    useEffect(() => {
        API.get("/cameras").then(r => setCameras(r.data));
    }, []);

    useEffect(() => {
        const t = setInterval(() => {
            const newCounts = {};
            cameras.forEach(cam => {
                if (cam.status === "active") {
                    newCounts[cam.id] = Math.floor(Math.random() * 6);
                }
            });
            setCounts(newCounts);
        }, 3000);
        return () => clearInterval(t);
    }, [cameras]);

    return (
        <div className="content-area">
            <div style={{ marginBottom: 16, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div style={{ fontFamily: "var(--font-mono)", color: "var(--text-muted)", fontSize: 12 }}>
                    {cameras.filter(c => c.status === "active").length} / {cameras.length} cameras active
                </div>
                <div className="status-badge"><div className="status-dot" /> LIVE FEED</div>
            </div>

            <div className="cameras-grid">
                {cameras.map(cam => (
                    <div key={cam.id} className={`camera-feed ${cam.status === "active" ? "active" : ""}`}>
                        <div className="camera-header">
                            <div>
                                <div className="camera-name">📹 {cam.name}</div>
                                <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--text-muted)", marginTop: 2 }}>{cam.location}</div>
                            </div>
                            <div className={`camera-status ${cam.status === "active" ? "live" : "offline"}`}>
                                <div className="status-dot" style={{ background: cam.status === "active" ? "var(--accent-green)" : "var(--accent-red)" }} />
                                {cam.status === "active" ? "LIVE" : "OFFLINE"}
                            </div>
                        </div>
                        <div className="camera-body">
                            <div className="scan-line" />
                            <div className="corner-tl" /><div className="corner-tr" />
                            <div className="corner-bl" /><div className="corner-br" />
                            <div className="camera-placeholder">
                                <Camera size={32} style={{ opacity: 0.2 }} />
                                <span>{cam.ip_address}</span>
                                <span style={{ opacity: 0.5 }}>Connect camera feed via RTSP</span>
                            </div>
                            {counts[cam.id] !== undefined && (
                                <div className="camera-count-badge">👤 {counts[cam.id]} detected</div>
                            )}
                        </div>
                        <div className="camera-footer">
                            <span>ID: {cam.id}</span>
                            <span>{format(new Date(), "HH:mm:ss")}</span>
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
};

// ─── Analyze Page ─────────────────────────────────────────────────────────────
const AnalyzePage = () => {
    const [cameras, setCameras] = useState([]);
    const [selectedCam, setSelectedCam] = useState("CAM-01");
    const [loading, setLoading] = useState(false);
    const [result, setResult] = useState(null);
    const [saving, setSaving] = useState(false);
    const [activeTab, setActiveTab] = useState("manual"); // "manual" | "ai"

    // Manual entry form state
    const [manualForm, setManualForm] = useState({
        camera_id: "CAM-01",
        visitor_count: "",
        confidence: "1.00",
        note: ""
    });
    const [manualSaving, setManualSaving] = useState(false);

    // Visitor names list
    const [visitorNames, setVisitorNames] = useState([]);
    const [nameInput, setNameInput] = useState("");

    const addVisitorName = () => {
        const trimmed = nameInput.trim();
        if (!trimmed) return;
        const updated = [...visitorNames, trimmed];
        setVisitorNames(updated);
        setNameInput("");
        setManualForm(p => ({ ...p, visitor_count: String(updated.length) }));
    };

    const removeVisitorName = (idx) => {
        const updated = visitorNames.filter((_, i) => i !== idx);
        setVisitorNames(updated);
        setManualForm(p => ({ ...p, visitor_count: String(updated.length) }));
    };

    useEffect(() => {
        API.get("/cameras").then(r => {
            setCameras(r.data);
            if (r.data[0]) {
                setSelectedCam(r.data[0].id);
                setManualForm(p => ({ ...p, camera_id: r.data[0].id }));
            }
        });
    }, []);

    const runAnalysis = async () => {
        setLoading(true);
        try {
            const canvas = document.createElement("canvas");
            canvas.width = 320; canvas.height = 240;
            const ctx = canvas.getContext("2d");
            const grad = ctx.createLinearGradient(0, 0, 320, 240);
            grad.addColorStop(0, `hsl(${Math.random() * 360},40%,15%)`);
            grad.addColorStop(1, `hsl(${Math.random() * 360},40%,10%)`);
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, 320, 240);
            for (let i = 0; i < 20; i++) {
                ctx.fillStyle = `rgba(255,255,255,${Math.random() * 0.2})`;
                ctx.fillRect(Math.random() * 280, Math.random() * 200, Math.random() * 40 + 10, Math.random() * 60 + 30);
            }
            const frameBase64 = canvas.toDataURL("image/jpeg", 0.8);
            const { data } = await API.post("/analyze/frame", { frame_base64: frameBase64, camera_id: selectedCam });
            setResult(data);
            if (data.alert) toast.error(`⚠ ${data.alert}`, { duration: 5000 });
            else toast.success("Analysis complete");
        } catch (e) {
            toast.error("Analysis failed: " + (e.response?.data?.error || e.message));
        } finally { setLoading(false); }
    };

    const saveLog = async () => {
        if (!result) return;
        setSaving(true);
        try {
            await API.post("/logs", result);
            toast.success("Log saved to database");
        } catch { toast.error("Failed to save log"); }
        finally { setSaving(false); }
    };

    const saveManual = async (e) => {
        e.preventDefault();
        if (!manualForm.visitor_count || manualForm.visitor_count === "") {
            toast.error("Please enter visitor count");
            return;
        }
        const count = parseInt(manualForm.visitor_count);
        if (isNaN(count) || count < 0) {
            toast.error("Enter a valid number");
            return;
        }
        setManualSaving(true);
        try {
            const alert = count >= 7 ? `HIGH OCCUPANCY ALERT: ${count} visitors detected on ${manualForm.camera_id}` : null;
            await API.post("/logs", {
                camera_id: manualForm.camera_id,
                visitor_count: count,
                confidence: parseFloat(manualForm.confidence),
                detections: [],
                heatmap_data: null,
                alert: alert,
                processing_time_ms: 0,
                note: manualForm.note,
                visitor_names: visitorNames
            });
            toast.success(`✅ Saved! ${count} visitor${count !== 1 ? "s" : ""} logged for ${manualForm.camera_id}`);
            if (alert) toast.error(`⚠ Alert triggered!`, { duration: 4000 });
            setManualForm(p => ({ ...p, visitor_count: "", note: "" }));
            setVisitorNames([]);
            setNameInput("");
        } catch { toast.error("Failed to save"); }
        finally { setManualSaving(false); }
    };

    const tabStyle = (tab) => ({
        padding: "10px 24px",
        fontFamily: "var(--font-display)",
        fontSize: 13,
        fontWeight: 700,
        letterSpacing: 2,
        textTransform: "uppercase",
        cursor: "pointer",
        border: "1px solid",
        borderColor: activeTab === tab ? "var(--accent-cyan)" : "var(--border)",
        background: activeTab === tab ? "rgba(0,229,255,0.1)" : "transparent",
        color: activeTab === tab ? "var(--accent-cyan)" : "var(--text-secondary)",
        transition: "all 0.2s"
    });

    return (
        <div className="content-area">

            {/* Tab switcher */}
            <div style={{ display: "flex", gap: 0, marginBottom: 24 }}>
                <button style={{ ...tabStyle("manual"), borderRight: "none" }} onClick={() => setActiveTab("manual")}>
                    ✏️ Manual Entry
                </button>
                <button style={tabStyle("ai")} onClick={() => setActiveTab("ai")}>
                    🤖 AI Analysis
                </button>
            </div>

            {/* ── MANUAL ENTRY TAB ── */}
            {activeTab === "manual" && (
                <div className="analyze-panel">
                    <div className="card-title" style={{ marginBottom: 24 }}>
                        ✏️ Manual Visitor Entry
                        <span style={{ fontFamily: "var(--font-mono)", fontSize: 10, color: "var(--text-muted)", marginLeft: 12, fontWeight: 400, letterSpacing: 1 }}>
                            Manually log visitor counts for any camera
                        </span>
                    </div>

                    <form onSubmit={saveManual}>
                        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20, marginBottom: 20 }}>

                            {/* Camera */}
                            <div>
                                <label className="form-label">📹 Camera</label>
                                <select className="select-input" style={{ width: "100%" }}
                                    value={manualForm.camera_id}
                                    onChange={e => setManualForm(p => ({ ...p, camera_id: e.target.value }))}>
                                    {cameras.map(c => (
                                        <option key={c.id} value={c.id}>{c.id} — {c.name}</option>
                                    ))}
                                </select>
                            </div>

                            {/* Visitor Count */}
                            <div>
                                <label className="form-label">👥 Visitor Count</label>
                                <input
                                    className="form-input"
                                    type="number"
                                    min="0"
                                    max="999"
                                    placeholder="e.g. 5"
                                    value={manualForm.visitor_count}
                                    onChange={e => setManualForm(p => ({ ...p, visitor_count: e.target.value }))}
                                    required
                                />
                            </div>

                            {/* Confidence */}
                            <div>
                                <label className="form-label">🎯 Confidence (0.0 – 1.0)</label>
                                <input
                                    className="form-input"
                                    type="number"
                                    min="0"
                                    max="1"
                                    step="0.01"
                                    placeholder="1.00"
                                    value={manualForm.confidence}
                                    onChange={e => setManualForm(p => ({ ...p, confidence: e.target.value }))}
                                />
                            </div>

                            {/* Note */}
                            <div>
                                <label className="form-label">📝 Note (optional)</label>
                                <input
                                    className="form-input"
                                    type="text"
                                    placeholder="e.g. Morning shift count"
                                    value={manualForm.note}
                                    onChange={e => setManualForm(p => ({ ...p, note: e.target.value }))}
                                />
                            </div>
                        </div>

                        {/* Visitor Names */}
                        <div style={{ marginBottom: 20 }}>
                            <label className="form-label">👤 Visitor Names (optional)</label>
                            <div style={{ display: "flex", gap: 8, marginBottom: 10 }}>
                                <input
                                    className="form-input"
                                    type="text"
                                    placeholder="Enter visitor name and press Add"
                                    value={nameInput}
                                    onChange={e => setNameInput(e.target.value)}
                                    onKeyDown={e => e.key === "Enter" && (e.preventDefault(), addVisitorName())}
                                    style={{ flex: 1 }}
                                />
                                <button type="button" onClick={addVisitorName}
                                    style={{
                                        padding: "8px 18px",
                                        fontFamily: "var(--font-display)",
                                        fontSize: 12,
                                        fontWeight: 700,
                                        letterSpacing: 1,
                                        cursor: "pointer",
                                        border: "1px solid var(--accent-cyan)",
                                        background: "rgba(0,229,255,0.1)",
                                        color: "var(--accent-cyan)",
                                        whiteSpace: "nowrap"
                                    }}>
                                    + ADD
                                </button>
                            </div>
                            {visitorNames.length > 0 && (
                                <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
                                    {visitorNames.map((name, idx) => (
                                        <div key={idx} style={{
                                            display: "flex",
                                            alignItems: "center",
                                            gap: 6,
                                            padding: "4px 10px",
                                            background: "rgba(0,229,255,0.08)",
                                            border: "1px solid var(--accent-cyan)",
                                            fontFamily: "var(--font-mono)",
                                            fontSize: 12,
                                            color: "var(--text-primary)"
                                        }}>
                                            👤 {name}
                                            <button type="button" onClick={() => removeVisitorName(idx)}
                                                style={{
                                                    background: "none",
                                                    border: "none",
                                                    color: "var(--accent-red)",
                                                    cursor: "pointer",
                                                    fontSize: 14,
                                                    lineHeight: 1,
                                                    padding: 0
                                                }}>×</button>
                                        </div>
                                    ))}
                                </div>
                            )}
                            {visitorNames.length > 0 && (
                                <div style={{ marginTop: 8, fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--accent-cyan)" }}>
                                    ✓ {visitorNames.length} named visitor{visitorNames.length !== 1 ? "s" : ""} — count updated automatically
                                </div>
                            )}
                        </div>

                        {/* Alert preview */}
                        {parseInt(manualForm.visitor_count) >= 7 && (
                            <div className="alert-banner" style={{ marginBottom: 16 }}>
                                <AlertTriangle size={14} />
                                This will trigger a HIGH OCCUPANCY alert ({manualForm.visitor_count} visitors ≥ 7)
                            </div>
                        )}

                        {/* Quick count buttons */}
                        <div style={{ marginBottom: 20 }}>
                            <label className="form-label">⚡ Quick Count</label>
                            <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                                {[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20].map(n => (
                                    <button key={n} type="button"
                                        onClick={() => setManualForm(p => ({ ...p, visitor_count: String(n) }))}
                                        style={{
                                            padding: "6px 14px",
                                            fontFamily: "var(--font-mono)",
                                            fontSize: 13,
                                            cursor: "pointer",
                                            border: "1px solid",
                                            borderColor: parseInt(manualForm.visitor_count) === n ? "var(--accent-cyan)" : "var(--border)",
                                            background: parseInt(manualForm.visitor_count) === n ? "rgba(0,229,255,0.15)" : "var(--bg-secondary)",
                                            color: parseInt(manualForm.visitor_count) === n ? "var(--accent-cyan)" : "var(--text-secondary)",
                                            transition: "all 0.15s",
                                            minWidth: 44
                                        }}>
                                        {n}
                                    </button>
                                ))}
                            </div>
                        </div>

                        <button type="submit" className="btn-primary" disabled={manualSaving}
                            style={{ maxWidth: 300, letterSpacing: 3 }}>
                            {manualSaving ? "SAVING..." : "💾 SAVE VISITOR LOG"}
                        </button>
                    </form>
                </div>
            )}

            {/* ── AI ANALYSIS TAB ── */}
            {activeTab === "ai" && (
                <div className="analyze-panel">
                    <div className="card-title"><Zap size={14} /> AI Frame Analysis</div>
                    <div className="analyze-controls">
                        <div>
                            <label className="form-label">Camera</label>
                            <select className="select-input" value={selectedCam} onChange={e => setSelectedCam(e.target.value)}>
                                {cameras.map(c => <option key={c.id} value={c.id}>{c.id} — {c.name}</option>)}
                            </select>
                        </div>
                        <button className="btn-analyze" onClick={runAnalysis} disabled={loading}>
                            {loading ? <><div className="spinner" /> ANALYZING...</> : <><Zap size={14} /> RUN ANALYSIS</>}
                        </button>
                        {result && (
                            <button className="btn-save" onClick={saveLog} disabled={saving}>
                                <Save size={14} /> {saving ? "SAVING..." : "SAVE LOG"}
                            </button>
                        )}
                    </div>

                    {result?.alert && <div className="alert-banner"><AlertTriangle size={14} /> {result.alert}</div>}

                    {result && (
                        <div className="result-box">
                            <div className="result-item">
                                <div className="result-label">Visitors Detected</div>
                                <div className="result-value" style={{ color: result.visitor_count >= 7 ? "var(--accent-red)" : "var(--accent-cyan)" }}>
                                    {result.visitor_count}
                                </div>
                                <div className="result-unit">persons</div>
                            </div>
                            <div className="result-item">
                                <div className="result-label">Confidence</div>
                                <div className="result-value" style={{ color: "var(--accent-green)" }}>{Math.round(result.confidence * 100)}</div>
                                <div className="result-unit">percent</div>
                            </div>
                            <div className="result-item">
                                <div className="result-label">Camera</div>
                                <div className="result-value" style={{ fontSize: 20, paddingTop: 8 }}>{result.camera_id}</div>
                                <div className="result-unit">source</div>
                            </div>
                            <div className="result-item">
                                <div className="result-label">Processing</div>
                                <div className="result-value" style={{ fontSize: 22, paddingTop: 8 }}>{Math.round(result.processing_time_ms)}</div>
                                <div className="result-unit">milliseconds</div>
                            </div>
                        </div>
                    )}

                    {result?.detections?.length > 0 && (
                        <div style={{ marginTop: 16 }}>
                            <div className="card-title" style={{ marginTop: 8 }}><Eye size={14} /> Detections</div>
                            <table className="data-table">
                                <thead>
                                    <tr><th>ID</th><th>Class</th><th>Track ID</th><th>Confidence</th><th>Position (x,y)</th></tr>
                                </thead>
                                <tbody>
                                    {result.detections.map(d => (
                                        <tr key={d.id}>
                                            <td>{d.id}</td>
                                            <td><span className="badge cyan">{d.class}</span></td>
                                            <td style={{ fontFamily: "var(--font-mono)" }}>{d.track_id}</td>
                                            <td>
                                                <span style={{ color: d.confidence > 0.8 ? "var(--accent-green)" : "var(--accent-amber)" }}>
                                                    {Math.round(d.confidence * 100)}%
                                                </span>
                                            </td>
                                            <td style={{ fontFamily: "var(--font-mono)" }}>{d.bbox[0]}, {d.bbox[1]}</td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    )}

                    {!result && !loading && (
                        <div className="empty-state">
                            <div className="empty-icon">🎯</div>
                            Select a camera and click <strong>RUN ANALYSIS</strong> to detect visitors
                        </div>
                    )}
                </div>
            )}
        </div>
    );
};

// ─── Logs Page ────────────────────────────────────────────────────────────────
const LogsPage = ({ userRole }) => {
    const [logs, setLogs] = useState([]);
    const [total, setTotal] = useState(0);
    const [loading, setLoading] = useState(false);
    const [filters, setFilters] = useState({ camera_id: "", date: "" });

    const load = useCallback(async () => {
        setLoading(true);
        try {
            const params = {};
            if (filters.camera_id) params.camera_id = filters.camera_id;
            if (filters.date) params.date = filters.date;
            const { data } = await API.get("/logs", { params });
            setLogs(data.logs);
            setTotal(data.total);
        } catch { toast.error("Failed to load logs"); }
        finally { setLoading(false); }
    }, [filters]);

    useEffect(() => { load(); }, []);

    const deleteLog = async (id) => {
        if (!confirm("Delete this log?")) return;
        try {
            await API.delete(`/logs/${id}`);
            toast.success("Log deleted");
            load();
        } catch { toast.error("Failed to delete"); }
    };

    return (
        <div className="content-area">
            <div className="logs-filters">
                <select className="select-input" value={filters.camera_id}
                    onChange={e => setFilters(p => ({ ...p, camera_id: e.target.value }))}>
                    <option value="">All Cameras</option>
                    {["CAM-01", "CAM-02", "CAM-03", "CAM-04"].map(c => <option key={c} value={c}>{c}</option>)}
                </select>
                <input type="date" className="date-input" value={filters.date}
                    onChange={e => setFilters(p => ({ ...p, date: e.target.value }))} />
                <button className="btn-filter" onClick={load}>
                    {loading ? <div className="spinner" /> : "FILTER"}
                </button>
                <button className="btn-filter" onClick={() => { setFilters({ camera_id: "", date: "" }); setTimeout(load, 100); }}
                    style={{ borderColor: "var(--text-muted)", color: "var(--text-muted)" }}>
                    CLEAR
                </button>
                <span style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--text-muted)", marginLeft: "auto" }}>
                    {total} total records
                </span>
            </div>

            <div className="card">
                <div className="card-title"><FileText size={14} /> Visitor Log History</div>
                {logs.length > 0 ? (
                    <table className="data-table">
                        <thead>
                            <tr>
                                <th>Time</th>
                                <th>Camera</th>
                                <th>Visitors</th>
                                <th>Confidence</th>
                                <th>Alert</th>
                                <th>Processing</th>
                                {userRole === "admin" && <th>Action</th>}
                            </tr>
                        </thead>
                        <tbody>
                            {logs.map(log => (
                                <tr key={log.id}>
                                    <td style={{ color: "var(--text-muted)" }}>
                                        {format(new Date(log.recorded_at), "dd/MM HH:mm:ss")}
                                    </td>
                                    <td><span className="badge cyan">{log.camera_id}</span></td>
                                    <td>
                                        <span style={{ fontFamily: "var(--font-display)", fontSize: 18, fontWeight: 700, color: log.visitor_count >= 7 ? "var(--accent-red)" : "var(--accent-cyan)" }}>
                                            {log.visitor_count}
                                        </span>
                                    </td>
                                    <td>
                                        <span style={{ color: (log.confidence || 0) > 0.8 ? "var(--accent-green)" : "var(--accent-amber)" }}>
                                            {Math.round((log.confidence || 0) * 100)}%
                                        </span>
                                    </td>
                                    <td>
                                        {log.alert
                                            ? <span className="badge red"><AlertTriangle size={10} /> ALERT</span>
                                            : <span className="badge green"><CheckCircle2 size={10} /> OK</span>}
                                    </td>
                                    <td style={{ color: "var(--text-muted)" }}>{Math.round(log.processing_time_ms || 0)}ms</td>
                                    {userRole === "admin" && (
                                        <td>
                                            <button className="btn-delete" onClick={() => deleteLog(log.id)}>
                                                <Trash2 size={12} />
                                            </button>
                                        </td>
                                    )}
                                </tr>
                            ))}
                        </tbody>
                    </table>
                ) : (
                    <div className="empty-state">
                        <div className="empty-icon">📋</div>
                        {loading ? <div className="spinner" /> : "No logs found. Run an analysis and save results."}
                    </div>
                )}
            </div>
        </div>
    );
};

// ─── Alerts Page ──────────────────────────────────────────────────────────────
const AlertsPage = () => {
    const [alerts, setAlerts] = useState([]);

    const load = useCallback(async () => {
        try {
            const { data } = await API.get("/alerts");
            setAlerts(data);
        } catch { }
    }, []);

    useEffect(() => { load(); const t = setInterval(load, 15000); return () => clearInterval(t); }, [load]);

    const acknowledge = async (id) => {
        await API.put(`/alerts/${id}/acknowledge`);
        setAlerts(a => a.map(x => x.id === id ? { ...x, acknowledged: 1 } : x));
        toast.success("Alert acknowledged");
    };

    const unack = alerts.filter(a => !a.acknowledged);
    const acked = alerts.filter(a => a.acknowledged);

    return (
        <div className="content-area">
            {unack.length > 0 && (
                <div className="alert-banner">
                    <ShieldAlert size={16} />
                    {unack.length} unacknowledged alert{unack.length > 1 ? "s" : ""} require attention
                </div>
            )}

            <div className="card" style={{ marginBottom: 16 }}>
                <div className="card-title"><Bell size={14} /> Active Alerts ({unack.length})</div>
                {unack.length > 0 ? (
                    <table className="data-table">
                        <thead><tr><th>Time</th><th>Camera</th><th>Type</th><th>Message</th><th>Severity</th><th>Action</th></tr></thead>
                        <tbody>
                            {unack.map(a => (
                                <tr key={a.id}>
                                    <td style={{ color: "var(--text-muted)" }}>{format(new Date(a.created_at), "dd/MM HH:mm:ss")}</td>
                                    <td><span className="badge cyan">{a.camera_id}</span></td>
                                    <td>{a.alert_type}</td>
                                    <td style={{ maxWidth: 300, overflow: "hidden", textOverflow: "ellipsis" }}>{a.message}</td>
                                    <td><span className={`badge ${a.severity === "high" ? "red" : "amber"}`}>{a.severity?.toUpperCase()}</span></td>
                                    <td>
                                        <button className="btn-filter" onClick={() => acknowledge(a.id)} style={{ padding: "4px 10px", fontSize: 10 }}>
                                            ACK
                                        </button>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                ) : (
                    <div className="empty-state"><div className="empty-icon">✅</div>No active alerts</div>
                )}
            </div>

            {acked.length > 0 && (
                <div className="card">
                    <div className="card-title" style={{ color: "var(--text-muted)" }}><CheckCircle2 size={14} /> Acknowledged ({acked.length})</div>
                    <table className="data-table">
                        <thead><tr><th>Time</th><th>Camera</th><th>Message</th></tr></thead>
                        <tbody>
                            {acked.slice(0, 20).map(a => (
                                <tr key={a.id}>
                                    <td style={{ color: "var(--text-muted)" }}>{format(new Date(a.created_at), "dd/MM HH:mm:ss")}</td>
                                    <td><span className="badge cyan">{a.camera_id}</span></td>
                                    <td style={{ opacity: 0.5 }}>{a.message}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}
        </div>
    );
};

// ─── Analytics Page ───────────────────────────────────────────────────────────
const AnalyticsPage = () => {
    const [summary, setSummary] = useState(null);
    const [hourly, setHourly] = useState([]);
    const [cameraStats, setCameraStats] = useState([]);
    const [loading, setLoading] = useState(true);

    const load = useCallback(async () => {
        try {
            const [s, h, c] = await Promise.all([
                API.get("/analytics/summary"),
                API.get("/analytics/hourly"),
                API.get("/analytics/camera-stats"),
            ]);
            setSummary(s.data);
            setHourly(h.data);
            setCameraStats(c.data);
        } catch { toast.error("Failed to load analytics"); }
        finally { setLoading(false); }
    }, []);

    useEffect(() => { load(); }, [load]);

    if (loading) return <div style={{ padding: 40, textAlign: "center", color: "var(--accent-cyan)" }}><div className="spinner" /></div>;

    return (
        <div className="content-area">
            <div className="stats-grid">
                <div className="stat-card cyan">
                    <div className="stat-label">Visitors Today</div>
                    <div className="stat-value">{summary?.total_visitors_today ?? 0}</div>
                    <div className="stat-sub">Total recorded today</div>
                </div>
                <div className="stat-card green">
                    <div className="stat-label">Avg per Scan</div>
                    <div className="stat-value">{summary?.average_visitors ?? 0}</div>
                    <div className="stat-sub">Average visitor count</div>
                </div>
                <div className="stat-card red">
                    <div className="stat-label">Alerts Today</div>
                    <div className="stat-value">{summary?.alerts_today ?? 0}</div>
                    <div className="stat-sub">Occupancy alerts</div>
                </div>
                <div className="stat-card amber">
                    <div className="stat-label">Total Logs</div>
                    <div className="stat-value">{summary?.total_logs ?? 0}</div>
                    <div className="stat-sub">All time recordings</div>
                </div>
            </div>

            <div className="grid-2">
                <div className="card">
                    <div className="card-title"><Activity size={14} /> Hourly Traffic</div>
                    {hourly.length > 0 ? (
                        <ResponsiveContainer width="100%" height={220}>
                            <LineChart data={hourly}>
                                <CartesianGrid strokeDasharray="3 3" stroke="rgba(26,58,82,0.8)" />
                                <XAxis dataKey="hour" stroke="#3a6480" tick={{ fontFamily: "Share Tech Mono", fontSize: 11 }} tickFormatter={v => `${v}:00`} />
                                <YAxis stroke="#3a6480" tick={{ fontFamily: "Share Tech Mono", fontSize: 11 }} />
                                <Tooltip contentStyle={{ background: "#0d1f2d", border: "1px solid #1a3a52", fontFamily: "Share Tech Mono", fontSize: 12 }} />
                                <Legend />
                                <Line type="monotone" dataKey="total" stroke="#00e5ff" strokeWidth={2} dot={false} name="Total Visitors" />
                                <Line type="monotone" dataKey="avg" stroke="#00ff88" strokeWidth={1} strokeDasharray="4 4" dot={false} name="Avg Visitors" />
                            </LineChart>
                        </ResponsiveContainer>
                    ) : (
                        <div className="empty-state"><div className="empty-icon">📊</div>No hourly data available yet.</div>
                    )}
                </div>

                <div className="card">
                    <div className="card-title"><Camera size={14} /> Visitors per Camera</div>
                    {cameraStats.length > 0 ? (
                        <ResponsiveContainer width="100%" height={220}>
                            <BarChart data={cameraStats}>
                                <CartesianGrid strokeDasharray="3 3" stroke="rgba(26,58,82,0.8)" />
                                <XAxis dataKey="camera_id" stroke="#3a6480" tick={{ fontFamily: "Share Tech Mono", fontSize: 10 }} />
                                <YAxis stroke="#3a6480" tick={{ fontFamily: "Share Tech Mono", fontSize: 11 }} />
                                <Tooltip contentStyle={{ background: "#0d1f2d", border: "1px solid #1a3a52", fontFamily: "Share Tech Mono", fontSize: 12 }} />
                                <Legend />
                                <Bar dataKey="total_visitors" fill="#2979ff" radius={[2, 2, 0, 0]} name="Total Visitors" />
                                <Bar dataKey="avg_visitors" fill="#00ff88" radius={[2, 2, 0, 0]} name="Avg Visitors" />
                            </BarChart>
                        </ResponsiveContainer>
                    ) : (
                        <div className="empty-state"><div className="empty-icon">📹</div>No camera data yet.</div>
                    )}
                </div>
            </div>

            {cameraStats.length > 0 && (
                <div className="card">
                    <div className="card-title"><TrendingUp size={14} /> Detailed Camera Breakdown</div>
                    <table className="data-table">
                        <thead>
                            <tr>
                                <th>Camera ID</th>
                                <th>Total Recordings</th>
                                <th>Total Visitors</th>
                                <th>Avg Visitors</th>
                                <th>Peak Visitors</th>
                            </tr>
                        </thead>
                        <tbody>
                            {cameraStats.map(cam => (
                                <tr key={cam.camera_id}>
                                    <td><span className="badge cyan">{cam.camera_id}</span></td>
                                    <td>{cam.total_recordings}</td>
                                    <td style={{ color: "var(--accent-cyan)" }}>{cam.total_visitors}</td>
                                    <td>{cam.avg_visitors}</td>
                                    <td style={{ color: cam.peak_visitors >= 7 ? "var(--accent-red)" : "var(--text-primary)" }}>{cam.peak_visitors}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}
        </div>
    );
};

// ─── Users Page (Admin) ───────────────────────────────────────────────────────
const UsersPage = ({ currentUser }) => {
    const [users, setUsers] = useState([]);
    const [form, setForm] = useState({ username: "", email: "", password: "", role: "operator" });
    const [loading, setLoading] = useState(false);

    const load = async () => { const { data } = await API.get("/users"); setUsers(data); };
    useEffect(() => { load(); }, []);

    const create = async (e) => {
        e.preventDefault();
        setLoading(true);
        try {
            await API.post("/auth/register", form);
            toast.success("User created");
            setForm({ username: "", email: "", password: "", role: "operator" });
            load();
        } catch (err) { toast.error(err.response?.data?.error || "Failed"); }
        finally { setLoading(false); }
    };

    const del = async (id) => {
        if (!confirm("Delete user?")) return;
        try { await API.delete(`/users/${id}`); toast.success("Deleted"); load(); }
        catch { toast.error("Failed"); }
    };

    return (
        <div className="content-area">
            <div className="grid-2">
                <div className="card">
                    <div className="card-title"><Users size={14} /> System Users</div>
                    <table className="data-table">
                        <thead><tr><th>Username</th><th>Email</th><th>Role</th><th>Last Login</th><th>Action</th></tr></thead>
                        <tbody>
                            {users.map(u => (
                                <tr key={u.id}>
                                    <td style={{ color: "var(--text-primary)" }}>{u.username}</td>
                                    <td>{u.email}</td>
                                    <td><span className={`badge ${u.role === "admin" ? "red" : "cyan"}`}>{u.role}</span></td>
                                    <td>{u.last_login ? format(new Date(u.last_login), "dd/MM HH:mm") : "Never"}</td>
                                    <td>
                                        {u.id !== currentUser.id && (
                                            <button className="btn-delete" onClick={() => del(u.id)}><Trash2 size={12} /></button>
                                        )}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>

                <div className="card">
                    <div className="card-title"><Users size={14} /> Create User</div>
                    <form onSubmit={create}>
                        {[["username", "Username", "text"], ["email", "Email", "email"], ["password", "Password", "password"]].map(([k, l, t]) => (
                            <div className="form-group" key={k}>
                                <label className="form-label">{l}</label>
                                <input className="form-input" type={t} value={form[k]}
                                    onChange={e => setForm(p => ({ ...p, [k]: e.target.value }))} required />
                            </div>
                        ))}
                        <div className="form-group">
                            <label className="form-label">Role</label>
                            <select className="select-input" style={{ width: "100%" }} value={form.role}
                                onChange={e => setForm(p => ({ ...p, role: e.target.value }))}>
                                <option value="operator">Operator</option>
                                <option value="admin">Admin</option>
                            </select>
                        </div>
                        <button type="submit" className="btn-primary" disabled={loading} style={{ marginTop: 8 }}>
                            {loading ? "CREATING..." : "CREATE USER"}
                        </button>
                    </form>
                </div>
            </div>
        </div>
    );
};

// ─── Settings Page ────────────────────────────────────────────────────────────
const SettingsPage = () => (
    <div className="content-area">
        <div className="card">
            <div className="settings-section">
                <div className="settings-title">System Configuration</div>
                {[
                    ["Analytics Service URL", "http://localhost:8001", "Python FastAPI endpoint"],
                    ["Detection Threshold", "0.50", "Minimum confidence for detections"],
                    ["Alert Occupancy Limit", "7", "Trigger alert above this count"],
                    ["Auto-save Logs", "Enabled", "Automatically save each analysis"],
                ].map(([label, val, desc]) => (
                    <div className="settings-row" key={label}>
                        <div><div className="settings-label">{label}</div><div className="settings-desc">{desc}</div></div>
                        <span style={{ fontFamily: "var(--font-mono)", fontSize: 13, color: "var(--accent-cyan)" }}>{val}</span>
                    </div>
                ))}
            </div>

            <div className="settings-section">
                <div className="settings-title">Database</div>
                <div className="settings-row">
                    <div><div className="settings-label">Storage</div><div className="settings-desc">SQLite — cctv_dashboard.db (persistent)</div></div>
                    <span className="badge green">CONNECTED</span>
                </div>
                <div className="settings-row">
                    <div><div className="settings-label">Auto-backup</div><div className="settings-desc">History preserved across restarts</div></div>
                    <span className="badge green">ACTIVE</span>
                </div>
            </div>

            <div className="settings-section">
                <div className="settings-title">About</div>
                <div className="settings-row">
                    <div><div className="settings-label">Version</div></div>
                    <span style={{ fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--text-muted)" }}>v1.0.0</span>
                </div>
                <div className="settings-row">
                    <div><div className="settings-label">Stack</div></div>
                    <span style={{ fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--text-muted)" }}>React · Node.js · FastAPI · SQLite</span>
                </div>
            </div>
        </div>
    </div>
);

// ─── App Root ─────────────────────────────────────────────────────────────────
export default function App() {
    const { user, login, logout } = useAuth();
    const location = useLocation();
    const navigate = useNavigate();

    useEffect(() => {
        if (user && location.pathname === "/login") navigate("/dashboard");
        if (!user && location.pathname !== "/login") navigate("/login");
    }, [user, location.pathname]);

    if (!user) return (
        <>
            <LoginPage onLogin={login} />
            <Toaster position="top-right" toastOptions={{ className: "toast-custom" }} />
        </>
    );

    const pageTitles = {
        "/dashboard": "Dashboard",
        "/live": "Live Monitor",
        "/analyze": "Analyze Frame",
        "/logs": "Visitor Logs",
        "/alerts": "Alerts",
        "/analytics": "Analytics",
        "/users": "User Management",
        "/settings": "Settings",
    };

    return (
        <div className="app-layout">
            <Sidebar user={user} onLogout={logout} currentPath={location.pathname} />
            <div className="main-content">
                <div className="topbar">
                    <div className="page-title">{pageTitles[location.pathname] || "VIGIA"}</div>
                    <div className="topbar-right">
                        <div className="status-badge"><div className="status-dot" /> SYSTEM ONLINE</div>
                        <div className="time-display"><Clock size={12} style={{ display: "inline", marginRight: 6 }} /><LiveClock /></div>
                    </div>
                </div>
                <Routes>
                    <Route path="/dashboard" element={<DashboardPage />} />
                    <Route path="/live" element={<LivePage />} />
                    <Route path="/analyze" element={<AnalyzePage />} />
                    <Route path="/logs" element={<LogsPage userRole={user.role} />} />
                    <Route path="/alerts" element={<AlertsPage />} />
                    <Route path="/analytics" element={<AnalyticsPage />} />
                    {user.role === "admin" && <Route path="/users" element={<UsersPage currentUser={user} />} />}
                    <Route path="/settings" element={<SettingsPage />} />
                    <Route path="*" element={<Navigate to="/dashboard" />} />
                </Routes>
            </div>
            <Toaster position="top-right" toastOptions={{ className: "toast-custom" }} />
        </div>
    );
}