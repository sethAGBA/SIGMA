import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/theme/app_colors.dart';
import 'core/services/auth_service.dart';
import 'screens/auth/login_page.dart';
import 'screens/main_layout.dart';
import 'core/services/theme_service.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await initializeDateFormatting('fr_FR', null);

  final themeService = ThemeService();
  await themeService.init();

  // Vérifier si une session existe déjà (stay-logged-in)
  final authService = AuthService();
  await authService.init();

  runApp(MyApp(isLoggedIn: authService.isLoggedIn));
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
        );
      },
    );
  }
}
