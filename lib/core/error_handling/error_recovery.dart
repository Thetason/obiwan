import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'error_handler.dart';

/// Advanced error recovery system with automatic retry and fallback mechanisms
class ErrorRecoveryManager {
  static final ErrorRecoveryManager _instance = ErrorRecoveryManager._internal();
  factory ErrorRecoveryManager() => _instance;
  ErrorRecoveryManager._internal();
  
  final Map<String, RecoveryStrategy> _recoveryStrategies = {};
  final Map<String, int> _retryAttempts = {};
  final Map<String, DateTime> _lastRetryTime = {};
  final List<RecoveryAction> _recoveryHistory = [];
  
  /// Initialize default recovery strategies
  void initialize() {
    _registerDefaultStrategies();
  }
  
  void _registerDefaultStrategies() {
    // Audio processing errors
    registerRecoveryStrategy(
      'AudioProcessingException',
      RecoveryStrategy(
        maxRetries: 3,
        retryDelay: const Duration(milliseconds: 500),
        backoffMultiplier: 2.0,
        fallbackActions: [
          FallbackAction.reinitializeAudio,
          FallbackAction.switchToBackupProcessor,
          FallbackAction.disableAdvancedFeatures,
        ],
        recoveryConditions: [
          RecoveryCondition.waitForMicrophone,
          RecoveryCondition.checkPermissions,
        ],
      ),
    );
    
    // Network errors
    registerRecoveryStrategy(
      'NetworkException',
      RecoveryStrategy(
        maxRetries: 5,
        retryDelay: const Duration(seconds: 1),
        backoffMultiplier: 1.5,
        fallbackActions: [
          FallbackAction.switchToOfflineMode,
          FallbackAction.useLocalCache,
          FallbackAction.showOfflineMessage,
        ],
        recoveryConditions: [
          RecoveryCondition.checkNetworkConnectivity,
          RecoveryCondition.validateEndpoint,
        ],
      ),
    );
    
    // Storage errors
    registerRecoveryStrategy(
      'StorageException',
      RecoveryStrategy(
        maxRetries: 2,
        retryDelay: const Duration(milliseconds: 200),
        backoffMultiplier: 2.0,
        fallbackActions: [
          FallbackAction.clearCorruptedData,
          FallbackAction.useAlternativeStorage,
          FallbackAction.switchToMemoryStorage,
        ],
        recoveryConditions: [
          RecoveryCondition.checkStorageSpace,
          RecoveryCondition.validateStoragePermissions,
        ],
      ),
    );
    
    // Model loading errors
    registerRecoveryStrategy(
      'ModelLoadException',
      RecoveryStrategy(
        maxRetries: 2,
        retryDelay: const Duration(seconds: 2),
        backoffMultiplier: 1.0,
        fallbackActions: [
          FallbackAction.useBackupModel,
          FallbackAction.downloadModel,
          FallbackAction.useBasicMode,
        ],
        recoveryConditions: [
          RecoveryCondition.validateModelFiles,
          RecoveryCondition.checkModelVersion,
        ],
      ),
    );
    
    // Validation errors
    registerRecoveryStrategy(
      'ValidationException',
      RecoveryStrategy(
        maxRetries: 1,
        retryDelay: const Duration(milliseconds: 100),
        backoffMultiplier: 1.0,
        fallbackActions: [
          FallbackAction.sanitizeInput,
          FallbackAction.useDefaultValues,
          FallbackAction.skipValidation,
        ],
        recoveryConditions: [
          RecoveryCondition.validateInputFormat,
        ],
      ),
    );
  }
  
  /// Register a recovery strategy for a specific error type
  void registerRecoveryStrategy(String errorType, RecoveryStrategy strategy) {
    _recoveryStrategies[errorType] = strategy;
  }
  
