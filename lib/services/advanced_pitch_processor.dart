import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dual_engine_service.dart';
import '../models/analysis_result.dart';

/// 고도화된 피치 처리 시스템
/// 실시간 FFT, 자동 보정, 하모닉 분석 등 정교한 기능 구현
class AdvancedPitchProcessor {
  final DualEngineService _dualEngine = DualEngineService();
  
  // 캐시 시스템
  final Map<int, _FFTCache> _fftCache = {};
  Timer? _cacheCleanupTimer;
  
  // 칼만 필터 상태 (노이즈 제거용)
  double _kalmanState = 0.0;
  double _kalmanUncertainty = 1.0;
  static const double _kalmanQ = 0.01; // 프로세스 노이즈
  static const double _kalmanR = 0.1;  // 측정 노이즈
  
  AdvancedPitchProcessor() {
    // 캐시 정리 타이머 (5분마다)
    _cacheCleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupCache();
    });
  }
  
  void dispose() {
    _cacheCleanupTimer?.cancel();
  }
  
  /// 고급 피치 분석 (실시간 처리)
  Future<AdvancedPitchResult> analyzeAdvanced(
    Float32List audioData, {
    double sampleRate = 48000.0,
    bool useKalmanFilter = true,
    bool detectVibrato = true,
    bool analyzeFormants = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // 1. 전처리: 노이즈 게이트 + 프리엠퍼시스
      final preprocessed = _preprocess(audioData, sampleRate);
      
      // 2. 실시간 FFT 스펙트럼 계산
      final spectrum = _computeFFTSpectrum(preprocessed, sampleRate);
      
      // 3. 기본 주파수 검출 (여러 알고리즘 앙상블)
      final fundamentalResult = await _detectFundamental(
        preprocessed, 
        spectrum, 
        sampleRate
      );
      
      // 4. 칼만 필터로 노이즈 제거 (옵션)
      double filteredFrequency = fundamentalResult.frequency;
      if (useKalmanFilter && fundamentalResult.frequency > 0) {
        filteredFrequency = _applyKalmanFilter(fundamentalResult.frequency);
      }
      
      // 5. 하모닉 구조 분석
      final harmonics = _analyzeHarmonics(
        spectrum, 
        filteredFrequency,
        sampleRate
      );
      
      // 6. 비브라토 검출 (옵션)
      VibratoInfo? vibratoInfo;
      if (detectVibrato) {
        vibratoInfo = _detectVibratoAdvanced(preprocessed, sampleRate);
      }
      
      // 7. 포먼트 분석 (음색 특성)
      FormantInfo? formantInfo;
      if (analyzeFormants) {
        formantInfo = _analyzeFormants(spectrum, sampleRate);
      }
      
      // 8. 음정 정확도 계산
      final pitchAccuracy = _calculatePitchAccuracy(filteredFrequency);
      
      // 9. 스펙트럴 특징 추출
      final spectralFeatures = _extractSpectralFeatures(spectrum);
      
      stopwatch.stop();
      
      return AdvancedPitchResult(
        frequency: filteredFrequency,
        confidence: fundamentalResult.confidence,
        harmonics: harmonics,
        vibrato: vibratoInfo,
        formants: formantInfo,
        pitchAccuracy: pitchAccuracy,
        spectralFeatures: spectralFeatures,
        processingTimeMs: stopwatch.elapsedMilliseconds.toDouble(),
        timestamp: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('❌ Advanced pitch analysis failed: $e');
      stopwatch.stop();
      
      return AdvancedPitchResult(
        frequency: 0,
        confidence: 0,
        harmonics: [],
        vibrato: null,
        formants: null,
        pitchAccuracy: PitchAccuracy(noteName: '', cents: 0, inTune: false),
        spectralFeatures: SpectralFeatures.empty(),
        processingTimeMs: stopwatch.elapsedMilliseconds.toDouble(),
        timestamp: DateTime.now(),
      );
    }
  }
  
  /// 전처리: 노이즈 게이트 + 프리엠퍼시스
  Float32List _preprocess(Float32List audio, double sampleRate) {
    final processed = Float32List(audio.length);
    
    // 1. 노이즈 게이트 (매우 작은 신호 제거)
    const double noiseGate = 0.01;
    
    // 2. 프리엠퍼시스 필터 (고주파 강조)
    const double preEmphasis = 0.97;
    
    for (int i = 0; i < audio.length; i++) {
      // 노이즈 게이트
      double sample = audio[i].abs() < noiseGate ? 0.0 : audio[i];
      
      // 프리엠퍼시스
      if (i > 0) {
        sample = sample - preEmphasis * audio[i - 1];
      }
      
      processed[i] = sample;
    }
    
    return processed;
  }
  
  /// 실제 FFT 스펙트럼 계산
  FrequencySpectrum _computeFFTSpectrum(
    Float32List audio, 
    double sampleRate
  ) {
    // 캐시 확인
    final cacheKey = audio.hashCode;
    if (_fftCache.containsKey(cacheKey)) {
      final cached = _fftCache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp).inSeconds < 1) {
        return cached.spectrum;
      }
    }
    
    // FFT 크기 (2의 거듭제곱)
    final fftSize = _nextPowerOfTwo(audio.length);
    final paddedAudio = Float32List(fftSize);
    
    // 제로 패딩
    for (int i = 0; i < audio.length && i < fftSize; i++) {
      paddedAudio[i] = audio[i];
    }
    
    // 해밍 윈도우 적용
    _applyHammingWindow(paddedAudio);
    
    // FFT 수행 (Cooley-Tukey 알고리즘)
    final complexData = _performFFT(paddedAudio);
    
    // 파워 스펙트럼 계산
    final spectrum = FrequencySpectrum(
      frequencies: Float32List(fftSize ~/ 2),
      magnitudes: Float32List(fftSize ~/ 2),
      sampleRate: sampleRate,
    );
    
    for (int i = 0; i < fftSize ~/ 2; i++) {
      final real = complexData[i * 2];
      final imag = complexData[i * 2 + 1];
      
      spectrum.frequencies[i] = i * sampleRate / fftSize;
      spectrum.magnitudes[i] = math.sqrt(real * real + imag * imag);
    }
    
    // 캐시 저장
    _fftCache[cacheKey] = _FFTCache(
      spectrum: spectrum,
      timestamp: DateTime.now(),
    );
    
    return spectrum;
  }
  
  /// FFT 구현 (Cooley-Tukey 알고리즘)
  Float32List _performFFT(Float32List data) {
    final n = data.length;
    final complexData = Float32List(n * 2); // real, imag pairs
    
    // 실수 데이터를 복소수로 변환
    for (int i = 0; i < n; i++) {
      complexData[i * 2] = data[i];     // real
      complexData[i * 2 + 1] = 0;       // imag
    }
    
    // Bit-reversal permutation
    int j = 0;
    for (int i = 1; i < n - 1; i++) {
      int bit = n >> 1;
      while (j >= bit) {
        j -= bit;
        bit >>= 1;
      }
      j += bit;
      
      if (i < j) {
        // Swap
        final tempReal = complexData[i * 2];
        final tempImag = complexData[i * 2 + 1];
        complexData[i * 2] = complexData[j * 2];
        complexData[i * 2 + 1] = complexData[j * 2 + 1];
        complexData[j * 2] = tempReal;
        complexData[j * 2 + 1] = tempImag;
      }
    }
    
    // Cooley-Tukey FFT
    for (int len = 2; len <= n; len <<= 1) {
      final halfLen = len >> 1;
      final angleStep = -2 * math.pi / len;
      
      for (int i = 0; i < n; i += len) {
        double angle = 0;
        
        for (int j = 0; j < halfLen; j++) {
          final cos = math.cos(angle);
          final sin = math.sin(angle);
          
          final idx1 = (i + j) * 2;
          final idx2 = (i + j + halfLen) * 2;
          
          final tReal = cos * complexData[idx2] - sin * complexData[idx2 + 1];
          final tImag = sin * complexData[idx2] + cos * complexData[idx2 + 1];
          
          complexData[idx2] = complexData[idx1] - tReal;
          complexData[idx2 + 1] = complexData[idx1 + 1] - tImag;
          
          complexData[idx1] = complexData[idx1] + tReal;
          complexData[idx1 + 1] = complexData[idx1 + 1] + tImag;
          
          angle += angleStep;
        }
      }
    }
    
    return complexData;
  }
  
  /// 기본 주파수 검출 (앙상블 방법)
  Future<FundamentalResult> _detectFundamental(
    Float32List audio,
    FrequencySpectrum spectrum,
    double sampleRate,
  ) async {
    // 1. AI 엔진 결과 (가장 정확)
    DualResult? aiResult;
    try {
      aiResult = await _dualEngine.analyzeDual(audio);
    } catch (e) {
      debugPrint('AI engine failed: $e');
    }
    
    // 2. 자기상관(Autocorrelation) 방법
    final acfFreq = _autocorrelationPitch(audio, sampleRate);
    
    // 3. 스펙트럼 피크 방법
    final peakFreq = _spectralPeakPitch(spectrum);
    
    // 4. Cepstrum 방법
    final cepstrumFreq = _cepstrumPitch(audio, sampleRate);
    
    // 앙상블: 가중 평균
    double frequency = 0;
    double confidence = 0;
    double totalWeight = 0;
    
    if (aiResult != null && aiResult.frequency > 0) {
      frequency += aiResult.frequency * 0.5; // AI 가중치 50%
      confidence += aiResult.confidence * 0.5;
      totalWeight += 0.5;
    }
    
    if (acfFreq > 0) {
      frequency += acfFreq * 0.2; // ACF 가중치 20%
      confidence += 0.8 * 0.2;
      totalWeight += 0.2;
    }
    
    if (peakFreq > 0) {
      frequency += peakFreq * 0.2; // 스펙트럼 가중치 20%
      confidence += 0.7 * 0.2;
      totalWeight += 0.2;
    }
    
    if (cepstrumFreq > 0) {
      frequency += cepstrumFreq * 0.1; // Cepstrum 가중치 10%
      confidence += 0.6 * 0.1;
      totalWeight += 0.1;
    }
    
    if (totalWeight > 0) {
      frequency /= totalWeight;
      confidence /= totalWeight;
    }
    
    return FundamentalResult(
      frequency: frequency,
      confidence: confidence,
      method: 'Ensemble',
    );
  }
  
  /// 자기상관 피치 검출
  double _autocorrelationPitch(Float32List audio, double sampleRate) {
    const int minLag = 20;  // ~2400Hz
    final int maxLag = (sampleRate / 50).round(); // ~50Hz
    
    double maxCorr = 0;
    int bestLag = 0;
    
    for (int lag = minLag; lag < maxLag && lag < audio.length ~/ 2; lag++) {
      double corr = 0;
      double norm1 = 0;
      double norm2 = 0;
      
      for (int i = 0; i < audio.length - lag; i++) {
        corr += audio[i] * audio[i + lag];
        norm1 += audio[i] * audio[i];
        norm2 += audio[i + lag] * audio[i + lag];
      }
      
      // 정규화된 상관계수
      if (norm1 > 0 && norm2 > 0) {
        corr = corr / math.sqrt(norm1 * norm2);
        
        if (corr > maxCorr) {
          maxCorr = corr;
          bestLag = lag;
        }
      }
    }
    
    if (bestLag > 0 && maxCorr > 0.3) {
      return sampleRate / bestLag;
    }
    
    return 0;
  }
  
  /// 스펙트럼 피크 피치 검출
  double _spectralPeakPitch(FrequencySpectrum spectrum) {
    double maxMag = 0;
    double peakFreq = 0;
    
    // 50Hz ~ 2000Hz 범위에서 피크 찾기
    for (int i = 0; i < spectrum.magnitudes.length; i++) {
      final freq = spectrum.frequencies[i];
      if (freq < 50 || freq > 2000) continue;
      
      if (spectrum.magnitudes[i] > maxMag) {
        maxMag = spectrum.magnitudes[i];
        peakFreq = freq;
      }
    }
    
    // Parabolic interpolation for sub-bin accuracy
    final peakIdx = spectrum.frequencies.indexOf(peakFreq);
    if (peakIdx > 0 && peakIdx < spectrum.magnitudes.length - 1) {
      final y1 = spectrum.magnitudes[peakIdx - 1];
      final y2 = spectrum.magnitudes[peakIdx];
      final y3 = spectrum.magnitudes[peakIdx + 1];
      
      final x0 = (y3 - y1) / (2 * (2 * y2 - y1 - y3));
      peakFreq += x0 * (spectrum.frequencies[1] - spectrum.frequencies[0]);
    }
    
    return peakFreq;
  }
  
  /// Cepstrum 피치 검출
  double _cepstrumPitch(Float32List audio, double sampleRate) {
    // 간단한 구현 (실제로는 더 복잡)
    final spectrum = _computeFFTSpectrum(audio, sampleRate);
    
    // 로그 스펙트럼
    final logSpectrum = Float32List(spectrum.magnitudes.length);
    for (int i = 0; i < spectrum.magnitudes.length; i++) {
      logSpectrum[i] = math.log(spectrum.magnitudes[i] + 1e-10);
    }
    
    // IFFT of log spectrum = cepstrum
    // 여기서는 간단히 자기상관으로 대체
    return _autocorrelationPitch(logSpectrum, sampleRate);
  }
  
  /// 칼만 필터 적용
  double _applyKalmanFilter(double measurement) {
    // 예측 단계
    final predictedState = _kalmanState;
    final predictedUncertainty = _kalmanUncertainty + _kalmanQ;
    
    // 업데이트 단계
    final kalmanGain = predictedUncertainty / (predictedUncertainty + _kalmanR);
    _kalmanState = predictedState + kalmanGain * (measurement - predictedState);
    _kalmanUncertainty = (1 - kalmanGain) * predictedUncertainty;
    
    return _kalmanState;
  }
  
  /// 하모닉 구조 분석
  List<HarmonicComponent> _analyzeHarmonics(
    FrequencySpectrum spectrum,
    double fundamental,
    double sampleRate,
  ) {
    if (fundamental <= 0) return [];
    
    final harmonics = <HarmonicComponent>[];
    const int maxHarmonics = 10;
    const double tolerance = 10; // Hz
    
    for (int n = 1; n <= maxHarmonics; n++) {
      final targetFreq = fundamental * n;
      if (targetFreq > sampleRate / 2) break;
      
      // 타겟 주파수 근처에서 피크 찾기
      double peakMag = 0;
      double actualFreq = targetFreq;
      
      for (int i = 0; i < spectrum.frequencies.length; i++) {
        final freq = spectrum.frequencies[i];
        if ((freq - targetFreq).abs() < tolerance) {
          if (spectrum.magnitudes[i] > peakMag) {
            peakMag = spectrum.magnitudes[i];
            actualFreq = freq;
          }
        }
      }
      
      if (peakMag > 0) {
        harmonics.add(HarmonicComponent(
          order: n,
          frequency: actualFreq,
          amplitude: peakMag,
          deviation: actualFreq - targetFreq,
        ));
      }
    }
    
    return harmonics;
  }
  
  /// 고급 비브라토 검출
  VibratoInfo _detectVibratoAdvanced(Float32List audio, double sampleRate) {
    // 짧은 윈도우로 피치 추적
    const int windowSize = 512;
    const int hopSize = 128;
    final pitchContour = <double>[];
    
    for (int i = 0; i < audio.length - windowSize; i += hopSize) {
      final window = audio.sublist(i, i + windowSize);
      final pitch = _autocorrelationPitch(Float32List.fromList(window), sampleRate);
      if (pitch > 0) {
        pitchContour.add(pitch);
      }
    }
    
    if (pitchContour.length < 10) {
      return VibratoInfo(rate: 0, depth: 0, regularity: 0);
    }
    
    // 피치 변동 분석
    final mean = pitchContour.reduce((a, b) => a + b) / pitchContour.length;
    
    // Detrend
    final detrended = pitchContour.map((p) => p - mean).toList();
    
    // 자기상관으로 주기 찾기
    double maxCorr = 0;
    int bestLag = 0;
    
    for (int lag = 5; lag < detrended.length ~/ 2; lag++) {
      double corr = 0;
      for (int i = 0; i < detrended.length - lag; i++) {
        corr += detrended[i] * detrended[i + lag];
      }
      
      if (corr > maxCorr) {
        maxCorr = corr;
        bestLag = lag;
      }
    }
    
    // 비브라토 파라미터 계산
    final vibratoRate = bestLag > 0 ? sampleRate / (bestLag * hopSize) : 0;
    
    // 깊이 (센트 단위)
    double variance = 0;
    for (final p in pitchContour) {
      variance += math.pow(p - mean, 2);
    }
    variance /= pitchContour.length;
    final depth = 1200 * math.log(1 + math.sqrt(variance) / mean) / math.log(2);
    
    // 규칙성 (0~1)
    final regularity = maxCorr / (detrended.length * variance + 1e-10);
    
    return VibratoInfo(
      rate: vibratoRate,
      depth: depth,
      regularity: regularity.clamp(0, 1),
    );
  }
  
  /// 포먼트 분석
  FormantInfo _analyzeFormants(FrequencySpectrum spectrum, double sampleRate) {
    // LPC(선형 예측 코딩) 방법의 간단한 구현
    final peaks = <FormantPeak>[];
    
    // 스펙트럼 포락선 추출
    final envelope = _extractSpectralEnvelope(spectrum);
    
    // 로컬 최대값 찾기
    for (int i = 1; i < envelope.length - 1; i++) {
      if (envelope[i] > envelope[i - 1] && envelope[i] > envelope[i + 1]) {
        final freq = spectrum.frequencies[i];
        
        // 포먼트 범위 체크 (F1: 200-1000Hz, F2: 500-2500Hz, F3: 1500-3500Hz)
        if (freq > 200 && freq < 3500) {
          peaks.add(FormantPeak(
            frequency: freq,
            amplitude: envelope[i],
            bandwidth: _estimateBandwidth(spectrum, i),
          ));
        }
      }
    }
    
    // 상위 3개 포먼트 선택
    peaks.sort((a, b) => b.amplitude.compareTo(a.amplitude));
    
    return FormantInfo(
      f1: peaks.isNotEmpty ? peaks[0].frequency : 0,
      f2: peaks.length > 1 ? peaks[1].frequency : 0,
      f3: peaks.length > 2 ? peaks[2].frequency : 0,
      peaks: peaks.take(5).toList(),
    );
  }
  
  /// 스펙트럼 포락선 추출
  Float32List _extractSpectralEnvelope(FrequencySpectrum spectrum) {
    final envelope = Float32List(spectrum.magnitudes.length);
    const int smoothingWindow = 5;
    
    for (int i = 0; i < spectrum.magnitudes.length; i++) {
      double sum = 0;
      int count = 0;
      
      for (int j = -smoothingWindow; j <= smoothingWindow; j++) {
        final idx = i + j;
        if (idx >= 0 && idx < spectrum.magnitudes.length) {
          sum += spectrum.magnitudes[idx];
          count++;
        }
      }
      
      envelope[i] = count > 0 ? sum / count : 0;
    }
    
    return envelope;
  }
  
  /// 대역폭 추정
  double _estimateBandwidth(FrequencySpectrum spectrum, int peakIdx) {
    final peakMag = spectrum.magnitudes[peakIdx];
    final halfPower = peakMag / math.sqrt(2);
    
    // 3dB 대역폭 찾기
    int leftIdx = peakIdx;
    int rightIdx = peakIdx;
    
    while (leftIdx > 0 && spectrum.magnitudes[leftIdx] > halfPower) {
      leftIdx--;
    }
    
    while (rightIdx < spectrum.magnitudes.length - 1 && 
           spectrum.magnitudes[rightIdx] > halfPower) {
      rightIdx++;
    }
    
    return spectrum.frequencies[rightIdx] - spectrum.frequencies[leftIdx];
  }
  
  /// 음정 정확도 계산
  PitchAccuracy _calculatePitchAccuracy(double frequency) {
    if (frequency <= 0) {
      return PitchAccuracy(noteName: '', cents: 0, inTune: false);
    }
    
    // A4 = 440Hz 기준
    const double a4 = 440.0;
    
    // MIDI 노트 번호 계산
    final midiNote = 69 + 12 * math.log(frequency / a4) / math.log(2);
    final nearestNote = midiNote.round();
    
    // 센트 오차
    final cents = (midiNote - nearestNote) * 100;
    
    // 노트 이름
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final noteName = notes[nearestNote % 12];
    final octave = (nearestNote ~/ 12) - 1;
    
    return PitchAccuracy(
      noteName: '$noteName$octave',
      cents: cents,
      inTune: cents.abs() < 10, // ±10센트 이내면 정확
    );
  }
  
  /// 스펙트럴 특징 추출
  SpectralFeatures _extractSpectralFeatures(FrequencySpectrum spectrum) {
    if (spectrum.magnitudes.isEmpty) {
      return SpectralFeatures.empty();
    }
    
    // 스펙트럴 중심
    double centroid = 0;
    double totalMag = 0;
    
    for (int i = 0; i < spectrum.magnitudes.length; i++) {
      centroid += spectrum.frequencies[i] * spectrum.magnitudes[i];
      totalMag += spectrum.magnitudes[i];
    }
    
    if (totalMag > 0) {
      centroid /= totalMag;
    }
    
    // 스펙트럴 스프레드
    double spread = 0;
    for (int i = 0; i < spectrum.magnitudes.length; i++) {
      spread += math.pow(spectrum.frequencies[i] - centroid, 2) * spectrum.magnitudes[i];
    }
    
    if (totalMag > 0) {
      spread = math.sqrt(spread / totalMag);
    }
    
    // 스펙트럴 플럭스
    double flux = 0;
    // (이전 프레임과 비교 필요 - 여기서는 간단히 구현)
    
    // 스펙트럴 롤오프
    double rolloff = 0;
    double cumSum = 0;
    final threshold = totalMag * 0.85;
    
    for (int i = 0; i < spectrum.magnitudes.length; i++) {
      cumSum += spectrum.magnitudes[i];
      if (cumSum >= threshold) {
        rolloff = spectrum.frequencies[i];
        break;
      }
    }
    
    return SpectralFeatures(
      centroid: centroid,
      spread: spread,
      flux: flux,
      rolloff: rolloff,
      brightness: centroid / 1000, // 정규화
    );
  }
  
  /// 해밍 윈도우 적용
  void _applyHammingWindow(Float32List data) {
    final n = data.length;
    for (int i = 0; i < n; i++) {
      data[i] *= 0.54 - 0.46 * math.cos(2 * math.pi * i / (n - 1));
    }
  }
  
  /// 2의 거듭제곱 찾기
  int _nextPowerOfTwo(int n) {
    int power = 1;
    while (power < n) {
      power *= 2;
    }
    return power;
  }
  
  /// 캐시 정리
  void _cleanupCache() {
    final now = DateTime.now();
    _fftCache.removeWhere((key, cache) => 
      now.difference(cache.timestamp).inMinutes > 5
    );
  }
}

