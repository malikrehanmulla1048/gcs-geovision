import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../models/entry_log.dart';
import '../../widgets/common_widgets.dart';
import 'profile_screen.dart';

class MyEntriesScreen extends StatefulWidget {
  const MyEntriesScreen({super.key});
  @override
  State<MyEntriesScreen> createState() => _MyEntriesScreenState();
}

class _MyEntriesScreenState extends State<MyEntriesScreen> {
  final _db = DbService();
  List<EntryLog> _all = [];
  String _filter = 'all';
  bool _loading  = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;
    try {
      final userLogs = await _db.getEntryLogsByUser(user.email);
      final allLogs  = await _db.getAllEntryLogs();
      final display  = userLogs.isNotEmpty ? userLogs : allLogs;
      display.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted) setState(() { _all = display; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<EntryLog> get _filtered => _filter == 'all' ? _all
      : _filter == 'exit'
          ? _all.where((e) => e.type == 'exit').toList()
          : _all.where((e) => e.type != 'exit').toList();

  int get _entries => _all.where((e) => e.type != 'exit').length;
  int get _exits   => _all.where((e) => e.type == 'exit').length;

  String _month(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m - 1];
  }

  String _dayLabel(DateTime d) {
    const days   = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    const months = ['January','February','March','April','May','June',
                    'July','August','September','October','November','December'];
    return '${days[d.weekday % 7]}, ${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme    = context.watch<ThemeNotifier>();
    final filtered = _filtered;

    // Group by date
    final Map<String, List<EntryLog>> groups = {};
    for (final e in filtered) {
      final key = _dayLabel(e.timestamp);
      groups.putIfAbsent(key, () => []).add(e);
    }

    return UserShell(
      activeIndex: 1,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title
          Text('🚪 Entry History', style: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w800, color: theme.textPrimary)),
          const SizedBox(height: 3),
          Text('Your campus gate entries and exits', style: GoogleFonts.inter(
            fontSize: 13, color: theme.textTertiary)),
          const SizedBox(height: 16),

          // Stats chips
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

          // Content
          if (_loading)
            Center(child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(children: [
                const Text('⏳', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text('Loading your entries…', style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: theme.textTertiary)),
              ]),
            ))
          else if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(GeoRadius.lg)),
              child: Center(child: Column(children: [
                const Text('📭', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text('No entries found for this filter.', style: GoogleFonts.inter(
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
                        color: theme.textTertiary, letterSpacing: .5)),
                    ),
                    ...group.value.map((e) => _entryItem(theme, e)),
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

  Widget _entryItem(ThemeNotifier theme, EntryLog e) {
    final isEntry  = e.type != 'exit';
    final dotColor = isEntry ? GeoColors.success : const Color(0xFF6366F1);
    final typeLabel = isEntry ? '→ Entry' : '← Exit';
    final time = '${e.timestamp.hour.toString().padLeft(2,"0")}:${e.timestamp.minute.toString().padLeft(2,"0")}';
    final conf = e.confidence != null ? ' · ${e.confidence!.toStringAsFixed(1)}%' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('📍 ${e.gate}', style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary)),
          Text('$time$conf', style: GoogleFonts.inter(
            fontSize: 11, color: theme.textTertiary)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: dotColor.withOpacity(.1),
            borderRadius: BorderRadius.circular(GeoRadius.full)),
          child: Text(typeLabel, style: GoogleFonts.inter(
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
          border: Border.all(
            color: active ? GeoColors.primary.withOpacity(.25) : theme.border),
          borderRadius: BorderRadius.circular(GeoRadius.full)),
        child: Text(label, style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: active ? GeoColors.primary : theme.textSecondary))));
  }
}
