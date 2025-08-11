import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/dual_engine_service.dart';
import '../services/native_audio_service.dart';
import 'resource_manager.dart';

/// 자동 복구 시스템 - 서버 연결 실패, 오디오 엔진 크래시, 피치 분석 실패시 자동 복구
class ResilienceManager {
  static final ResilienceManager _instance = ResilienceManager._internal();
  factory ResilienceManager() => _instance;
  ResilienceManager._internal();

  final ResourceManager _resourceManager = ResourceManager();
  
  // 서비스 인스턴스들
  DualEngineService? _dualEngineService;
  NativeAudioService? _nativeAudioService;
  
  // 연결 상태 모니터링
  bool _isConnected = true;
  Timer? _connectionMonitorTimer;
  Timer? _healthCheckTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  // 복구 상태 추적
  final Map<String, RetryState> _retryStates = {};
  final Map<String, DateTime> _lastSuccessfulOperations = {};
  
  // 복구 통계
  int _totalRecoveryAttempts = 0;
  int _successfulRecoveries = 0;
  final List<RecoveryEvent> _recoveryHistory = [];
  
  bool _isInitialized = false;

  /// 초기화
  Future<void> initialize({
    DualEngineService? dualEngineService,
    NativeAudioService? nativeAudioService,
  }) async {
    if (_isInitialized) return;

    _dualEngineService = dualEngineService ?? DualEngineService();
    _nativeAudioService = nativeAudioService ?? NativeAudioService.instance;

    await _setupConnectivityMonitoring();
    _startHealthChecking();
    
    _isInitialized = true;
    _logRecovery('ResilienceManager initialized', RecoveryType.initialization);
    debugPrint('🛡️ [ResilienceManager] Initialized successfully');
  }

  /// 연결 상태 모니터링 설정
  Future<void> _setupConnectivityMonitoring() async {
    // 연결 상태 초기화
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    _isConnected = result != ConnectivityResult.none;

    // 연결 상태 변화 감지
    _connectivitySubscription = _resourceManager.registerStreamSubscription(
      connectivity.onConnectivityChanged.listen((result) {
        final wasConnected = _isConnected;
        _isConnected = result != ConnectivityResult.none;
        
        if (!wasConnected && _isConnected) {
          _onConnectionRestored();
        } else if (wasConnected && !_isConnected) {
          _onConnectionLost();
        }
      }),
      debugName: 'ConnectivityMonitoring'
    );

    // 주기적 연결 모니터링
    _connectionMonitorTimer = _resourceManager.registerTimer(
      const Duration(seconds: 30),
      _checkConnectionHealth,
      debugName: 'ConnectionMonitor'
    );
  }

  /// 헬스 체크 시작
  void _startHealthChecking() {
    _healthCheckTimer = _resourceManager.registerTimer(
      const Duration(minutes: 2),
      _performHealthCheck,
      debugName: 'HealthCheck'
    );
  }

  /// 연결 복구됨
  void _onConnectionRestored() {
    debugPrint('🔄 [ResilienceManager] Connection restored');
    _logRecovery('Connection restored', RecoveryType.networkReconnection);
    
    // 모든 재시도 상태 초기화
    for (final key in _retryStates.keys.toList()) {
      _retryStates[key] = RetryState();
    }
    
    // 즉시 헬스 체크 수행
    _performHealthCheck();
  }

  /// 연결 끊김
  void _onConnectionLost() {
    debugPrint('❌ [ResilienceManager] Connection lost');
    _logRecovery('Connection lost', RecoveryType.networkDisconnection);
  }

