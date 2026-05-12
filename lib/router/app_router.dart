import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../screens/admin/dashboard_screen.dart';
import '../screens/admin/cctv_feed_screen.dart';
import '../screens/admin/entry_history_screen.dart';
import '../screens/admin/security_threats_screen.dart';
import '../screens/admin/visitor_management_screen.dart';
import '../screens/user/profile_screen.dart';
import '../screens/user/my_entries_screen.dart';
import '../screens/user/face_enrol_screen.dart';

GoRouter buildRouter(AuthService auth) => GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final loggedIn = auth.isLoggedIn;
    final loc      = state.uri.path;

    // Not logged in → redirect to login for any protected route
    if (!loggedIn && loc != '/') return '/';

    // Logged in admin trying to hit / → send to dashboard
    if (loggedIn && auth.isAdmin && loc == '/') return '/admin/dashboard';

    // Logged in student trying to hit / → send to profile
    if (loggedIn && !auth.isAdmin && loc == '/') return '/user/profile';

    // Student trying to access admin route
    if (loggedIn && !auth.isAdmin && loc.startsWith('/admin')) return '/user/profile';

    // Admin trying to access user route
    if (loggedIn && auth.isAdmin && loc.startsWith('/user')) return '/admin/dashboard';

    return null;
  },
  routes: [
    // ── AUTH ──
    GoRoute(path: '/', builder: (_, __) => const LoginScreen()),

    // ── ADMIN ──
    GoRoute(path: '/admin/dashboard',  builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/admin/cctv',       builder: (_, __) => const CctvFeedScreen()),
    GoRoute(path: '/admin/entries',    builder: (_, __) => const EntryHistoryScreen()),
    GoRoute(path: '/admin/threats',    builder: (_, __) => const SecurityThreatsScreen()),
    GoRoute(path: '/admin/visitors',   builder: (_, __) => const VisitorManagementScreen()),

    // ── USER ──
    GoRoute(path: '/user/profile',  builder: (_, __) => const UserProfileScreen()),
    GoRoute(path: '/user/entries',  builder: (_, __) => const MyEntriesScreen()),
    GoRoute(
      path: '/user/face-enrol',
      builder: (_, state) {
        final mode = state.uri.queryParameters['mode'] ?? 'update';
        return FaceEnrolScreen(mode: mode);
      },
    ),
  ],
);
