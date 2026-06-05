import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Checks GitHub Releases for a newer APK and returns the download URL if available.
class UpdateService {
  static const _repo = 'marcpedrin/gcs-geovision';
  static const _currentVersion = '1.0.0'; // bump this with each release

  /// Returns download URL if update is available, null otherwise.
  static Future<UpdateInfo?> checkForUpdate() async {
    if (kIsWeb) return null; // web doesn't need APK updates
    if (!Platform.isAndroid) return null;
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String? ?? '').replaceAll(RegExp(r'[^0-9.]'), '');
      if (tagName.isEmpty) return null;

      if (_isNewer(tagName, _currentVersion)) {
        final assets = data['assets'] as List<dynamic>? ?? [];
        String? apkUrl;
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
        if (apkUrl != null) {
          return UpdateInfo(
            version: tagName,
            downloadUrl: apkUrl,
            releaseNotes: data['body'] as String? ?? 'Bug fixes and improvements.',
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _isNewer(String remote, String local) {
    final r = _parse(remote);
    final l = _parse(local);
    for (int i = 0; i < 3; i++) {
      final ri = i < r.length ? r[i] : 0;
      final li = i < l.length ? l[i] : 0;
      if (ri > li) return true;
      if (ri < li) return false;
    }
    return false;
  }

  static List<int> _parse(String v) =>
      v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
}

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}
