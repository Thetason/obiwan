import 'dart:developer' as developer;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

enum LogLevel {
  error,
  warning,
  info,
  debug,
}

class DebugLogger {
  static DebugLogger? _instance;
  static DebugLogger get instance {
    _instance ??= DebugLogger._();
    return _instance!;
  }

  DebugLogger._();

  File? _logFile;
  File? _devMirrorFile; // mirrors logs into repo for external analysis
  bool _isInitialized = false;

  /// 로거 초기화 - 앱 시작시 호출 필요
  Future<void> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDirectory = Directory('${directory.path}/logs');
      
      if (!await logDirectory.exists()) {
        await logDirectory.create(recursive: true);
      }
      
      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      _logFile = File('${logDirectory.path}/vocal_trainer_$timestamp.log');
      
      // Dev mirror: write also to ~/obiwan/.devlogs/latest.log so external tools can read
      try {
        final home = Platform.environment['HOME'] ?? '';
        if (home.isNotEmpty) {
          final devDir = Directory('$home/obiwan/.devlogs');
          if (!await devDir.exists()) {
            await devDir.create(recursive: true);
          }
          _devMirrorFile = File('${devDir.path}/latest.log');
        }
      } catch (_) {
        _devMirrorFile = null;
      }
      
      _isInitialized = true;
      await _writeToFile('🚀 [INIT] Debug Logger initialized at ${DateTime.now()}');
      
      print('✅ Debug Logger initialized: ${_logFile?.path}');
    } catch (e) {
      print('❌ Debug Logger initialization failed: $e');
    }
  }

  /// 로그 레벨에 따른 색상 및 이모지 반환
  String _getLogPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return '🔴 [ERROR]';
      case LogLevel.warning:
        return '🟡 [WARN]';
      case LogLevel.info:
        return '🔵 [INFO]';
      case LogLevel.debug:
        return '🟢 [DEBUG]';
    }
  }

  /// 메인 로깅 함수
  Future<void> log(
    String message, {
    LogLevel level = LogLevel.info,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    final prefix = _getLogPrefix(level);
    final tagStr = tag != null ? '[$tag] ' : '';
    
    final logMessage = '$timestamp $prefix $tagStr$message';
    
    // 콘솔 출력
    print(logMessage);
    
    // Developer log (디버깅용)
    developer.log(
      message,
      time: DateTime.now(),
      level: _getLogLevelValue(level),
      name: tag ?? 'VocalTrainer',
      error: error,
      stackTrace: stackTrace,
    );
    
    // 파일에 저장
    await _writeToFile(logMessage);
    
    // 에러인 경우 스택 트레이스도 저장
    if (error != null || stackTrace != null) {
      await _writeToFile('  Error: $error');
      if (stackTrace != null) {
        await _writeToFile('  Stack Trace:\n$stackTrace');
      }
    }
  }

  /// 에러 로그 (빨강)
  Future<void> error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    await log(message, level: LogLevel.error, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// 경고 로그 (노랑)
  Future<void> warning(String message, {String? tag}) async {
    await log(message, level: LogLevel.warning, tag: tag);
  }

  /// 정보 로그 (파랑)
  Future<void> info(String message, {String? tag}) async {
    await log(message, level: LogLevel.info, tag: tag);
  }

  /// 디버그 로그 (초록)
  Future<void> debug(String message, {String? tag}) async {
    await log(message, level: LogLevel.debug, tag: tag);
  }

  /// 오디오 전용 로깅
  Future<void> audio(String message, {LogLevel level = LogLevel.info}) async {
    await log(message, level: level, tag: 'AUDIO');
  }

  /// 피치 분석 전용 로깅
  Future<void> pitch(String message, {LogLevel level = LogLevel.info}) async {
    await log(message, level: level, tag: 'PITCH');
  }

  /// 네이티브 브릿지 전용 로깅
  Future<void> native(String message, {LogLevel level = LogLevel.info}) async {
    await log(message, level: level, tag: 'NATIVE');
  }

  /// 파일에 로그 작성
  Future<void> _writeToFile(String message) async {
    if (!_isInitialized || _logFile == null) return;
    
    try {
      await _logFile!.writeAsString('$message\n', mode: FileMode.append);
      if (_devMirrorFile != null) {
        await _devMirrorFile!.writeAsString('$message\n', mode: FileMode.append);
      }
    } catch (e) {
      print('❌ Failed to write log to file: $e');
    }
  }

  /// LogLevel을 developer log 레벨로 변환
  int _getLogLevelValue(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return 1000;
      case LogLevel.warning:
        return 900;
      case LogLevel.info:
        return 800;
      case LogLevel.debug:
        return 700;
    }
  }

  /// 로그 파일 내용 읽기 (최근 100줄)
  Future<String> getRecentLogs({int lines = 100}) async {
    if (!_isInitialized || _logFile == null) return 'Logger not initialized';
    
    try {
      if (!await _logFile!.exists()) return 'Log file does not exist';
      
      final content = await _logFile!.readAsString();
      final allLines = content.split('\n');
      final recentLines = allLines.length > lines 
          ? allLines.sublist(allLines.length - lines)
          : allLines;
      
      return recentLines.join('\n');
    } catch (e) {
      return 'Error reading log file: $e';
    }
  }

  /// 로그 파일 삭제 (정리용)
  Future<void> clearLogs() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.delete();
        await initialize(); // 새 로그 파일 생성
        await info('Log file cleared and recreated');
      }
    } catch (e) {
      print('❌ Failed to clear log file: $e');
    }
  }
}

/// 전역 로거 인스턴스 (편의 함수)
final logger = DebugLogger.instance;
