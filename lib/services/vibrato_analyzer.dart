import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../utils/pitch_color_system.dart';

/// 🎵 오비완 v3.3 - 고급 비브라토 분석기
/// 
/// CREPE/SPICE 피치 데이터를 기반으로 정밀한 비브라토 분석을 수행합니다.
/// - 비브라토 속도 (rate): 초당 진동 횟수 (4-8Hz가 정상)
/// - 비브라토 깊이 (depth): 음정 변화폭 (센트 단위)
/// - 비브라토 규칙성 (regularity): 일정함 정도
/// 
/// NO DUMMY DATA 원칙: 모든 분석은 실제 CREPE/SPICE 데이터만 사용
class VibratoAnalyzer {
  // === 분석 매개변수 ===
  static const int _minDataPoints = 15;        // 최소 분석 데이터 개수
  static const int _maxHistorySize = 50;       // 최대 히스토리 유지 개수
  static const double _normalVibratoRateMin = 4.0;  // 정상 비브라토 최소 속도 (Hz)
  static const double _normalVibratoRateMax = 8.0;  // 정상 비브라토 최대 속도 (Hz)
  static const double _minVibratoDepth = 10.0;      // 최소 비브라토 깊이 (cents)
  static const double _maxVibratoDepth = 200.0;     // 최대 비브라토 깊이 (cents)
  static const double _confidenceThreshold = 0.6;   // 신뢰할 수 있는 피치 임계값

  // === 내부 상태 ===
  final List<VibratoDataPoint> _pitchHistory = [];
  int _analysisCount = 0;

  /// 🎯 실시간 비브라토 분석
  /// 
  /// CREPE/SPICE에서 받은 실제 피치 데이터를 기반으로 비브라토를 분석합니다.
  /// [pitchData]: 실제 피치 측정 데이터 (PitchData 객체)
  /// 
  /// Returns: 비브라토 분석 결과 (VibratoAnalysisResult)
  VibratoAnalysisResult analyzeVibrato(PitchData pitchData) {
    _analysisCount++;
    
    // 신뢰할 수 없는 데이터는 제외
    if (pitchData.confidence < _confidenceThreshold || pitchData.frequency <= 0) {
      debugPrint('🚨 [VibratoAnalyzer] 신뢰도 낮은 데이터 제외: confidence=${pitchData.confidence.toStringAsFixed(2)}, freq=${pitchData.frequency.toStringAsFixed(1)}Hz');
      return VibratoAnalysisResult.insufficient();
    }

    // 피치 데이터를 히스토리에 추가
    _addPitchData(pitchData);

    // 충분한 데이터가 쌓이지 않았으면 분석 불가
    if (_pitchHistory.length < _minDataPoints) {
      debugPrint('📊 [VibratoAnalyzer] 데이터 수집 중: ${_pitchHistory.length}/$_minDataPoints');
      return VibratoAnalysisResult.insufficient();
    }

    // 실제 비브라토 분석 수행
    return _performVibratoAnalysis();
  }

  /// 히스토리에 피치 데이터 추가
  void _addPitchData(PitchData pitchData) {
    final dataPoint = VibratoDataPoint(
      timestamp: pitchData.timestamp.millisecondsSinceEpoch / 1000.0,
      frequency: pitchData.frequency,
      confidence: pitchData.confidence,
      amplitude: pitchData.amplitude,
    );

    _pitchHistory.add(dataPoint);

    // 히스토리 크기 제한
    if (_pitchHistory.length > _maxHistorySize) {
      _pitchHistory.removeAt(0);
    }
  }

  /// 🔬 핵심 비브라토 분석 로직
  VibratoAnalysisResult _performVibratoAnalysis() {
    debugPrint('🎵 [VibratoAnalyzer] 비브라토 분석 시작 (데이터 개수: ${_pitchHistory.length})');

    // 1. 피치 변화 추세 제거 (detrending)
    final detrendedFrequencies = _removeTrend(_pitchHistory);
    
    // 2. 비브라토 속도 분석 (주기 검출)
    final vibratoRate = _calculateVibratoRate(detrendedFrequencies);
    
    // 3. 비브라토 깊이 분석 (주파수 변화폭)
    final vibratoDepth = _calculateVibratoDepth(detrendedFrequencies);
    
    // 4. 비브라토 규칙성 분석 (주기성 평가)
    final regularity = _calculateRegularity(detrendedFrequencies);
    
    // 5. 전체적인 비브라토 품질 평가
    final quality = _evaluateVibratoQuality(vibratoRate, vibratoDepth, regularity);

    // 비브라토 존재 여부 판정
    final isVibratoPresent = _isVibratoPresent(vibratoRate, vibratoDepth);

    final result = VibratoAnalysisResult(
      isPresent: isVibratoPresent,
      rate: vibratoRate,
      depth: vibratoDepth,
      regularity: regularity,
      quality: quality,
      confidenceLevel: _calculateConfidenceLevel(),
      analysisTimestamp: DateTime.now(),
    );

    debugPrint('🎯 [VibratoAnalyzer] 분석 완료: ${result.toString()}');
    return result;
  }

