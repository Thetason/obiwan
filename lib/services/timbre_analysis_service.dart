import 'dart:typed_data';
import 'dart:math' as math;

/// 음색 분석 결과
class TimbreResult {
  final double brightness;        // 밝기 (0.0 ~ 1.0)
  final double warmth;            // 따뜻함 (0.0 ~ 1.0)
  final double tension;           // 성대 긴장도 (0.0 ~ 1.0)
  final double breathiness;       // 숨소리 정도 (0.0 ~ 1.0)
  final List<double> formants;   // 포먼트 주파수들
  final double spectralCentroid; // 스펙트럴 센트로이드
  final String voiceType;        // 음색 타입 (맑은, 허스키, 부드러운 등)
  
  TimbreResult({
    required this.brightness,
    required this.warmth,
    required this.tension,
    required this.breathiness,
    required this.formants,
    required this.spectralCentroid,
    required this.voiceType,
  });
}

/// 음색(Timbre) 분석 서비스
/// 포먼트 주파수, 스펙트럴 센트로이드, 성대 긴장도 등을 분석
class TimbreAnalysisService {
  static final TimbreAnalysisService _instance = TimbreAnalysisService._internal();
  factory TimbreAnalysisService() => _instance;
  TimbreAnalysisService._internal();
  
  static TimbreAnalysisService get instance => _instance;
  
  /// 오디오 샘플에서 음색 분석
  Future<TimbreResult> analyzeTimbre(Float32List audioData, double sampleRate) async {
    if (audioData.isEmpty) {
      return _getDefaultResult();
    }
    
    // FFT를 위한 준비
    final fftSize = _getNextPowerOfTwo(audioData.length);
    final paddedData = _padToSize(audioData, fftSize);
    
    // 스펙트럼 분석
    final spectrum = await _computeFFT(paddedData);
    
    // 포먼트 추출 (F1, F2, F3)
    final formants = _extractFormants(spectrum, sampleRate);
    
    // 스펙트럴 센트로이드 계산
    final spectralCentroid = _calculateSpectralCentroid(spectrum, sampleRate);
    
    // 음색 특징 계산
    final brightness = _calculateBrightness(spectralCentroid);
    final warmth = _calculateWarmth(formants);
    final tension = _calculateTension(formants, spectrum);
    final breathiness = _calculateBreathiness(spectrum);
    
    // 음색 타입 결정
    final voiceType = _determineVoiceType(brightness, warmth, tension, breathiness);
    
    return TimbreResult(
      brightness: brightness,
      warmth: warmth,
      tension: tension,
      breathiness: breathiness,
      formants: formants,
      spectralCentroid: spectralCentroid,
      voiceType: voiceType,
    );
  }
  
  /// FFT 계산 (최적화된 버전 - 필요한 주파수만 계산)
  Future<List<double>> _computeFFT(Float32List data) async {
    final n = data.length;
    // 음성 분석에 필요한 주파수 범위만 계산 (0-5000Hz)
    final maxFreqBin = math.min((5000 * n / 48000).round(), n ~/ 2);
    final spectrum = List<double>.filled(maxFreqBin, 0.0);
    
    // 샘플링하여 계산 부하 감소 (매 10번째 주파수만 계산)
    final step = 10;
    for (int k = 0; k < maxFreqBin; k += step) {
      double real = 0.0;
      double imag = 0.0;
      
      // 데이터도 샘플링하여 계산 (매 4번째 샘플만 사용)
      for (int t = 0; t < n; t += 4) {
        final angle = -2 * math.pi * k * t / n;
        real += data[t] * math.cos(angle);
        imag += data[t] * math.sin(angle);
      }
      
      spectrum[k] = math.sqrt(real * real + imag * imag);
      
      // 사이값 보간
      if (k > 0 && k < maxFreqBin - step) {
        for (int i = 1; i < step && k + i < maxFreqBin; i++) {
          spectrum[k + i] = spectrum[k];
        }
      }
    }
    
    return spectrum;
  }
  
  /// 포먼트 주파수 추출
  List<double> _extractFormants(List<double> spectrum, double sampleRate) {
    final formants = <double>[];
    final freqResolution = sampleRate / (spectrum.length * 2);
    
    // 피크 찾기
    final peaks = <int>[];
    for (int i = 1; i < spectrum.length - 1; i++) {
      if (spectrum[i] > spectrum[i - 1] && spectrum[i] > spectrum[i + 1]) {
        peaks.add(i);
      }
    }
    
    // 상위 3개 피크를 포먼트로 간주
    peaks.sort((a, b) => spectrum[b].compareTo(spectrum[a]));
    
    for (int i = 0; i < math.min(3, peaks.length); i++) {
      formants.add(peaks[i] * freqResolution);
    }
    
    // 포먼트가 부족하면 기본값 추가
    while (formants.length < 3) {
      formants.add(0.0);
    }
    
    formants.sort();
    return formants;
  }
  
  /// 스펙트럴 센트로이드 계산
  double _calculateSpectralCentroid(List<double> spectrum, double sampleRate) {
    double weightedSum = 0.0;
    double magnitudeSum = 0.0;
    final freqResolution = sampleRate / (spectrum.length * 2);
    
    for (int i = 0; i < spectrum.length; i++) {
      final frequency = i * freqResolution;
      weightedSum += frequency * spectrum[i];
      magnitudeSum += spectrum[i];
    }
    
    if (magnitudeSum == 0) return 0.0;
    return weightedSum / magnitudeSum;
  }
  
