import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class DatabaseConfig {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      // Per il web, usiamo un database in memoria o localStorage
      // Per ora disabilitiamo il database su web
      throw UnsupportedError('Database non supportato su web. Usa la versione mobile.');
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Per desktop, usiamo sqflite_common_ffi
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // Per mobile (Android/iOS), sqflite funziona automaticamente

    _initialized = true;
  }

  static bool get isSupported {
    if (kIsWeb) return false;
    return true;
  }
}
