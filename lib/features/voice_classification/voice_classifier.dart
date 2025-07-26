import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../audio_analysis/pitch_correction_engine.dart';
import '../audio_analysis/timbre_analyzer.dart';
import '../../core/performance/performance_manager.dart';

/// Advanced voice classification system for vocal type detection
class VoiceClassifier with PerformanceMixin {
  static final VoiceClassifier _instance = VoiceClassifier._internal();
  factory VoiceClassifier() => _instance;
  VoiceClassifier._internal();

  final PitchCorrectionEngine _pitchEngine = PitchCorrectionEngine();
  final TimbreAnalyzer _timbreAnalyzer = TimbreAnalyzer();
  
  bool _isInitialized = false;
  final Map<String, dynamic> _classificationCache = {};
  
  // Voice type classification models
  final Map<VoiceType, VoiceTypeProfile> _voiceProfiles = {
    VoiceType.soprano: VoiceTypeProfile(
      name: 'Soprano',
      fundamentalRange: FrequencyRange(261.63, 1046.50), // C4-C6
      optimalRange: FrequencyRange(349.23, 783.99),      // F4-G5
      formantF1Range: FrequencyRange(800, 1200),
      formantF2Range: FrequencyRange(1200, 2800),
      timbreCharacteristics: {
        'brightness': 0.7,
        'clarity': 0.8,
        'resonance': 0.6,
        'warmth': 0.4,
      },
    ),
    VoiceType.mezzoSoprano: VoiceTypeProfile(
      name: 'Mezzo-Soprano',
      fundamentalRange: FrequencyRange(220.00, 880.00), // A3-A5
      optimalRange: FrequencyRange(293.66, 659.25),     // D4-E5
      formantF1Range: FrequencyRange(700, 1100),
      formantF2Range: FrequencyRange(1100, 2400),
      timbreCharacteristics: {
        'brightness': 0.6,
        'clarity': 0.7,
        'resonance': 0.7,
        'warmth': 0.6,
      },
    ),
    VoiceType.alto: VoiceTypeProfile(
      name: 'Alto',
      fundamentalRange: FrequencyRange(174.61, 698.46), // F3-F5
      optimalRange: FrequencyRange(246.94, 523.25),     // B3-C5
      formantF1Range: FrequencyRange(600, 1000),
      formantF2Range: FrequencyRange(1000, 2200),
      timbreCharacteristics: {
        'brightness': 0.4,
        'clarity': 0.6,
        'resonance': 0.8,
        'warmth': 0.8,
      },
    ),
    VoiceType.tenor: VoiceTypeProfile(
      name: 'Tenor',
      fundamentalRange: FrequencyRange(130.81, 523.25), // C3-C5
      optimalRange: FrequencyRange(174.61, 392.00),     // F3-G4
      formantF1Range: FrequencyRange(400, 800),
      formantF2Range: FrequencyRange(800, 1800),
      timbreCharacteristics: {
        'brightness': 0.8,
        'clarity': 0.8,
        'resonance': 0.6,
        'warmth': 0.5,
      },
    ),
    VoiceType.baritone: VoiceTypeProfile(
      name: 'Baritone',
      fundamentalRange: FrequencyRange(98.00, 392.00),  // G2-G4
      optimalRange: FrequencyRange(130.81, 293.66),     // C3-D4
      formantF1Range: FrequencyRange(350, 700),
      formantF2Range: FrequencyRange(700, 1600),
      timbreCharacteristics: {
        'brightness': 0.6,
        'clarity': 0.7,
        'resonance': 0.7,
        'warmth': 0.7,
      },
    ),
    VoiceType.bass: VoiceTypeProfile(
      name: 'Bass',
      fundamentalRange: FrequencyRange(82.41, 329.63),  // E2-E4
      optimalRange: FrequencyRange(110.00, 246.94),     // A2-B3
      formantF1Range: FrequencyRange(300, 600),
      formantF2Range: FrequencyRange(600, 1400),
      timbreCharacteristics: {
        'brightness': 0.3,
        'clarity': 0.6,
        'resonance': 0.9,
        'warmth': 0.9,
      },
    ),
  };

  /// Initialize the voice classifier
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _pitchEngine.initialize();
    await _timbreAnalyzer.initialize();
    
