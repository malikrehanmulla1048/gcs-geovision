import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://your-backend.com/api'; // ← change this

  final http.Client _client = http.Client();

  // GET request
  Future<Map<String, dynamic>> get(String endpoint) async {
    final response = await _client.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  // POST request
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  // Example: fetch CCTV camera status
  Future<List<dynamic>> getCameraStatus() async {
    final data = await get('/cameras/status');
    return data['cameras'] ?? [];
  }

  // Example: send alert
  Future<void> sendAlert(String cameraId, String message) async {
    await post('/alerts', {'camera_id': cameraId, 'message': message});
  }

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    // Add auth token here if needed:
    // 'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  void dispose() => _client.close();
}