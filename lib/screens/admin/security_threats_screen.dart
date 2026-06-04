import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/backend_service.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/common_widgets.dart';

class SecurityThreatsScreen extends StatefulWidget {
  const SecurityThreatsScreen({super.key});
  @override
  State<SecurityThreatsScreen> createState() => _SecurityThreatsScreenState();
}

class _SecurityThreatsScreenState extends State<SecurityThreatsScreen> {
  late final BackendService _backend;
  Timer? _refreshTimer;

  List<dynamic> _threats = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String _statusFilter = 'active';

  @override
  void initState() {
    super.initState();
    _backend = context.read<AuthService>().backend;
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() { _refreshTimer?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final threats = await _backend.getThreats(
      status: _statusFilter == 'all' ? null : _statusFilter,
    );
    if (!mounted) return;
    setState(() { _threats = threats; _loading = false; });
  }

  Future<void> _resolve(int id) async {
    await _backend.resolveThreat(id);
    _load();
    GeoToast.show(context, 'Threat marked as resolved.', type: 'success');
  }

  Color _typeColor(String type) => switch (type) {
    'blacklisted' => GeoColors.danger,
    'unverified'  => GeoColors.warning,
    _             => const Color(0xFF6366F1),
  };

  IconData _typeIcon(String type) => switch (type) {
    'blacklisted' => Icons.block_outlined,
    'unverified'  => Icons.gps_fixed_outlined,
    _             => Icons.person_off_outlined,
  };

  String _typeLabel(String type) => switch (type) {
    'blacklisted' => 'Blacklisted Individual',
    'unverified'  => 'Geofence Violation',
    _             => 'Unidentified Person',
  };

  @override
  Widget build(BuildContext context) {
    final theme    = context.watch<ThemeNotifier>();
    final active   = _threats.where((t) => t['status'] == 'active').length;
    final resolved = _threats.where((t) => t['status'] == 'resolved').length;
    final blacklisted = _threats.where((t) => t['threat_type'] == 'blacklisted').length;
    final unidentified = _threats.where((t) => t['threat_type'] == 'unidentified').length;
    final unverified   = _threats.where((t) => t['threat_type'] == 'unverified').length;

    return AdminShell(
      activeRoute: '/admin/threats',
      breadcrumb: 'Security Threats',
      pageTitle: 'Security Threats',
      topbarActions: [
        const LiveBadge(),
        const SizedBox(width: 8),
        _topBtn(theme, Icons.refresh_outlined, 'Refresh', _load),
      ],
      body: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Security Threats', style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w800, color: theme.textPrimary)),
            const SizedBox(height: 4),
            Text('Real-time monitoring of all campus security incidents. Only real detection events appear here.',
              style: GoogleFonts.inter(fontSize: 13, color: theme.textSecondary)),
            const SizedBox(height: 20),

            // Stats
            Row(children: [
              Expanded(child: StatCard(theme: theme, icon: '!', value: '$active',
                label: 'Active Threats', iconBg: GeoColors.dangerGhost,
                trend: active > 0 ? 'Requires attention' : 'All clear', trendUp: false)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(theme: theme, icon: 'B', value: '$blacklisted',
                label: 'Blacklisted', iconBg: GeoColors.dangerGhost)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(theme: theme, icon: 'U', value: '$unidentified',
                label: 'Unidentified', iconBg: const Color(0x1A6366F1))),
              const SizedBox(width: 12),
              Expanded(child: StatCard(theme: theme, icon: 'G', value: '$unverified',
                label: 'Geofence Violations', iconBg: GeoColors.warningGhost)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(theme: theme, icon: 'R', value: '$resolved',
                label: 'Resolved', iconBg: GeoColors.successGhost, trend: 'Total', trendUp: true)),
            ]),
            const SizedBox(height: 20),

            // Filter tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: theme.bgBadge,
                borderRadius: BorderRadius.circular(GeoRadius.md)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _filterChip(theme, 'Active', 'active'),
                _filterChip(theme, 'Resolved', 'resolved'),
                _filterChip(theme, 'All', 'all'),
              ]),
            ),
            const SizedBox(height: 16),

