import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';

// ── USER SHELL (topbar + nav) ────────────────────────────────────────
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
            IconButton(
              icon: Icon(theme.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: theme.textSecondary),
              onPressed: () => context.read<ThemeNotifier>().toggle(),
            ),
          ]),
        ),
        Divider(height: 1, color: theme.border),

        // Desktop nav
        if (MediaQuery.of(context).size.width > 600)
          Container(
            color: theme.bgCard,
            child: Row(children: [
              _navItem(context, theme, Icons.person_outline, 'Profile',      '/user/profile',     activeIndex == 0),
              _navItem(context, theme, Icons.history,         'My Entries',  '/user/entries',     activeIndex == 1),
              _navItem(context, theme, Icons.face_retouching_natural, 'Face Enrolment', '/user/face-enrol', activeIndex == 2),
            ]),
          ),

        Expanded(child: body),
      ]),

      // Mobile bottom nav
      bottomNavigationBar: MediaQuery.of(context).size.width <= 600
          ? _buildBottomNav(context, theme)
          : null,
    );
  }

  Widget _navItem(BuildContext context, ThemeNotifier theme, IconData icon, String label, String route, bool active) =>
    GestureDetector(
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: active ? BoxDecoration(
          border: Border(bottom: BorderSide(color: GeoColors.primary, width: 2))) : null,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: active ? GeoColors.primary : theme.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: active ? GeoColors.primary : theme.textSecondary)),
        ]),
      ));

  Widget _buildBottomNav(BuildContext context, ThemeNotifier theme) => Container(
    decoration: BoxDecoration(
      color: theme.bgCard,
      border: Border(top: BorderSide(color: theme.border))),
    child: SafeArea(child: Row(children: [
      _bottomItem(context, theme, Icons.person_outline,            'Profile',  '/user/profile',  activeIndex == 0),
      _bottomItem(context, theme, Icons.history,                   'Entries',  '/user/entries',  activeIndex == 1),
      _bottomItem(context, theme, Icons.face_retouching_natural,  'Face ID',  '/user/face-enrol', activeIndex == 2),
      _bottomLogout(context, theme),
    ])));

  Widget _bottomItem(BuildContext context, ThemeNotifier theme, IconData icon, String label,
      String route, bool active) =>
    Expanded(child: GestureDetector(
      onTap: () => context.go(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: active ? GeoColors.primary : theme.textTertiary),
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
          Icon(Icons.logout, size: 22, color: theme.textTertiary),
          const SizedBox(height: 2),
          Text('Logout', style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w600, color: theme.textTertiary)),
        ])),
    ));
}