  /// 피치 데이터에서 추세 제거 (Linear Detrending)
  List<double> _removeTrend(List<VibratoDataPoint> data) {
    if (data.length < 3) return data.map((d) => d.frequency).toList();

    final frequencies = data.map((d) => d.frequency).toList();
    final timestamps = data.map((d) => d.timestamp).toList();

    // 선형 회귀로 추세선 계산
    final n = data.length;
    final sumX = timestamps.reduce((a, b) => a + b);
    final sumY = frequencies.reduce((a, b) => a + b);
    final sumXY = List.generate(n, (i) => timestamps[i] * frequencies[i]).reduce((a, b) => a + b);
    final sumX2 = timestamps.map((x) => x * x).reduce((a, b) => a + b);

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    // 추세 제거
    return List.generate(n, (i) {
      final trend = slope * timestamps[i] + intercept;
      return frequencies[i] - trend;
    });
  }

  /// 🌊 비브라토 속도 계산 (Hz)
  /// 
  /// Zero-crossing 방법과 Peak detection을 결합하여 정확한 주기 검출
  double _calculateVibratoRate(List<double> detrendedData) {
    if (detrendedData.length < _minDataPoints) return 0.0;

    // Zero-crossing 검출
    final zeroCrossings = _findZeroCrossings(detrendedData);
    
    // Peak/Valley 검출
    final extrema = _findExtrema(detrendedData);

    if (zeroCrossings.length < 4 && extrema.length < 4) {
      debugPrint('📊 [VibratoAnalyzer] 주기성 부족: crossings=${zeroCrossings.length}, extrema=${extrema.length}');
      return 0.0;
    }

    // 시간 범위 계산
    final timeSpan = _pitchHistory.last.timestamp - _pitchHistory.first.timestamp;
    if (timeSpan <= 0.1) return 0.0; // 너무 짧은 시간

    // 두 방법의 결과를 결합하여 더 정확한 주기 계산
    double rate1 = 0.0, rate2 = 0.0;

    if (zeroCrossings.length >= 4) {
      final cycles1 = zeroCrossings.length / 2.0; // 반주기 개수를 주기로 변환
      rate1 = cycles1 / timeSpan;
    }

    if (extrema.length >= 4) {
      final cycles2 = extrema.length / 2.0; // Peak-Valley 쌍을 주기로 변환
      rate2 = cycles2 / timeSpan;
    }

    // 두 방법의 평균값 사용 (더 안정적)
    final finalRate = (rate1 > 0 && rate2 > 0) ? (rate1 + rate2) / 2.0 : math.max(rate1, rate2);

    debugPrint('🌊 [VibratoAnalyzer] 비브라토 속도: ${finalRate.toStringAsFixed(2)}Hz (crossings=${rate1.toStringAsFixed(2)}, extrema=${rate2.toStringAsFixed(2)})');
    return finalRate;
  }

  /// Zero-crossing 지점 찾기
  List<int> _findZeroCrossings(List<double> data) {
    final crossings = <int>[];
    final mean = data.reduce((a, b) => a + b) / data.length;
    
    for (int i = 1; i < data.length; i++) {
      final prev = data[i - 1] - mean;
      final curr = data[i] - mean;
      
      if ((prev > 0 && curr <= 0) || (prev <= 0 && curr > 0)) {
        crossings.add(i);
      }
    }
    
    return crossings;
  }

  /// Peak/Valley 극값 찾기
  List<int> _findExtrema(List<double> data) {
    final extrema = <int>[];
    
    for (int i = 1; i < data.length - 1; i++) {
      final prev = data[i - 1];
      final curr = data[i];
      final next = data[i + 1];
      
      // Peak 또는 Valley 검출
      if ((curr > prev && curr > next) || (curr < prev && curr < next)) {
        extrema.add(i);
      }
    }
    
    return extrema;
  }

  /// 📏 비브라토 깊이 계산 (cents)
  /// 
  /// 주파수 변화폭을 cents 단위로 변환
  double _calculateVibratoDepth(List<double> detrendedData) {
    if (detrendedData.isEmpty) return 0.0;

    final maxFreq = detrendedData.reduce(math.max);
    final minFreq = detrendedData.reduce(math.min);
    final range = maxFreq - minFreq;

    // 중심 주파수 계산
    final baseFrequency = _pitchHistory.map((d) => d.frequency).reduce((a, b) => a + b) / _pitchHistory.length;
    
    if (baseFrequency <= 0 || range <= 0) return 0.0;

    // 주파수 변화를 cents로 변환
    // 1 cent = 1/100 semitone = 1200 * log2(f2/f1) cents
    final depth = 1200 * math.log(1 + range / baseFrequency) / math.ln2;

    debugPrint('📏 [VibratoAnalyzer] 비브라토 깊이: ${depth.toStringAsFixed(1)} cents (range=${range.toStringAsFixed(2)}Hz, base=${baseFrequency.toStringAsFixed(1)}Hz)');
    return depth;
  }

