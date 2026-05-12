import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/common_widgets.dart';

class EntryHistoryScreen extends StatefulWidget {
  const EntryHistoryScreen({super.key});
  @override
  State<EntryHistoryScreen> createState() => _EntryHistoryScreenState();
}

class _EntryHistoryScreenState extends State<EntryHistoryScreen> {
  final _rng = Random();
  Timer? _liveTimer;
  final List<_Row> _rows = [];
  String _search = '';
  String _typeFilter = 'all';
  String _gateFilter = 'all';
  int _entryCount = 247, _exitCount = 89, _deniedCount = 5;
  double _avgConf = 96.3;
  final List<double> _confVals = [];

  static const _people = [
    {'name': 'Arjun Kumar',    'id': 'SRN21CS001', 'dept': 'CS',    'initials': 'AK', 'color': '#dc2626,#991b1b'},
    {'name': 'Priya Sharma',   'id': 'SRN21EC045', 'dept': 'EC',    'initials': 'PS', 'color': '#2563eb,#1e3a8a'},
    {'name': 'Rohit Nair',     'id': 'SRN21ME012', 'dept': 'ME',    'initials': 'RN', 'color': '#16a34a,#14532d'},
    {'name': 'Sneha Krishnan', 'id': 'STAF-005',   'dept': 'Admin', 'initials': 'SK', 'color': '#7c3aed,#4c1d95'},
    {'name': 'Mohammed Tariq', 'id': 'SRN21IT088', 'dept': 'IT',    'initials': 'MT', 'color': '#db2777,#831843'},
    {'name': 'Divya Menon',    'id': 'SRN22CS034', 'dept': 'CS',    'initials': 'DM', 'color': '#0891b2,#164e63'},
    {'name': 'Kiran Reddy',    'id': 'SRN22EE021', 'dept': 'EE',    'initials': 'KR', 'color': '#d97706,#92400e'},
    {'name': 'Ananya Pillai',  'id': 'STAF-009',   'dept': 'Admin', 'initials': 'AP', 'color': '#dc2626,#7f1d1d'},
    {'name': 'Suresh Babu',    'id': 'SRN21CV007', 'dept': 'CV',    'initials': 'SB', 'color': '#059669,#064e3b'},
  ];

  static const _gates = ['Main Gate','East Entrance','Library','Admin Block','Sports Complex'];

  @override
  void initState() {
    super.initState();
    _seed();
    _startLive();
  }

  @override
  void dispose() { _liveTimer?.cancel(); super.dispose(); }

  void _seed() {
    final seeds = [
      ['entry',0],['entry',1],['exit',2],['entry',3],['entry',4],['exit',5],['denied',6],['entry',7],['exit',8],
    ];
    for (final s in seeds.reversed) {
      _addRow(s[1] as int, s[0] as String);
    }
  }

