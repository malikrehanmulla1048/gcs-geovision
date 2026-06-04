// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';
import 'profile_screen.dart';

// ── Head movement steps ────────────────────────────────────────────
enum _EnrolStep { front, left, right, processing, done }

class FaceEnrolScreen extends StatefulWidget {
  final String mode; // 'register' | 'update'
  const FaceEnrolScreen({super.key, this.mode = 'update'});
  @override
  State<FaceEnrolScreen> createState() => _FaceEnrolScreenState();
}

class _FaceEnrolScreenState extends State<FaceEnrolScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──
  _EnrolStep _currentStep = _EnrolStep.front;
  bool _stepCaptured = false;
  bool _detecting    = false;
  String _instruction = 'Centre your face and look straight at the camera.';
  String? _error;

  Uint8List? _frontFrame;
  Uint8List? _leftFrame;
  Uint8List? _rightFrame;

  // Camera state
  bool _cameraReady = false;
  Timer? _poseTimer;

  late AnimationController _pulse;

  // JS interop: hold a reference to the capture function
  late final _CaptureHelper _captureHelper;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _captureHelper = _CaptureHelper();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  @override
  void dispose() {
    _pulse.dispose();
    _poseTimer?.cancel();
    _captureHelper.stopCamera();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      await _captureHelper.startCamera();
      if (mounted) {
        setState(() => _cameraReady = true);
        _startPoseLoop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera access denied: $e');
    }
  }

  void _startPoseLoop() {
    _poseTimer = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      if (_detecting || _stepCaptured ||
          _currentStep == _EnrolStep.processing || _currentStep == _EnrolStep.done) return;
      _detecting = true;
      try {
        await _checkCurrentStep();
      } finally {
        _detecting = false;
      }
    });
  }

  Future<void> _checkCurrentStep() async {
    final jpeg = await _captureHelper.captureFrame();
    if (jpeg == null || jpeg.isEmpty) return;

    final auth    = context.read<AuthService>();
    final email   = auth.userEmail ?? '';
    final stepStr = _currentStep.name;

    try {
      final result = await auth.backend.checkEnrolFrame(
        email: email, step: stepStr, jpegBytes: jpeg,
      );

      if (!mounted) return;
      if (result['frame_accepted'] == true) {
        setState(() {
          _stepCaptured = true;
          _instruction  = result['message'] ?? 'Captured!';
        });

        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;

        switch (_currentStep) {
          case _EnrolStep.front:
            _frontFrame = jpeg;
            setState(() {
              _currentStep = _EnrolStep.left;
              _stepCaptured = false;
              _instruction = 'Now slowly turn your head to the LEFT.';
            });
          case _EnrolStep.left:
            _leftFrame = jpeg;
            setState(() {
              _currentStep = _EnrolStep.right;
              _stepCaptured = false;
              _instruction = 'Now slowly turn your head to the RIGHT.';
            });
          case _EnrolStep.right:
            _rightFrame = jpeg;
            _submitEnrolment();
          default: break;
        }
      } else {
        if (mounted) setState(() => _instruction = result['message'] ?? '');
      }
    } catch (_) {
      if (mounted) setState(() => _instruction = 'Connecting to backend...');
    }
  }

  Future<void> _submitEnrolment() async {
    if (!mounted) return;
    setState(() {
      _currentStep = _EnrolStep.processing;
      _instruction = 'Processing face data...';
    });
    _poseTimer?.cancel();
    _captureHelper.stopCamera();

    try {
      final auth   = context.read<AuthService>();
      final result = await auth.backend.submitEnrolment(
        email:     auth.userEmail ?? '',
        frontJpeg: _frontFrame!,
        leftJpeg:  _leftFrame!,
        rightJpeg: _rightFrame!,
      );
      if (!mounted) return;
      if (result['ok'] == true) {
        await auth.refreshUser();
        setState(() => _currentStep = _EnrolStep.done);
      } else {
        setState(() {
          _error = result['detail'] ?? 'Enrolment failed. Please try again.';
          _currentStep = _EnrolStep.front;
        });
        _initCamera();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach backend: $e';
        _currentStep = _EnrolStep.front;
      });
      _initCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme      = context.watch<ThemeNotifier>();
    final isRegister = widget.mode == 'register';

    return UserShell(
      activeIndex: 2,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 8),
          Text('Face Enrolment', style: GoogleFonts.inter(
            fontSize: 22, fontWeight: FontWeight.w800, color: theme.textPrimary)),
          const SizedBox(height: 4),
          Text(isRegister
              ? 'Complete your registration by enrolling your face for campus entry.'
              : 'Update your face data for campus entry recognition.',
            style: GoogleFonts.inter(fontSize: 13, color: theme.textTertiary),
            textAlign: TextAlign.center),
          const SizedBox(height: 24),

          if (_error != null) Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GeoColors.dangerGhost,
              border: Border.all(color: GeoColors.danger.withOpacity(.3)),
              borderRadius: BorderRadius.circular(GeoRadius.md)),
            child: Row(children: [
              const Icon(Icons.error_outline, color: GeoColors.danger, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(_error!, style: GoogleFonts.inter(
                fontSize: 13, color: GeoColors.danger))),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => setState(() => _error = null),
                color: GeoColors.danger),
            ])),

          if (_currentStep == _EnrolStep.done)
            _buildSuccess(theme)
          else
            _buildEnrolContent(theme),
        ]),
      ),
    );
  }

  Widget _buildEnrolContent(ThemeNotifier theme) => Column(children: [
    _buildStepIndicator(theme),
    const SizedBox(height: 24),

    // Camera viewfinder — static display, camera streams in background
    _buildViewfinder(theme),
    const SizedBox(height: 20),

    // Instruction card
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.bgCard,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(GeoRadius.lg)),
      child: Column(children: [
        Icon(
          _stepCaptured ? Icons.check_circle : Icons.face,
          color: _stepCaptured ? GeoColors.success : GeoColors.primary,
          size: 28),
        const SizedBox(height: 10),
        Text(_instruction, style: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w600,
          color: _stepCaptured ? GeoColors.success : theme.textPrimary,
          height: 1.5),
          textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Text('Keep your face in frame. The system captures automatically when your pose is correct.',
          style: GoogleFonts.inter(fontSize: 12, color: theme.textTertiary, height: 1.6),
          textAlign: TextAlign.center),
      ]),
    ),
    const SizedBox(height: 20),

    // Instructions
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.bgCard,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(GeoRadius.lg)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Instructions', style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary)),
        const SizedBox(height: 14),
        ...[
          'Ensure good, even lighting on your face',
          'Remove sunglasses, masks, or heavy accessories',
          'Follow the on-screen prompts for head movements',
          'Keep a neutral expression',
          'The system captures automatically',
        ].map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.check_circle_outline, size: 16, color: GeoColors.success),
            const SizedBox(width: 10),
            Expanded(child: Text(s, style: GoogleFonts.inter(
              fontSize: 13, color: theme.textSecondary, height: 1.4))),
          ]))),
      ])),
    const SizedBox(height: 80),
  ]);

  Widget _buildStepIndicator(ThemeNotifier theme) {
    final steps = [
      (_EnrolStep.front,      'Look Straight', Icons.face),
      (_EnrolStep.left,       'Turn Left',      Icons.rotate_left),
      (_EnrolStep.right,      'Turn Right',     Icons.rotate_right),
      (_EnrolStep.processing, 'Processing',    Icons.cloud_upload_outlined),
    ];

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: steps.asMap().entries.map((entry) {
      final i    = entry.key;
      final step = entry.value;
      final done = _currentStep.index > step.$1.index;
      final active = _currentStep == step.$1;

      return Row(mainAxisSize: MainAxisSize.min, children: [
        if (i > 0) Container(width: 32, height: 1,
          color: done ? GeoColors.success : theme.border),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? GeoColors.success : active ? GeoColors.primary : theme.bgBadge,
            border: Border.all(color: done ? GeoColors.success : active ? GeoColors.primary : theme.border)),
          child: Center(child: done
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Icon(step.$3, color: active ? Colors.white : theme.textTertiary, size: 18))),
      ]);
    }).toList());
  }

  Widget _buildViewfinder(ThemeNotifier theme) {
    final isProcessing = _currentStep == _EnrolStep.processing;
    final color = _stepCaptured ? GeoColors.success : GeoColors.primary;

    return Container(
      width: 320, height: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(GeoRadius.lg),
        border: Border.all(color: color.withOpacity(.6), width: 2)),
      child: Stack(children: [
        if (isProcessing)
          Positioned.fill(child: ClipRRect(
            borderRadius: BorderRadius.circular(GeoRadius.lg - 2),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: GeoColors.primary),
              const SizedBox(height: 16),
              Text('Analysing face data...', style: GoogleFonts.inter(
                fontSize: 13, color: Colors.white70)),
            ]))))
        else if (!_cameraReady)
          const Positioned.fill(child: Center(child:
            CircularProgressIndicator(color: GeoColors.primary)))
        else
          Positioned.fill(child: ClipRRect(
            borderRadius: BorderRadius.circular(GeoRadius.lg - 2),
            child: _VideoPreview(captureHelper: _captureHelper))),

        // Corner brackets
        ..._buildCorners(color),

        // Pulse ring
        if (!isProcessing) Center(child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(.15 + _pulse.value * .2),
                width: 2))))),
      ]));
  }

  List<Widget> _buildCorners(Color color) => [
    Positioned(top: 16, left: 16, child: _corner(color)),
    Positioned(top: 16, right: 16, child: Transform(
      transform: Matrix4.rotationY(3.14159), alignment: Alignment.center, child: _corner(color))),
    Positioned(bottom: 16, left: 16, child: Transform(
      transform: Matrix4.rotationX(3.14159), alignment: Alignment.center, child: _corner(color))),
    Positioned(bottom: 16, right: 16, child: Transform(
      transform: (Matrix4.identity()..rotateX(3.14159)..rotateY(3.14159)),
      alignment: Alignment.center, child: _corner(color))),
  ];

  Widget _corner(Color color) => SizedBox(
    width: 22, height: 22,
    child: CustomPaint(painter: _CornerPainter(color)));

  Widget _buildSuccess(ThemeNotifier theme) => Column(children: [
    Container(
      width: 100, height: 100,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF15803D)],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: const Center(child: Icon(Icons.check, color: Colors.white, size: 52))),
    const SizedBox(height: 24),

    Text('Face Enrolled Successfully', style: GoogleFonts.inter(
      fontSize: 22, fontWeight: FontWeight.w800, color: GeoColors.success)),
    const SizedBox(height: 8),
    Text('Your face data has been securely stored.\nYou can now enter campus via facial recognition.',
      style: GoogleFonts.inter(fontSize: 14, color: theme.textSecondary, height: 1.6),
      textAlign: TextAlign.center),
    const SizedBox(height: 28),

    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GeoColors.successGhost,
        border: Border.all(color: GeoColors.success.withOpacity(.25)),
        borderRadius: BorderRadius.circular(GeoRadius.lg)),
      child: Column(children: [
        _successRow(theme, Icons.photo_camera, '3 angles captured', 'Front, left, and right profile'),
        const SizedBox(height: 12),
        _successRow(theme, Icons.lock_outline, 'Encrypted & secured', 'Face embedding stored in backend'),
        const SizedBox(height: 12),
        _successRow(theme, Icons.smart_toy_outlined, 'AI model updated', '512-dim face vector enrolled'),
      ])),
    const SizedBox(height: 28),

    SizedBox(width: double.infinity, child: ElevatedButton(
      onPressed: () => context.go('/user/profile'),
      style: ElevatedButton.styleFrom(
        backgroundColor: GeoColors.primary, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GeoRadius.md))),
      child: Text('Go to Profile', style: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w800)))),
    const SizedBox(height: 80),
  ]);

  Widget _successRow(ThemeNotifier theme, IconData icon, String title, String sub) =>
    Row(children: [
      Icon(icon, size: 22, color: GeoColors.success),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w700, color: theme.textPrimary)),
        Text(sub, style: GoogleFonts.inter(fontSize: 12, color: theme.textSecondary)),
      ]),
    ]);
}

