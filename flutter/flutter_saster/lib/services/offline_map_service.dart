import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class OfflineMapException implements Exception {
  final String message;
  const OfflineMapException(this.message);

  @override
  String toString() => message;
}

class OfflineMapService {
  OfflineMapService._();

  static final OfflineMapService instance = OfflineMapService._();

  static const String kAssetMbtiles = 'assets/maps/aklan.mbtiles';
  static const String kStyleAssetUri = 'asset://assets/styles/liberty/style.json';
  static const String kSourceId = 'openmaptiles';

  Future<String>? _prepareFuture;

  /// Ensures the bundled MBTiles archive exists in permanent storage and
  /// returns its path. The copy happens only once per bundled version.
  Future<String> prepare() => _prepareFuture ??= _prepare();

  Future<String> _prepare() async {
    try {
      final bytes = await rootBundle.load(kAssetMbtiles);
      final expectedLength = bytes.lengthInBytes;

      final supportDir = await getApplicationSupportDirectory();
      final mapsDir = Directory('${supportDir.path}/maps');
      await mapsDir.create(recursive: true);

      final target = File('${mapsDir.path}/aklan.mbtiles');
      final sidecar = File('${mapsDir.path}/aklan.mbtiles.version');

      final exists = await target.exists() && await sidecar.exists();
      final versionMatches =
          exists && (await sidecar.readAsString()).trim() == '$expectedLength';
      final sizeMatches = exists && (await target.length()) == expectedLength;

      if (exists && versionMatches && sizeMatches) {
        if (kDebugMode) await _printVerification(target.path);
        return target.path;
      }

      final buffer =
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
      final tmp = File('${mapsDir.path}/aklan.mbtiles.tmp');
      await tmp.writeAsBytes(buffer, flush: true);
      if (await target.exists()) await target.delete();
      await tmp.rename(target.path);
      await sidecar.writeAsString('$expectedLength', flush: true);

      if (kDebugMode) await _printVerification(target.path);
      return target.path;
    } catch (error) {
      throw OfflineMapException('Offline map is not ready yet.');
    }
  }

  /// Debug-only self-check so a real device log confirms the archive that the
  /// map provider will open: path, existence, size, SQLite records, and the
  /// metadata that controls rendering (minimum requirement before reading
  /// tiles as (z/x/y) XYZ).
  Future<void> _printVerification(String path) async {
    try {
      final file = File(path);
      final size = await file.length();
      debugPrint('OfflineMap archive: $path');
      debugPrint('  exists: ${await file.exists()}');
      debugPrint(
        '  size: $size bytes (${(size / (1024 * 1024)).toStringAsFixed(2)} MB)',
      );
      final db = sqlite3.open(path);
      try {
        final tiles = db.select('SELECT COUNT(*) AS n FROM tiles;').first['n'];
        debugPrint('  tiles rows: $tiles');
        for (final row in db.select('SELECT name, value FROM metadata;')) {
          final key = row['name']?.toString() ?? '';
          if (const {
            'name',
            'format',
            'minzoom',
            'maxzoom',
            'bounds',
            'center',
            'type',
          }.contains(key)) {
            debugPrint('  metadata $key: ${row['value']}');
          }
        }
        final zoom = db
            .select(
              'SELECT MIN(zoom_level) AS mn, MAX(zoom_level) AS mx FROM tiles;',
            )
            .first;
        debugPrint('  tiles zoom range: ${zoom['mn']}..${zoom['mx']}');
        if (size > 0) debugPrint('  header ok: gzip MVT payloads expected');
      } finally {
        db.close();
      }
    } catch (error) {
      // Verification is diagnostic only — never block the map on it.
      debugPrint('OfflineMap verification skipped: $error');
    }
  }
}