            // Threat table
            Container(
              decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(GeoRadius.lg)),
              child: Column(children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(children: [
                    Icon(Icons.warning_amber_outlined, size: 16,
                      color: active > 0 ? GeoColors.danger : theme.textTertiary),
                    const SizedBox(width: 8),
                    Text('Threats', style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary)),
                    const SizedBox(width: 10),
                    if (active > 0) Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: GeoColors.dangerGhost,
                        borderRadius: BorderRadius.circular(GeoRadius.full)),
                      child: Text('$active Active', style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700, color: GeoColors.danger))),
                  ])),

                // Column headers
                Container(
                  color: theme.bgBadge,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(children: [
                    _th(theme, 'Type',      48),
                    _th(theme, 'Incident',  0, flex: true),
                    _th(theme, 'Gate',      120),
                    _th(theme, 'Confidence',80),
                    _th(theme, 'Time',      90),
                    _th(theme, 'Status',    90),
                    _th(theme, 'Action',    110),
                  ])),
                Divider(height: 1, color: theme.border),

                if (_loading)
                  const Padding(padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: GeoColors.primary)))
                else if (_threats.isEmpty)
                  Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: [
                    const Icon(Icons.shield_outlined, size: 40, color: GeoColors.success),
                    const SizedBox(height: 12),
                    Text('No threats detected.', style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700, color: GeoColors.success)),
                    const SizedBox(height: 4),
                    Text('All camera zones are clear.', style: GoogleFonts.inter(
                      fontSize: 12, color: theme.textTertiary)),
                  ])))
                else
                  ..._threats.map((t) => _threatRow(theme, t as Map<String, dynamic>)),
              ]),
            ),
          ]),
        ),

        // Detail panel
        if (_selected != null) ...[
          GestureDetector(
            onTap: () => setState(() => _selected = null),
            child: Container(color: Colors.black.withOpacity(.35))),
          Positioned(right: 0, top: 0, bottom: 0, child: _buildDetailPanel(theme, _selected!)),
        ],
      ]),
    );
  }

  Widget _filterChip(ThemeNotifier theme, String label, String value) => GestureDetector(
    onTap: () { setState(() { _statusFilter = value; _loading = true; }); _load(); },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _statusFilter == value ? GeoColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(GeoRadius.sm)),
      child: Text(label, style: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: _statusFilter == value ? Colors.white : theme.textSecondary)),
    ));

  Widget _threatRow(ThemeNotifier theme, Map<String, dynamic> t) {
    final type     = t['threat_type'] as String? ?? 'unidentified';
    final color    = _typeColor(type);
    final icon     = _typeIcon(type);
    final name     = t['user_name'] as String? ?? 'Unknown Person';
    final gate     = t['gate']   as String? ?? '—';
    final conf     = (t['confidence'] as num?)?.toDouble() ?? 0;
    final status   = t['status'] as String? ?? 'active';
    final timeStr  = t['detected_at'] as String? ?? '';
    final timeFmt  = timeStr.isNotEmpty
        ? '${DateTime.parse(timeStr).toLocal().hour.toString().padLeft(2,'0')}:${DateTime.parse(timeStr).toLocal().minute.toString().padLeft(2,'0')}'
        : '--:--';

    final statusBg = status == 'active' ? GeoColors.dangerGhost : GeoColors.successGhost;
    final statusFg = status == 'active' ? GeoColors.danger : GeoColors.success;

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.border))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          SizedBox(width: 48, child: Icon(icon, size: 22, color: color)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_typeLabel(type), style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700, color: theme.textPrimary)),
            Text(name, style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary)),
          ])),
          SizedBox(width: 120, child: Text(gate, style: GoogleFonts.inter(
            fontSize: 12, color: theme.textSecondary), overflow: TextOverflow.ellipsis)),
          SizedBox(width: 80, child: Text('${conf.toStringAsFixed(0)}%', style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: conf > 85 ? GeoColors.danger : GeoColors.warning))),
          SizedBox(width: 90, child: Text(timeFmt, style: GoogleFonts.inter(
            fontSize: 12, color: theme.textSecondary))),
          SizedBox(width: 90, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(GeoRadius.full)),
            child: Text(status == 'active' ? 'Active' : 'Resolved', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, color: statusFg)))),
          SizedBox(width: 110, child: Row(children: [
            GestureDetector(
              onTap: () => setState(() => _selected = t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: GeoColors.primary, borderRadius: BorderRadius.circular(GeoRadius.sm)),
                child: Text('Details', style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)))),
            const SizedBox(width: 6),
            if (status == 'active') GestureDetector(
              onTap: () => _resolve(t['id'] as int),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: GeoColors.success),
                  borderRadius: BorderRadius.circular(GeoRadius.sm)),
                child: const Icon(Icons.check, size: 13, color: GeoColors.success))),
          ])),
        ]),
      ),
    );
  }

  Widget _buildDetailPanel(ThemeNotifier theme, Map<String, dynamic> t) {
    final type  = t['threat_type'] as String? ?? 'unidentified';
    final color = _typeColor(type);
    final icon  = _typeIcon(type);
    final snap  = t['snapshot_path'] as String?;
    final fname = snap?.split(RegExp(r'[\\/]')).last;

    return Container(
      width: 480,
      color: theme.bgCard,
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.border))),
          child: Row(children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(_typeLabel(type), style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w800, color: theme.textPrimary))),
            GestureDetector(
              onTap: () => setState(() => _selected = null),
              child: Container(width: 30, height: 30,
                decoration: BoxDecoration(color: theme.bgBadge, shape: BoxShape.circle),
                child: Center(child: Icon(Icons.close, size: 16, color: theme.textPrimary)))),
          ])),

        // Content
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _panelSection(theme, 'INCIDENT INFORMATION'),
            _panelRow(theme, 'Threat Type',   _typeLabel(type)),
            _panelRow(theme, 'Person',        t['user_name'] as String? ?? 'Unknown'),
            _panelRow(theme, 'Gate',          t['gate'] as String? ?? '—'),
            _panelRow(theme, 'Confidence',    '${((t['confidence'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%'),
            _panelRow(theme, 'Status',        (t['status'] as String? ?? '—').toUpperCase()),
            _panelRow(theme, 'Detected',      _fmtDateTime(t['detected_at'] as String? ?? '')),
            if (t['resolved_at'] != null)
              _panelRow(theme, 'Resolved',    _fmtDateTime(t['resolved_at'] as String)),
            const SizedBox(height: 20),

            // Screenshot
            if (fname != null) ...[
              _panelSection(theme, 'SNAPSHOT'),
              Container(
                height: 180, width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(GeoRadius.md),
                  border: Border.all(color: theme.border)),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.camera_alt_outlined, size: 32, color: Colors.white38),
                  const SizedBox(height: 8),
                  Text(fname, style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('Screenshots auto-deleted after 15 days',
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.white24)),
                ]))),
              const SizedBox(height: 20),
            ],

            // Actions
            if (t['status'] == 'active') ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Mark as Resolved'),
              style: ElevatedButton.styleFrom(backgroundColor: GeoColors.success),
              onPressed: () { _resolve(t['id'] as int); setState(() => _selected = null); },
            ),
          ]),
        )),
      ]),
    );
  }

  Widget _panelSection(ThemeNotifier theme, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: theme.textTertiary, letterSpacing: .8)));

  Widget _panelRow(ThemeNotifier theme, String key, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(key, style: GoogleFonts.inter(fontSize: 12, color: theme.textTertiary)),
      Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textPrimary)),
    ]));

  Widget _th(ThemeNotifier theme, String label, double w, {bool flex = false}) {
    final child = Text(label.toUpperCase(), style: GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w700, color: theme.textTertiary, letterSpacing: .5));
    return flex ? Expanded(child: child) : SizedBox(width: w, child: child);
  }

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
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: theme.textSecondary)),
        ])));

  String _fmtDateTime(String iso) {
    if (iso.isEmpty) return '—';
    final dt = DateTime.parse(iso).toLocal();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month-1]} ${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}
