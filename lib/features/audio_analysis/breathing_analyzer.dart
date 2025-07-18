import 'dart:math' as math;
import '../../domain/entities/vocal_analysis.dart';
import '../../domain/entities/audio_data.dart';

class BreathingAnalyzer {
  static const int windowSize = 1024;
  static const double breathingFreqMin = 0.1; // 6 breaths/min
  static const double breathingFreqMax = 0.5; // 30 breaths/min
  
  final int sampleRate;
  
  BreathingAnalyzer({this.sampleRate = 16000});
  
  Future<BreathingType> analyzeBreathing(AudioData audioData) async {
    final samples = audioData.samples;
    
    // 1. 에너지 엔벨로프 추출
    final envelope = _extractEnergyEnvelope(samples);
    
    // 2. 호흡 주기 검출
    final breathingCycles = _detectBreathingCycles(envelope);
    
    // 3. 호흡 패턴 분석
    final pattern = _analyzeBreathingPattern(breathingCycles, samples);
    
    // 4. 호흡 타입 분류
    return _classifyBreathingType(pattern);
  }
  
  Future<double> calculateSpectralTilt(AudioData audioData) async {
    final samples = audioData.samples;
    
    // FFT를 위한 윈도우 선택
    final windowStart = (samples.length - windowSize) ~/ 2;
    final window = samples.sublist(windowStart, windowStart + windowSize);
    
    // Hamming window 적용
    final windowed = _applyHammingWindow(window);
    
    // FFT 수행 (간단한 DFT 구현)
    final spectrum = _computeFFT(windowed);
    
    // 스펙트럼 크기 계산
    final magnitudes = <double>[];
    for (int i = 0; i < spectrum.length ~/ 2; i++) {
      final real = spectrum[i * 2];
      final imag = spectrum[i * 2 + 1];
      magnitudes.add(math.sqrt(real * real + imag * imag));
    }
    
    // 로그 스케일 변환
    final logMagnitudes = magnitudes.map((m) => 
      m > 0 ? 20 * math.log(m) / math.ln10 : -100
    ).toList();
    
    // 선형 회귀로 기울기 계산
    final tilt = _calculateLinearRegression(logMagnitudes.cast<double>());
    
    return tilt;
  }
  
  List<double> _extractEnergyEnvelope(List<double> samples) {
    const frameSize = 512;
    const hopSize = 256;
    final envelope = <double>[];
    
    for (int i = 0; i < samples.length - frameSize; i += hopSize) {
      double energy = 0.0;
      
      for (int j = 0; j < frameSize; j++) {
        energy += samples[i + j] * samples[i + j];
      }
      
      envelope.add(math.sqrt(energy / frameSize));
    }
    
    // 스무딩 적용
    return _smoothEnvelope(envelope, 5);
  }
  
  List<double> _smoothEnvelope(List<double> envelope, int windowSize) {
    final smoothed = List<double>.filled(envelope.length, 0.0);
    
    for (int i = 0; i < envelope.length; i++) {
      double sum = 0.0;
      int count = 0;
      
      for (int j = math.max(0, i - windowSize); 
           j <= math.min(envelope.length - 1, i + windowSize); 
           j++) {
        sum += envelope[j];
        count++;
      }
      
      smoothed[i] = sum / count;
    }
    
    return smoothed;
  }
  
  List<BreathingCycle> _detectBreathingCycles(List<double> envelope) {
    final cycles = <BreathingCycle>[];
    
    // 미분 계산
    final derivatives = <double>[];
    for (int i = 1; i < envelope.length; i++) {
      derivatives.add(envelope[i] - envelope[i - 1]);
    }
    
    // 영교차 검출로 호흡 주기 찾기
    final peaks = <int>[];
    final valleys = <int>[];
    
    for (int i = 1; i < derivatives.length; i++) {
      // Peak: 미분이 양수에서 음수로
      if (derivatives[i - 1] > 0 && derivatives[i] <= 0) {
        peaks.add(i);
      }
      // Valley: 미분이 음수에서 양수로
      else if (derivatives[i - 1] < 0 && derivatives[i] >= 0) {
        valleys.add(i);
      }
    }
    
    // 호흡 사이클 구성
    for (int i = 0; i < math.min(peaks.length, valleys.length) - 1; i++) {
      if (valleys[i] < peaks[i] && peaks[i] < valleys[i + 1]) {
        cycles.add(BreathingCycle(
          inhaleStart: valleys[i],
          peakAmplitude: peaks[i],
          exhaleEnd: valleys[i + 1],
          amplitude: envelope[peaks[i]] - envelope[valleys[i]],
        ));
      }
    }
    
    return cycles;
  }
  
