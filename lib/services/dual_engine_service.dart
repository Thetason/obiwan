import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/analysis_result.dart';

/// CREPE + SPICE 듀얼 엔진 서비스
class DualEngineService {
  static const String _crepeUrl = 'http://localhost:5002';
  static const String _spiceUrl = 'http://localhost:5003';
  
  late final Dio _crepeClient;
  late final Dio _spiceClient;
  
  // 싱글톤
  static final DualEngineService _instance = DualEngineService._internal();
  factory DualEngineService() => _instance;
  
  DualEngineService._internal() {
    _crepeClient = Dio(BaseOptions(
      baseUrl: _crepeUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    
    _spiceClient = Dio(BaseOptions(
      baseUrl: _spiceUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }
  
  /// 서버 상태 확인
  Future<EngineStatus> checkStatus() async {
    final crepeHealthy = await _checkServerHealth(_crepeClient);
    final spiceHealthy = await _checkServerHealth(_spiceClient);
    
    return EngineStatus(
      crepeHealthy: crepeHealthy,
      spiceHealthy: spiceHealthy,
    );
  }
  
  Future<bool> _checkServerHealth(Dio client) async {
    try {
      final response = await client.get('/health');
      return response.statusCode == 200 && 
             response.data['status'] == 'healthy';
    } catch (e) {
      debugPrint('Server health check failed: $e');
      return false;
    }
  }
  
  /// CREPE 단일 분석
  Future<CrepeResult?> analyzeWithCrepe(Float32List audioData) async {
    try {
      final response = await _crepeClient.post('/analyze', data: {
        'audio': audioData.toList(),
      });
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return CrepeResult.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('CREPE analysis failed: $e');
      return null;
    }
  }
  
  /// SPICE 단일 분석
  Future<SpiceResult?> analyzeWithSpice(Float32List audioData) async {
    try {
      final response = await _spiceClient.post('/analyze', data: {
        'audio': audioData.toList(),
      });
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return SpiceResult.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('SPICE analysis failed: $e');
      return null;
    }
  }
  
  /// 듀얼 엔진 분석 (자동 선택)
  Future<DualResult?> analyzeDual(Float32List audioData) async {
    // 오디오 복잡도 판단
    final isComplex = _isComplexAudio(audioData);
    
    // 병렬 실행
    final futures = <Future>[];
    futures.add(analyzeWithCrepe(audioData));
    
    if (isComplex) {
      futures.add(analyzeWithSpice(audioData));
    }
    
    final results = await Future.wait(futures, eagerError: false);
    
    final crepeResult = results[0] as CrepeResult?;
    final spiceResult = results.length > 1 ? results[1] as SpiceResult? : null;
    
    return _fuseResults(crepeResult, spiceResult);
  }
  
  /// 오디오 복잡도 판단
  bool _isComplexAudio(Float32List audioData) {
    if (audioData.length < 100) return false;
    
    // 간단한 휴리스틱: RMS와 Zero-crossing rate
    final rms = _calculateRMS(audioData);
    final zcr = _calculateZCR(audioData);
    
    return rms > 0.05 && zcr > 0.1;
  }
  
  double _calculateRMS(Float32List data) {
    if (data.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (final sample in data) {
      sum += sample * sample;
    }
    return math.sqrt(sum / data.length);
  }
  
  double _calculateZCR(Float32List data) {
    if (data.length < 2) return 0.0;
    
    int crossings = 0;
    for (int i = 1; i < data.length; i++) {
      if ((data[i-1] >= 0) != (data[i] >= 0)) {
        crossings++;
      }
    }
    return crossings / data.length;
  }
  
  /// 결과 융합
  DualResult? _fuseResults(CrepeResult? crepe, SpiceResult? spice) {
    if (crepe == null && spice == null) return null;
    
    // 주요 피치 선택 (CREPE 우선)
    final mainFreq = crepe?.frequency ?? spice?.frequency ?? 0.0;
    final mainConf = crepe?.confidence ?? spice?.confidence ?? 0.0;
    
    // 추천 엔진 결정
    String recommended = 'CREPE';
    if (spice != null && spice.isChord) {
      recommended = 'SPICE';
    }
    
    // 분석 품질 계산
    double quality = 0.0;
    if (crepe != null) quality += crepe.confidence * 0.7;
    if (spice != null) quality += spice.confidence * 0.3;
    
    return DualResult(
      frequency: mainFreq,
      confidence: mainConf,
      timestamp: DateTime.now(),
      crepeResult: crepe,
      spiceResult: spice,
      recommendedEngine: recommended,
      analysisQuality: quality,
    );
  }
}

/// 엔진 상태
class EngineStatus {
  final bool crepeHealthy;
  final bool spiceHealthy;
  
  EngineStatus({
    required this.crepeHealthy,
    required this.spiceHealthy,
  });
  
  bool get anyHealthy => crepeHealthy || spiceHealthy;
  bool get bothHealthy => crepeHealthy && spiceHealthy;
  
  String get statusText {
    if (bothHealthy) return "두 엔진 모두 정상";
    if (crepeHealthy) return "CREPE만 정상";
    if (spiceHealthy) return "SPICE만 정상";
    return "두 엔진 모두 오프라인";
  }
}

/// 실시간 스트림
class RealtimeAnalysisStream {
  final DualEngineService _service = DualEngineService();
  final StreamController<DualResult> _controller = 
      StreamController<DualResult>.broadcast();
  
  Stream<DualResult> get stream => _controller.stream;
  
  Timer? _timer;
  final List<Float32List> _buffer = [];
  static const int _maxBufferSize = 3;
  
  void startStream() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _processBuffer();
    });
  }
  
  void addAudioChunk(Float32List chunk) {
    _buffer.add(chunk);
    if (_buffer.length > _maxBufferSize) {
      _buffer.removeAt(0);
    }
  }
  
  void _processBuffer() async {
    if (_buffer.isEmpty) return;
    
    // 버퍼 결합
    final totalLength = _buffer.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final combined = Float32List(totalLength);
    
    int offset = 0;
    for (final chunk in _buffer) {
      combined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    
    // 분석 실행
    final result = await _service.analyzeDual(combined);
    if (result != null) {
      _controller.add(result);
    }
  }
  
  void stopStream() {
    _timer?.cancel();
    _timer = null;
    _buffer.clear();
  }
  
  void dispose() {
    stopStream();
    _controller.close();
  }
}