import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/backend_service.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/common_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final BackendService _backend;
  Timer? _refreshTimer;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  // Data
  Map<String, dynamic> _stats    = {};
  Map<String, dynamic> _health   = {};
  List<dynamic>        _threats  = [];
  List<dynamic>        _recentLogs = [];
  List<dynamic>        _onCampus   = [];
  bool _loading = true;

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _backend = context.read<AuthService>().backend;
    _loadAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadAll());
    _clockTimer   = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _backend.getStats(),
        _backend.getHealth(),
        _backend.getThreats(status: 'active'),
        _backend.getEntryLogs(limit: 8),
        _backend.getOnCampus(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats      = results[0] as Map<String, dynamic>;
        _health     = results[1] as Map<String, dynamic>;
        _threats    = results[2] as List<dynamic>;
        _recentLogs = results[3] as List<dynamic>;
        _onCampus   = results[4] as List<dynamic>;
        _loading    = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final timeStr = '${_now.hour.toString().padLeft(2,'0')}:${_now.minute.toString().padLeft(2,'0')}:${_now.second.toString().padLeft(2,'0')}';
    final dateStr = '${_fmtDay(_now.weekday)}, ${_monthName(_now.month)} ${_now.day} ${_now.year}';

    return AdminShell(
      activeRoute: '/admin/dashboard',
      breadcrumb: 'Dashboard',
      pageTitle: 'Command Centre',
      topbarActions: [
        const LiveBadge(),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.refresh_outlined, size: 18),
          onPressed: _loadAll,
          tooltip: 'Refresh',
          color: theme.textSecondary,
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GeoColors.primary))
          : _buildBody(theme, timeStr, dateStr),
    );
  }

  Widget _buildBody(ThemeNotifier theme, String timeStr, String dateStr) {
    final activeThreatCount = _threats.length;
    final entriesCount      = _stats['entries_today'] ?? 0;
    final onCampusCount     = _stats['on_campus_count'] ?? 0;
    final profileCount      = _stats['registered_profiles'] ?? 0;
    final avgConf           = _stats['avg_confidence'] ?? 0.0;
    final activeCams        = _health['cameras_active'] ?? 0;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── MAIN CONTENT ────────────────────────────────────────────
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Command Centre', style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w800, color: theme.textPrimary)),
              Text('$dateStr · $timeStr', style: GoogleFonts.inter(
                fontSize: 13, color: theme.textTertiary)),
            ])),
          ]),
          const SizedBox(height: 20),

          // Stats row
          Row(children: [
            Expanded(child: StatCard(theme: theme, icon: '→', value: '$entriesCount',
              label: 'Entries Today', iconBg: GeoColors.successGhost, trend: 'Today', trendUp: true)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(theme: theme, icon: '!', value: '$activeThreatCount',
              label: 'Active Threats', iconBg: GeoColors.dangerGhost,
              trend: activeThreatCount > 0 ? 'Action required' : 'All clear',
              trendUp: false)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(theme: theme, icon: 'C', value: '$activeCams',
              label: 'Active Cameras', iconBg: theme.bgBadge)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(theme: theme, icon: 'P', value: '$profileCount',
              label: 'Registered Profiles', iconBg: theme.bgBadge)),
          ]),
          const SizedBox(height: 20),

          // People on campus + avg confidence
          Row(children: [
            Expanded(child: _campusCard(theme, onCampusCount, avgConf.toDouble())),
            const SizedBox(width: 20),
            Expanded(child: _systemHealthCard(theme)),
          ]),
          const SizedBox(height: 20),

          // Threat alerts
          if (_threats.isNotEmpty) ...[
            _sectionHeader(theme, Icons.warning_amber_outlined, 'Active Threat Alerts', GeoColors.danger),
            const SizedBox(height: 12),
            ..._threats.take(5).map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _threatCard(theme, t))),
            const SizedBox(height: 12),
          ],

          // Activity Tabs
          _sectionHeader(theme, Icons.history_outlined, 'Activity', theme.textPrimary),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
              borderRadius: BorderRadius.circular(GeoRadius.lg)),
            child: Column(children: [
              // Tab bar
              Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.border))),
                child: TabBar(
                  controller: _tabCtrl,
                  indicatorColor: GeoColors.primary,
                  labelColor: GeoColors.primary,
                  unselectedLabelColor: theme.textTertiary,
                  labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
                  tabs: [
                    const Tab(text: 'Recent Scans'),
                    Tab(text: 'On Campus ($onCampusCount)'),
                  ],
                ),
              ),
              SizedBox(
                height: 320,
                child: TabBarView(controller: _tabCtrl, children: [
                  _buildRecentScans(theme),
                  _buildOnCampus(theme),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),
        ]),
      )),

      // ── RIGHT PANEL: CCTV PREVIEW ──────────────────────────────
      if (MediaQuery.of(context).size.width > 1100)
        Container(
          width: 340,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: theme.border))),
          child: _buildRightPanel(theme),
        ),
    ]);
  }

  Widget _campusCard(ThemeNotifier theme, int onCampus, double avgConf) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
      borderRadius: BorderRadius.circular(GeoRadius.lg)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.people_outline, size: 18, color: GeoColors.primary),
        const SizedBox(width: 8),
        Text('People on Campus', style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary)),
      ]),
      const SizedBox(height: 16),
      Text('$onCampus', style: GoogleFonts.inter(
        fontSize: 42, fontWeight: FontWeight.w800, color: theme.textPrimary)),
      Text('currently on campus', style: GoogleFonts.inter(
        fontSize: 13, color: theme.textSecondary)),
      const SizedBox(height: 16),
      Row(children: [
        const Icon(Icons.verified_outlined, size: 14, color: GeoColors.success),
        const SizedBox(width: 6),
        Text('Avg FR confidence: ${avgConf.toStringAsFixed(1)}%',
          style: GoogleFonts.inter(fontSize: 12, color: theme.textSecondary)),
      ]),
    ]));

  Widget _systemHealthCard(ThemeNotifier theme) {
    final cpu    = _health['cpu_percent'] as num? ?? 0;
    final ram    = _health['ram_percent'] as num? ?? 0;
    final dbMb   = _health['db_size_mb'] as num? ?? 0;
    final camT   = _health['cameras_total'] as num? ?? 0;
    final camA   = _health['cameras_active'] as num? ?? 0;
    final up     = _health['uptime_seconds'] as num? ?? 0;
    final upHrs  = (up / 3600).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(GeoRadius.lg)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.monitor_heart_outlined, size: 18, color: GeoColors.primary),
          const SizedBox(width: 8),
          Text('System Health', style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary)),
        ]),
        const SizedBox(height: 16),
        _healthRow(theme, Icons.memory_outlined,       'CPU',       '${cpu.round()}%',    cpu / 100),
        _healthRow(theme, Icons.storage_outlined,      'RAM',       '${ram.round()}%',    ram / 100),
        _healthRow(theme, Icons.storage_outlined,      'Database',  '${dbMb.toStringAsFixed(1)} MB', null),
        _healthRow(theme, Icons.videocam_outlined,     'Cameras',   '$camA / $camT active', null),
        _healthRow(theme, Icons.access_time_outlined,  'Uptime',    '${upHrs}h', null),
      ]));
  }

  Widget _healthRow(ThemeNotifier theme, IconData icon, String label, String value, double? progress) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: theme.textTertiary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: theme.textSecondary))),
          Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: theme.textPrimary)),
        ]),
        if (progress != null) ...[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(GeoRadius.full),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: theme.bgBadge,
              color: progress > 0.85 ? GeoColors.danger : progress > 0.6 ? GeoColors.warning : GeoColors.success,
              minHeight: 4,
            )),
        ],
      ]));

  Widget _threatCard(ThemeNotifier theme, Map<String, dynamic> t) {
    final type = t['threat_type'] as String? ?? 'unidentified';
    final Color bg; final Color fg; final IconData icon; final String label;
    switch (type) {
      case 'blacklisted':
        bg = GeoColors.dangerGhost; fg = GeoColors.danger;
        icon = Icons.block_outlined; label = 'Blacklisted Individual';
      case 'unverified':
        bg = GeoColors.warningGhost; fg = GeoColors.warning;
        icon = Icons.gps_fixed_outlined; label = 'Geofence Violation';
      default:
        bg = const Color(0x1A6366F1); fg = const Color(0xFF6366F1);
        icon = Icons.person_off_outlined; label = 'Unidentified Person';
    }
    final name  = t['user_name'] as String? ?? 'Unknown';
    final gate  = t['gate']  as String? ?? 'Unknown Gate';
    final conf  = t['confidence'] as num? ?? 0;
    final time  = t['detected_at'] as String? ?? '';
    final timeFmt = time.isNotEmpty
        ? '${DateTime.parse(time).toLocal().hour.toString().padLeft(2,'0')}:${DateTime.parse(time).toLocal().minute.toString().padLeft(2,'0')}'
        : '--:--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg.withOpacity(.5), border: Border.all(color: fg.withOpacity(.3)),
        borderRadius: BorderRadius.circular(GeoRadius.lg)),
      child: Row(children: [
        Icon(icon, size: 22, color: fg),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
          Text('$name — $gate · ${conf.toStringAsFixed(0)}% confidence · $timeFmt',
            style: GoogleFonts.inter(fontSize: 11, color: theme.textSecondary)),
        ])),
        TextButton(
          onPressed: () => context.go('/admin/threats'),
          child: Text('View', style: GoogleFonts.inter(fontSize: 12, color: fg, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _buildRecentScans(ThemeNotifier theme) {
    if (_recentLogs.isEmpty) return Center(child: Text('No entries yet.',
      style: GoogleFonts.inter(fontSize: 13, color: theme.textTertiary)));
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _recentLogs.length,
      itemBuilder: (_, i) {
        final e    = _recentLogs[i] as Map<String, dynamic>;
        final name = e['user_name'] as String? ?? 'Unknown';
        final gate = e['gate'] as String? ?? '';
        final type = e['type'] as String? ?? 'entry';
        final conf = (e['confidence'] as num?)?.toDouble() ?? 0;
        final time = e['timestamp'] as String? ?? '';
        final timeFmt = time.isNotEmpty
            ? '${DateTime.parse(time).toLocal().hour.toString().padLeft(2,'0')}:${DateTime.parse(time).toLocal().minute.toString().padLeft(2,'0')}'
            : '--';
        final Color typeColor = type == 'entry' ? GeoColors.success : type == 'denied' ? GeoColors.danger : const Color(0xFF6366F1);
        final initials = name.trim().split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.border))),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: GeoColors.avatarGradients[name.hashCode.abs() % GeoColors.avatarGradients.length],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Center(child: Text(initials, style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary)),
              Text('$gate · $timeFmt', style: GoogleFonts.inter(
                fontSize: 11, color: theme.textTertiary)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(.1),
                  borderRadius: BorderRadius.circular(GeoRadius.full)),
                child: Text(type.substring(0,1).toUpperCase() + type.substring(1),
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: typeColor))),
              const SizedBox(height: 2),
              Text('${conf.toStringAsFixed(0)}%', style: GoogleFonts.inter(
                fontSize: 11, color: theme.textTertiary)),
            ]),
          ]),
        );
      },
    );
  }

  Widget _buildOnCampus(ThemeNotifier theme) {
    if (_onCampus.isEmpty) return Center(child: Text('No one on campus right now.',
      style: GoogleFonts.inter(fontSize: 13, color: theme.textTertiary)));
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _onCampus.length,
      itemBuilder: (_, i) {
        final u    = _onCampus[i] as Map<String, dynamic>;
        final name = u['user_name'] as String? ?? 'Unknown';
        final gate = u['gate']  as String? ?? '';
        final id   = u['user_id'] as String? ?? '';
        final dept = u['dept']  as String? ?? '';
        final initials = name.trim().split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.border))),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: GeoColors.avatarGradients[name.hashCode.abs() % GeoColors.avatarGradients.length],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Center(child: Text(initials, style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary)),
              Text('$id${dept.isNotEmpty ? " · $dept" : ""} · Entered at $gate',
                style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary)),
            ])),
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: GeoColors.success, shape: BoxShape.circle)),
          ]),
        );
      },
    );
  }

  Widget _buildRightPanel(ThemeNotifier theme) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Live Camera Preview
      Text('Live Camera', style: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w700, color: theme.textPrimary)),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => context.go('/admin/cctv'),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(GeoRadius.md),
            border: Border.all(color: theme.border)),
          child: Stack(children: [
            const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.videocam_outlined, size: 32, color: Colors.white38),
              SizedBox(height: 8),
              Text('Click to open CCTV', style: TextStyle(fontSize: 12, color: Colors.white38)),
            ])),
            Positioned(top: 8, left: 8, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: GeoColors.danger, borderRadius: BorderRadius.circular(4)),
              child: Text('LIVE', style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)))),
            Positioned(bottom: 8, right: 8, child: Text('CAM-01 · Main Gate',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.white60))),
          ]),
        ),
      ),
      const SizedBox(height: 20),

      // Quick stats
      Text('Quick Stats', style: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w700, color: theme.textPrimary)),
      const SizedBox(height: 10),
      _quickStat(theme, Icons.login_outlined,       'Entries today',    '${_stats['entries_today'] ?? 0}'),
      _quickStat(theme, Icons.logout_outlined,      'Exits today',      '${_stats['exits_today'] ?? 0}'),
      _quickStat(theme, Icons.block_outlined,       'Access denied',    '${_stats['denied_today'] ?? 0}'),
      _quickStat(theme, Icons.warning_amber_outlined, 'Active threats',  '${_threats.length}'),
      const SizedBox(height: 20),

      // Quick links
      Text('Quick Access', style: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w700, color: theme.textPrimary)),
      const SizedBox(height: 10),
      _quickLink(theme, Icons.history_outlined,           'Entry History',     '/admin/entries'),
      _quickLink(theme, Icons.warning_amber_outlined,     'Security Threats',  '/admin/threats'),
      _quickLink(theme, Icons.videocam_outlined,          'CCTV Feed',         '/admin/cctv'),
      _quickLink(theme, Icons.badge_outlined,             'Visitor Management','/admin/visitors'),
    ]));

  Widget _quickStat(ThemeNotifier theme, IconData icon, String label, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, size: 15, color: theme.textTertiary),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: theme.textSecondary))),
      Text(val, style: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w800, color: theme.textPrimary)),
    ]));

  Widget _quickLink(ThemeNotifier theme, IconData icon, String label, String route) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: GestureDetector(
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.bgBadge,
          borderRadius: BorderRadius.circular(GeoRadius.sm)),
        child: Row(children: [
          Icon(icon, size: 15, color: GeoColors.primary),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary)),
          const Spacer(),
          Icon(Icons.chevron_right, size: 16, color: theme.textTertiary),
        ]),
      )));

  Widget _sectionHeader(ThemeNotifier theme, IconData icon, String title, Color color) => Row(children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(width: 8),
    Text(title, style: GoogleFonts.inter(
      fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary)),
  ]);

  String _fmtDay(int d) => ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d-1];
  String _monthName(int m) => ['January','February','March','April','May','June',
    'July','August','September','October','November','December'][m-1];
}