  /// 📊 비브라토 규칙성 계산 (0.0 ~ 1.0)
  /// 
  /// 주기의 일관성을 평가
  double _calculateRegularity(List<double> detrendedData) {
    if (detrendedData.length < _minDataPoints) return 0.0;

    // 자기상관함수(Autocorrelation)를 이용한 주기성 분석
    final autocorr = _calculateAutocorrelation(detrendedData);
    
    // 가장 강한 주기 신호 찾기
    double maxCorr = 0.0;
    int bestLag = 0;
    
    for (int lag = 2; lag < autocorr.length ~/ 3; lag++) {
      if (autocorr[lag] > maxCorr) {
        maxCorr = autocorr[lag];
        bestLag = lag;
      }
    }

    // 주기성 강도를 규칙성으로 변환
    final regularity = math.max(0.0, math.min(1.0, maxCorr));

    debugPrint('📊 [VibratoAnalyzer] 규칙성: ${regularity.toStringAsFixed(3)} (maxCorr=${maxCorr.toStringAsFixed(3)}, lag=$bestLag)');
    return regularity;
  }

  /// 자기상관함수 계산
  List<double> _calculateAutocorrelation(List<double> data) {
    final n = data.length;
    final autocorr = List<double>.filled(n, 0.0);
    
    for (int lag = 0; lag < n; lag++) {
      double sum = 0.0;
      int count = 0;
      
      for (int i = 0; i < n - lag; i++) {
        sum += data[i] * data[i + lag];
        count++;
      }
      
      autocorr[lag] = count > 0 ? sum / count : 0.0;
    }
    
    // 정규화
    if (autocorr[0] > 0) {
      for (int i = 0; i < n; i++) {
        autocorr[i] /= autocorr[0];
      }
    }
    
    return autocorr;
  }

  /// 🏆 비브라토 품질 평가
  VibratoQuality _evaluateVibratoQuality(double rate, double depth, double regularity) {
    // 이상적인 비브라토 매개변수
    const idealRate = 6.0;      // Hz
    const idealDepth = 50.0;    // cents
    const minRegularity = 0.6;  // 최소 규칙성

    // 각 매개변수별 점수 계산
    final rateScore = _calculateParameterScore(rate, idealRate, 2.0);
    final depthScore = _calculateParameterScore(depth, idealDepth, 20.0);
    final regularityScore = regularity;

    // 가중 평균 점수
    final overallScore = (rateScore * 0.3 + depthScore * 0.3 + regularityScore * 0.4);

    debugPrint('🏆 [VibratoAnalyzer] 품질 평가: overall=${overallScore.toStringAsFixed(3)}, rate=${rateScore.toStringAsFixed(3)}, depth=${depthScore.toStringAsFixed(3)}, reg=${regularityScore.toStringAsFixed(3)}');

    // 품질 등급 결정
    if (overallScore >= 0.85 && regularity >= minRegularity) {
      return VibratoQuality.excellent;
    } else if (overallScore >= 0.7 && regularity >= minRegularity * 0.9) {
      return VibratoQuality.good;
    } else if (overallScore >= 0.5 && regularity >= minRegularity * 0.7) {
      return VibratoQuality.fair;
    } else if (overallScore >= 0.3) {
      return VibratoQuality.poor;
    } else {
      return VibratoQuality.none;
    }
  }

  /// 매개변수별 점수 계산 (가우시안 분포 기반)
  double _calculateParameterScore(double actual, double ideal, double tolerance) {
    final diff = (actual - ideal).abs();
    return math.exp(-math.pow(diff / tolerance, 2));
  }

  /// 비브라토 존재 여부 판정
  bool _isVibratoPresent(double rate, double depth) {
    final rateOk = rate >= _normalVibratoRateMin && rate <= _normalVibratoRateMax;
    final depthOk = depth >= _minVibratoDepth && depth <= _maxVibratoDepth;
    
    return rateOk && depthOk;
  }

  /// 분석 신뢰도 계산
  double _calculateConfidenceLevel() {
    if (_pitchHistory.isEmpty) return 0.0;
    
    final avgConfidence = _pitchHistory.map((d) => d.confidence).reduce((a, b) => a + b) / _pitchHistory.length;
    final dataQuality = math.min(1.0, _pitchHistory.length / _maxHistorySize);
    
    return (avgConfidence + dataQuality) / 2.0;
  }