    _isInitialized = true;
  }

  /// Classify voice type from audio sample
  Future<VoiceClassificationResult> classifyVoice(
    Float32List audioData, {
    int sampleRate = 44100,
    Duration minAnalysisDuration = const Duration(seconds: 10),
  }) async {
    return measureOperation('voice_classification', () async {
      if (!_isInitialized) {
        throw StateError('VoiceClassifier not initialized');
      }

      if (audioData.length < sampleRate * minAnalysisDuration.inSeconds) {
        throw ArgumentError('Audio sample too short for reliable classification');
      }

      // Extract fundamental frequency characteristics
      final pitchAnalysis = await _analyzePitchCharacteristics(audioData, sampleRate);
      
      // Extract timbre characteristics
      final timbreAnalysis = await _timbreAnalyzer.analyzeTimbre(audioData.toList());
      
      // Extract formant information
      final formantAnalysis = await _analyzeFormants(audioData, sampleRate);
      
      // Calculate vocal range
      final vocalRange = _calculateVocalRange(pitchAnalysis.pitchHistory);
      
      // Classify based on combined features
      final classification = _performClassification(
        pitchAnalysis,
        timbreAnalysis,
        formantAnalysis,
        vocalRange,
      );
      
      return VoiceClassificationResult(
        primaryType: classification.primaryType,
        confidence: classification.confidence,
        alternativeTypes: classification.alternativeTypes,
        vocalRange: vocalRange,
        fundamentalFrequency: pitchAnalysis.averagePitch,
        formants: formantAnalysis,
        timbreProfile: TimbreProfile(
          brightness: timbreAnalysis.brightness,
          warmth: timbreAnalysis.warmth,
          resonance: timbreAnalysis.resonance,
          clarity: _calculateClarity(timbreAnalysis),
        ),
        analysisMetadata: VoiceAnalysisMetadata(
          sampleDuration: Duration(milliseconds: (audioData.length / sampleRate * 1000).round()),
          sampleRate: sampleRate,
          averageAmplitude: _calculateAverageAmplitude(audioData),
          dynamicRange: _calculateDynamicRange(audioData),
        ),
        recommendations: _generateRecommendations(classification.primaryType, timbreAnalysis),
      );
    });
  }

  /// Analyze pitch characteristics over time
  Future<PitchAnalysis> _analyzePitchCharacteristics(
    Float32List audioData,
    int sampleRate,
  ) async {
    const frameSize = 2048;
    const hopSize = 512;
    final pitchHistory = <double>[];
    
    for (int i = 0; i < audioData.length - frameSize; i += hopSize) {
      final frame = audioData.sublist(i, i + frameSize);
      final pitch = await _pitchEngine.estimatePitch(frame, sampleRate);
      
      if (pitch > 0) {
        pitchHistory.add(pitch);
      }
    }
    
    if (pitchHistory.isEmpty) {
      throw StateError('Could not extract pitch information from audio');
    }
    
    // Calculate statistics
    pitchHistory.sort();
    final averagePitch = pitchHistory.reduce((a, b) => a + b) / pitchHistory.length;
    final medianPitch = pitchHistory[pitchHistory.length ~/ 2];
    final minPitch = pitchHistory.first;
    final maxPitch = pitchHistory.last;
    
    // Calculate stability (inverse of pitch variance)
    final variance = pitchHistory
        .map((p) => math.pow(p - averagePitch, 2))
        .reduce((a, b) => a + b) / pitchHistory.length;
    final stability = 1.0 / (1.0 + math.sqrt(variance) / averagePitch);
    
    return PitchAnalysis(
      pitchHistory: pitchHistory,
      averagePitch: averagePitch,
      medianPitch: medianPitch,
      minPitch: minPitch,
      maxPitch: maxPitch,
      pitchStability: stability,
      pitchRange: maxPitch - minPitch,
    );
  }

  /// Analyze formant frequencies
  Future<FormantAnalysis> _analyzeFormants(
    Float32List audioData,
    int sampleRate,
  ) async {
    // Simplified formant analysis using spectral peaks
    const frameSize = 4096;
    const hopSize = 2048;
    final f1Values = <double>[];
    final f2Values = <double>[];
    final f3Values = <double>[];
    
    for (int i = 0; i < audioData.length - frameSize; i += hopSize) {
      final frame = audioData.sublist(i, i + frameSize);
      final formants = _extractFormants(frame, sampleRate);
      
      if (formants.isNotEmpty) {
        if (formants.length > 0) f1Values.add(formants[0]);
        if (formants.length > 1) f2Values.add(formants[1]);
        if (formants.length > 2) f3Values.add(formants[2]);
      }
    }
    
    return FormantAnalysis(
      f1: f1Values.isNotEmpty ? f1Values.reduce((a, b) => a + b) / f1Values.length : 0,
      f2: f2Values.isNotEmpty ? f2Values.reduce((a, b) => a + b) / f2Values.length : 0,
      f3: f3Values.isNotEmpty ? f3Values.reduce((a, b) => a + b) / f3Values.length : 0,
      f1Range: f1Values.isNotEmpty ? FrequencyRange(
        f1Values.reduce(math.min),
        f1Values.reduce(math.max),
      ) : FrequencyRange(0, 0),
      f2Range: f2Values.isNotEmpty ? FrequencyRange(
        f2Values.reduce(math.min),
        f2Values.reduce(math.max),
      ) : FrequencyRange(0, 0),
    );
  }

  /// Extract formant frequencies from audio frame
  List<double> _extractFormants(List<double> frame, int sampleRate) {
    // Apply window function
    final windowed = <double>[];
    for (int i = 0; i < frame.length; i++) {
      final window = 0.5 - 0.5 * math.cos(2 * math.pi * i / (frame.length - 1));
      windowed.add(frame[i] * window);
    }
    
    // Compute magnitude spectrum (simplified FFT)
    final spectrum = _computeMagnitudeSpectrum(windowed, sampleRate);
    
    // Find spectral peaks that could be formants
    final peaks = _findSpectralPeaks(spectrum, sampleRate);
    
    // Filter peaks to typical formant frequency ranges
    final formants = peaks.where((peak) => 
      peak.frequency >= 200 && peak.frequency <= 4000
    ).map((peak) => peak.frequency).toList();
    
    formants.sort();
    return formants.take(3).toList(); // Return first 3 formants
  }

  /// Compute magnitude spectrum (simplified)
  List<SpectralPeak> _computeMagnitudeSpectrum(List<double> signal, int sampleRate) {
    final spectrum = <SpectralPeak>[];
    final fftSize = signal.length;
    final freqResolution = sampleRate / fftSize;
    
    // Simplified magnitude calculation
    for (int k = 0; k < fftSize ~/ 2; k++) {
      double magnitude = 0.0;
      for (int n = 0; n < signal.length; n++) {
        final angle = -2 * math.pi * k * n / fftSize;
        magnitude += signal[n] * math.cos(angle);
      }
      magnitude = magnitude.abs();
      
      spectrum.add(SpectralPeak(
        frequency: k * freqResolution,
        magnitude: magnitude,
      ));
    }
    
    return spectrum;
  }

  /// Find peaks in the spectrum
  List<SpectralPeak> _findSpectralPeaks(List<SpectralPeak> spectrum, int sampleRate) {
    final peaks = <SpectralPeak>[];
    const minPeakHeight = 0.1;
    const minPeakDistance = 5; // Minimum distance between peaks
    
    for (int i = minPeakDistance; i < spectrum.length - minPeakDistance; i++) {
      final current = spectrum[i];
      
      if (current.magnitude < minPeakHeight) continue;
      
      // Check if it's a local maximum
      bool isPeak = true;
      for (int j = i - minPeakDistance; j <= i + minPeakDistance; j++) {
        if (j != i && spectrum[j].magnitude >= current.magnitude) {
          isPeak = false;
          break;
        }
      }
      
      if (isPeak) {
        peaks.add(current);
      }
    }
    
    // Sort by magnitude and return top peaks
    peaks.sort((a, b) => b.magnitude.compareTo(a.magnitude));
    return peaks.take(10).toList();
  }

  /// Calculate vocal range from pitch history
  VocalRange _calculateVocalRange(List<double> pitchHistory) {
    if (pitchHistory.isEmpty) {
      return VocalRange(
        lowestNote: 0,
        highestNote: 0,
        comfortableRange: FrequencyRange(0, 0),
        totalRange: 0,
        rangeInSemitones: 0,
      );
    }
    
    pitchHistory.sort();
    final lowest = pitchHistory.first;
    final highest = pitchHistory.last;
    
    // Calculate comfortable range (middle 50% of pitches)
    final q1Index = (pitchHistory.length * 0.25).round();
    final q3Index = (pitchHistory.length * 0.75).round();
    final comfortableLow = pitchHistory[q1Index];
    final comfortableHigh = pitchHistory[q3Index];
    
    // Convert to semitones
    final rangeInSemitones = _frequencyToSemitones(highest) - _frequencyToSemitones(lowest);
    
    return VocalRange(
      lowestNote: lowest,
      highestNote: highest,
      comfortableRange: FrequencyRange(comfortableLow, comfortableHigh),
      totalRange: highest - lowest,
      rangeInSemitones: rangeInSemitones,
    );
  }

  /// Perform voice type classification
  ClassificationResult _performClassification(
    PitchAnalysis pitchAnalysis,
    TimbreAnalysis timbreAnalysis,
    FormantAnalysis formantAnalysis,
    VocalRange vocalRange,
  ) {
    final scores = <VoiceType, double>{};
    
    for (final entry in _voiceProfiles.entries) {
      final voiceType = entry.key;
      final profile = entry.value;
      
      // Score based on fundamental frequency range
      final pitchScore = _scorePitchMatch(pitchAnalysis.averagePitch, profile);
      
      // Score based on vocal range
      final rangeScore = _scoreRangeMatch(vocalRange, profile);
      
      // Score based on timbre characteristics
      final timbreScore = _scoreTimbreMatch(timbreAnalysis, profile);
      
      // Score based on formant characteristics
      final formantScore = _scoreFormantMatch(formantAnalysis, profile);
      
      // Combined score with weights
      final totalScore = (
        pitchScore * 0.3 +
        rangeScore * 0.25 +
        timbreScore * 0.25 +
        formantScore * 0.2
      );
      
      scores[voiceType] = totalScore;
    }
    
    // Sort by score
    final sortedScores = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final primaryType = sortedScores.first.key;
    final confidence = sortedScores.first.value;
    
    // Get alternative types with confidence > 0.3
    final alternatives = sortedScores
        .skip(1)
        .where((entry) => entry.value > 0.3)
        .map((entry) => VoiceTypeCandidate(
              type: entry.key,
              confidence: entry.value,
            ))
        .toList();
    
    return ClassificationResult(
      primaryType: primaryType,
      confidence: confidence,
      alternativeTypes: alternatives,
    );
  }

  double _scorePitchMatch(double averagePitch, VoiceTypeProfile profile) {
    if (profile.optimalRange.contains(averagePitch)) {
      return 1.0;
    } else if (profile.fundamentalRange.contains(averagePitch)) {
      // Calculate how close to optimal range
      final optimalCenter = (profile.optimalRange.min + profile.optimalRange.max) / 2;
      final distance = (averagePitch - optimalCenter).abs();
      final maxDistance = (profile.fundamentalRange.max - profile.fundamentalRange.min) / 2;
      return math.max(0.0, 1.0 - distance / maxDistance);
    }
    return 0.0;
  }

  double _scoreRangeMatch(VocalRange vocalRange, VoiceTypeProfile profile) {
    final rangeOverlap = _calculateRangeOverlap(
      FrequencyRange(vocalRange.lowestNote, vocalRange.highestNote),
      profile.fundamentalRange,
    );
    return rangeOverlap;
  }

  double _scoreTimbreMatch(TimbreAnalysis timbreAnalysis, VoiceTypeProfile profile) {
    final characteristics = profile.timbreCharacteristics;
    double score = 0.0;
    int count = 0;
    
    if (characteristics.containsKey('brightness')) {
      score += 1.0 - (timbreAnalysis.brightness - characteristics['brightness']!).abs();
      count++;
    }
    
    if (characteristics.containsKey('warmth')) {
      score += 1.0 - (timbreAnalysis.warmth - characteristics['warmth']!).abs();
      count++;
    }
    
    if (characteristics.containsKey('resonance')) {
      score += 1.0 - (timbreAnalysis.resonance - characteristics['resonance']!).abs();
      count++;
    }
    
    return count > 0 ? score / count : 0.0;
  }

  double _scoreFormantMatch(FormantAnalysis formantAnalysis, VoiceTypeProfile profile) {
    double score = 0.0;
    int count = 0;
    
    // Score F1 match
    if (profile.formantF1Range.contains(formantAnalysis.f1)) {
      score += 1.0;
    } else {
      final distance = math.min(
        (formantAnalysis.f1 - profile.formantF1Range.min).abs(),
        (formantAnalysis.f1 - profile.formantF1Range.max).abs(),
      );
      final maxDistance = profile.formantF1Range.max - profile.formantF1Range.min;
      score += math.max(0.0, 1.0 - distance / maxDistance);
    }
    count++;
    
    // Score F2 match
    if (profile.formantF2Range.contains(formantAnalysis.f2)) {
      score += 1.0;
    } else {
      final distance = math.min(
        (formantAnalysis.f2 - profile.formantF2Range.min).abs(),
        (formantAnalysis.f2 - profile.formantF2Range.max).abs(),
      );
      final maxDistance = profile.formantF2Range.max - profile.formantF2Range.min;
      score += math.max(0.0, 1.0 - distance / maxDistance);
    }
    count++;
    
    return count > 0 ? score / count : 0.0;
  }

  double _calculateRangeOverlap(FrequencyRange range1, FrequencyRange range2) {
    final overlapMin = math.max(range1.min, range2.min);
    final overlapMax = math.min(range1.max, range2.max);
    
    if (overlapMin >= overlapMax) return 0.0;
    
    final overlapSize = overlapMax - overlapMin;
    final range1Size = range1.max - range1.min;
    final range2Size = range2.max - range2.min;
    
    return overlapSize / math.max(range1Size, range2Size);
  }

  double _frequencyToSemitones(double frequency) {
    const a4Frequency = 440.0;
    return 12 * math.log(frequency / a4Frequency) / math.ln2;
  }

  double _calculateClarity(TimbreAnalysis timbreAnalysis) {
    // Clarity is inverse of roughness and related to harmonic structure
    return math.max(0.0, 1.0 - timbreAnalysis.roughness);
  }

  double _calculateAverageAmplitude(Float32List audioData) {
    return audioData.map((sample) => sample.abs()).reduce((a, b) => a + b) / audioData.length;
  }

  double _calculateDynamicRange(Float32List audioData) {
    final sortedAmplitudes = audioData.map((sample) => sample.abs()).toList()..sort();
    final p95 = sortedAmplitudes[(sortedAmplitudes.length * 0.95).round()];
    final p5 = sortedAmplitudes[(sortedAmplitudes.length * 0.05).round()];
    return 20 * math.log(p95 / math.max(p5, 1e-10)) / math.ln10; // dB
  }

  List<String> _generateRecommendations(VoiceType voiceType, TimbreAnalysis timbreAnalysis) {
    final recommendations = <String>[];
    final profile = _voiceProfiles[voiceType]!;
    
    // General recommendations based on voice type
    switch (voiceType) {
      case VoiceType.soprano:
        recommendations.add('고음역 발성 시 목의 긴장을 피하고 두성 공명을 활용하세요');
        recommendations.add('브레스 서포트를 강화하여 고음의 안정성을 높이세요');
        break;
      case VoiceType.alto:
        recommendations.add('중저음역의 풍부한 공명을 살려 표현력을 높이세요');
        recommendations.add('가슴 공명과 머리 공명의 균형을 맞추세요');
        break;
      case VoiceType.tenor:
        recommendations.add('패사지오 구간에서의 매끄러운 연결을 연습하세요');
        recommendations.add('고음 확장 시 믹스 보이스 기법을 활용하세요');
        break;
      case VoiceType.bass:
        recommendations.add('저음역의 깊이와 공명을 극대화하세요');
        recommendations.add('중음역으로의 자연스러운 이행을 연습하세요');
        break;
      default:
        break;
    }
    
    // Timbre-based recommendations
    if (timbreAnalysis.brightness < 0.5) {
      recommendations.add('밝기를 높이기 위해 구강 공간을 더 넓게 유지하세요');
    }
    
    if (timbreAnalysis.warmth < 0.5) {
      recommendations.add('따뜻한 음색을 위해 가슴 공명을 늘려보세요');
    }
    
    if (timbreAnalysis.resonance < 0.6) {
      recommendations.add('공명 연습을 통해 음성의 풍부함을 높이세요');
    }
    
    return recommendations;
  }

  /// Get voice type profile information
  VoiceTypeProfile? getVoiceTypeProfile(VoiceType voiceType) {
    return _voiceProfiles[voiceType];
  }

  /// Get all available voice types
  List<VoiceType> getAvailableVoiceTypes() {
    return _voiceProfiles.keys.toList();
  }

  void dispose() {
    _classificationCache.clear();
    _pitchEngine.dispose();
    _timbreAnalyzer.dispose();
  }
}

