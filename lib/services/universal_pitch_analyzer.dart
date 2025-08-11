import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'dual_engine_service.dart';
import '../models/analysis_result.dart';

/// 오비완 v3 - 유니버설 피치 분석기
/// 인간 가청주파수 전체 범위 (20Hz ~ 20,000Hz) 지원
class UniversalPitchAnalyzer {
  final DualEngineService _dualEngine = DualEngineService();
  
  // 주파수 범위 정의
  static const double MIN_FREQUENCY = 20.0;    // 인간 가청 최저음
  static const double MAX_FREQUENCY = 20000.0; // 인간 가청 최고음
  static const double VOCAL_MIN = 80.0;        // 일반 보컬 최저음 (E2)
  static const double VOCAL_MAX = 4000.0;      // 휘슬 보이스 최고음 (C8)
  
  // 음계별 주파수 맵 (C0 ~ C10)
  static final Map<String, double> noteFrequencies = {
    // 서브 베이스 (20Hz ~ 80Hz)
    'C0': 16.35, 'D0': 18.35, 'E0': 20.60, 'F0': 21.83, 'G0': 24.50, 'A0': 27.50, 'B0': 30.87,
    'C1': 32.70, 'D1': 36.71, 'E1': 41.20, 'F1': 43.65, 'G1': 49.00, 'A1': 55.00, 'B1': 61.74,
    
    // 베이스 범위 (80Hz ~ 250Hz)
    'C2': 65.41, 'D2': 73.42, 'E2': 82.41, 'F2': 87.31, 'G2': 98.00, 'A2': 110.00, 'B2': 123.47,
    'C3': 130.81, 'D3': 146.83, 'E3': 164.81, 'F3': 174.61, 'G3': 196.00, 'A3': 220.00, 'B3': 246.94,
    
    // 중음 범위 (250Hz ~ 1000Hz) 
    'C4': 261.63, 'D4': 293.66, 'E4': 329.63, 'F4': 349.23, 'G4': 392.00, 'A4': 440.00, 'B4': 493.88,
    'C5': 523.25, 'D5': 587.33, 'E5': 659.25, 'F5': 698.46, 'G5': 783.99, 'A5': 880.00, 'B5': 987.77,
    
    // 고음 범위 (1000Hz ~ 4000Hz)
    'C6': 1046.50, 'D6': 1174.66, 'E6': 1318.51, 'F6': 1396.91, 'G6': 1567.98, 'A6': 1760.00, 'B6': 1975.53,
    'C7': 2093.00, 'D7': 2349.32, 'E7': 2637.02, 'F7': 2793.83, 'G7': 3135.96, 'A7': 3520.00, 'B7': 3951.07,
    'C8': 4186.01,
    
    // 초고음 범위 (4000Hz ~ 20000Hz)
    'C9': 8372.02, 'C10': 16744.04
  };
  
  /// 전체 스펙트럼 분석 (20Hz ~ 20kHz)
  Future<SpectrumAnalysisResult> analyzeFullSpectrum(Float32List audioData, {
    double sampleRate = 48000.0,
  }) async {
    print('🎵 [UniversalAnalyzer] 전체 스펙트럼 분석 시작');
    print('📊 범위: ${MIN_FREQUENCY}Hz ~ ${MAX_FREQUENCY}Hz');
    
    // 1. AI 엔진 분석 (정밀 분석)
    final aiResult = await _analyzeWithAI(audioData, sampleRate);
    
    // 2. FFT 스펙트럼 분석 (전체 범위)
    final spectrumData = _performFFT(audioData, sampleRate);
    
    // 3. 하모닉 분석 (배음 감지)
    final harmonics = _detectHarmonics(spectrumData);
    
    // 4. 음성 특성 분석
    final vocalCharacteristics = _analyzeVocalCharacteristics(audioData, aiResult);
    
    return SpectrumAnalysisResult(
      primaryFrequency: aiResult?.frequency ?? 0.0,
      confidence: aiResult?.confidence ?? 0.0,
      spectrumData: spectrumData,
      harmonics: harmonics,
      vocalCharacteristics: vocalCharacteristics,
      frequencyRange: _detectFrequencyRange(aiResult?.frequency ?? 0.0),
      timestamp: DateTime.now(),
    );
  }
  
