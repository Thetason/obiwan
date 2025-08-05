import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';  
import 'package:flutter/foundation.dart';

/// 공식 CREPE 서버와 통신하는 피치 분석 서비스
class OfficialCrepeService {
  static const String _baseUrl = 'http://localhost:5002';
  static const int _timeoutMs = 15000; // CREPE는 처리 시간이 더 필요
  
  late final Dio _dio;
  
  // 싱글톤 패턴
  static final OfficialCrepeService _instance = OfficialCrepeService._internal();
  factory OfficialCrepeService() => _instance;
  
  OfficialCrepeService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: Duration(milliseconds: _timeoutMs),
      receiveTimeout: Duration(milliseconds: _timeoutMs),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    // 로깅 인터셉터 (디버그 모드에서만)
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false, // 오디오 데이터는 로그에서 제외
        responseBody: false,
      ));
    }
  }
  
  /// 서버 상태 확인
  Future<CrepeServerStatus?> checkServerHealth() async {
    try {
      final response = await _dio.get('/health');
      if (response.statusCode == 200) {
        return CrepeServerStatus.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('CREPE server health check failed: $e');
      return null;
    }
  }
  
  /// 공식 CREPE 피치 분석
  Future<CrepeAnalysisResult?> analyzePitch(Float32List audioData) async {
    try {
      final response = await _dio.post('/analyze', data: {
        'audio': audioData.toList(),
      });
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return CrepeAnalysisResult.fromJson(response.data['data']);
      }
      
      return null;
    } catch (e) {
      debugPrint('Official CREPE analysis failed: $e');
      return null;
    }
  }
  
  /// 실시간 분석 (여러 청크)
  Future<CrepeAnalysisResult?> analyzeRealtime(List<Float32List> audioChunks) async {
    try {
      final response = await _dio.post('/realtime_analyze', data: {
        'audio_chunks': audioChunks.map((chunk) => chunk.toList()).toList(),
      });
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return CrepeAnalysisResult.fromJson(response.data['data']);
      }
      
      return null;
    } catch (e) {
      debugPrint('CREPE realtime analysis failed: $e');
      return null;
    }
  }
  
  /// 모델 정보 가져오기
  Future<CrepeModelInfo?> getModelInfo() async {
    try {
      final response = await _dio.get('/model_info');
      if (response.statusCode == 200) {
        return CrepeModelInfo.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get CREPE model info: $e');
      return null;
    }
  }
  
  /// CREPE 정확도 테스트
  Future<CrepeTestResult?> testAccuracy() async {
    try {
      final response = await _dio.get('/test');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return CrepeTestResult.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint('CREPE accuracy test failed: $e');
      return null;
    }
  }
}

/// 실시간 CREPE 분석 스트림 매니저
class RealtimeCrepeStream {
  final OfficialCrepeService _service = OfficialCrepeService();
  final StreamController<CrepeAnalysisResult> _controller = 
      StreamController<CrepeAnalysisResult>.broadcast();
  
  Stream<CrepeAnalysisResult> get stream => _controller.stream;
  
  Timer? _analysisTimer;
  final List<Float32List> _audioBuffer = [];
  final int _maxBufferSize = 3; // 3개 청크씩 모아서 분석
  
  /// 실시간 스트림 시작
  void startStream() {
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _processBuffer();
    });
  }
  
  /// 오디오 청크 추가
  void addAudioChunk(Float32List audioData) {
    _audioBuffer.add(audioData);
    
    // 버퍼 크기 제한
    if (_audioBuffer.length > _maxBufferSize) {
      _audioBuffer.removeAt(0);
    }
  }
  
  /// 버퍼 처리
  void _processBuffer() async {
    if (_audioBuffer.isEmpty) return;
    
    try {
      final result = await _service.analyzeRealtime(List.from(_audioBuffer));
      if (result != null) {
        _controller.add(result);
      }
    } catch (e) {
      debugPrint('Real-time processing error: $e');
    }
  }
  
  /// 스트림 중단
  void stopStream() {
    _analysisTimer?.cancel();
    _analysisTimer = null;
    _audioBuffer.clear();
  }
  
  /// 리소스 해제
  void dispose() {
    stopStream();
    _controller.close();
  }
}

/// CREPE 서버 상태 정보
class CrepeServerStatus {
  final String status;
  final String server;
  final String version;
  final String model;
  final String crepeVersion;
  final int sampleRate;
  final int stepSizeMs;
  final double timestamp;
  
  CrepeServerStatus({
    required this.status,
    required this.server,
    required this.version,
    required this.model,
    required this.crepeVersion,
    required this.sampleRate,
    required this.stepSizeMs,
    required this.timestamp,
  });
  
