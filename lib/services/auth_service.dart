import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend_service.dart';
import 'geofence_service.dart';

/// Mirrors session / auth backed by the Python backend.
/// Passwords are bcrypt-hashed server-side — never sent plaintext after first call.
class AuthService extends ChangeNotifier {
  final BackendService _backend = BackendService();

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? get userData => _userData;

  bool get isLoggedIn    => _userData != null;
  bool get isAdmin       => _userData?['role'] == 'admin';
  bool get isFaceEnrolled => _userData?['face_enrolled'] == true;
  String? get userEmail  => _userData?['email'] as String?;
  String? get userName   => _userData?['name']  as String?;
  String? get token      => _userData != null ? userEmail : null; // session token = email

  BackendService get backend => _backend;

  // ── RESTORE SESSION ───────────────────────────────────────────────

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('gv_session_email');
    if (email == null) return;
    try {
      final user = await _backend.getUser(email);
      if (user != null) {
        _userData = user;
        GeofenceService().startTracking(email);
        notifyListeners();
      }
    } catch (_) {
      // backend not reachable — clear session
      await prefs.remove('gv_session_email');
    }
  }

  // ── LOGIN ─────────────────────────────────────────────────────────

  Future<({bool ok, String? error})> login(String email, String password) async {
    try {
      final result = await _backend.login(email, password);
      if (result['ok'] != true) {
        return (ok: false, error: result['error'] as String? ?? 'Login failed.');
      }
      _userData = result['user'] as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gv_session_email', email);
      GeofenceService().startTracking(email);
      notifyListeners();
      return (ok: true, error: null);
    } catch (e) {
      return (ok: false, error: 'Cannot reach backend. Make sure run_backend.bat is running.');
    }
  }

  // ── REGISTER ──────────────────────────────────────────────────────

  Future<({bool ok, String? error})> register({
    required String email, required String password, required String name,
    required String studentId, String? phone, String? dept, String? year,
  }) async {
    try {
      final result = await _backend.register(
        email: email, password: password, name: name,
        studentId: studentId, phone: phone, dept: dept, year: year,
      );
      if (result['ok'] != true) {
        return (ok: false, error: result['error'] as String? ?? 'Registration failed.');
      }
      // Auto-login after register
      final loginResult = await login(email, password);
      return loginResult;
    } catch (e) {
      return (ok: false, error: 'Cannot reach backend. Make sure run_backend.bat is running.');
    }
  }

  // ── LOGOUT ────────────────────────────────────────────────────────

  Future<void> logout() async {
    _userData = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gv_session_email');
    GeofenceService().stopTracking();
    notifyListeners();
  }

  // ── UPDATE PROFILE ────────────────────────────────────────────────

  Future<void> updateProfile({
    required String name, String? phone, String? dept, String? year,
  }) async {
    final email = userEmail;
    if (email == null) return;
    await _backend.updateProfile(email, name: name, phone: phone, dept: dept, year: year);
    // Refresh local user data
    final user = await _backend.getUser(email);
    if (user != null) {
      _userData = user;
      notifyListeners();
    }
  }

  /// Called after face enrolment completes to refresh the enrolled flag.
  Future<void> refreshUser() async {
    final email = userEmail;
    if (email == null) return;
    final user = await _backend.getUser(email);
    if (user != null) {
      _userData = user;
      notifyListeners();
    }
  }
}
