import 'dart:math' as math;
import '../entities/audio_data.dart';
import '../entities/vocal_analysis.dart';
import '../repositories/audio_analysis_repository.dart';

class AnalyzeVocalQuality {
  final AudioAnalysisRepository repository;

  AnalyzeVocalQuality(this.repository);

  Future<VocalAnalysis> call(AudioData audioData) async {
    try {
      // 1. 음성 전처리
      final preprocessedAudio = _preprocessAudio(audioData);
      
      // 2. 피치 분석
      final pitchValues = await repository.extractPitch(preprocessedAudio);
      final pitchStability = _calculatePitchStability(pitchValues);
      
      // 3. 포먼트 추출
      final formants = await repository.extractFormants(preprocessedAudio);
      final resonancePosition = _classifyResonance(formants);
      
      // 4. 호흡 패턴 분석
      final breathingType = await repository.classifyBreathing(preprocessedAudio);
      
      // 5. 스펙트럴 틸트 계산
      final spectralTilt = await repository.calculateSpectralTilt(preprocessedAudio);
      
      // 6. 입 모양과 혀 위치 추정
      final mouthOpening = _estimateMouthOpening(formants);
      final tonguePosition = _estimateTonguePosition(formants);
      
      // 7. 비브라토 분석
      final vibratoQuality = _analyzeVibrato(pitchValues);
      
      // 8. 종합 점수 계산
      final overallScore = _calculateOverallScore(
        pitchStability: pitchStability,
        breathingType: breathingType,
        resonancePosition: resonancePosition,
        vibratoQuality: vibratoQuality,
        spectralTilt: spectralTilt,
      );
      
      return VocalAnalysis(
        pitchStability: pitchStability,
        breathingType: breathingType,
        resonancePosition: resonancePosition,
        mouthOpening: mouthOpening,
        tonguePosition: tonguePosition,
        vibratoQuality: vibratoQuality,
        overallScore: overallScore,
        timestamp: DateTime.now(),
        fundamentalFreq: pitchValues,
        formants: formants,
        spectralTilt: spectralTilt,
      );
    } catch (e) {
      throw AnalysisException('Failed to analyze vocal quality: $e');
    }
  }

  AudioData _preprocessAudio(AudioData audioData) {
    // 노이즈 제거 및 정규화
    final normalizedSamples = _normalizeSamples(audioData.samples);
    final denoisedSamples = _applyNoiseGate(normalizedSamples, threshold: 0.02);
    
    return audioData.copyWith(samples: denoisedSamples);
  }

  List<double> _normalizeSamples(List<double> samples) {
    final maxAmplitude = samples.reduce((a, b) => a.abs() > b.abs() ? a : b).abs();
    if (maxAmplitude == 0) return samples;
    
    return samples.map((s) => s / maxAmplitude).toList();
  }

  List<double> _applyNoiseGate(List<double> samples, {required double threshold}) {
    return samples.map((s) => s.abs() < threshold ? 0.0 : s).toList();
  }

  double _calculatePitchStability(List<double> pitchValues) {
    if (pitchValues.isEmpty) return 0.0;
    
    // 피치 값에서 0 제거 (무성음 구간)
    final validPitches = pitchValues.where((p) => p > 0).toList();
    if (validPitches.isEmpty) return 0.0;
    
    // 평균과 표준편차 계산
    final mean = validPitches.reduce((a, b) => a + b) / validPitches.length;
    final variance = validPitches
        .map((p) => math.pow(p - mean, 2))
        .reduce((a, b) => a + b) / validPitches.length;
    final stdDev = math.sqrt(variance);
    
    // 변동계수 (Coefficient of Variation) 계산
    final cv = stdDev / mean;
    
    // 안정성 점수 (0-100)
    // CV가 낮을수록 안정적
    final stability = math.max(0, 100 - (cv * 500));
    
    return stability.clamp(0, 100).toDouble();
  }

  ResonancePosition _classifyResonance(List<double> formants) {
    if (formants.length < 3) return ResonancePosition.throat;
    
    final f1 = formants[0];
    final f2 = formants[1];
    final f3 = formants[2];
    
    // 포먼트 비율 기반 공명 위치 분류
    final f2f1Ratio = f2 / f1;
    final f3f2Ratio = f3 / f2;
    
    if (f2f1Ratio < 2.5 && f3f2Ratio < 1.3) {
      return ResonancePosition.throat;
    } else if (f2f1Ratio > 3.5 && f3f2Ratio > 1.5) {
      return ResonancePosition.head;
    } else if (f2f1Ratio > 2.5 && f2f1Ratio < 3.5) {
      return ResonancePosition.mouth;
    } else {
      return ResonancePosition.mixed;
    }
  }

