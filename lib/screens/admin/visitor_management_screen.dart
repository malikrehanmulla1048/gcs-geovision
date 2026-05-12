import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/common_widgets.dart';

class VisitorManagementScreen extends StatefulWidget {
  const VisitorManagementScreen({super.key});
  @override
  State<VisitorManagementScreen> createState() => _VisitorManagementScreenState();
}

class _VisitorManagementScreenState extends State<VisitorManagementScreen> {
  final _rng = Random();
  final List<_Visitor> _visitors = [];

  static const _colors = ['#7c3aed','#2563eb','#0891b2','#059669','#d97706','#e11d48'];
  static const _gates  = ['Main Gate','East Entrance','North Gate','Admin Block Entry'];

  @override
  void initState() {
    super.initState();
    _seedVisitors();
  }

  void _seedVisitors() {
    final seeds = [
      ['Ramesh Kumar',  '+91 98001 11111','Meeting Faculty', 'Dr. Ravi Shankar',    'CS Dept',   'KA-DL-2021-0001234','On Campus'],
      ['Ananya Shah',   '+91 98001 22222','Parent Visit',    'Admin Office',        'Admin Block','MH-5432109876',     'On Campus'],
      ['Courier Exec',  '+91 98001 33333','Delivery',        'Admin Block',         'Admin Block','CORP-DELIVERY-001', 'On Campus'],
      ['Dr. Jha',       '+91 98001 44444','Guest Lecture',   'Prof. Meenakshi Iyer','EC Dept',   'GOV-GJ-19875432',   'On Campus'],
      ['Vijay Thomas',  '+91 98001 55555','Maintenance',     'Facilities',          'Lab Block', 'MAINT-2024-007',    'Exited'],
    ];
    for (final s in seeds) {
      final name = s[0];
      final initials = name.split(' ').take(2).map((w) => w[0]).join().toUpperCase();
      _visitors.add(_Visitor(
        id: _visitors.length + 1,
        name: name, phone: s[1], purpose: s[2], host: s[3], dept: s[4], idnum: s[5],
        status: s[6], gate: _gates[_rng.nextInt(_gates.length)],
        checkinAt: DateTime.now(), initials: initials,
        color: _colors[_visitors.length % _colors.length],
      ));
    }
  }

  Color _hexColor(String hex) {
    try { return Color(int.parse(hex.trim().replaceAll('#', '0xFF'))); }
    catch (_) { return GeoColors.primary; }
  }

  int get _active   => _visitors.where((v) => v.status == 'On Campus').length;
  int get _exited   => _visitors.where((v) => v.status == 'Exited').length;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();

    return AdminShell(
      activeRoute: '/admin/visitors',
      breadcrumb: 'Visitor Management',
      pageTitle: 'Visitor Management',
      topbarActions: [
        _topBtn('⬇ Export Log', theme),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Visitor Management', style: GoogleFonts.inter(
            fontSize: 22, fontWeight: FontWeight.w800, color: theme.textPrimary)),
          const SizedBox(height: 4),
          Text('Register new visitors, monitor active guests, and track their location.',
            style: GoogleFonts.inter(fontSize: 13, color: theme.textSecondary)),
          const SizedBox(height: 20),

          // Stats
          Row(children: [
            Expanded(child: StatCard(theme: theme, icon: '🪪',
              value: '$_active', label: 'On Campus Now',
              trend: '▲ Today', trendUp: true, iconBg: GeoColors.successGhost)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(theme: theme, icon: '📋',
              value: '${_visitors.length}', label: 'Total Visitors Today')),
            const SizedBox(width: 12),
            Expanded(child: StatCard(theme: theme, icon: '⏳',
              value: '0', label: 'Awaiting Check-in', iconBg: GeoColors.warningGhost)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(theme: theme, icon: '🚪',
              value: '$_exited', label: 'Exited Today',
              trend: '▼ Today', trendUp: false, iconBg: GeoColors.dangerGhost)),
          ]),
          const SizedBox(height: 24),

