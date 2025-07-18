import 'dart:math' as math;
import 'package:pitch_detector_dart/pitch_detector_dart.dart';

class PitchAnalyzer {
  static const double minFrequency = 80.0;  // E2
  static const double maxFrequency = 1000.0; // B5
  static const int hopSize = 160; // 10ms at 16kHz
  
  final PitchDetector _pitchDetector;
  
  PitchAnalyzer({int sampleRate = 16000}) 
    : _pitchDetector = PitchDetector(sampleRate.toDouble(), 1024);
  
  Future<List<double>> analyzePitch(List<double> audioSamples) async {
    final pitchValues = <double>[];
    
    // 슬라이딩 윈도우로 피치 추출
    for (int i = 0; i < audioSamples.length - 1024; i += hopSize) {
      final window = audioSamples.sublist(i, i + 1024);
      
      // 윈도우 함수 적용 (Hamming window)
      final windowedSamples = _applyHammingWindow(window);
      
      // 피치 검출
      final pitchResult = await _pitchDetector.getPitchFromFloatBuffer(windowedSamples);
      
      if (pitchResult.pitch > 0 && 
          pitchResult.pitch >= minFrequency && 
          pitchResult.pitch <= maxFrequency &&
          pitchResult.probability > 0.8) {
        pitchValues.add(pitchResult.pitch);
      } else {
        pitchValues.add(0.0); // 무성음 또는 신뢰도 낮은 구간
      }
    }
    
    // 중간값 필터로 노이즈 제거
    return _medianFilter(pitchValues, 5);
  }
  
  double calculatePitchStability(List<double> pitchValues) {
    if (pitchValues.isEmpty) return 0.0;
    
    // 유성음 구간만 추출
    final voicedPitches = pitchValues.where((p) => p > 0).toList();
    if (voicedPitches.length < 10) return 0.0;
    
    // 센트 단위로 변환하여 안정성 계산
    final cents = <double>[];
    final referencePitch = _findReferencePitch(voicedPitches);
    
    for (final pitch in voicedPitches) {
      final centDiff = 1200 * math.log(pitch / referencePitch) / math.ln2;
      cents.add(centDiff);
    }
    
    // 표준편차 계산
    final mean = cents.reduce((a, b) => a + b) / cents.length;
    final variance = cents.map((c) => math.pow(c - mean, 2))
        .reduce((a, b) => a + b) / cents.length;
    final stdDev = math.sqrt(variance);
    
    // 안정성 점수 계산 (±3 cent 이내가 목표)
    // 표준편차가 3 cent 이하면 100점
    final stability = math.max(0, 100 - (stdDev / 3 * 100));
    
    return stability.clamp(0, 100);
  }
  
  List<double> _applyHammingWindow(List<double> samples) {
    final windowed = List<double>.filled(samples.length, 0.0);
    final n = samples.length;
    
    for (int i = 0; i < n; i++) {
      final window = 0.54 - 0.46 * math.cos(2 * math.pi * i / (n - 1));
      windowed[i] = samples[i] * window;
    }
    
    return windowed;
  }
  
  List<double> _medianFilter(List<double> data, int windowSize) {
    if (data.length < windowSize) return data;
    
    final filtered = List<double>.filled(data.length, 0.0);
    final halfWindow = windowSize ~/ 2;
    
    for (int i = 0; i < data.length; i++) {
      final start = math.max(0, i - halfWindow);
      final end = math.min(data.length, i + halfWindow + 1);
      
      final window = data.sublist(start, end).toList();
      window.sort();
      
      filtered[i] = window[window.length ~/ 2];
    }
    
    return filtered;
  }
  
