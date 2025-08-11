import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:collection';

/// Voice Activity Detection (VAD) Service
/// 음성 활동 감지로 무성 구간 스킵 → 연산량 20-40% 절감
class VADService {
  // VAD 파라미터
  static const double kEnergyThresholdMin = 0.001;
  static const double kEnergyThresholdMax = 0.1;
  static const double kZCRThresholdUnvoiced = 0.3;
  static const double kZCRThresholdVoiced = 0.1;
  static const int kHangoverFrames = 10;
  static const int kLookaheadFrames = 3;
  static const int kSmoothingFrames = 5;
  
  // 스펙트럼 기반 VAD 파라미터
  static const double kSpectralCentroidThreshold = 500.0; // Hz
  static const double kSpectralFlatnessThreshold = 0.5;
  static const double kSpectralRolloffThreshold = 0.85;
  
  // 적응형 임계값
  double _adaptiveEnergyThreshold = 0.01;
  double _noiseFloor = 0.0;
  double _signalPeak = 1.0;
  
  // 상태 추적
  bool _isVoiceActive = false;
  int _hangoverCounter = 0;
  int _silenceCounter = 0;
  int _voiceCounter = 0;
  
  // 버퍼
  final Queue<double> _energyBuffer = Queue<double>();
  final Queue<double> _zcrBuffer = Queue<double>();
  final Queue<bool> _vadBuffer = Queue<bool>();
  
  // 통계
  int _totalFrames = 0;
  int _voicedFrames = 0;
  int _processedFrames = 0;
  double _computationSaved = 0.0;
  
  /// VAD 초기화
  Future<void> initialize() async {
    print('🎙️ VAD 서비스 초기화');
    await calibrateNoiseFloor();
  }
  
  /// 노이즈 플로어 캘리브레이션
  Future<void> calibrateNoiseFloor({List<double>? samples}) async {
    if (samples != null && samples.isNotEmpty) {
      // 제공된 샘플로 캘리브레이션
      final energies = <double>[];
      const frameSize = 512;
      
      for (int i = 0; i < samples.length - frameSize; i += frameSize) {
        final frame = samples.sublist(i, i + frameSize);
        energies.add(_calculateEnergy(frame));
      }
      
      if (energies.isNotEmpty) {
        energies.sort();
        _noiseFloor = energies[energies.length ~/ 4]; // 25 퍼센타일
        _adaptiveEnergyThreshold = _noiseFloor * 3.0;
        
        print('✅ 노이즈 플로어 캘리브레이션 완료');
        print('📊 Noise Floor: ${_noiseFloor.toStringAsFixed(6)}');
        print('📊 Adaptive Threshold: ${_adaptiveEnergyThreshold.toStringAsFixed(6)}');
      }
    }
  }
  
  /// 메인 VAD 처리
  VADResult processFrame(List<double> frame) {
    _totalFrames++;
    
    // 1. 기본 특징 추출
    final energy = _calculateEnergy(frame);
    final zcr = _calculateZCR(frame);
    final spectralFeatures = _extractSpectralFeatures(frame);
    
    // 2. 버퍼 업데이트
    _updateBuffers(energy, zcr);
    
    // 3. 적응형 임계값 업데이트
    _updateAdaptiveThreshold(energy);
    
    // 4. 멀티모달 VAD 결정
    final decision = _makeVADDecision(
      energy: energy,
      zcr: zcr,
      spectralCentroid: spectralFeatures.centroid,
      spectralFlatness: spectralFeatures.flatness,
    );
    
    // 5. 후처리 (행오버, 스무딩)
    final finalDecision = _postProcessDecision(decision);
    
    // 6. 통계 업데이트
    if (finalDecision.isVoiced) {
      _voicedFrames++;
      _processedFrames++;
    } else {
      // 무성 구간은 처리 스킵
      _computationSaved++;
    }
    
    // 7. 성능 리포트 (매 100 프레임마다)
    if (_totalFrames % 100 == 0) {
      final reductionRate = (_computationSaved / _totalFrames) * 100;
      print('📊 VAD 연산 절감률: ${reductionRate.toStringAsFixed(1)}%');
      print('📊 음성 프레임 비율: ${(_voicedFrames * 100.0 / _totalFrames).toStringAsFixed(1)}%');
    }
    
    return finalDecision;
  }
  
  /// 에너지 계산 (RMS)
  double _calculateEnergy(List<double> frame) {
    double sum = 0;
    for (final sample in frame) {
      sum += sample * sample;
    }
    return math.sqrt(sum / frame.length);
  }
  
  /// Zero Crossing Rate 계산
  double _calculateZCR(List<double> frame) {
    int crossings = 0;
    for (int i = 1; i < frame.length; i++) {
      if ((frame[i] >= 0) != (frame[i-1] >= 0)) {
        crossings++;
      }
    }
    return crossings / frame.length;
  }
  
