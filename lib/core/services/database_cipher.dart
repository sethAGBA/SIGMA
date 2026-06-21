// lib/core/services/database_cipher.dart
//
// Ouverture SQLite chiffrée (Android/iOS) via sqflite_sqlcipher.

import 'package:sqflite_sqlcipher/sqflite.dart';

Future<Database> openEncryptedDatabase({
  required String path,
  required String password,
  required int version,
  required Future<void> Function(Database db, int version) onCreate,
  required Future<void> Function(Database db, int oldVersion, int newVersion)
      onUpgrade,
}) {
  return openDatabase(
    path,
    password: password,
    version: version,
    onCreate: onCreate,
    onUpgrade: onUpgrade,
  );
}
