import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/entry_log.dart';
import '../models/visitor.dart';

/// Web-compatible data service using SharedPreferences (JSON store).
/// Mirrors api/db.js IndexedDB logic 1:1.
class DbService {
  static final DbService _instance = DbService._internal();
  factory DbService() => _instance;
  DbService._internal();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── HARDCODED SEED USERS (from db.js HARDCODED array) ─────────────────
  static final List<UserModel> _hardcoded = [
    const UserModel(
      email: 'admin@reva.edu.in',
      password: 'Admin',
      role: 'admin',
      name: 'Admin User',
    ),
    UserModel(
      email: 'student@reva.edu.in',
      password: 'Student',
      role: 'student',
      name: 'Demo Student',
      studentId: 'SRN21CV007',
      phone: '+91 98765 43210',
      dept: 'Computer Science',
      year: '3rd Year',
      faceEnrolled: false,
      joinedAt: DateTime.now(),
    ),
  ];

  static const List<Map<String, String>> people = [
    {'name': 'Arjun Kumar',    'id': 'SRN21CS001', 'dept': 'CS',     'role': 'Student', 'initials': 'AK', 'color': '#dc2626,#991b1b'},
    {'name': 'Priya Sharma',   'id': 'SRN21EC045', 'dept': 'EC',     'role': 'Student', 'initials': 'PS', 'color': '#2563eb,#1e3a8a'},
    {'name': 'Rohit Nair',     'id': 'SRN21ME012', 'dept': 'ME',     'role': 'Student', 'initials': 'RN', 'color': '#16a34a,#14532d'},
    {'name': 'Sneha Krishnan', 'id': 'STAF-005',   'dept': 'Admin',  'role': 'Staff',   'initials': 'SK', 'color': '#7c3aed,#4c1d95'},
    {'name': 'Mohammed Tariq', 'id': 'SRN21IT088', 'dept': 'IT',     'role': 'Student', 'initials': 'MT', 'color': '#db2777,#831843'},
    {'name': 'Divya Menon',    'id': 'SRN22CS034', 'dept': 'CS',     'role': 'Student', 'initials': 'DM', 'color': '#0891b2,#164e63'},
    {'name': 'Kiran Reddy',    'id': 'SRN22EE021', 'dept': 'EE',     'role': 'Student', 'initials': 'KR', 'color': '#d97706,#92400e'},
    {'name': 'Ananya Pillai',  'id': 'STAF-009',   'dept': 'Admin',  'role': 'Staff',   'initials': 'AP', 'color': '#dc2626,#7f1d1d'},
    {'name': 'Suresh Babu',    'id': 'SRN21CV007', 'dept': 'CV',     'role': 'Student', 'initials': 'SB', 'color': '#059669,#064e3b'},
    {'name': 'Lavanya Singh',  'id': 'SRN22CS019', 'dept': 'CS',     'role': 'Student', 'initials': 'LS', 'color': '#6366f1,#312e81'},
    {'name': 'Ravi Teja',      'id': 'SRN21EC081', 'dept': 'EC',     'role': 'Student', 'initials': 'RT', 'color': '#ea580c,#7c2d12'},
    {'name': 'Meghna Bose',    'id': 'STAF-012',   'dept': 'Faculty','role': 'Faculty', 'initials': 'MB', 'color': '#0ea5e9,#0c4a6e'},
  ];

  static const List<String> gates = [
    'Main Gate', 'East Entrance', 'Library', 'Admin Block',
    'Sports Complex', 'Lab Block', 'Cafeteria', 'North Gate'
  ];

  // ── SEED ──────────────────────────────────────────────────────────────
  Future<void> seedDefaults() async {
    final p = await prefs;
    final seeded = p.getBool('gv_seeded') ?? false;
    if (seeded) return;

    // Seed users
    final userList = _hardcoded.map((u) => jsonEncode(u.toMap())).toList();
    await p.setStringList('gv_users', userList);

    // Seed entry logs
    final rng = Random();
    final types = ['entry', 'exit', 'entry', 'entry', 'exit'];
    final now = DateTime.now();
    final logs = <String>[];
    for (int i = 0; i < 20; i++) {
      final person = people[i % people.length];
      logs.add(jsonEncode(EntryLog(
        id: i + 1,
        userId: person['id']!,
        name: person['name']!,
        gate: gates[i % gates.length],
        type: types[i % types.length],
        timestamp: now.subtract(Duration(minutes: i * 10)),
        confidence: 85 + rng.nextDouble() * 14,
        dept: person['dept'],
        initials: person['initials'],
        color: person['color'],
      ).toMap()));
    }
    await p.setStringList('gv_entry_logs', logs);

    // Seed visitors
    const seeds = [
      {'name': 'Ramesh Kumar',  'phone': '+91 98001 11111', 'purpose': 'Meeting Faculty', 'host': 'Dr. Ravi Shankar',    'dept': 'CS Dept',    'idnum': 'KA-DL-2021-0001234', 'status': 'On Campus'},
      {'name': 'Ananya Shah',   'phone': '+91 98001 22222', 'purpose': 'Parent Visit',    'host': 'Admin Office',        'dept': 'Admin Block', 'idnum': 'MH-5432109876',      'status': 'On Campus'},
      {'name': 'Courier Exec',  'phone': '+91 98001 33333', 'purpose': 'Delivery',        'host': 'Admin Block',         'dept': 'Admin Block', 'idnum': 'CORP-DELIVERY-001',  'status': 'On Campus'},
      {'name': 'Dr. Jha',       'phone': '+91 98001 44444', 'purpose': 'Guest Lecture',   'host': 'Prof. Meenakshi Iyer','dept': 'EC Dept',    'idnum': 'GOV-GJ-19875432',    'status': 'On Campus'},
      {'name': 'Vijay Thomas',  'phone': '+91 98001 55555', 'purpose': 'Maintenance',     'host': 'Facilities',          'dept': 'Lab Block',  'idnum': 'MAINT-2024-007',     'status': 'Exited'},
    ];
    final gList = ['Main Gate', 'East Entrance', 'North Gate', 'Admin Block Entry'];
    final visitors = seeds.asMap().entries.map((e) => jsonEncode(Visitor(
      id: e.key + 1,
      name: e.value['name']!, phone: e.value['phone']!,
      purpose: e.value['purpose']!, host: e.value['host']!,
      dept: e.value['dept']!, idnum: e.value['idnum']!,
      status: e.value['status']!,
      gate: gList[rng.nextInt(gList.length)],
      checkinAt: DateTime.now(),
      lat: 12.9121, lng: 77.5221,
    ).toMap())).toList();
    await p.setStringList('gv_visitors', visitors);

    await p.setBool('gv_seeded', true);
  }

