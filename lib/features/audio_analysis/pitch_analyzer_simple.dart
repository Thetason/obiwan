import 'dart:math' as math;

class PitchAnalyzer {
  static const double minFrequency = 80.0;
  static const double maxFrequency = 1000.0;
  static const int hopSize = 160; // 10ms at 16kHz
  
  Future<List<double>> analyzePitch(List<double> audioSamples) async {
    final pitchValues = <double>[];
    
    // 간단한 피치 추정 (실제로는 더 정교한 알고리즘 사용)
    for (int i = 0; i < audioSamples.length - 1024; i += hopSize) {
      final window = audioSamples.sublist(i, i + 1024);
      final pitch = _estimatePitch(window);
      
      if (pitch > 0 && pitch >= minFrequency && pitch <= maxFrequency) {
        pitchValues.add(pitch);
      } else {
        pitchValues.add(0.0);
      }
    }
    
    return pitchValues;
  }
  
  double _estimatePitch(List<double> window) {
    // 간단한 피치 추정 (자기상관 기반)
    final autocorr = _computeAutocorrelation(window);
    
    // 피크 찾기
    double maxCorr = 0.0;
    int bestLag = 0;
    
    for (int lag = 20; lag < autocorr.length ~/ 2; lag++) {
      if (autocorr[lag] > maxCorr) {
        maxCorr = autocorr[lag];
        bestLag = lag;
      }
    }
    
    if (maxCorr > 0.3 && bestLag > 0) {
      return 16000.0 / bestLag; // 샘플레이트 / 지연
    }
    
    return 0.0;
  }
  
  List<double> _computeAutocorrelation(List<double> samples) {
    final result = List<double>.filled(samples.length, 0.0);
    
    for (int lag = 0; lag < samples.length; lag++) {
      double sum = 0.0;
      for (int i = 0; i < samples.length - lag; i++) {
        sum += samples[i] * samples[i + lag];
      }
      result[lag] = sum;
    }
    
    return result;
  }
  
  double calculatePitchStability(List<double> pitchValues) {
    if (pitchValues.isEmpty) return 0.0;
    
    final voicedPitches = pitchValues.where((p) => p > 0).toList();
    if (voicedPitches.length < 10) return 0.0;
    
    final mean = voicedPitches.reduce((a, b) => a + b) / voicedPitches.length;
    final variance = voicedPitches.map((p) => math.pow(p - mean, 2))
        .reduce((a, b) => a + b) / voicedPitches.length;
    final stdDev = math.sqrt(variance);
    
    final cv = stdDev / mean;
    final stability = math.max(0, 100 - (cv * 500));
    
    return stability.clamp(0, 100).toDouble();
  }
  
  Map<String, double> analyzeVibrato(List<double> pitchValues) {
    final voicedPitches = pitchValues.where((p) => p > 0).toList();
    if (voicedPitches.length < 50) {
      return {'rate': 0, 'extent': 0, 'regularity': 0};
    }
    
    // 간단한 비브라토 분석
    final differences = <double>[];
    for (int i = 1; i < voicedPitches.length; i++) {
      differences.add((voicedPitches[i] - voicedPitches[i - 1]).abs());
    }
    
    final avgDifference = differences.reduce((a, b) => a + b) / differences.length;
    final avgPitch = voicedPitches.reduce((a, b) => a + b) / voicedPitches.length;
    final vibratoDepth = avgDifference / avgPitch;
    
    return {
      'rate': vibratoDepth > 0.01 ? 5.0 : 0.0,
      'extent': vibratoDepth * 100,
      'regularity': vibratoDepth > 0.01 ? 0.8 : 0.0,
    };
  }
  
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
}