  /// 스펙트럼 특징 추출
  SpectralFeatures _extractSpectralFeatures(List<double> frame) {
    // 간단한 FFT (DFT) 구현
    final fftSize = frame.length;
    final spectrum = <double>[];
    
    // 실제로는 FFT 라이브러리 사용 권장
    for (int k = 0; k < fftSize ~/ 2; k++) {
      double real = 0;
      double imag = 0;
      
      for (int n = 0; n < fftSize; n++) {
        final angle = -2 * math.pi * k * n / fftSize;
        real += frame[n] * math.cos(angle);
        imag += frame[n] * math.sin(angle);
      }
      
      spectrum.add(math.sqrt(real * real + imag * imag));
    }
    
    // Spectral Centroid (무게 중심 주파수)
    double centroid = 0;
    double totalMagnitude = 0;
    
    for (int i = 0; i < spectrum.length; i++) {
      final freq = i * 48000.0 / fftSize;
      centroid += freq * spectrum[i];
      totalMagnitude += spectrum[i];
    }
    
    if (totalMagnitude > 0) {
      centroid /= totalMagnitude;
    }
    
    // Spectral Flatness (평탄도)
    double geometricMean = 1;
    double arithmeticMean = 0;
    int count = 0;
    
    for (final mag in spectrum) {
      if (mag > 0) {
        geometricMean *= math.pow(mag, 1.0 / spectrum.length);
        arithmeticMean += mag;
        count++;
      }
    }
    
    arithmeticMean /= count;
    final flatness = arithmeticMean > 0 ? geometricMean / arithmeticMean : 0;
    
    return SpectralFeatures(
      centroid: centroid,
      flatness: flatness,
      rolloff: 0.85, // 간단화를 위해 고정값
    );
  }
  
  /// 버퍼 업데이트
  void _updateBuffers(double energy, double zcr) {
    _energyBuffer.add(energy);
    if (_energyBuffer.length > kSmoothingFrames) {
      _energyBuffer.removeFirst();
    }
    
    _zcrBuffer.add(zcr);
    if (_zcrBuffer.length > kSmoothingFrames) {
      _zcrBuffer.removeFirst();
    }
  }
  
  /// 적응형 임계값 업데이트
  void _updateAdaptiveThreshold(double energy) {
    // 이동 평균으로 천천히 조정
    const alpha = 0.98; // 슬로우 업데이트
    
    if (!_isVoiceActive) {
      // 무음 구간에서만 노이즈 플로어 업데이트
      _noiseFloor = alpha * _noiseFloor + (1 - alpha) * energy;
      _adaptiveEnergyThreshold = _noiseFloor * 3.0;
    } else {
      // 음성 구간에서 피크 추적
      if (energy > _signalPeak) {
        _signalPeak = energy;
      }
    }
  }
  
  /// 멀티모달 VAD 결정
  VADDecision _makeVADDecision({
    required double energy,
    required double zcr,
    required double spectralCentroid,
    required double spectralFlatness,
  }) {
    // 각 특징에 대한 투표
    int votes = 0;
    double confidence = 0;
    
    // 1. 에너지 기반 투표
    if (energy > _adaptiveEnergyThreshold) {
      votes++;
      confidence += 0.3;
    }
    
    // 2. ZCR 기반 투표 (낮은 ZCR = 음성)
    if (zcr < kZCRThresholdVoiced) {
      votes++;
      confidence += 0.2;
    } else if (zcr > kZCRThresholdUnvoiced) {
      votes--;
      confidence -= 0.1;
    }
    
    // 3. 스펙트럼 중심 주파수 (음성은 보통 200-3000Hz)
    if (spectralCentroid > 200 && spectralCentroid < 3000) {
      votes++;
      confidence += 0.25;
    }
    
    // 4. 스펙트럼 평탄도 (음성은 낮은 평탄도)
    if (spectralFlatness < kSpectralFlatnessThreshold) {
      votes++;
      confidence += 0.25;
    }
    
    // 최종 결정
    final isVoiced = votes >= 2; // 과반수 투표
    confidence = confidence.clamp(0, 1);
    
    return VADDecision(
      isVoiced: isVoiced,
      confidence: confidence,
      energy: energy,
      zcr: zcr,
    );
  }
  