  // ── USERS ──────────────────────────────────────────────────────────────
  Future<List<UserModel>> _getUsers() async {
    final p = await prefs;
    final raw = p.getStringList('gv_users') ?? [];
    return raw.map((s) => UserModel.fromMap(jsonDecode(s))).toList();
  }

  Future<void> _saveUsers(List<UserModel> users) async {
    final p = await prefs;
    await p.setStringList('gv_users', users.map((u) => jsonEncode(u.toMap())).toList());
  }

  Future<UserModel?> getUser(String email) async {
    final users = await _getUsers();
    try { return users.firstWhere((u) => u.email == email); }
    catch (_) { return null; }
  }

  Future<List<UserModel>> getAllUsers() => _getUsers();

  Future<void> saveUser(UserModel user) async {
    final users = await _getUsers();
    final idx = users.indexWhere((u) => u.email == user.email);
    if (idx >= 0) users[idx] = user; else users.add(user);
    await _saveUsers(users);
  }

  Future<({bool ok, String? error, UserModel? user})> authenticate(
      String email, String password) async {
    await seedDefaults();
    final user = await getUser(email);
    if (user == null) return (ok: false, error: 'No account found with this email.', user: null);
    if (user.password != password) return (ok: false, error: 'Incorrect password.', user: null);
    return (ok: true, error: null, user: user);
  }

  Future<({bool ok, String? error, UserModel? user})> register({
    required String email, required String password, required String name,
    required String studentId, String? phone, String? dept, String? year,
  }) async {
    await seedDefaults();
    final existing = await getUser(email);
    if (existing != null) return (ok: false, error: 'Email already registered.', user: null);
    final user = UserModel(
      email: email, password: password, role: 'student', name: name,
      studentId: studentId, phone: phone, dept: dept, year: year,
      faceEnrolled: false, joinedAt: DateTime.now(),
    );
    await saveUser(user);
    return (ok: true, error: null, user: user);
  }

  // ── ENTRY LOGS ─────────────────────────────────────────────────────────
  Future<List<EntryLog>> getAllEntryLogs() async {
    final p = await prefs;
    final raw = p.getStringList('gv_entry_logs') ?? [];
    final logs = raw.map((s) => EntryLog.fromMap(jsonDecode(s))).toList();
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs;
  }

  Future<List<EntryLog>> getEntryLogsByUser(String userId) async {
    final all = await getAllEntryLogs();
    return all.where((e) => e.userId == userId).toList();
  }

  Future<void> addEntryLog(EntryLog log) async {
    final p = await prefs;
    final raw = p.getStringList('gv_entry_logs') ?? [];
    raw.insert(0, jsonEncode(log.toMap()));
    if (raw.length > 200) raw.removeLast();
    await p.setStringList('gv_entry_logs', raw);
  }

  // ── VISITORS ────────────────────────────────────────────────────────────
  Future<List<Visitor>> getAllVisitors() async {
    final p = await prefs;
    final raw = p.getStringList('gv_visitors') ?? [];
    return raw.map((s) => Visitor.fromMap(jsonDecode(s))).toList();
  }

  Future<void> addVisitor(Visitor v) async {
    final p = await prefs;
    final raw = p.getStringList('gv_visitors') ?? [];
    raw.add(jsonEncode(v.toMap()));
    await p.setStringList('gv_visitors', raw);
  }

  Future<void> updateVisitor(Visitor v) async {
    final p = await prefs;
    final raw = p.getStringList('gv_visitors') ?? [];
    final updated = raw.map((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['id'] == v.id ? jsonEncode(v.toMap()) : s;
    }).toList();
    await p.setStringList('gv_visitors', updated);
  }

  Future<void> removeVisitor(int id) async {
    final p = await prefs;
    final raw = p.getStringList('gv_visitors') ?? [];
    final updated = raw.where((s) => (jsonDecode(s) as Map<String, dynamic>)['id'] != id).toList();
    await p.setStringList('gv_visitors', updated);
  }
}
