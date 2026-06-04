// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/backend_service.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register webcam platform view
  _registerCameraView();

  final prefs  = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('gv_theme_dark') ?? true;

  final auth    = AuthService();
  await auth.restoreSession();

  final backend = BackendService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeNotifier()..setDark(isDark),
        ),
        ChangeNotifierProvider<AuthService>.value(value: auth),
        Provider<BackendService>.value(value: backend),
      ],
      child: const GeoVisionApp(),
    ),
  );
}

void _registerCameraView() {
  // Register a factory for the 'gv-camera-view' platform view type.
  // The video element is created lazily by the FaceEnrolScreen; here we just
  // register a container that the screen will populate.
  // ignore: undefined_prefixed_name
  try {
    final existingEl = web.document.getElementById('gv-camera-container');
    if (existingEl == null) {
      final div = web.HTMLDivElement()
        ..id = 'gv-camera-container'
        ..style.display = 'none';
      web.document.body?.appendChild(div);
    }
  } catch (_) {}
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
    auth.addListener(() => _router.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;

    SharedPreferences.getInstance()
        .then((p) => p.setBool('gv_theme_dark', isDark));

    return MaterialApp.router(
      title: 'GeoVision Campus Security',
      debugShowCheckedModeBanner: false,
      theme:     buildTheme(dark: false),
      darkTheme: buildTheme(dark: true),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
    );
  }
}