  /// 🧹 히스토리 초기화
  void clearHistory() {
    _pitchHistory.clear();
    _analysisCount = 0;
    debugPrint('🧹 [VibratoAnalyzer] 히스토리 초기화 완료');
  }

  /// 📈 분석 통계 정보
  VibratoAnalysisStats getAnalysisStats() {
    return VibratoAnalysisStats(
      totalAnalysisCount: _analysisCount,
      currentDataPoints: _pitchHistory.length,
      avgConfidence: _pitchHistory.isEmpty ? 0.0 : 
          _pitchHistory.map((d) => d.confidence).reduce((a, b) => a + b) / _pitchHistory.length,
      timeSpan: _pitchHistory.isEmpty ? 0.0 : 
          _pitchHistory.last.timestamp - _pitchHistory.first.timestamp,
    );
  }
}

/// 🎵 비브라토 데이터 포인트
class VibratoDataPoint {
  final double timestamp;    // 시간 (초)
  final double frequency;    // 주파수 (Hz)
  final double confidence;   // 신뢰도 (0.0 ~ 1.0)
  final double amplitude;    // 음량

  const VibratoDataPoint({
    required this.timestamp,
    required this.frequency,
    required this.confidence,
    required this.amplitude,
  });
}

/// 🎯 비브라토 분석 결과
class VibratoAnalysisResult {
  final bool isPresent;              // 비브라토 감지 여부
  final double rate;                 // 비브라토 속도 (Hz)
  final double depth;                // 비브라토 깊이 (cents)
  final double regularity;           // 규칙성 (0.0 ~ 1.0)
  final VibratoQuality quality;      // 품질 등급
  final double confidenceLevel;      // 분석 신뢰도
  final DateTime analysisTimestamp;  // 분석 시간

  const VibratoAnalysisResult({
    required this.isPresent,
    required this.rate,
    required this.depth,
    required this.regularity,
    required this.quality,
    required this.confidenceLevel,
    required this.analysisTimestamp,
  });

  /// 분석 데이터 부족
  const VibratoAnalysisResult.insufficient()
      : isPresent = false,
        rate = 0.0,
        depth = 0.0,
        regularity = 0.0,
        quality = VibratoQuality.none,
        confidenceLevel = 0.0,
        analysisTimestamp = const DateTime.fromMillisecondsSinceEpoch(0);

  /// 비브라토 강도 (0.0 ~ 1.0)
  double get intensity {
    if (!isPresent) return 0.0;
    return math.min(1.0, depth / 100.0); // 100 cents를 최대로 정규화
  }

  /// 비브라토 상태 설명
  String get statusDescription {
    if (!isPresent) return '비브라토 없음';
    
    final rateDesc = rate < 5.0 ? '느린' : rate > 7.0 ? '빠른' : '적절한';
    final depthDesc = depth < 30.0 ? '얕은' : depth > 80.0 ? '깊은' : '적절한';
    
    return '$rateDesc 속도 (${rate.toStringAsFixed(1)}Hz), $depthDesc 깊이 (${depth.toStringAsFixed(0)} cents)';
  }

  /// 성능 피드백 메시지
  String get feedback {
    switch (quality) {
      case VibratoQuality.excellent:
        return '완벽한 비브라토입니다! 🎵✨';
      case VibratoQuality.good:
        return '좋은 비브라토입니다. 조금 더 일정하게 유지해보세요.';
      case VibratoQuality.fair:
        return '비브라토가 감지되었습니다. 속도와 깊이를 조절해보세요.';
      case VibratoQuality.poor:
        return '비브라토 연습이 필요합니다. 일정한 떨림을 만들어보세요.';
      case VibratoQuality.none:
        return '비브라토가 감지되지 않았습니다.';
    }
  }

  @override
  String toString() {
    return 'VibratoResult(present=$isPresent, rate=${rate.toStringAsFixed(1)}Hz, depth=${depth.toStringAsFixed(1)}cents, quality=$quality, confidence=${confidenceLevel.toStringAsFixed(2)})';
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

/// 📊 분석 통계 정보
class VibratoAnalysisStats {
  final int totalAnalysisCount;    // 총 분석 횟수
  final int currentDataPoints;     // 현재 데이터 포인트 수
  final double avgConfidence;      // 평균 신뢰도
  final double timeSpan;           // 분석 시간 범위 (초)

  const VibratoAnalysisStats({
    required this.totalAnalysisCount,
    required this.currentDataPoints,
    required this.avgConfidence,
    required this.timeSpan,
  });

  @override
  String toString() {
    return 'VibratoStats(count=$totalAnalysisCount, points=$currentDataPoints, confidence=${avgConfidence.toStringAsFixed(2)}, span=${timeSpan.toStringAsFixed(1)}s)';
  }
}