  /// Attempt to recover from an error
  Future<RecoveryResult> attemptRecovery(AppError error, {
    Function? originalOperation,
    Map<String, dynamic>? context,
  }) async {
    final errorType = error.type.toString();
    final strategy = _recoveryStrategies[errorType];
    
    if (strategy == null) {
      return RecoveryResult.failure('No recovery strategy found for $errorType');
    }
    
    final recoveryKey = '${errorType}_${error.context ?? 'unknown'}';
    final attempts = _retryAttempts[recoveryKey] ?? 0;
    
    // Check if we've exceeded max retries
    if (attempts >= strategy.maxRetries) {
      return await _executeFallback(error, strategy, context);
    }
    
    // Check retry conditions
    final conditionResult = await _checkRecoveryConditions(strategy.recoveryConditions, context);
    if (!conditionResult.success) {
      return RecoveryResult.failure('Recovery conditions not met: ${conditionResult.message}');
    }
    
    // Wait for retry delay with exponential backoff
    final delay = _calculateRetryDelay(strategy, attempts);
    await Future.delayed(delay);
    
    // Update retry tracking
    _retryAttempts[recoveryKey] = attempts + 1;
    _lastRetryTime[recoveryKey] = DateTime.now();
    
    // Attempt recovery
    try {
      if (originalOperation != null) {
        await originalOperation();
        
        // Success - reset retry counter
        _retryAttempts.remove(recoveryKey);
        _lastRetryTime.remove(recoveryKey);
        
        _recordRecoveryAction(RecoveryAction(
          errorType: errorType,
          action: 'retry_success',
          timestamp: DateTime.now(),
          attempt: attempts + 1,
          success: true,
        ));
        
        return RecoveryResult.success('Recovery successful after ${attempts + 1} attempts');
      } else {
        return RecoveryResult.failure('No original operation provided for retry');
      }
    } catch (e, stackTrace) {
      _recordRecoveryAction(RecoveryAction(
        errorType: errorType,
        action: 'retry_failed',
        timestamp: DateTime.now(),
        attempt: attempts + 1,
        success: false,
        details: e.toString(),
      ));
      
      // If this was the last retry attempt, try fallback
      if (attempts + 1 >= strategy.maxRetries) {
        return await _executeFallback(error, strategy, context);
      }
      
      // Recursive call for next retry
      return await attemptRecovery(error, originalOperation: originalOperation, context: context);
    }
  }
  
  Duration _calculateRetryDelay(RecoveryStrategy strategy, int attempts) {
    final baseDelay = strategy.retryDelay.inMilliseconds;
    final multipliedDelay = baseDelay * math.pow(strategy.backoffMultiplier, attempts);
    
    // Add jitter to prevent thundering herd
    final jitter = math.Random().nextDouble() * 0.1 * multipliedDelay;
    
    return Duration(milliseconds: (multipliedDelay + jitter).round());
  }
  
  Future<ConditionResult> _checkRecoveryConditions(
    List<RecoveryCondition> conditions,
    Map<String, dynamic>? context,
  ) async {
    for (final condition in conditions) {
      final result = await _evaluateCondition(condition, context);
      if (!result.success) {
        return result;
      }
    }
    return ConditionResult.success();
  }
  
  Future<ConditionResult> _evaluateCondition(
    RecoveryCondition condition,
    Map<String, dynamic>? context,
  ) async {
    switch (condition) {
      case RecoveryCondition.waitForMicrophone:
        return await _checkMicrophoneAvailability();
        
      case RecoveryCondition.checkPermissions:
        return await _checkPermissions();
        
      case RecoveryCondition.checkNetworkConnectivity:
        return await _checkNetworkConnectivity();
        
      case RecoveryCondition.validateEndpoint:
        return await _validateEndpoint(context?['endpoint']);
        
      case RecoveryCondition.checkStorageSpace:
        return await _checkStorageSpace();
        
      case RecoveryCondition.validateStoragePermissions:
        return await _validateStoragePermissions();
        
      case RecoveryCondition.validateModelFiles:
        return await _validateModelFiles(context?['modelPath']);
        
      case RecoveryCondition.checkModelVersion:
        return await _checkModelVersion(context?['expectedVersion']);
        
      case RecoveryCondition.validateInputFormat:
        return await _validateInputFormat(context?['input']);
        
      default:
        return ConditionResult.failure('Unknown recovery condition: $condition');
    }
  }
  