  double _findReferencePitch(List<double> pitches) {
    // 히스토그램을 사용하여 가장 빈번한 피치 찾기
    const binSize = 5.0; // Hz
    final histogram = <int, int>{};
    
    for (final pitch in pitches) {
      final bin = (pitch / binSize).round();
      histogram[bin] = (histogram[bin] ?? 0) + 1;
    }
    
    // 가장 빈번한 빈 찾기
    int maxCount = 0;
    int maxBin = 0;
    
    histogram.forEach((bin, count) {
      if (count > maxCount) {
        maxCount = count;
        maxBin = bin;
      }
    });
    
    // 해당 빈의 평균 피치 계산
    final binPitches = pitches.where((p) => 
      (p / binSize).round() == maxBin
    ).toList();
    
    if (binPitches.isEmpty) return pitches.first;
    
    return binPitches.reduce((a, b) => a + b) / binPitches.length;
  }
  
  // 피치 곡선 스무딩
  List<double> smoothPitchCurve(List<double> pitchValues, {int windowSize = 3}) {
    if (pitchValues.length < windowSize) return pitchValues;
    
    final smoothed = List<double>.filled(pitchValues.length, 0.0);
    
    for (int i = 0; i < pitchValues.length; i++) {
      if (pitchValues[i] == 0) {
        smoothed[i] = 0;
        continue;
      }
      
      double sum = 0;
      int count = 0;
      
      for (int j = math.max(0, i - windowSize); 
           j <= math.min(pitchValues.length - 1, i + windowSize); 
           j++) {
        if (pitchValues[j] > 0) {
          sum += pitchValues[j];
          count++;
        }
      }
      
      smoothed[i] = count > 0 ? sum / count : 0;
    }
    
    return smoothed;
  }
  
  // 비브라토 분석
  Map<String, double> analyzeVibrato(List<double> pitchValues) {
    final voicedPitches = pitchValues.where((p) => p > 0).toList();
    if (voicedPitches.length < 50) {
      return {'rate': 0, 'extent': 0, 'regularity': 0};
    }
    
    // 피치 곡선의 미분 계산
    final derivatives = <double>[];
    for (int i = 1; i < voicedPitches.length; i++) {
      derivatives.add(voicedPitches[i] - voicedPitches[i - 1]);
    }
    
    // 영교차 검출로 비브라토 주기 찾기
    final zeroCrossings = <int>[];
    for (int i = 1; i < derivatives.length; i++) {
      if (derivatives[i - 1] * derivatives[i] < 0) {
        zeroCrossings.add(i);
      }
    }
    
    if (zeroCrossings.length < 4) {
      return {'rate': 0, 'extent': 0, 'regularity': 0};
    }
    
    // 비브라토 속도 계산 (Hz)
    final periods = <double>[];
    for (int i = 2; i < zeroCrossings.length; i += 2) {
      final period = (zeroCrossings[i] - zeroCrossings[i - 2]) * 0.01; // 10ms hop
      if (period > 0) {
        periods.add(1 / period);
      }
    }
    
    final avgRate = periods.isNotEmpty ? 
        periods.reduce((a, b) => a + b) / periods.length : 0.0;
    
    // 비브라토 진폭 계산 (cents)
    final avgPitch = voicedPitches.reduce((a, b) => a + b) / voicedPitches.length;
    final maxDeviation = voicedPitches.map((p) => (p - avgPitch).abs()).reduce(math.max);
    final extentCents = 1200 * math.log(1 + maxDeviation / avgPitch) / math.ln2;
    
    // 규칙성 계산 (0-1)
    double regularity = 0;
    if (periods.length > 1) {
      final periodMean = periods.reduce((a, b) => a + b) / periods.length;
      final periodVariance = periods.map((p) => math.pow(p - periodMean, 2))
          .reduce((a, b) => a + b) / periods.length;
      regularity = 1 / (1 + math.sqrt(periodVariance) / periodMean);
    }
    
    return {
      'rate': avgRate.clamp(0, 10),
      'extent': extentCents.clamp(0, 100),
      'regularity': regularity.clamp(0, 1),
    };
  }
}