import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:collection';

/// Pitch Smoothing Service
/// Median 필터 + Viterbi 경로 최적화로 안정적인 피치 추적
class PitchSmoothingService {
  // 스무딩 파라미터
  static const int kMedianFilterSize = 5;
  static const int kMovingAverageSize = 3;
  static const double kViterbiTransitionCost = 50.0; // cents
  static const double kOctaveJumpThreshold = 600.0; // cents
  static const double kConfidenceWeight = 0.3;
  
  // 비터비 파라미터
  static const int kViterbiBeamWidth = 5;
  static const int kViterbiHistorySize = 30;
  static const double kSemitoneInCents = 100.0;
  
  // 비브라토 감지 파라미터
  static const double kVibratoMinRate = 4.0; // Hz
  static const double kVibratoMaxRate = 8.0; // Hz
  static const double kVibratoMinExtent = 20.0; // cents
  
  // 버퍼
  final Queue<double> _medianBuffer = Queue<double>();
  final Queue<double> _averageBuffer = Queue<double>();
  final List<ViterbiNode> _viterbiPath = [];
  final Queue<PitchFrame> _pitchHistory = Queue<PitchFrame>();
  
  // 통계
  int _totalFrames = 0;
  int _jumpCount = 0;
  int _smoothedFrames = 0;
  double _averageConfidence = 0.0;
  
  // 비브라토 상태
  bool _vibratoDetected = false;
  double _vibratoRate = 0.0;
  double _vibratoExtent = 0.0;
  
  /// 초기화
  void initialize() {
    print('🎵 피치 스무딩 서비스 초기화');
    reset();
  }
  
  /// 메인 스무딩 처리
  SmoothedPitch processFrame(RawPitch rawPitch) {
    _totalFrames++;
    
    // 1. 옥타브 에러 감지 및 수정
    final octaveCorrected = _correctOctaveErrors(rawPitch);
    
    // 2. Median 필터 적용
    final medianFiltered = _applyMedianFilter(octaveCorrected);
    
    // 3. Viterbi 경로 최적화
    final viterbiSmoothed = _applyViterbiSmoothing(medianFiltered);
    
    // 4. 이동 평균 (Moving Average)
    final movingAverage = _applyMovingAverage(viterbiSmoothed);
    
    // 5. 비브라토 감지 및 보존
    _detectVibrato();
    
    // 6. 적응형 스무딩 (비브라토 시 약하게)
    final adaptiveSmoothed = _applyAdaptiveSmoothing(movingAverage);
    
    // 7. 히스토리 업데이트
    _updateHistory(adaptiveSmoothed);
    
    // 8. 통계 업데이트
    _updateStatistics(rawPitch, adaptiveSmoothed);
    
    return adaptiveSmoothed;
  }
  
  /// 옥타브 에러 수정
  RawPitch _correctOctaveErrors(RawPitch pitch) {
    if (_pitchHistory.isEmpty) {
      return pitch;
    }
    
    final lastPitch = _pitchHistory.last;
    final cents = _frequencyToCents(pitch.frequency, lastPitch.frequency);
    
    // 옥타브 점프 감지 (1200 cents = 1 옥타브)
    if (cents.abs() > kOctaveJumpThreshold) {
      final octaveShift = (cents / 1200).round();
      final correctedFreq = pitch.frequency / math.pow(2, octaveShift);
      
      // 수정 후 다시 확인
      final correctedCents = _frequencyToCents(correctedFreq, lastPitch.frequency);
      
      if (correctedCents.abs() < cents.abs()) {
        _jumpCount++;
        print('⚠️ 옥타브 에러 수정: ${pitch.frequency.toStringAsFixed(1)}Hz -> ${correctedFreq.toStringAsFixed(1)}Hz');
        
        return RawPitch(
          frequency: correctedFreq,
          confidence: pitch.confidence * 0.9, // 신뢰도 약간 감소
          timestamp: pitch.timestamp,
        );
      }
    }
    
    return pitch;
  }
  
