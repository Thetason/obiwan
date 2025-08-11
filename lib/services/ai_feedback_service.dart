import 'dart:math' as math;
import '../models/analysis_result.dart';
import '../models/pitch_point.dart';

class AIFeedbackService {
  static final AIFeedbackService _instance = AIFeedbackService._internal();
  factory AIFeedbackService() => _instance;
  AIFeedbackService._internal();

  // 피드백 카테고리
  static const Map<String, List<String>> feedbackTemplates = {
    'excellent': [
      '훌륭해요! 매우 안정적인 음정을 유지했습니다.',
      '완벽합니다! 프로 수준의 음정 컨트롤을 보여주셨네요.',
      '정말 잘했어요! 음정이 매우 정확합니다.',
    ],
    'good': [
      '잘하고 있어요! 조금만 더 연습하면 완벽해질 거예요.',
      '좋아요! 음정이 대체로 안정적입니다.',
      '훌륭한 시도입니다! 약간의 개선 여지가 있어요.',
    ],
    'needsWork': [
      '연습이 더 필요해요. 천천히 음정에 집중해보세요.',
      '음정이 불안정합니다. 호흡을 안정시키고 다시 시도해보세요.',
      '기초부터 차근차근 연습해봅시다.',
    ],
  };

  // 종합적인 AI 피드백 생성
  VocalFeedback generateFeedback({
    required List<PitchPoint> pitchHistory,
    double? targetFrequency,
    String? targetNote,
  }) {
    if (pitchHistory.isEmpty) {
      return VocalFeedback(
        overallScore: 0,
        pitchAccuracy: 0,
        pitchStability: 0,
        vibrato: VibratoAnalysis(present: false),
        summary: '녹음된 데이터가 없습니다.',
        suggestions: ['녹음 버튼을 눌러 노래를 불러보세요.'],
      );
    }

    // 1. 음정 정확도 분석
    final pitchAccuracy = _analyzePitchAccuracy(pitchHistory, targetFrequency);
    
    // 2. 음정 안정성 분석
    final pitchStability = _analyzePitchStability(pitchHistory);
    
    // 3. 비브라토 분석
    final vibrato = _analyzeVibrato(pitchHistory);
    
    // 4. 음역대 분석
    final range = _analyzeVocalRange(pitchHistory);
    
    // 5. 전체 점수 계산
    final overallScore = _calculateOverallScore(
      accuracy: pitchAccuracy,
      stability: pitchStability,
      vibrato: vibrato,
      confidence: _getAverageConfidence(pitchHistory),
    );
    
    // 6. 피드백 메시지 생성
    final summary = _generateSummary(overallScore, pitchAccuracy, pitchStability);
    final suggestions = _generateSuggestions(
      pitchAccuracy: pitchAccuracy,
      stability: pitchStability,
      vibrato: vibrato,
      range: range,
    );
    
    // 7. 강점과 약점 분석
    final strengths = _identifyStrengths(pitchAccuracy, pitchStability, vibrato);
    final improvements = _identifyImprovements(pitchAccuracy, pitchStability, vibrato);

    return VocalFeedback(
      overallScore: overallScore,
      pitchAccuracy: pitchAccuracy,
      pitchStability: pitchStability,
      vibrato: vibrato,
      vocalRange: range,
      summary: summary,
      suggestions: suggestions,
      strengths: strengths,
      improvements: improvements,
      pitchHistory: pitchHistory,
    );
  }

  // 음정 정확도 분석
  double _analyzePitchAccuracy(List<PitchPoint> pitchHistory, double? targetFreq) {
    if (targetFreq == null || targetFreq <= 0) {
      // 타겟이 없으면 평균 주파수 대비 편차로 계산
      final avgFreq = _getAverageFrequency(pitchHistory);
      if (avgFreq <= 0) return 0;
      
      double totalDeviation = 0;
      int validCount = 0;
      
      for (final point in pitchHistory) {
        if (point.frequency > 0) {
          final deviation = (point.frequency - avgFreq).abs() / avgFreq;
          totalDeviation += math.min(deviation, 1.0); // 최대 100% 편차
          validCount++;
        }
      }
      
      return validCount > 0 ? math.max(0, 1.0 - (totalDeviation / validCount)) : 0;
    }
    
    // 타겟 주파수가 있으면 그것과 비교
    double totalAccuracy = 0;
    int validCount = 0;
    
    for (final point in pitchHistory) {
      if (point.frequency > 0) {
        // 센트 단위로 정확도 계산
        final cents = 1200 * math.log(point.frequency / targetFreq) / math.log(2);
        // ±50센트 이내를 100%로, ±100센트를 0%로
        final accuracy = math.max(0, 1.0 - cents.abs() / 100);
        totalAccuracy += accuracy * point.confidence;
        validCount++;
      }
    }
    
    return validCount > 0 ? totalAccuracy / validCount : 0;
  }