  Future<RecoveryResult> _executeFallback(
    AppError error,
    RecoveryStrategy strategy,
    Map<String, dynamic>? context,
  ) async {
    for (final fallbackAction in strategy.fallbackActions) {
      try {
        final result = await _executeFallbackAction(fallbackAction, error, context);
        if (result.success) {
          _recordRecoveryAction(RecoveryAction(
            errorType: error.type.toString(),
            action: 'fallback_${fallbackAction.toString()}',
            timestamp: DateTime.now(),
            success: true,
          ));
          
          return result;
        }
      } catch (e, stackTrace) {
        _recordRecoveryAction(RecoveryAction(
          errorType: error.type.toString(),
          action: 'fallback_${fallbackAction.toString()}',
          timestamp: DateTime.now(),
          success: false,
          details: e.toString(),
        ));
      }
    }
    
    return RecoveryResult.failure('All fallback actions failed');
  }
  
  Future<RecoveryResult> _executeFallbackAction(
    FallbackAction action,
    AppError error,
    Map<String, dynamic>? context,
  ) async {
    switch (action) {
      case FallbackAction.reinitializeAudio:
        return await _reinitializeAudio();
        
      case FallbackAction.switchToBackupProcessor:
        return await _switchToBackupProcessor();
        
      case FallbackAction.disableAdvancedFeatures:
        return await _disableAdvancedFeatures();
        
      case FallbackAction.switchToOfflineMode:
        return await _switchToOfflineMode();
        
      case FallbackAction.useLocalCache:
        return await _useLocalCache();
        
      case FallbackAction.showOfflineMessage:
        return await _showOfflineMessage();
        
      case FallbackAction.clearCorruptedData:
        return await _clearCorruptedData(context?['dataPath']);
        
      case FallbackAction.useAlternativeStorage:
        return await _useAlternativeStorage();
        
      case FallbackAction.switchToMemoryStorage:
        return await _switchToMemoryStorage();
        
      case FallbackAction.useBackupModel:
        return await _useBackupModel();
        
      case FallbackAction.downloadModel:
        return await _downloadModel(context?['modelUrl']);
        
      case FallbackAction.useBasicMode:
        return await _useBasicMode();
        
      case FallbackAction.sanitizeInput:
        return await _sanitizeInput(context?['input']);
        
      case FallbackAction.useDefaultValues:
        return await _useDefaultValues();
        
      case FallbackAction.skipValidation:
        return await _skipValidation();
        
      default:
        return RecoveryResult.failure('Unknown fallback action: $action');
    }
  }
  
  void _recordRecoveryAction(RecoveryAction action) {
    _recoveryHistory.add(action);
    
    // Maintain history size
    if (_recoveryHistory.length > 1000) {
      _recoveryHistory.removeAt(0);
    }
  }
  
  // Mock implementations of condition checks and fallback actions
  // In a real app, these would contain actual implementation logic
  