  /// Median 필터 적용
  RawPitch _applyMedianFilter(RawPitch pitch) {
    _medianBuffer.add(pitch.frequency);
    
    if (_medianBuffer.length > kMedianFilterSize) {
      _medianBuffer.removeFirst();
    }
    
    if (_medianBuffer.length < 3) {
      return pitch; // 충분한 데이터가 없으면 원본 반환
    }
    
    // 중간값 계산
    final sorted = List<double>.from(_medianBuffer)..sort();
    final median = sorted[sorted.length ~/ 2];
    
    return RawPitch(
      frequency: median,
      confidence: pitch.confidence,
      timestamp: pitch.timestamp,
    );
  }
  
  /// Viterbi 경로 최적화
  SmoothedPitch _applyViterbiSmoothing(RawPitch pitch) {
    // 초기화
    if (_viterbiPath.isEmpty) {
      _viterbiPath.add(ViterbiNode(
        frequency: pitch.frequency,
        confidence: pitch.confidence,
        cost: 0,
        previousIndex: -1,
      ));
      
      return SmoothedPitch(
        frequency: pitch.frequency,
        confidence: pitch.confidence,
        timestamp: pitch.timestamp,
        smoothingApplied: false,
      );
    }
    
    // 후보 노트 생성 (현재 주파수 주변)
    final candidates = _generateCandidates(pitch.frequency);
    final newNodes = <ViterbiNode>[];
    
    for (final candidate in candidates) {
      double minCost = double.infinity;
      int bestPrevIndex = -1;
      
      // 이전 경로와의 비용 계산
      for (int i = 0; i < _viterbiPath.length && i < kViterbiBeamWidth; i++) {
        final prevNode = _viterbiPath[_viterbiPath.length - 1 - i];
        final transitionCost = _calculateTransitionCost(
          prevNode.frequency,
          candidate,
          pitch.confidence,
        );
        
        final totalCost = prevNode.cost + transitionCost;
        
        if (totalCost < minCost) {
          minCost = totalCost;
          bestPrevIndex = _viterbiPath.length - 1 - i;
        }
      }
      
      newNodes.add(ViterbiNode(
        frequency: candidate,
        confidence: pitch.confidence,
        cost: minCost,
        previousIndex: bestPrevIndex,
      ));
    }
    
    // 최적 경로 선택
    newNodes.sort((a, b) => a.cost.compareTo(b.cost));
    final bestNode = newNodes.first;
    
    _viterbiPath.add(bestNode);
    
    // 히스토리 크기 제한
    if (_viterbiPath.length > kViterbiHistorySize) {
      _viterbiPath.removeAt(0);
    }
    
    // 스무딩 적용 여부 판단
    final smoothingApplied = (bestNode.frequency - pitch.frequency).abs() > 1.0;
    
    if (smoothingApplied) {
      _smoothedFrames++;
    }
    
    return SmoothedPitch(
      frequency: bestNode.frequency,
      confidence: bestNode.confidence,
      timestamp: pitch.timestamp,
      smoothingApplied: smoothingApplied,
      transitionCost: bestNode.cost,
    );
  }
  
  /// 후보 주파수 생성
  List<double> _generateCandidates(double frequency) {
    final candidates = <double>[frequency];
    
    // 주변 반음 추가 (±50 cents)
    for (int i = 1; i <= 2; i++) {
      final factor = math.pow(2, i * 50 / 1200); // 50 cents
      candidates.add(frequency * factor);
      candidates.add(frequency / factor);
    }
    
    return candidates;
  }
  
  /// 전이 비용 계산
  double _calculateTransitionCost(
    double prevFreq,
    double currFreq,
    double confidence,
  ) {
    // 센트 차이 계산
    final cents = _frequencyToCents(currFreq, prevFreq).abs();
    
    // 기본 전이 비용
    double cost = cents / kViterbiTransitionCost;
    
    // 신뢰도 가중치
    cost *= (2.0 - confidence);
    
    // 비브라토 감지 시 비용 감소
    if (_vibratoDetected && cents < kVibratoMinExtent * 2) {
      cost *= 0.5;
    }
    
    return cost;
  }
  
