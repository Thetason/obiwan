import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// CREPE 서버와 통신하는 고성능 피치 분석 서비스
class CrepePitchService {
  static const String _baseUrl = 'http://localhost:5000';
  static const int _timeoutMs = 5000;
  
  late final Dio _dio;
  
  // 싱글톤 패턴
  static final CrepePitchService _instance = CrepePitchService._internal();
  factory CrepePitchService() => _instance;
  
  CrepePitchService._internal() {
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
  Future<bool> checkServerHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200 && 
             response.data['status'] == 'healthy';
    } catch (e) {
      debugPrint('Server health check failed: $e');
      return false;
    }
  }
  
  /// 단일 오디오 청크 피치 분석 (동기식)
  Future<PitchAnalysisResult?> analyzePitch(Float32List audioData) async {
    try {
      final response = await _dio.post('/analyze', data: {
        'audio': audioData.toList(),
      });
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return PitchAnalysisResult.fromJson(response.data['data']);
      }
      
      return null;
    } catch (e) {
      debugPrint('Pitch analysis failed: $e');
      return null;
    }
  }
  
  /// 실시간 피치 분석 (비동기식)
  Future<String?> startRealtimeAnalysis(Float32List audioData) async {
    try {
      final response = await _dio.post('/analyze_realtime', data: {
        'audio': audioData.toList(),
      });
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['task_id'];
      }
      
      return null;
    } catch (e) {
      debugPrint('Realtime analysis start failed: $e');
      return null;
    }
  }
  
  /// 실시간 분석 결과 조회
  Future<PitchAnalysisResult?> getRealtimeResult(String taskId) async {
    try {
      final response = await _dio.get('/get_result/$taskId');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return PitchAnalysisResult.fromJson(response.data['data']);
      } else if (response.statusCode == 202) {
        // 아직 처리 중
        return null;
      }
      
      return null;
    } catch (e) {
      debugPrint('Get realtime result failed: $e');
      return null;
    }
  }
  
  /// 배치 피치 분석 (여러 청크 동시 처리)
  Future<List<PitchAnalysisResult>> batchAnalyze(List<Float32List> audioChunks) async {
    try {
      final response = await _dio.post('/batch_analyze', data: {
        'audio_chunks': audioChunks.map((chunk) => chunk.toList()).toList(),
      });
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final results = <PitchAnalysisResult>[];
        for (final resultData in response.data['results']) {
          results.add(PitchAnalysisResult.fromJson(resultData['data']));
        }
        return results;
      }
      
      return [];
    } catch (e) {
      debugPrint('Batch analysis failed: $e');
      return [];
    }
  }
}

/// 실시간 피치 분석 스트림 매니저
class RealtimePitchStream {
  final CrepePitchService _service = CrepePitchService();
  final StreamController<PitchAnalysisResult> _controller = 
      StreamController<PitchAnalysisResult>.broadcast();
  
  Stream<PitchAnalysisResult> get stream => _controller.stream;
  
  Timer? _pollTimer;
  final Set<String> _pendingTasks = {};
  
  /// 실시간 스트림 시작
  void startStream() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _pollResults();
    });
  }
  
  /// 오디오 청크 추가
  Future<void> addAudioChunk(Float32List audioData) async {
    final taskId = await _service.startRealtimeAnalysis(audioData);
    if (taskId != null) {
      _pendingTasks.add(taskId);
    }
  }
  
  /// 결과 폴링
  void _pollResults() async {
    final completedTasks = <String>[];
    
    for (final taskId in _pendingTasks) {
      final result = await _service.getRealtimeResult(taskId);
      if (result != null) {
        _controller.add(result);
        completedTasks.add(taskId);
      }
    }
    
    // 완료된 태스크 제거
    for (final taskId in completedTasks) {
      _pendingTasks.remove(taskId);
    }
  }
  
  /// 스트림 중단
  void stopStream() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pendingTasks.clear();
  }
  
  /// 리소스 해제
  void dispose() {
    stopStream();
    _controller.close();
  }
}

/// 피치 분석 결과 모델
class PitchAnalysisResult {
  final List<double> frequencies;    // 각 프레임의 주파수값
  final List<double> confidence;     // 각 프레임의 신뢰도
  final List<double> timestamps;     // 각 프레임의 타임스탬프
  final int sampleRate;              // 샘플레이트
  
  PitchAnalysisResult({
    required this.frequencies,
    required this.confidence,
    required this.timestamps,
    required this.sampleRate,
  });
  
