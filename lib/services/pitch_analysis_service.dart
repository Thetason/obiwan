import 'dart:math' as math;
import 'dart:typed_data';

/// 시간별 피치 분석 데이터
class PitchDataPoint {
  final double timeSeconds;    // 시간 (초)
  final double frequency;      // 주파수 (Hz)
  final double confidence;     // 신뢰도 (0.0 - 1.0)
  final double amplitude;      // 음량 (RMS)
  final String noteName;       // 노트명 (C4, D#5 등)
  final bool isStable;         // 안정적인 피치인지 여부

  PitchDataPoint({
    required this.timeSeconds,
    required this.frequency,
    required this.confidence,
    required this.amplitude,
    required this.noteName,
    required this.isStable,
  });
}

/// 비브라토 분석 데이터
class VibratoData {
  final double rate;           // 비브라토 속도 (Hz)
  final double depth;          // 비브라토 깊이 (cents)
  final bool isPresent;        // 비브라토 존재 여부

  VibratoData({
    required this.rate,
    required this.depth,
    required this.isPresent,
  });
}

/// 시간별 피치 분석 서비스
class PitchAnalysisService {
  static const double _sampleRate = 48000.0;
  static const int _windowSize = 2048;      // FFT 윈도우 크기
  static const int _hopSize = 512;          // 오버랩 스텝 크기
  static const double _minFreq = 80.0;      // 최소 주파수 (Hz)
  static const double _maxFreq = 2000.0;    // 최대 주파수 (Hz)
  
  /// 오디오 데이터에서 시간별 피치 추출
  static List<PitchDataPoint> extractPitchOverTime(List<double> audioData) {
    if (audioData.length < _windowSize) {
      return [];
    }
    
    final pitchPoints = <PitchDataPoint>[];
    final numWindows = (audioData.length - _windowSize) ~/ _hopSize + 1;
    
    print('🎵 [PitchAnalysis] 오디오 길이: ${audioData.length} 샘플');
    print('🎵 [PitchAnalysis] 분석할 윈도우 수: $numWindows');
    
    for (int i = 0; i < numWindows; i++) {
      final startIdx = i * _hopSize;
      final endIdx = math.min(startIdx + _windowSize, audioData.length);
      
      if (endIdx - startIdx < _windowSize) break;
      
      final window = audioData.sublist(startIdx, endIdx);
      final timeSeconds = startIdx / _sampleRate;
      
      // 피치 추정
      final pitchResult = _estimatePitch(window);
      final amplitude = _calculateRMS(window);
      
      final frequency = pitchResult['frequency'] as double;
      final confidence = pitchResult['confidence'] as double;
      
      if (frequency > _minFreq && frequency < _maxFreq) {
        final noteName = _frequencyToNoteName(frequency);
        final isStable = confidence > 0.6 && amplitude > 0.001;
        
        pitchPoints.add(PitchDataPoint(
          timeSeconds: timeSeconds,
          frequency: frequency,
          confidence: confidence,
          amplitude: amplitude,
          noteName: noteName,
          isStable: isStable,
        ));
      }
    }
    
    print('🎵 [PitchAnalysis] 추출된 피치 포인트: ${pitchPoints.length}개');
    return _smoothPitchData(pitchPoints);
  }
  
  /// 고급 피치 추정 (YIN 알고리즘 기반)
  static Map<String, double> _estimatePitch(List<double> window) {
    final length = window.length;
    final yinBuffer = List<double>.filled(length ~/ 2, 0.0);
    
    // Step 1: Difference function
    for (int tau = 1; tau < length ~/ 2; tau++) {
      double sum = 0.0;
      for (int i = 0; i < length ~/ 2; i++) {
        final delta = window[i] - window[i + tau];
        sum += delta * delta;
      }
      yinBuffer[tau] = sum;
    }
    
    // Step 2: Cumulative mean normalized difference
    yinBuffer[0] = 1.0;
    double cumulativeSum = 0.0;
    
    for (int tau = 1; tau < length ~/ 2; tau++) {
      cumulativeSum += yinBuffer[tau];
      if (cumulativeSum != 0) {
        yinBuffer[tau] = yinBuffer[tau] * tau / cumulativeSum;
      } else {
        yinBuffer[tau] = 1.0;
      }
    }
    
    // Step 3: Find the first minimum below threshold
    const threshold = 0.15;
    int minTau = 1;
    double minValue = yinBuffer[1];
    
    for (int tau = 1; tau < length ~/ 2; tau++) {
      if (yinBuffer[tau] < threshold) {
        minTau = tau;
        minValue = yinBuffer[tau];
        break;
      }
      if (yinBuffer[tau] < minValue) {
        minTau = tau;
        minValue = yinBuffer[tau];
      }
    }
    
    // Step 4: Parabolic interpolation
    double interpolatedTau = minTau.toDouble();
    if (minTau > 0 && minTau < yinBuffer.length - 1) {
      final s0 = yinBuffer[minTau - 1];
      final s1 = yinBuffer[minTau];
      final s2 = yinBuffer[minTau + 1];
      
      final a = (s0 - 2 * s1 + s2) / 2;
      final b = (s2 - s0) / 2;
      
      if (a != 0) {
        interpolatedTau = minTau - b / (2 * a);
      }
    }
    
    final frequency = interpolatedTau > 0 ? _sampleRate / interpolatedTau : 0.0;
    final confidence = math.max(0.0, 1.0 - minValue);
    
    return {
      'frequency': frequency,
      'confidence': confidence,
    };
  }
  
