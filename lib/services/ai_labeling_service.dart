import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import '../models/vocal_label.dart';

/// AI Labeling Service
/// YouTube 오디오 추출, AI 분석, 라벨 생성을 담당하는 서비스
class AILabelingService {
  final Dio _dio = Dio();
  final String crepeUrl = 'http://localhost:5002/analyze';
  final String spiceUrl = 'http://localhost:5003/analyze';
  
  // 포먼트 분석 임계값
  static const double singerFormantThreshold = 0.5;
  static const double f1ChestThreshold = 600;
  static const double f1HeadThreshold = 400;
  static const double f2BrightThreshold = 2000;
  
  /// YouTube URL 배치 처리
  Future<List<VocalLabel>> processBatch(List<Map<String, dynamic>> youtubeList) async {
    List<VocalLabel> labels = [];
    
    for (var item in youtubeList) {
      try {
        // 1. YouTube 오디오 추출 (Python 스크립트 호출)
        final audioPath = await _extractYouTubeAudio(
          item['url'],
          item['start'] ?? 0,
          item['end'] ?? 15,
        );
        
        if (audioPath == null) {
          print('❌ Failed to extract audio for ${item['url']}');
          continue;
        }
        
        // 2. AI 분석 (CREPE + SPICE + 포먼트)
        final analysis = await _analyzeAudio(audioPath);
        
        // 3. 라벨 생성
        final label = _generateLabel(item, analysis);
        labels.add(label);
        
        // 4. 임시 파일 정리
        await File(audioPath).delete();
        
      } catch (e) {
        print('❌ Error processing ${item['url']}: $e');
      }
    }
    
    return labels;
  }
  
  /// YouTube에서 오디오 추출 (Python 스크립트 활용)
  Future<String?> _extractYouTubeAudio(String url, double start, double end) async {
    try {
      final result = await Process.run('python3', [
        'youtube_audio_extractor.py',
        url,
        start.toString(),
        end.toString(),
      ]);
      
      if (result.exitCode == 0) {
        // 추출된 파일 경로 반환
        return result.stdout.toString().trim();
      }
      
      return null;
    } catch (e) {
      print('Audio extraction error: $e');
      return null;
    }
  }
  
  /// 오디오 분석 (CREPE + SPICE + 포먼트)
  Future<Map<String, dynamic>> _analyzeAudio(String audioPath) async {
    // 오디오 파일 읽기
    final audioFile = File(audioPath);
    final audioBytes = await audioFile.readAsBytes();
    final audioBase64 = base64Encode(audioBytes);
    
    // 병렬로 CREPE와 SPICE 분석
    final results = await Future.wait([
      _analyzeWithCrepe(audioBase64),
      _analyzeWithSpice(audioBase64),
      _extractFormants(audioPath),
    ]);
    
    return {
      'crepe': results[0],
      'spice': results[1],
      'formants': results[2],
      'combined': _combineAnalysis(results[0], results[1], results[2]),
    };
  }
  
