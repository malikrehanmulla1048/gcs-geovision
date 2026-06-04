import 'package:go_router/go_router.dart';
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

    if (!loggedIn && loc != '/') return '/';

    if (loggedIn) {
      // Redirect to dashboard / profile if on root
      if (loc == '/') {
        return auth.isAdmin ? '/admin/dashboard' : '/user/profile';
      }

      // Students who haven't enrolled face yet → go to enrolment first
      if (!auth.isAdmin && !auth.isFaceEnrolled && loc != '/user/face-enrol') {
        return '/user/face-enrol?mode=register';
      }

      // Prevent students from accessing admin routes
      if (!auth.isAdmin && loc.startsWith('/admin')) return '/user/profile';

      // Prevent admins from accessing user routes
      if (auth.isAdmin && loc.startsWith('/user')) return '/admin/dashboard';
    }

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