  /// 후처리 (Hangover, Smoothing)
  VADResult _postProcessDecision(VADDecision decision) {
    // Hangover 로직: 음성 종료 후 일정 프레임 유지
    if (decision.isVoiced) {
      _isVoiceActive = true;
      _hangoverCounter = kHangoverFrames;
      _voiceCounter++;
      _silenceCounter = 0;
    } else {
      _silenceCounter++;
      
      if (_hangoverCounter > 0) {
        _hangoverCounter--;
        _isVoiceActive = true; // Hangover 기간 중에는 음성 유지
      } else {
        _isVoiceActive = false;
        _voiceCounter = 0;
      }
    }
    
    // 스무딩: 짧은 무음 구간 무시
    _vadBuffer.add(_isVoiceActive);
    if (_vadBuffer.length > kSmoothingFrames) {
      _vadBuffer.removeFirst();
    }
    
    // 버퍼의 과반수가 음성이면 음성으로 판단
    final voicedCount = _vadBuffer.where((v) => v).length;
    final smoothedDecision = voicedCount > kSmoothingFrames ~/ 2;
    
    // 최종 결과
    return VADResult(
      isVoiced: smoothedDecision,
      confidence: decision.confidence,
      energy: decision.energy,
      zcr: decision.zcr,
      hangoverRemaining: _hangoverCounter,
      consecutiveSilence: _silenceCounter,
      consecutiveVoice: _voiceCounter,
    );
  }
  
  /// 통계 획듍
  VADStatistics getStatistics() {
    return VADStatistics(
      totalFrames: _totalFrames,
      voicedFrames: _voicedFrames,
      processedFrames: _processedFrames,
      computationSaved: _computationSaved / _totalFrames,
      voiceActivityRatio: _voicedFrames / math.max(1, _totalFrames),
      noiseFloor: _noiseFloor,
      adaptiveThreshold: _adaptiveEnergyThreshold,
    );
  }
  
  /// 리셋
  void reset() {
    _isVoiceActive = false;
    _hangoverCounter = 0;
    _silenceCounter = 0;
    _voiceCounter = 0;
    _energyBuffer.clear();
    _zcrBuffer.clear();
    _vadBuffer.clear();
    _totalFrames = 0;
    _voicedFrames = 0;
    _processedFrames = 0;
    _computationSaved = 0;
  }
  
  /// 고급 VAD: 기계학습 기반 (TFLite 모델 사용 시)
  Future<VADResult> processFrameML(List<double> frame) async {
    // TODO: WebRTC VAD 또는 경량 ML 모델 통합
    // 현재는 기본 알고리즘 사용
    return processFrame(frame);
  }
}

/// 스펙트럼 특징
class SpectralFeatures {
  final double centroid;  // 주파수 무게 중심
  final double flatness;  // 스펙트럼 평탄도
  final double rolloff;   // 에너지 85% 지점
  
  const SpectralFeatures({
    required this.centroid,
    required this.flatness,
    required this.rolloff,
  });
}

/// VAD 결정 (내부용)
class VADDecision {
  final bool isVoiced;
  final double confidence;
  final double energy;
  final double zcr;
  
  const VADDecision({
    required this.isVoiced,
    required this.confidence,
    required this.energy,
    required this.zcr,
  });
}

/// VAD 결과
class VADResult {
  final bool isVoiced;
  final double confidence;
  final double energy;
  final double zcr;
  final int hangoverRemaining;
  final int consecutiveSilence;
  final int consecutiveVoice;
  
  const VADResult({
    required this.isVoiced,
    required this.confidence,
    required this.energy,
    required this.zcr,
    required this.hangoverRemaining,
    required this.consecutiveSilence,
    required this.consecutiveVoice,
  });
  
  /// 처리 스킵 여부 결정
  bool get shouldSkipProcessing => !isVoiced && consecutiveSilence > 3;
  
  /// 음성 시작 감지
  bool get isVoiceOnset => isVoiced && consecutiveVoice == 1;
  
  /// 음성 종료 감지
  bool get isVoiceOffset => !isVoiced && consecutiveSilence == 1;
}

/// VAD 통계
class VADStatistics {
  final int totalFrames;
  final int voicedFrames;
  final int processedFrames;
  final double computationSaved;
  final double voiceActivityRatio;
  final double noiseFloor;
  final double adaptiveThreshold;
  
  const VADStatistics({
    required this.totalFrames,
    required this.voicedFrames,
    required this.processedFrames,
    required this.computationSaved,
    required this.voiceActivityRatio,
    required this.noiseFloor,
    required this.adaptiveThreshold,
  });
  
  @override
  String toString() {
    return '''
VAD Statistics:
  Total Frames: $totalFrames
  Voiced Frames: $voicedFrames (${(voiceActivityRatio * 100).toStringAsFixed(1)}%)
  Processed Frames: $processedFrames
  Computation Saved: ${(computationSaved * 100).toStringAsFixed(1)}%
  Noise Floor: ${noiseFloor.toStringAsFixed(6)}
  Adaptive Threshold: ${adaptiveThreshold.toStringAsFixed(6)}
''';
  }
}