  MouthOpening _estimateMouthOpening(List<double> formants) {
    if (formants.isEmpty) return MouthOpening.medium;
    
    final f1 = formants[0];
    
    // F1 주파수 기반 입 열림 정도 추정
    if (f1 < 400) {
      return MouthOpening.narrow;
    } else if (f1 > 700) {
      return MouthOpening.wide;
    } else {
      return MouthOpening.medium;
    }
  }

  TonguePosition _estimateTonguePosition(List<double> formants) {
    if (formants.length < 2) return TonguePosition.lowFront;
    
    final f1 = formants[0];
    final f2 = formants[1];
    
    // F1, F2 주파수 기반 혀 위치 추정
    if (f1 < 400 && f2 > 2200) {
      return TonguePosition.highFront;
    } else if (f1 < 400 && f2 < 1200) {
      return TonguePosition.highBack;
    } else if (f1 > 600 && f2 > 1800) {
      return TonguePosition.lowFront;
    } else {
      return TonguePosition.lowBack;
    }
  }

  VibratoQuality _analyzeVibrato(List<double> pitchValues) {
    if (pitchValues.length < 100) return VibratoQuality.none;
    
    // 피치 변동 분석
    final differences = <double>[];
    for (int i = 1; i < pitchValues.length; i++) {
      if (pitchValues[i] > 0 && pitchValues[i - 1] > 0) {
        differences.add((pitchValues[i] - pitchValues[i - 1]).abs());
      }
    }
    
    if (differences.isEmpty) return VibratoQuality.none;
    
    final avgDifference = differences.reduce((a, b) => a + b) / differences.length;
    
    // 평균 피치 계산
    final validPitches = pitchValues.where((p) => p > 0).toList();
    if (validPitches.isEmpty) return VibratoQuality.none;
    
    final avgPitch = validPitches.reduce((a, b) => a + b) / validPitches.length;
    final vibratoDepth = avgDifference / avgPitch;
    
    if (vibratoDepth < 0.01) {
      return VibratoQuality.none;
    } else if (vibratoDepth < 0.03) {
      return VibratoQuality.light;
    } else if (vibratoDepth < 0.05) {
      return VibratoQuality.medium;
    } else {
      return VibratoQuality.heavy;
    }
  }

  int _calculateOverallScore({
    required double pitchStability,
    required BreathingType breathingType,
    required ResonancePosition resonancePosition,
    required VibratoQuality vibratoQuality,
    required double spectralTilt,
  }) {
    double score = 0;
    
    // 피치 안정성 (30%)
    score += pitchStability * 0.3;
    
    // 호흡 타입 (25%)
    switch (breathingType) {
      case BreathingType.diaphragmatic:
        score += 25;
        break;
      case BreathingType.mixed:
        score += 20;
        break;
      case BreathingType.chest:
        score += 10;
        break;
    }
    
    // 공명 위치 (25%)
    switch (resonancePosition) {
      case ResonancePosition.mixed:
        score += 25;
        break;
      case ResonancePosition.head:
      case ResonancePosition.mouth:
        score += 20;
        break;
      case ResonancePosition.throat:
        score += 10;
        break;
    }
    
    // 비브라토 품질 (10%)
    switch (vibratoQuality) {
      case VibratoQuality.light:
      case VibratoQuality.medium:
        score += 10;
        break;
      case VibratoQuality.none:
        score += 5;
        break;
      case VibratoQuality.heavy:
        score += 3;
        break;
    }
    
    // 스펙트럴 틸트 (10%)
    // 적절한 스펙트럴 틸트는 -6 ~ -12 dB/octave
    if (spectralTilt >= -12 && spectralTilt <= -6) {
      score += 10;
    } else if (spectralTilt >= -15 && spectralTilt <= -3) {
      score += 7;
    } else {
      score += 3;
    }
    
    return score.round().clamp(0, 100);
  }
}

class AnalysisException implements Exception {
  final String message;
  AnalysisException(this.message);
  
  @override
  String toString() => 'AnalysisException: $message';
}