// === 데이터 클래스들 ===

class AdvancedPitchResult {
  final double frequency;
  final double confidence;
  final List<HarmonicComponent> harmonics;
  final VibratoInfo? vibrato;
  final FormantInfo? formants;
  final PitchAccuracy pitchAccuracy;
  final SpectralFeatures spectralFeatures;
  final double processingTimeMs;
  final DateTime timestamp;
  
  AdvancedPitchResult({
    required this.frequency,
    required this.confidence,
    required this.harmonics,
    this.vibrato,
    this.formants,
    required this.pitchAccuracy,
    required this.spectralFeatures,
    required this.processingTimeMs,
    required this.timestamp,
  });
}

class FrequencySpectrum {
  final Float32List frequencies;
  final Float32List magnitudes;
  final double sampleRate;
  
  FrequencySpectrum({
    required this.frequencies,
    required this.magnitudes,
    required this.sampleRate,
  });
}

class FundamentalResult {
  final double frequency;
  final double confidence;
  final String method;
  
  FundamentalResult({
    required this.frequency,
    required this.confidence,
    required this.method,
  });
}

class HarmonicComponent {
  final int order;
  final double frequency;
  final double amplitude;
  final double deviation;
  
  HarmonicComponent({
    required this.order,
    required this.frequency,
    required this.amplitude,
    required this.deviation,
  });
}

