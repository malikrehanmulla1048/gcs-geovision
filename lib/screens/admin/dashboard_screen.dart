import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/db_service.dart';
import '../../models/entry_log.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/common_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db  = DbService();
  final _rng = Random();
  Timer? _feedTimer;
  Timer? _clockTimer;

  int _entryCount = 247;
  DateTime _now   = DateTime.now();

  // Live feed items (last 6)
  final List<_FeedItem> _feed      = [];
  final List<_ScanItem> _scans     = [];
  final List<double>    _confValues = [];
  double _avgConf = 96.3;

  static const _gates = DbService.gates;
  static const _people = DbService.people;

  @override
  void initState() {
    super.initState();
    _seedFeed();
    _startLiveSim();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _feedTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _seedFeed() {
    final seeds = [
      ('entry', 0), ('entry', 1), ('entry', 2), ('exit', 3), ('entry', 4),
    ];
    for (final (type, idx) in seeds.reversed) {
      _addToFeed(type, idx);
    }
  }

  void _startLiveSim() {
    final delay = 4000 + _rng.nextInt(3000);
    _feedTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      _simulateLiveEvent();
      _startLiveSim();
    });
  }

  void _simulateLiveEvent() {
    final idx  = _rng.nextInt(_people.length);
    final r    = _rng.nextDouble();
    String type;
    if (r < .65)      type = 'entry';
    else if (r < .9)  type = 'exit';
    else               type = 'denied';

    setState(() {
      _addToFeed(type, idx);
      if (type == 'entry') _entryCount++;
    });
  }

  void _addToFeed(String type, int personIdx) {
    final p    = _people[personIdx % _people.length];
    final conf = type == 'denied'
        ? 55 + _rng.nextDouble() * 25
        : 85 + _rng.nextDouble() * 14.9;

    _confValues.add(conf);
    if (_confValues.length > 20) _confValues.removeAt(0);
    _avgConf = _confValues.reduce((a, b) => a + b) / _confValues.length;

    _feed.insert(0, _FeedItem(
      name:     p['name']!,
      id:       p['id']!,
      initials: p['initials']!,
      colors:   p['color']!.split(','),
      gate:     _gates[_rng.nextInt(_gates.length)],
      time:     DateTime.now(),
      conf:     conf,
      type:     type,
    ));
    if (_feed.length > 6) _feed.removeLast();

    _scans.insert(0, _ScanItem(
      name:     p['name']!,
      initials: p['initials']!,
      colors:   p['color']!.split(','),
      gate:     _gates[_rng.nextInt(_gates.length)],
      time:     DateTime.now(),
      conf:     85 + _rng.nextDouble() * 15,
    ));
    if (_scans.length > 5) _scans.removeLast();
  }

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}:${d.second.toString().padLeft(2,'0')}';

  String _fmtDate(DateTime d) {
    const days = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[d.weekday % 7]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();

    return AdminShell(
      activeRoute: '/admin/dashboard',
      breadcrumb:  'Dashboard',
      pageTitle:   'Security Command Centre',
      topbarActions: [
        _topbarBtn('⬇ Export', theme),
        const SizedBox(width: 8),
        _topbarBtn('↺ Refresh', theme),
      ],
      rightPanel: _buildRightPanel(theme),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Page title
          Text('Security Command Centre', style: GoogleFonts.inter(
            fontSize: 22, fontWeight: FontWeight.w800, color: theme.textPrimary, letterSpacing: -.3,
          )),
          const SizedBox(height: 4),
          Text('Real-time overview of campus security, entries, threats, and system health.',
            style: GoogleFonts.inter(fontSize: 13, color: theme.textSecondary)),
          const SizedBox(height: 16),

          // Stats
          _buildStatsGrid(theme),
          const SizedBox(height: 16),

          // 2-column: threats + feed
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _buildThreatAlerts(theme)),
            const SizedBox(width: 20),
            Expanded(child: _buildLiveFeed(theme)),
          ]),
          const SizedBox(height: 20),

          // CCTV preview
          _buildCctvSection(theme),
          const SizedBox(height: 20),

          // System health
          _buildSystemHealth(theme),
        ]),
      ),
    );
  }

  Widget _topbarBtn(String label, ThemeNotifier theme) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: theme.bgCard,
      border: Border.all(color: theme.border),
      borderRadius: BorderRadius.circular(GeoRadius.sm),
    ),
    child: Text(label, style: GoogleFonts.inter(
      fontSize: 12, fontWeight: FontWeight.w500, color: theme.textSecondary,
    )),
  );

  // ── STATS GRID ────────────────────────────────────────────────────────
  Widget _buildStatsGrid(ThemeNotifier theme) => Row(children: [
    Expanded(child: StatCard(
      theme: theme, icon: '🚪',
      value: _entryCount.toString(),
      label: 'Total Entries Today',
      trend: '▲ 12%', trendUp: true,
    )),
    const SizedBox(width: 12),
    Expanded(child: StatCard(
      theme: theme, icon: '🚨',
      value: '3', label: 'Active Threats',
      trend: '▲ 3 New', trendUp: false,
      iconBg: GeoColors.dangerGhost, iconColor: GeoColors.danger,
    )),
    const SizedBox(width: 12),
    Expanded(child: StatCard(
      theme: theme, icon: '📹',
      value: '11', label: 'Active Cameras',
      trend: '11/12',
    )),
    const SizedBox(width: 12),
    Expanded(child: StatCard(
      theme: theme, icon: '👥',
      value: '1,842', label: 'Registered Profiles',
      trend: '▲ 8 New', trendUp: true,
      iconBg: GeoColors.successGhost,
    )),
  ]);

  // ── THREAT ALERTS ─────────────────────────────────────────────────────
  Widget _buildThreatAlerts(ThemeNotifier theme) => SectionCard(
    theme: theme,
    title: '⚠️ Threat Alerts',
    count: '3 Active', redCount: true,
    linkLabel: 'View All →',
    onLink: () => context.go('/admin/threats'),
    child: Column(children: [
      _alertItem(theme, '🚫', 'Unknown face — North Gate',
          '📍 Gate 1 · 09:42 AM · No match in database', 'Critical', true),
      const SizedBox(height: 10),
      _alertItem(theme, '🚷', 'Blacklisted individual — East Entrance',
          '📍 Gate 3 · 10:15 AM · ID: BL-00499', 'Critical', true),
      const SizedBox(height: 10),
      _alertItem(theme, '🚶', 'Tailgating — Library Entrance',
          '📍 Gate 5 · 11:03 AM · 3 people on 1 scan', 'Warning', false),
    ]),
  );

  Widget _alertItem(ThemeNotifier theme, String icon, String title, String meta,
      String badge, bool critical) {
    final color = critical ? GeoColors.danger : GeoColors.warning;
    final ghost = critical ? GeoColors.dangerGhost : GeoColors.warningGhost;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GeoRadius.md),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: ghost, borderRadius: BorderRadius.circular(GeoRadius.md)),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 15))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary,
          )),
          Text(meta, style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          decoration: BoxDecoration(color: ghost, borderRadius: BorderRadius.circular(GeoRadius.full)),
          child: Text(badge.toUpperCase(), style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: .5,
          )),
        ),
      ]),
    );
  }

  // ── LIVE FEED ─────────────────────────────────────────────────────────
  Widget _buildLiveFeed(ThemeNotifier theme) => SectionCard(
    theme: theme,
    title: '🟢 Live Activity Feed',
    count: 'Real-time',
    linkLabel: 'Full Log →',
    onLink: () => context.go('/admin/entries'),
    child: Column(
      children: _feed.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _feedRow(theme, f),
      )).toList(),
    ),
  );

  Widget _feedRow(ThemeNotifier theme, _FeedItem f) {
    final confColor = f.type == 'denied'
        ? GeoColors.danger
        : f.conf < 75 ? GeoColors.warning : GeoColors.success;
    final typeLabel = f.type == 'exit' ? '↩ Exit'
        : f.type == 'denied' ? '🚫 Denied' : '→ Entry';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(GeoRadius.md),
      ),
      child: Row(children: [
        AvatarCircle(
          initials: f.initials,
          gradient: [
            _hexColor(f.colors[0]),
            _hexColor(f.colors.length > 1 ? f.colors[1] : f.colors[0]),
          ],
          size: 36, fontSize: 12,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.name, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary,
          )),
          Text('${f.id} · ${f.gate} · ${_fmtTime(f.time)}',
            style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary),
            overflow: TextOverflow.ellipsis,
          ),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${f.conf.toStringAsFixed(1)}%', style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w700, color: confColor,
          )),
          Text(typeLabel, style: GoogleFonts.inter(
            fontSize: 11, color: theme.textTertiary,
          )),
        ]),
      ]),
    );
  }

  // ── CCTV GRID ─────────────────────────────────────────────────────────
  Widget _buildCctvSection(ThemeNotifier theme) => Container(
    decoration: BoxDecoration(
      color: theme.bgCard,
      border: Border.all(color: theme.border),
      borderRadius: BorderRadius.circular(GeoRadius.lg),
    ),
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Text('📹 Live Camera Preview', style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary,
          )),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: theme.bgBadge, borderRadius: BorderRadius.circular(GeoRadius.full)),
            child: Text('11 / 12 Online', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: theme.textSecondary,
            )),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.go('/admin/cctv'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: GeoColors.primaryGhost),
                borderRadius: BorderRadius.circular(GeoRadius.sm),
              ),
              child: Text('Full Feed →', style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600, color: GeoColors.primary,
              )),
            ),
          ),
        ]),
      ),
      Divider(height: 1, color: theme.border),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          _cctvCell('assets/cctv_main_gate.png',  '📍 Main Gate — CAM-01',   false, theme),
          const SizedBox(width: 14),
          _cctvCell('assets/cctv_library.png',    '📍 Library — CAM-02',     false, theme),
          const SizedBox(width: 14),
          _cctvCell('assets/cctv_lobby.png',      '📍 Admin Block — CAM-05', false, theme),
          const SizedBox(width: 14),
          _cctvCell('assets/cctv_parking.png',    '📍 Sports Complex — CAM-09 · OFFLINE', true, theme),
        ]),
      ),
    ]),
  );

  Widget _cctvCell(String asset, String label, bool offline, ThemeNotifier theme) =>
      Expanded(child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(GeoRadius.md),
          child: Stack(children: [
            Positioned.fill(child: Image.asset(
              asset, fit: BoxFit.cover,
              color: offline ? Colors.black.withOpacity(.7) : null,
              colorBlendMode: offline ? BlendMode.darken : null,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF111111),
                child: const Center(child: Text('📹', style: TextStyle(fontSize: 28))),
              ),
            )),
            if (!offline) Positioned(top: 8, left: 8, child: Row(children: [
              const LiveDot(), const SizedBox(width: 4),
              Text('LIVE', style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white,
              )),
            ])),
            Positioned(bottom: 0, left: 0, right: 0, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Color(0xD9000000), Colors.transparent],
              )),
              child: Text(label, style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white,
              )),
            )),
          ]),
        ),
      ));

  // ── SYSTEM HEALTH ─────────────────────────────────────────────────────
  Widget _buildSystemHealth(ThemeNotifier theme) => SectionCard(
    theme: theme, title: '⚙️ System Health',
    child: Row(children: [
      Expanded(child: HealthCard(theme: theme, label: 'AI Recognition',
        value: '91%', sub: 'CPU Load · Online', progress: .91,
        barColor: GeoColors.success, status: 'online')),
      const SizedBox(width: 14),
      Expanded(child: HealthCard(theme: theme, label: 'Database',
        value: '68%', sub: 'Storage Used · Online', progress: .68,
        barColor: const Color(0xFF555555), status: 'online')),
      const SizedBox(width: 14),
      Expanded(child: HealthCard(theme: theme, label: 'CCTV Network',
        value: '11 / 12', sub: 'Cameras Active · 1 Offline', progress: .92,
        barColor: GeoColors.warning, status: 'degraded')),
      const SizedBox(width: 14),
      Expanded(child: HealthCard(theme: theme, label: 'Gate Control',
        value: '8 / 8', sub: 'Gates Operational', progress: 1,
        barColor: GeoColors.success, status: 'online')),
    ]),
  );

  // ── RIGHT PANEL ───────────────────────────────────────────────────────
  Widget _buildRightPanel(ThemeNotifier theme) => Container(
    width: 320,
    color: theme.bgCard,
    child: Column(children: [
      Divider(height: 1, color: theme.border),
      // Clock
      Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [theme.bgBadge, theme.bgCard],
          ),
          border: Border(bottom: BorderSide(color: theme.border)),
        ),
        child: Column(children: [
          Text(_fmtTime(_now), style: GoogleFonts.inter(
            fontSize: 34, fontWeight: FontWeight.w800,
            letterSpacing: -1.5, color: theme.textPrimary,
          )),
          Text(_fmtDate(_now), style: GoogleFonts.inter(
            fontSize: 12, color: theme.textTertiary,
          )),
          const SizedBox(height: 10),
          const LiveBadge(label: 'MONITORING LIVE'),
        ]),
      ),

      Expanded(child: SingleChildScrollView(child: Column(children: [
        // Threat summary
        _panelSection(theme, 'THREAT SUMMARY', Column(children: [
          _threatSummaryRow(theme, GeoColors.danger,  'Unauthorized Access', '2', red: true),
          _threatSummaryRow(theme, GeoColors.warning, 'Tailgating',          '1'),
          _threatSummaryRow(theme, const Color(0xFF666666), 'Low Confidence', '4'),
          _threatSummaryRow(theme, GeoColors.danger,  'Blacklisted',         '1', red: true),
        ])),

        // Recent scans
        _panelSection(theme, 'RECENT SCANS', Column(
          children: _scans.map((s) => _scanItem(theme, s)).toList(),
        )),

        // Today at a glance
        _panelSection(theme, 'TODAY AT A GLANCE', Column(children: [
          _threatSummaryRow(theme, const Color(0xFF111111), 'Peak Hour', '09:00 – 10:00'),
          _threatSummaryRow(theme, const Color(0xFF111111), 'Busiest Gate', 'Main Gate'),
          _threatSummaryRow(theme, GeoColors.success,
              'Avg Confidence', '${_avgConf.toStringAsFixed(1)}%'),
        ])),

        Padding(
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: () => context.go('/admin/entries'),
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: GeoColors.primary,
                borderRadius: BorderRadius.circular(GeoRadius.md),
              ),
              child: Center(child: Text('📋 View Full Activity Log',
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
                ),
              )),
            ),
          ),
        ),
      ]))),
    ]),
  );

  Widget _panelSection(ThemeNotifier theme, String title, Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: theme.border)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: theme.textTertiary, letterSpacing: .8,
      )),
      const SizedBox(height: 14),
      child,
    ]),
  );

  Widget _threatSummaryRow(ThemeNotifier theme, Color dot, String name, String count, {bool red = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(name, style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, color: theme.textPrimary,
        ))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: red ? GeoColors.dangerGhost : theme.bgBadge,
            borderRadius: BorderRadius.circular(GeoRadius.full),
          ),
          child: Text(count, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: red ? GeoColors.danger : theme.textSecondary,
          )),
        ),
      ]),
    );

  Widget _scanItem(ThemeNotifier theme, _ScanItem s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      AvatarCircle(
        initials: s.initials,
        gradient: [_hexColor(s.colors[0]), _hexColor(s.colors.length > 1 ? s.colors[1] : s.colors[0])],
        size: 32, fontSize: 11,
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.name, style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: theme.textPrimary,
        )),
        Text('${s.gate} · ${_fmtTime(s.time)}', style: GoogleFonts.inter(
          fontSize: 11, color: theme.textTertiary,
        )),
      ])),
      Text('${s.conf.toStringAsFixed(1)}%', style: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w700, color: GeoColors.success,
      )),
    ]),
  );

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.trim().replaceAll('#', '0xFF')));
    } catch (_) {
      return GeoColors.primary;
    }
  }
}

class _FeedItem {
  final String name, id, initials, gate, type;
  final List<String> colors;
  final DateTime time;
  final double conf;
  const _FeedItem({required this.name, required this.id, required this.initials,
    required this.colors, required this.gate, required this.time,
    required this.conf, required this.type});
}

class _ScanItem {
  final String name, initials, gate;
  final List<String> colors;
  final DateTime time;
  final double conf;
  const _ScanItem({required this.name, required this.initials, required this.colors,
    required this.gate, required this.time, required this.conf});
}
