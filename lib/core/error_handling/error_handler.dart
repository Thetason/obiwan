import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized error handling system for the vocal trainer application
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();
  
  final StreamController<AppError> _errorController = 
      StreamController<AppError>.broadcast();
  
  Stream<AppError> get errorStream => _errorController.stream;
  
  final List<AppError> _errorHistory = [];
  final Map<String, int> _errorCounts = {};
  
  /// Handle different types of errors with appropriate logging and user feedback
  void handleError(dynamic error, {
    StackTrace? stackTrace,
    String? context,
    ErrorSeverity severity = ErrorSeverity.medium,
    bool showToUser = true,
    Map<String, dynamic>? additionalData,
  }) {
    final appError = _createAppError(
      error,
      stackTrace: stackTrace,
      context: context,
      severity: severity,
      additionalData: additionalData,
    );
    
    _logError(appError);
    _recordError(appError);
    
    if (showToUser) {
      _errorController.add(appError);
    }
    
    // Handle critical errors
    if (severity == ErrorSeverity.critical) {
      _handleCriticalError(appError);
    }
  }
  
  AppError _createAppError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    ErrorSeverity severity = ErrorSeverity.medium,
    Map<String, dynamic>? additionalData,
  }) {
    final errorType = _determineErrorType(error);
    final message = _extractErrorMessage(error);
    final userMessage = _generateUserFriendlyMessage(error, errorType);
    
    return AppError(
      type: errorType,
      message: message,
      userMessage: userMessage,
      stackTrace: stackTrace ?? StackTrace.current,
      context: context,
      severity: severity,
      timestamp: DateTime.now(),
      additionalData: additionalData ?? {},
    );
  }
  
  ErrorType _determineErrorType(dynamic error) {
    if (error is AudioProcessingException) return ErrorType.audioProcessing;
    if (error is NetworkException) return ErrorType.network;
    if (error is StorageException) return ErrorType.storage;
    if (error is ValidationException) return ErrorType.validation;
    if (error is ModelLoadException) return ErrorType.model;
    if (error is PlatformException) return ErrorType.platform;
    if (error is FileSystemException) return ErrorType.fileSystem;
    if (error is FormatException) return ErrorType.dataFormat;
    if (error is TimeoutException) return ErrorType.timeout;
    if (error is StateError) return ErrorType.state;
    if (error is ArgumentError) return ErrorType.argument;
    
    return ErrorType.unknown;
  }
  
  String _extractErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString();
    } else if (error is String) {
      return error;
    } else {
      return error?.toString() ?? 'Unknown error occurred';
    }
  }
  
  String _generateUserFriendlyMessage(dynamic error, ErrorType type) {
    switch (type) {
      case ErrorType.audioProcessing:
        return '오디오 처리 중 문제가 발생했습니다. 마이크 권한을 확인해주세요.';
      case ErrorType.network:
        return '네트워크 연결을 확인해주세요.';
      case ErrorType.storage:
        return '데이터 저장 중 문제가 발생했습니다. 저장 공간을 확인해주세요.';
      case ErrorType.validation:
        return '입력된 데이터가 올바르지 않습니다.';
      case ErrorType.model:
        return 'AI 모델 로딩 중 문제가 발생했습니다. 앱을 다시 시작해주세요.';
      case ErrorType.platform:
        return '시스템 오류가 발생했습니다.';
      case ErrorType.fileSystem:
        return '파일 시스템 오류가 발생했습니다.';
      case ErrorType.dataFormat:
        return '데이터 형식이 올바르지 않습니다.';
      case ErrorType.timeout:
        return '요청 시간이 초과되었습니다. 다시 시도해주세요.';
      case ErrorType.state:
        return '앱 상태 오류가 발생했습니다. 앱을 다시 시작해주세요.';
      case ErrorType.argument:
        return '잘못된 매개변수가 전달되었습니다.';
      case ErrorType.unknown:
      default:
        return '알 수 없는 오류가 발생했습니다. 문제가 지속되면 고객지원에 문의해주세요.';
    }
  }
  
  void _logError(AppError error) {
    // Console logging for development
    if (kDebugMode) {
      developer.log(
        'Error: ${error.message}',
        name: 'VocalTrainerError',
        error: error.message,
        stackTrace: error.stackTrace,
        level: _getSeverityLevel(error.severity),
      );
    }
    
    // Additional logging can be added here (e.g., crash reporting services)
    _logToAnalytics(error);
  }
  
  int _getSeverityLevel(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return 400; // Info level
      case ErrorSeverity.medium:
        return 900; // Warning level
      case ErrorSeverity.high:
        return 1000; // Error level
      case ErrorSeverity.critical:
        return 1200; // Severe level
    }
  }
  
  void _logToAnalytics(AppError error) {
    // Mock analytics logging
    // In a real app, you would integrate with Firebase Crashlytics, Sentry, etc.
    try {
      final analyticsData = {
        'error_type': error.type.toString(),
        'error_message': error.message,
        'severity': error.severity.toString(),
        'context': error.context,
        'timestamp': error.timestamp.toIso8601String(),
        'platform': defaultTargetPlatform.toString(),
      };
      
      // Mock analytics call
      debugPrint('Analytics: Error logged - ${analyticsData}');
    } catch (e) {
      // Fail silently for analytics errors
      debugPrint('Failed to log error to analytics: $e');
    }
  }
  
  void _recordError(AppError error) {
    _errorHistory.add(error);
    
    // Count error occurrences
    final errorKey = '${error.type.toString()}_${error.message}';
    _errorCounts[errorKey] = (_errorCounts[errorKey] ?? 0) + 1;
    
    // Maintain history size
    if (_errorHistory.length > 1000) {
      _errorHistory.removeAt(0);
    }
  }
  
  void _handleCriticalError(AppError error) {
    // For critical errors, we might want to:
    // 1. Save app state
    // 2. Clear caches
    // 3. Send crash report
    // 4. Show recovery dialog
    
    debugPrint('CRITICAL ERROR: ${error.message}');
    
    // Attempt to save current state
    _attemptStateSave();
    
    // Clear potentially corrupted caches
    _clearCaches();
  }
  
  void _attemptStateSave() {
    try {
      // Save critical app state before potential crash
      debugPrint('Attempting to save app state due to critical error');
    } catch (e) {
      debugPrint('Failed to save app state: $e');
    }
  }
  
  void _clearCaches() {
    try {
      // Clear potentially corrupted caches
      debugPrint('Clearing caches due to critical error');
    } catch (e) {
      debugPrint('Failed to clear caches: $e');
    }
  }
  
  /// Get error statistics for debugging and monitoring
  ErrorStatistics getErrorStatistics() {
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));
    final lastWeek = now.subtract(const Duration(days: 7));
    
    final recent24HourErrors = _errorHistory
        .where((e) => e.timestamp.isAfter(last24Hours))
        .toList();
    
    final recentWeekErrors = _errorHistory
        .where((e) => e.timestamp.isAfter(lastWeek))
        .toList();
    
    return ErrorStatistics(
      totalErrors: _errorHistory.length,
      errors24Hours: recent24HourErrors.length,
      errorsThisWeek: recentWeekErrors.length,
      mostCommonErrors: _getMostCommonErrors(),
      errorCountsByType: _getErrorCountsByType(),
      criticalErrors: _errorHistory
          .where((e) => e.severity == ErrorSeverity.critical)
          .length,
    );
  }
  
  List<String> _getMostCommonErrors() {
    final sortedErrors = _errorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedErrors.take(5).map((e) => '${e.key} (${e.value})').toList();
  }
  
  Map<ErrorType, int> _getErrorCountsByType() {
    final counts = <ErrorType, int>{};
    
    for (final error in _errorHistory) {
      counts[error.type] = (counts[error.type] ?? 0) + 1;
    }
    
    return counts;
  }
  
  /// Clear error history (useful for testing or after handling issues)
  void clearErrorHistory() {
    _errorHistory.clear();
    _errorCounts.clear();
  }
  
  /// Get recent errors for debugging
  List<AppError> getRecentErrors({int limit = 50}) {
    return _errorHistory.reversed.take(limit).toList();
  }
  
  void dispose() {
    _errorController.close();
  }
}