class VibratoInfo {
  final double rate;       // Hz
  final double depth;      // cents
  final double regularity; // 0-1
  
  VibratoInfo({
    required this.rate,
    required this.depth,
    required this.regularity,
  });
}

class FormantInfo {
  final double f1;
  final double f2;
  final double f3;
  final List<FormantPeak> peaks;
  
  FormantInfo({
    required this.f1,
    required this.f2,
    required this.f3,
    required this.peaks,
  });
}

class FormantPeak {
  final double frequency;
  final double amplitude;
  final double bandwidth;
  
  FormantPeak({
    required this.frequency,
    required this.amplitude,
    required this.bandwidth,
  });
}

class PitchAccuracy {
  final String noteName;
  final double cents;
  final bool inTune;
  
  PitchAccuracy({
    required this.noteName,
    required this.cents,
    required this.inTune,
  });
}

class SpectralFeatures {
  final double centroid;
  final double spread;
  final double flux;
  final double rolloff;
  final double brightness;
  
  SpectralFeatures({
    required this.centroid,
    required this.spread,
    required this.flux,
    required this.rolloff,
    required this.brightness,
  });
  
  factory SpectralFeatures.empty() {
    return SpectralFeatures(
      centroid: 0,
      spread: 0,
      flux: 0,
      rolloff: 0,
      brightness: 0,
    );
  }
}

class _FFTCache {
  final FrequencySpectrum spectrum;
  final DateTime timestamp;
  
  _FFTCache({
    required this.spectrum,
    required this.timestamp,
  });
}