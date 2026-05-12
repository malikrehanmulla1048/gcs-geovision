import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../models/entry_log.dart';
import '../../widgets/common_widgets.dart';

// ── USER SHELL (topbar + bottom nav) ────────────────────────────────────
class UserShell extends StatelessWidget {
  final int activeIndex; // 0=Profile, 1=Entries, 2=FaceID
  final Widget body;
  const UserShell({super.key, required this.activeIndex, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    return Scaffold(
      backgroundColor: theme.bgBody,
      body: Column(children: [
        // Topbar
        Container(
          color: theme.bgCard,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 20, right: 20, bottom: 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => context.go('/'),
              child: Image.asset('assets/logo.png', height: 40,
                errorBuilder: (_, __, ___) => RichText(text: TextSpan(children: [
                  TextSpan(text: 'Geo', style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w900, color: GeoColors.primary)),
                  TextSpan(text: 'Vision', style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w900, color: theme.textPrimary)),
                ]))),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => context.read<ThemeNotifier>().toggle(),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: theme.bgBadge, shape: BoxShape.circle),
                child: Center(child: Text(theme.isDark ? '☀️' : '🌙',
                  style: const TextStyle(fontSize: 16))),
              ),
            ),
          ]),
        ),
        Divider(height: 1, color: theme.border),

        // Desktop nav (visible on wide)
        if (MediaQuery.of(context).size.width > 600)
          Container(
            color: theme.bgCard,
            child: Row(children: [
              _navItem(context, theme, '🙍 Profile', '/user/profile',     activeIndex == 0),
              _navItem(context, theme, '🚪 My Entries', '/user/entries',  activeIndex == 1),
              _navItem(context, theme, '🤳 Face Enrolment', '/user/face-enrol', activeIndex == 2),
            ]),
          ),

        Expanded(child: body),
      ]),

      // Bottom nav (visible on narrow)
      bottomNavigationBar: MediaQuery.of(context).size.width <= 600
          ? _buildBottomNav(context, theme)
          : null,
    );
  }

  Widget _navItem(BuildContext context, ThemeNotifier theme, String label, String route, bool active) =>
    GestureDetector(
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: active ? BoxDecoration(
          border: Border(bottom: BorderSide(color: GeoColors.primary, width: 2))) : null,
        child: Text(label, style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: active ? GeoColors.primary : theme.textSecondary)),
      ));

  Widget _buildBottomNav(BuildContext context, ThemeNotifier theme) => Container(
    decoration: BoxDecoration(
      color: theme.bgCard,
      border: Border(top: BorderSide(color: theme.border))),
    child: SafeArea(child: Row(children: [
      _bottomItem(context, theme, '🙍', 'Profile',  '/user/profile',      activeIndex == 0),
      _bottomItem(context, theme, '🚪', 'Entries',  '/user/entries',      activeIndex == 1),
      _bottomItem(context, theme, '🤳', 'Face ID',  '/user/face-enrol',   activeIndex == 2),
      _bottomLogout(context, theme),
    ])));

  Widget _bottomItem(BuildContext context, ThemeNotifier theme, String icon, String label,
      String route, bool active) =>
    Expanded(child: GestureDetector(
      onTap: () => context.go(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: active ? GeoColors.primary : theme.textTertiary)),
        ])),
    ));

  Widget _bottomLogout(BuildContext context, ThemeNotifier theme) =>
    Expanded(child: GestureDetector(
      onTap: () async {
        await context.read<AuthService>().logout();
        if (context.mounted) context.go('/');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🚪', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text('Logout', style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w600, color: theme.textTertiary)),
        ])),
    ));
}

