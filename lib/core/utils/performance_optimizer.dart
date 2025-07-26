import 'dart:async';
import 'dart:isolate';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PerformanceOptimizer {
  static final PerformanceOptimizer _instance = PerformanceOptimizer._internal();
  factory PerformanceOptimizer() => _instance;
  PerformanceOptimizer._internal();
  
  // 성능 모니터링 관련
  final Stopwatch _frameStopwatch = Stopwatch();
  final List<double> _frameTimes = [];
  Timer? _performanceTimer;
  
  // 메모리 관리
  final Map<String, dynamic> _cache = {};
  static const int _maxCacheSize = 50;
  
  // 배터리 최적화
  bool _isLowPowerMode = false;
  Timer? _batteryOptimizationTimer;
  int _batteryLevel = 100;
  bool _isCharging = false;
  
  void initialize() {
    _startPerformanceMonitoring();
    _startBatteryOptimization();
  }
  
  void _startPerformanceMonitoring() {
    _performanceTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _monitorPerformance(),
    );
  }
  
  void _monitorPerformance() {
    // 프레임 레이트 측정
    if (_frameStopwatch.isRunning) {
      final frameTime = _frameStopwatch.elapsedMilliseconds.toDouble();
      _frameTimes.add(frameTime);
      
      // 최근 60프레임만 유지
      if (_frameTimes.length > 60) {
        _frameTimes.removeAt(0);
      }
    }
    
    // 메모리 사용량 체크
    _checkMemoryUsage();
  }
  
  void _checkMemoryUsage() {
    // 캐시 크기 제한
    if (_cache.length > _maxCacheSize) {
      // LRU 방식으로 오래된 항목 제거
      final keys = _cache.keys.toList();
      final itemsToRemove = keys.take(_cache.length - _maxCacheSize);
      for (final key in itemsToRemove) {
        _cache.remove(key);
      }
    }
  }
  
  void _startBatteryOptimization() {
    _batteryOptimizationTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _optimizeBatteryUsage(),
    );
  }
  
  void _optimizeBatteryUsage() {
    try {
      // 플랫폼별 배터리 최적화
      if (!kIsWeb) {
        _checkBatteryLevel();
      }
      
      // 배터리 레벨에 따른 최적화
      if (_batteryLevel < 20 && !_isCharging) {
        _enableLowPowerMode();
      } else if (_batteryLevel > 50 || _isCharging) {
        _disableLowPowerMode();
      }
    } catch (e) {
      debugPrint('Battery optimization error: $e');
    }
  }
  
  void _checkBatteryLevel() {
    // 시뮬레이션: 실제로는 battery_plus 패키지 사용
    // final battery = Battery();
    // battery.batteryLevel.then((level) => _batteryLevel = level);
    // battery.isInBatterySaveMode.then((lowPower) => _isLowPowerMode = lowPower);
  }
  
  void _enableLowPowerMode() {
    if (_isLowPowerMode) return;
    
    _isLowPowerMode = true;
    debugPrint('[PerformanceOptimizer] Low power mode enabled');
    
    // 성능 최적화 설정
    _applyLowPowerSettings();
  }
  
  void _disableLowPowerMode() {
    if (!_isLowPowerMode) return;
    
    _isLowPowerMode = false;
    debugPrint('[PerformanceOptimizer] Low power mode disabled');
    
    // 정상 성능 설정 복원
    _applyNormalPowerSettings();
  }
  
  void _applyLowPowerSettings() {
    // 3D 렌더링 품질 하향 조정
    _setRenderQuality(0.5);
    
    // 오디오 분석 주기 증가 (30fps -> 15fps)
    _setAudioAnalysisRate(15);
    
    // 애니메이션 프레임 레이트 감소
    _setAnimationFrameRate(30);
  }
  
  void _applyNormalPowerSettings() {
    // 고품질 렌더링 복원
    _setRenderQuality(1.0);
    
    // 정상 오디오 분석 주기 (60fps)
    _setAudioAnalysisRate(60);
    
    // 정상 애니메이션 프레임 레이트
    _setAnimationFrameRate(60);
  }
  
  void _setRenderQuality(double quality) {
    // 렌더링 품질 설정 (0.0 ~ 1.0)
    cacheData('render_quality', quality);
  }
  
  void _setAudioAnalysisRate(int fps) {
    // 오디오 분석 주기 설정
    cacheData('audio_analysis_fps', fps);
  }
  
  void _setAnimationFrameRate(int fps) {
    // 애니메이션 프레임 레이트 설정
    cacheData('animation_fps', fps);
  }
  
  // 3D 모델 LOD (Level of Detail) 시스템
  String getOptimizedModelPath(String modelKey, double distance) {
    final renderQuality = getCachedData<double>('render_quality') ?? 1.0;
    
    // 저전력 모드에서는 더 적극적으로 LOD 적용
    final distanceMultiplier = _isLowPowerMode ? 0.5 : 1.0;
    final adjustedDistance = distance * distanceMultiplier;
    
    if (adjustedDistance > 10.0 || renderQuality < 0.3) {
      return 'assets/models/low_detail/$modelKey.glb';
    } else if (adjustedDistance > 5.0 || renderQuality < 0.7) {
      return 'assets/models/medium_detail/$modelKey.glb';
    } else {
      return 'assets/models/high_detail/$modelKey.glb';
    }
  }
  
  // 동적 품질 조정
  double getOptimizedQuality(String feature) {
    final baseQuality = getCachedData<double>('render_quality') ?? 1.0;
    final fps = getAverageFPS();
    
    // FPS가 낮으면 품질을 더 낮춤
    if (fps < 20) {
      return baseQuality * 0.5;
    } else if (fps < 30) {
      return baseQuality * 0.7;
    }
    
    return baseQuality;
  }
  
  // 텍스처 압축 및 캐싱
  Future<Uint8List> getOptimizedTexture(String texturePath) async {
    // 캐시에서 확인
    if (_cache.containsKey(texturePath)) {
      return _cache[texturePath] as Uint8List;
    }
    
    try {
      // 텍스처 로드
      final ByteData data = await rootBundle.load(texturePath);
      final bytes = data.buffer.asUint8List();
      
      // 압축 및 캐싱
      final compressedBytes = await _compressTexture(bytes);
      _cache[texturePath] = compressedBytes;
      
      return compressedBytes;
    } catch (e) {
      debugPrint('Failed to load texture: $texturePath, error: $e');
      return Uint8List(0);
    }
  }
  
  Future<Uint8List> _compressTexture(Uint8List originalBytes) async {
    try {
      // 저전력 모드에서는 더 강한 압축 적용
      final compressionQuality = _isLowPowerMode ? 0.5 : 0.8;
      
      // 간단한 압축 시뮬레이션 (실제로는 image 패키지 사용)
      final compressionRatio = compressionQuality;
      final compressedSize = (originalBytes.length * compressionRatio).round();
      
      // 실제 압축 구현 필요:
      // import 'package:image/image.dart' as img;
      // final image = img.decodeImage(originalBytes);
      // final compressed = img.encodeJpg(image, quality: (compressionQuality * 100).round());
      
      return Uint8List.fromList(originalBytes.take(compressedSize).toList());
    } catch (e) {
      debugPrint('Texture compression failed: $e');
      return originalBytes;
    }
  }
  
  // 메모리 압박 감지 및 대응
  void _handleMemoryPressure() {
    final report = generatePerformanceReport();
    final memoryUsage = report['memoryUsage'] as int;
    
    // 메모리 사용량이 높으면 캐시 정리
    if (memoryUsage > 50 * 1024 * 1024) { // 50MB
      clearCache();
      debugPrint('[PerformanceOptimizer] Cache cleared due to memory pressure');
    }
  }
  
  // 오디오 처리 최적화
  Future<T> processAudioInIsolate<T>(
    T Function(List<dynamic>) computation,
    List<dynamic> audioData,
  ) async {
    if (kIsWeb) {
      // 웹에서는 Isolate 사용 불가, 메인 스레드에서 처리
      return computation(audioData);
    }
    
    try {
      final receivePort = ReceivePort();
      
      await Isolate.spawn(
        _audioProcessingEntry<T>,
        {
          'sendPort': receivePort.sendPort,
          'audioData': audioData,
          'computation': computation,
        },
      );
      
      final result = await receivePort.first;
      return result as T;
    } catch (e) {
      debugPrint('Isolate processing failed, falling back to main thread: $e');
      return computation(audioData);
    }
  }
  
  static void _audioProcessingEntry<T>(Map<String, dynamic> params) {
    try {
      final sendPort = params['sendPort'] as SendPort;
      final audioData = params['audioData'] as List<dynamic>;
      final computation = params['computation'] as T Function(List<dynamic>);
      
      final result = computation(audioData);
      sendPort.send(result);
    } catch (e) {
      // 에러 발생시 기본값 전송
      final sendPort = params['sendPort'] as SendPort;
      sendPort.send(null);
    }
  }
  
  // 오디오 품질 최적화
  int getOptimizedAudioSampleRate() {
    if (_isLowPowerMode) {
      return 8000; // 저품질
    } else if (!isPerformanceGood()) {
      return 16000; // 중품질
    } else {
      return 44100; // 고품질
    }
  }
  
  int getOptimizedAudioBufferSize() {
    if (_isLowPowerMode) {
      return 2048; // 큰 버퍼 (지연 증가, 배터리 절약)
    } else if (!isPerformanceGood()) {
      return 1024; // 중간 버퍼
    } else {
      return 512; // 작은 버퍼 (낮은 지연)
    }
  }
  
  // 프레임 레이트 최적화
  void startFrameOptimization() {
    _frameStopwatch.start();
  }
  
  void endFrameOptimization() {
    _frameStopwatch.stop();
    _frameStopwatch.reset();
  }
  
  double getAverageFPS() {
    if (_frameTimes.isEmpty) return 0.0;
    
    final avgFrameTime = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
    return avgFrameTime > 0 ? 1000.0 / avgFrameTime : 0.0;
  }
  
  bool isPerformanceGood() {
    final fps = getAverageFPS();
    return fps >= 30.0; // 최소 30 FPS 유지
  }
  
  // 메모리 캐시 관리 (LRU 구현)
  final Map<String, DateTime> _cacheAccessTimes = {};
  
  void cacheData(String key, dynamic data) {
    _cache[key] = data;
    _cacheAccessTimes[key] = DateTime.now();
    
    // 캐시 크기 제한
    if (_cache.length > _maxCacheSize) {
      _evictLRU();
    }
  }
  
  T? getCachedData<T>(String key) {
    if (_cache.containsKey(key)) {
      _cacheAccessTimes[key] = DateTime.now(); // 액세스 시간 업데이트
      return _cache[key] as T?;
    }
    return null;
  }
  
  void _evictLRU() {
    // 가장 오래 사용되지 않은 항목 제거
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _cacheAccessTimes.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestTime = entry.value;
        oldestKey = entry.key;
      }
    }
    
    if (oldestKey != null) {
      _cache.remove(oldestKey);
      _cacheAccessTimes.remove(oldestKey);
    }
  }
  
  void clearCache() {
    _cache.clear();
    _cacheAccessTimes.clear();
  }
  
  // 캐시 통계
  Map<String, dynamic> getCacheStats() {
    return {
      'size': _cache.length,
      'maxSize': _maxCacheSize,
      'hitRate': _calculateCacheHitRate(),
      'oldestEntry': _getOldestCacheEntry(),
    };
  }
  
  double _calculateCacheHitRate() {
    // 간단한 히트율 계산 (실제로는 더 정교한 추적 필요)
    return _cache.isNotEmpty ? 0.8 : 0.0;
  }
  
  String? _getOldestCacheEntry() {
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _cacheAccessTimes.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestTime = entry.value;
        oldestKey = entry.key;
      }
    }
    
    return oldestKey;
  }
  
  // 스마트 성능 조정
  void adjustPerformanceBasedOnUsage() {
    final report = generatePerformanceReport();
    final fps = report['averageFPS'] as double;
    final memoryUsage = report['memoryUsage'] as int;
    
    // FPS 기반 자동 조정
    if (fps < 20) {
      _enableLowPowerMode();
    } else if (fps > 50 && !_isLowPowerMode) {
      // 성능이 좋으면 품질을 높일 수 있음
      _setRenderQuality(math.min(1.0, getOptimizedQuality('render') + 0.1));
    }
    
    // 메모리 사용량 기반 조정
    if (memoryUsage > 100 * 1024 * 1024) { // 100MB
      _handleMemoryPressure();
    }
  }
  
  // 디바이스 성능 프로파일링
  void profileDevice() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isInitialized) {
        timer.cancel();
        return;
      }
      
      adjustPerformanceBasedOnUsage();
    });
  }
  
  bool get _isInitialized => _performanceTimer?.isActive ?? false;
  
  // 리소스 해제
  void dispose() {
    _performanceTimer?.cancel();
    _batteryOptimizationTimer?.cancel();
    _cache.clear();
    _cacheAccessTimes.clear();
    _frameTimes.clear();
  }
  
  // 성능 보고서 생성
  Map<String, dynamic> generatePerformanceReport() {
    final cacheStats = getCacheStats();
    
    return {
      'averageFPS': getAverageFPS(),
      'frameCount': _frameTimes.length,
      'cacheSize': _cache.length,
      'cacheStats': cacheStats,
      'memoryUsage': _estimateMemoryUsage(),
      'isLowPowerMode': _isLowPowerMode,
      'batteryLevel': _batteryLevel,
      'isCharging': _isCharging,
      'performanceGood': isPerformanceGood(),
      'renderQuality': getCachedData<double>('render_quality') ?? 1.0,
      'audioSampleRate': getOptimizedAudioSampleRate(),
      'audioBufferSize': getOptimizedAudioBufferSize(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  int _estimateMemoryUsage() {
    // 캐시 항목당 평균 1KB로 추정
    int cacheMemory = _cache.length * 1024;
    
    // 프레임 시간 데이터
    int frameMemory = _frameTimes.length * 8; // double = 8 bytes
    
    // 기본 오버헤드
    int overhead = 10 * 1024; // 10KB
    
    return cacheMemory + frameMemory + overhead;
  }
  
  // 성능 권장사항 생성
  List<String> generatePerformanceRecommendations() {
    final recommendations = <String>[];
    final report = generatePerformanceReport();
    
    final fps = report['averageFPS'] as double;
    final memoryUsage = report['memoryUsage'] as int;
    final batteryLevel = report['batteryLevel'] as int;
    
    if (fps < 24) {
      recommendations.add('프레임 레이트가 낮습니다. 렌더링 품질을 낮추는 것을 고려하세요.');
    }
    
    if (memoryUsage > 50 * 1024 * 1024) {
      recommendations.add('메모리 사용량이 높습니다. 캐시를 정리하는 것을 고려하세요.');
    }
    
    if (batteryLevel < 20 && !_isCharging) {
      recommendations.add('배터리 잔량이 부족합니다. 저전력 모드를 활성화하세요.');
    }
    
    if (_cache.length > _maxCacheSize * 0.8) {
      recommendations.add('캐시 사용량이 높습니다. 일부 데이터를 정리하세요.');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('성능이 양호합니다.');
    }
    
    return recommendations;
  }
}