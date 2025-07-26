import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:fftea/fftea.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import '../../domain/entities/vocal_analysis.dart';
import 'audio_capture_service.dart';

/// 실시간 보컬 분석 엔진
class RealTimeVocalAnalyzer {
  final AudioCaptureService _audioService = AudioCaptureService();
  final PitchDetector _pitchDetector = PitchDetector();
  
  StreamController<VocalAnalysis>? _analysisController;
  StreamSubscription<List<double>>? _audioSubscription;
  
  // 분석 설정
  static const int sampleRate = 16000;
  static const int windowSize = 1024;
  static const int hopSize = 512;
  
  // 분석 상태
  List<double> _audioBuffer = [];
  List<double> _pitchHistory = [];
  List<double> _amplitudeHistory = [];
  bool _isAnalyzing = false;
  
  // 공명 분석을 위한 포먼트 추적
  final List<double> _formantHistory = [];
  
  /// 분석 시작
  Future<void> startAnalysis() async {
    if (_isAnalyzing) return;
    
    try {
      // 오디오 서비스 초기화
      await _audioService.initialize();
      
      // 분석 스트림 생성
      _analysisController = StreamController<VocalAnalysis>.broadcast();
      
      // 오디오 캡처 시작
      await _audioService.startCapture();
      
      // 오디오 스트림 구독
      _audioSubscription = _audioService.audioStream.listen(_processAudioChunk);
      
      _isAnalyzing = true;
      print('🎤 실시간 음성 분석 시작');
      
    } catch (e) {
      print('❌ 음성 분석 시작 실패: $e');
      throw Exception('음성 분석 시작 실패: $e');
    }
  }
  
  /// 분석 중지
  Future<void> stopAnalysis() async {
    if (!_isAnalyzing) return;
    
    _isAnalyzing = false;
    
    await _audioSubscription?.cancel();
    await _audioService.stopCapture();
    await _analysisController?.close();
    
    _audioBuffer.clear();
    _pitchHistory.clear();
    _amplitudeHistory.clear();
    _formantHistory.clear();
    
    print('🛑 음성 분석 중지');
  }
  
  /// 분석 결과 스트림
  Stream<VocalAnalysis> get analysisStream {
    _analysisController ??= StreamController<VocalAnalysis>.broadcast();
    return _analysisController!.stream;
  }
  
  /// 분석 상태
  bool get isAnalyzing => _isAnalyzing;
  
  /// 오디오 청크 처리
  void _processAudioChunk(List<double> chunk) {
    if (!_isAnalyzing) return;
    
    // 버퍼에 추가
    _audioBuffer.addAll(chunk);
    
    // 윈도우 크기만큼 데이터가 쌓이면 분석
    while (_audioBuffer.length >= windowSize) {
      final window = _audioBuffer.take(windowSize).toList();
      _audioBuffer.removeRange(0, hopSize);
      
      _analyzeWindow(window);
    }
  }
  
  /// 윈도우 단위 분석
  void _analyzeWindow(List<double> window) {
    try {
      // 1. 기본 신호 분석
      final amplitude = _calculateRMS(window);
      final pitchResult = _analyzePitch(window);
      
      // 2. 주파수 영역 분석
      final fftResult = _performFFT(window);
      final formants = _extractFormants(fftResult);
      final spectralFeatures = _analyzeSpectralFeatures(fftResult);
      
      // 3. 호흡 패턴 분석
      final breathingType = _analyzeBreathingPattern(amplitude);
      
      // 4. 공명 위치 분석
      final resonancePosition = _analyzeResonancePosition(formants);
      
      // 5. 비브라토 분석
      final vibratoQuality = _analyzeVibrato();
      
      // 6. 종합 점수 계산
      final overallScore = _calculateOverallScore(
        pitchResult.stability,
        amplitude,
        spectralFeatures,
      );
      
      // 7. 분석 결과 생성
      final analysis = VocalAnalysis(
        pitchStability: pitchResult.stability,
        breathingType: breathingType,
        resonancePosition: resonancePosition,
        mouthOpening: _analyzeMouthOpening(formants),
        tonguePosition: _analyzeTonguePosition(formants),
        vibratoQuality: vibratoQuality,
        overallScore: overallScore,
        timestamp: DateTime.now(),
        fundamentalFreq: [pitchResult.frequency],
        formants: formants,
        spectralTilt: spectralFeatures['tilt'] ?? 0.0,
      );
      
      // 분석 결과 전송
      _analysisController?.add(analysis);
      
    } catch (e) {
      print('⚠️ 윈도우 분석 오류: $e');
    }
  }
  
  /// RMS 진폭 계산
  double _calculateRMS(List<double> samples) {
    double sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    return math.sqrt(sum / samples.length);
  }
  
  /// 피치 분석 (자체 구현)
  ({double frequency, double stability}) _analyzePitch(List<double> window) {
    try {
      // 자체 피치 검출 알고리즘 사용
      final frequency = _detectPitchAutocorrelation(window);
      
      // 피치 히스토리에 추가
      if (frequency > 0 && frequency >= 80 && frequency <= 1000) {
        _pitchHistory.add(frequency);
        if (_pitchHistory.length > 50) {
          _pitchHistory.removeAt(0);
        }
      }
      
      // 피치 안정성 계산
      final stability = _calculatePitchStability();
      
      return (frequency: frequency, stability: stability);
      
    } catch (e) {
      return (frequency: 0.0, stability: 0.0);
    }
  }
  
