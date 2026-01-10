// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'screen/login_screen.dart';
import 'screen/main_screen.dart';
import 'dart:convert'; // For utf8.encode
import 'package:crypto/crypto.dart'; // For sha256
import 'models/user.dart'; // For User and UserRole

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  await DatabaseService().init(); // Initialize database
  // For initial setup, create a default admin user if none exists
  final users = await DatabaseService().getUsers();
  if (users.isEmpty) {
    // Create a default admin user (password: admin123)
    final defaultAdmin = User(
      id: 'admin',
      name: 'Admin',
      email: 'admin@afroforma.com',
      passwordHash: sha256.convert(utf8.encode('admin123')).toString(), // Hashed password for 'admin123'
      role: UserRole.admin,
      permissions: [],
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
      isActive: true,
    );
    await DatabaseService().insertUser(defaultAdmin);
  }

  Widget initialScreen;
  // In a real app, you'd check for a persistent session here
  // For now, we'll always start with LoginScreen unless a user is already "logged in" (AuthService._currentUser is set)
  if (await AuthService.checkLoggedIn()) {
    initialScreen =  MainScreen();
  } else {
    initialScreen = const LoginScreen();
  }

  runApp(FormationManagementApp(initialScreen: initialScreen));
}