  // 음정 안정성 분석
  double _analyzePitchStability(List<PitchPoint> pitchHistory) {
    if (pitchHistory.length < 3) return 0;
    
    // 연속된 음정 변화율 계산
    double totalVariation = 0;
    int validPairs = 0;
    
    for (int i = 1; i < pitchHistory.length; i++) {
      final prev = pitchHistory[i - 1];
      final curr = pitchHistory[i];
      
      if (prev.frequency > 0 && curr.frequency > 0) {
        // 센트 단위 변화
        final cents = 1200 * math.log(curr.frequency / prev.frequency) / math.log(2);
        // 10센트 이내 변화를 안정적으로 봄
        final stability = math.max(0, 1.0 - cents.abs() / 50);
        totalVariation += stability;
        validPairs++;
      }
    }
    
    return validPairs > 0 ? totalVariation / validPairs : 0;
  }

  // 비브라토 분석
  VibratoAnalysis _analyzeVibrato(List<PitchPoint> pitchHistory) {
    if (pitchHistory.length < 20) {
      return VibratoAnalysis(present: false);
    }
    
    // 주파수 변화 패턴 분석
    List<double> frequencies = [];
    for (final point in pitchHistory) {
      if (point.frequency > 0) {
        frequencies.add(point.frequency);
      }
    }
    
    if (frequencies.length < 20) {
      return VibratoAnalysis(present: false);
    }
    
    // 이동 평균으로 전체 트렌드 제거
    final trend = _calculateMovingAverage(frequencies, 5);
    final detrended = <double>[];
    for (int i = 0; i < frequencies.length && i < trend.length; i++) {
      detrended.add(frequencies[i] - trend[i]);
    }
    
    // 영점 교차 횟수로 비브라토 주파수 추정
    int zeroCrossings = 0;
    for (int i = 1; i < detrended.length; i++) {
      if (detrended[i - 1] * detrended[i] < 0) {
        zeroCrossings++;
      }
    }
    
    // 비브라토 판단 (4-8Hz 범위)
    final duration = pitchHistory.length * 0.05; // 50ms 간격 가정
    final vibratoRate = zeroCrossings / (2 * duration);
    
    if (vibratoRate >= 4 && vibratoRate <= 8) {
      // 비브라토 깊이 계산
      double maxDeviation = 0;
      for (final val in detrended) {
        maxDeviation = math.max(maxDeviation, val.abs());
      }
      
      final avgFreq = _getAverageFrequency(pitchHistory);
      final depth = (maxDeviation / avgFreq) * 100; // 퍼센트
      
      return VibratoAnalysis(
        present: true,
        rate: vibratoRate,
        depth: depth,
        quality: _evaluateVibratoQuality(vibratoRate, depth),
      );
    }
    
    return VibratoAnalysis(present: false);
  }

  // 음역대 분석
  VocalRange _analyzeVocalRange(List<PitchPoint> pitchHistory) {
    if (pitchHistory.isEmpty) {
      return VocalRange(lowest: '', highest: '', rangeInSemitones: 0);
    }
    
    double minFreq = double.infinity;
    double maxFreq = 0;
    String lowestNote = '';
    String highestNote = '';
    
    for (final point in pitchHistory) {
      if (point.frequency > 0 && point.confidence > 0.5) {
        if (point.frequency < minFreq) {
          minFreq = point.frequency;
          lowestNote = point.note;
        }
        if (point.frequency > maxFreq) {
          maxFreq = point.frequency;
          highestNote = point.note;
        }
      }
    }
    
    if (minFreq == double.infinity || maxFreq == 0) {
      return VocalRange(lowest: '', highest: '', rangeInSemitones: 0);
    }
    
    // 반음 단위 범위 계산
    final semitones = (12 * math.log(maxFreq / minFreq) / math.log(2)).round();
    
    return VocalRange(
      lowest: lowestNote,
      highest: highestNote,
      rangeInSemitones: semitones,
      lowestFreq: minFreq,
      highestFreq: maxFreq,
    );
  }

  // 전체 점수 계산
  double _calculateOverallScore({
    required double accuracy,
    required double stability,
    required VibratoAnalysis vibrato,
    required double confidence,
  }) {
    // 가중치 적용
    double score = 0;
    score += accuracy * 0.4;    // 정확도 40%
    score += stability * 0.3;   // 안정성 30%
    score += confidence * 0.2;  // 신뢰도 20%
    
    // 비브라토 보너스 (최대 10%)
    if (vibrato.present && vibrato.quality == 'excellent') {
      score += 0.1;
    } else if (vibrato.present && vibrato.quality == 'good') {
      score += 0.05;
    }
    
    return math.min(1.0, score);
  }

  // 요약 메시지 생성
  String _generateSummary(double score, double accuracy, double stability) {
    if (score >= 0.9) {
      return feedbackTemplates['excellent']![math.Random().nextInt(3)];
    } else if (score >= 0.7) {
      return feedbackTemplates['good']![math.Random().nextInt(3)];
    } else {
      return feedbackTemplates['needsWork']![math.Random().nextInt(3)];
    }
  }