  /// 자동상관을 이용한 피치 검출
  double _detectPitchAutocorrelation(List<double> samples) {
    if (samples.length < 100) return 0.0;
    
    final minPeriod = (sampleRate / 1000).floor(); // 1000Hz 최대
    final maxPeriod = (sampleRate / 80).floor(); // 80Hz 최소
    
    double maxCorrelation = 0.0;
    int bestPeriod = 0;
    
    for (int period = minPeriod; period <= maxPeriod && period < samples.length ~/ 2; period++) {
      double correlation = 0.0;
      int count = 0;
      
      for (int i = 0; i < samples.length - period; i++) {
        correlation += samples[i] * samples[i + period];
        count++;
      }
      
      if (count > 0) {
        correlation /= count;
        
        if (correlation > maxCorrelation) {
          maxCorrelation = correlation;
          bestPeriod = period;
        }
      }
    }
    
    // 임계값 확인
    if (maxCorrelation > 0.3 && bestPeriod > 0) {
      return sampleRate / bestPeriod;
    }
    
    return 0.0;
  }
  
  /// Hamming 윈도우 적용
  List<double> _applyHammingWindow(List<double> samples) {
    final windowed = <double>[];
    final n = samples.length;
    
    for (int i = 0; i < n; i++) {
      final windowValue = 0.54 - 0.46 * math.cos(2 * math.pi * i / (n - 1));
      windowed.add(samples[i] * windowValue);
    }
    
    return windowed;
  }
  
  /// 피치 안정성 계산
  double _calculatePitchStability() {
    if (_pitchHistory.length < 10) return 0.0;
    
    final recent = _pitchHistory.take(10).toList();
    final mean = recent.reduce((a, b) => a + b) / recent.length;
    
    double variance = 0.0;
    for (final pitch in recent) {
      variance += math.pow(pitch - mean, 2);
    }
    variance /= recent.length;
    
    final standardDeviation = math.sqrt(variance);
    
    // 안정성을 0-1 스케일로 변환 (표준편차가 작을수록 안정적)
    return math.max(0.0, 1.0 - (standardDeviation / 50.0));
  }
  
  /// 간단한 스펙트럼 분석
  List<double> _performFFT(List<double> samples) {
    // 간단한 파워 스펙트럼 계산 (FFT 대신)
    final magnitude = <double>[];
    final bins = 64; // 스펙트럼 빈 수
    
    for (int bin = 0; bin < bins; bin++) {
      double power = 0.0;
      final binStart = (bin * samples.length / bins).floor();
      final binEnd = ((bin + 1) * samples.length / bins).floor();
      
      for (int i = binStart; i < binEnd && i < samples.length; i++) {
        power += samples[i] * samples[i];
      }
      
      magnitude.add(math.sqrt(power / (binEnd - binStart)));
    }
    
    return magnitude;
  }
  
  /// 포먼트 추출
  List<double> _extractFormants(List<double> spectrum) {
    final formants = <double>[];
    
    // 주파수 빈 계산
    final freqPerBin = sampleRate / 2.0 / spectrum.length;
    
    // 피크 찾기 (첫 3개 포먼트)
    final peaks = _findPeaks(spectrum, minDistance: 10);
    
    for (int i = 0; i < math.min(3, peaks.length); i++) {
      final formantFreq = peaks[i] * freqPerBin;
      if (formantFreq >= 200 && formantFreq <= 3000) {
        formants.add(formantFreq);
      }
    }
    
    // 부족한 포먼트는 기본값으로 채움
    while (formants.length < 3) {
      formants.add(0.0);
    }
    
    return formants;
  }
  
  /// 스펙트럼에서 피크 찾기
  List<int> _findPeaks(List<double> spectrum, {int minDistance = 5}) {
    final peaks = <int>[];
    
    for (int i = minDistance; i < spectrum.length - minDistance; i++) {
      bool isPeak = true;
      
      // 주변보다 큰지 확인
      for (int j = -minDistance; j <= minDistance; j++) {
        if (j != 0 && spectrum[i] <= spectrum[i + j]) {
          isPeak = false;
          break;
        }
      }
      
      if (isPeak && spectrum[i] > 0.1) { // 임계값 적용
        peaks.add(i);
      }
    }
    
    // 크기순으로 정렬
    peaks.sort((a, b) => spectrum[b].compareTo(spectrum[a]));
    
    return peaks;
  }
  
