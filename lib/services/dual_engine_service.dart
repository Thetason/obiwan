import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// CREPE + SPICE 듀얼 엔진 피치 분석 서비스
class DualEngineService {
  static const String _crepeUrl = 'http://localhost:5002';
  static const String _spiceUrl = 'http://localhost:5003';
  static const int _timeoutMs = 10000;
  
  late final Dio _crepeClient;
  late final Dio _spiceClient;
  
  // 싱글톤 패턴
  static final DualEngineService _instance = DualEngineService._internal();
  factory DualEngineService() => _instance;
  
  DualEngineService._internal() {
    _crepeClient = Dio(BaseOptions(
      baseUrl: _crepeUrl,
      connectTimeout: Duration(milliseconds: _timeoutMs),
      receiveTimeout: Duration(milliseconds: _timeoutMs),
    ));
    
    _spiceClient = Dio(BaseOptions(
      baseUrl: _spiceUrl,
      connectTimeout: Duration(milliseconds: _timeoutMs),
      receiveTimeout: Duration(milliseconds: _timeoutMs),
    ));
    
    if (kDebugMode) {
      _crepeClient.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));
      _spiceClient.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));
    }
  }
  
  /// 서버 상태 확인
  Future<DualEngineStatus> checkEngineStatus() async {
    final crepeHealth = await _checkServerHealth(_crepeClient, 'CREPE');
    final spiceHealth = await _checkServerHealth(_spiceClient, 'SPICE');
    
    return DualEngineStatus(
      crepeHealthy: crepeHealth,
      spiceHealthy: spiceHealth,
      timestamp: DateTime.now(),
    );
  }
  
  Future<bool> _checkServerHealth(Dio client, String engineName) async {
    try {
      final response = await client.get('/health');
      return response.statusCode == 200 && response.data['status'] == 'healthy';
    } catch (e) {
      debugPrint('$engineName server health check failed: $e');
      return false;
    }
  }
  
  /// 듀얼 엔진 분석 (CREPE + SPICE 동시 실행)
  Future<DualAnalysisResult?> analyzeDual(Float32List audioData, {AnalysisMode mode = AnalysisMode.auto}) async {
    try {
      final List<Future<dynamic>> futures = [];
      
      // 분석 모드에 따라 엔진 선택
      bool useCrepe = mode == AnalysisMode.auto || mode == AnalysisMode.crepe || mode == AnalysisMode.both;
      bool useSpice = mode == AnalysisMode.auto || mode == AnalysisMode.spice || mode == AnalysisMode.both;
      
      // CREPE 분석
      if (useCrepe) {
        futures.add(_analyzeWithCrepe(audioData));
      }
      
      // SPICE 분석 (auto 모드에서는 오디오가 복합음일 때만)
      if (useSpice && (mode == AnalysisMode.spice || mode == AnalysisMode.both || await _isComplexAudio(audioData))) {
        futures.add(_analyzeWithSpice(audioData));
      }
      
      // 병렬 실행
      final results = await Future.wait(futures, eagerError: false);
      
      CrepeAnalysisResult? crepeResult;
      SpiceAnalysisResult? spiceResult;
      
      int resultIndex = 0;
      if (useCrepe && results.length > resultIndex) {
        crepeResult = results[resultIndex] as CrepeAnalysisResult?;
        resultIndex++;
      }
      if (useSpice && results.length > resultIndex) {
        spiceResult = results[resultIndex] as SpiceAnalysisResult?;
      }
      
      return DualAnalysisResult(
        crepeResult: crepeResult,
        spiceResult: spiceResult,
        fusedResult: _fuseResults(crepeResult, spiceResult),
        analysisMode: mode,
        timestamp: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('Dual analysis failed: $e');
      return null;
    }
  }
  
  /// CREPE 단일 분석
  Future<CrepeAnalysisResult?> analyzeWithCrepe(Float32List audioData) async {
    return await _analyzeWithCrepe(audioData);
  }
  
  /// SPICE 단일 분석
  Future<SpiceAnalysisResult?> analyzeWithSpice(Float32List audioData) async {
    return await _analyzeWithSpice(audioData);
  }
  
  Future<CrepeAnalysisResult?> _analyzeWithCrepe(Float32List audioData) async {
    try {
      final response = await _crepeClient.post('/analyze', data: {
        'audio': audioData.toList(),
      });
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return CrepeAnalysisResult.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('CREPE analysis failed: $e');
      return null;
    }
  }
  
  Future<SpiceAnalysisResult?> _analyzeWithSpice(Float32List audioData) async {
    try {
      final response = await _spiceClient.post('/analyze', data: {
        'audio': audioData.toList(),
      });
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return SpiceAnalysisResult.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('SPICE analysis failed: $e');
      return null;
    }
  }
  
  /// 오디오가 복합음인지 판단 (간단한 휴리스틱)
  Future<bool> _isComplexAudio(Float32List audioData) async {
    // 간단한 스펙트럼 분석으로 복합음 여부 판단
    // 실제로는 FFT 등을 사용하지만, 여기서는 단순화
    final rms = _calculateRMS(audioData);
    final zeroCrossingRate = _calculateZeroCrossingRate(audioData);
    
    // 복합음은 일반적으로 더 높은 제로 크로싱 레이트를 가짐
    return zeroCrossingRate > 0.1 && rms > 0.05;
  }
  
  double _calculateRMS(Float32List audioData) {
    if (audioData.isEmpty) return 0.0;
    
    double sumSquares = 0.0;
    for (final sample in audioData) {
      sumSquares += sample * sample;
    }
    return (sumSquares / audioData.length).clamp(0.0, 1.0);
  }
  
  double _calculateZeroCrossingRate(Float32List audioData) {
    if (audioData.length < 2) return 0.0;
    
    int crossings = 0;
    for (int i = 1; i < audioData.length; i++) {
      if ((audioData[i-1] >= 0) != (audioData[i] >= 0)) {
        crossings++;
      }
    }
    return crossings / audioData.length;
  }
  
  /// CREPE와 SPICE 결과 융합
  FusedAnalysisResult? _fuseResults(CrepeAnalysisResult? crepe, SpiceAnalysisResult? spice) {
    if (crepe == null && spice == null) return null;
    
    // CREPE를 메인으로 사용하고 SPICE로 보완
    final mainPitch = crepe?.mainPitch ?? spice?.mainPitch ?? 0.0;
    final mainConfidence = crepe?.overallConfidence ?? spice?.averageConfidence ?? 0.0;
    
    // 다중 피치는 SPICE에서 가져오기
    final multiplePitches = spice?.multiplePitches ?? [];
    
    // 안정성은 두 결과의 평균
    final stability = ((crepe?.stability ?? 0.0) + (spice?.pitchStability ?? 0.0)) / 2.0;
    
    return FusedAnalysisResult(
      primaryPitch: mainPitch,
      primaryConfidence: mainConfidence,
      multiplePitches: multiplePitches,
      pitchStability: stability,
      analysisQuality: _calculateAnalysisQuality(crepe, spice),
      recommendedEngine: _recommendEngine(crepe, spice),
    );
  }
  
  double _calculateAnalysisQuality(CrepeAnalysisResult? crepe, SpiceAnalysisResult? spice) {
    double quality = 0.0;
    int sources = 0;
    
    if (crepe != null) {
      quality += crepe.overallConfidence * 0.7; // CREPE에 더 높은 가중치
      sources++;
    }
    
    if (spice != null) {
      quality += spice.averageConfidence * 0.3;
      sources++;
    }
    
    return sources > 0 ? quality / sources : 0.0;
  }
  
  AnalysisEngine _recommendEngine(CrepeAnalysisResult? crepe, SpiceAnalysisResult? spice) {
    if (crepe == null) return AnalysisEngine.spice;
    if (spice == null) return AnalysisEngine.crepe;
    
    // 다중 피치가 감지되면 SPICE 추천
    if (spice.multiplePitches.length > 1) {
      return AnalysisEngine.spice;
    }
    
    // 단일 피치면 CREPE 추천
    return AnalysisEngine.crepe;
  }
}

