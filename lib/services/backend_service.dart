import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Communicates with the Python FastAPI backend at localhost:8000.
class BackendService {
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://marcpedrin-geovision-backend.hf.space',
  );
  static const Duration _timeout = Duration(seconds: 20);

  final http.Client _client = http.Client();

  // ── AUTH ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(_timeout);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String email, required String password, required String name,
    required String studentId, String? phone, String? dept, String? year,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email, 'password': password, 'name': name,
        'student_id': studentId, 'phone': phone, 'dept': dept, 'year': year,
      }),
    ).timeout(_timeout);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getUser(String email) async {
    try {
      final res = await _client.get(
        Uri.parse('$baseUrl/auth/user/$email'),
      ).timeout(_timeout);
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  Future<void> updateProfile(String email, {
    required String name, String? phone, String? dept, String? year,
  }) async {
    await _client.put(
      Uri.parse('$baseUrl/auth/user/$email/profile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'phone': phone ?? '', 'dept': dept ?? '', 'year': year ?? ''}),
    ).timeout(_timeout);
  }

  // ── FACE ENROLMENT ───────────────────────────────────────────────

  /// Check head pose for a given step.
  /// Returns {ok, frame_accepted, message, pose}
  Future<Map<String, dynamic>> checkEnrolFrame({
    required String email,
    required String step,
    required Uint8List jpegBytes,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/enrol/frame'));
    req.fields['email'] = email;
    req.fields['step']  = step;
    req.files.add(http.MultipartFile.fromBytes(
      'image', jpegBytes,
      filename: 'frame.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));
    final streamed = await req.send().timeout(_timeout);
    final body     = await streamed.stream.bytesToString();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// Submit 3 captured frames for final enrolment.
  Future<Map<String, dynamic>> submitEnrolment({
    required String email,
    required Uint8List frontJpeg,
    required Uint8List leftJpeg,
    required Uint8List rightJpeg,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/enrol/submit'));
    req.fields['email'] = email;
    for (final (name, bytes) in [
      ('front', frontJpeg), ('left', leftJpeg), ('right', rightJpeg)
    ]) {
      req.files.add(http.MultipartFile.fromBytes(
        name, bytes,
        filename: '$name.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }
    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final body     = await streamed.stream.bytesToString();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// Run face recognition on a single JPEG frame.
  Future<Map<String, dynamic>> recognizeFrame(String gate, Uint8List jpegBytes) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/recognize'));
    req.fields['gate'] = gate;
    req.files.add(http.MultipartFile.fromBytes(
      'image', jpegBytes,
      filename: 'frame.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));
    final streamed = await req.send().timeout(_timeout);
    final body = await streamed.stream.bytesToString();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  // ── STATS ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/stats')).timeout(_timeout);
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> getHealth() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/health')).timeout(_timeout);
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<List<dynamic>> getOnCampus() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/on_campus')).timeout(_timeout);
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  // ── ENTRY LOGS ───────────────────────────────────────────────────

  Future<List<dynamic>> getEntryLogs({
    int limit = 100, int offset = 0,
    String typeFilter = 'all', String gateFilter = 'all', String search = '',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/entry_logs').replace(queryParameters: {
        'limit':       '$limit',
        'offset':      '$offset',
        'type_filter': typeFilter,
        'gate_filter': gateFilter,
        'search':      search,
      });
      final res = await _client.get(uri).timeout(_timeout);
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getUserEntryLogs(String email) async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/entry_logs/user/$email')).timeout(_timeout);
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  // ── THREATS ──────────────────────────────────────────────────────

  Future<List<dynamic>> getThreats({String? status}) async {
    try {
      final uri = Uri.parse('$baseUrl/threats')
          .replace(queryParameters: status != null ? {'status': status} : {});
      final res = await _client.get(uri).timeout(_timeout);
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  Future<void> resolveThreat(int threatId) async {
    await _client.post(Uri.parse('$baseUrl/threats/$threatId/resolve')).timeout(_timeout);
  }

  // ── CAMERAS ──────────────────────────────────────────────────────

  Future<List<dynamic>> getCameras() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/cameras')).timeout(_timeout);
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> addCamera(String name, String source) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/cameras'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'source': source}),
    ).timeout(_timeout);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> deleteCamera(int cameraId) async {
    await _client.delete(Uri.parse('$baseUrl/cameras/$cameraId')).timeout(_timeout);
  }

  // ── USERS ────────────────────────────────────────────────────────

  Future<List<dynamic>> getAllUsers() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/users')).timeout(_timeout);
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  Future<void> setBlacklisted(String email, bool blacklisted) async {
    await _client.post(
      Uri.parse('$baseUrl/users/$email/blacklist'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'blacklisted': blacklisted}),
    ).timeout(_timeout);
  }

  Future<void> setGeofenced(String email, bool geofenced) async {
    await _client.post(
      Uri.parse('$baseUrl/users/$email/geofence'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'geofenced': geofenced}),
    ).timeout(_timeout);
  }

  // ── VISITORS ─────────────────────────────────────────────────────

  Future<List<dynamic>> getVisitors() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/visitors')).timeout(_timeout);
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> addVisitor({
    required String name, required String phone, required String purpose,
    required String host, required String dept, required String idNumber, required String gate,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/visitors'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name, 'phone': phone, 'purpose': purpose,
        'host': host, 'dept': dept, 'id_number': idNumber, 'gate': gate,
      }),
    ).timeout(_timeout);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> checkoutVisitor(int visitorId) async {
    await _client.post(Uri.parse('$baseUrl/visitors/$visitorId/checkout')).timeout(_timeout);
  }

  void dispose() => _client.close();
}
