import 'dart:async';
import 'dart:isolate';
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
    // 배터리 상태 확인 및 최적화
    // 실제 구현에서는 battery_plus 패키지 사용
    if (_isLowPowerMode) {
      _enableLowPowerMode();
    }
  }
  
  void _enableLowPowerMode() {
    // 저전력 모드 활성화
    // - 3D 렌더링 품질 하향 조정
    // - 오디오 분석 주기 증가
    // - 애니메이션 프레임 레이트 감소
  }
  
  // 3D 모델 LOD (Level of Detail) 시스템
  String getOptimizedModelPath(String modelKey, double distance) {
    if (distance > 10.0) {
      return 'assets/models/low_detail/$modelKey.glb';
    } else if (distance > 5.0) {
      return 'assets/models/medium_detail/$modelKey.glb';
    } else {
      return 'assets/models/high_detail/$modelKey.glb';
    }
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
    // 텍스처 압축 로직
    // 실제 구현에서는 이미지 압축 라이브러리 사용
    return originalBytes;
  }
  
  // 오디오 처리 최적화
  Future<T> processAudioInIsolate<T>(
    Future<T> Function() computation,
  ) async {
    if (kIsWeb) {
      // 웹에서는 Isolate 사용 불가
      return await computation();
    }
    
    final receivePort = ReceivePort();
    
    await Isolate.spawn(
      _audioProcessingEntry,
      receivePort.sendPort,
    );
    
    final result = await receivePort.first;
    return result as T;
  }
  
  static void _audioProcessingEntry(SendPort sendPort) {
    // 오디오 처리 로직
    // 실제 구현에서는 computation 실행
    sendPort.send('processed');
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
  
  // 메모리 캐시 관리
  void cacheData(String key, dynamic data) {
    _cache[key] = data;
  }
  
  T? getCachedData<T>(String key) {
    return _cache[key] as T?;
  }
  
  void clearCache() {
    _cache.clear();
  }
  
  // 리소스 해제
  void dispose() {
    _performanceTimer?.cancel();
    _batteryOptimizationTimer?.cancel();
    _cache.clear();
    _frameTimes.clear();
  }
  
  // 성능 보고서 생성
  Map<String, dynamic> generatePerformanceReport() {
    return {
      'averageFPS': getAverageFPS(),
      'frameCount': _frameTimes.length,
      'cacheSize': _cache.length,
      'memoryUsage': _cache.length * 1024, // 대략적인 메모리 사용량
      'isLowPowerMode': _isLowPowerMode,
      'performanceGood': isPerformanceGood(),
    };
  }
}