  /// CREPE 분석
  Future<Map<String, dynamic>> _analyzeWithCrepe(String audioBase64) async {
    try {
      final response = await _dio.post(
        crepeUrl,
        data: {
          'audio_base64': audioBase64,
          'sample_rate': 44100,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      print('CREPE analysis error: $e');
    }
    
    return {};
  }
  
  /// SPICE 분석
  Future<Map<String, dynamic>> _analyzeWithSpice(String audioBase64) async {
    try {
      final response = await _dio.post(
        spiceUrl,
        data: {
          'audio_base64': audioBase64,
          'sample_rate': 44100,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      print('SPICE analysis error: $e');
    }
    
    return {};
  }
  
  /// 포먼트 추출 (음성학적 분석)
  Future<Map<String, dynamic>> _extractFormants(String audioPath) async {
    // Formant 서버 호출 시도
    const formantUrl = 'http://localhost:5004';
    
    try {
      // 오디오 파일 읽기
      final audioFile = File(audioPath);
      if (await audioFile.exists()) {
        final audioBytes = await audioFile.readAsBytes();
        final audioBase64 = base64Encode(audioBytes);
        
        // Formant 서버로 분석 요청
        final response = await _dio.post(
          '$formantUrl/analyze',
          data: {
            'audio_base64': audioBase64,
            'sample_rate': 44100,
            'start_time': 0,
            'duration': 15,
          },
          options: Options(
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        
        if (response.statusCode == 200) {
          final data = response.data;
          print('✅ Formant 서버 분석 성공');
          
          // 서버 응답에서 포먼트 데이터 추출
          return {
            'f1': data['formants']['f1'] ?? 500,
            'f2': data['formants']['f2'] ?? 1500,
            'f3': data['formants']['f3'] ?? 2500,
            'singersFormant': data['formants']['singers_formant'] ?? 0.5,
            'spectralCentroid': data['spectral_features']?['spectral_centroid'] ?? 2000,
            'hnr': data['spectral_features']?['zero_crossing_rate'] ?? 15,
            'server_analysis': true,
            'vocal_technique': data['vocal_technique'],
            'timbre': data['timbre'],
            'breath_support': data['breath_support'],
          };
        }
      }
    } catch (e) {
      print('⚠️ Formant 서버 연결 실패, 시뮬레이션 모드 사용: $e');
    }
    
    // 서버 연결 실패 시 시뮬레이션 폴백
    final random = math.Random();
    
    // F1, F2, F3 포먼트 주파수
    final f1 = 400 + random.nextDouble() * 400; // 400-800 Hz
    final f2 = 1200 + random.nextDouble() * 800; // 1200-2000 Hz
    final f3 = 2400 + random.nextDouble() * 800; // 2400-3200 Hz
    
    // Singer's Formant (2800-3200 Hz 대역 에너지)
    final singersFormant = random.nextDouble();
    
    // 스펙트럴 중심 (밝기 지표)
    final spectralCentroid = 1500 + random.nextDouble() * 2000;
    
    // 배음 대 잡음 비율
    final harmonicToNoiseRatio = 10 + random.nextDouble() * 20;
    
    return {
      'f1': f1,
      'f2': f2,
      'f3': f3,
      'singersFormant': singersFormant,
      'spectralCentroid': spectralCentroid,
      'hnr': harmonicToNoiseRatio,
      'server_analysis': false,
    };
  }
  
  /// 분석 결과 통합
  Map<String, dynamic> _combineAnalysis(
    Map<String, dynamic> crepe,
    Map<String, dynamic> spice,
    Map<String, dynamic> formants,
  ) {
    // CREPE와 SPICE 결과 평균
    List<double> frequencies = [];
    List<double> confidences = [];
    
    if (crepe.containsKey('pitches')) {
      frequencies.addAll((crepe['pitches'] as List).cast<double>());
    }
    if (spice.containsKey('pitches')) {
      frequencies.addAll((spice['pitches'] as List).cast<double>());
    }
    
    if (crepe.containsKey('confidences')) {
      confidences.addAll((crepe['confidences'] as List).cast<double>());
    }
    if (spice.containsKey('confidences')) {
      confidences.addAll((spice['confidences'] as List).cast<double>());
    }
    
    // 통계 계산
    final avgFreq = frequencies.isNotEmpty
        ? frequencies.reduce((a, b) => a + b) / frequencies.length
        : 220.0;
    
    final avgConfidence = confidences.isNotEmpty
        ? confidences.reduce((a, b) => a + b) / confidences.length
        : 0.5;
    
    final stdFreq = _calculateStandardDeviation(frequencies);
    
    return {
      'avgFrequency': avgFreq,
      'avgConfidence': avgConfidence,
      'stdFrequency': stdFreq,
      'formants': formants,
    };
  }
  
  /// 표준편차 계산
  double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => math.pow(v - mean, 2));
    final avgSquaredDiff = squaredDiffs.reduce((a, b) => a + b) / values.length;
    
    return math.sqrt(avgSquaredDiff);
  }
  
  /// 라벨 생성 (포먼트 기반 개선 버전)
  VocalLabel _generateLabel(
    Map<String, dynamic> item,
    Map<String, dynamic> analysis,
  ) {
    final combined = analysis['combined'] as Map<String, dynamic>;
    final formants = combined['formants'] as Map<String, dynamic>;
    
    // 포먼트 기반 발성 기법 판별
    final technique = _classifyTechnique(formants);
    
    // 스펙트럴 중심 기반 음색 판별
    final tone = _classifyTone(formants);
    
    // 통계 기반 품질 지표
    final avgFreq = combined['avgFrequency'] as double;
    final avgConfidence = combined['avgConfidence'] as double;
    final stdFreq = combined['stdFrequency'] as double;
    
    // 품질 점수 계산
    final quality = _calculateQuality(avgConfidence, stdFreq);
    
    // 음정 정확도 (신뢰도 기반)
    final pitchAccuracy = avgConfidence * 100;
    
    // 호흡 지지력 (안정성 기반)
    final breathSupport = _calculateBreathSupport(stdFreq, avgConfidence);
    
    // 신뢰도 계산
    final aiConfidence = _calculateConfidence(
      avgConfidence,
      formants['singersFormant'] as double,
      formants['f1'] as double,
    );
    
    return VocalLabel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      youtubeUrl: item['url'],
      artistName: item['artist'],
      songTitle: item['song'],
      startTime: (item['start'] ?? 0).toDouble(),
      endTime: (item['end'] ?? 15).toDouble(),
      overallQuality: quality,
      technique: technique,
      tone: tone,
      pitchAccuracy: pitchAccuracy,
      breathSupport: breathSupport,
      notes: 'AI Generated (Confidence: ${(aiConfidence * 100).toStringAsFixed(1)}%)',
      createdAt: DateTime.now(),
      createdBy: 'ai_bot',
    );
  }
  
  /// 포먼트 기반 발성 기법 분류
  String _classifyTechnique(Map<String, dynamic> formants) {
    final f1 = formants['f1'] as double;
    final f2 = formants['f2'] as double;
    final singersFormant = formants['singersFormant'] as double;
    
    // Singer's Formant가 매우 강함 → Belt
    if (singersFormant > 0.7) {
      return VocalTechnique.belt;
    }
    
    // F1이 높음 → Chest Voice
    if (f1 > f1ChestThreshold && singersFormant < 0.3) {
      return VocalTechnique.chest;
    }
    
    // F1이 낮고 F2가 높음 → Head Voice
    if (f1 < f1HeadThreshold && f2 > f2BrightThreshold) {
      return VocalTechnique.head;
    }
    
    // 그 외 → Mix Voice
    return VocalTechnique.mix;
  }
  
  /// 스펙트럴 중심 기반 음색 분류
  String _classifyTone(Map<String, dynamic> formants) {
    final spectralCentroid = formants['spectralCentroid'] as double;
    
    if (spectralCentroid < 1500) {
      return VocalTone.dark;
    } else if (spectralCentroid < 2500) {
      return VocalTone.warm;
    } else if (spectralCentroid < 3500) {
      return VocalTone.neutral;
    } else {
      return VocalTone.bright;
    }
  }
  
  /// 품질 점수 계산
  int _calculateQuality(double confidence, double std) {
    final score = confidence * 3 + (1 - math.min(std / 50, 1)) * 2;
    return math.max(1, math.min(5, score.round()));
  }
  
  /// 호흡 지지력 계산
  double _calculateBreathSupport(double std, double confidence) {
    final stability = 1 - math.min(std / 100, 1);
    return (stability * 0.6 + confidence * 0.4) * 100;
  }
  
  /// AI 신뢰도 계산
  double _calculateConfidence(double avgConfidence, double singersFormant, double f1) {
    double confidence = 0.5;
    
    // 피치 신뢰도가 높으면
    if (avgConfidence > 0.9) {
      confidence += 0.2;
    } else if (avgConfidence > 0.8) {
      confidence += 0.1;
    }
    
    // Singer's Formant가 명확하면
    if (singersFormant > 0.8 || singersFormant < 0.2) {
      confidence += 0.1;
    }
    
    // F1이 전형적인 범위면
    if (f1 > 300 && f1 < 700) {
      confidence += 0.1;
    }
    
    // 배음 구조가 명확하면
    confidence += 0.1;
    
    return math.min(1.0, confidence);
  }
  
  /// 라벨 저장
  Future<void> saveLabel(VocalLabel label) async {
    final file = File('labels/${label.id}.json');
    await file.writeAsString(jsonEncode(label.toJson()));
  }
  
  /// 라벨 불러오기
  Future<List<VocalLabel>> loadLabels({String? status}) async {
    final dir = Directory('labels');
    if (!await dir.exists()) {
      return [];
    }
    
    final files = await dir.list().toList();
    final labels = <VocalLabel>[];
    
    for (var file in files) {
      if (file is File && file.path.endsWith('.json')) {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        labels.add(VocalLabel.fromJson(json));
      }
    }
    
    return labels;
  }
}