// ── Camera capture helper (JS interop) ─────────────────────────────────────
class _CaptureHelper {
  web.HTMLVideoElement? _video;
  web.HTMLCanvasElement? _canvas;
  bool _active = false;

  Future<void> startCamera() async {
    _video  = web.HTMLVideoElement()
      ..autoplay = true
      ..muted    = true
      ..id       = 'gv-enrol-video';
    _canvas = web.HTMLCanvasElement()
      ..width  = 640
      ..height = 480
      ..id     = 'gv-enrol-canvas';

    // Hide both elements from view
    _video!.style.cssText  = 'position:fixed;top:-9999px;left:-9999px;width:1px;height:1px;';
    _canvas!.style.cssText = 'position:fixed;top:-9999px;left:-9999px;width:1px;height:1px;';
    web.document.body?.append(_video!);
    web.document.body?.append(_canvas!);

    // Request camera using promiseToFuture for web 1.1.x compatibility
    final constraints = web.MediaStreamConstraints(
      video: true.toJS,
      audio: false.toJS,
    );
    final stream = await js_util.promiseToFuture<web.MediaStream>(
      web.window.navigator.mediaDevices.getUserMedia(constraints),
    );
    _video!.srcObject = stream;
    await js_util.promiseToFuture<void>(_video!.play());
    _active = true;
  }