// ── USER PROFILE SCREEN ──────────────────────────────────────────────
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});
  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _editOpen    = false;
  bool _loading     = true;
  int  _entryCount  = 0;
  int  _daysSince   = 0;

  // Edit fields
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _editDept = '', _editYear = '';
  bool _saving = false;

  @override
  void initState() { super.initState(); _loadData(); }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    final auth = context.read<AuthService>();
    final email = auth.userEmail;
    if (email == null) return;
    try {
      final logs = await auth.backend.getUserEntryLogs(email);
      final user = auth.userData;
      final days = user?['joined_at'] != null
          ? DateTime.now().difference(DateTime.parse(user!['joined_at'] as String)).inDays
          : 0;
      if (mounted) setState(() {
        _entryCount = logs.length;
        _daysSince  = days;
        _loading    = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEdit() {
    final user = context.read<AuthService>().userData!;
    _nameCtrl.text  = user['name'] ?? '';
    _phoneCtrl.text = user['phone'] ?? '';
    _editDept = user['dept'] ?? '';
    _editYear = user['year'] ?? '';
    setState(() => _editOpen = true);
  }

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty) {
      GeoToast.show(context, 'Please enter your name.', type: 'error');
      return;
    }
    setState(() => _saving = true);
    await context.read<AuthService>().updateProfile(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      dept: _editDept,
      year: _editYear,
    );
    if (mounted) {
      setState(() { _editOpen = false; _saving = false; });
      GeoToast.show(context, 'Profile updated.', type: 'success');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final auth  = context.watch<AuthService>();
    final user  = auth.userData;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const SizedBox();
    }

    final name      = user['name'] as String? ?? 'User';
    final email     = user['email'] as String? ?? '';
    final dept      = user['dept'] as String? ?? '';
    final year      = user['year'] as String? ?? '';
    final studentId = user['student_id'] as String? ?? '';
    final phone     = user['phone'] as String? ?? '';
    final enrolled  = user['face_enrolled'] == true;
    final joinedAt  = user['joined_at'] as String?;
    final initials  = name.trim().split(' ')
        .where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();

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
                  Container(
                    width: 90, height: 90,
                    decoration: const BoxDecoration(shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)),
                    child: Center(child: Text(initials, style: GoogleFonts.inter(
                      fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)))),
                  Positioned(bottom: 0, right: 0, child: GestureDetector(
                    onTap: _openEdit,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: GeoColors.primary, shape: BoxShape.circle,
                        border: Border.all(color: theme.bgCard, width: 2)),
                      child: const Center(child: Icon(Icons.edit, size: 13, color: Colors.white))))),
                ]),
                const SizedBox(height: 12),
                Text(name, style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800, color: theme.textPrimary)),
                if (dept.isNotEmpty || year.isNotEmpty)
                  Text('$dept${dept.isNotEmpty && year.isNotEmpty ? " — " : ""}$year',
                    style: GoogleFonts.inter(fontSize: 13, color: theme.textSecondary)),
                const SizedBox(height: 12),
                // Badges
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (studentId.isNotEmpty) ...[
                    _badge(theme, studentId, Icons.badge_outlined),
                    const SizedBox(width: 8),
                  ],
                  enrolled
                    ? _statusBadge(GeoColors.successGhost, GeoColors.success, Icons.check_circle_outline, 'Face Enrolled')
                    : _statusBadge(GeoColors.warningGhost, GeoColors.warning, Icons.pending_outlined, 'Face Pending'),
                ]),
              ]),
            ),
            const SizedBox(height: 16),

            // Stats
            _loading
              ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
              : Row(children: [
                  Expanded(child: _statChip(theme, '$_entryCount', 'Entries')),
                  const SizedBox(width: 12),
                  Expanded(child: _statChip(theme, enrolled ? 'Active' : 'Pending', 'Face ID')),
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
                _infoRow(theme, Icons.email_outlined,   'Email',       email),
                _infoRow(theme, Icons.phone_outlined,   'Phone',       phone.isEmpty ? '—' : phone),
                _infoRow(theme, Icons.school_outlined,  'Department',  dept.isEmpty ? '—' : dept),
                _infoRow(theme, Icons.calendar_today_outlined, 'Year', year.isEmpty ? '—' : year),
                _infoRow(theme, Icons.event_outlined,   'Registered',
                  joinedAt != null ? _fmtDate(DateTime.parse(joinedAt)) : '—', last: true),
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
                _actionButton(theme, Icons.edit_outlined, 'Edit Profile', _openEdit),
                const SizedBox(height: 10),
                _actionButton(theme, Icons.face_retouching_natural,
                  enrolled ? 'Re-enrol Face Data' : 'Enrol Face Data',
                  () => context.go('/user/face-enrol'), outline: true),
                const SizedBox(height: 10),
                _actionButton(theme, Icons.logout, 'Sign Out',
                  () async {
                    await context.read<AuthService>().logout();
                    if (mounted) context.go('/');
                  }, outline: true, danger: true),
              ])),
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
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                icon: _saving ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(_saving ? 'Saving...' : 'Save Changes'),
                onPressed: _saving ? null : _saveProfile,
              )),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: OutlinedButton(
                onPressed: () => setState(() => _editOpen = false),
                child: const Text('Cancel'),
              )),
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

  Widget _badge(ThemeNotifier theme, String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(color: theme.bgBadge, borderRadius: BorderRadius.circular(GeoRadius.full)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: theme.textSecondary),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSecondary)),
    ]));

  Widget _statusBadge(Color bg, Color fg, IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(GeoRadius.full)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: fg),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    ]));

  Widget _statChip(ThemeNotifier theme, String val, String label) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: theme.bgCard, border: Border.all(color: theme.border),
      borderRadius: BorderRadius.circular(GeoRadius.lg)),
    child: Column(children: [
      Text(val, style: GoogleFonts.inter(
        fontSize: 22, fontWeight: FontWeight.w800, color: theme.textPrimary)),
      Text(label, style: GoogleFonts.inter(fontSize: 12, color: theme.textSecondary)),
    ]));

  Widget _sectionTitle(ThemeNotifier theme, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Align(alignment: Alignment.centerLeft,
      child: Text(title, style: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary))));

  Widget _infoRow(ThemeNotifier theme, IconData icon, String label, String value,
      {bool last = false}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: theme.border))),
      child: Row(children: [
        Icon(icon, size: 18, color: theme.textTertiary),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: theme.textTertiary)),
          Text(value, style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: theme.textPrimary)),
        ]),
      ]));

  Widget _actionButton(ThemeNotifier theme, IconData icon, String label, VoidCallback onTap,
      {bool outline = false, bool danger = false}) {
    if (!outline) {
      return SizedBox(width: double.infinity, child: ElevatedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label),
        onPressed: onTap,
      ));
    }
    if (danger) {
      return SizedBox(width: double.infinity, child: OutlinedButton.icon(
        icon: Icon(icon, size: 16, color: GeoColors.danger),
        label: Text(label, style: const TextStyle(color: GeoColors.danger)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: GeoColors.danger),
          foregroundColor: GeoColors.danger,
        ),
        onPressed: onTap,
      ));
    }
    return SizedBox(width: double.infinity, child: OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
    ));
  }

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month-1]} ${d.year}';
  }
}
