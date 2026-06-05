// ignore: avoid_web_libraries_in_flutter
@JS()
library cctv_web_camera;

import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

/// Registers and manages a browser webcam stream using getUserMedia.
/// Returns a view type string to use with HtmlElementView.
class WebCameraHelper {
  static const String _viewType = 'geovision-webcam-view';
  static bool _registered = false;
  static web.MediaStream? _stream;
  static web.HTMLVideoElement? _videoEl;

  static String registerViewFactory() {
    if (!_registered && kIsWeb) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        final video = web.document.createElement('video') as web.HTMLVideoElement
          ..autoplay = true
          ..muted = true
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..style.background = '#000';
        _videoEl = video;
        if (_stream != null) {
          video.srcObject = _stream;
        }
        return video;
      });
      _registered = true;
    }
    return _viewType;
  }

  static Future<bool> startCamera() async {
    if (!kIsWeb) return false;
    try {
      final constraints = web.MediaStreamConstraints(video: true.toJS);
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;
      _stream = stream;
      _videoEl?.srcObject = stream;
      return true;
    } catch (e) {
      return false;
    }
  }

  static void stopCamera() {
    if (_stream != null) {
      final tracks = _stream!.getTracks().toDart;
      for (final track in tracks) {
        track.stop();
      }
      _stream = null;
      if (_videoEl != null) {
        _videoEl!.srcObject = null;
      }
    }
  }

  static bool get hasStream => _stream != null;
}