  /// 이동 평균 적용
  SmoothedPitch _applyMovingAverage(SmoothedPitch pitch) {
    _averageBuffer.add(pitch.frequency);
    
    if (_averageBuffer.length > kMovingAverageSize) {
      _averageBuffer.removeFirst();
    }
    
    if (_averageBuffer.isEmpty) {
      return pitch;
    }
    
    final average = _averageBuffer.reduce((a, b) => a + b) / _averageBuffer.length;
    
    return SmoothedPitch(
      frequency: average,
      confidence: pitch.confidence,
      timestamp: pitch.timestamp,
      smoothingApplied: pitch.smoothingApplied,
      transitionCost: pitch.transitionCost,
    );
  }
  
  /// 적응형 스무딩
  SmoothedPitch _applyAdaptiveSmoothing(SmoothedPitch pitch) {
    // 비브라토 감지 시 약한 스무딩
    if (_vibratoDetected) {
      // 비브라토는 보존하면서 노이즈만 제거
      if (_pitchHistory.isNotEmpty) {
        final lastPitch = _pitchHistory.last;
        final cents = _frequencyToCents(pitch.frequency, lastPitch.frequency);
        
        // 비브라토 범위 내면 원본 유지
        if (cents.abs() < _vibratoExtent * 1.5) {
          return pitch;
        }
      }
    }
    
    // 낮은 신뢰도에서 강한 스무딩
    if (pitch.confidence < 0.5 && _pitchHistory.isNotEmpty) {
      final lastPitch = _pitchHistory.last;
      final blendFactor = pitch.confidence;
      
      return SmoothedPitch(
        frequency: lastPitch.frequency * (1 - blendFactor) + pitch.frequency * blendFactor,
        confidence: pitch.confidence,
        timestamp: pitch.timestamp,
        smoothingApplied: true,
        transitionCost: pitch.transitionCost,
      );
    }
    
    return pitch;
  }
  
  /// 비브라토 감지
  void _detectVibrato() {
    if (_pitchHistory.length < 20) {
      return; // 충분한 데이터 필요
    }
    
    // FFT를 사용한 주기성 감지 (간단한 버전)
    final recentPitches = _pitchHistory.toList().sublist(_pitchHistory.length - 20);
    final frequencies = recentPitches.map((p) => p.frequency).toList();
    
    // 평균 제거 (DC 성분)
    final mean = frequencies.reduce((a, b) => a + b) / frequencies.length;
    final centered = frequencies.map((f) => f - mean).toList();
    
    // 변동폭 계산
    double maxDeviation = 0;
    for (final value in centered) {
      maxDeviation = math.max(maxDeviation, value.abs());
    }
    
    // 센트로 변환
    final extentCents = _frequencyToCents(mean + maxDeviation, mean).abs();
    
    // Zero-crossing rate로 주기 추정
    int zeroCrossings = 0;
    for (int i = 1; i < centered.length; i++) {
      if ((centered[i] >= 0) != (centered[i-1] >= 0)) {
        zeroCrossings++;
      }
    }
    
    final estimatedRate = zeroCrossings / 2.0 / (20 * 0.01); // 10ms 프레임 가정
    
    // 비브라토 판단
    _vibratoDetected = estimatedRate >= kVibratoMinRate && 
                       estimatedRate <= kVibratoMaxRate && 
                       extentCents >= kVibratoMinExtent;
    
    if (_vibratoDetected) {
      _vibratoRate = estimatedRate;
      _vibratoExtent = extentCents;
    }
  }
  
  /// 히스토리 업데이트
  void _updateHistory(SmoothedPitch pitch) {
    _pitchHistory.add(PitchFrame(
      frequency: pitch.frequency,
      confidence: pitch.confidence,
      timestamp: pitch.timestamp,
    ));
    
    if (_pitchHistory.length > 100) {
      _pitchHistory.removeFirst();
    }
  }
  