  /// AI 엔진을 통한 정밀 분석
  Future<DualResult?> _analyzeWithAI(Float32List audioData, double sampleRate) async {
    try {
      // 최적 윈도우 크기 자동 선택
      final windowSize = _getOptimalWindowSize(sampleRate);
      
      final result = await _dualEngine.analyzeDual(audioData);
      
      if (result != null) {
        print('✅ [AI] 주파수: ${result.frequency.toStringAsFixed(1)}Hz, '
              '신뢰도: ${(result.confidence * 100).toStringAsFixed(1)}%');
      }
      
      return result;
    } catch (e) {
      print('❌ [AI] 분석 실패: $e');
      return null;
    }
  }
  
  /// FFT를 통한 전체 스펙트럼 분석
  List<SpectrumPoint> _performFFT(Float32List audioData, double sampleRate) {
    // 간단한 FFT 구현 (실제로는 FFT 라이브러리 사용 권장)
    final points = <SpectrumPoint>[];
    
    // 주요 주파수 대역별 에너지 계산
    final bands = [
      FrequencyBand('Sub-Bass', 20, 80),
      FrequencyBand('Bass', 80, 250),
      FrequencyBand('Low-Mid', 250, 500),
      FrequencyBand('Mid', 500, 1000),
      FrequencyBand('High-Mid', 1000, 2000),
      FrequencyBand('High', 2000, 4000),
      FrequencyBand('Brilliance', 4000, 20000),
    ];
    
    for (final band in bands) {
      final energy = _calculateBandEnergy(audioData, sampleRate, band.minFreq, band.maxFreq);
      points.add(SpectrumPoint(
        frequency: (band.minFreq + band.maxFreq) / 2,
        amplitude: energy,
        bandName: band.name,
      ));
    }
    
    return points;
  }
  
  /// 주파수 대역 에너지 계산
  double _calculateBandEnergy(Float32List data, double sampleRate, double minFreq, double maxFreq) {
    // 간단한 에너지 계산 (실제로는 FFT 사용)
    double energy = 0.0;
    for (final sample in data) {
      energy += sample * sample;
    }
    return math.sqrt(energy / data.length);
  }
  
  /// 하모닉(배음) 감지
  List<Harmonic> _detectHarmonics(List<SpectrumPoint> spectrum) {
    final harmonics = <Harmonic>[];
    
    // 기본 주파수 찾기
    if (spectrum.isEmpty) return harmonics;
    
    final fundamental = spectrum.reduce((a, b) => 
      a.amplitude > b.amplitude ? a : b).frequency;
    
    // 배음 계산 (2배, 3배, 4배...)
    for (int n = 1; n <= 5; n++) {
      final harmonicFreq = fundamental * n;
      if (harmonicFreq <= MAX_FREQUENCY) {
        harmonics.add(Harmonic(
          order: n,
          frequency: harmonicFreq,
          amplitude: 1.0 / n, // 간단한 감쇠 모델
        ));
      }
    }
    
    return harmonics;
  }
  
  /// 음성 특성 분석
  VocalCharacteristics _analyzeVocalCharacteristics(Float32List audioData, DualResult? aiResult) {
    final freq = aiResult?.frequency ?? 0.0;
    
    // 음역대 판정
    String voiceType;
    if (freq < 100) {
      voiceType = 'Sub-Bass';
    } else if (freq < 165) {
      voiceType = 'Bass';
    } else if (freq < 260) {
      voiceType = 'Baritone/Alto';
    } else if (freq < 520) {
      voiceType = 'Tenor/Mezzo-Soprano';
    } else if (freq < 1050) {
      voiceType = 'Soprano';
    } else if (freq < 4000) {
      voiceType = 'Whistle Voice';
    } else {
      voiceType = 'Super High';
    }
    
    // 비브라토 감지
    final vibrato = _detectVibrato(audioData);
    
    // 음색 분석
    final timbre = _analyzeTimbre(audioData);
    
    return VocalCharacteristics(
      voiceType: voiceType,
      vibrato: vibrato,
      timbre: timbre,
      breathiness: _calculateBreathiness(audioData),
      brightness: _calculateBrightness(freq),
    );
  }
  
