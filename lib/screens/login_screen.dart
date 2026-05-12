import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _obscureLogin    = true;
  bool _obscureReg      = true;
  bool _obscureConfirm  = true;
  bool _loading         = false;
  String? _loginError;
  String? _regError;

  // Login fields
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Register fields
  final _fNameCtrl    = TextEditingController();
  final _lNameCtrl    = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regIdCtrl    = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regPwCtrl    = TextEditingController();
  final _regCfCtrl    = TextEditingController();
  String _dept        = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final auth = context.read<AuthService>();
    await auth.restoreSession();
    if (auth.isLoggedIn && mounted) {
      _navigate(auth.isAdmin);
    }
  }

  void _navigate(bool admin) {
    if (admin) context.go('/admin/dashboard');
    else       context.go('/user/profile');
  }

  @override
  void dispose() {
    _tabs.dispose();
    _emailCtrl.dispose(); _passwordCtrl.dispose();
    _fNameCtrl.dispose(); _lNameCtrl.dispose();
    _regEmailCtrl.dispose(); _regIdCtrl.dispose();
    _regPhoneCtrl.dispose(); _regPwCtrl.dispose(); _regCfCtrl.dispose();
    super.dispose();
  }

  // ── QUICK FILL ──────────────────────────────────────────────────────
  void _fillAdmin() {
    _emailCtrl.text    = 'admin@reva.edu.in';
    _passwordCtrl.text = 'Admin';
  }
  void _fillStudent() {
    _emailCtrl.text    = 'student@reva.edu.in';
    _passwordCtrl.text = 'Student';
  }

  // ── LOGIN ────────────────────────────────────────────────────────────
  Future<void> _doLogin() async {
    setState(() { _loginError = null; });
    final email = _emailCtrl.text.trim();
    final pwd   = _passwordCtrl.text;
    if (email.isEmpty || pwd.isEmpty) {
      setState(() => _loginError = 'Please enter your email and password.');
      return;
    }
    setState(() => _loading = true);
    final result = await context.read<AuthService>().login(email, pwd);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.ok) {
      setState(() => _loginError = result.error);
      return;
    }
    _navigate(context.read<AuthService>().isAdmin);
  }

  // ── REGISTER ─────────────────────────────────────────────────────────
  Future<void> _doRegister() async {
    setState(() { _regError = null; });
    final fname = _fNameCtrl.text.trim();
    final lname = _lNameCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final sid   = _regIdCtrl.text.trim();
    final pwd   = _regPwCtrl.text;
    final cf    = _regCfCtrl.text;

    if (fname.isEmpty || lname.isEmpty) { setState(() => _regError = 'Please enter your full name.'); return; }
    if (!email.contains('@'))           { setState(() => _regError = 'Please enter a valid email.'); return; }
    if (sid.isEmpty)                    { setState(() => _regError = 'Please enter your student/employee ID.'); return; }
    if (pwd.length < 6)                 { setState(() => _regError = 'Password must be at least 6 characters.'); return; }
    if (pwd != cf)                      { setState(() => _regError = 'Passwords do not match.'); return; }

    setState(() => _loading = true);
    final result = await context.read<AuthService>().register(
      email: email, password: pwd, name: '$fname $lname',
      studentId: sid, phone: _regPhoneCtrl.text.trim(), dept: _dept,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.ok) { setState(() => _regError = result.error); return; }
    context.go('/user/face-enrol?mode=register');
  }

  // ── BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.enter) {
          if (_tabs.index == 0) _doLogin(); else _doRegister();
        }
      },
      child: Scaffold(
        backgroundColor: GeoColors.authBg,
        body: Stack(children: [
          // Grid texture
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // Ambient glow orbs
          Positioned(top: -200, left: -200,
            child: _GlowOrb(color: GeoColors.primary.withOpacity(.18), size: 600)),
          Positioned(bottom: -150, right: -150,
            child: _GlowOrb(color: GeoColors.primary.withOpacity(.12), size: 500)),

          // Card
          Center(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (_, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, (1 - v) * 24),
                  child: child,
                ),
              ),
              child: Container(
                width: 420,
                decoration: BoxDecoration(
                  color: const Color(0xE31414140),
                  border: Border.all(color: Colors.white.withOpacity(.09)),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(.6), blurRadius: 80, offset: const Offset(0, 24)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: const ColorFilter.mode(Colors.transparent, BlendMode.srcOver),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        // Logo
                        Image.asset('assets/logo.png', height: 120,
                          errorBuilder: (_, __, ___) => RichText(text: TextSpan(children: [
                            TextSpan(text: 'Geo', style: GoogleFonts.inter(
                              fontSize: 32, fontWeight: FontWeight.w900, color: GeoColors.primary)),
                            TextSpan(text: 'Vision', style: GoogleFonts.inter(
                              fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                          ])),
                        ),
                        const SizedBox(height: 20),

                        // Tab bar
                        _buildTabBar(),
                        const SizedBox(height: 28),

                        // Panels
                        AnimatedBuilder(
                          animation: _tabs,
                          builder: (_, __) => _tabs.index == 0
                              ? _buildLoginPanel()
                              : _buildRegisterPanel(),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          )),
        ]),
      ),
    );
  }

  // ── TAB BAR ─────────────────────────────────────────────────────────
  Widget _buildTabBar() => Container(
    height: 42,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.05),
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.all(4),
    child: Row(children: [
      _tab('Sign In', 0),
      _tab('Register', 1),
    ]),
  );

  Widget _tab(String label, int idx) {
    final active = _tabs.index == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabs.index = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? GeoColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active ? [BoxShadow(
              color: GeoColors.primary.withOpacity(.35), blurRadius: 14, offset: const Offset(0, 4),
            )] : [],
          ),
          child: Center(child: Text(label, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: active ? Colors.white : Colors.white.withOpacity(.45),
          ))),
        ),
      ),
    );
  }

  // ── LOGIN PANEL ──────────────────────────────────────────────────────
  Widget _buildLoginPanel() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Section label
    Text('QUICK ACCESS DEMO', style: GoogleFonts.inter(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: Colors.white.withOpacity(.35), letterSpacing: .7,
    )),
    const SizedBox(height: 16),

    // Hint chips
    Row(children: [
      _hintChip('🔐 Admin Login',   onTap: _fillAdmin,   red: true),
      const SizedBox(width: 8),
      _hintChip('🎓 Student Login', onTap: _fillStudent, red: false),
    ]),
    const SizedBox(height: 14),

    // Error
    if (_loginError != null) _errorBox(_loginError!),

    // Email
    _darkLabel('EMAIL ADDRESS'),
    const SizedBox(height: 6),
    _darkInput(controller: _emailCtrl, hint: 'your@reva.edu.in', keyboardType: TextInputType.emailAddress),
    const SizedBox(height: 14),

    // Password
    _darkLabel('PASSWORD'),
    const SizedBox(height: 6),
    _darkInput(
      controller: _passwordCtrl,
      hint: 'Enter password',
      obscure: _obscureLogin,
      suffix: IconButton(
        icon: Text(_obscureLogin ? '👁' : '🙈', style: const TextStyle(fontSize: 16)),
        onPressed: () => setState(() => _obscureLogin = !_obscureLogin),
        color: Colors.white.withOpacity(.35),
      ),
    ),
    const SizedBox(height: 20),

    // Button
    _primaryBtn('Sign In', _doLogin),
    const SizedBox(height: 20),

    // Footer
    Center(child: Text('Secure access • GeoVision Campus Security v3.0',
      style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(.25)),
    )),
  ]);

  // ── REGISTER PANEL ───────────────────────────────────────────────────
  Widget _buildRegisterPanel() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (_regError != null) _errorBox(_regError!),

    // Name row
    Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _darkLabel('FIRST NAME *'),
        const SizedBox(height: 6),
        _darkInput(controller: _fNameCtrl, hint: 'John'),
      ])),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _darkLabel('LAST NAME *'),
        const SizedBox(height: 6),
        _darkInput(controller: _lNameCtrl, hint: 'Doe'),
      ])),
    ]),
    const SizedBox(height: 14),

    _darkLabel('EMAIL ADDRESS *'),
    const SizedBox(height: 6),
    _darkInput(controller: _regEmailCtrl, hint: 'you@reva.edu.in', keyboardType: TextInputType.emailAddress),
    const SizedBox(height: 14),

    _darkLabel('STUDENT / EMPLOYEE ID *'),
    const SizedBox(height: 6),
    _darkInput(controller: _regIdCtrl, hint: 'e.g. SRN22CS001'),
    const SizedBox(height: 14),

    _darkLabel('PHONE NUMBER'),
    const SizedBox(height: 6),
    _darkInput(controller: _regPhoneCtrl, hint: '+91 98765 43210', keyboardType: TextInputType.phone),
    const SizedBox(height: 14),

    _darkLabel('DEPARTMENT'),
    const SizedBox(height: 6),
    _darkDropdown(),
    const SizedBox(height: 14),

    Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _darkLabel('PASSWORD *'),
        const SizedBox(height: 6),
        _darkInput(controller: _regPwCtrl, hint: 'Min 6 chars', obscure: _obscureReg,
          suffix: IconButton(
            icon: Text(_obscureReg ? '👁' : '🙈', style: const TextStyle(fontSize: 16)),
            onPressed: () => setState(() => _obscureReg = !_obscureReg),
            color: Colors.white.withOpacity(.35),
          ),
        ),
      ])),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _darkLabel('CONFIRM *'),
        const SizedBox(height: 6),
        _darkInput(controller: _regCfCtrl, hint: 'Repeat', obscure: _obscureConfirm,
          suffix: IconButton(
            icon: Text(_obscureConfirm ? '👁' : '🙈', style: const TextStyle(fontSize: 16)),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            color: Colors.white.withOpacity(.35),
          ),
        ),
      ])),
    ]),
    const SizedBox(height: 20),

    _primaryBtn('Create Account & Enrol Face →', _doRegister),
    const SizedBox(height: 16),

    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Already have an account? ', style: GoogleFonts.inter(
        fontSize: 11, color: Colors.white.withOpacity(.25),
      )),
      GestureDetector(
        onTap: () => setState(() => _tabs.index = 0),
        child: Text('Sign in here', style: GoogleFonts.inter(
          fontSize: 11, color: const Color(0xFFF87171), fontWeight: FontWeight.w600,
        )),
      ),
    ]),
  ]);

  // ── HELPERS ──────────────────────────────────────────────────────────
  Widget _hintChip(String label, {required VoidCallback onTap, required bool red}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: red ? GeoColors.primary.withOpacity(.12) : const Color(0x1A6366F1),
          border: Border.all(
            color: red ? GeoColors.primary.withOpacity(.2) : const Color(0x336366F1),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: red ? const Color(0xFFF87171) : const Color(0xFFA5B4FC),
        )),
      ),
    );

  Widget _darkLabel(String text) => Text(text, style: GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w700,
    color: Colors.white.withOpacity(.5), letterSpacing: .5,
  ));

  Widget _errorBox(String msg) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: GeoColors.danger.withOpacity(.12),
      border: Border.all(color: GeoColors.danger.withOpacity(.25)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text('⚠ $msg', style: GoogleFonts.inter(
      fontSize: 12, color: const Color(0xFFF87171),
    )),
  );

  Widget _darkInput({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        fontSize: 14, color: Colors.white.withOpacity(.22),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withOpacity(.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withOpacity(.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GeoColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      suffixIcon: suffix,
    ),
  );

  Widget _darkDropdown() {
    const depts = [
      'Computer Science & Engineering',
      'Electronics & Communication',
      'Mechanical Engineering',
      'Civil Engineering',
      'Business Administration',
      'Other',
    ];
    return DropdownButtonFormField<String>(
      value: _dept.isEmpty ? null : _dept,
      hint: Text('Select department…', style: GoogleFonts.inter(
        color: Colors.white.withOpacity(.22), fontSize: 14,
      )),
      dropdownColor: const Color(0xFF1A1A1A),
      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(.1)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      items: depts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
      onChanged: (v) => setState(() => _dept = v ?? ''),
    );
  }

  Widget _primaryBtn(String label, VoidCallback action) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: _loading ? null : action,
      style: ElevatedButton.styleFrom(
        backgroundColor: GeoColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _loading
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w800,
            )),
    ),
  );
}

// ── GRID TEXTURE PAINTER ─────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.025)
      ..strokeWidth = 1;
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

// ── GLOW ORB ─────────────────────────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [color, Colors.transparent],
        stops: const [0, .65],
      ),
    ),
  );
}
