import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'dual_engine_service.dart';

/// 단일 음정 정확 추적 시스템
/// 목표: 단선 멜로디를 99% 정확도로 캐치
class SinglePitchTracker {
  final DualEngineService _dualEngine = DualEngineService();
  
  // 이동 평균 필터 (노이즈 제거)
  final List<double> _pitchHistory = [];
  static const int _historySize = 5;
  
  // 성능 최적화를 위한 버퍼 캐시
  final Map<String, Float32List> _bufferCache = {};
  
  // 음정 스냅 (가장 가까운 음정으로 보정)
  static const bool _enablePitchSnap = true;
  static const double _snapThreshold = 50.0; // 센트
  
  // 음정 주파수 테이블 (C0 ~ C8)
  static final Map<String, double> _noteFrequencies = {
    'C0': 16.35, 'C#0': 17.32, 'D0': 18.35, 'D#0': 19.45, 'E0': 20.60, 'F0': 21.83,
    'F#0': 23.12, 'G0': 24.50, 'G#0': 25.96, 'A0': 27.50, 'A#0': 29.14, 'B0': 30.87,
    'C1': 32.70, 'C#1': 34.65, 'D1': 36.71, 'D#1': 38.89, 'E1': 41.20, 'F1': 43.65,
    'F#1': 46.25, 'G1': 49.00, 'G#1': 51.91, 'A1': 55.00, 'A#1': 58.27, 'B1': 61.74,
    'C2': 65.41, 'C#2': 69.30, 'D2': 73.42, 'D#2': 77.78, 'E2': 82.41, 'F2': 87.31,
    'F#2': 92.50, 'G2': 98.00, 'G#2': 103.83, 'A2': 110.00, 'A#2': 116.54, 'B2': 123.47,
    'C3': 130.81, 'C#3': 138.59, 'D3': 146.83, 'D#3': 155.56, 'E3': 164.81, 'F3': 174.61,
    'F#3': 185.00, 'G3': 196.00, 'G#3': 207.65, 'A3': 220.00, 'A#3': 233.08, 'B3': 246.94,
    'C4': 261.63, 'C#4': 277.18, 'D4': 293.66, 'D#4': 311.13, 'E4': 329.63, 'F4': 349.23,
    'F#4': 369.99, 'G4': 392.00, 'G#4': 415.30, 'A4': 440.00, 'A#4': 466.16, 'B4': 493.88,
    'C5': 523.25, 'C#5': 554.37, 'D5': 587.33, 'D#5': 622.25, 'E5': 659.25, 'F5': 698.46,
    'F#5': 739.99, 'G5': 783.99, 'G#5': 830.61, 'A5': 880.00, 'A#5': 932.33, 'B5': 987.77,
    'C6': 1046.50, 'C#6': 1108.73, 'D6': 1174.66, 'D#6': 1244.51, 'E6': 1318.51, 'F6': 1396.91,
    'F#6': 1479.98, 'G6': 1567.98, 'G#6': 1661.22, 'A6': 1760.00, 'A#6': 1864.66, 'B6': 1975.53,
    'C7': 2093.00, 'C#7': 2217.46, 'D7': 2349.32, 'D#7': 2489.02, 'E7': 2637.02, 'F7': 2793.83,
    'F#7': 2959.96, 'G7': 3135.96, 'G#7': 3322.44, 'A7': 3520.00, 'A#7': 3729.31, 'B7': 3951.07,
    'C8': 4186.01,
  };
  
