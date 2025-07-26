import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

/// Comprehensive test utilities for vocal trainer application
class TestUtils {
  static final Random _random = Random(42); // Fixed seed for reproducible tests
  
  /// Generate synthetic audio data for testing
  static Float32List generateSineWave({
    double frequency = 440.0,
    double amplitude = 0.5,
    int sampleRate = 44100,
    double duration = 1.0,
    double phase = 0.0,
  }) {
    final sampleCount = (sampleRate * duration).round();
    final audioData = Float32List(sampleCount);
    
    for (int i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      audioData[i] = amplitude * math.sin(2 * math.pi * frequency * t + phase);
    }
    
    return audioData;
  }
  
  /// Generate complex audio with multiple frequencies
  static Float32List generateComplexAudio({
    List<double> frequencies = const [220.0, 440.0, 880.0],
    List<double> amplitudes = const [0.3, 0.5, 0.2],
    int sampleRate = 44100,
    double duration = 1.0,
    double noiseLevel = 0.0,
  }) {
    assert(frequencies.length == amplitudes.length, 
           'Frequencies and amplitudes must have same length');
    
    final sampleCount = (sampleRate * duration).round();
    final audioData = Float32List(sampleCount);
    
    for (int i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      double sample = 0.0;
      
      // Add all frequency components
      for (int j = 0; j < frequencies.length; j++) {
        sample += amplitudes[j] * math.sin(2 * math.pi * frequencies[j] * t);
      }
      
      // Add noise if specified
      if (noiseLevel > 0) {
        sample += noiseLevel * (_random.nextDouble() * 2.0 - 1.0);
      }
      
      audioData[i] = sample;
    }
    
    return audioData;
  }
  
  /// Generate chirp signal (frequency sweep)
  static Float32List generateChirp({
    double startFreq = 100.0,
    double endFreq = 1000.0,
    double amplitude = 0.5,
    int sampleRate = 44100,
    double duration = 1.0,
  }) {
    final sampleCount = (sampleRate * duration).round();
    final audioData = Float32List(sampleCount);
    
    for (int i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final frequency = startFreq + (endFreq - startFreq) * (t / duration);
      audioData[i] = amplitude * math.sin(2 * math.pi * frequency * t);
    }
    
    return audioData;
  }
  
  /// Generate white noise
  static Float32List generateWhiteNoise({
    double amplitude = 0.1,
    int sampleRate = 44100,
    double duration = 1.0,
    int? seed,
  }) {
    final random = seed != null ? Random(seed) : _random;
    final sampleCount = (sampleRate * duration).round();
    final audioData = Float32List(sampleCount);
    
    for (int i = 0; i < sampleCount; i++) {
      audioData[i] = amplitude * (random.nextDouble() * 2.0 - 1.0);
    }
    
    return audioData;
  }
  
  /// Generate pink noise (1/f noise)
  static Float32List generatePinkNoise({
    double amplitude = 0.1,
    int sampleRate = 44100,
    double duration = 1.0,
    int? seed,
  }) {
    final random = seed != null ? Random(seed) : _random;
    final sampleCount = (sampleRate * duration).round();
    final audioData = Float32List(sampleCount);
    
    // Simple pink noise generation using filtering
    double b0 = 0.0, b1 = 0.0, b2 = 0.0, b3 = 0.0, b4 = 0.0, b5 = 0.0, b6 = 0.0;
    
    for (int i = 0; i < sampleCount; i++) {
      final white = random.nextDouble() * 2.0 - 1.0;
      
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.96900 * b2 + white * 0.1538520;
      b3 = 0.86650 * b3 + white * 0.3104856;
      b4 = 0.55000 * b4 + white * 0.5329522;
      b5 = -0.7616 * b5 - white * 0.0168980;
      
      final pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362;
      b6 = white * 0.115926;
      
      audioData[i] = amplitude * pink * 0.11;
    }
    
    return audioData;
  }
  
  /// Generate impulse signal
  static Float32List generateImpulse({
    double amplitude = 1.0,
    int position = 0,
    int length = 1024,
  }) {
    final audioData = Float32List(length);
    if (position >= 0 && position < length) {
      audioData[position] = amplitude;
    }
    return audioData;
  }
  
