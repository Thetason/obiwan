import 'dart:math' as math;
import 'pitch_color_system.dart';

/// 🎵 비브라토 분석기
/// 
/// 실시간으로 목소리의 비브라토(떨림)를 감지하고 분석합니다.
/// 비브라토는 음정의 주기적인 변화로 감지됩니다.
class VibratoAnalyzer {
  
  // 분석 설정
  static const int _windowSize = 10;        // 분석 윈도우 크기
  static const double _minVibratoRate = 4.0;  // 최소 비브라토 속도 (Hz)
  static const double _maxVibratoRate = 8.0;  // 최대 비브라토 속도 (Hz)
  static const double _minVibratoDepth = 0.2; // 최소 비브라토 깊이 (semitone)
  
  // 상태 관리
  final List<double> _frequencyHistory = [];
  final List<double> _timeHistory = [];
  final List<double> _amplitudeHistory = [];
  
  /// 🎯 비브라토 분석 결과
  VibratoResult analyzeVibrato(PitchData pitchData) {
    _addToHistory(pitchData);
    
    if (_frequencyHistory.length < _windowSize) {
      return VibratoResult.none();
    }
    
    // 주파수 변화 패턴 분석
    final vibratoRate = _calculateVibratoRate();
    final vibratoDepth = _calculateVibratoDepth();
    final regularity = _calculateRegularity();
    
    // 비브라토 감지 임계값 확인
    final isVibrato = vibratoRate >= _minVibratoRate &&
                      vibratoRate <= _maxVibratoRate &&
                      vibratoDepth >= _minVibratoDepth;
    
    if (!isVibrato) {
      return VibratoResult.none();
    }
    
    // 비브라토 품질 평가
    final quality = _evaluateVibratoQuality(vibratoRate, vibratoDepth, regularity);
    
    return VibratoResult(
      isPresent: true,
      rate: vibratoRate,
      depth: vibratoDepth,
      regularity: regularity,
      quality: quality,
    );
  }
  
  void _addToHistory(PitchData pitchData) {
    _frequencyHistory.add(pitchData.frequency);
    _timeHistory.add(pitchData.timestamp.millisecondsSinceEpoch / 1000.0);
    _amplitudeHistory.add(pitchData.amplitude);
    
    // 윈도우 크기 유지
    if (_frequencyHistory.length > _windowSize) {
      _frequencyHistory.removeAt(0);
      _timeHistory.removeAt(0);
      _amplitudeHistory.removeAt(0);
    }
  }
  
  /// 비브라토 속도 계산 (Hz)
  double _calculateVibratoRate() {
    if (_frequencyHistory.length < _windowSize) return 0.0;
    
    // 주파수 변화의 극값 찾기 (peak detection)
    final peaks = <int>[];
    final valleys = <int>[];
    
    for (int i = 1; i < _frequencyHistory.length - 1; i++) {
      final prev = _frequencyHistory[i - 1];
      final curr = _frequencyHistory[i];
      final next = _frequencyHistory[i + 1];
      
      if (curr > prev && curr > next) {
        peaks.add(i);
      } else if (curr < prev && curr < next) {
        valleys.add(i);
      }
    }
    
    if (peaks.length < 2 && valleys.length < 2) return 0.0;
    
    // 주기 계산
    final cycles = math.max(peaks.length - 1, valleys.length - 1);
    if (cycles <= 0) return 0.0;
    
    final timeDuration = _timeHistory.last - _timeHistory.first;
    return cycles / timeDuration;
  }
  
  /// 비브라토 깊이 계산 (semitone)
  double _calculateVibratoDepth() {
    if (_frequencyHistory.isEmpty) return 0.0;
    
    final maxFreq = _frequencyHistory.reduce(math.max);
    final minFreq = _frequencyHistory.reduce(math.min);
    
    if (minFreq <= 0) return 0.0;
    
    // 주파수 비율을 semitone으로 변환
    return 12 * math.log(maxFreq / minFreq) / math.ln2;
  }
  
  /// 비브라토 규칙성 계산 (0.0 ~ 1.0)
  double _calculateRegularity() {
    if (_frequencyHistory.length < _windowSize) return 0.0;
    
    // 주파수 변화의 표준편차 계산
    final mean = _frequencyHistory.reduce((a, b) => a + b) / _frequencyHistory.length;
    final variance = _frequencyHistory
        .map((f) => math.pow(f - mean, 2))
        .reduce((a, b) => a + b) / _frequencyHistory.length;
    final stdDev = math.sqrt(variance);
    
    // 변화의 일관성 평가 (낮은 표준편차 = 높은 규칙성)
    final maxExpectedStdDev = mean * 0.05; // 5% 변화 허용
    return math.max(0.0, 1.0 - (stdDev / maxExpectedStdDev));
  }
  