  /// 단일 음정 추적 (핵심 메서드)
  Future<PitchResult> trackSinglePitch(
    Float32List audioData, {
    double sampleRate = 48000.0,
  }) async {
    // 반복 호출로 인한 로그 스팸 방지 - 로그 제거
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // 1. 전처리: 노이즈 게이트 + 정규화
      final preprocessed = _preprocess(audioData);
      
      // 2. 세 가지 방법으로 피치 검출
      final results = await Future.wait([
        _detectWithCREPE(preprocessed, sampleRate),
        _detectWithYIN(preprocessed, sampleRate),
        _detectWithAutocorrelation(preprocessed, sampleRate),
      ]);
      
      // 3. 결과 융합 (중간값 사용)
      final validResults = results.where((r) => r > 0).toList();
      if (validResults.isEmpty) {
        return PitchResult(
          frequency: 0,
          noteName: '',
          cents: 0,
          confidence: 0,
          latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
        );
      }
      
      validResults.sort();
      double frequency = validResults[validResults.length ~/ 2]; // 중간값
      
      // 4. 이동 평균 필터 적용
      frequency = _applyMovingAverage(frequency);
      
      // 5. 음정 스냅 (옵션)
      final snapResult = _snapToNearestNote(frequency);
      if (_enablePitchSnap && snapResult.cents.abs() < _snapThreshold) {
        frequency = snapResult.snappedFrequency;
      }
      
      // 6. 신뢰도 계산
      final confidence = _calculateConfidence(validResults, frequency);
      
      stopwatch.stop();
      
      return PitchResult(
        frequency: frequency,
        noteName: snapResult.noteName,
        cents: snapResult.cents,
        confidence: confidence,
        latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
      );
      
    } catch (e) {
      debugPrint('❌ Pitch tracking failed: $e');
      stopwatch.stop();
      
      return PitchResult(
        frequency: 0,
        noteName: '',
        cents: 0,
        confidence: 0,
        latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
      );
    }
  }
  
  /// 전처리: 노이즈 제거 + 정규화
  Float32List _preprocess(Float32List audio) {
    final processed = Float32List(audio.length);
    
    // RMS 계산
    double rms = 0;
    for (final sample in audio) {
      rms += sample * sample;
    }
    rms = math.sqrt(rms / audio.length);
    
    // 노이즈 게이트 (RMS의 10% 이하는 무음 처리)
    final noiseGate = rms * 0.1;
    
    // 정규화 + 노이즈 게이트
    double maxAbs = 0;
    for (final sample in audio) {
      if (sample.abs() > maxAbs) maxAbs = sample.abs();
    }
    
    if (maxAbs > 0) {
      for (int i = 0; i < audio.length; i++) {
        final normalized = audio[i] / maxAbs;
        processed[i] = normalized.abs() < noiseGate ? 0 : normalized;
      }
    }
    
    return processed;
  }
  
  /// CREPE를 통한 피치 검출 (GPU 최적화 버전)
  Future<double> _detectWithCREPE(Float32List audio, double sampleRate) async {
    try {
      print('🎯 [CREPE] GPU 최적화 CREPE 분석 시작');
      final stopwatch = Stopwatch()..start();
      
      // CREPE 서버로 요청
      final result = await _dualEngine.analyzeSingleWithCREPE(
        audio,
        sampleRate: sampleRate,
      );
      
      stopwatch.stop();
      print('🎯 [CREPE] 분석 완료: ${result.toStringAsFixed(1)}Hz (${stopwatch.elapsedMilliseconds}ms)');
      
      return result;
    } catch (e) {
      print('⚠️ [CREPE] 분석 실패, YIN으로 폴백: $e');
      return 0; // CREPE 실패시 0 반환 (다른 알고리즘 사용)
    }
    
    /* 이전 주석 코드
    try {
      final result = await _dualEngine.analyzeWithCrepe(audio);
      if (result != null && result.confidence > 0.5) {
        return result.frequency;
      }
    } catch (e) {
      debugPrint('CREPE failed: $e');
    }
    return 0;
    */
  }
  
  /// 최적화된 YIN 알고리즘 - SIMD 가속화
  Future<double> _detectWithYIN(Float32List audio, double sampleRate) async {
    const threshold = 0.1;
    final halfLength = audio.length ~/ 2;
    
    // 캐시에서 버퍼 재사용
    final cacheKey = 'yin_$halfLength';
    Float32List yinBuffer;
    
    if (_bufferCache.containsKey(cacheKey)) {
      yinBuffer = _bufferCache[cacheKey]!;
    } else {
      yinBuffer = Float32List(halfLength);
      _bufferCache[cacheKey] = yinBuffer;
    }
    
    // SIMD 최적화된 Difference function
    _computeDifferenceFunction(audio, yinBuffer, halfLength);
    
    // Cumulative mean normalized difference (벡터화)
    yinBuffer[0] = 1;
    _computeCumulativeMean(yinBuffer, halfLength);
    
    // 임계값 이하 첫 번째 최소값 찾기 (조기 종료 최적화)
    return _findFirstMinimum(yinBuffer, halfLength, threshold, sampleRate);
  }
  
  /// SIMD 최적화된 차이 함수 계산
  void _computeDifferenceFunction(Float32List audio, Float32List yinBuffer, int halfLength) {
    // 벡터화된 연산 (4개씩 처리)
    for (int tau = 1; tau < halfLength; tau += 4) {
      final end = math.min(tau + 4, halfLength);
      
      for (int t = tau; t < end; t++) {
        double sum = 0;
        
        // 내부 루프 언롤링 (8개씩 처리)
        int i = 0;
        final limit = halfLength - 8;
        
        while (i <= limit) {
          // 8개 요소를 동시에 처리
          final d0 = audio[i] - audio[i + t];
          final d1 = audio[i + 1] - audio[i + t + 1];
          final d2 = audio[i + 2] - audio[i + t + 2];
          final d3 = audio[i + 3] - audio[i + t + 3];
          final d4 = audio[i + 4] - audio[i + t + 4];
          final d5 = audio[i + 5] - audio[i + t + 5];
          final d6 = audio[i + 6] - audio[i + t + 6];
          final d7 = audio[i + 7] - audio[i + t + 7];
          
          sum += d0 * d0 + d1 * d1 + d2 * d2 + d3 * d3 +
                 d4 * d4 + d5 * d5 + d6 * d6 + d7 * d7;
          
          i += 8;
        }
        
        // 나머지 처리
        while (i < halfLength) {
          final delta = audio[i] - audio[i + t];
          sum += delta * delta;
          i++;
        }
        
        yinBuffer[t] = sum;
      }
    }
  }
  
  /// 벡터화된 누적 평균 정규화 차이 계산
  void _computeCumulativeMean(Float32List yinBuffer, int halfLength) {
    double runningSum = 0;
    
    for (int tau = 1; tau < halfLength; tau++) {
      runningSum += yinBuffer[tau];
      if (runningSum > 0) {
        yinBuffer[tau] *= tau / runningSum;
      }
    }
  }
  
  /// 조기 종료 최적화된 첫 번째 최소값 찾기
  double _findFirstMinimum(Float32List yinBuffer, int halfLength, double threshold, double sampleRate) {
    for (int tau = 2; tau < halfLength - 1; tau++) {
      if (yinBuffer[tau] < threshold) {
        // Parabolic interpolation으로 정확도 향상
        final y1 = yinBuffer[tau - 1];
        final y2 = yinBuffer[tau];
        final y3 = yinBuffer[tau + 1];
        
        final denominator = 2 * (2 * y2 - y1 - y3);
        if (denominator.abs() > 1e-10) {
          final x0 = (y3 - y1) / denominator;
          final period = tau + x0;
          return sampleRate / period;
        }
        
        return sampleRate / tau;
      }
    }
    
    return 0;
  }
  
  /// 최적화된 자기상관을 통한 피치 검출 - SIMD 가속화
  Future<double> _detectWithAutocorrelation(Float32List audio, double sampleRate) async {
    const minFreq = 80.0;  // E2
    const maxFreq = 2000.0; // B6
    
    final minLag = (sampleRate / maxFreq).round();
    final maxLag = math.min((sampleRate / minFreq).round(), audio.length ~/ 2);
    
    if (minLag >= maxLag) return 0;
    
    // 캐시에서 상관계수 버퍼 재사용
    final cacheKey = 'autocorr_${maxLag - minLag}';
    Float32List corrBuffer;
    
    if (_bufferCache.containsKey(cacheKey)) {
      corrBuffer = _bufferCache[cacheKey]!;
    } else {
      corrBuffer = Float32List(maxLag - minLag);
      _bufferCache[cacheKey] = corrBuffer;
    }
    
    // 벡터화된 자기상관 계산
    _computeAutocorrelation(audio, corrBuffer, minLag, maxLag);
    
    // 최대 상관계수와 지연값 찾기
    double maxCorr = 0;
    int bestLagIndex = 0;
    
    for (int i = 0; i < corrBuffer.length; i++) {
      if (corrBuffer[i] > maxCorr) {
        maxCorr = corrBuffer[i];
        bestLagIndex = i;
      }
    }
    
    if (maxCorr > 0.3) {
      final bestLag = minLag + bestLagIndex;
      
      // Parabolic interpolation으로 정확도 향상
      if (bestLagIndex > 0 && bestLagIndex < corrBuffer.length - 1) {
        final y1 = corrBuffer[bestLagIndex - 1];
        final y2 = corrBuffer[bestLagIndex];
        final y3 = corrBuffer[bestLagIndex + 1];
        
        final x0 = (y3 - y1) / (2 * (2 * y2 - y1 - y3));
        final interpolatedLag = bestLag + x0;
        
        return sampleRate / interpolatedLag;
      }
      
      return sampleRate / bestLag;
    }
    
    return 0;
  }
  
  /// SIMD 최적화된 자기상관 계산
  void _computeAutocorrelation(Float32List audio, Float32List corrBuffer, int minLag, int maxLag) {
    final audioLength = audio.length;
    
    for (int lagIndex = 0; lagIndex < corrBuffer.length; lagIndex++) {
      final lag = minLag + lagIndex;
      if (lag >= audioLength) break;
      
      double corr = 0;
      double norm1 = 0;
      double norm2 = 0;
      
      final length = audioLength - lag;
      
      // 벡터화된 내적 계산 (8개씩 처리)
      int i = 0;
      final limit = length - 8;
      
      while (i <= limit) {
        // 8개 요소를 동시에 처리
        final a0 = audio[i], a1 = audio[i + 1], a2 = audio[i + 2], a3 = audio[i + 3];
        final a4 = audio[i + 4], a5 = audio[i + 5], a6 = audio[i + 6], a7 = audio[i + 7];
        
        final b0 = audio[i + lag], b1 = audio[i + lag + 1], b2 = audio[i + lag + 2], b3 = audio[i + lag + 3];
        final b4 = audio[i + lag + 4], b5 = audio[i + lag + 5], b6 = audio[i + lag + 6], b7 = audio[i + lag + 7];
        
        corr += a0 * b0 + a1 * b1 + a2 * b2 + a3 * b3 + a4 * b4 + a5 * b5 + a6 * b6 + a7 * b7;
        norm1 += a0 * a0 + a1 * a1 + a2 * a2 + a3 * a3 + a4 * a4 + a5 * a5 + a6 * a6 + a7 * a7;
        norm2 += b0 * b0 + b1 * b1 + b2 * b2 + b3 * b3 + b4 * b4 + b5 * b5 + b6 * b6 + b7 * b7;
        
        i += 8;
      }
      
      // 나머지 처리
      while (i < length) {
        final a = audio[i];
        final b = audio[i + lag];
        corr += a * b;
        norm1 += a * a;
        norm2 += b * b;
        i++;
      }
      
      // 정규화된 상관계수
      if (norm1 > 1e-10 && norm2 > 1e-10) {
        corrBuffer[lagIndex] = corr / math.sqrt(norm1 * norm2);
      } else {
        corrBuffer[lagIndex] = 0;
      }
    }
  }
  
  /// 이동 평균 필터
  double _applyMovingAverage(double frequency) {
    _pitchHistory.add(frequency);
    
    if (_pitchHistory.length > _historySize) {
      _pitchHistory.removeAt(0);
    }
    
    if (_pitchHistory.isEmpty) return frequency;
    
    // 중간값 필터 (아웃라이어 제거)
    final sorted = List<double>.from(_pitchHistory)..sort();
    return sorted[sorted.length ~/ 2];
  }
  
  /// 가장 가까운 음정으로 스냅
  SnapResult _snapToNearestNote(double frequency) {
    if (frequency <= 0) {
      return SnapResult(noteName: '', cents: 0, snappedFrequency: 0);
    }
    
    String closestNote = '';
    double closestFreq = 0;
    double minCents = double.infinity;
    
    _noteFrequencies.forEach((note, freq) {
      // 센트 계산: 1200 * log2(f1/f2)
      final cents = 1200 * (math.log(frequency / freq) / math.log(2));
      
      if (cents.abs() < minCents.abs()) {
        minCents = cents;
        closestNote = note;
        closestFreq = freq;
      }
    });
    
    return SnapResult(
      noteName: closestNote,
      cents: minCents,
      snappedFrequency: closestFreq,
    );
  }
  
  /// 신뢰도 계산
  double _calculateConfidence(List<dynamic> results, double finalFrequency) {
    if (results.isEmpty) return 0;
    
    // dynamic을 double로 변환
    final doubleResults = results.map((r) => r as double).toList();
    if (results.isEmpty) return 0;
    
    // 결과들의 일치도 계산
    double variance = 0;
    for (final freq in doubleResults) {
      variance += math.pow(freq - finalFrequency, 2);
    }
    variance = math.sqrt(variance / doubleResults.length);
    
    // 변동이 작을수록 신뢰도 높음
    final confidence = math.exp(-variance / 100);
    
    return confidence.clamp(0, 1);
  }
  
  /// 히스토리 초기화
  void reset() {
    _pitchHistory.clear();
  }
}

/// 피치 결과
class PitchResult {
  final double frequency;
  final String noteName;
  final double cents;
  final double confidence;
  final double latencyMs;
  
  PitchResult({
    required this.frequency,
    required this.noteName,
    required this.cents,
    required this.confidence,
    required this.latencyMs,
  });
  
  bool get isAccurate => confidence > 0.8;
  bool get isRealtime => latencyMs < 20;
  
  String get display {
    if (frequency <= 0) return '---';
    
    final centsStr = cents >= 0 ? '+${cents.round()}' : '${cents.round()}';
    return '$noteName ${centsStr}¢';
  }
}

/// 스냅 결과
class SnapResult {
  final String noteName;
  final double cents;
  final double snappedFrequency;
  
  SnapResult({
    required this.noteName,
    required this.cents,
    required this.snappedFrequency,
  });
}