/// Voice type enumeration
enum VoiceType {
  soprano,
  mezzoSoprano,
  alto,
  tenor,
  baritone,
  bass,
}

/// Voice type profile containing characteristics
class VoiceTypeProfile {
  final String name;
  final FrequencyRange fundamentalRange;
  final FrequencyRange optimalRange;
  final FrequencyRange formantF1Range;
  final FrequencyRange formantF2Range;
  final Map<String, double> timbreCharacteristics;

  VoiceTypeProfile({
    required this.name,
    required this.fundamentalRange,
    required this.optimalRange,
    required this.formantF1Range,
    required this.formantF2Range,
    required this.timbreCharacteristics,
  });
}

/// Frequency range helper class
class FrequencyRange {
  final double min;
  final double max;

  FrequencyRange(this.min, this.max);

  bool contains(double frequency) {
    return frequency >= min && frequency <= max;
  }

  double get center => (min + max) / 2;
  double get span => max - min;
}

/// Voice classification result
class VoiceClassificationResult {
  final VoiceType primaryType;
  final double confidence;
  final List<VoiceTypeCandidate> alternativeTypes;
  final VocalRange vocalRange;
  final double fundamentalFrequency;
  final FormantAnalysis formants;
  final TimbreProfile timbreProfile;
  final VoiceAnalysisMetadata analysisMetadata;
  final List<String> recommendations;