  factory CrepeServerStatus.fromJson(Map<String, dynamic> json) {
    return CrepeServerStatus(
      status: json['status'],
      server: json['server'],
      version: json['version'],
      model: json['model'],
      crepeVersion: json['crepe_version'],
      sampleRate: json['sample_rate'],
      stepSizeMs: json['step_size_ms'],
      timestamp: json['timestamp'].toDouble(),
    );
  }
  
  bool get isHealthy => status == 'healthy';
}

/// CREPE 분석 결과
class CrepeAnalysisResult {
  final List<double> timestamps;
  final List<double> frequencies;
  final List<double> confidence;
  final List<List<double>> activation;
  final CrepeStatistics statistics;
  final CrepeParameters parameters;
  
  CrepeAnalysisResult({
    required this.timestamps,
    required this.frequencies,
    required this.confidence,
    required this.activation,
    required this.statistics,
    required this.parameters,
  });
  
  factory CrepeAnalysisResult.fromJson(Map<String, dynamic> json) {
    return CrepeAnalysisResult(
      timestamps: List<double>.from(json['timestamps']),
      frequencies: List<double>.from(json['frequencies']),
      confidence: List<double>.from(json['confidence']),
      activation: (json['activation'] as List)
          .map((e) => List<double>.from(e))
          .toList(),
      statistics: CrepeStatistics.fromJson(json['statistics']),
      parameters: CrepeParameters.fromJson(json['parameters']),
    );
  }
  
  /// 주요 피치 (유성음만)
  double get mainPitch => statistics.averageFrequency;
  
  /// 전체 신뢰도
  double get overallConfidence => statistics.averageConfidence;
  
  /// 피치 안정성
  double get stability => statistics.pitchStability;
  
  /// 유성음/무성음 비율
  double get voicedRatio => statistics.voicedRatio;
  
  @override
  String toString() {
    return 'CrepeResult(pitch: ${mainPitch.toStringAsFixed(1)}Hz, '
           'confidence: ${(overallConfidence * 100).toStringAsFixed(1)}%, '
           'stability: ${stability.toStringAsFixed(1)}%, '
           'voiced: ${(voicedRatio * 100).toStringAsFixed(1)}%)';
  }
}

/// CREPE 통계 정보
class CrepeStatistics {
  final double averageFrequency;
  final double averageConfidence;
  final double pitchStability;
  final double voicedRatio;
  final int totalFrames;
  final int voicedFrames;
  
  CrepeStatistics({
    required this.averageFrequency,
    required this.averageConfidence,
    required this.pitchStability,
    required this.voicedRatio,
    required this.totalFrames,
    required this.voicedFrames,
  });
  
  factory CrepeStatistics.fromJson(Map<String, dynamic> json) {
    return CrepeStatistics(
      averageFrequency: json['average_frequency'].toDouble(),
      averageConfidence: json['average_confidence'].toDouble(),
      pitchStability: json['pitch_stability'].toDouble(),
      voicedRatio: json['voiced_ratio'].toDouble(),
      totalFrames: json['total_frames'],
      voicedFrames: json['voiced_frames'],
    );
  }
}

/// CREPE 파라미터 정보
class CrepeParameters {
  final String model;
  final int sampleRate;
  final int stepSizeMs;
  final bool viterbi;
  final double inferenceTimeMs;
  
  CrepeParameters({
    required this.model,
    required this.sampleRate,
    required this.stepSizeMs,
    required this.viterbi,
    required this.inferenceTimeMs,
  });
  
  factory CrepeParameters.fromJson(Map<String, dynamic> json) {
    return CrepeParameters(
      model: json['model'],
      sampleRate: json['sample_rate'],
      stepSizeMs: json['step_size_ms'],
      viterbi: json['viterbi'],
      inferenceTimeMs: json['inference_time_ms'].toDouble(),
    );
  }
}

/// CREPE 모델 정보
class CrepeModelInfo {
  final String modelName;
  final String modelCapacity;
  final int sampleRate;
  final int stepSizeMs;
  final String frequencyRange;
  final int outputBins;
  final bool viterbiSmoothing;
  final bool centerAlignment;
  final String paper;
  final String authors;
  final String accuracy;
  
  CrepeModelInfo({
    required this.modelName,
    required this.modelCapacity,
    required this.sampleRate,  
    required this.stepSizeMs,
    required this.frequencyRange,
    required this.outputBins,
    required this.viterbiSmoothing,
    required this.centerAlignment,
    required this.paper,
    required this.authors,
    required this.accuracy,
  });
  
