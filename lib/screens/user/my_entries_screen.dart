import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';
import 'profile_screen.dart';

class MyEntriesScreen extends StatefulWidget {
  const MyEntriesScreen({super.key});
  @override
  State<MyEntriesScreen> createState() => _MyEntriesScreenState();
}

class _MyEntriesScreenState extends State<MyEntriesScreen> {
  List<dynamic> _all = [];
  String _filter = 'all';
  bool _loading  = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final auth  = context.read<AuthService>();
    final email = auth.userEmail;
    if (email == null) return;
    try {
      final logs = await auth.backend.getUserEntryLogs(email);
      if (mounted) setState(() { _all = logs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    if (_filter == 'all') return _all;
    return _all.where((e) => (e['type'] as String?) == _filter).toList();
  }

  int get _entries => _all.where((e) => e['type'] == 'entry').length;
  int get _exits   => _all.where((e) => e['type'] == 'exit').length;

  @override
  Widget build(BuildContext context) {
    final theme    = context.watch<ThemeNotifier>();
    final filtered = _filtered;

    // Group by date
    final Map<String, List<dynamic>> groups = {};
    for (final e in filtered) {
      final ts  = e['timestamp'] as String? ?? '';
      final key = ts.isNotEmpty
          ? () { final d = DateTime.parse(ts).toLocal();
              const days = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
              const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
              return '${days[d.weekday % 7]}, ${d.day} ${months[d.month-1]}'; }()
          : 'Unknown Date';
      groups.putIfAbsent(key, () => []).add(e);
    }

    return UserShell(
      activeIndex: 1,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Entry History', style: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w800, color: theme.textPrimary)),
          const SizedBox(height: 3),
          Text('Your campus gate entries and exits', style: GoogleFonts.inter(
            fontSize: 13, color: theme.textTertiary)),
          const SizedBox(height: 16),

          // Stats
          Row(children: [
            _statChip(theme, '${_all.length}', 'Total'),
            const SizedBox(width: 12),
            _statChip(theme, '$_entries', 'Entries'),
            const SizedBox(width: 12),
            _statChip(theme, '$_exits', 'Exits'),
          ]),
          const SizedBox(height: 16),

          // Filter chips
          Row(children: [
            _filterChip(theme, 'All',          'all'),
            const SizedBox(width: 8),
            _filterChip(theme, 'Entries Only', 'entry'),
            const SizedBox(width: 8),
            _filterChip(theme, 'Exits Only',   'exit'),
          ]),
          const SizedBox(height: 16),

          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: GeoColors.primary)))
          else if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(GeoRadius.lg)),
              child: Center(child: Column(children: [
                Icon(Icons.history_outlined, size: 40, color: theme.textTertiary),
                const SizedBox(height: 12),
                Text('No entries found.', style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: theme.textTertiary)),
              ])))
          else
            Container(
              decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(GeoRadius.lg)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final group in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                      child: Text(group.key.toUpperCase(), style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: theme.textTertiary, letterSpacing: .5))),
                    ...group.value.map((e) => _entryItem(theme, e as Map<String, dynamic>)),
                  ],
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _entryItem(ThemeNotifier theme, Map<String, dynamic> e) {
    final type    = e['type']  as String? ?? 'entry';
    final gate    = e['gate']  as String? ?? 'Gate';
    final ts      = e['timestamp'] as String? ?? '';
    final conf    = (e['confidence'] as num?)?.toDouble();
    final isEntry = type == 'entry';
    final dotColor = isEntry ? GeoColors.success : const Color(0xFF6366F1);
    final label   = isEntry ? 'Entry' : type == 'exit' ? 'Exit' : 'Denied';
    final time    = ts.isNotEmpty
        ? () { final d = DateTime.parse(ts).toLocal();
            return '${d.hour.toString().padLeft(2,"0")}:${d.minute.toString().padLeft(2,"0")}'; }()
        : '--:--';
    final confStr = conf != null ? ' · ${conf.toStringAsFixed(1)}%' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(gate, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary)),
          Text('$time$confStr', style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: dotColor.withOpacity(.1),
            borderRadius: BorderRadius.circular(GeoRadius.full)),
          child: Text(label, style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600, color: dotColor))),
      ]),
    );
  }

  Widget _statChip(ThemeNotifier theme, String val, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(GeoRadius.lg)),
      child: Column(children: [
        Text(val, style: GoogleFonts.inter(
          fontSize: 22, fontWeight: FontWeight.w800, color: theme.textPrimary)),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: theme.textSecondary)),
      ])));

  Widget _filterChip(ThemeNotifier theme, String label, String value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? GeoColors.primary.withOpacity(.12) : theme.bgCard,
          border: Border.all(color: active ? GeoColors.primary.withOpacity(.25) : theme.border),
          borderRadius: BorderRadius.circular(GeoRadius.full)),
        child: Text(label, style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: active ? GeoColors.primary : theme.textSecondary))));
  }
}
