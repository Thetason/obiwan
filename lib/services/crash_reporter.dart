import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 크래시 리포팅 서비스 - 앱 크래시 정보 수집 및 복구 시도
class CrashReporter {
  static final CrashReporter _instance = CrashReporter._internal();
  factory CrashReporter() => _instance;
  CrashReporter._internal();

  bool _isInitialized = false;
  String? _crashLogDir;
  DeviceInfoPlugin? _deviceInfo;
  PackageInfo? _packageInfo;
  
  // 크래시 통계
  int _totalCrashes = 0;
  int _recoveredCrashes = 0;
  final List<CrashEvent> _crashHistory = [];
  
  // 복구 시도 관련
  Function? _recoveryCallback;
  Timer? _recoveryTimer;

  /// 초기화
  Future<void> initialize({Function? onRecoveryAttempt}) async {
    if (_isInitialized) return;

    try {
      // 디바이스 정보 수집
      _deviceInfo = DeviceInfoPlugin();
      _packageInfo = await PackageInfo.fromPlatform();
      
      // 크래시 로그 디렉토리 설정
      await _setupCrashLogDirectory();
      
      // 전역 에러 핸들러 설정
      _setupGlobalErrorHandlers();
      
      // 이전 크래시 복구 시도
      await _checkAndRecoverFromPreviousCrashes();
      
      _recoveryCallback = onRecoveryAttempt;
      _isInitialized = true;
      
      debugPrint('📊 [CrashReporter] Initialized successfully');
      await _logCrash('CrashReporter initialized', StackTrace.current, CrashSeverity.info);
      
    } catch (e, stackTrace) {
      debugPrint('❌ [CrashReporter] Initialization failed: $e');
      await _logCrash('CrashReporter initialization failed: $e', stackTrace, CrashSeverity.error);
    }
  }

  /// 크래시 로그 디렉토리 설정
  Future<void> _setupCrashLogDirectory() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      _crashLogDir = '${appDocDir.path}/crash_logs';
      
      final crashDir = Directory(_crashLogDir!);
      if (!crashDir.existsSync()) {
        crashDir.createSync(recursive: true);
      }
      