  void _startLive() {
    final delay = 3500 + _rng.nextInt(4000);
    _liveTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      final idx = _rng.nextInt(_people.length);
      final r = _rng.nextDouble();
      final type = r < .6 ? 'entry' : r < .88 ? 'exit' : 'denied';
      setState(() => _addRow(idx, type));
      _startLive();
    });
  }

  void _addRow(int pIdx, String type) {
    final p = _people[pIdx % _people.length];
    final conf = type == 'denied'
        ? 55 + _rng.nextDouble() * 25
        : 85 + _rng.nextDouble() * 14.9;
    _confVals.add(conf);
    if (_confVals.length > 30) _confVals.removeAt(0);
    _avgConf = _confVals.reduce((a, b) => a + b) / _confVals.length;

    _rows.insert(0, _Row(
      name: p['name']!, id: p['id']!, dept: p['dept']!,
      initials: p['initials']!, color: p['color']!,
      gate: _gates[_rng.nextInt(_gates.length)],
      time: DateTime.now(), type: type, conf: conf,
    ));
    if (_rows.length > 50) _rows.removeLast();

    if (type == 'entry') _entryCount++;
    else if (type == 'exit') _exitCount++;
    else _deniedCount++;
  }

  List<_Row> get _filtered => _rows.where((r) {
    final matchSearch = r.name.toLowerCase().contains(_search.toLowerCase()) ||
        r.id.toLowerCase().contains(_search.toLowerCase());
    final matchType = _typeFilter == 'all' || r.type == _typeFilter;
    final matchGate = _gateFilter == 'all' || r.gate == _gateFilter;
    return matchSearch && matchType && matchGate;
  }).toList();

  Color _hexColor(String hex) {
    try { return Color(int.parse(hex.trim().replaceAll('#', '0xFF'))); }
    catch (_) { return GeoColors.primary; }
  }

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}:${d.second.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final filtered = _filtered;

    return AdminShell(
      activeRoute: '/admin/entries',
      breadcrumb: 'Entry History',
      pageTitle: 'Entry & Exit History',
      topbarActions: [
        const LiveBadge(),
        const SizedBox(width: 8),
        _topBtn('⬇ Export CSV', theme),
        const SizedBox(width: 8),
        _topBtn('↺ Refresh', theme),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Entry & Exit History', style: GoogleFonts.inter(
            fontSize: 22, fontWeight: FontWeight.w800, color: theme.textPrimary)),
          const SizedBox(height: 4),
          Text('Live log of all campus gate events. Auto-updating in real-time.',
            style: GoogleFonts.inter(fontSize: 13, color: theme.textSecondary)),
          const SizedBox(height: 16),

          // Stats
          Row(children: [
            Expanded(child: StatCard(theme: theme, icon: '→', value: '$_entryCount',
              label: 'Total Entries', trend: '▲ 12%', trendUp: true)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(theme: theme, icon: '↩', value: '$_exitCount',
              label: 'Total Exits', trend: 'Today')),
            const SizedBox(width: 12),
            Expanded(child: StatCard(theme: theme, icon: '🚫', value: '$_deniedCount',
              label: 'Access Denied', trend: '▲ 2', trendUp: false,
              iconBg: GeoColors.dangerGhost)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(theme: theme, icon: '✓',
              value: '${_avgConf.toStringAsFixed(1)}%',
              label: 'Avg Confidence', trend: '▲ 1.2%', trendUp: true,
              iconBg: GeoColors.successGhost)),
          ]),
          const SizedBox(height: 20),

          // Table
          Container(
            decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
              borderRadius: BorderRadius.circular(GeoRadius.lg)),
            child: Column(children: [
              // Table header/filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(children: [
                  Text('📋 Live Entry Log', style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: theme.bgBadge, borderRadius: BorderRadius.circular(GeoRadius.full)),
                    child: Text('${filtered.length} records', style: GoogleFonts.inter(
                      fontSize: 11, color: theme.textSecondary))),
                  const Spacer(),
                  // Search
                  SizedBox(width: 200, child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: GoogleFonts.inter(fontSize: 12, color: theme.textPrimary),
                    decoration: InputDecoration(
                      hintText: '🔍 Search name or ID…',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: theme.textTertiary),
                      filled: true, fillColor: theme.bgInput,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(GeoRadius.sm),
                        borderSide: BorderSide(color: theme.border)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(GeoRadius.sm),
                        borderSide: BorderSide(color: theme.border))),
                  )),
                  const SizedBox(width: 8),
                  _filterDrop(theme, _typeFilter, ['all','entry','exit','denied'],
                    ['All Types','Entry','Exit','Denied'], (v) => setState(() => _typeFilter = v!)),
                  const SizedBox(width: 8),
                  _filterDrop(theme, _gateFilter, ['all',..._gates],
                    ['All Gates',..._gates], (v) => setState(() => _gateFilter = v!)),
                ]),
              ),
              Divider(height: 1, color: theme.border),

              // Column headers
              Container(
                color: theme.bgBadge,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  _th(theme, '#', 40),
                  _th(theme, 'Person', 180),
                  _th(theme, 'Dept', 80),
                  _th(theme, 'Gate', 130),
                  _th(theme, 'Time', 90),
                  _th(theme, 'Type', 90),
                  _th(theme, 'Conf.', 70),
                  _th(theme, 'Action', 90),
                ]),
              ),
              Divider(height: 2, color: theme.border),

              // Rows
              ...filtered.asMap().entries.map((e) {
                final r = e.value;
                final colors = r.color.split(',');
                final conf = r.conf;
                final confColor = r.type == 'denied' ? GeoColors.danger
                    : conf >= 90 ? GeoColors.success
                    : conf >= 75 ? GeoColors.warning : GeoColors.danger;
                return Container(
                  decoration: BoxDecoration(border: Border(
                    bottom: BorderSide(color: theme.border))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      SizedBox(width: 40, child: Text(
                        (filtered.length - e.key).toString().padLeft(3, '0'),
                        style: GoogleFonts.inter(fontSize: 12, color: theme.textTertiary, fontWeight: FontWeight.w600))),
                      SizedBox(width: 180, child: Row(children: [
                        AvatarCircle(initials: r.initials, size: 34, fontSize: 11,
                          gradient: [_hexColor(colors[0]), _hexColor(colors.length > 1 ? colors[1] : colors[0])]),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary), overflow: TextOverflow.ellipsis),
                          Text(r.id, style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary)),
                        ])),
                      ])),
                      SizedBox(width: 80, child: Text(r.dept, style: GoogleFonts.inter(fontSize: 13, color: theme.textPrimary))),
                      SizedBox(width: 130, child: Text('📍 ${r.gate}', style: GoogleFonts.inter(fontSize: 13, color: theme.textPrimary), overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 90, child: Text(_fmtTime(r.time), style: GoogleFonts.inter(fontSize: 13, color: theme.textPrimary))),
                      SizedBox(width: 90, child: _typeBadge(theme, r.type)),
                      SizedBox(width: 70, child: Text('${conf.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: confColor))),
                      SizedBox(width: 90, child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            border: Border.all(color: GeoColors.primaryGhost),
                            borderRadius: BorderRadius.circular(GeoRadius.sm)),
                          child: Text('View Profile', style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w600, color: GeoColors.primary))))),
                    ]),
                  ),
                );
              }),

              // Footer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(children: [
                  Text('Showing latest ${filtered.length} entries',
                    style: GoogleFonts.inter(fontSize: 12, color: theme.textTertiary)),
                  const Spacer(),
                  Text('Total: ${_rows.length} records',
                    style: GoogleFonts.inter(fontSize: 12, color: theme.textTertiary)),
                ])),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _th(ThemeNotifier theme, String label, double w) => SizedBox(
    width: w,
    child: Text(label.toUpperCase(), style: GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: theme.textTertiary, letterSpacing: .6)));

  Widget _typeBadge(ThemeNotifier theme, String type) {
    Color bg, fg;
    String label;
    if (type == 'entry') { bg = GeoColors.successGhost; fg = const Color(0xFF16A34A); label = '→ Entry'; }
    else if (type == 'exit') { bg = const Color(0x1A6366F1); fg = const Color(0xFF6366F1); label = '↩ Exit'; }
    else { bg = GeoColors.dangerGhost; fg = GeoColors.danger; label = '🚫 Denied'; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(GeoRadius.full)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: fg)));
  }

  Widget _topBtn(String label, ThemeNotifier theme) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
      borderRadius: BorderRadius.circular(GeoRadius.sm)),
    child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: theme.textSecondary)));

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

class _Row {
  final String name, id, dept, initials, color, gate, type;
  final DateTime time;
  final double conf;
  const _Row({required this.name, required this.id, required this.dept,
    required this.initials, required this.color, required this.gate,
    required this.time, required this.type, required this.conf});
}
