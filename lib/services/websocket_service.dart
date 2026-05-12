import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WsStatus { disconnected, connecting, connected, error }

class WebSocketService extends ChangeNotifier {
  static const String wsUrl = 'wss://your-backend.com/ws'; // ← change this

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  WsStatus _status = WsStatus.disconnected;
  WsStatus get status => _status;

  // Latest data from server (e.g. camera motion alerts)
  Map<String, dynamic> _latestEvent = {};
  Map<String, dynamic> get latestEvent => _latestEvent;

  void connect() {
    if (_status == WsStatus.connected) return;

    _status = WsStatus.connecting;
    notifyListeners();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _status = WsStatus.connected;
      notifyListeners();

      _subscription = _channel!.stream.listen(
        (message) {
          _latestEvent = jsonDecode(message as String);
          notifyListeners();
        },
        onError: (error) {
          _status = WsStatus.error;
          notifyListeners();
          _reconnect();
        },
        onDone: () {
          _status = WsStatus.disconnected;
          notifyListeners();
        },
      );
    } catch (e) {
      _status = WsStatus.error;
      notifyListeners();
    }
  }

  // Send a message to the server
  void send(Map<String, dynamic> data) {
    if (_status == WsStatus.connected) {
      _channel?.sink.add(jsonEncode(data));
    }
  }

  // Auto-reconnect after 5 seconds
  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      disconnect();
      connect();
    });
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _status = WsStatus.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}