          // Add visitor + map row
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Add visitor card
            Expanded(child: Container(
              height: 380,
              decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(GeoRadius.lg)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('🪪', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 18),
                Text('Visitor Enrolment', style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700, color: theme.textPrimary)),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Register a new visitor, capture their details and facial data securely.',
                    style: GoogleFonts.inter(fontSize: 13, color: theme.textSecondary),
                    textAlign: TextAlign.center)),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => GeoToast.show(context, 'Visitor registration form coming soon', type: 'info'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                    decoration: BoxDecoration(color: GeoColors.primary,
                      borderRadius: BorderRadius.circular(GeoRadius.md)),
                    child: Text('✚ Add Visitor', style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)))),
              ])),
            ),
            const SizedBox(width: 24),

            // Live tracker map placeholder
            Expanded(child: Container(
              height: 380,
              decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(GeoRadius.lg)),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.border))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('📍 Live Visitor Tracker', style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary)),
                    Text('🟠 Visitors on campus   🔵 Security guards',
                      style: GoogleFonts.inter(fontSize: 12, color: theme.textTertiary)),
                  ])),
                Expanded(child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(GeoRadius.lg)),
                  child: Stack(children: [
                    // Simulated map background
                    Positioned.fill(child: CustomPaint(painter: _MapPainter(theme))),
                    // Visitor dots
                    ..._visitors.where((v) => v.status != 'Exited').map((v) {
                      final dx = 80.0 + _rng.nextInt(200);
                      final dy = 60.0 + _rng.nextInt(200);
                      return Positioned(left: dx, top: dy, child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316), shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(color: Colors.orange.withOpacity(.5), blurRadius: 8)]),
                        child: Center(child: Text(v.initials, style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)))));
                    }),
                    // Guard dots
                    ...List.generate(3, (i) => Positioned(
                      left: 50.0 + i * 120, top: 150.0,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB), shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                        child: Center(child: Text('G', style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white))))),
                    ),
                  ])))
              ]))),
          ]),
          const SizedBox(height: 24),

          // Active visitors table
          Container(
            decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
              borderRadius: BorderRadius.circular(GeoRadius.lg)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Text('👥 Active Visitors', style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: theme.bgBadge, borderRadius: BorderRadius.circular(GeoRadius.full)),
                    child: Text('$_active Active, ${_visitors.length} Total',
                      style: GoogleFonts.inter(fontSize: 11, color: theme.textSecondary))),
                ])),
              Divider(height: 1, color: theme.border),

              // Table header
              Container(
                color: theme.bgBadge,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  _th(theme, '#', 40), _th(theme, 'Visitor', 180),
                  _th(theme, 'Purpose', 130), _th(theme, 'Host', 150),
                  _th(theme, 'Check-in', 100), _th(theme, 'Gate', 130),
                  _th(theme, 'Status', 100), _th(theme, 'Action', 100),
                ])),
              Divider(height: 1, color: theme.border),

              ..._visitors.asMap().entries.map((e) {
                final v = e.value;
                final statusBg = v.status == 'On Campus' ? GeoColors.successGhost
                    : v.status == 'Checking In' ? GeoColors.warningGhost : theme.bgBadge;
                final statusFg = v.status == 'On Campus' ? GeoColors.success
                    : v.status == 'Checking In' ? GeoColors.warning : theme.textTertiary;
                final timeStr = '${v.checkinAt.hour.toString().padLeft(2,'0')}:${v.checkinAt.minute.toString().padLeft(2,'0')}';
                return Container(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.border))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      SizedBox(width: 40, child: Text((e.key+1).toString().padLeft(2,'0'),
                        style: GoogleFonts.inter(fontSize: 12, color: theme.textTertiary, fontWeight: FontWeight.w600))),
                      SizedBox(width: 180, child: Row(children: [
                        Container(width: 36, height: 36, decoration: BoxDecoration(
                          shape: BoxShape.circle, color: _hexColor(v.color)),
                          child: Center(child: Text(v.initials, style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(v.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary), overflow: TextOverflow.ellipsis),
                          Text(v.idnum, style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary)),
                        ])),
                      ])),
                      SizedBox(width: 130, child: Text(v.purpose, style: GoogleFonts.inter(fontSize: 13, color: theme.textPrimary), overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 150, child: Text(v.host, style: GoogleFonts.inter(fontSize: 13, color: theme.textPrimary), overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 100, child: Text(timeStr, style: GoogleFonts.inter(fontSize: 12, color: theme.textPrimary))),
                      SizedBox(width: 130, child: Text('📍 ${v.gate}', style: GoogleFonts.inter(fontSize: 13, color: theme.textPrimary), overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 100, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(GeoRadius.full)),
                        child: Text(v.status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: statusFg)))),
                      SizedBox(width: 100, child: v.status != 'Exited'
                        ? GestureDetector(
                            onTap: () => setState(() => v.status = 'Exited'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(border: Border.all(color: GeoColors.dangerGhost),
                                borderRadius: BorderRadius.circular(GeoRadius.sm)),
                              child: Text('Check Out', style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.w600, color: GeoColors.danger))))
                        : Text('Checked out', style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary))),
                    ]),
                  ),
                );
              }),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _th(ThemeNotifier theme, String label, double w) => SizedBox(
    width: w, child: Text(label.toUpperCase(), style: GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w700, color: theme.textTertiary, letterSpacing: .5)));

  Widget _topBtn(String label, ThemeNotifier theme) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
      borderRadius: BorderRadius.circular(GeoRadius.sm)),
    child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: theme.textSecondary)));
}

class _Visitor {
  final int id;
  final String name, phone, purpose, host, dept, idnum, gate, initials, color;
  String status;
  final DateTime checkinAt;
  _Visitor({required this.id, required this.name, required this.phone,
    required this.purpose, required this.host, required this.dept,
    required this.idnum, required this.status, required this.gate,
    required this.checkinAt, required this.initials, required this.color});
}

class _MapPainter extends CustomPainter {
  final ThemeNotifier theme;
  const _MapPainter(this.theme);
  @override
  void paint(Canvas canvas, Size size) {
    // Simple grid map background
    final bg = Paint()..color = const Color(0xFF1A1A2E);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);
    final grid = Paint()..color = Colors.white.withOpacity(.05)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    // Campus boundary
    final boundary = Paint()..color = Colors.white.withOpacity(.08)
      ..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(30, 30, size.width - 60, size.height - 60),
      const Radius.circular(8)), boundary);
    // Roads
    final road = Paint()..color = Colors.white.withOpacity(.04)..strokeWidth = 8;
    canvas.drawLine(Offset(size.width/2, 30), Offset(size.width/2, size.height - 30), road);
    canvas.drawLine(Offset(30, size.height/2), Offset(size.width - 30, size.height/2), road);
  }
  @override bool shouldRepaint(_) => false;
}
