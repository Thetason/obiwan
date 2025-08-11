import 'dart:typed_data';
import 'dart:math' as math;

/// 리듬 정확도 분석 결과
class RhythmResult {
  final double accuracy;           // 리듬 정확도 (0.0 ~ 1.0)
  final double stability;          // 템포 안정성 (0.0 ~ 1.0)
  final double beatStrength;       // 비트 강도 (0.0 ~ 1.0)
  final double syncopation;        // 싱코페이션 정도 (0.0 ~ 1.0)
  final int estimatedBPM;          // 예상 BPM
  final List<BeatPoint> beats;     // 감지된 비트 포인트들
  final String rhythmPattern;      // 리듬 패턴 (4/4, 3/4 등)
  final String feedback;           // 리듬 피드백 메시지
  
  RhythmResult({
    required this.accuracy,
    required this.stability,
    required this.beatStrength,
    required this.syncopation,
    required this.estimatedBPM,
    required this.beats,
    required this.rhythmPattern,
    required this.feedback,
  });
}

/// 비트 포인트 정보
class BeatPoint {
  final double timeSeconds;  // 비트 시간 (초)
  final double strength;      // 비트 강도 (0.0 ~ 1.0)
  final bool isOnBeat;       // 정박에 맞는지 여부
  final double deviation;     // 정박과의 차이 (ms)
  
  BeatPoint({
    required this.timeSeconds,
    required this.strength,
    required this.isOnBeat,
    required this.deviation,
  });
}

/// 리듬 정확도 분석 서비스
/// 비트 감지, 템포 추정, 리듬 패턴 분석
class RhythmAnalysisService {
  static final RhythmAnalysisService _instance = RhythmAnalysisService._internal();
  factory RhythmAnalysisService() => _instance;
  RhythmAnalysisService._internal();
  
  static RhythmAnalysisService get instance => _instance;
  
  /// 오디오에서 리듬 분석
  Future<RhythmResult> analyzeRhythm(
    Float32List audioData, 
    double sampleRate,
    {int? targetBPM}
  ) async {
    if (audioData.isEmpty) {
      return _getDefaultResult();
    }
    
    // 1. 온셋 감지 (에너지 변화 기반)
    final onsets = _detectOnsets(audioData, sampleRate);
    
    // 2. BPM 추정
    final estimatedBPM = _estimateBPM(onsets, sampleRate);
    
    // 3. 비트 그리드 생성
    final beatGrid = _generateBeatGrid(
      audioData.length / sampleRate,
      targetBPM ?? estimatedBPM,
    );
    
    // 4. 비트 포인트 분석
    final beats = _analyzeBeatPoints(onsets, beatGrid, sampleRate);
    
    // 5. 리듬 메트릭 계산
    final accuracy = _calculateRhythmAccuracy(beats);
    final stability = _calculateTempoStability(beats);
    final beatStrength = _calculateBeatStrength(beats);
    final syncopation = _calculateSyncopation(beats);
    
    // 6. 리듬 패턴 감지
    final rhythmPattern = _detectRhythmPattern(beats);
    
    // 7. 피드백 생성
    final feedback = _generateRhythmFeedback(
      accuracy: accuracy,
      stability: stability,
      beatStrength: beatStrength,
      syncopation: syncopation,
      bpm: estimatedBPM,
      pattern: rhythmPattern,
    );
    
    return RhythmResult(
      accuracy: accuracy,
      stability: stability,
      beatStrength: beatStrength,
      syncopation: syncopation,
      estimatedBPM: estimatedBPM,
      beats: beats,
      rhythmPattern: rhythmPattern,
      feedback: feedback,
    );
  }
  
  /// 온셋 감지 (에너지 변화 기반)
  List<double> _detectOnsets(Float32List audioData, double sampleRate) {
    final onsets = <double>[];
    final windowSize = (sampleRate * 0.01).toInt(); // 10ms 윈도우
    
    // 에너지 계산
    final energy = <double>[];
    for (int i = 0; i < audioData.length - windowSize; i += windowSize) {
      double sum = 0.0;
      for (int j = 0; j < windowSize; j++) {
        sum += audioData[i + j] * audioData[i + j];
      }
      energy.add(sum / windowSize);
    }
    
    // 에너지 변화율 계산
    if (energy.length < 2) return onsets;
    
    for (int i = 1; i < energy.length; i++) {
      final diff = energy[i] - energy[i - 1];
      
      // 에너지가 급격히 증가하는 지점을 온셋으로 감지
      if (diff > 0 && diff > energy[i - 1] * 0.3) {
        final timeSeconds = (i * windowSize) / sampleRate;
        
        // 너무 가까운 온셋은 무시 (최소 50ms 간격)
        if (onsets.isEmpty || timeSeconds - onsets.last > 0.05) {
          onsets.add(timeSeconds);
        }
      }
    }
    
    return onsets;
  }
  