  VoiceClassificationResult({
    required this.primaryType,
    required this.confidence,
    required this.alternativeTypes,
    required this.vocalRange,
    required this.fundamentalFrequency,
    required this.formants,
    required this.timbreProfile,
    required this.analysisMetadata,
    required this.recommendations,
  });
}

/// Voice type candidate with confidence
class VoiceTypeCandidate {
  final VoiceType type;
  final double confidence;

  VoiceTypeCandidate({
    required this.type,
    required this.confidence,
  });
}

/// Vocal range analysis
class VocalRange {
  final double lowestNote;
  final double highestNote;
  final FrequencyRange comfortableRange;
  final double totalRange;
  final double rangeInSemitones;

  VocalRange({
    required this.lowestNote,
    required this.highestNote,
    required this.comfortableRange,
    required this.totalRange,
    required this.rangeInSemitones,
  });
}

/// Formant analysis result
class FormantAnalysis {
  final double f1;
  final double f2;
  final double f3;
  final FrequencyRange f1Range;
  final FrequencyRange f2Range;

  FormantAnalysis({
    required this.f1,
    required this.f2,
    required this.f3,
    required this.f1Range,
    required this.f2Range,
  });
}

/// Timbre profile
class TimbreProfile {
  final double brightness;
  final double warmth;
  final double resonance;
  final double clarity;

