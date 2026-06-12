import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/backend_service.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/web_camera_helper.dart';

class CctvFeedScreen extends StatefulWidget {
  const CctvFeedScreen({super.key});
  @override
  State<CctvFeedScreen> createState() => _CctvFeedScreenState();
}

class _CctvFeedScreenState extends State<CctvFeedScreen> {
  late final BackendService _backend;

  List<Map<String, dynamic>> _cameras = [];
  int _selectedCameraId = -1;

  // WebSocket stream for the active camera
  WebSocketChannel? _wsChannel;
  Uint8List? _currentFrame;
  List<dynamic> _detections = [];
  bool _hasThreat = false;
  bool _loading   = true;
  bool _camError  = false;
  bool _noCamera  = false; // true when cloud server has no physical webcam
  String _camErrorMsg = '';

  // Browser webcam mode (web only)
  bool _browserCamActive = false;
  bool _browserCamLoading = false;
  String _viewType = '';

  final TextEditingController _addNameCtrl   = TextEditingController();
  final TextEditingController _addSourceCtrl = TextEditingController();
  bool _addingCam = false;

  @override
  void initState() {
    super.initState();
    _backend = context.read<AuthService>().backend;
    _loadCameras();
    if (kIsWeb) {
      _viewType = WebCameraHelper.registerViewFactory();
    }
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    if (_browserCamActive) WebCameraHelper.stopCamera();
    _addNameCtrl.dispose();
    _addSourceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCameras() async {
    final cams = await _backend.getCameras();
    if (!mounted) return;
    final camList = cams.cast<Map<String, dynamic>>();
    setState(() {
      _cameras = camList;
      _loading = false;
      if (camList.isNotEmpty) {
        _selectCamera(camList.first['id'] as int);
      }
    });
  }

  void _selectCamera(int id) {
    if (_selectedCameraId == id) return;
    _wsChannel?.sink.close();
    setState(() {
      _selectedCameraId = id;
      _currentFrame = null;
      _detections   = [];
      _hasThreat    = false;
      _camError     = false;
      _noCamera     = false;
    });
    _connectWebSocket(id);
  }

  void _connectWebSocket(int cameraId) {
    final baseUrl = BackendService.baseUrl;
    final wsBase = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse('$wsBase/ws/camera/$cameraId'));
      _wsChannel!.stream.listen(
        (msg) {
          if (!mounted) return;
          try {
            final data = jsonDecode(msg as String) as Map<String, dynamic>;
            if (data['error'] != null) {
              final err = data['error'] as String;
              final noCamera = err.toLowerCase().contains('no camera') ||
                  err.toLowerCase().contains('cannot open') ||
                  err.toLowerCase().contains('index out') ||
                  err.toLowerCase().contains('device not found');
              setState(() {
                _camError = true;
                _noCamera = noCamera;
                _camErrorMsg = err;
              });
              return;
            }
            final b64   = data['frame_b64'] as String;
            final bytes = base64Decode(b64);
            setState(() {
              _currentFrame = bytes;
              _detections   = (data['detections'] as List?) ?? [];
              _hasThreat    = data['has_threat'] == true;
              _camError     = false;
              _noCamera     = false;
            });
          } catch (_) {}
        },
        onError: (_) {
          if (mounted) setState(() {
            _camError = true;
            _noCamera = true;
            _camErrorMsg = 'WebSocket connection failed.';
          });
        },
        onDone: () {
          if (mounted) setState(() {
            _camError = true;
            _noCamera = true;
            _camErrorMsg = 'Camera stream disconnected.';
          });
        },
      );
    } catch (e) {
      setState(() {
        _camError = true;
        _noCamera = true;
        _camErrorMsg = 'Cannot connect to backend: $e';
      });
    }
  }

  Future<void> _addCamera() async {
    final name   = _addNameCtrl.text.trim();
    final source = _addSourceCtrl.text.trim();
    if (name.isEmpty || source.isEmpty) return;
    setState(() => _addingCam = true);
    try {
      final result = await _backend.addCamera(name, source);
      _addNameCtrl.clear();
      _addSourceCtrl.clear();
      await _loadCameras();
      if (mounted && result['ok'] == true) {
        GeoToast.show(context, 'Camera added.', type: 'success');
      }
    } finally {
      if (mounted) setState(() => _addingCam = false);
    }
  }

  Future<void> _deleteCamera(int id) async {
    if (id == _selectedCameraId) {
      _wsChannel?.sink.close();
    }
    await _backend.deleteCamera(id);
    _loadCameras();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final selected = _cameras.firstWhere(
      (c) => c['id'] == _selectedCameraId,
      orElse: () => {},
    );

    return AdminShell(
      activeRoute: '/admin/cctv',
      breadcrumb: 'CCTV Feed',
      pageTitle: 'CCTV — Live Camera Feed',
      topbarActions: [
        const LiveBadge(),
        const SizedBox(width: 8),
        _topBtn(theme, Icons.add_outlined, 'Add Camera', _showAddCameraDialog),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GeoColors.primary))
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── CAMERA LIST SIDEBAR ──────────────────────────────
              Container(
                width: 240,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: theme.border))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Text('Cameras (${_cameras.length})', style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: theme.textTertiary, letterSpacing: .5)),
                  ),
                  Expanded(child: ListView.builder(
                    itemCount: _cameras.length,
                    itemBuilder: (_, i) {
                      final cam = _cameras[i];
                      final id  = cam['id'] as int;
                      final isSelected = id == _selectedCameraId;
                      return GestureDetector(
                        onTap: () => _selectCamera(id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? GeoColors.primaryGhost : Colors.transparent,
                            border: Border(left: BorderSide(
                              color: isSelected ? GeoColors.primary : Colors.transparent,
                              width: 2))),
                          child: Row(children: [
                            Icon(Icons.videocam_outlined, size: 16,
                              color: isSelected ? GeoColors.primary : theme.textTertiary),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(cam['name'] as String? ?? 'Camera',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                                  color: isSelected ? GeoColors.primary : theme.textPrimary),
                                overflow: TextOverflow.ellipsis),
                              Text('Source: ${cam['source']}',
                                style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary)),
                            ])),
                            if (!isSelected) IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16),
                              onPressed: () => _deleteCamera(id),
                              color: theme.textTertiary,
                              tooltip: 'Remove camera',
                            ),
                          ]),
                        ),
                      );
                    },
                  )),
                ]),
              ),

              // ── MAIN FEED ────────────────────────────────────────
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Camera name + status
                  Row(children: [
                    Text(selected['name'] as String? ?? 'Camera', style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w800, color: theme.textPrimary)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _hasThreat ? GeoColors.dangerGhost : GeoColors.successGhost,
                        borderRadius: BorderRadius.circular(GeoRadius.full)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: _hasThreat ? GeoColors.danger : GeoColors.success,
                            shape: BoxShape.circle)),
                        Text(_hasThreat ? 'THREAT DETECTED' : 'All Clear',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                            color: _hasThreat ? GeoColors.danger : GeoColors.success)),
                      ])),
                  ]),
                  const SizedBox(height: 16),

                  // Video frame display
                  Container(
                    width: double.infinity,
                    height: 480,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A0A),
                      borderRadius: BorderRadius.circular(GeoRadius.lg),
                      border: Border.all(color: _hasThreat ? GeoColors.danger : theme.border,
                        width: _hasThreat ? 2 : 1)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(GeoRadius.lg - 1),
                      child: _browserCamActive
                          ? Stack(children: [
                              if (_viewType.isNotEmpty)
                                HtmlElementView(viewType: _viewType),
                              Positioned(
                                top: 12, right: 12,
                                child: GestureDetector(
                                  onTap: () {
                                    WebCameraHelper.stopCamera();
                                    setState(() => _browserCamActive = false);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(GeoRadius.sm)),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Icon(Icons.stop_circle_outlined, size: 14, color: GeoColors.danger),
                                      const SizedBox(width: 5),
                                      Text('Stop Camera', style: GoogleFonts.inter(
                                        fontSize: 11, color: Colors.white)),
                                    ]),
                                  ),
                                )),
                              Positioned(
                                top: 12, left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: GeoColors.danger.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(GeoRadius.sm)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Container(width: 6, height: 6,
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                                    const SizedBox(width: 5),
                                    Text('LIVE — Browser Camera', style: GoogleFonts.inter(
                                      fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                                  ]),
                                )),
                            ])
                          : _camError
                              ? (_noCamera ? _buildNoLocalCameraWidget(theme) : _buildErrorWidget(theme))
                              : _currentFrame == null
                                  ? const Center(child: CircularProgressIndicator(color: GeoColors.primary))
                                  : Image.memory(_currentFrame!,
                                      fit: BoxFit.contain,
                                      gaplessPlayback: true),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Detection list
                  if (_detections.isNotEmpty) ...[
                    Text('Detections (${_detections.length})', style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700, color: theme.textPrimary)),
                    const SizedBox(height: 10),
                    ..._detections.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _detectionChip(theme, d as Map<String, dynamic>))),
                    const SizedBox(height: 8),
                  ],

                  // Help text
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
                      borderRadius: BorderRadius.circular(GeoRadius.md)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('FR Colour Key', style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700, color: theme.textPrimary)),
                      const SizedBox(height: 8),
                      _colorKey(Colors.green, 'Authorised — enrolled & geofence OK'),
                      _colorKey(Colors.orange, 'Unidentified — not in database'),
                      _colorKey(Colors.red, 'Blacklisted — flagged individual'),
                    ]),
                  ),
                ]),
              )),
            ]),
    );
  }

  Widget _buildNoLocalCameraWidget(ThemeNotifier theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: GeoColors.primaryGhost,
              shape: BoxShape.circle),
            child: const Icon(Icons.videocam_outlined, size: 48, color: GeoColors.primary)),
          const SizedBox(height: 20),
          Text('No Backend Camera',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            'The cloud server has no webcam. Use your browser camera\nor run the backend locally for full face recognition.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white54, height: 1.6),
            textAlign: TextAlign.center),
          const SizedBox(height: 20),

          // Primary: Use browser webcam
          if (kIsWeb) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _browserCamLoading ? null : () async {
                  setState(() => _browserCamLoading = true);
                  final ok = await WebCameraHelper.startCamera();
                  setState(() {
                    _browserCamLoading = false;
                    if (ok) {
                      _browserCamActive = true;
                      _camError = false;
                    }
                  });
                  if (!ok && mounted) {
                    GeoToast.show(context, 'Camera permission denied.', type: 'error');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GeoColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GeoRadius.md))),
                icon: _browserCamLoading
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.videocam, size: 18, color: Colors.white),
                label: Text(
                  _browserCamLoading ? 'Requesting permission…' : '📷  Use Your Webcam (Browser)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
              )),
            const SizedBox(height: 12),
            Text('— or run backend locally for face recognition —',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white24)),
            const SizedBox(height: 12),
          ],

          // Secondary: local backend instructions
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(GeoRadius.md),
              border: Border.all(color: GeoColors.primary.withOpacity(0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _codeRow('1. cd backend/'),
              _codeRow('2. pip install -r requirements.txt'),
              _codeRow('3. python main.py'),
            ])),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _connectWebSocket(_selectedCameraId),
            icon: const Icon(Icons.refresh, size: 16, color: GeoColors.primary),
            label: Text('Retry Backend Connection',
              style: GoogleFonts.inter(fontSize: 13, color: GeoColors.primary))),
        ]),
      ),
    );
  }

  Widget _buildErrorWidget(ThemeNotifier theme) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.videocam_off_outlined, size: 48, color: Colors.white38),
        const SizedBox(height: 12),
        Text(_camErrorMsg, style: GoogleFonts.inter(
          fontSize: 13, color: Colors.white54), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _connectWebSocket(_selectedCameraId),
          child: const Text('Retry', style: TextStyle(color: GeoColors.primary)),
        ),
      ]),
    );
  }

  Widget _codeRow(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: GoogleFonts.robotoMono(
      fontSize: 11, color: GeoColors.primary)));

  Widget _detectionChip(ThemeNotifier theme, Map<String, dynamic> d) {
    final threat = d['threat_type'] as String?;
    final name   = d['name'] as String? ?? 'Unknown';
    final conf   = (d['confidence'] as num?)?.toDouble() ?? 0;
    final Color color;
    final IconData icon;
    final String label;
    if (threat == 'blacklisted') {
      color = GeoColors.danger; icon = Icons.block; label = 'Blacklisted';
    } else if (threat == 'unidentified') {
      color = GeoColors.warning; icon = Icons.person_off_outlined; label = 'Unidentified';
    } else {
      color = GeoColors.success; icon = Icons.verified_user_outlined; label = 'Authorised';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        border: Border.all(color: color.withOpacity(.3)),
        borderRadius: BorderRadius.circular(GeoRadius.md)),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text('$name — ${conf.toStringAsFixed(0)}% confidence',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(.15),
            borderRadius: BorderRadius.circular(GeoRadius.full)),
          child: Text(label, style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700, color: color))),
      ]),
    );
  }

  Widget _colorKey(Color color, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Container(width: 14, height: 3, color: color, margin: const EdgeInsets.only(right: 8)),
      Text(label, style: GoogleFonts.inter(fontSize: 12, color: context.read<ThemeNotifier>().textSecondary)),
    ]));

  Widget _topBtn(ThemeNotifier theme, IconData icon, String label, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
          borderRadius: BorderRadius.circular(GeoRadius.sm)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: theme.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w500, color: theme.textSecondary)),
        ]),
      ));

  void _showAddCameraDialog() {
    final theme = context.read<ThemeNotifier>();
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: theme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GeoRadius.lg)),
      title: Text('Add Camera', style: GoogleFonts.inter(
        fontWeight: FontWeight.w800, color: theme.textPrimary)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _addNameCtrl,
          style: GoogleFonts.inter(color: theme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Camera Name (e.g. North Gate — CAM-02)',
            labelStyle: GoogleFonts.inter(color: theme.textTertiary, fontSize: 13)),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _addSourceCtrl,
          style: GoogleFonts.inter(color: theme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Source: webcam index (0, 1…) or RTSP URL',
            labelStyle: GoogleFonts.inter(color: theme.textTertiary, fontSize: 13)),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () { Navigator.pop(context); _addCamera(); },
          child: const Text('Add')),
      ],
    ));
  }
}
