import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'debug_logger.dart';

/// 중앙 집중식 에러 처리 시스템
class ErrorHandler {
  static ErrorHandler? _instance;
  static ErrorHandler get instance {
    _instance ??= ErrorHandler._();
    return _instance!;
  }

  ErrorHandler._();

  /// Flutter 에러 처리 초기화
  void initialize() {
    // Flutter 프레임워크 에러 처리
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // 비동기 에러 처리
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleAsyncError(error, stack);
      return true;
    };

    logger.info('Error Handler initialized', tag: 'ERROR_HANDLER');
  }

  /// Flutter 프레임워크 에러 처리
  void _handleFlutterError(FlutterErrorDetails details) {
    logger.error(
      'Flutter Error: ${details.summary}',
      tag: 'FLUTTER',
      error: details.exception,
      stackTrace: details.stack,
    );

    // 추가 컨텍스트 정보
    if (details.context != null) {
      logger.error('Error Context: ${details.context}', tag: 'FLUTTER');
    }
    
    if (details.library != null) {
      logger.error('Library: ${details.library}', tag: 'FLUTTER');
    }

    // 디버그 모드에서는 기본 동작 수행
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  }

  /// 비동기 에러 처리
  void _handleAsyncError(Object error, StackTrace stack) {
    logger.error(
      'Async Error: $error',
      tag: 'ASYNC',
      error: error,
      stackTrace: stack,
    );
  }

  /// 오디오 관련 에러 처리
  Future<T?> handleAudioError<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    try {
      logger.audio('Starting $operationName');
      final result = await operation();
      logger.audio('Completed $operationName successfully');
      return result;
    } on PlatformException catch (e) {
      await _handlePlatformException(e, operationName);
      return null;
    } catch (e, stack) {
      await logger.error(
        'Audio operation failed: $operationName',
        tag: 'AUDIO',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// 네이티브 플랫폼 에러 처리
  Future<void> _handlePlatformException(PlatformException e, String operation) async {
    String errorCategory = _categorizePlatformError(e.code);
    
    await logger.error(
      'Platform Error in $operation: ${e.message}',
      tag: 'PLATFORM',
      error: e,
    );

    // 에러 코드별 상세 분석
    await logger.error('Error Code: ${e.code}', tag: 'PLATFORM');
    await logger.error('Error Category: $errorCategory', tag: 'PLATFORM');
    
    if (e.details != null) {
      await logger.error('Error Details: ${e.details}', tag: 'PLATFORM');
    }

    // 해결 제안
    final suggestion = _getErrorSuggestion(e.code);
    if (suggestion.isNotEmpty) {
      await logger.warning('Suggestion: $suggestion', tag: 'PLATFORM');
    }
  }

  /// 플랫폼 에러 코드 분류
  String _categorizePlatformError(String code) {
    switch (code) {
      case 'PERMISSION_DENIED':
        return '권한 거부';
      case 'ENGINE_NOT_READY':
      case 'ENGINE_NOT_RUNNING':
        return '오디오 엔진 문제';
      case 'INPUT_NODE_MISSING':
        return '오디오 입력 문제';
      case 'BUFFER_PROCESSING_FAILED':
      case 'NO_SAMPLES':
        return '오디오 데이터 처리 문제';
      case 'START_FAILED':
        return '녹음 시작 실패';
      default:
        return '기타 플랫폼 에러';
    }
  }

  /// 에러별 해결 제안
  String _getErrorSuggestion(String code) {
    switch (code) {
      case 'PERMISSION_DENIED':
        return '시스템 설정에서 마이크 권한을 허용해주세요.';
      case 'ENGINE_NOT_READY':
        return '오디오 엔진을 재초기화해보세요.';
      case 'ENGINE_NOT_RUNNING':
        return '녹음 시작 후 오디오 엔진이 정상 실행되는지 확인하세요.';
      case 'INPUT_NODE_MISSING':
        return '마이크가 연결되어 있는지 확인하세요.';
      case 'BUFFER_PROCESSING_FAILED':
        return 'processAudioBuffer 함수가 호출되는지 확인하세요.';
      case 'NO_SAMPLES':
        return '오디오 버퍼가 정상적으로 처리되는지 확인하세요.';
      default:
        return '';
    }
  }

  /// 피치 분석 에러 처리
  Future<T?> handlePitchAnalysisError<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    try {
      logger.pitch('Starting $operationName');
      final result = await operation();
      logger.pitch('Completed $operationName successfully');
      return result;
    } catch (e, stack) {
      await logger.error(
        'Pitch analysis failed: $operationName',
        tag: 'PITCH',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// 네트워크 에러 처리
  Future<T?> handleNetworkError<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    try {
      logger.info('Starting network operation: $operationName', tag: 'NETWORK');
      final result = await operation();
      logger.info('Completed network operation: $operationName', tag: 'NETWORK');
      return result;
    } on TimeoutException catch (e) {
      await logger.error(
        'Network timeout in $operationName',
        tag: 'NETWORK',
        error: e,
      );
      return null;
    } catch (e, stack) {
      await logger.error(
        'Network error in $operationName',
        tag: 'NETWORK',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// 일반적인 try-catch 헬퍼
  Future<T?> safeExecute<T>(
    Future<T> Function() operation, {
    required String operationName,
    String? tag,
    bool logStart = false,
  }) async {
    try {
      if (logStart) {
        await logger.info('Starting $operationName', tag: tag);
      }
      
      final result = await operation();
      
      if (logStart) {
        await logger.info('Completed $operationName successfully', tag: tag);
      }
      
      return result;
    } catch (e, stack) {
      await logger.error(
        'Operation failed: $operationName',
        tag: tag ?? 'GENERAL',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// 동기 함수용 에러 처리
  T? safeExecuteSync<T>(
    T Function() operation, {
    required String operationName,
    String? tag,
  }) {
    try {
      return operation();
    } catch (e, stack) {
      logger.error(
        'Sync operation failed: $operationName',
        tag: tag ?? 'GENERAL',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// 에러 상황 보고서 생성
  Future<String> generateErrorReport() async {
    final recentLogs = await logger.getRecentLogs(lines: 50);
    final timestamp = DateTime.now().toIso8601String();
    
    return '''
=== Vocal Trainer AI Error Report ===
Generated: $timestamp

Recent Logs (Last 50 lines):
$recentLogs

=== End of Report ===
''';
  }
}

/// 전역 에러 핸들러 인스턴스
final errorHandler = ErrorHandler.instance;

/// 편의 함수들
extension ErrorHandlerExtensions on Future {
  /// Future에 에러 처리 추가
  Future<T?> withErrorHandling<T>(String operationName, {String? tag}) {
    return errorHandler.safeExecute<T>(
      () => this as Future<T>,
      operationName: operationName,
      tag: tag,
    );
  }
}