/// 실시간 듀얼 엔진 스트림
class RealtimeDualStream {
  final DualEngineService _service = DualEngineService();
  final StreamController<DualAnalysisResult> _controller = 
      StreamController<DualAnalysisResult>.broadcast();
  
  Stream<DualAnalysisResult> get stream => _controller.stream;
  
  Timer? _analysisTimer;
  final List<Float32List> _audioBuffer = [];
  final int _maxBufferSize = 3;
  AnalysisMode _currentMode = AnalysisMode.auto;
  
  void startStream({AnalysisMode mode = AnalysisMode.auto}) {
    _currentMode = mode;
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _processBuffer();
    });
  }
  
  void addAudioChunk(Float32List audioData) {
    _audioBuffer.add(audioData);
    if (_audioBuffer.length > _maxBufferSize) {
      _audioBuffer.removeAt(0);
    }
  }
  
  void _processBuffer() async {
    if (_audioBuffer.isEmpty) return;
    
    try {
      // 버퍼의 모든 청크를 연결
      final totalLength = _audioBuffer.fold<int>(0, (sum, chunk) => sum + chunk.length);
      final combinedAudio = Float32List(totalLength);
      
      int offset = 0;
      for (final chunk in _audioBuffer) {
        combinedAudio.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      
      final result = await _service.analyzeDual(combinedAudio, mode: _currentMode);
      if (result != null) {
        _controller.add(result);
      }
    } catch (e) {
      debugPrint('Real-time dual processing error: $e');
    }
  }
  
  void setAnalysisMode(AnalysisMode mode) {
    _currentMode = mode;
  }
  
  void stopStream() {
    _analysisTimer?.cancel();
    _analysisTimer = null;
    _audioBuffer.clear();
  }
  
  void dispose() {
    stopStream();
    _controller.close();
  }
}