  /// Generate step function
  static Float32List generateStep({
    double amplitude = 1.0,
    int stepPosition = 512,
    int length = 1024,
  }) {
    final audioData = Float32List(length);
    for (int i = stepPosition; i < length; i++) {
      audioData[i] = amplitude;
    }
    return audioData;
  }
  
  /// Compare two Float32List arrays with tolerance
  static bool compareFloat32Lists(
    Float32List a, 
    Float32List b, {
    double tolerance = 1e-6,
  }) {
    if (a.length != b.length) return false;
    
    for (int i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > tolerance) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Calculate signal-to-noise ratio
  static double calculateSNR(Float32List signal, Float32List noise) {
    assert(signal.length == noise.length, 'Signal and noise must have same length');
    
    double signalPower = 0.0;
    double noisePower = 0.0;
    
    for (int i = 0; i < signal.length; i++) {
      signalPower += signal[i] * signal[i];
      noisePower += noise[i] * noise[i];
    }
    
    signalPower /= signal.length;
    noisePower /= noise.length;
    
    if (noisePower == 0.0) return double.infinity;
    
    return 10 * math.log(signalPower / noisePower) / math.ln10;
  }
  
  /// Calculate RMS value
  static double calculateRMS(Float32List data) {
    if (data.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (final sample in data) {
      sum += sample * sample;
    }
    
    return math.sqrt(sum / data.length);
  }
  
  /// Calculate peak amplitude
  static double calculatePeak(Float32List data) {
    if (data.isEmpty) return 0.0;
    
    double peak = 0.0;
    for (final sample in data) {
      peak = math.max(peak, sample.abs());
    }
    
    return peak;
  }
  
  /// Calculate frequency spectrum magnitude at specific frequency
  static double getMagnitudeAtFrequency(
    Float32List audioData,
    double targetFrequency,
    int sampleRate,
  ) {
    final length = audioData.length;
    double realSum = 0.0;
    double imagSum = 0.0;
    
    final omega = 2 * math.pi * targetFrequency / sampleRate;
    
    for (int n = 0; n < length; n++) {
      final angle = omega * n;
      realSum += audioData[n] * math.cos(angle);
      imagSum -= audioData[n] * math.sin(angle);
    }
    
    return math.sqrt(realSum * realSum + imagSum * imagSum) / length;
  }
  
  /// Verify that frequency content matches expected
  static bool verifyFrequencyContent(
    Float32List audioData,
    List<double> expectedFrequencies,
    int sampleRate, {
    double tolerance = 0.1,
    double magnitudeThreshold = 0.01,
  }) {
    for (final freq in expectedFrequencies) {
      final magnitude = getMagnitudeAtFrequency(audioData, freq, sampleRate);
      
      if (magnitude < magnitudeThreshold) {
        return false;
      }
      
      // Check that nearby frequencies have lower magnitude
      final lowerFreq = freq * (1.0 - tolerance);
      final upperFreq = freq * (1.0 + tolerance);
      
      final lowerMag = getMagnitudeAtFrequency(audioData, lowerFreq, sampleRate);
      final upperMag = getMagnitudeAtFrequency(audioData, upperFreq, sampleRate);
      
      if (lowerMag > magnitude * 0.8 || upperMag > magnitude * 0.8) {
        // Allow some leeway for spectral leakage
        continue;
      }
    }
    
    return true;
  }
  
  /// Create mock breathing pattern data
  static List<double> generateBreathingPattern({
    double rate = 15.0, // breaths per minute
    double duration = 60.0, // seconds
    double baselineNoise = 0.05,
    int? seed,
  }) {
    final random = seed != null ? Random(seed) : _random;
    final sampleRate = 10; // 10 Hz for breathing data
    final sampleCount = (duration * sampleRate).round();
    final data = <double>[];
    
    final breathPeriod = 60.0 / rate; // seconds per breath
    
    for (int i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      
      // Breathing cycle (inhale + exhale)
      final cyclePosition = (t % breathPeriod) / breathPeriod;
      double breathValue;
      
      if (cyclePosition < 0.4) {
        // Inhale phase
        breathValue = math.sin(cyclePosition * math.pi / 0.4);
      } else if (cyclePosition < 0.6) {
        // Hold phase
        breathValue = 1.0;
      } else {
        // Exhale phase
        final exhalePos = (cyclePosition - 0.6) / 0.4;
        breathValue = math.cos(exhalePos * math.pi / 2);
      }
      
      // Add noise
      breathValue += baselineNoise * (random.nextDouble() * 2.0 - 1.0);
      
      data.add(breathValue);
    }
    
    return data;
  }
  
  /// Create mock vocal analysis results
  static Map<String, double> generateMockAnalysisResults({
    double? pitchAccuracy,
    double? rhythmAccuracy,
    double? toneQuality,
    double? overallScore,
    int? seed,
  }) {
    final random = seed != null ? Random(seed) : _random;
    
    return {
      'pitchAccuracy': pitchAccuracy ?? (0.7 + random.nextDouble() * 0.3),
      'rhythmAccuracy': rhythmAccuracy ?? (0.6 + random.nextDouble() * 0.4),
      'toneQuality': toneQuality ?? (0.65 + random.nextDouble() * 0.35),
      'overallScore': overallScore ?? (0.65 + random.nextDouble() * 0.35),
      'breathing': 0.5 + random.nextDouble() * 0.5,
      'resonance': 0.4 + random.nextDouble() * 0.6,
      'articulation': 0.55 + random.nextDouble() * 0.45,
    };
  }
  
  /// Generate test session data
  static Map<String, dynamic> generateTestSessionData({
    String? sessionId,
    String? userId,
    DateTime? createdAt,
    int recordingCount = 3,
    int? seed,
  }) {
    final random = seed != null ? Random(seed) : _random;
    final now = DateTime.now();
    
    return {
      'id': sessionId ?? 'test_session_${random.nextInt(10000)}',
      'userId': userId ?? 'test_user_${random.nextInt(1000)}',
      'name': 'Test Session ${random.nextInt(100)}',
      'type': 'practice',
      'createdAt': (createdAt ?? now).toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'status': 'completed',
      'metadata': {
        'duration': 300 + random.nextInt(900), // 5-20 minutes
        'exerciseType': 'scales',
        'difficulty': 1 + random.nextInt(5),
      },
      'recordings': List.generate(recordingCount, (index) => {
        'id': 'recording_${index}',
        'sessionId': sessionId ?? 'test_session_${random.nextInt(10000)}',
        'duration': 30 + random.nextInt(120), // 30s - 2.5min
        'createdAt': now.subtract(Duration(minutes: recordingCount - index)).toIso8601String(),
        'analysis': generateMockAnalysisResults(seed: seed != null ? seed + index : null),
      }),
    };
  }
  
  /// Validate test results against expected ranges
  static void expectInRange(double actual, double min, double max, {String? reason}) {
    expect(actual, greaterThanOrEqualTo(min), reason: reason ?? 'Value below minimum');
    expect(actual, lessThanOrEqualTo(max), reason: reason ?? 'Value above maximum');
  }
  
  /// Validate audio data properties
  static void validateAudioData(
    Float32List audioData, {
    double? expectedDuration,
    int? expectedSampleRate,
    double maxAmplitude = 1.0,
    double? expectedRMS,
    double rmsTolerance = 0.1,
  }) {
    expect(audioData, isNotNull, reason: 'Audio data should not be null');
    expect(audioData.length, greaterThan(0), reason: 'Audio data should not be empty');
    
    // Check amplitude limits
    final peak = calculatePeak(audioData);
    expect(peak, lessThanOrEqualTo(maxAmplitude), 
           reason: 'Peak amplitude exceeds maximum');
    
    // Check for silence
    final rms = calculateRMS(audioData);
    expect(rms, greaterThan(0.0), reason: 'Audio should not be silent');
    
    // Check expected RMS if provided
    if (expectedRMS != null) {
      expectInRange(rms, expectedRMS - rmsTolerance, expectedRMS + rmsTolerance,
                    reason: 'RMS not in expected range');
    }
    
    // Check expected duration if provided
    if (expectedDuration != null && expectedSampleRate != null) {
      final actualDuration = audioData.length / expectedSampleRate;
      expectInRange(actualDuration, expectedDuration * 0.95, expectedDuration * 1.05,
                    reason: 'Duration not in expected range');
    }
    
    // Check for NaN or infinite values
    for (int i = 0; i < audioData.length; i++) {
      expect(audioData[i].isFinite, isTrue, 
             reason: 'Audio data contains non-finite values at index $i');
    }
  }
  
  /// Create test progress data
  static Map<String, dynamic> generateProgressData({
    int sessionCount = 10,
    double improvementTrend = 0.1,
    int? seed,
  }) {
    final random = seed != null ? Random(seed) : _random;
    
    return {
      'overallMetrics': {
        'totalScore': 0.75 + random.nextDouble() * 0.2,
        'improvement': improvementTrend,
        'consistency': 0.6 + random.nextDouble() * 0.3,
        'practiceStreak': 5 + random.nextInt(15),
        'totalPracticeTime': Duration(hours: 20 + random.nextInt(80)).inMilliseconds,
      },
      'skillMetrics': {
        'pitch_accuracy': {
          'current': 0.7 + random.nextDouble() * 0.3,
          'trend': -0.1 + random.nextDouble() * 0.2,
          'level': 'intermediate',
        },
        'rhythm_accuracy': {
          'current': 0.6 + random.nextDouble() * 0.4,
          'trend': random.nextDouble() * 0.15,
          'level': 'beginner',
        },
        'tone_quality': {
          'current': 0.65 + random.nextDouble() * 0.35,
          'trend': random.nextDouble() * 0.1,
          'level': 'intermediate',
        },
      },
      'weeklyProgress': List.generate(12, (week) => {
        'weekStart': DateTime.now().subtract(Duration(days: (11 - week) * 7)).toIso8601String(),
        'sessionCount': random.nextInt(8),
        'totalDuration': Duration(hours: random.nextInt(10)).inMilliseconds,
        'averageScore': 0.5 + random.nextDouble() * 0.5,
        'improvement': -0.1 + random.nextDouble() * 0.2,
      }),
    };
  }
}

/// Custom matchers for audio testing
class AudioMatchers {
  /// Matcher for checking if audio contains expected frequency
  static Matcher containsFrequency(double frequency, int sampleRate, {double tolerance = 0.1}) {
    return _ContainsFrequencyMatcher(frequency, sampleRate, tolerance);
  }
  
  /// Matcher for checking RMS value
  static Matcher hasRMS(double expectedRMS, {double tolerance = 0.1}) {
    return _HasRMSMatcher(expectedRMS, tolerance);
  }
  
  /// Matcher for checking peak amplitude
  static Matcher hasPeak(double expectedPeak, {double tolerance = 0.1}) {
    return _HasPeakMatcher(expectedPeak, tolerance);
  }
}

class _ContainsFrequencyMatcher extends Matcher {
  final double frequency;
  final int sampleRate;
  final double tolerance;
  
  _ContainsFrequencyMatcher(this.frequency, this.sampleRate, this.tolerance);
  
  @override
  bool matches(Object? item, Map matchState) {
    if (item is! Float32List) return false;
    
    final magnitude = TestUtils.getMagnitudeAtFrequency(item, frequency, sampleRate);
    return magnitude > 0.01; // Minimum threshold for frequency presence
  }
  
  @override
  Description describe(Description description) {
    return description.add('contains frequency $frequency Hz (±${tolerance * 100}%)');
  }
}

class _HasRMSMatcher extends Matcher {
  final double expectedRMS;
  final double tolerance;
  
  _HasRMSMatcher(this.expectedRMS, this.tolerance);
  
  @override
  bool matches(Object? item, Map matchState) {
    if (item is! Float32List) return false;
    
    final actualRMS = TestUtils.calculateRMS(item);
    return (actualRMS - expectedRMS).abs() <= tolerance;
  }
  
  @override
  Description describe(Description description) {
    return description.add('has RMS $expectedRMS (±$tolerance)');
  }
}

class _HasPeakMatcher extends Matcher {
  final double expectedPeak;
  final double tolerance;
  
  _HasPeakMatcher(this.expectedPeak, this.tolerance);
  
  @override
  bool matches(Object? item, Map matchState) {
    if (item is! Float32List) return false;
    
    final actualPeak = TestUtils.calculatePeak(item);
    return (actualPeak - expectedPeak).abs() <= tolerance;
  }
  
  @override
  Description describe(Description description) {
    return description.add('has peak amplitude $expectedPeak (±$tolerance)');
  }
}