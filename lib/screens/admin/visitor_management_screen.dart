import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/backend_service.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/common_widgets.dart';

class VisitorManagementScreen extends StatefulWidget {
  const VisitorManagementScreen({super.key});
  @override
  State<VisitorManagementScreen> createState() => _VisitorManagementScreenState();
}

class _VisitorManagementScreenState extends State<VisitorManagementScreen> {
  late final BackendService _backend;
  List<dynamic> _visitors = [];
  bool _loading   = true;
  bool _showForm  = false;

  // Form controllers
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _hostCtrl    = TextEditingController();
  final _deptCtrl    = TextEditingController();
  final _idCtrl      = TextEditingController();
  String _gate = 'Main Gate';
  bool _submitting = false;

  static const _gates = ['Main Gate', 'East Entrance', 'North Gate', 'Admin Block Entry'];

  @override
  void initState() {
    super.initState();
    _backend = context.read<AuthService>().backend;
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _purposeCtrl.dispose(); _hostCtrl.dispose();
    _deptCtrl.dispose(); _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final visitors = await _backend.getVisitors();
    if (!mounted) return;
    setState(() { _visitors = visitors; _loading = false; });
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _purposeCtrl.text.trim().isEmpty) {
      GeoToast.show(context, 'Please fill in Name and Purpose.', type: 'error');
      return;
    }
    setState(() => _submitting = true);
    try {
      await _backend.addVisitor(
        name:     _nameCtrl.text.trim(),
        phone:    _phoneCtrl.text.trim(),
        purpose:  _purposeCtrl.text.trim(),
        host:     _hostCtrl.text.trim(),
        dept:     _deptCtrl.text.trim(),
        idNumber: _idCtrl.text.trim(),
        gate:     _gate,
      );
      _nameCtrl.clear(); _phoneCtrl.clear(); _purposeCtrl.clear();
      _hostCtrl.clear(); _deptCtrl.clear();  _idCtrl.clear();
      setState(() { _showForm = false; _submitting = false; });
      GeoToast.show(context, 'Visitor checked in.', type: 'success');
      _load();
    } catch (e) {
      setState(() => _submitting = false);
      GeoToast.show(context, 'Error: $e', type: 'error');
    }
  }

  Future<void> _checkout(int id) async {
    await _backend.checkoutVisitor(id);
    _load();
    GeoToast.show(context, 'Visitor checked out.', type: 'success');
  }

  int get _active  => _visitors.where((v) => v['status'] == 'On Campus').length;
  int get _exited  => _visitors.where((v) => v['status'] == 'Exited').length;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();

    return AdminShell(
      activeRoute: '/admin/visitors',
      breadcrumb: 'Visitor Management',
      pageTitle: 'Visitor Management',
      topbarActions: [
        _topBtn(theme, Icons.person_add_outlined, 'Add Visitor',
          () => setState(() => _showForm = !_showForm)),
        const SizedBox(width: 8),
        _topBtn(theme, Icons.refresh_outlined, 'Refresh', _load),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Visitor Management', style: GoogleFonts.inter(
            fontSize: 22, fontWeight: FontWeight.w800, color: theme.textPrimary)),
          const SizedBox(height: 4),
          Text('Register new visitors and manage campus guest access.',
            style: GoogleFonts.inter(fontSize: 13, color: theme.textSecondary)),
          const SizedBox(height: 20),

          // Stats
          Row(children: [
            Expanded(child: StatCard(theme: theme, icon: 'A', value: '$_active',
              label: 'On Campus Now', trend: 'Today', trendUp: true, iconBg: GeoColors.successGhost)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(theme: theme, icon: 'T', value: '${_visitors.length}',
              label: 'Total Today')),
            const SizedBox(width: 12),
            Expanded(child: StatCard(theme: theme, icon: 'E', value: '$_exited',
              label: 'Exited Today', iconBg: theme.bgBadge, trendUp: false)),
          ]),
          const SizedBox(height: 20),

          // Add visitor form (toggle)
          if (_showForm) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(GeoRadius.lg)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.person_add_outlined, size: 18, color: GeoColors.primary),
                  const SizedBox(width: 8),
                  Text('Register Visitor', style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w800, color: theme.textPrimary)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showForm = false),
                    color: theme.textTertiary),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _field(theme, 'Full Name *', _nameCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(theme, 'Phone Number', _phoneCtrl, type: TextInputType.phone)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(theme, 'Purpose of Visit *', _purposeCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(theme, 'Host / Meeting With', _hostCtrl)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(theme, 'Department / Destination', _deptCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(theme, 'Govt. ID Number', _idCtrl)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Entry Gate', style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700, color: theme.textTertiary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _gate,
                      dropdownColor: theme.bgCard,
                      style: GoogleFonts.inter(color: theme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true, fillColor: theme.bgInput,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(GeoRadius.md),
                          borderSide: BorderSide(color: theme.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
                      items: _gates.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (v) => setState(() => _gate = v!)),
                  ])),
                ]),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  icon: _submitting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.login, size: 16),
                  label: Text(_submitting ? 'Checking in...' : 'Check In Visitor'),
                  onPressed: _submitting ? null : _submit,
                )),
              ]),
            ),
            const SizedBox(height: 20),
          ],

          // Visitor list
          Container(
            decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
              borderRadius: BorderRadius.circular(GeoRadius.lg)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.people_outline, size: 16, color: GeoColors.primary),
                  const SizedBox(width: 8),
                  Text('Visitors', style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: theme.bgBadge,
                      borderRadius: BorderRadius.circular(GeoRadius.full)),
                    child: Text('$_active on campus · ${_visitors.length} total',
                      style: GoogleFonts.inter(fontSize: 11, color: theme.textSecondary))),
                ])),
              Divider(height: 1, color: theme.border),

              // Table header
              Container(
                color: theme.bgBadge,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  _th(theme, '#',        40),
                  _th(theme, 'Visitor',  180),
                  _th(theme, 'Purpose',  130),
                  _th(theme, 'Host',     140),
                  _th(theme, 'Gate',     120),
                  _th(theme, 'Check-in', 90),
                  _th(theme, 'Status',   100),
                  _th(theme, 'Action',   110),
                ])),
              Divider(height: 1, color: theme.border),

              if (_loading)
                const Padding(padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: GeoColors.primary)))
              else if (_visitors.isEmpty)
                Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: [
                  const Icon(Icons.badge_outlined, size: 40, color: GeoColors.success),
                  const SizedBox(height: 12),
                  Text('No visitors today.', style: GoogleFonts.inter(
                    fontSize: 13, color: theme.textTertiary)),
                ])))
              else
                ..._visitors.asMap().entries.map((entry) {
                  final i = entry.key;
                  final v = entry.value as Map<String, dynamic>;
                  final name      = v['name']     as String? ?? '—';
                  final phone     = v['phone']    as String? ?? '';
                  final purpose   = v['purpose']  as String? ?? '—';
                  final host      = v['host']     as String? ?? '—';
                  final gate      = v['gate']     as String? ?? '—';
                  final status    = v['status']   as String? ?? 'On Campus';
                  final idnum     = v['id_number'] as String? ?? '';
                  final checkinRaw = v['checkin_at'] as String? ?? '';
                  final checkinFmt = checkinRaw.isNotEmpty
                      ? () { final d = DateTime.parse(checkinRaw).toLocal();
                          return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}'; }()
                      : '--:--';
                  final initials = name.trim().split(' ')
                      .where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();
                  final onCampus = status == 'On Campus';
                  final statusBg = onCampus ? GeoColors.successGhost : theme.bgBadge;
                  final statusFg = onCampus ? GeoColors.success : theme.textTertiary;

                  return Container(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.border))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        SizedBox(width: 40, child: Text((i+1).toString().padLeft(2,'0'),
                          style: GoogleFonts.inter(fontSize: 12, color: theme.textTertiary,
                            fontWeight: FontWeight.w600))),
                        SizedBox(width: 180, child: Row(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: GeoColors.avatarGradients[name.hashCode.abs() % GeoColors.avatarGradients.length],
                                begin: Alignment.topLeft, end: Alignment.bottomRight)),
                            child: Center(child: Text(initials, style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)))),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: GoogleFonts.inter(fontSize: 13,
                              fontWeight: FontWeight.w600, color: theme.textPrimary),
                              overflow: TextOverflow.ellipsis),
                            Text(idnum.isNotEmpty ? idnum : (phone.isNotEmpty ? phone : '—'),
                              style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary),
                              overflow: TextOverflow.ellipsis),
                          ])),
                        ])),
                        SizedBox(width: 130, child: Text(purpose, style: GoogleFonts.inter(
                          fontSize: 12, color: theme.textPrimary), overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 140, child: Text(host, style: GoogleFonts.inter(
                          fontSize: 12, color: theme.textPrimary), overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 120, child: Text(gate, style: GoogleFonts.inter(
                          fontSize: 12, color: theme.textPrimary), overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 90, child: Text(checkinFmt, style: GoogleFonts.inter(
                          fontSize: 12, color: theme.textPrimary))),
                        SizedBox(width: 100, child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: statusBg,
                            borderRadius: BorderRadius.circular(GeoRadius.full)),
                          child: Text(status, style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700, color: statusFg)))),
                        SizedBox(width: 110, child: onCampus
                            ? GestureDetector(
                                onTap: () => _checkout(v['id'] as int),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: GeoColors.danger),
                                    borderRadius: BorderRadius.circular(GeoRadius.sm)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.logout, size: 12, color: GeoColors.danger),
                                    const SizedBox(width: 4),
                                    Text('Check Out', style: GoogleFonts.inter(
                                      fontSize: 11, fontWeight: FontWeight.w600, color: GeoColors.danger)),
                                  ])))
                            : Text('Exited', style: GoogleFonts.inter(
                                fontSize: 11, color: theme.textTertiary))),
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

  Widget _field(ThemeNotifier theme, String label, TextEditingController ctrl,
      {TextInputType? type}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w700, color: theme.textTertiary)),
    const SizedBox(height: 6),
    TextField(controller: ctrl, keyboardType: type,
      style: GoogleFonts.inter(fontSize: 14, color: theme.textPrimary),
      decoration: InputDecoration(
        filled: true, fillColor: theme.bgInput,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(GeoRadius.md),
          borderSide: BorderSide(color: theme.border)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13))),
  ]);

  Widget _th(ThemeNotifier theme, String label, double w) => SizedBox(width: w,
    child: Text(label.toUpperCase(), style: GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w700, color: theme.textTertiary, letterSpacing: .5)));

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
          Text(label, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w500, color: theme.textSecondary)),
        ])));
}