      // 오래된 로그 정리 (30일 이상)
      await _cleanupOldLogs();
      
    } catch (e) {
      debugPrint('❌ [CrashReporter] Failed to setup crash log directory: $e');
      _crashLogDir = null;
    }
  }

  /// 전역 에러 핸들러 설정
  void _setupGlobalErrorHandlers() {
    // Flutter 프레임워크 에러
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // Dart 런타임 에러 (Isolate)
    Isolate.current.addErrorListener(
      RawReceivePort((pair) async {
        final List<dynamic> errorAndStackTrace = pair;
        final error = errorAndStackTrace.first;
        final stackTrace = errorAndStackTrace.last as String;
        
        await _logCrash(
          'Isolate error: $error',
          StackTrace.fromString(stackTrace),
          CrashSeverity.critical,
        );
        
        _attemptRecovery(error.toString());
      }).sendPort,
    );

    // Zone 에러 (runZonedGuarded에서 포착되지 않은 에러)
    runZonedGuarded(() {
      // 앱의 메인 실행 영역
    }, (error, stackTrace) {
      _handleZoneError(error, stackTrace);
    });
  }

  /// Flutter 에러 처리
  void _handleFlutterError(FlutterErrorDetails details) async {
    final severity = _determineSeverity(details);
    
    await _logCrash(
      'Flutter Error: ${details.exceptionAsString()}',
      details.stack ?? StackTrace.current,
      severity,
      context: details.context?.toString(),
      library: details.library,
    );

    if (severity == CrashSeverity.critical) {
      _attemptRecovery(details.exceptionAsString());
    }

    // 디버그 모드에서는 원래 동작 유지
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  }

  /// Zone 에러 처리
  void _handleZoneError(Object error, StackTrace stackTrace) async {
    await _logCrash(
      'Zone Error: $error',
      stackTrace,
      CrashSeverity.critical,
    );
    
    _attemptRecovery(error.toString());
  }

  /// 수동 크래시 리포팅
  Future<void> reportCrash(
    Object error,
    StackTrace stackTrace, {
    CrashSeverity severity = CrashSeverity.error,
    String? context,
    Map<String, dynamic>? customData,
  }) async {
    await _logCrash(
      error.toString(),
      stackTrace,
      severity,
      context: context,
      customData: customData,
    );

    if (severity == CrashSeverity.critical) {
      _attemptRecovery(error.toString());
    }
  }

  /// 크래시 로깅
  Future<void> _logCrash(
    String error,
    StackTrace stackTrace,
    CrashSeverity severity, {
    String? context,
    String? library,
    Map<String, dynamic>? customData,
  }) async {
    _totalCrashes++;
    
    final crashEvent = CrashEvent(
      error: error,
      stackTrace: stackTrace.toString(),
      severity: severity,
      timestamp: DateTime.now(),
      context: context,
      library: library,
      customData: customData,
    );

    // 메모리에 저장 (최근 50개만)
    _crashHistory.add(crashEvent);
    if (_crashHistory.length > 50) {
      _crashHistory.removeAt(0);
    }

    // 파일에 저장
    await _saveCrashToFile(crashEvent);

    // 콘솔 출력
    _printCrashInfo(crashEvent);
  }

  /// 크래시 파일 저장
  Future<void> _saveCrashToFile(CrashEvent crashEvent) async {
    if (_crashLogDir == null) return;

    try {
      final timestamp = crashEvent.timestamp.toIso8601String().replaceAll(':', '-');
      final fileName = 'crash_$timestamp.json';
      final filePath = '$_crashLogDir/$fileName';

      // 디바이스 정보 수집
      final deviceInfo = await _collectDeviceInfo();
      final appInfo = await _collectAppInfo();

      final crashData = {
        'crashEvent': crashEvent.toJson(),
        'deviceInfo': deviceInfo,
        'appInfo': appInfo,
        'systemInfo': await _collectSystemInfo(),
      };

      final file = File(filePath);
      await file.writeAsString(jsonEncode(crashData));
      
      debugPrint('📁 [CrashReporter] Crash log saved: $fileName');
      
    } catch (e) {
      debugPrint('❌ [CrashReporter] Failed to save crash log: $e');
    }
  }

  /// 디바이스 정보 수집
  Future<Map<String, dynamic>> _collectDeviceInfo() async {
    final deviceInfo = <String, dynamic>{};
    
    try {
      if (_deviceInfo != null) {
        if (Platform.isAndroid) {
          final androidInfo = await _deviceInfo!.androidInfo;
          deviceInfo.addAll({
            'platform': 'Android',
            'model': androidInfo.model,
            'brand': androidInfo.brand,
            'device': androidInfo.device,
            'androidVersion': androidInfo.version.release,
            'androidSdk': androidInfo.version.sdkInt,
            'manufacturer': androidInfo.manufacturer,
            'product': androidInfo.product,
            'hardware': androidInfo.hardware,
            'bootloader': androidInfo.bootloader,
            'fingerprint': androidInfo.fingerprint,
          });
        } else if (Platform.isIOS) {
          final iosInfo = await _deviceInfo!.iosInfo;
          deviceInfo.addAll({
            'platform': 'iOS',
            'model': iosInfo.model,
            'name': iosInfo.name,
            'systemName': iosInfo.systemName,
            'systemVersion': iosInfo.systemVersion,
            'localizedModel': iosInfo.localizedModel,
            'identifierForVendor': iosInfo.identifierForVendor,
            'isPhysicalDevice': iosInfo.isPhysicalDevice,
          });
        } else if (Platform.isMacOS) {
          final macInfo = await _deviceInfo!.macOsInfo;
          deviceInfo.addAll({
            'platform': 'macOS',
            'computerName': macInfo.computerName,
            'hostName': macInfo.hostName,
            'arch': macInfo.arch,
            'model': macInfo.model,
            'kernelVersion': macInfo.kernelVersion,
            'osRelease': macInfo.osRelease,
            'majorVersion': macInfo.majorVersion,
            'minorVersion': macInfo.minorVersion,
            'patchVersion': macInfo.patchVersion,
          });
        }
      }
    } catch (e) {
      deviceInfo['error'] = 'Failed to collect device info: $e';
    }
    
    return deviceInfo;
  }

  /// 앱 정보 수집
  Future<Map<String, dynamic>> _collectAppInfo() async {
    final appInfo = <String, dynamic>{};
    
    try {
      if (_packageInfo != null) {
        appInfo.addAll({
          'appName': _packageInfo!.appName,
          'packageName': _packageInfo!.packageName,
          'version': _packageInfo!.version,
          'buildNumber': _packageInfo!.buildNumber,
          'buildSignature': _packageInfo!.buildSignature,
        });
      }
    } catch (e) {
      appInfo['error'] = 'Failed to collect app info: $e';
    }
    
    return appInfo;
  }

  /// 시스템 정보 수집
  Future<Map<String, dynamic>> _collectSystemInfo() async {
    return {
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
      'dartVersion': Platform.version,
      'environment': Platform.environment,
      'locale': Platform.localeName,
      'numberOfProcessors': Platform.numberOfProcessors,
      'pathSeparator': Platform.pathSeparator,
    };
  }

  /// 심각도 판단
  CrashSeverity _determineSeverity(FlutterErrorDetails details) {
    final error = details.exception;
    final stack = details.stack?.toString() ?? '';
    
    // 치명적 에러 패턴
    if (error is OutOfMemoryError || 
        error is StackOverflowError ||
        stack.contains('RenderObject') ||
        stack.contains('State lifecycle')) {
      return CrashSeverity.critical;
    }
    
    // 심각한 에러 패턴
    if (error is StateError ||
        error is ArgumentError ||
        stack.contains('AnimationController') ||
        stack.contains('StreamController')) {
      return CrashSeverity.error;
    }
    
    // 경고 수준
    if (error is AssertionError ||
        stack.contains('RenderFlex overflowed')) {
      return CrashSeverity.warning;
    }
    
    return CrashSeverity.info;
  }

  /// 복구 시도
  void _attemptRecovery(String errorMessage) {
    if (_recoveryTimer?.isActive == true) return; // 이미 복구 중
    
    debugPrint('🔄 [CrashReporter] Attempting recovery for: $errorMessage');
    
    _recoveryTimer = Timer(const Duration(seconds: 2), () async {
      try {
        // 복구 콜백 실행
        if (_recoveryCallback != null) {
          await _recoveryCallback!();
          _recoveredCrashes++;
          debugPrint('✅ [CrashReporter] Recovery successful');
          
          await _logCrash(
            'Recovery successful for: $errorMessage',
            StackTrace.current,
            CrashSeverity.info,
          );
        }
      } catch (e, stackTrace) {
        debugPrint('❌ [CrashReporter] Recovery failed: $e');
        await _logCrash(
          'Recovery failed for: $errorMessage, Recovery error: $e',
          stackTrace,
          CrashSeverity.error,
        );
      } finally {
        _recoveryTimer = null;
      }
    });
  }

  /// 이전 크래시에서 복구 시도
  Future<void> _checkAndRecoverFromPreviousCrashes() async {
    if (_crashLogDir == null) return;

    try {
      final crashDir = Directory(_crashLogDir!);
      if (!crashDir.existsSync()) return;

      final crashFiles = crashDir.listSync()
          .where((file) => file.path.endsWith('.json'))
          .toList();

      if (crashFiles.isNotEmpty) {
        debugPrint('🔍 [CrashReporter] Found ${crashFiles.length} previous crash logs');
        
        // 가장 최근 크래시 파일 분석
        crashFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        final latestCrashFile = crashFiles.first as File;
        
        final crashData = jsonDecode(await latestCrashFile.readAsString());
        final crashEvent = CrashEvent.fromJson(crashData['crashEvent']);
        
        // 최근 크래시가 심각한 경우 복구 시도
        if (crashEvent.severity == CrashSeverity.critical &&
            DateTime.now().difference(crashEvent.timestamp) < const Duration(minutes: 10)) {
          
          debugPrint('🔄 [CrashReporter] Attempting recovery from recent critical crash');
          _attemptRecovery('Previous critical crash: ${crashEvent.error}');
        }
      }
    } catch (e) {
      debugPrint('❌ [CrashReporter] Failed to check previous crashes: $e');
    }
  }

  /// 오래된 로그 정리
  Future<void> _cleanupOldLogs() async {
    if (_crashLogDir == null) return;

    try {
      final crashDir = Directory(_crashLogDir!);
      if (!crashDir.existsSync()) return;

      final now = DateTime.now();
      final cutoffDate = now.subtract(const Duration(days: 30));

      final files = crashDir.listSync()
          .where((file) => file.path.endsWith('.json'))
          .toList();

      for (final file in files) {
        final stat = file.statSync();
        if (stat.modified.isBefore(cutoffDate)) {
          file.deleteSync();
        }
      }

      debugPrint('🧹 [CrashReporter] Cleaned up old crash logs');
    } catch (e) {
      debugPrint('❌ [CrashReporter] Failed to cleanup old logs: $e');
    }
  }

  /// 크래시 정보 출력
  void _printCrashInfo(CrashEvent crashEvent) {
    final severityIcon = {
      CrashSeverity.info: 'ℹ️',
      CrashSeverity.warning: '⚠️',
      CrashSeverity.error: '❌',
      CrashSeverity.critical: '💥',
    }[crashEvent.severity] ?? '❓';

    debugPrint('$severityIcon [CrashReporter] ${crashEvent.severity.name.toUpperCase()}');
    debugPrint('   Error: ${crashEvent.error}');
    if (crashEvent.context != null) {
      debugPrint('   Context: ${crashEvent.context}');
    }
    if (crashEvent.library != null) {
      debugPrint('   Library: ${crashEvent.library}');
    }
    debugPrint('   Time: ${crashEvent.timestamp}');
  }

  /// 크래시 통계 조회
  CrashStats getCrashStats() {
    final now = DateTime.now();
    final recentCrashes = _crashHistory.where(
      (event) => now.difference(event.timestamp) <= const Duration(hours: 1)
    ).length;

    final severityBreakdown = <CrashSeverity, int>{};
    for (final event in _crashHistory) {
      severityBreakdown[event.severity] = 
          (severityBreakdown[event.severity] ?? 0) + 1;
    }

    return CrashStats(
      totalCrashes: _totalCrashes,
      recoveredCrashes: _recoveredCrashes,
      recentCrashes: recentCrashes,
      crashHistory: List.from(_crashHistory),
      severityBreakdown: severityBreakdown,
    );
  }

  /// 크래시 로그 내보내기
  Future<List<File>> exportCrashLogs() async {
    if (_crashLogDir == null) return [];

    try {
      final crashDir = Directory(_crashLogDir!);
      if (!crashDir.existsSync()) return [];

      return crashDir.listSync()
          .where((file) => file.path.endsWith('.json'))
          .cast<File>()
          .toList();
    } catch (e) {
      debugPrint('❌ [CrashReporter] Failed to export crash logs: $e');
      return [];
    }
  }

  /// 정리
  Future<void> dispose() async {
    debugPrint('🧹 [CrashReporter] Disposing...');
    
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _recoveryCallback = null;
    
    // 마지막 상태 저장
    if (_crashHistory.isNotEmpty) {
      await _logCrash(
        'CrashReporter disposed (Total crashes: $_totalCrashes, Recovered: $_recoveredCrashes)',
        StackTrace.current,
        CrashSeverity.info,
      );
    }
    
    _isInitialized = false;
    debugPrint('✅ [CrashReporter] Disposed successfully');
  }
}

