import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/common_widgets.dart';

class SecurityThreatsScreen extends StatefulWidget {
  const SecurityThreatsScreen({super.key});
  @override
  State<SecurityThreatsScreen> createState() => _SecurityThreatsScreenState();
}

class _SecurityThreatsScreenState extends State<SecurityThreatsScreen> {
  final _rng = Random();
  Timer? _simTimer;
  _ThreatItem? _selected;
  List<_ThreatItem> _threats = [];

  static const _templates = [
    ['🚫', 'Unknown face detected', 'Unauthorized Access'],
    ['🚷', 'Blacklisted individual spotted', 'Blacklisted Individual'],
    ['🚶', 'Tailgating detected', 'Tailgating'],
    ['📵', 'Curfew violation', 'Curfew Breach'],
    ['🔍', 'Low confidence match', 'Low Confidence Scan'],
  ];

  static const _templateGates = [
    ['North Gate', 'East Entrance', 'Main Gate'],
    ['East Entrance', 'Admin Block', 'Library'],
    ['Library Entrance', 'Lab Block', 'Cafeteria'],
    ['Hostel Block A', 'Block D', 'Sports Complex'],
    ['Main Gate', 'North Gate', 'East Entrance'],
  ];

  static const _guards = [
    {
      'name': 'Rajan Kumar',
      'id': 'GRD-001',
      'zone': 'North Campus',
      'init': 'RK',
      'eta': '~2 min'
    },
    {
      'name': 'Suresh Patil',
      'id': 'GRD-002',
      'zone': 'East Zone',
      'init': 'SP',
      'eta': '~4 min'
    },
    {
      'name': 'Vikram Singh',
      'id': 'GRD-003',
      'zone': 'Main Gate',
      'init': 'VS',
      'eta': '~1 min'
    },
  ];

  static const _pieData = [
    ['Unauthorized Access', '#dc2626', 2],
    ['Tailgating', '#f59e0b', 2],
    ['Low Confidence', '#6366f1', 2],
    ['Blacklisted', '#7c3aed', 1],
    ['Curfew Breach', '#0891b2', 1],
  ];

  @override
  void initState() {
    super.initState();
    _threats = [
      _make(0, 'Critical', 'Active'),
      _make(1, 'Critical', 'Active'),
      _make(2, 'Medium', 'Resolving'),
      _make(3, 'High', 'Resolving'),
      _make(4, 'Low', 'Active'),
    ];
    _startSim();
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    super.dispose();
  }

  _ThreatItem _make(int tpl, String sev, String status) {
    final gates = _templateGates[tpl % _templateGates.length];
    return _ThreatItem(
      icon: _templates[tpl][0],
      title: _templates[tpl][1],
      type: _templates[tpl][2],
      gate: gates[_rng.nextInt(gates.length)],
      severity: sev,
      status: status,
      time: DateTime.now(),
    );
  }