  /// 통계 업데이트
  void _updateStatistics(RawPitch raw, SmoothedPitch smoothed) {
    _averageConfidence = (_averageConfidence * 0.95) + (smoothed.confidence * 0.05);
    
    // 매 100 프레임마다 리포트
    if (_totalFrames % 100 == 0) {
      final smoothingRate = _smoothedFrames * 100.0 / _totalFrames;
      final jumpRate = _jumpCount * 100.0 / _totalFrames;
      
      print('📊 스무딩 통계:');
      print('  - 스무딩 비율: ${smoothingRate.toStringAsFixed(1)}%');
      print('  - 옥타브 점프 수정: ${jumpRate.toStringAsFixed(2)}%');
      print('  - 평균 신뢰도: ${_averageConfidence.toStringAsFixed(3)}');
      
      if (_vibratoDetected) {
        print('  - 비브라토: ${_vibratoRate.toStringAsFixed(1)}Hz, ±${_vibratoExtent.toStringAsFixed(1)} cents');
      }
    }
  }
  
  /// 주파수를 센트로 변환
  double _frequencyToCents(double freq1, double freq2) {
    if (freq1 <= 0 || freq2 <= 0) return 0;
    return 1200 * math.log(freq1 / freq2) / math.log(2);
  }
  
  /// 통계 획듍
  SmoothingStatistics getStatistics() {
    return SmoothingStatistics(
      totalFrames: _totalFrames,
      smoothedFrames: _smoothedFrames,
      octaveJumps: _jumpCount,
      averageConfidence: _averageConfidence,
      vibratoDetected: _vibratoDetected,
      vibratoRate: _vibratoRate,
      vibratoExtent: _vibratoExtent,
    );
  }
  
  /// 리셋
  void reset() {
    _medianBuffer.clear();
    _averageBuffer.clear();
    _viterbiPath.clear();
    _pitchHistory.clear();
    _totalFrames = 0;
    _jumpCount = 0;
    _smoothedFrames = 0;
    _averageConfidence = 0.0;
    _vibratoDetected = false;
    _vibratoRate = 0.0;
    _vibratoExtent = 0.0;
  }
}

/// 원시 피치 데이터
class RawPitch {
  final double frequency;
  final double confidence;
  final DateTime timestamp;
  
  const RawPitch({
    required this.frequency,
    required this.confidence,
    required this.timestamp,
  });
}

/// 스무딩된 피치
class SmoothedPitch {
  final double frequency;
  final double confidence;
  final DateTime timestamp;
  final bool smoothingApplied;
  final double? transitionCost;
  
  const SmoothedPitch({
    required this.frequency,
    required this.confidence,
    required this.timestamp,
    required this.smoothingApplied,
    this.transitionCost,
  });
}

/// 피치 프레임 (히스토리용)
class PitchFrame {
  final double frequency;
  final double confidence;
  final DateTime timestamp;
  
  const PitchFrame({
    required this.frequency,
    required this.confidence,
    required this.timestamp,
  });
}

/// Viterbi 노드
class ViterbiNode {
  final double frequency;
  final double confidence;
  final double cost;
  final int previousIndex;
  
  const ViterbiNode({
    required this.frequency,
    required this.confidence,
    required this.cost,
    required this.previousIndex,
  });
}

/// 스무딩 통계
class SmoothingStatistics {
  final int totalFrames;
  final int smoothedFrames;
  final int octaveJumps;
  final double averageConfidence;
  final bool vibratoDetected;
  final double vibratoRate;
  final double vibratoExtent;
  
  const SmoothingStatistics({
    required this.totalFrames,
    required this.smoothedFrames,
    required this.octaveJumps,
    required this.averageConfidence,
    required this.vibratoDetected,
    required this.vibratoRate,
    required this.vibratoExtent,
  });
  
  double get smoothingRate => totalFrames > 0 ? smoothedFrames / totalFrames : 0;
  double get jumpRate => totalFrames > 0 ? octaveJumps / totalFrames : 0;
  
  @override
  String toString() {
    return '''
Smoothing Statistics:
  Total Frames: $totalFrames
  Smoothing Rate: ${(smoothingRate * 100).toStringAsFixed(1)}%
  Octave Jump Rate: ${(jumpRate * 100).toStringAsFixed(2)}%
  Average Confidence: ${averageConfidence.toStringAsFixed(3)}
  Vibrato: ${vibratoDetected ? "${vibratoRate.toStringAsFixed(1)}Hz, ±${vibratoExtent.toStringAsFixed(1)} cents" : "Not detected"}
''';
  }
}