  /// RMS 계산
  static double _calculateRMS(List<double> window) {
    if (window.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (final sample in window) {
      sum += sample * sample;
    }
    return math.sqrt(sum / window.length);
  }
  
  /// 피치 데이터 스무딩 (노이즈 제거)
  static List<PitchDataPoint> _smoothPitchData(List<PitchDataPoint> rawData) {
    if (rawData.length < 3) return rawData;
    
    final smoothed = <PitchDataPoint>[];
    
    // 첫 번째 포인트
    smoothed.add(rawData[0]);
    
    // 중간 포인트들 (3포인트 moving average)
    for (int i = 1; i < rawData.length - 1; i++) {
      final prev = rawData[i - 1];
      final curr = rawData[i];
      final next = rawData[i + 1];
      
      // 주파수가 너무 크게 점프하면 median을 사용
      final frequencies = [prev.frequency, curr.frequency, next.frequency];
      frequencies.sort();
      final medianFreq = frequencies[1];
      
      // 원래 값과 median이 50% 이상 차이나면 median 사용
      final useMedian = (curr.frequency - medianFreq).abs() / curr.frequency > 0.5;
      
      final smoothedFreq = useMedian ? medianFreq : 
          (prev.frequency + curr.frequency + next.frequency) / 3;
      final smoothedConf = (prev.confidence + curr.confidence + next.confidence) / 3;
      
      smoothed.add(PitchDataPoint(
        timeSeconds: curr.timeSeconds,
        frequency: smoothedFreq,
        confidence: smoothedConf,
        amplitude: curr.amplitude,
        noteName: _frequencyToNoteName(smoothedFreq),
        isStable: smoothedConf > 0.6,
      ));
    }
    
    // 마지막 포인트
    smoothed.add(rawData.last);
    
    return smoothed;
  }
  
  /// 비브라토 분석
  static VibratoData analyzeVibrato(List<PitchDataPoint> pitchData) {
    if (pitchData.length < 10) {
      return VibratoData(rate: 0, depth: 0, isPresent: false);
    }
    
    // 안정적인 구간만 분석
    final stablePoints = pitchData.where((p) => p.isStable).toList();
    if (stablePoints.length < 8) {
      return VibratoData(rate: 0, depth: 0, isPresent: false);
    }
    
    // 주파수 변화 분석
    final freqChanges = <double>[];
    for (int i = 1; i < stablePoints.length; i++) {
      final change = stablePoints[i].frequency - stablePoints[i-1].frequency;
      freqChanges.add(change);
    }
    
    // 주파수 변화의 주기성 분석 (간단한 방법)
    final avgChange = freqChanges.reduce((a, b) => a + b) / freqChanges.length;
    final variance = freqChanges.map((c) => (c - avgChange) * (c - avgChange))
        .reduce((a, b) => a + b) / freqChanges.length;
    
    final stdDev = math.sqrt(variance);
    final isVibrato = stdDev > 5.0; // 5Hz 이상의 변화
    
    // 비브라토 속도 추정 (매우 간단한 방법)
    double vibratoRate = 0.0;
    if (isVibrato && stablePoints.length > 1) {
      final totalTime = stablePoints.last.timeSeconds - stablePoints.first.timeSeconds;
      final zeroCrossings = _countZeroCrossings(freqChanges);
      vibratoRate = zeroCrossings / (2 * totalTime); // Hz
    }
    
    return VibratoData(
      rate: vibratoRate,
      depth: _frequencyToCents(stdDev),
      isPresent: isVibrato && vibratoRate > 3.0 && vibratoRate < 12.0,
    );
  }
  
  static int _countZeroCrossings(List<double> data) {
    int count = 0;
    for (int i = 1; i < data.length; i++) {
      if ((data[i-1] >= 0) != (data[i] >= 0)) {
        count++;
      }
    }
    return count;
  }
  
  /// 주파수를 노트명으로 변환
  static String _frequencyToNoteName(double frequency) {
    if (frequency < 80) return '---';
    
    final notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final a4 = 440.0;
    final c0 = a4 * math.pow(2, -4.75);
    
    if (frequency <= c0) return '---';
    
    final h = 12 * (math.log(frequency / c0) / math.ln2);
    final octave = (h / 12).floor();
    final noteIndex = (h % 12).round() % 12;
    
    return '${notes[noteIndex]}$octave';
  }
  
  /// 주파수 차이를 센트로 변환
  static double _frequencyToCents(double freqDiff) {
    return 1200 * (math.log(1 + freqDiff.abs() / 440) / math.ln2);
  }
  
  /// 피치 데이터 요약 통계
  static Map<String, dynamic> getPitchStatistics(List<PitchDataPoint> pitchData) {
    if (pitchData.isEmpty) {
      return {
        'averageFrequency': 0.0,
        'frequencyRange': 0.0,
        'stability': 0.0,
        'totalDuration': 0.0,
        'stablePercentage': 0.0,
      };
    }
    
    final frequencies = pitchData.map((p) => p.frequency).toList();
    final stablePoints = pitchData.where((p) => p.isStable).length;
    
    frequencies.sort();
    final avgFreq = frequencies.reduce((a, b) => a + b) / frequencies.length;
    final freqRange = frequencies.last - frequencies.first;
    final totalDuration = pitchData.last.timeSeconds - pitchData.first.timeSeconds;
    final stablePercentage = stablePoints / pitchData.length;
    
    // 안정성 계산 (주파수 변화의 표준편차 기반)
    final variance = frequencies.map((f) => (f - avgFreq) * (f - avgFreq))
        .reduce((a, b) => a + b) / frequencies.length;
    final stability = math.max(0.0, 1.0 - math.sqrt(variance) / avgFreq);
    
    return {
      'averageFrequency': avgFreq,
      'frequencyRange': freqRange,
      'stability': stability,
      'totalDuration': totalDuration,
      'stablePercentage': stablePercentage,
    };
  }
}