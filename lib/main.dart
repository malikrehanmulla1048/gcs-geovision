import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/db_service.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Seed defaults in background
  final db = DbService();
  await db.seedDefaults();

  // Restore saved theme preference
  final prefs   = await SharedPreferences.getInstance();
  final isDark   = prefs.getBool('gv_theme_dark') ?? true; // default dark

  // Auth service
  final auth = AuthService();
  await auth.restoreSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final t = ThemeNotifier()..setDark(isDark);
          return t;
        }),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: const GeoVisionApp(),
    ),
  );
}

class GeoVisionApp extends StatefulWidget {
  const GeoVisionApp({super.key});
  @override
  State<GeoVisionApp> createState() => _GeoVisionAppState();
}

class _GeoVisionAppState extends State<GeoVisionApp> {
  late final _router;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _router = buildRouter(auth);
    // Re-route whenever auth state changes
    auth.addListener(() => _router.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final theme  = context.watch<ThemeNotifier>();
    final isDark = theme.isDark;

    // Persist theme preference
    SharedPreferences.getInstance().then((p) => p.setBool('gv_theme_dark', isDark));

    return MaterialApp.router(
      title:         'GeoVision Campus Security',
      debugShowCheckedModeBanner: false,
      theme:         buildTheme(dark: false),
      darkTheme:     buildTheme(dark: true),
      themeMode:     isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig:  _router,
    );
  }
}