  // 개선 제안 생성
  List<String> _generateSuggestions({
    required double pitchAccuracy,
    required double stability,
    required VibratoAnalysis vibrato,
    required VocalRange range,
  }) {
    final suggestions = <String>[];
    
    if (pitchAccuracy < 0.7) {
      suggestions.add('🎯 음정 정확도를 높이기 위해 피아노나 튜너 앱과 함께 연습해보세요.');
    }
    
    if (stability < 0.7) {
      suggestions.add('💨 호흡을 안정시켜 음정을 일정하게 유지하는 연습을 해보세요.');
    }
    
    if (!vibrato.present) {
      suggestions.add('🎵 긴 음을 낼 때 자연스러운 비브라토를 넣어보세요.');
    } else if (vibrato.quality == 'too fast') {
      suggestions.add('🎵 비브라토 속도를 조금 느리게 조절해보세요.');
    } else if (vibrato.quality == 'too slow') {
      suggestions.add('🎵 비브라토 속도를 조금 빠르게 조절해보세요.');
    }
    
    if (range.rangeInSemitones < 12) {
      suggestions.add('🎹 음역대를 넓히는 스케일 연습을 시도해보세요.');
    }
    
    if (suggestions.isEmpty) {
      suggestions.add('👏 훌륭합니다! 계속 이 수준을 유지하세요.');
    }
    
    return suggestions;
  }

  // 강점 식별
  List<String> _identifyStrengths(double accuracy, double stability, VibratoAnalysis vibrato) {
    final strengths = <String>[];
    
    if (accuracy >= 0.85) {
      strengths.add('음정 정확도가 매우 뛰어납니다');
    }
    if (stability >= 0.85) {
      strengths.add('매우 안정적인 음정 유지');
    }
    if (vibrato.present && vibrato.quality == 'excellent') {
      strengths.add('아름다운 비브라토');
    }
    
    return strengths;
  }

  // 개선점 식별
  List<String> _identifyImprovements(double accuracy, double stability, VibratoAnalysis vibrato) {
    final improvements = <String>[];
    
    if (accuracy < 0.7) {
      improvements.add('음정 정확도 향상 필요');
    }
    if (stability < 0.7) {
      improvements.add('음정 안정성 개선 필요');
    }
    if (!vibrato.present) {
      improvements.add('비브라토 기술 개발');
    }
    
    return improvements;
  }

  // 유틸리티 함수들
  double _getAverageFrequency(List<PitchPoint> pitchHistory) {
    if (pitchHistory.isEmpty) return 0;
    
    double sum = 0;
    int count = 0;
    
    for (final point in pitchHistory) {
      if (point.frequency > 0) {
        sum += point.frequency;
        count++;
      }
    }
    
    return count > 0 ? sum / count : 0;
  }

  double _getAverageConfidence(List<PitchPoint> pitchHistory) {
    if (pitchHistory.isEmpty) return 0;
    
    double sum = 0;
    for (final point in pitchHistory) {
      sum += point.confidence;
    }
    
    return sum / pitchHistory.length;
  }

  List<double> _calculateMovingAverage(List<double> data, int window) {
    if (data.length < window) return data;
    
    final result = <double>[];
    for (int i = 0; i <= data.length - window; i++) {
      double sum = 0;
      for (int j = 0; j < window; j++) {
        sum += data[i + j];
      }
      result.add(sum / window);
    }
    
    return result;
  }

  String _evaluateVibratoQuality(double rate, double depth) {
    if (rate >= 5 && rate <= 7 && depth >= 2 && depth <= 5) {
      return 'excellent';
    } else if (rate >= 4 && rate <= 8 && depth >= 1 && depth <= 7) {
      return 'good';
    } else if (rate > 8) {
      return 'too fast';
    } else if (rate < 4) {
      return 'too slow';
    } else if (depth > 7) {
      return 'too wide';
    } else {
      return 'needs work';
    }
  }
}


// AI 피드백 결과
class VocalFeedback {
  final double overallScore;
  final double pitchAccuracy;
  final double pitchStability;
  final VibratoAnalysis vibrato;
  final VocalRange? vocalRange;
  final String summary;
  final List<String> suggestions;
  final List<String> strengths;
  final List<String> improvements;
  final List<PitchPoint>? pitchHistory;
  
  VocalFeedback({
    required this.overallScore,
    required this.pitchAccuracy,
    required this.pitchStability,
    required this.vibrato,
    this.vocalRange,
    required this.summary,
    required this.suggestions,
    this.strengths = const [],
    this.improvements = const [],
    this.pitchHistory,
  });
}

// 비브라토 분석
class VibratoAnalysis {
  final bool present;
  final double? rate;
  final double? depth;
  final String? quality;
  
  VibratoAnalysis({
    required this.present,
    this.rate,
    this.depth,
    this.quality,
  });
}

// 음역대 분석
class VocalRange {
  final String lowest;
  final String highest;
  final int rangeInSemitones;
  final double? lowestFreq;
  final double? highestFreq;
  
  VocalRange({
    required this.lowest,
    required this.highest,
    required this.rangeInSemitones,
    this.lowestFreq,
    this.highestFreq,
  });
  
  String get description {
    if (rangeInSemitones >= 24) return '매우 넓은 음역대';
    if (rangeInSemitones >= 18) return '넓은 음역대';
    if (rangeInSemitones >= 12) return '보통 음역대';
    return '좁은 음역대';
  }
}