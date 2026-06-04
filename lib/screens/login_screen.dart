import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

// ── Login flow states ─────────────────────────────────────────────
enum _LoginStep { email, password, register }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  _LoginStep _step = _LoginStep.email;

  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePass   = true;
  bool _loading       = false;
  String? _error;

  // Register fields
  final _fNameCtrl    = TextEditingController();
  final _lNameCtrl    = TextEditingController();
  final _regIdCtrl    = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regPwCtrl    = TextEditingController();
  final _regCfCtrl    = TextEditingController();
  bool _obscureRegPw  = true;
  bool _obscureRegCf  = true;
  String _dept        = '';

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _checkSession();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose(); _passwordCtrl.dispose();
    _fNameCtrl.dispose(); _lNameCtrl.dispose();
    _regIdCtrl.dispose(); _regPhoneCtrl.dispose();
    _regPwCtrl.dispose(); _regCfCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    final auth = context.read<AuthService>();
    if (auth.isLoggedIn) _navigate(auth);
  }

  void _navigate(AuthService auth) {
    if (auth.isAdmin) {
      context.go('/admin/dashboard');
    } else if (!auth.isFaceEnrolled) {
      context.go('/user/face-enrol?mode=register');
    } else {
      context.go('/user/profile');
    }
  }

  void _stepTo(_LoginStep s) {
    _fadeCtrl.reset();
    setState(() { _step = s; _error = null; });
    _fadeCtrl.forward();
  }

  // ── EMAIL NEXT ────────────────────────────────────────────────────
  void _nextFromEmail() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    // Admin email → go to password step
    // Any other → if ends in @reva.edu.in, password step; else register
    if (email == 'admin@reva.edu.in') {
      _stepTo(_LoginStep.password);
    } else {
      // For any reva email that might be registered, try password first.
      // For a new user flow, they'll also go to password (if wrong, we'll show register option).
      _stepTo(_LoginStep.password);
    }
  }

  // ── LOGIN ─────────────────────────────────────────────────────────
  Future<void> _doLogin() async {
    final email = _emailCtrl.text.trim();
    final pwd   = _passwordCtrl.text;
    if (pwd.isEmpty) { setState(() => _error = 'Enter your password.'); return; }
    setState(() { _loading = true; _error = null; });
    final auth   = context.read<AuthService>();
    final result = await auth.login(email, pwd);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.ok) {
      // If login failed and not admin email, offer to register
      if (email != 'admin@reva.edu.in') {
        setState(() => _error = 'Account not found. Would you like to register?');
      } else {
        setState(() => _error = result.error);
      }
      return;
    }
    _navigate(auth);
  }

  // ── REGISTER ─────────────────────────────────────────────────────
  Future<void> _doRegister() async {
    final fname = _fNameCtrl.text.trim();
    final lname = _lNameCtrl.text.trim();
    final sid   = _regIdCtrl.text.trim();
    final pwd   = _regPwCtrl.text;
    final cf    = _regCfCtrl.text;
    if (fname.isEmpty || lname.isEmpty) { setState(() => _error = 'Enter your full name.'); return; }
    if (sid.isEmpty)                    { setState(() => _error = 'Enter your student / employee ID.'); return; }
    if (pwd.length < 6)                 { setState(() => _error = 'Password must be at least 6 characters.'); return; }
    if (pwd != cf)                      { setState(() => _error = 'Passwords do not match.'); return; }

    setState(() { _loading = true; _error = null; });
    final auth   = context.read<AuthService>();
    final result = await auth.register(
      email: _emailCtrl.text.trim(), password: pwd, name: '$fname $lname',
      studentId: sid, phone: _regPhoneCtrl.text.trim(), dept: _dept,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.ok) { setState(() => _error = result.error); return; }
    context.go('/user/face-enrol?mode=register');
  }

  // ── BUILD ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F1),
      body: Center(child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (e) {
          if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.enter) {
            if (_step == _LoginStep.email)    _nextFromEmail();
            if (_step == _LoginStep.password) _doLogin();
            if (_step == _LoginStep.register) _doRegister();
          }
        },
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Container(
            width: 440,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 28, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.fromLTRB(44, 44, 44, 44),
            child: _buildStepContent(),
          ),
        ),
      )),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _LoginStep.email:    return _buildEmailStep();
      case _LoginStep.password: return _buildPasswordStep();
      case _LoginStep.register: return _buildRegisterStep();
    }
  }

  // ── STEP 1: EMAIL ─────────────────────────────────────────────────
  Widget _buildEmailStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      _msLogo(),
      const SizedBox(height: 24),
      Text('Sign in', style: GoogleFonts.inter(
        fontSize: 24, fontWeight: FontWeight.w300, color: const Color(0xFF1B1B1B))),
      const SizedBox(height: 4),
      Text('to continue to GeoVision Campus Security', style: GoogleFonts.inter(
        fontSize: 13, color: const Color(0xFF505050))),
      const SizedBox(height: 24),

      if (_error != null) _errorBanner(_error!),

      _msInput(controller: _emailCtrl, label: 'Email, phone, or Skype',
          keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 8),

      GestureDetector(
        onTap: () => _stepTo(_LoginStep.register),
        child: Text("Don't have an account? Create one",
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0067B8))),
      ),
      const SizedBox(height: 28),

      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        _msNextBtn('Next', _nextFromEmail),
      ]),
    ],
  );

  // ── STEP 2: PASSWORD ──────────────────────────────────────────────
  Widget _buildPasswordStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      _msLogo(),
      const SizedBox(height: 24),

      // Back arrow + email
      GestureDetector(
        onTap: () => _stepTo(_LoginStep.email),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD2D0CE)),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.arrow_back, size: 14, color: Color(0xFF323130)),
            const SizedBox(width: 6),
            Text(_emailCtrl.text.trim(), style: GoogleFonts.inter(
              fontSize: 13, color: const Color(0xFF323130))),
          ]),
        ),
      ),
      const SizedBox(height: 20),

      Text('Enter password', style: GoogleFonts.inter(
        fontSize: 24, fontWeight: FontWeight.w300, color: const Color(0xFF1B1B1B))),
      const SizedBox(height: 20),

      if (_error != null) ...[
        _errorBanner(_error!),
        if (_error!.contains('register'))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => _stepTo(_LoginStep.register),
              child: Text('Create an account',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0067B8))),
            ),
          ),
      ],

      _msInput(
        controller: _passwordCtrl,
        label: 'Password',
        obscure: _obscurePass,
        suffix: IconButton(
          icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: const Color(0xFF605E5C)),
          onPressed: () => setState(() => _obscurePass = !_obscurePass),
        ),
      ),
      const SizedBox(height: 8),
      Text('Forgot password?', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0067B8))),
      const SizedBox(height: 28),

      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        _msNextBtn(_loading ? '' : 'Sign in', _loading ? () {} : _doLogin, loading: _loading),
      ]),
    ],
  );

  // ── STEP 3: REGISTER ──────────────────────────────────────────────
  Widget _buildRegisterStep() => SingleChildScrollView(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      _msLogo(),
      const SizedBox(height: 20),

      GestureDetector(
        onTap: () => _stepTo(_LoginStep.email),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.arrow_back, size: 16, color: Color(0xFF0067B8)),
          const SizedBox(width: 4),
          Text('Back', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0067B8))),
        ]),
      ),
      const SizedBox(height: 12),

      Text('Create account', style: GoogleFonts.inter(
        fontSize: 24, fontWeight: FontWeight.w300, color: const Color(0xFF1B1B1B))),
      const SizedBox(height: 4),
      Text(_emailCtrl.text.trim(), style: GoogleFonts.inter(
        fontSize: 13, color: const Color(0xFF505050))),
      const SizedBox(height: 20),

      if (_error != null) _errorBanner(_error!),

      Row(children: [
        Expanded(child: _msInput(controller: _fNameCtrl, label: 'First name')),
        const SizedBox(width: 12),
        Expanded(child: _msInput(controller: _lNameCtrl, label: 'Last name')),
      ]),
      const SizedBox(height: 12),

      _msInput(controller: _regIdCtrl, label: 'Student / Employee ID'),
      const SizedBox(height: 12),

      _msInput(controller: _regPhoneCtrl, label: 'Phone number (optional)',
          keyboardType: TextInputType.phone),
      const SizedBox(height: 12),

      _msDeptDropdown(),
      const SizedBox(height: 12),

      _msInput(controller: _regPwCtrl, label: 'Create password',
        obscure: _obscureRegPw,
        suffix: IconButton(
          icon: Icon(_obscureRegPw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: const Color(0xFF605E5C)),
          onPressed: () => setState(() => _obscureRegPw = !_obscureRegPw),
        ),
      ),
      const SizedBox(height: 12),

      _msInput(controller: _regCfCtrl, label: 'Confirm password',
        obscure: _obscureRegCf,
        suffix: IconButton(
          icon: Icon(_obscureRegCf ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18, color: const Color(0xFF605E5C)),
          onPressed: () => setState(() => _obscureRegCf = !_obscureRegCf),
        ),
      ),
      const SizedBox(height: 24),

      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        _msNextBtn(_loading ? '' : 'Create account', _loading ? () {} : _doRegister, loading: _loading),
      ]),
    ],
  ));

  // ── HELPERS ──────────────────────────────────────────────────────

  Widget _msLogo() => Row(children: [
    // Microsoft four-colour logo
    SizedBox(width: 22, height: 22, child: CustomPaint(painter: _MsLogoPainter())),
    const SizedBox(width: 8),
    Text('Microsoft', style: GoogleFonts.inter(
      fontSize: 15, fontWeight: FontWeight.w400, color: const Color(0xFF252423))),
  ]);

  Widget _msInput({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1B1B1B)),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF605E5C)),
      filled: true,
      fillColor: Colors.white,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0xFF8A8886)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0xFF8A8886)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0xFF0067B8), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      suffixIcon: suffix,
    ),
  );

  Widget _msDeptDropdown() {
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
      hint: Text('Department (optional)', style: GoogleFonts.inter(
        fontSize: 13, color: const Color(0xFF605E5C))),
      dropdownColor: Colors.white,
      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1B1B1B)),
      decoration: const InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFF8A8886)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFF8A8886)),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: depts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
      onChanged: (v) => setState(() => _dept = v ?? ''),
    );
  }

  Widget _msNextBtn(String label, VoidCallback onTap, {bool loading = false}) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF0067B8),
      foregroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      elevation: 0,
    ),
    child: loading
        ? const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
  );

  Widget _errorBanner(String msg) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    color: const Color(0xFFFDE7E9),
    child: Row(children: [
      const Icon(Icons.error_outline, size: 16, color: Color(0xFFBC2F32)),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: GoogleFonts.inter(
        fontSize: 12, color: const Color(0xFF1B1B1B)))),
    ]),
  );
}

// ── Microsoft 4-colour logo painter ──────────────────────────────────────
class _MsLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height / 2;
    final w = size.width  / 2;
    final gap = size.width * 0.04;
    final paints = [
      Paint()..color = const Color(0xFFF25022), // top-left red
      Paint()..color = const Color(0xFF7FBA00), // top-right green
      Paint()..color = const Color(0xFF00A4EF), // bottom-left blue
      Paint()..color = const Color(0xFFFFB900), // bottom-right yellow
    ];
    final rects = [
      Rect.fromLTWH(0,     0,     w - gap, h - gap),
      Rect.fromLTWH(w + gap, 0,   w - gap, h - gap),
      Rect.fromLTWH(0,     h + gap, w - gap, h - gap),
      Rect.fromLTWH(w + gap, h + gap, w - gap, h - gap),
    ];
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(rects[i], paints[i]);
    }
  }
  @override bool shouldRepaint(_) => false;
}