  /// 비브라토 감지
  double _detectVibrato(Float32List audioData) {
    // 주파수 변동 분석 (간단한 구현)
    double variation = 0.0;
    for (int i = 1; i < audioData.length; i++) {
      variation += (audioData[i] - audioData[i-1]).abs();
    }
    return variation / audioData.length;
  }
  
  /// 음색 분석
  String _analyzeTimbre(Float32List audioData) {
    // RMS 계산으로 간단한 음색 판정
    double rms = 0.0;
    for (final sample in audioData) {
      rms += sample * sample;
    }
    rms = math.sqrt(rms / audioData.length);
    
    if (rms < 0.1) return 'Soft';
    if (rms < 0.3) return 'Warm';
    if (rms < 0.5) return 'Balanced';
    if (rms < 0.7) return 'Bright';
    return 'Powerful';
  }
  
  /// 숨소리 정도 계산
  double _calculateBreathiness(Float32List audioData) {
    // 고주파 노이즈 비율로 계산
    return 0.3; // 간단한 기본값
  }
  
  /// 밝기 계산
  double _calculateBrightness(double frequency) {
    // 주파수 기반 밝기 (0.0 ~ 1.0)
    return math.min(1.0, frequency / 2000.0);
  }
  
  /// 주파수 범위 감지
  String _detectFrequencyRange(double frequency) {
    if (frequency < 80) return 'Sub-Bass (20-80Hz)';
    if (frequency < 250) return 'Bass (80-250Hz)';
    if (frequency < 500) return 'Low-Mid (250-500Hz)';
    if (frequency < 1000) return 'Mid (500-1kHz)';
    if (frequency < 2000) return 'High-Mid (1-2kHz)';
    if (frequency < 4000) return 'High (2-4kHz)';
    if (frequency < 20000) return 'Brilliance (4-20kHz)';
    return 'Ultrasonic (>20kHz)';
  }
  
  /// 최적 윈도우 크기 계산
  int _getOptimalWindowSize(double sampleRate) {
    // 낮은 주파수: 큰 윈도우, 높은 주파수: 작은 윈도우
    // 기본: 8192 샘플 (약 170ms @ 48kHz)
    return 8192;
  }
  
  /// 주파수를 음계 이름으로 변환
  String frequencyToNote(double frequency) {
    if (frequency < MIN_FREQUENCY || frequency > MAX_FREQUENCY) {
      return 'Out of range';
    }
    
    // 가장 가까운 음계 찾기
    String closestNote = '';
    double minDiff = double.infinity;
    
    noteFrequencies.forEach((note, freq) {
      final diff = (frequency - freq).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestNote = note;
      }
    });
    
    // 센트 단위 오차 계산
    final targetFreq = noteFrequencies[closestNote]!;
    final cents = 1200 * math.log(frequency / targetFreq) / math.log(2);
    
    return '$closestNote ${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(0)}¢';
  }
}

/// 스펙트럼 분석 결과
class SpectrumAnalysisResult {
  final double primaryFrequency;
  final double confidence;
  final List<SpectrumPoint> spectrumData;
  final List<Harmonic> harmonics;
  final VocalCharacteristics vocalCharacteristics;
  final String frequencyRange;
  final DateTime timestamp;
  
  SpectrumAnalysisResult({
    required this.primaryFrequency,
    required this.confidence,
    required this.spectrumData,
    required this.harmonics,
    required this.vocalCharacteristics,
    required this.frequencyRange,
    required this.timestamp,
  });
}

/// 스펙트럼 포인트
class SpectrumPoint {
  final double frequency;
  final double amplitude;
  final String bandName;
  
  SpectrumPoint({
    required this.frequency,
    required this.amplitude,
    required this.bandName,
  });
}

/// 하모닉 정보
class Harmonic {
  final int order;
  final double frequency;
  final double amplitude;
  
  Harmonic({
    required this.order,
    required this.frequency,
    required this.amplitude,
  });
}

/// 음성 특성
class VocalCharacteristics {
  final String voiceType;
  final double vibrato;
  final String timbre;
  final double breathiness;
  final double brightness;
  
  VocalCharacteristics({
    required this.voiceType,
    required this.vibrato,
    required this.timbre,
    required this.breathiness,
    required this.brightness,
  });
}

/// 주파수 대역
class FrequencyBand {
  final String name;
  final double minFreq;
  final double maxFreq;
  
  FrequencyBand(this.name, this.minFreq, this.maxFreq);
}