  void _startSim() {
    final delay = 12000 + _rng.nextInt(15000);
    _simTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      final tpl = _rng.nextInt(_templates.length);
      final severities = ['Low', 'Medium', 'High', 'Critical'];
      final sev = severities[_rng.nextInt(severities.length)];
      setState(() {
        _threats.insert(0, _make(tpl, sev, 'Active'));
        if (_threats.length > 15) _threats.removeLast();
      });
      _startSim();
    });
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.trim().replaceAll('#', '0xFF')));
    } catch (_) {
      return GeoColors.primary;
    }
  }

  Color _sevColor(String sev) => switch (sev) {
        'Critical' => GeoColors.danger,
        'High' => GeoColors.warning,
        'Medium' => const Color(0xFF6366F1),
        _ => const Color(0xFF888888),
      };

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final active = _threats.where((t) => t.status == 'Active').length;
    final resolving = _threats.where((t) => t.status == 'Resolving').length;
    final resolved = _threats.where((t) => t.status == 'Resolved').length;

    return AdminShell(
      activeRoute: '/admin/threats',
      breadcrumb: 'Security Threats',
      pageTitle: 'Security Threats',
      topbarActions: [
        const LiveBadge(),
        const SizedBox(width: 8),
        _topBtn('⬇ Export', theme),
        const SizedBox(width: 8),
        _topBtn('↺ Refresh', theme),
      ],
      body: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Security Threats',
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary)),
            const SizedBox(height: 4),
            Text('Real-time monitoring of all campus security incidents.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: theme.textSecondary)),
            const SizedBox(height: 20),

            // Top section: pie + stats
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Pie card
              Container(
                width: 320,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: theme.bgCard,
                    border: Border.all(color: theme.border),
                    borderRadius: BorderRadius.circular(GeoRadius.lg)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📊 Threat Breakdown',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.textPrimary)),
                      const SizedBox(height: 18),
                      Center(
                          child: SizedBox(
                              width: 200,
                              height: 200,
                              child: Stack(children: [
                                CustomPaint(
                                    size: const Size(200, 200),
                                    painter: _PiePainter(_pieData)),
                                Center(
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                      Text('8',
                                          style: GoogleFonts.inter(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w800,
                                              color: theme.textPrimary)),
                                      Text('Total',
                                          style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: theme.textTertiary)),
                                    ])),
                              ]))),
                      const SizedBox(height: 16),
                      ..._pieData
                          .map((d) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(children: [
                                  Container(
                                      width: 10,
                                      height: 10,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                          color: _hexColor(d[1] as String),
                                          shape: BoxShape.circle)),
                                  Expanded(
                                      child: Text(d[0] as String,
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: theme.textPrimary))),
                                  Text('${d[2]}',
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: theme.textPrimary)),
                                ]),
                              ))
                          .toList(),
                    ]),
              ),
              const SizedBox(width: 20),

              // Stats right
              Expanded(
                  child: Column(children: [
                Row(children: [
                  Expanded(
                      child: StatCard(
                          theme: theme,
                          icon: '🚨',
                          value: '$active',
                          label: 'Active Threats',
                          trend: '▲ 2',
                          trendUp: false,
                          iconBg: GeoColors.dangerGhost)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: StatCard(
                          theme: theme,
                          icon: '⏳',
                          value: '$resolving',
                          label: 'Being Resolved',
                          iconBg: GeoColors.warningGhost)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: StatCard(
                          theme: theme,
                          icon: '✓',
                          value: '$resolved',
                          label: 'Resolved Today',
                          trend: '▲ 3',
                          trendUp: true,
                          iconBg: GeoColors.successGhost)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: StatCard(
                          theme: theme,
                          icon: '🔒',
                          value: '12',
                          label: 'Guards On Duty')),
                ]),
                const SizedBox(height: 12),
                // Recent resolutions
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: theme.bgCard,
                        border: Border.all(color: theme.border),
                        borderRadius: BorderRadius.circular(GeoRadius.lg)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('⏱ Recent Resolutions',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: theme.textPrimary)),
                          const SizedBox(height: 12),
                          _recentRes(theme, 'Tailgating — Library · 09:15 AM'),
                          _recentRes(
                              theme, 'Unknown Face — North Entry · 08:32 AM'),
                          _recentRes(
                              theme, 'Curfew breach — Block D · 11:22 PM'),
                        ])),
              ])),
            ]),
            const SizedBox(height: 20),

            // Threat list
            Container(
              decoration: BoxDecoration(
                  color: theme.bgCard,
                  border: Border.all(color: theme.border),
                  borderRadius: BorderRadius.circular(GeoRadius.lg)),
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(children: [
                      Text('⚠️ Active Threats',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.textPrimary)),
                      const SizedBox(width: 10),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                              color: GeoColors.dangerGhost,
                              borderRadius:
                                  BorderRadius.circular(GeoRadius.full)),
                          child: Text('$active Active',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: GeoColors.danger))),
                    ])),
                // Header row
                Container(
                    color: theme.bgBadge,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(children: [
                      _th(theme, '', 40),
                      _th(theme, 'Incident', 0, flex: true),
                      _th(theme, 'Time', 90),
                      _th(theme, 'Severity', 90),
                      _th(theme, 'Status', 100),
                      _th(theme, 'Action', 100),
                    ])),
                Divider(height: 1, color: theme.border),

                ..._threats.map((t) => _threatRow(theme, t)),
              ]),
            ),
          ]),
        ),

        // Detail panel
        if (_selected != null) ...[
          GestureDetector(
              onTap: () => setState(() => _selected = null),
              child: Container(color: Colors.black.withOpacity(.35))),
          Positioned(
              right: 0, top: 0, bottom: 0, child: _buildDetailPanel(theme)),
        ],
      ]),
    );
  }

  Widget _recentRes(ThemeNotifier theme, String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
                color: GeoColors.success, shape: BoxShape.circle)),
        Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.textPrimary))),
        Text('✓ Resolved',
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: GeoColors.success)),
      ]));

  Widget _th(ThemeNotifier theme, String label, double w, {bool flex = false}) {
    final child = Text(label.toUpperCase(),
        style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: theme.textTertiary,
            letterSpacing: .5));
    return flex ? Expanded(child: child) : SizedBox(width: w, child: child);
  }

  Widget _threatRow(ThemeNotifier theme, _ThreatItem t) {
    final sevColor = _sevColor(t.severity);
    final statusBg = t.status == 'Active'
        ? GeoColors.dangerGhost
        : t.status == 'Resolving'
            ? GeoColors.warningGhost
            : GeoColors.successGhost;
    final statusFg = t.status == 'Active'
        ? GeoColors.danger
        : t.status == 'Resolving'
            ? GeoColors.warning
            : GeoColors.success;
    final time =
        '${t.time.hour.toString().padLeft(2, '0')}:${t.time.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.border))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          SizedBox(
              width: 40,
              child: Text(t.icon, style: const TextStyle(fontSize: 22))),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(t.title,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary)),
                Text('📍 ${t.gate} · $time',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: theme.textTertiary)),
              ])),
          SizedBox(
              width: 90,
              child: Text(time,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: theme.textSecondary))),
          SizedBox(
              width: 90,
              child: Text(t.severity,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sevColor))),
          SizedBox(
              width: 100,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(GeoRadius.full)),
                  child: Text(t.status,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusFg)))),
          SizedBox(
              width: 100,
              child: GestureDetector(
                  onTap: () => setState(() => _selected = t),
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                          color: GeoColors.primary,
                          borderRadius: BorderRadius.circular(GeoRadius.sm)),
                      child: Text('🔍 Track',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white))))),
        ]),
      ),
    );
  }

  // ── DETAIL PANEL ──────────────────────────────────────────────────────
  Widget _buildDetailPanel(ThemeNotifier theme) {
    final t = _selected!;
    return Container(
      width: 520,
      color: theme.bgCard,
      child: Column(children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.border))),
            child: Row(children: [
              Expanded(
                  child: Text('${t.icon} ${t.type}',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary))),
              GestureDetector(
                  onTap: () => setState(() => _selected = null),
                  child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: theme.bgBadge, shape: BoxShape.circle),
                      child: Center(
                          child: Text('✕',
                              style: GoogleFonts.inter(
                                  fontSize: 16, color: theme.textPrimary))))),
            ])),
        Expanded(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _panelSectionTitle(theme, 'INCIDENT INFORMATION'),
            _detailRow(theme, 'Location', '📍 ${t.gate}'),
            _detailRow(theme, 'Time Detected',
                '${t.time.hour.toString().padLeft(2, "0")}:${t.time.minute.toString().padLeft(2, "0")}'),
            _detailRow(theme, 'Severity', t.severity),
            _detailRow(theme, 'Verified Status', '⏳ Pending Verification'),
            _detailRow(theme, 'Assigned Guard',
                '${_guards[0]['name']} · +91 98001 11111'),
            const SizedBox(height: 20),
            _panelSectionTitle(theme, '📍 THREAT LOCATION MAP'),
            Container(
                height: 200,
                decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(GeoRadius.md),
                    border: Border.all(color: theme.border)),
                child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🗺️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text('Map: ${t.gate}',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('Lat: 12.91°N  Lng: 77.52°E',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.white38)),
                ]))),
            const SizedBox(height: 20),
            _panelSectionTitle(theme, '👮 NEARBY SECURITY GUARDS'),
            ..._guards.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                              colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)])),
                      child: Center(
                          child: Text(g['init']!,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('${g['name']} ${g['id']}',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.textPrimary)),
                        Text('📍 ${g['zone']}',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: theme.textTertiary)),
                      ])),
                  Text('🏃 ${g['eta']}',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: GeoColors.success)),
                ]))),
          ]),
        )),
      ]),
    );
  }

  Widget _panelSectionTitle(ThemeNotifier theme, String title) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.textTertiary,
              letterSpacing: .8)));

  Widget _detailRow(ThemeNotifier theme, String key, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(key,
            style: GoogleFonts.inter(fontSize: 12, color: theme.textTertiary)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary)),
      ]));

  Widget _topBtn(String label, ThemeNotifier theme) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
          color: theme.bgCard,
          border: Border.all(color: theme.border),
          borderRadius: BorderRadius.circular(GeoRadius.sm)),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.textSecondary)));
}

class _ThreatItem {
  final String icon, title, type, gate, severity, status;
  final DateTime time;
  const _ThreatItem(
      {required this.icon,
      required this.title,
      required this.type,
      required this.gate,
      required this.severity,
      required this.status,
      required this.time});
}

// ── PIE CHART PAINTER ─────────────────────────────────────────────────────
class _PiePainter extends CustomPainter {
  final List<dynamic> data;
  const _PiePainter(this.data);

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.trim().replaceAll('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold<int>(0, (s, d) => s + (d[2] as int));
    final cx = size.width / 2, cy = size.height / 2, r = size.width / 2 - 4;
    double start = -3.14159 / 2;

    for (final d in data) {
      final sweep = (d[2] as int) / total * 2 * 3.14159;
      final paint = Paint()
        ..color = _hexColor(d[1] as String)
        ..style = PaintingStyle.fill;
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start,
          sweep, true, paint);
      start += sweep;
    }
    // Donut hole
    canvas.drawCircle(
        Offset(cx, cy),
        r * 0.56,
        Paint()
          ..color = const Color(0xFF1A1A1A)
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_) => false;
}