// ── USER PROFILE SCREEN ──────────────────────────────────────────────────
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});
  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _db = DbService();
  bool _editOpen = false;
  List<EntryLog> _logs = [];
  int _entryCount = 0, _daysSince = 0;

  // Edit fields
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _editDept = '', _editYear = '';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose();
  }

  Future<void> _loadEntries() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;
    try {
      final userLogs = await _db.getEntryLogsByUser(user.email);
      final allLogs  = await _db.getAllEntryLogs();
      final display  = userLogs.isNotEmpty ? userLogs : allLogs.take(5).toList();
      final days     = user.joinedAt != null
          ? DateTime.now().difference(user.joinedAt!).inDays : 0;
      if (mounted) setState(() {
        _logs = display; _entryCount = display.length; _daysSince = days;
      });
    } catch (e) { debugPrint('$e'); }
  }

  void _openEdit() {
    final user = context.read<AuthService>().currentUser!;
    _nameCtrl.text  = user.name;
    _phoneCtrl.text = user.phone ?? '';
    _editDept = user.dept ?? '';
    _editYear = user.year ?? '';
    setState(() => _editOpen = true);
  }

  Future<void> _saveProfile() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser!;
    if (_nameCtrl.text.trim().isEmpty) {
      GeoToast.show(context, 'Please enter your name.', type: 'error');
      return;
    }
    await auth.updateProfile(user.copyWith(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      dept: _editDept,
      year: _editYear,
    ));
    if (mounted) {
      setState(() => _editOpen = false);
      GeoToast.show(context, '✅ Profile updated!', type: 'success');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final auth  = context.watch<AuthService>();
    final user  = auth.currentUser;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const SizedBox();
    }

    return UserShell(
      activeIndex: 0,
      body: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Hero card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(GeoRadius.lg)),
              child: Column(children: [
                // Avatar
                Stack(children: [
                  user.pfp != null
                      ? CircleAvatar(radius: 45, backgroundImage: AssetImage(user.pfp!))
                      : Container(
                          width: 90, height: 90,
                          decoration: const BoxDecoration(shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight)),
                          child: Center(child: Text(user.initials, style: GoogleFonts.inter(
                            fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)))),
                  Positioned(bottom: 0, right: 0, child: GestureDetector(
                    onTap: _openEdit,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: GeoColors.primary, shape: BoxShape.circle,
                        border: Border.all(color: theme.bgCard, width: 2)),
                      child: const Center(child: Text('✏️', style: TextStyle(fontSize: 12)))))),
                ]),
                const SizedBox(height: 12),
                Text(user.name, style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800, color: theme.textPrimary)),
                Text('${user.dept ?? "GeoVision Campus"} • ${user.year ?? "Student"}',
                  style: GoogleFonts.inter(fontSize: 13, color: theme.textSecondary)),
                const SizedBox(height: 12),
                // Badges
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _badge(theme, '🪪 ${user.studentId ?? "N/A"}'),
                  const SizedBox(width: 8),
                  user.faceEnrolled
                      ? _enrolledBadge()
                      : _pendingBadge(),
                ]),
              ]),
            ),
            const SizedBox(height: 16),

            // Stats chips
            Row(children: [
              Expanded(child: _statChip(theme, '$_entryCount', 'Entries')),
              const SizedBox(width: 12),
              Expanded(child: _statChip(theme, user.faceEnrolled ? '✓' : '✗', 'Face ID')),
              const SizedBox(width: 12),
              Expanded(child: _statChip(theme, '$_daysSince', 'Days Since')),
            ]),
            const SizedBox(height: 20),

            // Personal info
            _sectionTitle(theme, 'Personal Information'),
            Container(
              decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(GeoRadius.lg)),
              child: Column(children: [
                _infoRow(theme, '📧', 'Email', user.email),
                _infoRow(theme, '📱', 'Phone', user.phone ?? '—'),
                _infoRow(theme, '🏫', 'Department', user.dept ?? '—'),
                _infoRow(theme, '📅', 'Year', user.year ?? '—'),
                _infoRow(theme, '🗓', 'Registered',
                  user.joinedAt != null ? _fmtDate(user.joinedAt!) : '—', last: true),
              ]),
            ),
            const SizedBox(height: 20),

            // Actions
            _sectionTitle(theme, 'Actions'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(GeoRadius.lg)),
              child: Column(children: [
                GeoButton(label: '✏️ Edit Profile', onPressed: _openEdit),
                const SizedBox(height: 10),
                GeoButton(
                  label: '🤳 ${user.faceEnrolled ? "Re-enrol" : "Enrol"} Face Data',
                  onPressed: () => context.go('/user/face-enrol'),
                  outline: true),
                const SizedBox(height: 10),
                GeoButton(
                  label: '🚪 Sign Out',
                  onPressed: () async {
                    await context.read<AuthService>().logout();
                    if (mounted) context.go('/');
                  },
                  outline: true, danger: true),
              ])),
            const SizedBox(height: 20),

            // Recent entries
            _sectionTitle(theme, 'Recent Campus Entries'),
            Container(
              decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(GeoRadius.lg)),
              child: _logs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(child: Text('No entry records yet.',
                        style: GoogleFonts.inter(fontSize: 13, color: theme.textTertiary))))
                  : Column(children: _logs.take(6).map((e) => _entryRow(theme, e)).toList()),
            ),
            const SizedBox(height: 80),
          ]),
        ),

        // Edit sheet overlay
        if (_editOpen) _buildEditSheet(theme),
      ]),
    );
  }

  Widget _buildEditSheet(ThemeNotifier theme) => GestureDetector(
    onTap: () => setState(() => _editOpen = false),
    child: Container(color: Colors.black.withOpacity(.7),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(color: theme.bgCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(
                width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: theme.border,
                  borderRadius: BorderRadius.circular(GeoRadius.full)))),
              Text('Edit Profile', style: GoogleFonts.inter(
                fontSize: 17, fontWeight: FontWeight.w800, color: theme.textPrimary)),
              const SizedBox(height: 20),
              _editField(theme, 'Full Name', _nameCtrl),
              const SizedBox(height: 14),
              _editField(theme, 'Phone Number', _phoneCtrl, type: TextInputType.phone),
              const SizedBox(height: 14),
              _editDropdown(theme, 'Department', _editDept,
                ['Computer Science & Engineering','Electronics & Communication',
                 'Mechanical Engineering','Civil Engineering','Business Administration','Other'],
                (v) => setState(() => _editDept = v!)),
              const SizedBox(height: 14),
              _editDropdown(theme, 'Year of Study', _editYear,
                ['1st Year','2nd Year','3rd Year','4th Year','PG / Faculty'],
                (v) => setState(() => _editYear = v!)),
              const SizedBox(height: 20),
              GeoButton(label: '💾 Save Changes', onPressed: _saveProfile),
              const SizedBox(height: 10),
              GeoButton(label: 'Cancel', onPressed: () => setState(() => _editOpen = false),
                outline: true),
            ])),
          ),
        ),
      ),
    ),
  );

  Widget _editField(ThemeNotifier theme, String label, TextEditingController ctrl,
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

  Widget _editDropdown(ThemeNotifier theme, String label, String value,
      List<String> options, ValueChanged<String?> onChanged) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w700, color: theme.textTertiary)),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        value: options.contains(value) ? value : null,
        hint: Text('Select…', style: GoogleFonts.inter(color: theme.textTertiary, fontSize: 14)),
        dropdownColor: theme.bgCard,
        style: GoogleFonts.inter(color: theme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          filled: true, fillColor: theme.bgInput,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(GeoRadius.md),
            borderSide: BorderSide(color: theme.border)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: onChanged),
    ]);

  Widget _badge(ThemeNotifier theme, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(color: theme.bgBadge, borderRadius: BorderRadius.circular(GeoRadius.full)),
    child: Text(label, style: GoogleFonts.inter(
      fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSecondary)));

  Widget _enrolledBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(color: GeoColors.successGhost, borderRadius: BorderRadius.circular(GeoRadius.full)),
    child: Text('✅ Face Enrolled', style: GoogleFonts.inter(
      fontSize: 12, fontWeight: FontWeight.w600, color: GeoColors.success)));

  Widget _pendingBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(color: GeoColors.warningGhost, borderRadius: BorderRadius.circular(GeoRadius.full)),
    child: Text('⏳ Face Pending', style: GoogleFonts.inter(
      fontSize: 12, fontWeight: FontWeight.w600, color: GeoColors.warning)));

  Widget _statChip(ThemeNotifier theme, String val, String label) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
      borderRadius: BorderRadius.circular(GeoRadius.lg)),
    child: Column(children: [
      Text(val, style: GoogleFonts.inter(
        fontSize: 24, fontWeight: FontWeight.w800, color: theme.textPrimary)),
      Text(label, style: GoogleFonts.inter(fontSize: 12, color: theme.textSecondary)),
    ]));

  Widget _sectionTitle(ThemeNotifier theme, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Align(alignment: Alignment.centerLeft,
      child: Text(title, style: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary))));

  Widget _infoRow(ThemeNotifier theme, String icon, String label, String value, {bool last = false}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: theme.border))),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary)),
          Text(value, style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: theme.textPrimary)),
        ]),
      ]));

  Widget _entryRow(ThemeNotifier theme, EntryLog e) {
    final isEntry = e.type != 'exit';
    final color   = isEntry ? GeoColors.success : const Color(0xFF6366F1);
    final time    = '${e.timestamp.day} ${_month(e.timestamp.month)}, ${e.timestamp.hour.toString().padLeft(2,"0")}:${e.timestamp.minute.toString().padLeft(2,"0")}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.border))),
      child: Row(children: [
        Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('📍 ${e.gate}', style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary)),
          Text(time, style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(GeoRadius.full)),
          child: Text(e.typeLabel, style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600, color: color))),
      ]));
  }

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month-1]} ${d.year}';
  }

  String _month(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m - 1];
  }
}
