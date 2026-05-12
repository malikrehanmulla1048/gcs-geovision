import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/common_widgets.dart';

class CctvFeedScreen extends StatefulWidget {
  const CctvFeedScreen({super.key});
  @override
  State<CctvFeedScreen> createState() => _CctvFeedScreenState();
}

class _CctvFeedScreenState extends State<CctvFeedScreen> {
  String? _fullscreenAsset;
  String? _fullscreenLabel;

  static const _cameras = [
    ['assets/cctv_main_gate.png',  '📍 Main Gate',      'CAM-01', 'false'],
    ['assets/cctv_library.png',    '📍 Library',        'CAM-02', 'false'],
    ['assets/cctv_lobby.png',      '📍 Admin Block',    'CAM-05', 'false'],
    ['assets/cctv_parking.png',    '📍 Sports Complex', 'CAM-09', 'true'],
    ['assets/cctv_main_gate.png',  '📍 East Entrance',  'CAM-03', 'false'],
    ['assets/cctv_library.png',    '📍 Lab Block',      'CAM-04', 'false'],
    ['assets/cctv_lobby.png',      '📍 Cafeteria',      'CAM-06', 'false'],
    ['assets/cctv_main_gate.png',  '📍 North Gate',     'CAM-07', 'false'],
    ['assets/cctv_library.png',    '📍 South Wing',     'CAM-08', 'false'],
    ['assets/cctv_lobby.png',      '📍 Hostel A',       'CAM-10', 'false'],
    ['assets/cctv_parking.png',    '📍 Hostel B',       'CAM-11', 'true'],
    ['assets/cctv_main_gate.png',  '📍 Reception',      'CAM-12', 'false'],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    return AdminShell(
      activeRoute: '/admin/cctv',
      breadcrumb: 'CCTV Feed',
      pageTitle: 'CCTV Feed',
      body: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Live CCTV Feed', style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w800, color: theme.textPrimary)),
            const SizedBox(height: 4),
            Row(children: [
              Text('All campus surveillance cameras — ',
                style: GoogleFonts.inter(fontSize: 13, color: theme.textSecondary)),
              const LiveBadge(),
            ]),
            const SizedBox(height: 20),
            // Stats
            Row(children: [
              _stat(theme, '11', 'Online'),
              const SizedBox(width: 12),
              _stat(theme, '1', 'Offline'),
              const SizedBox(width: 12),
              _stat(theme, '12', 'Total'),
              const SizedBox(width: 12),
              _stat(theme, '92%', 'Network Health'),
            ]),
            const SizedBox(height: 24),
            // Grid
            Container(
              decoration: BoxDecoration(
                color: theme.bgCard, border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(GeoRadius.lg)),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Text('📹 Surveillance Grid', style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: theme.bgBadge,
                        borderRadius: BorderRadius.circular(GeoRadius.full)),
                      child: Text('Tap to expand', style: GoogleFonts.inter(
                        fontSize: 11, color: theme.textSecondary))),
                  ])),
                Divider(height: 1, color: theme.border),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, crossAxisSpacing: 14, mainAxisSpacing: 14,
                      childAspectRatio: 16 / 9),
                    itemCount: _cameras.length,
                    itemBuilder: (_, i) {
                      final cam = _cameras[i];
                      final offline = cam[3] == 'true';
                      final label = '${cam[1]} — ${cam[2]}';
                      return GestureDetector(
                        onTap: () => setState(() {
                          _fullscreenAsset = cam[0]; _fullscreenLabel = label;
                        }),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(GeoRadius.md),
                          child: Stack(children: [
                            Positioned.fill(child: Image.asset(
                              cam[0], fit: BoxFit.cover,
                              color: offline ? Colors.black.withOpacity(.7) : null,
                              colorBlendMode: offline ? BlendMode.darken : null,
                              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF111111),
                                child: Center(child: Text(offline ? '📵' : '📹',
                                  style: const TextStyle(fontSize: 24)))))),
                            // Scan lines
                            Positioned.fill(child: CustomPaint(painter: _ScanLinePainter())),
                            // Status
                            Positioned(top: 8, left: 8, child: offline
                              ? Text('OFFLINE', style: GoogleFonts.inter(
                                  fontSize: 8, fontWeight: FontWeight.w700, color: const Color(0xFF888888)))
                              : Row(children: [
                                  const LiveDot(), const SizedBox(width: 4),
                                  Text('LIVE', style: GoogleFonts.inter(
                                    fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                                ])),
                            // Label bar
                            Positioned(bottom: 0, left: 0, right: 0, child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: const BoxDecoration(gradient: LinearGradient(
                                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                colors: [Color(0xD9000000), Colors.transparent])),
                              child: Text(label, style: GoogleFonts.inter(
                                fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)))),
                          ]),
                        ),
                      );
                    }),
                ),
              ]),
            ),
          ]),
        ),
        // Fullscreen overlay
        if (_fullscreenAsset != null) _buildModal(theme),
      ]),
    );
  }

  Widget _stat(ThemeNotifier theme, String val, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(GeoRadius.lg)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(val, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: theme.textPrimary)),
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: theme.textSecondary)),
      ])));

  Widget _buildModal(ThemeNotifier theme) => GestureDetector(
    onTap: () => setState(() { _fullscreenAsset = null; _fullscreenLabel = null; }),
    child: Container(
      color: Colors.black.withOpacity(.9),
      child: Center(child: GestureDetector(
        onTap: () {},
        child: Container(
          width: MediaQuery.of(context).size.width * .9,
          height: MediaQuery.of(context).size.height * .85,
          decoration: BoxDecoration(color: Colors.black,
            borderRadius: BorderRadius.circular(GeoRadius.lg),
            border: Border.all(color: theme.border)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GeoRadius.lg),
            child: Stack(children: [
              Positioned.fill(child: Image.asset(_fullscreenAsset!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('📹', style: TextStyle(fontSize: 64))))),
              Positioned.fill(child: CustomPaint(painter: _ScanLinePainter())),
              Positioned(top: 20, left: 20, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.7),
                  borderRadius: BorderRadius.circular(GeoRadius.md),
                  border: Border.all(color: Colors.white.withOpacity(.1))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_fullscreenLabel ?? '', style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(width: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: GeoColors.dangerGhost,
                      borderRadius: BorderRadius.circular(GeoRadius.sm)),
                    child: Text('LIVE', style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: GeoColors.danger, letterSpacing: 1))),
                ]))),
              Positioned(top: 20, right: 20, child: GestureDetector(
                onTap: () => setState(() { _fullscreenAsset = null; _fullscreenLabel = null; }),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.black.withOpacity(.7),
                    border: Border.all(color: Colors.white.withOpacity(.1))),
                  child: const Center(child: Text('✕',
                    style: TextStyle(fontSize: 20, color: Colors.white)))))),
            ]),
          ),
        ),
      )),
    ),
  );
}

class _ScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(.15)..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 2) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}
