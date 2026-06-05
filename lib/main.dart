import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/backend_service.dart';
import 'services/update_service.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    // Check for updates silently after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    final update = await UpdateService.checkForUpdate();
    if (update == null || !mounted) return;
    _showUpdateDialog(update);
  }

  void _showUpdateDialog(UpdateInfo update) {
    final theme = context.read<ThemeNotifier>();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: theme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GeoRadius.lg)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: GeoColors.primaryGhost, shape: BoxShape.circle),
            child: const Icon(Icons.system_update, color: GeoColors.primary, size: 20)),
          const SizedBox(width: 12),
          Text('Update Available', style: GoogleFonts.inter(
            fontWeight: FontWeight.w800, fontSize: 16, color: theme.textPrimary)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: GeoColors.successGhost,
              borderRadius: BorderRadius.circular(GeoRadius.full)),
            child: Text('v${update.version}', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700, color: GeoColors.success)),
          ),
          const SizedBox(height: 12),
          Text('A new version of GeoVision is available.',
            style: GoogleFonts.inter(fontSize: 13, color: theme.textSecondary)),
          const SizedBox(height: 8),
          Text(
            update.releaseNotes.length > 200
                ? '${update.releaseNotes.substring(0, 200)}…'
                : update.releaseNotes,
            style: GoogleFonts.inter(fontSize: 12, color: theme.textTertiary, height: 1.5)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later', style: GoogleFonts.inter(color: theme.textTertiary))),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse(update.downloadUrl);
              if (await canLaunchUrl(uri)) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GeoColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GeoRadius.sm))),
            icon: const Icon(Icons.download, size: 16, color: Colors.white),
            label: Text('Download & Install',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white))),
        ],
      ),
    );
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