  /// 연결 상태 확인
  void _checkConnectionHealth() async {
    if (!_isConnected) return;

    try {
      // 서버 상태 확인
      if (_dualEngineService != null) {
        final status = await _dualEngineService!.checkStatus()
            .timeout(const Duration(seconds: 10));
        
        if (!status.anyHealthy) {
          await _recoverServerConnection();
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ResilienceManager] Connection health check failed: $e');
      await _recoverServerConnection();
    }
  }

  /// 종합 헬스 체크
  void _performHealthCheck() async {
    debugPrint('🔍 [ResilienceManager] Performing health check');
    
    // 서버 연결 상태 확인
    await _checkServerHealth();
    
    // 오디오 서비스 상태 확인
    await _checkAudioServiceHealth();
    
    // 리소스 누수 확인
    _checkResourceLeaks();
    
    debugPrint('✅ [ResilienceManager] Health check completed');
  }

  /// 서버 상태 확인 및 복구
  Future<void> _checkServerHealth() async {
    if (_dualEngineService == null) return;

    try {
      final status = await _dualEngineService!.checkStatus()
          .timeout(const Duration(seconds: 15));
      
      if (!status.anyHealthy) {
        await _recoverServerConnection();
      } else {
        _recordSuccessfulOperation('server_health');
      }
    } catch (e) {
      debugPrint('❌ [ResilienceManager] Server health check failed: $e');
      await _recoverServerConnection();
    }
  }

  /// 오디오 서비스 상태 확인 및 복구
  Future<void> _checkAudioServiceHealth() async {
    if (_nativeAudioService == null) return;

    try {
      // 오디오 서비스 상태 확인 (간접적으로)
      final isInitialized = _nativeAudioService!.isInitialized;
      
      if (!isInitialized) {
        await _recoverAudioService();
      } else {
        _recordSuccessfulOperation('audio_service');
      }
    } catch (e) {
      debugPrint('❌ [ResilienceManager] Audio service health check failed: $e');
      await _recoverAudioService();
    }
  }

  /// 리소스 누수 확인
  void _checkResourceLeaks() {
    final status = _resourceManager.getStatus();
    
    if (status.totalResourceCount > 50) { // 임계값 설정
      debugPrint('⚠️ [ResilienceManager] High resource count detected: ${status.totalResourceCount}');
      _logRecovery('High resource count: ${status.totalResourceCount}', RecoveryType.resourceCleanup);
      
      // 선택적 리소스 정리 (전체 정리는 피함)
      _performSelectiveResourceCleanup();
    }
  }

  /// 서버 연결 복구
  Future<void> _recoverServerConnection() async {
    const serviceName = 'server_connection';
    final retryState = _getRetryState(serviceName);
    
    if (retryState.shouldRetry()) {
      _totalRecoveryAttempts++;
      debugPrint('🔄 [ResilienceManager] Attempting server connection recovery (attempt ${retryState.attemptCount + 1})');
      
      try {
        // Exponential backoff으로 대기
        await Future.delayed(retryState.getBackoffDelay());
        
        // 새로운 DualEngineService 인스턴스 생성하여 복구 시도
        _dualEngineService = DualEngineService();
        
        // 연결 테스트
        final status = await _dualEngineService!.checkStatus()
            .timeout(const Duration(seconds: 10));
        
        if (status.anyHealthy) {
          retryState.recordSuccess();
          _successfulRecoveries++;
          _recordSuccessfulOperation('server_connection');
          _logRecovery('Server connection recovered', RecoveryType.serverReconnection);
          debugPrint('✅ [ResilienceManager] Server connection recovered successfully');
        } else {
          retryState.recordFailure();
          debugPrint('❌ [ResilienceManager] Server connection recovery failed');
        }
        
      } catch (e) {
        retryState.recordFailure();
        debugPrint('❌ [ResilienceManager] Server connection recovery error: $e');
      }
    } else {
      debugPrint('⏸️ [ResilienceManager] Server connection recovery disabled (too many failures)');
    }
  }

  /// 오디오 서비스 복구
  Future<void> _recoverAudioService() async {
    const serviceName = 'audio_service';
    final retryState = _getRetryState(serviceName);
    
    if (retryState.shouldRetry()) {
      _totalRecoveryAttempts++;
      debugPrint('🔄 [ResilienceManager] Attempting audio service recovery (attempt ${retryState.attemptCount + 1})');
      
      try {
        await Future.delayed(retryState.getBackoffDelay());
        
        // 오디오 서비스 재초기화
        await _nativeAudioService!.initialize();
        
        retryState.recordSuccess();
        _successfulRecoveries++;
        _recordSuccessfulOperation('audio_service');
        _logRecovery('Audio service recovered', RecoveryType.audioRestart);
        debugPrint('✅ [ResilienceManager] Audio service recovered successfully');
        
      } catch (e) {
        retryState.recordFailure();
        debugPrint('❌ [ResilienceManager] Audio service recovery error: $e');
      }
    } else {
      debugPrint('⏸️ [ResilienceManager] Audio service recovery disabled (too many failures)');
    }
  }

  /// 선택적 리소스 정리
  void _performSelectiveResourceCleanup() {
    // 오래된 성공 기록 정리
    final now = DateTime.now();
    _lastSuccessfulOperations.removeWhere((key, time) => 
        now.difference(time) > const Duration(hours: 1));
    
    // 오래된 복구 히스토리 정리
    _recoveryHistory.removeWhere((event) => 
        now.difference(event.timestamp) > const Duration(hours: 24));
    
    debugPrint('🧹 [ResilienceManager] Selective resource cleanup completed');
  }

  /// 피치 분석 실패시 폴백 알고리즘
  Future<double?> performPitchAnalysisWithFallback(
    List<double> audioData, {
    Duration? timeout,
  }) async {
    const operationName = 'pitch_analysis';
    
    try {
      // 주 분석 시도
      if (_dualEngineService != null) {
        final result = await _dualEngineService!.analyzeSinglePitch(
          Float32List.fromList(audioData)
        ).timeout(timeout ?? const Duration(seconds: 5));
        
        if (result != null && result.frequency > 0) {
          _recordSuccessfulOperation(operationName);
          return result.frequency;
        }
      }
      
      // 폴백 알고리즘 1: 간단한 FFT 기반 피치 검출
      final fallbackFreq = _performBasicPitchDetection(audioData);
      if (fallbackFreq > 0) {
        _logRecovery('Used fallback pitch detection', RecoveryType.fallbackAlgorithm);
        return fallbackFreq;
      }
      
    } catch (e) {
      debugPrint('❌ [ResilienceManager] Pitch analysis failed: $e');
    }
    
    // 폴백 알고리즘 2: 기본값 반환
    _logRecovery('Used default pitch value', RecoveryType.fallbackAlgorithm);
    return null;
  }

  /// 기본 피치 검출 (폴백 알고리즘)
  double _performBasicPitchDetection(List<double> audioData) {
    if (audioData.length < 1024) return 0.0;
    
    try {
      // 간단한 autocorrelation 기반 피치 검출
      const sampleRate = 48000.0;
      const minFreq = 80.0;   // 최소 주파수 (Hz)
      const maxFreq = 1000.0; // 최대 주파수 (Hz)
      
      final minPeriod = (sampleRate / maxFreq).floor();
      final maxPeriod = (sampleRate / minFreq).floor();
      
      double maxCorrelation = 0.0;
      int bestPeriod = minPeriod;
      
      // Autocorrelation 계산
      for (int period = minPeriod; period <= math.min(maxPeriod, audioData.length ~/ 2); period++) {
        double correlation = 0.0;
        
        for (int i = 0; i < audioData.length - period; i++) {
          correlation += audioData[i] * audioData[i + period];
        }
        
        if (correlation > maxCorrelation) {
          maxCorrelation = correlation;
          bestPeriod = period;
        }
      }
      
      // 주파수 계산
      if (maxCorrelation > 0) {
        return sampleRate / bestPeriod;
      }
      
    } catch (e) {
      debugPrint('❌ [ResilienceManager] Basic pitch detection failed: $e');
    }
    
    return 0.0;
  }

  /// 재시도 상태 가져오기
  RetryState _getRetryState(String serviceName) {
    return _retryStates.putIfAbsent(serviceName, () => RetryState());
  }

  /// 성공적인 작업 기록
  void _recordSuccessfulOperation(String operationName) {
    _lastSuccessfulOperations[operationName] = DateTime.now();
    
    // 해당 서비스의 재시도 상태 초기화
    _retryStates[operationName]?.recordSuccess();
  }

  /// 복구 이벤트 로깅
  void _logRecovery(String message, RecoveryType type) {
    final event = RecoveryEvent(
      message: message,
      type: type,
      timestamp: DateTime.now(),
    );
    
    _recoveryHistory.add(event);
    
    // 히스토리 크기 제한 (최근 100개만 보관)
    if (_recoveryHistory.length > 100) {
      _recoveryHistory.removeAt(0);
    }
    
    if (kDebugMode) {
      debugPrint('🛡️ [ResilienceManager] $message');
    }
  }

  /// 복구 통계 조회
  RecoveryStats getRecoveryStats() {
    final now = DateTime.now();
    final recentRecoveries = _recoveryHistory.where(
      (event) => now.difference(event.timestamp) <= const Duration(hours: 1)
    ).length;
    
    return RecoveryStats(
      totalRecoveryAttempts: _totalRecoveryAttempts,
      successfulRecoveries: _successfulRecoveries,
      recentRecoveries: recentRecoveries,
      recoveryHistory: List.from(_recoveryHistory),
      isHealthy: _isConnected && _successfulRecoveries >= _totalRecoveryAttempts / 2,
    );
  }

  /// 정리
  Future<void> dispose() async {
    debugPrint('🧹 [ResilienceManager] Disposing...');
    
    await _connectivitySubscription?.cancel();
    _connectionMonitorTimer?.cancel();
    _healthCheckTimer?.cancel();
    
    _retryStates.clear();
    _lastSuccessfulOperations.clear();
    _recoveryHistory.clear();
    
    _isInitialized = false;
    debugPrint('✅ [ResilienceManager] Disposed successfully');
  }
}

/// 재시도 상태 관리
class RetryState {
  int attemptCount = 0;
  DateTime? lastAttempt;
  DateTime? lastSuccess;
  bool _isEnabled = true;
  
