import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';
import 'profile_screen.dart';

class FaceEnrolScreen extends StatefulWidget {
  final String mode; // 'register' | 'update'
  const FaceEnrolScreen({super.key, this.mode = 'update'});
  @override
  State<FaceEnrolScreen> createState() => _FaceEnrolScreenState();
}

class _FaceEnrolScreenState extends State<FaceEnrolScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  bool _capturing = false;
  bool _done = false;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  Future<void> _startCapture() async {
    setState(() { _capturing = true; _step = 1; });
    // Simulate capture steps
    for (int i = 1; i <= 3; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _step = i + 1);
    }
    // Simulate processing
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Mark face enrolled
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user != null) {
      await auth.updateProfile(user.copyWith(faceEnrolled: true));
    }
    setState(() { _done = true; _capturing = false; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final isRegister = widget.mode == 'register';

    return UserShell(
      activeIndex: 2,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const SizedBox(height: 12),

          // Title
          Text('🤳 Face Enrolment', style: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w800, color: theme.textPrimary)),
          const SizedBox(height: 4),
          Text(
            isRegister
                ? 'Complete your registration by enrolling your face'
                : 'Update your face data for campus entry recognition',
            style: GoogleFonts.inter(fontSize: 13, color: theme.textTertiary),
            textAlign: TextAlign.center),
          const SizedBox(height: 28),

          if (_done)
            _buildSuccess(theme)
          else if (_capturing)
            _buildCapturing(theme)
          else
            _buildIntro(theme),
        ]),
      ),
    );
  }

  Widget _buildIntro(ThemeNotifier theme) => Column(children: [
    // Camera viewfinder mock
    Container(
      width: 280, height: 340,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(GeoRadius.lg),
        border: Border.all(color: GeoColors.primary.withOpacity(.4), width: 2)),
      child: Stack(children: [
        // Grid lines
        Positioned.fill(child: CustomPaint(painter: _ViewfinderPainter())),

        // Corner brackets
        ..._corners(),

        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(animation: _pulse, builder: (_, __) => Container(
            width: 140, height: 140,
            decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(
                color: GeoColors.primary.withOpacity(.3 + _pulse.value * .2),
                width: 2)),
            child: Center(child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: GeoColors.primary.withOpacity(.4), width: 1.5)),
              child: const Center(child: Text('😶', style: TextStyle(fontSize: 64))),
            )),
          )),
          const SizedBox(height: 20),
          Text('Position your face\nwithin the frame', style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(.7), height: 1.5),
            textAlign: TextAlign.center),
        ])),
      ]),
    ),
    const SizedBox(height: 28),

    // Instructions
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(GeoRadius.lg)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('📋 Instructions', style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary)),
        const SizedBox(height: 14),
        ...[
          '✅ Ensure good, even lighting on your face',
          '✅ Remove sunglasses, masks, or heavy accessories',
          '✅ Look directly at the camera',
          '✅ Keep a neutral or slight smile expression',
          '✅ 3 photos will be taken from slightly different angles',
        ].map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(s, style: GoogleFonts.inter(
            fontSize: 13, color: theme.textSecondary, height: 1.4)))),
      ])),
    const SizedBox(height: 20),

    // Start button
    SizedBox(width: double.infinity, child: ElevatedButton(
      onPressed: _startCapture,
      style: ElevatedButton.styleFrom(
        backgroundColor: GeoColors.primary, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GeoRadius.md))),
      child: Text('🤳 Start Face Capture', style: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w800)))),
    const SizedBox(height: 80),
  ]);

  Widget _buildCapturing(ThemeNotifier theme) {
    final steps = ['Capture 1 / 3', 'Capture 2 / 3', 'Capture 3 / 3', 'Processing…'];
    final currentStep = (_step - 1).clamp(0, steps.length - 1);

    return Column(children: [
      Container(
        width: 280, height: 340,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(GeoRadius.lg),
          border: Border.all(color: GeoColors.success.withOpacity(.7), width: 2)),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _ViewfinderPainter(green: true))),
          ..._corners(green: true),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(animation: _pulse, builder: (_, __) => Container(
              width: 140, height: 140,
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(
                  color: GeoColors.success.withOpacity(.4 + _pulse.value * .3), width: 2)),
              child: const Center(child: Text('😊', style: TextStyle(fontSize: 64))),
            )),
            const SizedBox(height: 16),
            Text(steps[currentStep], style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          ])),
        ]),
      ),
      const SizedBox(height: 24),

      // Progress steps
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
          borderRadius: BorderRadius.circular(GeoRadius.lg)),
        child: Column(children: List.generate(4, (i) {
          final done    = i < _step;
          final active  = i == _step - 1;
          final labels  = ['Taking photo 1…','Taking photo 2…','Taking photo 3…','Processing with AI…'];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: done ? GeoColors.success : active ? GeoColors.primary : theme.bgBadge,
                  border: Border.all(
                    color: done ? GeoColors.success : active ? GeoColors.primary : theme.border)),
                child: Center(child: done
                    ? const Text('✓', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700))
                    : active ? const SizedBox(width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('${i+1}', style: GoogleFonts.inter(fontSize: 12,
                        color: theme.textTertiary)))),
              const SizedBox(width: 14),
              Text(labels[i], style: GoogleFonts.inter(
                fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: done ? GeoColors.success : active ? theme.textPrimary : theme.textTertiary)),
            ]));
        })),
      ),
    ]);
  }

  Widget _buildSuccess(ThemeNotifier theme) => Column(children: [
    Container(
      width: 120, height: 120,
      decoration: const BoxDecoration(shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF15803D)],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: const Center(child: Text('✓', style: TextStyle(
        fontSize: 52, color: Colors.white, fontWeight: FontWeight.w900)))),
    const SizedBox(height: 24),

    Text('Face Data Enrolled!', style: GoogleFonts.inter(
      fontSize: 22, fontWeight: FontWeight.w800, color: GeoColors.success)),
    const SizedBox(height: 8),
    Text('Your face data has been securely stored.\nYou can now use facial recognition at campus gates.',
      style: GoogleFonts.inter(fontSize: 14, color: theme.textSecondary, height: 1.6),
      textAlign: TextAlign.center),
    const SizedBox(height: 28),

    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: GeoColors.successGhost,
        border: Border.all(color: GeoColors.success.withOpacity(.25)),
        borderRadius: BorderRadius.circular(GeoRadius.lg)),
      child: Column(children: [
        _successDetail(theme, '📸', '3 photos captured', 'Multi-angle coverage'),
        const SizedBox(height: 12),
        _successDetail(theme, '🔒', 'Encrypted & secured', 'AES-256 encrypted'),
        const SizedBox(height: 12),
        _successDetail(theme, '🤖', 'AI model updated', '128-dim face vector stored'),
      ])),
    const SizedBox(height: 28),

    SizedBox(width: double.infinity, child: ElevatedButton(
      onPressed: () => context.go('/user/profile'),
      style: ElevatedButton.styleFrom(
        backgroundColor: GeoColors.primary, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GeoRadius.md))),
      child: Text('← Back to Profile', style: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w800)))),
    const SizedBox(height: 80),
  ]);

  Widget _successDetail(ThemeNotifier theme, String icon, String title, String sub) =>
    Row(children: [
      Text(icon, style: const TextStyle(fontSize: 22)),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w700, color: theme.textPrimary)),
        Text(sub, style: GoogleFonts.inter(fontSize: 12, color: theme.textSecondary)),
      ]),
    ]);

  List<Widget> _corners({bool green = false}) {
    final color = green ? GeoColors.success : GeoColors.primary;
    return [
      Positioned(top: 16, left: 16, child: _corner(color, rotate: false)),
      Positioned(top: 16, right: 16, child: _corner(color, rotate: true)),
      Positioned(bottom: 16, left: 16, child: _corner(color, rotate: false, bottom: true)),
      Positioned(bottom: 16, right: 16, child: _corner(color, rotate: true, bottom: true)),
    ];
  }

  Widget _corner(Color color, {bool rotate = false, bool bottom = false}) =>
    Transform.rotate(
      angle: rotate ? (bottom ? 3.14159 * 1.5 : 3.14159 / 2) : (bottom ? 3.14159 / 2 * 3 : 0),
      child: SizedBox(width: 20, height: 20,
        child: CustomPaint(painter: _CornerPainter(color))));
}

// ── PAINTERS ─────────────────────────────────────────────────────────────
class _ViewfinderPainter extends CustomPainter {
  final bool green;
  const _ViewfinderPainter({this.green = false});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (green ? Colors.green : Colors.red).withOpacity(.05)
      ..strokeWidth = .5;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
  }
  @override bool shouldRepaint(_) => false;
}
