import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sigma/core/services/api_service.dart';
import 'package:sigma/core/services/auth_service.dart';
import 'package:sigma/core/services/database_service.dart';
import 'package:sigma/models/user_model.dart';

void initPhase1TestBindings() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

void resetPhase1SecureStorage([Map<String, String>? values]) {
  FlutterSecureStorage.setMockInitialValues(
    Map<String, String>.from(values ?? {}),
  );
}

Future<void> resetPhase1Prefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
}

void tearDownPhase1Services() {
  ApiService.resetForTesting();
  AuthService().resetForTesting();
  DatabaseService.resetDatabaseForTesting();
  resetPhase1SecureStorage();
  resetPhase1Prefs();
}

String buildValidJwt({Duration validFor = const Duration(hours: 1)}) {
  final exp = DateTime.now().add(validFor).millisecondsSinceEpoch ~/ 1000;
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(utf8.encode('{"exp":$exp}'));
  return '$header.$payload.sig';
}

String randomToken(Random random, {int length = 24}) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return List.generate(length, (_) => chars[random.nextInt(chars.length)])
      .join();
}

Future<Database> createPhase1TestDatabase() async {
  final path =
      '${inMemoryDatabasePath}_phase1_${DateTime.now().microsecondsSinceEpoch}';
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE utilisateurs_systeme (
            id TEXT PRIMARY KEY,
            agent_id TEXT,
            username TEXT,
            password_hash TEXT,
            role TEXT,
            is_active INTEGER,
            created_at TEXT,
            permissions TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE audit_logs (
            id TEXT PRIMARY KEY,
            user_id TEXT,
            username TEXT,
            action TEXT NOT NULL,
            details TEXT,
            timestamp TEXT NOT NULL,
            severity TEXT NOT NULL,
            ip_address TEXT
          )
        ''');
      },
    ),
  );
}

Future<void> seedTestUser(Database db, UserAccount user) async {
  await db.insert('utilisateurs_systeme', user.toMap());
}