  /// 스펙트럼 특성 분석
  Map<String, double> _analyzeSpectralFeatures(List<double> spectrum) {
    // 스펙트럼 기울기 계산
    double tilt = 0.0;
    if (spectrum.length > 10) {
      final lowFreq = spectrum.take(spectrum.length ~/ 4).reduce((a, b) => a + b);
      final highFreq = spectrum.skip(spectrum.length * 3 ~/ 4).reduce((a, b) => a + b);
      tilt = (highFreq - lowFreq) / lowFreq;
    }
    
    // 스펙트럼 중심 계산
    double centroid = 0.0;
    double totalMagnitude = 0.0;
    
    for (int i = 0; i < spectrum.length; i++) {
      centroid += i * spectrum[i];
      totalMagnitude += spectrum[i];
    }
    
    if (totalMagnitude > 0) {
      centroid /= totalMagnitude;
    }
    
    return {
      'tilt': tilt,
      'centroid': centroid,
    };
  }
  
  /// 호흡 패턴 분석
  BreathingType _analyzeBreathingPattern(double amplitude) {
    _amplitudeHistory.add(amplitude);
    if (_amplitudeHistory.length > 100) {
      _amplitudeHistory.removeAt(0);
    }
    
    if (_amplitudeHistory.length < 20) return BreathingType.chest;
    
    // 진폭 변화의 규칙성 분석
    final recentAmplitudes = _amplitudeHistory.take(20).toList();
    final variance = _calculateVariance(recentAmplitudes);
    
    // 낮은 분산 = 안정적인 호흡 = 복식호흡
    if (variance < 0.01) {
      return BreathingType.diaphragmatic;
    } else if (variance < 0.05) {
      return BreathingType.mixed;
    } else {
      return BreathingType.chest;
    }
  }
  
  /// 공명 위치 분석
  ResonancePosition _analyzeResonancePosition(List<double> formants) {
    if (formants.length < 2) return ResonancePosition.throat;
    
    final f1 = formants[0];
    final f2 = formants[1];
    
    // 포먼트 비율을 기반으로 공명 위치 추정
    if (f1 < 400 && f2 < 1000) {
      return ResonancePosition.throat;
    } else if (f1 > 400 && f2 > 1000 && f2 < 2000) {
      return ResonancePosition.mouth;
    } else if (f2 > 2000) {
      return ResonancePosition.head;
    } else {
      return ResonancePosition.mixed;
    }
  }
  
  /// 입 모양 분석
  MouthOpening _analyzeMouthOpening(List<double> formants) {
    if (formants.isEmpty) return MouthOpening.medium;
    
    final f1 = formants[0];
    
    if (f1 < 350) {
      return MouthOpening.narrow;
    } else if (f1 > 650) {
      return MouthOpening.wide;
    } else {
      return MouthOpening.medium;
    }
  }
  
  /// 혀 위치 분석
  TonguePosition _analyzeTonguePosition(List<double> formants) {
    if (formants.length < 2) return TonguePosition.lowFront;
    
    final f1 = formants[0];
    final f2 = formants[1];
    
    if (f1 < 400 && f2 > 1800) {
      return TonguePosition.highFront;
    } else if (f1 < 400 && f2 < 1200) {
      return TonguePosition.highBack;
    } else if (f1 > 600 && f2 > 1400) {
      return TonguePosition.lowFront;
    } else {
      return TonguePosition.lowBack;
    }
  }
  
  /// 비브라토 분석
  VibratoQuality _analyzeVibrato() {
    if (_pitchHistory.length < 30) return VibratoQuality.none;
    
    // 최근 30개 피치 값에서 진동 분석
    final recent = _pitchHistory.takeLast(30).toList();
    
    // 주파수 변화의 주기성 검사
    int oscillations = 0;
    for (int i = 1; i < recent.length - 1; i++) {
      if ((recent[i] > recent[i-1] && recent[i] > recent[i+1]) ||
          (recent[i] < recent[i-1] && recent[i] < recent[i+1])) {
        oscillations++;
      }
    }
    
    final oscillationRate = oscillations / recent.length;
    
    if (oscillationRate < 0.1) {
      return VibratoQuality.none;
    } else if (oscillationRate < 0.2) {
      return VibratoQuality.light;
    } else if (oscillationRate < 0.4) {
      return VibratoQuality.medium;
    } else {
      return VibratoQuality.heavy;
    }
  }
  
  /// 종합 점수 계산
  int _calculateOverallScore(double pitchStability, double amplitude, Map<String, double> spectralFeatures) {
    double score = 0.0;
    
    // 피치 안정성 (40점)
    score += pitchStability * 40;
    
    // 음량 적절성 (20점)
    final amplitudeScore = amplitude > 0.1 && amplitude < 0.8 ? 1.0 : 0.5;
    score += amplitudeScore * 20;
    
    // 스펙트럼 품질 (40점)
    final spectralScore = math.max(0.0, 1.0 - (spectralFeatures['tilt']?.abs() ?? 1.0));
    score += spectralScore * 40;
    
    return score.round().clamp(0, 100);
  }
  
  /// 분산 계산
  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    double sum = 0.0;
    
    for (final value in values) {
      sum += math.pow(value - mean, 2);
    }
    
    return sum / values.length;
  }
  
  /// 리소스 정리
  void dispose() {
    stopAnalysis();
    _audioService.dispose();
  }
}

/// List 확장 메서드
extension ListExtension<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return sublist(length - count);
  }
}