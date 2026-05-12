import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/db_service.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
import 'router/app_router.dart';
import 'screens/cctv_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = DbService();
  await db.seedDefaults();

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('gv_theme_dark') ?? true;

  final auth = AuthService();
  await auth.restoreSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final t = ThemeNotifier()..setDark(isDark);
            return t;
          },
        ),

        ChangeNotifierProvider<AuthService>.value(
          value: auth,
        ),

        Provider<ApiService>(
          create: (_) => ApiService(),
          dispose: (_, service) => service.dispose(),
        ),

        ChangeNotifierProvider<WebSocketService>(
          create: (_) => WebSocketService(),
        ),
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
  late final dynamic _router;

  @override
  void initState() {
    super.initState();

    final auth = context.read<AuthService>();

    _router = buildRouter(auth);

    auth.addListener(() {
      _router.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final isDark = theme.isDark;

    SharedPreferences.getInstance().then(
      (p) => p.setBool('gv_theme_dark', isDark),
    );

    return MaterialApp.router(
      title: 'GeoVision Campus Security',
      debugShowCheckedModeBanner: false,

      theme: buildTheme(dark: false),
      darkTheme: buildTheme(dark: true),

      themeMode:
          isDark ? ThemeMode.dark : ThemeMode.light,

      routerConfig: _router,
    );
  }
}