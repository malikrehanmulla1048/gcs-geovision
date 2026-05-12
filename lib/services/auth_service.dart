import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'db_service.dart';

/// Mirrors the session / auth logic in api/db.js
class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin    => _currentUser?.isAdmin ?? false;

  final DbService _db = DbService();

  // ── RESTORE SESSION ────────────────────────────────────────────────
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('gv_user_email');
    if (email == null) return;
    final user = await _db.getUser(email);
    if (user != null) {
      _currentUser = user;
      notifyListeners();
    }
  }

  // ── LOGIN ──────────────────────────────────────────────────────────
  Future<({bool ok, String? error})> login(String email, String password) async {
    final result = await _db.authenticate(email, password);
    if (!result.ok) return (ok: false, error: result.error);
    _currentUser = result.user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gv_user_email', email);
    notifyListeners();
    return (ok: true, error: null);
  }

  // ── REGISTER ──────────────────────────────────────────────────────
  Future<({bool ok, String? error})> register({
    required String email, required String password, required String name,
    required String studentId, String? phone, String? dept, String? year,
  }) async {
    final result = await _db.register(
      email: email, password: password, name: name,
      studentId: studentId, phone: phone, dept: dept, year: year,
    );
    if (!result.ok) return (ok: false, error: result.error);
    _currentUser = result.user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gv_user_email', email);
    notifyListeners();
    return (ok: true, error: null);
  }

  // ── LOGOUT ────────────────────────────────────────────────────────
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gv_user_email');
    notifyListeners();
  }

  // ── UPDATE PROFILE ────────────────────────────────────────────────
  Future<void> updateProfile(UserModel updated) async {
    await _db.saveUser(updated);
    _currentUser = updated;
    notifyListeners();
  }
}