  static const int maxAttempts = 5;
  static const Duration backoffBase = Duration(seconds: 2);
  static const Duration maxBackoff = Duration(minutes: 5);

  bool shouldRetry() {
    if (!_isEnabled || attemptCount >= maxAttempts) return false;
    
    if (lastAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(lastAttempt!);
      final requiredDelay = getBackoffDelay();
      
      return timeSinceLastAttempt >= requiredDelay;
    }
    
    return true;
  }

  Duration getBackoffDelay() {
    // Exponential backoff with jitter
    final exponentialDelay = backoffBase * math.pow(2, attemptCount);
    final jitter = math.Random().nextDouble() * 0.1; // 10% jitter
    final delayWithJitter = exponentialDelay * (1 + jitter);
    
    return Duration(
      milliseconds: math.min(
        delayWithJitter.inMilliseconds,
        maxBackoff.inMilliseconds,
      ).toInt(),
    );
  }

  void recordAttempt() {
    attemptCount++;
    lastAttempt = DateTime.now();
    
    if (attemptCount >= maxAttempts) {
      _isEnabled = false;
    }
  }

  void recordFailure() {
    recordAttempt();
  }

  void recordSuccess() {
    lastSuccess = DateTime.now();
    attemptCount = 0;
    _isEnabled = true;
  }
}

/// 복구 이벤트
class RecoveryEvent {
  final String message;
  final RecoveryType type;
  final DateTime timestamp;

  const RecoveryEvent({
    required this.message,
    required this.type,
    required this.timestamp,
  });
}

/// 복구 타입
enum RecoveryType {
  initialization,
  networkReconnection,
  networkDisconnection,
  serverReconnection,
  audioRestart,
  fallbackAlgorithm,
  resourceCleanup,
}

/// 복구 통계
class RecoveryStats {
  final int totalRecoveryAttempts;
  final int successfulRecoveries;
  final int recentRecoveries;
  final List<RecoveryEvent> recoveryHistory;
  final bool isHealthy;

  const RecoveryStats({
    required this.totalRecoveryAttempts,
    required this.successfulRecoveries,
    required this.recentRecoveries,
    required this.recoveryHistory,
    required this.isHealthy,
  });

  double get successRate => 
      totalRecoveryAttempts > 0 ? successfulRecoveries / totalRecoveryAttempts : 1.0;

  @override
  String toString() {
    return 'RecoveryStats(attempts: $totalRecoveryAttempts, '
           'successful: $successfulRecoveries, '
           'rate: ${(successRate * 100).toStringAsFixed(1)}%, '
           'healthy: $isHealthy)';
  }
}