  /// BPM 추정 (온셋 간격 기반)
  int _estimateBPM(List<double> onsets, double sampleRate) {
    if (onsets.length < 4) return 120; // 기본값
    
    // 온셋 간격 계산
    final intervals = <double>[];
    for (int i = 1; i < onsets.length; i++) {
      intervals.add(onsets[i] - onsets[i - 1]);
    }
    
    // 가장 빈번한 간격 찾기 (히스토그램)
    final histogram = <int, int>{};
    for (final interval in intervals) {
      final bpm = (60.0 / interval).round();
      
      // 합리적인 BPM 범위 (60-200)
      if (bpm >= 60 && bpm <= 200) {
        // 10 BPM 단위로 그룹화
        final groupedBPM = (bpm ~/ 10) * 10;
        histogram[groupedBPM] = (histogram[groupedBPM] ?? 0) + 1;
      }
    }
    
    if (histogram.isEmpty) return 120;
    
    // 가장 빈번한 BPM 반환
    int maxCount = 0;
    int estimatedBPM = 120;
    
    histogram.forEach((bpm, count) {
      if (count > maxCount) {
        maxCount = count;
        estimatedBPM = bpm;
      }
    });
    
    return estimatedBPM;
  }
  
  /// 비트 그리드 생성
  List<double> _generateBeatGrid(double duration, int bpm) {
    final beatInterval = 60.0 / bpm; // 비트 간격 (초)
    final beats = <double>[];
    
    double time = 0.0;
    while (time < duration) {
      beats.add(time);
      time += beatInterval;
    }
    
    return beats;
  }
  
  /// 비트 포인트 분석
  List<BeatPoint> _analyzeBeatPoints(
    List<double> onsets,
    List<double> beatGrid,
    double sampleRate,
  ) {
    final beats = <BeatPoint>[];
    
    // 각 온셋에 대해 가장 가까운 비트 찾기
    for (final onset in onsets) {
      double minDistance = double.infinity;
      double closestBeat = 0.0;
      
      for (final gridBeat in beatGrid) {
        final distance = (onset - gridBeat).abs();
        if (distance < minDistance) {
          minDistance = distance;
          closestBeat = gridBeat;
        }
      }
      
      // 편차 계산 (밀리초)
      final deviation = (onset - closestBeat) * 1000;
      
      // 정박 판정 (±50ms 이내)
      final isOnBeat = deviation.abs() < 50;
      
      // 비트 강도 (편차가 작을수록 강함)
      final strength = math.max(0, 1.0 - (deviation.abs() / 100));
      
      beats.add(BeatPoint(
        timeSeconds: onset,
        strength: strength,
        isOnBeat: isOnBeat,
        deviation: deviation,
      ));
    }
    
    return beats;
  }
  
  /// 리듬 정확도 계산
  double _calculateRhythmAccuracy(List<BeatPoint> beats) {
    if (beats.isEmpty) return 0.0;
    
    int onBeatCount = 0;
    double totalStrength = 0.0;
    
    for (final beat in beats) {
      if (beat.isOnBeat) onBeatCount++;
      totalStrength += beat.strength;
    }
    
    // 정박 비율과 평균 강도의 조합
    final onBeatRatio = onBeatCount / beats.length;
    final avgStrength = totalStrength / beats.length;
    
    return (onBeatRatio * 0.7 + avgStrength * 0.3).clamp(0.0, 1.0);
  }
  
  /// 템포 안정성 계산
  double _calculateTempoStability(List<BeatPoint> beats) {
    if (beats.length < 3) return 1.0;
    
    // 비트 간격 계산
    final intervals = <double>[];
    for (int i = 1; i < beats.length; i++) {
      intervals.add(beats[i].timeSeconds - beats[i - 1].timeSeconds);
    }
    
    // 간격의 표준편차 계산
    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    double variance = 0.0;
    
    for (final interval in intervals) {
      variance += math.pow(interval - mean, 2);
    }
    
    final stdDev = math.sqrt(variance / intervals.length);
    
    // 변동계수 (CV) 기반 안정성 (낮을수록 안정적)
    final cv = stdDev / mean;
    
    return math.max(0, 1.0 - cv * 5).clamp(0.0, 1.0);
  }
  
  /// 비트 강도 계산
  double _calculateBeatStrength(List<BeatPoint> beats) {
    if (beats.isEmpty) return 0.0;
    
    double totalStrength = 0.0;
    for (final beat in beats) {
      totalStrength += beat.strength;
    }
    
    return (totalStrength / beats.length).clamp(0.0, 1.0);
  }
  
  /// 싱코페이션 정도 계산
  double _calculateSyncopation(List<BeatPoint> beats) {
    if (beats.isEmpty) return 0.0;
    
    int offBeatCount = 0;
    for (final beat in beats) {
      // 정박에서 벗어난 비트 카운트
      if (!beat.isOnBeat && beat.strength > 0.3) {
        offBeatCount++;
      }
    }
    
    return (offBeatCount / beats.length).clamp(0.0, 1.0);
  }
  
