import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

/// Bump whenever assets/db/wiki.sqlite is replaced so the on-device copy is
/// refreshed on next launch.
const int kDbAssetVersion = 1;

const String _dbAssetVersionKey = 'db_asset_version';

/// Port of WikiDatabase from Database.swift. The bundled SQLite file cannot
/// be opened in place (it lives inside the app bundle / APK), so it is copied
/// to the application support directory on first launch and opened read-only.
class WikiDatabase {
  WikiDatabase._(this.db);

  final Database db;

  static late WikiDatabase instance;

  static Future<void> initialize(SharedPreferences prefs) async {
    final supportDir = await getApplicationSupportDirectory();
    final dbFile = File(p.join(supportDir.path, 'wiki.sqlite'));

    final installedVersion = prefs.getInt(_dbAssetVersionKey);
    if (!dbFile.existsSync() || installedVersion != kDbAssetVersion) {
      final bytes = await rootBundle.load('assets/db/wiki.sqlite');
      await dbFile.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      await prefs.setInt(_dbAssetVersionKey, kDbAssetVersion);
    }

    final db = sqlite3.open(dbFile.path, mode: OpenMode.readOnly);
    instance = WikiDatabase._(db);
  }

  /// Opens the database directly from a file path, bypassing the asset copy.
  /// For tests only.
  @visibleForTesting
  static void initializeForTesting(String path) {
    instance = WikiDatabase._(sqlite3.open(path, mode: OpenMode.readOnly));
  }

  String? fetchGameVersion() {
    final result = db.select(
      'SELECT value FROM app_metadata WHERE key = ?',
      ['game_version'],
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }
}