  factory CrepeModelInfo.fromJson(Map<String, dynamic> json) {
    return CrepeModelInfo(
      modelName: json['model_name'],
      modelCapacity: json['model_capacity'],
      sampleRate: json['sample_rate'],
      stepSizeMs: json['step_size_ms'],
      frequencyRange: json['frequency_range'],
      outputBins: json['output_bins'],
      viterbiSmoothing: json['viterbi_smoothing'],
      centerAlignment: json['center_alignment'],
      paper: json['paper'],
      authors: json['authors'],
      accuracy: json['accuracy'],
    );
  }
}

/// CREPE 테스트 결과
class CrepeTestResult {
  final double testFrequency;
  final double detectedFrequency;
  final double errorCents;
  final double confidence;
  final String accuracy;
  final String message;
  
  CrepeTestResult({
    required this.testFrequency,
    required this.detectedFrequency,
    required this.errorCents,
    required this.confidence,
    required this.accuracy,
    required this.message,
  });
  
  factory CrepeTestResult.fromJson(Map<String, dynamic> json) {
    return CrepeTestResult(
      testFrequency: json['test_frequency'].toDouble(),
      detectedFrequency: json['detected_frequency'].toDouble(),
      errorCents: json['error_cents'].toDouble(),
      confidence: json['confidence'].toDouble(),
      accuracy: json['accuracy'],
      message: json['message'],
    );
  }
  
  bool get isAccurate => accuracy == 'excellent' || accuracy == 'good';
}

/// 보컬 트레이닝용 CREPE 피드백 생성기
class CrepeVocalFeedback {
  /// 음정 정확도 피드백 (CREPE 기반)
  static String getPitchAccuracyFeedback(double targetHz, double actualHz, double confidence) {
    if (actualHz <= 0 || confidence < 0.1) {
      return "목소리가 감지되지 않았어요 🎤";
    }
    
    final cents = 1200 * (actualHz / targetHz).clamp(0.1, 10.0).log() / (2.log());
    final absCents = cents.abs();
    final confidenceText = confidence > 0.8 ? "확실함" : confidence > 0.5 ? "보통" : "불확실";
    
    if (absCents < 5) {
      return "완벽합니다! 🎯 (${cents.toStringAsFixed(1)} cents, $confidenceText)";
    } else if (absCents < 15) {
      return cents > 0 
          ? "조금 높아요 ⬇️ (+${cents.toStringAsFixed(1)} cents, $confidenceText)"
          : "조금 낮아요 ⬆️ (${cents.toStringAsFixed(1)} cents, $confidenceText)";
    } else if (absCents < 30) {
      return cents > 0 
          ? "많이 높아요 ⬇️⬇️ (+${cents.toStringAsFixed(1)} cents, $confidenceText)"
          : "많이 낮아요 ⬆️⬆️ (${cents.toStringAsFixed(1)} cents, $confidenceText)";
    } else {
      return cents > 0 
          ? "너무 높습니다 🔻 (+${cents.toStringAsFixed(1)} cents, $confidenceText)"
          : "너무 낮습니다 🔺 (${cents.toStringAsFixed(1)} cents, $confidenceText)";
    }
  }
  
  /// CREPE 기반 종합 피드백
  static Map<String, String> getComprehensiveFeedback(CrepeAnalysisResult result) {
    return {
      'pitch': "평균 피치: ${result.mainPitch.toStringAsFixed(1)}Hz",
      'confidence': "CREPE 신뢰도: ${(result.overallConfidence * 100).toStringAsFixed(1)}%",
      'stability': "피치 안정성: ${result.stability.toStringAsFixed(1)}%",
      'voiced': "발성 비율: ${(result.voicedRatio * 100).toStringAsFixed(1)}%",
      'model': "분석: ${result.parameters.model}",
      'performance': "처리 시간: ${result.parameters.inferenceTimeMs.toStringAsFixed(1)}ms",
    };
  }
  
  /// 실시간 코칭 메시지
  static String getRealtimeCoaching(CrepeAnalysisResult result) {
    final pitch = result.mainPitch;
    final confidence = result.overallConfidence;
    final stability = result.stability;
    
    if (confidence < 0.3) {
      return "더 큰 소리로 불러보세요 📢";
    }
    
    if (stability < 30) {
      return "음정을 더 일정하게 유지해보세요 📈";
    }
    
    if (stability > 80 && confidence > 0.8) {
      return "훌륭한 발성입니다! 🌟";
    }
    
    return "좋습니다! 계속해보세요 👍";
  }
}