  TimbreProfile({
    required this.brightness,
    required this.warmth,
    required this.resonance,
    required this.clarity,
  });
}

/// Voice analysis metadata
class VoiceAnalysisMetadata {
  final Duration sampleDuration;
  final int sampleRate;
  final double averageAmplitude;
  final double dynamicRange;

  VoiceAnalysisMetadata({
    required this.sampleDuration,
    required this.sampleRate,
    required this.averageAmplitude,
    required this.dynamicRange,
  });
}

/// Pitch analysis result
class PitchAnalysis {
  final List<double> pitchHistory;
  final double averagePitch;
  final double medianPitch;
  final double minPitch;
  final double maxPitch;
  final double pitchStability;
  final double pitchRange;

  PitchAnalysis({
    required this.pitchHistory,
    required this.averagePitch,
    required this.medianPitch,
    required this.minPitch,
    required this.maxPitch,
    required this.pitchStability,
    required this.pitchRange,
  });
}

/// Classification result internal class
class ClassificationResult {
  final VoiceType primaryType;
  final double confidence;
  final List<VoiceTypeCandidate> alternativeTypes;

  ClassificationResult({
    required this.primaryType,
    required this.confidence,
    required this.alternativeTypes,
  });
}

/// Spectral peak helper class
class SpectralPeak {
  final double frequency;
  final double magnitude;

  SpectralPeak({
    required this.frequency,
    required this.magnitude,
  });
}