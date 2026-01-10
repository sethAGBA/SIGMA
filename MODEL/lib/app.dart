// import 'package:afroforma/screen/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:afroforma/services/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';

class FormationManagementApp extends StatelessWidget {
  final Widget initialScreen;

  const FormationManagementApp({super.key, required this.initialScreen});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Formation',
      theme: ThemeData(
  useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
  // Use Nunito as the primary app font and provide sensible fallbacks
  fontFamily: 'Nunito',
  fontFamilyFallback: const ['Arial', 'Segoe UI Symbol', 'Apple Color Emoji'],
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 0,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
      ],
      home: Builder(builder: (context) {
        return NotificationOverlay(child: initialScreen);
      }),
      debugShowCheckedModeBanner: false,
    );
  }
}