/// Custom exception classes for better error handling

class AudioProcessingException implements Exception {
  final String message;
  final String? details;
  
  AudioProcessingException(this.message, {this.details});
  
  @override
  String toString() => 'AudioProcessingException: $message${details != null ? ' ($details)' : ''}';
}

class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  
  NetworkException(this.message, {this.statusCode});
  
  @override
  String toString() => 'NetworkException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

class StorageException implements Exception {
  final String message;
  final String? path;
  
  StorageException(this.message, {this.path});
  
  @override
  String toString() => 'StorageException: $message${path != null ? ' (Path: $path)' : ''}';
}

class ValidationException implements Exception {
  final String message;
  final String? field;
  final dynamic value;
  
  ValidationException(this.message, {this.field, this.value});
  
  @override
  String toString() => 'ValidationException: $message${field != null ? ' (Field: $field, Value: $value)' : ''}';
}

class ModelLoadException implements Exception {
  final String message;
  final String? modelPath;
  
  ModelLoadException(this.message, {this.modelPath});
  
  @override
  String toString() => 'ModelLoadException: $message${modelPath != null ? ' (Model: $modelPath)' : ''}';
}

/// Data models for error handling

class AppError {
  final ErrorType type;
  final String message;
  final String userMessage;
  final StackTrace stackTrace;
  final String? context;
  final ErrorSeverity severity;
  final DateTime timestamp;
  final Map<String, dynamic> additionalData;
  
  AppError({
    required this.type,
    required this.message,
    required this.userMessage,
    required this.stackTrace,
    this.context,
    required this.severity,
    required this.timestamp,
    required this.additionalData,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'message': message,
      'userMessage': userMessage,
      'context': context,
      'severity': severity.toString(),
      'timestamp': timestamp.toIso8601String(),
      'additionalData': additionalData,
    };
  }
}

class ErrorStatistics {
  final int totalErrors;
  final int errors24Hours;
  final int errorsThisWeek;
  final List<String> mostCommonErrors;
  final Map<ErrorType, int> errorCountsByType;
  final int criticalErrors;
  
  ErrorStatistics({
    required this.totalErrors,
    required this.errors24Hours,
    required this.errorsThisWeek,
    required this.mostCommonErrors,
    required this.errorCountsByType,
    required this.criticalErrors,
  });
}

enum ErrorType {
  audioProcessing,
  network,
  storage,
  validation,
  model,
  platform,
  fileSystem,
  dataFormat,
  timeout,
  state,
  argument,
  unknown,
}

enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}

/// Mixin for easy error handling in widgets and services
mixin ErrorHandlerMixin {
  void handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    ErrorSeverity severity = ErrorSeverity.medium,
    bool showToUser = true,
    Map<String, dynamic>? additionalData,
  }) {
    ErrorHandler().handleError(
      error,
      stackTrace: stackTrace,
      context: context,
      severity: severity,
      showToUser: showToUser,
      additionalData: additionalData,
    );
  }
}