  /// 비브라토 품질 평가
  VibratoQuality _evaluateVibratoQuality(double rate, double depth, double regularity) {
    // 이상적인 비브라토 범위
    const idealRate = 6.0;      // Hz
    const idealDepth = 0.5;     // semitone
    const minRegularity = 0.7;  // 최소 규칙성
    
    // 속도 점수
    final rateScore = 1.0 - math.min(1.0, (rate - idealRate).abs() / 2.0);
    
    // 깊이 점수  
    final depthScore = 1.0 - math.min(1.0, (depth - idealDepth).abs() / 0.3);
    
    // 규칙성 점수
    final regularityScore = math.max(0.0, regularity);
    
    // 전체 품질 계산
    final overallScore = (rateScore + depthScore + regularityScore) / 3.0;
    
    if (overallScore >= 0.8 && regularity >= minRegularity) {
      return VibratoQuality.excellent;
    } else if (overallScore >= 0.6 && regularity >= minRegularity * 0.8) {
      return VibratoQuality.good;
    } else if (overallScore >= 0.4) {
      return VibratoQuality.fair;
    } else {
      return VibratoQuality.poor;
    }
  }
  
  /// 히스토리 클리어
  void clearHistory() {
    _frequencyHistory.clear();
    _timeHistory.clear();
    _amplitudeHistory.clear();
  }
}

/// 🎭 비브라토 분석 결과
class VibratoResult {
  final bool isPresent;         // 비브라토 감지 여부
  final double rate;            // 비브라토 속도 (Hz)
  final double depth;           // 비브라토 깊이 (semitone)
  final double regularity;      // 규칙성 (0.0 ~ 1.0)
  final VibratoQuality quality; // 품질 등급
  
  const VibratoResult({
    required this.isPresent,
    required this.rate,
    required this.depth,
    required this.regularity,
    required this.quality,
  });
  
  /// 비브라토 없음
  const VibratoResult.none()
      : isPresent = false,
        rate = 0.0,
        depth = 0.0,
        regularity = 0.0,
        quality = VibratoQuality.none;
  
  /// 비브라토 강도 (0.0 ~ 1.0)
  double get intensity {
    if (!isPresent) return 0.0;
    return math.min(1.0, depth / 1.0); // 1 semitone을 최대로 정규화
  }
  
  /// 비브라토 설명 텍스트
  String get description {
    if (!isPresent) return '비브라토 없음';
    
    final rateDesc = rate < 5.0 ? '느린' : rate > 7.0 ? '빠른' : '적당한';
    final depthDesc = depth < 0.3 ? '얕은' : depth > 0.7 ? '깊은' : '적당한';
    
    return '$rateDesc 속도, $depthDesc 깊이의 ${quality.description}';
  }
}

/// 🏆 비브라토 품질 등급
enum VibratoQuality {
  none('없음'),
  poor('부족함'),
  fair('보통'),
  good('좋음'),
  excellent('훌륭함');
  
  const VibratoQuality(this.description);
  final String description;
}

/// 🌟 호흡법 분석기 (추가 기능)
class BreathingAnalyzer {
  final List<double> _amplitudeHistory = [];
  static const int _windowSize = 20;
  
  /// 호흡 패턴 분석
  BreathingResult analyzeBreathing(List<PitchData> pitchHistory) {
    if (pitchHistory.length < _windowSize) {
      return BreathingResult.insufficient();
    }
    
    // 최근 데이터만 사용
    final recentData = pitchHistory.sublist(
      math.max(0, pitchHistory.length - _windowSize),
    );
    
    // 진폭 안정성 분석
    final amplitudes = recentData.map((p) => p.amplitude).toList();
    final stability = _calculateAmplitudeStability(amplitudes);
    
    // 호흡 지속성 분석  
    final sustainability = _calculateSustainability(recentData);
    
    // 전체 호흡 품질
    final quality = (stability + sustainability) / 2.0;
    
    return BreathingResult(
      stability: stability,
      sustainability: sustainability,
      quality: quality,
    );
  }
  
  double _calculateAmplitudeStability(List<double> amplitudes) {
    if (amplitudes.isEmpty) return 0.0;
    
    final mean = amplitudes.reduce((a, b) => a + b) / amplitudes.length;
    final variance = amplitudes
        .map((a) => math.pow(a - mean, 2))
        .reduce((a, b) => a + b) / amplitudes.length;
    final stdDev = math.sqrt(variance);
    
    // 낮은 표준편차 = 높은 안정성
    return math.max(0.0, 1.0 - stdDev);
  }
  
  double _calculateSustainability(List<PitchData> pitchData) {
    // 음성 지속 시간과 일관성 평가
    final voicedCount = pitchData.where((p) => p.confidence > 0.5).length;
    return voicedCount / pitchData.length;
  }
}

/// 🫁 호흡 분석 결과
class BreathingResult {
  final double stability;      // 안정성 (0.0 ~ 1.0)
  final double sustainability; // 지속성 (0.0 ~ 1.0)
  final double quality;        // 전체 품질 (0.0 ~ 1.0)
  
  const BreathingResult({
    required this.stability,
    required this.sustainability,
    required this.quality,
  });
  
  const BreathingResult.insufficient()
      : stability = 0.0,
        sustainability = 0.0,
        quality = 0.0;
  
  String get feedback {
    if (quality >= 0.8) {
      return '호흡이 매우 안정적입니다! 👏';
    } else if (quality >= 0.6) {
      return '좋은 호흡 패턴이에요. 조금 더 일정하게 유지해보세요.';
    } else if (quality >= 0.4) {
      return '호흡을 더 깊고 일정하게 해보세요. 🫁';
    } else {
      return '복식호흡을 연습해보세요. 배로 숨을 쉬어보세요.';
    }
  }
}