/// 크래시 이벤트
class CrashEvent {
  final String error;
  final String stackTrace;
  final CrashSeverity severity;
  final DateTime timestamp;
  final String? context;
  final String? library;
  final Map<String, dynamic>? customData;

  const CrashEvent({
    required this.error,
    required this.stackTrace,
    required this.severity,
    required this.timestamp,
    this.context,
    this.library,
    this.customData,
  });

  Map<String, dynamic> toJson() => {
    'error': error,
    'stackTrace': stackTrace,
    'severity': severity.name,
    'timestamp': timestamp.toIso8601String(),
    'context': context,
    'library': library,
    'customData': customData,
  };

  static CrashEvent fromJson(Map<String, dynamic> json) => CrashEvent(
    error: json['error'] ?? '',
    stackTrace: json['stackTrace'] ?? '',
    severity: CrashSeverity.values.firstWhere(
      (e) => e.name == json['severity'],
      orElse: () => CrashSeverity.error,
    ),
    timestamp: DateTime.parse(json['timestamp']),
    context: json['context'],
    library: json['library'],
    customData: json['customData'],
  );
}

/// 크래시 심각도
enum CrashSeverity {
  info,
  warning,
  error,
  critical,
}

/// 크래시 통계
class CrashStats {
  final int totalCrashes;
  final int recoveredCrashes;
  final int recentCrashes;
  final List<CrashEvent> crashHistory;
  final Map<CrashSeverity, int> severityBreakdown;

  const CrashStats({
    required this.totalCrashes,
    required this.recoveredCrashes,
    required this.recentCrashes,
    required this.crashHistory,
    required this.severityBreakdown,
  });

  double get recoveryRate => 
      totalCrashes > 0 ? recoveredCrashes / totalCrashes : 1.0;

  bool get isStable => recentCrashes < 5 && recoveryRate > 0.8;

  @override
  String toString() {
    return 'CrashStats(total: $totalCrashes, recovered: $recoveredCrashes, '
           'rate: ${(recoveryRate * 100).toStringAsFixed(1)}%, recent: $recentCrashes)';
  }
}