  Future<ConditionResult> _checkMicrophoneAvailability() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return ConditionResult.success();
  }
  
  Future<ConditionResult> _checkPermissions() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return ConditionResult.success();
  }
  
  Future<ConditionResult> _checkNetworkConnectivity() async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Mock network check
    return ConditionResult.success();
  }
  
  Future<ConditionResult> _validateEndpoint(String? endpoint) async {
    if (endpoint == null) {
      return ConditionResult.failure('No endpoint provided');
    }
    return ConditionResult.success();
  }
  
  Future<ConditionResult> _checkStorageSpace() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return ConditionResult.success();
  }
  
  Future<ConditionResult> _validateStoragePermissions() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return ConditionResult.success();
  }
  
  Future<ConditionResult> _validateModelFiles(String? modelPath) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return ConditionResult.success();
  }
  
  Future<ConditionResult> _checkModelVersion(String? expectedVersion) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return ConditionResult.success();  
  }
  
  Future<ConditionResult> _validateInputFormat(dynamic input) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return ConditionResult.success();
  }
  
  Future<RecoveryResult> _reinitializeAudio() async {
    await Future.delayed(const Duration(milliseconds: 500));
    debugPrint('Reinitializing audio system');
    return RecoveryResult.success('Audio system reinitialized');
  }
  
  Future<RecoveryResult> _switchToBackupProcessor() async {
    await Future.delayed(const Duration(milliseconds: 200));
    debugPrint('Switching to backup audio processor');
    return RecoveryResult.success('Switched to backup processor');
  }
  
  Future<RecoveryResult> _disableAdvancedFeatures() async {
    debugPrint('Disabling advanced audio features');
    return RecoveryResult.success('Advanced features disabled');
  }
  
  Future<RecoveryResult> _switchToOfflineMode() async {
    debugPrint('Switching to offline mode');
    return RecoveryResult.success('Switched to offline mode');
  }
  
  Future<RecoveryResult> _useLocalCache() async {
    debugPrint('Using local cache');
    return RecoveryResult.success('Using local cache data');
  }
  
  Future<RecoveryResult> _showOfflineMessage() async {
    debugPrint('Showing offline message to user');
    return RecoveryResult.success('Offline message displayed');
  }
  
  Future<RecoveryResult> _clearCorruptedData(String? dataPath) async {
    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('Clearing corrupted data at: $dataPath');
    return RecoveryResult.success('Corrupted data cleared');
  }
  
  Future<RecoveryResult> _useAlternativeStorage() async {
    debugPrint('Switching to alternative storage');
    return RecoveryResult.success('Using alternative storage');
  }
  
  Future<RecoveryResult> _switchToMemoryStorage() async {
    debugPrint('Switching to memory-only storage');
    return RecoveryResult.success('Using memory storage');
  }
  
  Future<RecoveryResult> _useBackupModel() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    debugPrint('Loading backup model');
    return RecoveryResult.success('Backup model loaded');
  }
  
  Future<RecoveryResult> _downloadModel(String? modelUrl) async {
    await Future.delayed(const Duration(seconds: 3));
    debugPrint('Downloading model from: $modelUrl');
    return RecoveryResult.success('Model downloaded successfully');
  }
  
  Future<RecoveryResult> _useBasicMode() async {
    debugPrint('Switching to basic mode');
    return RecoveryResult.success('Basic mode activated');
  }
  
  Future<RecoveryResult> _sanitizeInput(dynamic input) async {
    debugPrint('Sanitizing input data');
    return RecoveryResult.success('Input data sanitized');
  }
  
  Future<RecoveryResult> _useDefaultValues() async {
    debugPrint('Using default values');
    return RecoveryResult.success('Default values applied');
  }
  
  Future<RecoveryResult> _skipValidation() async {
    debugPrint('Skipping validation');
    return RecoveryResult.success('Validation skipped');
  }
  
  /// Get recovery statistics
  RecoveryStatistics getRecoveryStatistics() {
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));
    
    final recentActions = _recoveryHistory
        .where((action) => action.timestamp.isAfter(last24Hours))
        .toList();
    
    final successfulRecoveries = recentActions.where((action) => action.success).length;
    final failedRecoveries = recentActions.where((action) => !action.success).length;
    
    final recoveryByType = <String, int>{};
    for (final action in recentActions) {
      recoveryByType[action.errorType] = (recoveryByType[action.errorType] ?? 0) + 1;
    }
    
    return RecoveryStatistics(
      totalRecoveryAttempts: _recoveryHistory.length,
      recentRecoveryAttempts: recentActions.length,
      successfulRecoveries: successfulRecoveries,
      failedRecoveries: failedRecoveries,
      recoverySuccessRate: recentActions.isNotEmpty 
          ? successfulRecoveries / recentActions.length 
          : 0.0,
      recoveryByType: recoveryByType,
    );
  }
  
  /// Clear recovery history and retry counters
  void clearRecoveryHistory() {
    _recoveryHistory.clear();
    _retryAttempts.clear();
    _lastRetryTime.clear();
  }
  
  /// Get recent recovery actions for debugging
  List<RecoveryAction> getRecentRecoveryActions({int limit = 50}) {
    return _recoveryHistory.reversed.take(limit).toList();
  }
}

