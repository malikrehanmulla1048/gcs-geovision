import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/backend_service.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/common_widgets.dart';

class EntryHistoryScreen extends StatefulWidget {
  const EntryHistoryScreen({super.key});
  @override
  State<EntryHistoryScreen> createState() => _EntryHistoryScreenState();
}

class _EntryHistoryScreenState extends State<EntryHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final BackendService _backend;
  Timer? _refreshTimer;
  late TabController _tabCtrl;

  List<dynamic> _logs      = [];
  List<dynamic> _onCampus  = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  String _search     = '';
  String _typeFilter = 'all';
  String _gateFilter = 'all';

  static const _gates = ['all', 'Main Gate', 'East Entrance', 'Library', 'Admin Block', 'Sports Complex'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _backend = context.read<AuthService>().backend;
    _loadAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadAll());
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      _backend.getEntryLogs(typeFilter: _typeFilter, gateFilter: _gateFilter, search: _search),
      _backend.getOnCampus(),
      _backend.getStats(),
    ]);
    if (!mounted) return;
    setState(() {
      _logs     = results[0] as List<dynamic>;
      _onCampus = results[1] as List<dynamic>;
      _stats    = results[2] as Map<String, dynamic>;
      _loading  = false;
    });
  }

  Color _typeColor(String type) => switch (type) {
    'entry'  => GeoColors.success,
    'exit'   => const Color(0xFF6366F1),
    'denied' => GeoColors.danger,
    _        => GeoColors.warning,
  };

  String _typeName(String type) => switch (type) {
    'entry'  => 'Entry',
    'exit'   => 'Exit',
    'denied' => 'Denied',
    _        => type,
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();

    return AdminShell(
      activeRoute: '/admin/entries',
      breadcrumb: 'Entry History',
      pageTitle: 'Entry & Exit History',
      topbarActions: [
        const LiveBadge(),
        const SizedBox(width: 8),
        _topBtn(theme, Icons.refresh_outlined, 'Refresh', _loadAll),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Entry & Exit History', style: GoogleFonts.inter(
            fontSize: 22, fontWeight: FontWeight.w800, color: theme.textPrimary)),
          const SizedBox(height: 4),
          Text('Live log of all campus gate events. Updates every 10 seconds.',
            style: GoogleFonts.inter(fontSize: 13, color: theme.textSecondary)),
          const SizedBox(height: 16),

          // Stats
          Row(children: [
            Expanded(child: StatCard(theme: theme, icon: '→', value: '${_stats['entries_today'] ?? 0}',
              label: 'Entries Today', trend: 'Today', trendUp: true, iconBg: GeoColors.successGhost)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(theme: theme, icon: '←', value: '${_stats['exits_today'] ?? 0}',
              label: 'Exits Today', trend: 'Today')),
            const SizedBox(width: 12),
            Expanded(child: StatCard(theme: theme, icon: 'X', value: '${_stats['denied_today'] ?? 0}',
              label: 'Access Denied', iconBg: GeoColors.dangerGhost, trendUp: false)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(theme: theme, icon: '%', value: '${_stats['avg_confidence'] ?? 0}%',
              label: 'Avg Confidence', iconBg: GeoColors.successGhost, trendUp: true)),
          ]),
          const SizedBox(height: 20),

          // Tabs
          Container(
            decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
              borderRadius: BorderRadius.circular(GeoRadius.lg)),
            child: Column(children: [
              Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.border))),
                child: TabBar(
                  controller: _tabCtrl,
                  indicatorColor: GeoColors.primary,
                  labelColor: GeoColors.primary,
                  unselectedLabelColor: theme.textTertiary,
                  labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
                  tabs: [
                    Tab(text: 'Entry Log (${_logs.length})'),
                    Tab(text: 'On Campus (${_onCampus.length})'),
                  ],
                ),
              ),
              SizedBox(
                height: 600,
                child: TabBarView(controller: _tabCtrl, children: [
                  _buildEntryLog(theme),
                  _buildOnCampus(theme),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildEntryLog(ThemeNotifier theme) => Column(children: [
    // Filters
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        // Search
        Expanded(child: TextField(
          onChanged: (v) { setState(() { _search = v; _loading = true; }); _loadAll(); },
          style: GoogleFonts.inter(fontSize: 12, color: theme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search name or ID...',
            hintStyle: GoogleFonts.inter(fontSize: 12, color: theme.textTertiary),
            prefixIcon: Icon(Icons.search, size: 16, color: theme.textTertiary),
            filled: true, fillColor: theme.bgInput,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GeoRadius.sm),
              borderSide: BorderSide(color: theme.border)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GeoRadius.sm),
              borderSide: BorderSide(color: theme.border))),
        )),
        const SizedBox(width: 8),
        _filterDrop(theme, _typeFilter, ['all','entry','exit','denied'],
          ['All Types','Entry','Exit','Denied'],
          (v) { setState(() { _typeFilter = v!; _loading = true; }); _loadAll(); }),
        const SizedBox(width: 8),
        _filterDrop(theme, _gateFilter, _gates, ['All Gates', ..._gates.skip(1)],
          (v) { setState(() { _gateFilter = v!; _loading = true; }); _loadAll(); }),
      ]),
    ),
    Divider(height: 1, color: theme.border),

    // Table header
    Container(
      color: theme.bgBadge,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        _th(theme, '#',      40),
        _th(theme, 'Person', 180),
        _th(theme, 'Dept',   80),
        _th(theme, 'Gate',   130),
        _th(theme, 'Time',   90),
        _th(theme, 'Type',   90),
        _th(theme, 'Conf.',  70),
      ])),
    Divider(height: 2, color: theme.border),

    // Rows
    _loading
        ? const Expanded(child: Center(child: CircularProgressIndicator(color: GeoColors.primary)))
        : _logs.isEmpty
            ? Expanded(child: Center(child: Text('No entries found.',
                style: GoogleFonts.inter(fontSize: 13, color: theme.textTertiary))))
            : Expanded(child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (_, i) {
                  final e    = _logs[i] as Map<String, dynamic>;
                  final name = e['user_name'] as String? ?? 'Unknown';
                  final id   = e['user_id']  as String? ?? '';
                  final dept = e['dept']     as String? ?? '';
                  final gate = e['gate']     as String? ?? '';
                  final type = e['type']     as String? ?? 'entry';
                  final conf = (e['confidence'] as num?)?.toDouble() ?? 0;
                  final ts   = e['timestamp'] as String? ?? '';
                  final timeFmt = ts.isNotEmpty
                      ? () { final d = DateTime.parse(ts).toLocal();
                          return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}:${d.second.toString().padLeft(2,'0')}'; }()
                      : '--:--:--';
                  final initials = name.trim().split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();
                  final typeColor  = _typeColor(type);
                  final confColor  = type == 'denied' ? GeoColors.danger
                      : conf >= 90 ? GeoColors.success : conf >= 75 ? GeoColors.warning : GeoColors.danger;

                  return Container(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.border))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      child: Row(children: [
                        SizedBox(width: 40, child: Text(
                          (i + 1).toString().padLeft(3, '0'),
                          style: GoogleFonts.inter(fontSize: 12, color: theme.textTertiary,
                            fontWeight: FontWeight.w600))),
                        SizedBox(width: 180, child: Row(children: [
                          Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: GeoColors.avatarGradients[name.hashCode.abs() % GeoColors.avatarGradients.length],
                                begin: Alignment.topLeft, end: Alignment.bottomRight)),
                            child: Center(child: Text(initials, style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)))),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
                              color: theme.textPrimary), overflow: TextOverflow.ellipsis),
                            Text(id, style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary)),
                          ])),
                        ])),
                        SizedBox(width: 80, child: Text(dept, style: GoogleFonts.inter(
                          fontSize: 12, color: theme.textPrimary), overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 130, child: Text(gate, style: GoogleFonts.inter(
                          fontSize: 12, color: theme.textPrimary), overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 90, child: Text(timeFmt, style: GoogleFonts.inter(
                          fontSize: 12, color: theme.textPrimary))),
                        SizedBox(width: 90, child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: typeColor.withOpacity(.1),
                            borderRadius: BorderRadius.circular(GeoRadius.full)),
                          child: Text(_typeName(type), style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700, color: typeColor)))),
                        SizedBox(width: 70, child: Text('${conf.toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: confColor))),
                      ]),
                    ),
                  );
                },
              )),

    // Footer
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Text('Showing ${_logs.length} records',
          style: GoogleFonts.inter(fontSize: 12, color: theme.textTertiary)),
      ])),
  ]);

  Widget _buildOnCampus(ThemeNotifier theme) {
    if (_onCampus.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.people_outline, size: 40, color: GeoColors.success),
      const SizedBox(height: 12),
      Text('No one currently on campus.', style: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary)),
    ]));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _onCampus.length,
      itemBuilder: (_, i) {
        final u    = _onCampus[i] as Map<String, dynamic>;
        final name = u['user_name'] as String? ?? 'Unknown';
        final id   = u['user_id']  as String? ?? '';
        final dept = u['dept']     as String? ?? '';
        final gate = u['gate']     as String? ?? '';
        final initials = name.trim().split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: theme.bgBadge,
              borderRadius: BorderRadius.circular(GeoRadius.md),
              border: Border.all(color: theme.border)),
            child: Row(children: [
              Container(
                width: 38, height: 38,
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
                  fontSize: 13, fontWeight: FontWeight.w700, color: theme.textPrimary)),
                Text('$id${dept.isNotEmpty ? " · $dept" : ""}',
                  style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: GeoColors.success, shape: BoxShape.circle)),
                const SizedBox(height: 4),
                Text(gate, style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary)),
              ]),
            ]),
          ));
      },
    );
  }

  Widget _th(ThemeNotifier theme, String label, double w) => SizedBox(width: w,
    child: Text(label.toUpperCase(), style: GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w700, color: theme.textTertiary, letterSpacing: .6)));

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
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500,
            color: theme.textSecondary)),
        ])));

  Widget _filterDrop(ThemeNotifier theme, String value, List<String> vals,
      List<String> labels, ValueChanged<String?> onChanged) =>
    DropdownButton<String>(
      value: value,
      underline: const SizedBox(),
      style: GoogleFonts.inter(fontSize: 12, color: theme.textPrimary),
      dropdownColor: theme.bgCard,
      items: List.generate(vals.length, (i) =>
        DropdownMenuItem(value: vals[i], child: Text(labels[i]))),
      onChanged: onChanged);
}
