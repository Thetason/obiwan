import '../../domain/entities/audio_data.dart';
import '../../domain/entities/vocal_analysis.dart';
import '../../domain/repositories/audio_analysis_repository.dart';
import '../../features/audio_analysis/pitch_analyzer_simple.dart';
import '../../features/audio_analysis/formant_analyzer.dart';
import '../../features/audio_analysis/breathing_analyzer.dart';

class AudioAnalysisRepositoryImpl implements AudioAnalysisRepository {
  final PitchAnalyzer _pitchAnalyzer;
  final FormantAnalyzer _formantAnalyzer;
  final BreathingAnalyzer _breathingAnalyzer;
  
  AudioAnalysisRepositoryImpl({
    PitchAnalyzer? pitchAnalyzer,
    FormantAnalyzer? formantAnalyzer,
    BreathingAnalyzer? breathingAnalyzer,
  }) : _pitchAnalyzer = pitchAnalyzer ?? PitchAnalyzer(),
       _formantAnalyzer = formantAnalyzer ?? FormantAnalyzer(),
       _breathingAnalyzer = breathingAnalyzer ?? BreathingAnalyzer();
  
  @override
  Future<VocalAnalysis> analyzeAudio(AudioData audioData) async {
    try {
      // 병렬 처리로 성능 최적화
      final results = await Future.wait([
        extractPitch(audioData),
        extractFormants(audioData),
        classifyBreathing(audioData),
        calculateSpectralTilt(audioData),
      ]);
      
      final pitchValues = results[0] as List<double>;
      final formants = results[1] as List<double>;
      final breathingType = results[2] as BreathingType;
      final spectralTilt = results[3] as double;
      
      // 피치 안정성 계산
      final pitchStability = _pitchAnalyzer.calculatePitchStability(pitchValues);
      
      // 공명 위치 분류
      final resonancePosition = _formantAnalyzer.classifyResonance(formants);
      
      // 입 모양과 혀 위치 추정
      final mouthOpening = _estimateMouthOpening(formants);
      final tonguePosition = _estimateTonguePosition(formants);
      
      // 비브라토 분석
      final vibratoAnalysis = _pitchAnalyzer.analyzeVibrato(pitchValues);
      final vibratoQuality = _classifyVibratoQuality(vibratoAnalysis);
      
      // 종합 점수 계산
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
      throw AudioAnalysisException('Failed to analyze audio: $e');
    }
  }
  
  @override
  Future<List<double>> extractPitch(AudioData audioData) async {
    return _pitchAnalyzer.analyzePitch(audioData.samples);
  }
  
  @override
  Future<List<double>> extractFormants(AudioData audioData) async {
    return _formantAnalyzer.extractFormants(audioData.samples);
  }
  
  @override
  Future<BreathingType> classifyBreathing(AudioData audioData) async {
    return _breathingAnalyzer.analyzeBreathing(audioData);
  }
  
  @override
  Future<double> calculateSpectralTilt(AudioData audioData) async {
    return _breathingAnalyzer.calculateSpectralTilt(audioData);
  }
  
  MouthOpening _estimateMouthOpening(List<double> formants) {
    if (formants.isEmpty) return MouthOpening.medium;
    
    final f1 = formants[0];
    
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
  
  VibratoQuality _classifyVibratoQuality(Map<String, double> vibratoAnalysis) {
    final rate = vibratoAnalysis['rate'] ?? 0;
    final extent = vibratoAnalysis['extent'] ?? 0;
    final regularity = vibratoAnalysis['regularity'] ?? 0;
    
    if (rate < 1 || extent < 5) {
      return VibratoQuality.none;
    } else if (rate >= 4 && rate <= 7 && extent >= 10 && extent <= 30 && regularity > 0.7) {
      return VibratoQuality.medium;
    } else if (rate > 7 || extent > 30) {
      return VibratoQuality.heavy;
    } else {
      return VibratoQuality.light;
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

class AudioAnalysisException implements Exception {
  final String message;
  AudioAnalysisException(this.message);
  
  @override
  String toString() => 'AudioAnalysisException: $message';
}