// Data models for error recovery

class RecoveryStrategy {
  final int maxRetries;
  final Duration retryDelay;
  final double backoffMultiplier;
  final List<FallbackAction> fallbackActions;
  final List<RecoveryCondition> recoveryConditions;
  
  RecoveryStrategy({
    required this.maxRetries,
    required this.retryDelay,
    required this.backoffMultiplier,
    required this.fallbackActions,
    required this.recoveryConditions,
  });
}

class RecoveryResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  
  RecoveryResult._({
    required this.success,
    required this.message,
    this.data,
  });
  
  factory RecoveryResult.success(String message, {Map<String, dynamic>? data}) {
    return RecoveryResult._(success: true, message: message, data: data);
  }
  
  factory RecoveryResult.failure(String message, {Map<String, dynamic>? data}) {
    return RecoveryResult._(success: false, message: message, data: data);
  }
}

class ConditionResult {
  final bool success;
  final String message;
  
  ConditionResult._({required this.success, required this.message});
  
  factory ConditionResult.success([String message = 'Condition met']) {
    return ConditionResult._(success: true, message: message);
  }
  
  factory ConditionResult.failure(String message) {
    return ConditionResult._(success: false, message: message);
  }
}

class RecoveryAction {
  final String errorType;
  final String action;
  final DateTime timestamp;
  final int? attempt;
  final bool success;
  final String? details;
  
  RecoveryAction({
    required this.errorType,
    required this.action,
    required this.timestamp,
    this.attempt,
    required this.success,
    this.details,
  });
}

class RecoveryStatistics {
  final int totalRecoveryAttempts;
  final int recentRecoveryAttempts;
  final int successfulRecoveries;
  final int failedRecoveries;
  final double recoverySuccessRate;
  final Map<String, int> recoveryByType;
  
  RecoveryStatistics({
    required this.totalRecoveryAttempts,
    required this.recentRecoveryAttempts,
    required this.successfulRecoveries,
    required this.failedRecoveries,
    required this.recoverySuccessRate,
    required this.recoveryByType,
  });
}

enum RecoveryCondition {
  waitForMicrophone,
  checkPermissions,
  checkNetworkConnectivity,
  validateEndpoint,
  checkStorageSpace,
  validateStoragePermissions,
  validateModelFiles,
  checkModelVersion,
  validateInputFormat,
}

enum FallbackAction {
  reinitializeAudio,
  switchToBackupProcessor,
  disableAdvancedFeatures,
  switchToOfflineMode,
  useLocalCache,
  showOfflineMessage,
  clearCorruptedData,
  useAlternativeStorage,
  switchToMemoryStorage,
  useBackupModel,
  downloadModel,
  useBasicMode,
  sanitizeInput,
  useDefaultValues,
  skipValidation,
}

/// Mixin for classes that need error recovery capabilities
mixin ErrorRecoveryMixin {
  Future<RecoveryResult> attemptRecovery(
    AppError error, {
    Function? originalOperation,
    Map<String, dynamic>? context,
  }) {
    return ErrorRecoveryManager().attemptRecovery(
      error,
      originalOperation: originalOperation,
      context: context,
    );
  }
  
  Future<T> withRecovery<T>(
    Future<T> Function() operation, {
    String? context,
    Map<String, dynamic>? recoveryContext,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      final appError = AppError(
        type: ErrorHandler()._determineErrorType(error),
        message: error.toString(),
        userMessage: 'Operation failed',
        stackTrace: stackTrace,
        context: context,
        severity: ErrorSeverity.medium,
        timestamp: DateTime.now(),
        additionalData: recoveryContext ?? {},
      );
      
      final recoveryResult = await attemptRecovery(
        appError,
        originalOperation: operation,
        context: recoveryContext,
      );
      
      if (!recoveryResult.success) {
        rethrow;
      }
      
      // If recovery was successful, try the operation again
      return await operation();
    }
  }
}