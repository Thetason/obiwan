import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'debug_logger.dart';

class DevDiagnostics {
  /// Export a simple diagnostics snapshot to repo mirror path: ~/obiwan/.devlogs/diag_<ts>.json
  static Future<String?> export({Map<String, dynamic>? extra}) async {
    try {
      final home = Platform.environment['HOME'] ?? '';
      if (home.isEmpty) return null;
      final dir = Directory(p.join(home, 'obiwan', '.devlogs'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File(p.join(dir.path, 'diag_$ts.json'));

      final recent = await logger.getRecentLogs(lines: 300);
      final data = <String, dynamic>{
        'ts': ts,
        'platform': {
          'os': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
          'dart': Platform.version,
        },
        'kReleaseMode': kReleaseMode,
        'safeMode': const String.fromEnvironment('SAFE_MODE', defaultValue: 'true'),
        'recentLogs': recent,
      };
      if (extra != null) data['extra'] = extra;

      await file.writeAsString(_toJson(data));
      return file.path;
    } catch (e) {
      return null;
    }
  }

  static String _toJson(Map<String, dynamic> map) {
    // lightweight JSON encoder to avoid extra deps
    return const JsonEncoder.withIndent('  ').convert(map);
  }
}

// Minimal JSON encoder (since dart:convert JsonEncoder is available)
import 'dart:convert';