/// 분석 모드 열거형
enum AnalysisMode {
  auto,    // 자동 선택 (단순음: CREPE, 복합음: 듀얼)
  crepe,   // CREPE만 사용
  spice,   // SPICE만 사용
  both,    // 둘 다 항상 사용
}

/// 분석 엔진 열거형
enum AnalysisEngine {
  crepe,
  spice,
  fused,
}

/// 듀얼 엔진 상태
class DualEngineStatus {
  final bool crepeHealthy;
  final bool spiceHealthy;
  final DateTime timestamp;
  
  DualEngineStatus({
    required this.crepeHealthy,
    required this.spiceHealthy,
    required this.timestamp,
  });
  
  bool get anyHealthy => crepeHealthy || spiceHealthy;
  bool get bothHealthy => crepeHealthy && spiceHealthy;
  
  String get statusText {
    if (bothHealthy) return "두 엔진 모두 정상";
    if (crepeHealthy) return "CREPE 엔진만 정상";
    if (spiceHealthy) return "SPICE 엔진만 정상";
    return "두 엔진 모두 오프라인";
  }
}

/// 듀얼 분석 결과
class DualAnalysisResult {
  final CrepeAnalysisResult? crepeResult;
  final SpiceAnalysisResult? spiceResult;
  final FusedAnalysisResult? fusedResult;
  final AnalysisMode analysisMode;
  final DateTime timestamp;
  
  DualAnalysisResult({
    this.crepeResult,
    this.spiceResult,
    this.fusedResult,
    required this.analysisMode,
    required this.timestamp,
  });
  
  /// 최적 결과 선택
  double get bestPitch {
    if (fusedResult != null) return fusedResult!.primaryPitch;
    if (crepeResult != null) return crepeResult!.mainPitch;
    if (spiceResult != null) return spiceResult!.mainPitch;
    return 0.0;
  }
  
  double get bestConfidence {
    if (fusedResult != null) return fusedResult!.primaryConfidence;
    if (crepeResult != null) return crepeResult!.overallConfidence;
    if (spiceResult != null) return spiceResult!.averageConfidence;
    return 0.0;
  }
  
  List<MultiplePitch> get detectedPitches {
    if (fusedResult != null) return fusedResult!.multiplePitches;
    if (spiceResult != null) return spiceResult!.multiplePitches;
    return [];
  }
  
  bool get isChord => detectedPitches.length > 1;
  
  String get analysisTypeText {
    if (isChord) return "화음 감지";
    if (bestPitch > 0) return "단일음 감지";
    return "무성음";
  }
}

/// 융합 분석 결과
class FusedAnalysisResult {
  final double primaryPitch;
  final double primaryConfidence;
  final List<MultiplePitch> multiplePitches;
  final double pitchStability;
  final double analysisQuality;
  final AnalysisEngine recommendedEngine;
  
  FusedAnalysisResult({
    required this.primaryPitch,
    required this.primaryConfidence,
    required this.multiplePitches,
    required this.pitchStability,
    required this.analysisQuality,
    required this.recommendedEngine,
  });
}

/// SPICE 분석 결과 (기존 CREPE 결과와 호환)
class SpiceAnalysisResult {
  final List<double> timestamps;
  final List<double> frequencies;
  final List<double> confidence;
  final List<MultiplePitch> multiplePitches;
  final SpiceStatistics statistics;
  final SpiceParameters parameters;
  
  SpiceAnalysisResult({
    required this.timestamps,
    required this.frequencies,
    required this.confidence,
    required this.multiplePitches,
    required this.statistics,
    required this.parameters,
  });
  
