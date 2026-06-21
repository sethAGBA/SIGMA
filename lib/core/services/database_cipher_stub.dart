// Stub pour plateformes sans SQLCipher (web).

import 'package:sqflite/sqflite.dart';

Future<Database> openEncryptedDatabase({
  required String path,
  required String password,
  required int version,
  required Future<void> Function(Database db, int version) onCreate,
  required Future<void> Function(Database db, int oldVersion, int newVersion)
      onUpgrade,
}) {
  throw UnsupportedError(
    'SQLCipher n\'est disponible que sur Android et iOS.',
  );
}
