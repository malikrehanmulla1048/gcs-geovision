import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Thrown when the server returns a non-2xx status code.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  // TODO: Replace with your real backend URL
  // Android emulator: 'http://10.0.2.2:8000/api'
  // iOS sim / web:    'http://localhost:8000/api'
  static const String baseUrl = 'https://your-backend.com/api';

  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client = http.Client();
  String? _token;

  void setToken(String? token) => _token = token;

  // ── Generic HTTP ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> get(String endpoint) async {
    final res = await _client
        .get(Uri.parse('$baseUrl$endpoint'), headers: _headers())
        .timeout(_timeout);
    return _handle(res);
  }

  Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> body) async {
    final res = await _client
        .post(Uri.parse('$baseUrl$endpoint'),
            headers: _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    return _handle(res);
  }

  Future<Map<String, dynamic>> put(
      String endpoint, Map<String, dynamic> body) async {
    final res = await _client
        .put(Uri.parse('$baseUrl$endpoint'),
            headers: _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    return _handle(res);
  }

  Future<void> delete(String endpoint) async {
    final res = await _client
        .delete(Uri.parse('$baseUrl$endpoint'), headers: _headers())
        .timeout(_timeout);
    _handle(res);
  }

  // ── GeoVision domain methods ──────────────────────────────────────────────

  Future<List<dynamic>> getCameraList() async {
    final data = await get('/cameras');
    return data['cameras'] ?? [];
  }

  Future<Map<String, dynamic>> getCameraStatus(String cameraId) async {
    return get('/cameras/$cameraId/status');
  }

  Future<List<dynamic>> getAlerts({int page = 1, int limit = 20}) async {
    final data = await get('/alerts?page=$page&limit=$limit');
    return data['alerts'] ?? [];
  }

  Future<void> sendAlert({
    required String cameraId,
    required String message,
    String severity = 'medium',
  }) async {
    await post('/alerts', {
      'camera_id': cameraId,
      'message': message,
      'severity': severity,
    });
  }

  Future<String> login(String username, String password) async {
    final data = await post('/auth/login', {
      'username': username,
      'password': password,
    });
    final token = data['token'] as String?;
    if (token == null) {
      throw const ApiException(200, 'Token missing in response');
    }
    _token = token;
    return token;
  }

  Future<void> logout() async {
    await post('/auth/logout', {});
    _token = null;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Map<String, String> _headers() => {
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
        if (_token != null)
          HttpHeaders.authorizationHeader: 'Bearer $_token',
      };

  Map<String, dynamic> _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    String msg;
    try {
      msg = (jsonDecode(res.body) as Map)['message'] ?? res.body;
    } catch (_) {
      msg = res.body;
    }
    throw ApiException(res.statusCode, msg);
  }

  void dispose() => _client.close();
}