  /// 밝기 계산 (스펙트럴 센트로이드 기반)
  double _calculateBrightness(double spectralCentroid) {
    // 센트로이드가 높을수록 밝은 음색
    // 일반적으로 1000Hz ~ 5000Hz 범위
    final normalized = (spectralCentroid - 1000) / 4000;
    return normalized.clamp(0.0, 1.0);
  }
  
  /// 따뜻함 계산 (낮은 포먼트 기반)
  double _calculateWarmth(List<double> formants) {
    if (formants.isEmpty) return 0.5;
    
    // F1이 낮고 F2-F1 간격이 클수록 따뜻한 음색
    final f1 = formants[0];
    final f2 = formants.length > 1 ? formants[1] : f1;
    
    final lowF1Score = math.max(0, (800 - f1) / 800);
    final spacingScore = math.min(1, (f2 - f1) / 1000);
    
    return ((lowF1Score + spacingScore) / 2).clamp(0.0, 1.0);
  }
  
  /// 성대 긴장도 계산
  double _calculateTension(List<double> formants, List<double> spectrum) {
    // 높은 포먼트와 고주파 에너지가 많을수록 긴장도 높음
    double highFreqEnergy = 0.0;
    double totalEnergy = 0.0;
    
    final midPoint = spectrum.length ~/ 2;
    for (int i = 0; i < spectrum.length; i++) {
      totalEnergy += spectrum[i];
      if (i > midPoint) {
        highFreqEnergy += spectrum[i];
      }
    }
    
    if (totalEnergy == 0) return 0.0;
    
    final highFreqRatio = highFreqEnergy / totalEnergy;
    
    // F3가 높을수록 긴장도 증가
    final f3Tension = formants.length > 2 
        ? math.min(1, formants[2] / 4000)
        : 0.0;
    
    return ((highFreqRatio + f3Tension) / 2).clamp(0.0, 1.0);
  }
  
  /// 숨소리 정도 계산
  double _calculateBreathiness(List<double> spectrum) {
    // 고주파 노이즈 성분이 많을수록 숨소리가 많음
    double noiseEnergy = 0.0;
    double harmonicEnergy = 0.0;
    
    for (int i = 0; i < spectrum.length; i++) {
      if (i < spectrum.length * 0.3) {
        harmonicEnergy += spectrum[i];
      } else {
        noiseEnergy += spectrum[i];
      }
    }
    
    if (harmonicEnergy + noiseEnergy == 0) return 0.0;
    
    return (noiseEnergy / (harmonicEnergy + noiseEnergy)).clamp(0.0, 1.0);
  }
  
  /// 음색 타입 결정
  String _determineVoiceType(double brightness, double warmth, double tension, double breathiness) {
    if (breathiness > 0.6) {
      return '허스키한 음색';
    } else if (brightness > 0.7 && tension < 0.3) {
      return '맑고 깨끗한 음색';
    } else if (warmth > 0.7 && tension < 0.4) {
      return '따뜻하고 부드러운 음색';
    } else if (tension > 0.7) {
      return '긴장된 음색 (목에 힘이 들어감)';
    } else if (brightness < 0.3 && warmth > 0.5) {
      return '깊고 풍부한 음색';
    } else {
      return '균형잡힌 음색';
    }
  }
  
  /// 다음 2의 거듭제곱 찾기
  int _getNextPowerOfTwo(int n) {
    int power = 1;
    while (power < n) {
      power *= 2;
    }
    return power;
  }
  
  /// 패딩 추가
  Float32List _padToSize(Float32List data, int size) {
    final padded = Float32List(size);
    for (int i = 0; i < math.min(data.length, size); i++) {
      padded[i] = data[i];
    }
    return padded;
  }
  
  /// 기본 결과 반환
  TimbreResult _getDefaultResult() {
    return TimbreResult(
      brightness: 0.5,
      warmth: 0.5,
      tension: 0.5,
      breathiness: 0.5,
      formants: [700, 1220, 2600],
      spectralCentroid: 2000,
      voiceType: '분석 불가',
    );
  }
  
  /// 음색 피드백 생성
  String generateTimbreFeedback(TimbreResult result) {
    final feedback = StringBuffer();
    
    feedback.writeln('🎵 음색 분석 결과:');
    feedback.writeln('• 음색 타입: ${result.voiceType}');
    
    if (result.brightness > 0.7) {
      feedback.writeln('• 밝고 선명한 소리를 내고 있습니다.');
    } else if (result.brightness < 0.3) {
      feedback.writeln('• 어둡고 묵직한 소리입니다.');
    }
    
    if (result.warmth > 0.7) {
      feedback.writeln('• 따뜻하고 부드러운 톤이 좋습니다.');
    }
    
    if (result.tension > 0.6) {
      feedback.writeln('⚠️ 목에 힘이 들어가 있습니다. 릴렉스하세요.');
    } else if (result.tension < 0.3) {
      feedback.writeln('✅ 목이 편안한 상태로 잘 발성하고 있습니다.');
    }
    
    if (result.breathiness > 0.6) {
      feedback.writeln('• 숨소리가 많이 섞여 있습니다.');
      feedback.writeln('  복식호흡을 사용해 성대 접촉을 늘려보세요.');
    }
    
    // 포먼트 기반 피드백
    if (result.formants[0] < 600) {
      feedback.writeln('• 저음역대가 풍부합니다.');
    } else if (result.formants[0] > 900) {
      feedback.writeln('• 고음역대에 에너지가 집중되어 있습니다.');
    }
    
    return feedback.toString();
  }
}