  BreathingPattern _analyzeBreathingPattern(
    List<BreathingCycle> cycles, 
    List<double> samples
  ) {
    if (cycles.isEmpty) {
      return BreathingPattern(
        avgDepth: 0,
        avgRate: 0,
        variability: 0,
        inhaleExhaleRatio: 1,
        chestContribution: 0.5,
        diaphragmContribution: 0.5,
      );
    }
    
    // 평균 깊이 계산
    final depths = cycles.map((c) => c.amplitude).toList();
    final avgDepth = depths.reduce((a, b) => a + b) / depths.length;
    
    // 호흡 속도 계산 (breaths per minute)
    final durations = <double>[];
    for (int i = 1; i < cycles.length; i++) {
      final duration = (cycles[i].inhaleStart - cycles[i - 1].inhaleStart) / 
                      (sampleRate / 256.0); // hop size로 조정
      durations.add(duration);
    }
    
    final avgDuration = durations.isNotEmpty ? 
        durations.reduce((a, b) => a + b) / durations.length : 1.0;
    final avgRate = 60.0 / avgDuration;
    
    // 변동성 계산
    final depthVariance = depths.map((d) => math.pow(d - avgDepth, 2))
        .reduce((a, b) => a + b) / depths.length;
    final variability = math.sqrt(depthVariance) / avgDepth;
    
    // 들숨/날숨 비율
    final ratios = cycles.map((c) {
      final inhaleTime = c.peakAmplitude - c.inhaleStart;
      final exhaleTime = c.exhaleEnd - c.peakAmplitude;
      return inhaleTime / math.max(exhaleTime, 1);
    }).toList();
    
    final inhaleExhaleRatio = ratios.isNotEmpty ?
        ratios.reduce((a, b) => a + b) / ratios.length : 1.0;
    
    // 주파수 분석으로 흉식/복식 비율 추정
    final (chestContrib, diaphragmContrib) = _estimateBreathingMuscles(samples);
    
    return BreathingPattern(
      avgDepth: avgDepth,
      avgRate: avgRate,
      variability: variability,
      inhaleExhaleRatio: inhaleExhaleRatio,
      chestContribution: chestContrib,
      diaphragmContribution: diaphragmContrib,
    );
  }
  
  (double, double) _estimateBreathingMuscles(List<double> samples) {
    // 저주파 성분: 복식호흡 (횡격막)
    // 고주파 성분: 흉식호흡
    
    final lowFreqEnergy = _calculateFrequencyBandEnergy(
      samples, 0.1, 0.3, sampleRate
    );
    final highFreqEnergy = _calculateFrequencyBandEnergy(
      samples, 0.3, 0.5, sampleRate
    );
    
    final totalEnergy = lowFreqEnergy + highFreqEnergy;
    if (totalEnergy == 0) return (0.5, 0.5);
    
    final diaphragmContrib = lowFreqEnergy / totalEnergy;
    final chestContrib = highFreqEnergy / totalEnergy;
    
    return (chestContrib, diaphragmContrib);
  }
  
  double _calculateFrequencyBandEnergy(
    List<double> samples,
    double minFreq,
    double maxFreq,
    int sampleRate,
  ) {
    // 간단한 밴드패스 필터 구현
    double energy = 0.0;
    
    // Butterworth 필터 계수 (2차)
    final omega1 = 2 * math.pi * minFreq / sampleRate;
    final omega2 = 2 * math.pi * maxFreq / sampleRate;
    
    // 필터링 및 에너지 계산
    for (int i = 2; i < samples.length; i++) {
      // 간단한 밴드패스 필터 근사
      final filtered = samples[i] - samples[i - 2];
      energy += filtered * filtered;
    }
    
    return energy;
  }
  
  BreathingType _classifyBreathingType(BreathingPattern pattern) {
    // 복식호흡 특징:
    // - 낮은 호흡 속도 (12-20 bpm)
    // - 깊은 호흡
    // - 낮은 변동성
    // - 횡격막 기여도 높음
    
    if (pattern.diaphragmContribution > 0.7 &&
        pattern.avgRate >= 12 && pattern.avgRate <= 20 &&
        pattern.variability < 0.3) {
      return BreathingType.diaphragmatic;
    }
    
    // 흉식호흡 특징:
    // - 빠른 호흡 속도 (> 20 bpm)
    // - 얕은 호흡
    // - 높은 변동성
    // - 가슴 기여도 높음
    
    if (pattern.chestContribution > 0.7 &&
        (pattern.avgRate > 20 || pattern.variability > 0.5)) {
      return BreathingType.chest;
    }
    
    // 혼합 호흡
    return BreathingType.mixed;
  }
  
  List<double> _applyHammingWindow(List<double> samples) {
    final windowed = List<double>.filled(samples.length, 0.0);
    
    for (int i = 0; i < samples.length; i++) {
      final window = 0.54 - 0.46 * math.cos(2 * math.pi * i / (samples.length - 1));
      windowed[i] = samples[i] * window;
    }
    
    return windowed;
  }
  
  List<double> _computeFFT(List<double> samples) {
    // 간단한 DFT 구현 (실제로는 FFT 라이브러리 사용 권장)
    final n = samples.length;
    final result = List<double>.filled(n * 2, 0.0);
    
    for (int k = 0; k < n; k++) {
      double real = 0.0;
      double imag = 0.0;
      
      for (int t = 0; t < n; t++) {
        final angle = -2 * math.pi * k * t / n;
        real += samples[t] * math.cos(angle);
        imag += samples[t] * math.sin(angle);
      }
      
      result[k * 2] = real;
      result[k * 2 + 1] = imag;
    }
    
    return result;
  }
  
  double _calculateLinearRegression(List<double> data) {
    if (data.length < 2) return 0.0;
    
    final n = data.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    
    for (int i = 0; i < n; i++) {
      final x = i.toDouble();
      final y = data[i];
      
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }
    
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    
    return slope;
  }
}

class BreathingCycle {
  final int inhaleStart;
  final int peakAmplitude;
  final int exhaleEnd;
  final double amplitude;
  
  BreathingCycle({
    required this.inhaleStart,
    required this.peakAmplitude,
    required this.exhaleEnd,
    required this.amplitude,
  });
}

class BreathingPattern {
  final double avgDepth;
  final double avgRate;
  final double variability;
  final double inhaleExhaleRatio;
  final double chestContribution;
  final double diaphragmContribution;
  
  BreathingPattern({
    required this.avgDepth,
    required this.avgRate,
    required this.variability,
    required this.inhaleExhaleRatio,
    required this.chestContribution,
    required this.diaphragmContribution,
  });
}