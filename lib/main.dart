import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/theme/app_colors.dart';
import 'core/services/auth_service.dart';
import 'core/services/session_manager.dart';
import 'core/services/sync_service.dart';
import 'core/services/connectivity_monitor.dart';
import 'core/notifiers/dashboard_notifier.dart';
import 'screens/auth/login_page.dart';
import 'screens/main_layout.dart';
import 'core/services/theme_service.dart';
import 'package:intl/date_symbol_data_local.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await initializeDateFormatting('fr_FR', null);

  final themeService = ThemeService();
  await themeService.init();

  // Séquence d'initialisation Phase 0 (req. 3.1) :
  // 1. ApiService().init()      → charger l'URL serveur depuis SharedPreferences
  // 2. ConnectivityMonitor()  → ping /health + connectivity_plus
  // 3. runApp()
  final authService = AuthService();
  await authService.init(); // inclut ApiService().init()

  // Injecter le navigatorKey dans SessionManager
  SessionManager().navigatorKey = navigatorKey;
  // Si déjà connecté via session persistée, démarrer le timer
  if (authService.isLoggedIn) {
    SessionManager().start();
  }

  ConnectivityMonitor().start();
  // Tenter de vider la file des opérations offline en attente
  SyncService().flushPendingOperations();

  // Créer le DashboardNotifier et enregistrer le callback de logout
  // pour que AuthService puisse vider le cache sans accéder au contexte
  // Provider (Exigence 9.4).
  final dashboardNotifier = DashboardNotifier();
  authService.onLogout = dashboardNotifier.clearCache;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DashboardNotifier>.value(
          value: dashboardNotifier,
        ),
      ],
      child: MyApp(isLoggedIn: authService.isLoggedIn),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) {
        return MaterialApp(
          title: 'SIGMA',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeService().themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
          locale: const Locale('fr', 'FR'),
          // Démarrer sur LoginPage si pas connecté, sinon MainLayout
          home: isLoggedIn ? const MainLayout() : const LoginPage(),
          navigatorKey: navigatorKey,
        );
      },
    );
  }
}