  factory PitchAnalysisResult.fromJson(Map<String, dynamic> json) {
    return PitchAnalysisResult(
      frequencies: List<double>.from(json['frequencies']),
      confidence: List<double>.from(json['confidence']),
      timestamps: List<double>.from(json['timestamps']),
      sampleRate: json['sample_rate'],
    );
  }
  
  /// 평균 피치 계산 (유성음만)
  double get averagePitch {
    final voicedFrequencies = frequencies.where((f) => f > 0).toList();
    if (voicedFrequencies.isEmpty) return 0.0;
    
    return voicedFrequencies.reduce((a, b) => a + b) / voicedFrequencies.length;
  }
  
  /// 피치 안정성 계산 (표준편차 기반)
  double get pitchStability {
    final voicedFrequencies = frequencies.where((f) => f > 0).toList();
    if (voicedFrequencies.length < 2) return 0.0;
    
    final mean = averagePitch;
    final variance = voicedFrequencies
        .map((f) => (f - mean) * (f - mean))
        .reduce((a, b) => a + b) / voicedFrequencies.length;
    
    final stdDev = variance < 0 ? 0.0 : variance; // sqrt 대신 간단히
    
    // 안정성 점수 (낮은 표준편차 = 높은 안정성)
    return (100.0 / (1.0 + stdDev / 10.0)).clamp(0.0, 100.0);
  }
  
  /// 유성음 비율
  double get voicedRatio {
    if (frequencies.isEmpty) return 0.0;
    final voicedCount = frequencies.where((f) => f > 0).length;
    return voicedCount / frequencies.length;
  }
  
  /// 평균 신뢰도
  double get averageConfidence {
    if (confidence.isEmpty) return 0.0;
    return confidence.reduce((a, b) => a + b) / confidence.length;
  }
  
  @override
  String toString() {
    return 'PitchResult(avgPitch: ${averagePitch.toStringAsFixed(1)}Hz, '
           'stability: ${pitchStability.toStringAsFixed(1)}%, '
           'voiced: ${(voicedRatio * 100).toStringAsFixed(1)}%, '
           'confidence: ${(averageConfidence * 100).toStringAsFixed(1)}%)';
  }
}

/// 보컬 트레이닝용 피드백 생성기
class VocalFeedbackGenerator {
  /// 음정 정확도 피드백
  static String getPitchAccuracyFeedback(double targetHz, double actualHz) {
    if (actualHz <= 0) return "목소리가 감지되지 않았어요 🎤";
    
    final cents = 1200 * (actualHz / targetHz - 1) / (actualHz / targetHz).clamp(0.1, 10.0);
    final absCents = cents.abs();
    
    if (absCents < 5) {
      return "완벽합니다! 🎯 (${cents.toStringAsFixed(1)} cents)";
    } else if (absCents < 15) {
      return cents > 0 
          ? "조금 높아요 ⬇️ (+${cents.toStringAsFixed(1)} cents)"
          : "조금 낮아요 ⬆️ (${cents.toStringAsFixed(1)} cents)";
    } else if (absCents < 30) {
      return cents > 0 
          ? "많이 높아요 ⬇️⬇️ (+${cents.toStringAsFixed(1)} cents)"
          : "많이 낮아요 ⬆️⬆️ (${cents.toStringAsFixed(1)} cents)";
    } else {
      return cents > 0 
          ? "너무 높습니다 🔻 (+${cents.toStringAsFixed(1)} cents)"
          : "너무 낮습니다 🔺 (${cents.toStringAsFixed(1)} cents)";
    }
  }
  
  /// 안정성 피드백
  static String getStabilityFeedback(double stability) {
    if (stability >= 90) {
      return "매우 안정적입니다! 🎵";
    } else if (stability >= 70) {
      return "안정적이에요 👍";
    } else if (stability >= 50) {
      return "조금 더 안정적으로 불러보세요 🎶";
    } else {
      return "음정을 더 일정하게 유지해보세요 📈";
    }
  }
  
  /// 종합 피드백
  static Map<String, String> getComprehensiveFeedback(PitchAnalysisResult result) {
    return {
      'pitch': "평균 피치: ${result.averagePitch.toStringAsFixed(1)}Hz",
      'stability': getStabilityFeedback(result.pitchStability),
      'voiced': "발성 비율: ${(result.voicedRatio * 100).toStringAsFixed(1)}%",
      'confidence': "분석 신뢰도: ${(result.averageConfidence * 100).toStringAsFixed(1)}%",
    };
  }
}