  /// 리듬 패턴 감지
  String _detectRhythmPattern(List<BeatPoint> beats) {
    if (beats.length < 8) return "Unknown";
    
    // 간단한 패턴 감지 (비트 간격 기반)
    final intervals = <double>[];
    for (int i = 1; i < math.min(8, beats.length); i++) {
      intervals.add(beats[i].timeSeconds - beats[i - 1].timeSeconds);
    }
    
    // 평균 간격
    final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    
    // 패턴 추정 (간격의 규칙성 기반)
    bool isRegular = true;
    for (final interval in intervals) {
      if ((interval - avgInterval).abs() > avgInterval * 0.2) {
        isRegular = false;
        break;
      }
    }
    
    if (isRegular) {
      // BPM 기반 박자 추정
      final bpm = 60.0 / avgInterval;
      if (bpm > 140) return "Fast 4/4";
      if (bpm > 100) return "Moderate 4/4";
      if (bpm > 70) return "Slow 4/4";
      return "Ballad";
    } else {
      // 불규칙한 패턴
      return "Complex/Syncopated";
    }
  }
  
  /// 리듬 피드백 생성
  String _generateRhythmFeedback({
    required double accuracy,
    required double stability,
    required double beatStrength,
    required double syncopation,
    required int bpm,
    required String pattern,
  }) {
    final feedback = StringBuffer();
    
    feedback.writeln('🥁 리듬 분석 결과:');
    feedback.writeln('• 템포: ${bpm} BPM');
    feedback.writeln('• 패턴: $pattern');
    
    // 정확도 피드백
    if (accuracy > 0.8) {
      feedback.writeln('✅ 리듬이 매우 정확합니다!');
    } else if (accuracy > 0.6) {
      feedback.writeln('👍 리듬이 대체로 정확합니다.');
    } else {
      feedback.writeln('⚠️ 리듬 정확도를 개선해보세요.');
    }
    
    // 안정성 피드백
    if (stability > 0.8) {
      feedback.writeln('• 템포가 일정하게 유지되고 있습니다.');
    } else if (stability < 0.5) {
      feedback.writeln('• 템포가 불안정합니다. 메트로놈 연습을 추천합니다.');
    }
    
    // 비트 강도 피드백
    if (beatStrength < 0.5) {
      feedback.writeln('• 박자를 더 명확하게 표현해보세요.');
    }
    
    // 싱코페이션 피드백
    if (syncopation > 0.3) {
      feedback.writeln('• 싱코페이션이 감지됩니다. 의도적이라면 좋습니다!');
    }
    
    // 개선 제안
    if (accuracy < 0.7 || stability < 0.7) {
      feedback.writeln('\n💡 개선 팁:');
      if (accuracy < 0.7) {
        feedback.writeln('  - 메트로놈과 함께 연습하세요');
        feedback.writeln('  - 천천히 시작해서 점차 템포를 높이세요');
      }
      if (stability < 0.7) {
        feedback.writeln('  - 일정한 템포 유지에 집중하세요');
        feedback.writeln('  - 발 구르기나 손뼉으로 박자를 익히세요');
      }
    }
    
    return feedback.toString();
  }
  
  /// 기본 결과 반환
  RhythmResult _getDefaultResult() {
    return RhythmResult(
      accuracy: 0.0,
      stability: 0.0,
      beatStrength: 0.0,
      syncopation: 0.0,
      estimatedBPM: 120,
      beats: [],
      rhythmPattern: 'Unknown',
      feedback: '리듬 분석 불가',
    );
  }
  
  /// 메트로놈과 비교 분석
  Future<RhythmResult> compareWithMetronome(
    Float32List audioData,
    double sampleRate,
    int targetBPM,
    {int beatsPerMeasure = 4}
  ) async {
    // 기본 리듬 분석 수행
    final result = await analyzeRhythm(audioData, sampleRate, targetBPM: targetBPM);
    
    // 메트로놈 기준 추가 분석
    final expectedBeatInterval = 60.0 / targetBPM;
    final duration = audioData.length / sampleRate;
    final expectedBeats = (duration / expectedBeatInterval).floor();
    
    // 놓친 비트 계산
    final missedBeats = math.max(0, expectedBeats - result.beats.length);
    final missRate = missedBeats / expectedBeats;
    
    // 피드백 업데이트
    String enhancedFeedback = result.feedback;
    if (missRate > 0.1) {
      enhancedFeedback += '\n⚠️ ${(missRate * 100).toStringAsFixed(0)}%의 비트를 놓쳤습니다.';
    }
    
    return RhythmResult(
      accuracy: result.accuracy * (1 - missRate * 0.5),
      stability: result.stability,
      beatStrength: result.beatStrength,
      syncopation: result.syncopation,
      estimatedBPM: result.estimatedBPM,
      beats: result.beats,
      rhythmPattern: result.rhythmPattern,
      feedback: enhancedFeedback,
    );
  }
}