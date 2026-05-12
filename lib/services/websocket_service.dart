import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WsStatus { disconnected, connecting, connected, error }

class WsEvent {
  final String type;
  final String cameraId;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> raw;

  const WsEvent({
    required this.type,
    required this.cameraId,
    required this.message,
    required this.timestamp,
    required this.raw,
  });

  factory WsEvent.fromJson(Map<String, dynamic> json) => WsEvent(
        type: json['type'] as String? ?? 'unknown',
        cameraId: json['camera_id'] as String? ?? '',
        message: json['message'] as String? ?? '',
        timestamp: json.containsKey('timestamp')
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        raw: json,
      );
}

class WebSocketService extends ChangeNotifier {
  // TODO: Replace with your real WebSocket URL
  // Android emulator: 'ws://10.0.2.2:8000/ws'
  // iOS sim / web:    'ws://localhost:8000/ws'
  static const String _wsUrl = 'wss://your-backend.com/ws';

  static const int _maxRetries = 5;
  static const Duration _retryBase = Duration(seconds: 3);
  static const Duration _pingEvery = Duration(seconds: 20);

  WsStatus _status = WsStatus.disconnected;
  WsStatus get status => _status;

  WsEvent? _latestEvent;
  WsEvent? get latestEvent => _latestEvent;

  final List<WsEvent> eventHistory = [];

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  Timer? _retryTimer;
  int _retryCount = 0;
  String? _authToken;

  void setToken(String token) => _authToken = token;

  void connect([String? url]) {
    if (_status == WsStatus.connected || _status == WsStatus.connecting) return;

    _setStatus(WsStatus.connecting);
    _errorMessage = null;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url ?? _wsUrl));

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      if (_authToken != null) {
        _send({'type': 'auth', 'token': _authToken});
      }

      _setStatus(WsStatus.connected);
      _retryCount = 0;
      _startPing();
    } catch (e) {
      _errorMessage = e.toString();
      _setStatus(WsStatus.error);
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _retryTimer?.cancel();
    _pingTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setStatus(WsStatus.disconnected);
  }

  void send(Map<String, dynamic> data) {
    if (_status != WsStatus.connected) {
      debugPrint('[WS] Cannot send — not connected');
      return;
    }
    _send(data);
  }

  void subscribeCamera(String cameraId) =>
      send({'type': 'subscribe', 'camera_id': cameraId});

  void unsubscribeCamera(String cameraId) =>
      send({'type': 'unsubscribe', 'camera_id': cameraId});

  void _send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (e) {
      debugPrint('[WS] Send error: $e');
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['type'] == 'pong') return;

      final event = WsEvent.fromJson(json);
      _latestEvent = event;

      eventHistory.insert(0, event);
      if (eventHistory.length > 50) eventHistory.removeLast();

      notifyListeners();
    } catch (e) {
      debugPrint('[WS] Parse error: $e  raw: $raw');
    }
  }

  void _onError(Object error) {
    debugPrint('[WS] Error: $error');
    _errorMessage = error.toString();
    _setStatus(WsStatus.error);
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[WS] Connection closed');
    _setStatus(WsStatus.disconnected);
    _scheduleReconnect();
  }

  void _setStatus(WsStatus s) {
    _status = s;
    notifyListeners();
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingEvery, (_) {
      _send({'type': 'ping'});
    });
  }

  void _scheduleReconnect() {
    if (_retryCount >= _maxRetries) {
      debugPrint('[WS] Max retries reached. Giving up.');
      return;
    }
    final delay = _retryBase * (_retryCount + 1);
    debugPrint('[WS] Reconnecting in ${delay.inSeconds}s');
    _retryTimer = Timer(delay, () {
      _retryCount++;
      disconnect();
      connect();
    });
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}