  factory SpiceAnalysisResult.fromJson(Map<String, dynamic> json) {
    return SpiceAnalysisResult(
      timestamps: List<double>.from(json['timestamps']),
      frequencies: List<double>.from(json['frequencies']),
      confidence: List<double>.from(json['confidence']),
      multiplePitches: (json['multiple_pitches'] as List)
          .map((e) => MultiplePitch.fromJson(e))
          .toList(),
      statistics: SpiceStatistics.fromJson(json['statistics']),
      parameters: SpiceParameters.fromJson(json['parameters']),
    );
  }
  
  double get mainPitch => statistics.averageFrequency;
  double get averageConfidence => statistics.averageConfidence;
  double get pitchStability => statistics.pitchStability;
  double get voicedRatio => statistics.voicedRatio;
}

/// 다중 피치 정보
class MultiplePitch {
  final double frequency;
  final double strength;
  final double confidence;
  
  MultiplePitch({
    required this.frequency,
    required this.strength,
    required this.confidence,
  });
  
  factory MultiplePitch.fromJson(Map<String, dynamic> json) {
    return MultiplePitch(
      frequency: json['frequency'].toDouble(),
      strength: json['strength'].toDouble(),
      confidence: json['confidence'].toDouble(),
    );
  }
}

/// SPICE 통계
class SpiceStatistics {
  final double averageFrequency;
  final double averageConfidence;
  final double pitchStability;
  final double voicedRatio;
  final int totalFrames;
  final int voicedFrames;
  final int pitchCount;
  
  SpiceStatistics({
    required this.averageFrequency,
    required this.averageConfidence,
    required this.pitchStability,
    required this.voicedRatio,
    required this.totalFrames,
    required this.voicedFrames,
    required this.pitchCount,
  });
  
  factory SpiceStatistics.fromJson(Map<String, dynamic> json) {
    return SpiceStatistics(
      averageFrequency: json['average_frequency'].toDouble(),
      averageConfidence: json['average_confidence'].toDouble(),
      pitchStability: json['pitch_stability'].toDouble(),
      voicedRatio: json['voiced_ratio'].toDouble(),
      totalFrames: json['total_frames'],
      voicedFrames: json['voiced_frames'],
      pitchCount: json['pitch_count'],
    );
  }
}

/// SPICE 파라미터
class SpiceParameters {
  final String model;
  final int sampleRate;
  final String analysisType;
  final double inferenceTimeMs;
  
  SpiceParameters({
    required this.model,
    required this.sampleRate,
    required this.analysisType,
    required this.inferenceTimeMs,
  });
  
  factory SpiceParameters.fromJson(Map<String, dynamic> json) {
    return SpiceParameters(
      model: json['model'],
      sampleRate: json['sample_rate'],
      analysisType: json['analysis_type'],
      inferenceTimeMs: json['inference_time_ms'].toDouble(),
    );
  }
}

// CREPE 결과는 기존 official_crepe_service.dart에서 import
class CrepeAnalysisResult {
  final List<double> timestamps;
  final List<double> frequencies;
  final List<double> confidence;
  final List<List<double>> activation;
  
  CrepeAnalysisResult({
    required this.timestamps,
    required this.frequencies,
    required this.confidence,
    required this.activation,
  });
  
  factory CrepeAnalysisResult.fromJson(Map<String, dynamic> json) {
    return CrepeAnalysisResult(
      timestamps: List<double>.from(json['timestamps']),
      frequencies: List<double>.from(json['frequencies']),
      confidence: List<double>.from(json['confidence']),
      activation: (json['activation'] as List)
          .map((e) => List<double>.from(e))
          .toList(),
    );
  }
  
  double get mainPitch {
    final voicedFreqs = frequencies.where((f) => f > 0).toList();
    if (voicedFreqs.isEmpty) return 0.0;
    return voicedFreqs.reduce((a, b) => a + b) / voicedFreqs.length;
  }
  
  double get overallConfidence {
    if (confidence.isEmpty) return 0.0;
    return confidence.reduce((a, b) => a + b) / confidence.length;
  }
  
  double get stability {
    final voicedFreqs = frequencies.where((f) => f > 0).toList();
    if (voicedFreqs.length < 2) return 0.0;
    
    final mean = mainPitch;
    final variance = voicedFreqs
        .map((f) => (f - mean) * (f - mean))
        .reduce((a, b) => a + b) / voicedFreqs.length;
    
    return (100.0 / (1.0 + variance / 100.0)).clamp(0.0, 100.0);
  }
}