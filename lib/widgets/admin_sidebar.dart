import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'common_widgets.dart';

class AdminSidebar extends StatelessWidget {
  final String activeRoute;
  const AdminSidebar({super.key, required this.activeRoute});

  static const _navItems = [
    {'icon': '📊', 'label': 'Dashboard',     'route': '/admin/dashboard'},
    {'icon': '📹', 'label': 'CCTV Feed',     'route': '/admin/cctv'},
    {'icon': '🚪', 'label': 'Entry History', 'route': '/admin/entries'},
    {'icon': '⚠️', 'label': 'Threats',       'route': '/admin/threats'},
    {'icon': '🪪', 'label': 'Visitors',      'route': '/admin/visitors'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final auth  = context.watch<AuthService>();
    final user  = auth.currentUser;

    return Container(
      width: 260,
      color: theme.bgSidebar,
      child: Column(children: [
        // ── LOGO ──
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(.08))),
          ),
          child: Center(
            child: Image.asset(
              'assets/logo.png',
              height: 48,
              errorBuilder: (_, __, ___) => RichText(text: TextSpan(
                children: [
                  TextSpan(text: 'Geo', style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: GeoColors.primary,
                  )),
                  TextSpan(text: 'Vision', style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white,
                  )),
                ],
              )),
            ),
          ),
        ),

        // ── PROFILE STRIP ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(.08))),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Center(child: Text(
                user?.initials ?? 'AD',
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
                ),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.name ?? 'Admin User',
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text('Security Administrator',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFCCCCCC)),
              ),
            ])),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: GeoColors.online,
                boxShadow: [BoxShadow(
                  color: GeoColors.online.withOpacity(.5), blurRadius: 6,
                )],
              ),
            ),
          ]),
        ),

        // ── NAV ──
        Expanded(
          child: ListView(padding: const EdgeInsets.all(10), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
              child: Text('MAIN MENU', style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(.4), letterSpacing: 1.2,
              )),
            ),
            ..._navItems.map((item) {
              final isActive = activeRoute == item['route'];
              return GestureDetector(
                onTap: () => context.go(item['route']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(GeoRadius.md),
                    color: isActive
                        ? Colors.white.withOpacity(.07)
                        : Colors.transparent,
                    gradient: isActive ? LinearGradient(colors: [
                      GeoColors.primary.withOpacity(.22),
                      GeoColors.primaryDark.withOpacity(.16),
                    ]) : null,
                  ),
                  child: Row(children: [
                    // Active indicator bar
                    if (isActive)
                      Container(
                        width: 3, height: 20,
                        margin: const EdgeInsets.only(right: 11),
                        decoration: BoxDecoration(
                          color: GeoColors.primaryLight,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )
                    else
                      const SizedBox(width: 14),
                    Text(item['icon']!, style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(item['label']!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? Colors.white : const Color(0xFFCCCCCC),
                      ),
                    )),
                    // Badge for Threats
                    if (item['label'] == 'Threats')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: GeoColors.primary,
                          borderRadius: BorderRadius.circular(GeoRadius.full),
                        ),
                        child: Text('3', style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white,
                        )),
                      ),
                  ]),
                ),
              );
            }),
          ]),
        ),

        // ── LOGOUT ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white.withOpacity(.08))),
          ),
          child: GestureDetector(
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('Logout', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true),
                        child: Text('Logout', style: TextStyle(color: GeoColors.danger))),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await auth.logout();
                context.go('/');
              }
            },
            child: Row(children: [
              const SizedBox(width: 10),
              const Text('🚪', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 10),
              Text('Logout', style: GoogleFonts.inter(
                fontSize: 12, color: const Color(0xFFCCCCCC),
              )),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── ADMIN SHELL (sidebar + topbar + main content) ──────────────────────
class AdminShell extends StatelessWidget {
  final String activeRoute;
  final String pageTitle;
  final String breadcrumb;
  final Widget body;
  final List<Widget>? topbarActions;
  final Widget? rightPanel;

  const AdminShell({
    super.key,
    required this.activeRoute,
    required this.pageTitle,
    required this.breadcrumb,
    required this.body,
    this.topbarActions,
    this.rightPanel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();

    return Scaffold(
      backgroundColor: theme.bgBody,
      body: Row(children: [
        // Sidebar
        AdminSidebar(activeRoute: activeRoute),

        // Main
        Expanded(child: Column(children: [
          // Topbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            color: theme.bgCard,
            child: Row(children: [
              // Breadcrumb
              Text('GeoVision / ', style: GoogleFonts.inter(
                fontSize: 13, color: theme.textTertiary,
              )),
              Text(breadcrumb, style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary,
              )),
              const Spacer(),
              if (topbarActions != null) ...topbarActions!,
              const SizedBox(width: 8),
              // Theme toggle
              GestureDetector(
                onTap: () => context.read<ThemeNotifier>().toggle(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: theme.bgCard,
                    border: Border.all(color: theme.border),
                    borderRadius: BorderRadius.circular(GeoRadius.sm),
                  ),
                  child: Text(
                    theme.isDark ? '☀️  Light Mode' : '🌙  Dark Mode',
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600, color: theme.textPrimary,
                    ),
                  ),
                ),
              ),
            ]),
          ),
          Divider(height: 1, color: theme.border),

          // Body
          Expanded(child: Row(children: [
            Expanded(child: body),
            if (rightPanel != null) rightPanel!,
          ])),
        ])),
      ]),
    );
  }
}