  void stopCamera() {
    _active = false;
    final stream = _video?.srcObject;
    if (stream != null) {
      final tracks = (stream as web.MediaStream).getTracks().toDart;
      for (final t in tracks) t.stop();
    }
    _video?.remove();
    _canvas?.remove();
    _video  = null;
    _canvas = null;
  }

  Future<Uint8List?> captureFrame() async {
    if (!_active || _video == null || _canvas == null) return null;
    try {
      final ctx = _canvas!.getContext('2d') as web.CanvasRenderingContext2D;
      
      // Ensure canvas matches video aspect ratio exactly to prevent distortion
      final vw = _video!.videoWidth;
      final vh = _video!.videoHeight;
      if (vw > 0 && vh > 0) {
        if (_canvas!.width != vw || _canvas!.height != vh) {
          _canvas!.width = vw;
          _canvas!.height = vh;
        }
      }
      
      ctx.drawImage(_video!, 0, 0, _canvas!.width, _canvas!.height);
      
      final dataUrl = _canvas!.toDataURL('image/jpeg');
      final comma = dataUrl.indexOf(',');
      if (comma < 0) return null;
      final b64 = dataUrl.substring(comma + 1);
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  bool get isActive => _active;
}

// ── Video preview widget ──────────────────────────────────────────────────
class _VideoPreview extends StatefulWidget {
  final _CaptureHelper captureHelper;
  const _VideoPreview({required this.captureHelper});
  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  Timer? _frameTimer;
  Uint8List? _frame;

  @override
  void initState() {
    super.initState();
    // Poll the canvas at 15fps for display
    _frameTimer = Timer.periodic(const Duration(milliseconds: 66), (_) async {
      final bytes = await widget.captureHelper.captureFrame();
      if (bytes != null && mounted) setState(() => _frame = bytes);
    });
  }

  @override
  void dispose() { _frameTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_frame == null) {
      return const Center(child: CircularProgressIndicator(color: GeoColors.primary));
    }
    return Image.memory(_frame!, fit: BoxFit.cover, gaplessPlayback: true);
  }
}

// ── Corner painter ─────────────────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), p);
    canvas.drawLine(Offset.zero, Offset(0, size.height), p);
  }
  @override bool shouldRepaint(_) => false;
}
