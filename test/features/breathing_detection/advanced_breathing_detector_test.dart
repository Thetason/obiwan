import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/features/breathing_detection/advanced_breathing_detector.dart';
import '../../utils/test_utils.dart';

void main() {
  group('AdvancedBreathingDetector', () {
    late AdvancedBreathingDetector detector;
    late StreamController<BreathingAnalysis> analysisStreamController;
    
    setUp(() async {
      detector = AdvancedBreathingDetector();
      await detector.initialize();
      
      // Create a stream controller to capture analysis results
      analysisStreamController = StreamController<BreathingAnalysis>();
    });
    
    tearDown(() {
      detector.dispose();
      analysisStreamController.close();
    });
    
    group('Initialization', () {
      test('should initialize successfully', () async {
        final newDetector = AdvancedBreathingDetector();
        await newDetector.initialize();
        
        expect(newDetector.analysisStream, isNotNull);
        
        newDetector.dispose();
      });
      
      test('should handle multiple initialization calls', () async {
        final newDetector = AdvancedBreathingDetector();
        
        await newDetector.initialize();
        await newDetector.initialize(); // Second call should be safe
        
        expect(newDetector.analysisStream, isNotNull);
        
        newDetector.dispose();
      });
    });
    
    group('Audio Processing', () {
      test('should process breathing audio data', () async {
        // Generate breathing-like audio pattern
        final breathingAudio = _generateBreathingAudio(
          duration: 5.0,
          breathsPerMinute: 15,
          sampleRate: 44100,
        );
        
        detector.processAudioData(breathingAudio);
        
        // Allow time for processing
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Should have processed the audio without errors
        expect(detector.analysisStream, isNotNull);
      });
      
      test('should handle empty audio data', () {
        expect(() => detector.processAudioData([]), returnsNormally);
      });
      
      test('should handle single sample', () {
        expect(() => detector.processAudioData([0.5]), returnsNormally);
      });
      
      test('should process continuous audio stream', () async {
        const chunkSize = 1024;
        const numChunks = 10;
        
        for (int i = 0; i < numChunks; i++) {
          final chunk = TestUtils.generateSineWave(
            frequency: 100.0 + (i * 10), // Varying frequency to simulate breathing
            duration: chunkSize / 44100,
            sampleRate: 44100,
          );
          
          detector.processAudioData(chunk);
          await Future.delayed(const Duration(milliseconds: 50));
        }
        
        // Should handle continuous stream without errors
      });
    });
    
    group('Breathing Detection', () {
      test('should detect breathing events from synthetic data', () async {
        final completer = Completer<BreathingAnalysis>();
        
        // Listen for analysis results
        final subscription = detector.analysisStream.listen((analysis) {
          if (!completer.isCompleted) {
            completer.complete(analysis);
          }
        });
        
        // Generate realistic breathing pattern
        final breathingAudio = _generateBreathingAudio(
          duration: 10.0,
          breathsPerMinute: 12,
          sampleRate: 44100,
        );
        
        detector.processAudioData(breathingAudio);
        
        // Wait for analysis
        final analysis = await completer.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException('No analysis received', 5),
        );
        
        expect(analysis, isNotNull);
        expect(analysis.breathingRate, greaterThan(0));
        expect(analysis.breathingRate, lessThan(30)); // Reasonable range
        
        await subscription.cancel();
      });
      
      test('should classify different breath types', () async {
        final breathingEvents = <BreathingEvent>[];
        
        final subscription = detector.analysisStream.listen((analysis) {
          breathingEvents.addAll(analysis.recentEvents);
        });
        
        // Generate inhale pattern (increasing amplitude)
        final inhaleAudio = _generateInhalePattern(duration: 2.0, sampleRate: 44100);
        detector.processAudioData(inhaleAudio);
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Generate exhale pattern (decreasing amplitude)  
        final exhaleAudio = _generateExhalePattern(duration: 3.0, sampleRate: 44100);
        detector.processAudioData(exhaleAudio);
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Should detect both inhale and exhale events
        final inhaleEvents = breathingEvents.where((e) => e.type == BreathType.inhale);
        final exhaleEvents = breathingEvents.where((e) => e.type == BreathType.exhale);
        
        expect(inhaleEvents, isNotEmpty, reason: 'Should detect inhale events');
        expect(exhaleEvents, isNotEmpty, reason: 'Should detect exhale events');
        
        await subscription.cancel();
      });
      
      test('should calculate breathing rate accurately', () async {
        final completer = Completer<BreathingAnalysis>();
        
        final subscription = detector.analysisStream.listen((analysis) {
          if (analysis.breathingRate > 0 && !completer.isCompleted) {
            completer.complete(analysis);
          }
        });
        
        const targetRate = 15.0; // breaths per minute
        final breathingAudio = _generateBreathingAudio(
          duration: 60.0, // 1 minute for accurate rate calculation
          breathsPerMinute: targetRate,
          sampleRate: 44100,
        );
        
        detector.processAudioData(breathingAudio);
        
        final analysis = await completer.future.timeout(const Duration(seconds: 10));
        
        // Should be within 20% of target rate
        expect(analysis.breathingRate, closeTo(targetRate, targetRate * 0.2));
        
        await subscription.cancel();
      });
    });
    
    group('Rhythm Analysis', () {
      test('should detect regular breathing rhythm', () async {
        final completer = Completer<BreathingAnalysis>();
        
        final subscription = detector.analysisStream.listen((analysis) {
          if (!completer.isCompleted) {
            completer.complete(analysis);
          }
        });
        
        // Generate very regular breathing pattern
        final regularBreathing = _generateBreathingAudio(
          duration: 30.0,
          breathsPerMinute: 12,
          sampleRate: 44100,
          irregularity: 0.0, // Perfect regularity
        );
        
        detector.processAudioData(regularBreathing);
        
        final analysis = await completer.future.timeout(const Duration(seconds: 5));
        
        expect(analysis.rhythmRegularity, greaterThan(0.8),
               reason: 'Regular breathing should have high rhythm regularity');
        
        await subscription.cancel();
      });
      
      test('should detect irregular breathing rhythm', () async {
        final completer = Completer<BreathingAnalysis>();
        
        final subscription = detector.analysisStream.listen((analysis) {
          if (!completer.isCompleted) {
            completer.complete(analysis);
          }
        });
        
        // Generate irregular breathing pattern
        final irregularBreathing = _generateBreathingAudio(
          duration: 30.0,
          breathsPerMinute: 12,
          sampleRate: 44100,
          irregularity: 0.5, // High irregularity
        );
        
        detector.processAudioData(irregularBreathing);
        
        final analysis = await completer.future.timeout(const Duration(seconds: 5));
        
        expect(analysis.rhythmRegularity, lessThan(0.6),
               reason: 'Irregular breathing should have low rhythm regularity');
        
        await subscription.cancel();
      });
    });
    
    group('Efficiency Assessment', () {
      test('should assess breathing efficiency', () async {
        final completer = Completer<BreathingAnalysis>();
        
        final subscription = detector.analysisStream.listen((analysis) {
          if (!completer.isCompleted) {
            completer.complete(analysis);
          }
        });
        
        // Generate breathing with ideal 1:2 inhale:exhale ratio
        final efficientBreathing = _generateEfficientBreathing(
          duration: 20.0,
          sampleRate: 44100,
        );
        
        detector.processAudioData(efficientBreathing);
        
        final analysis = await completer.future.timeout(const Duration(seconds: 5));
        
        expect(analysis.efficiency, greaterThan(0.5),
               reason: 'Efficient breathing pattern should have good efficiency score');
        expect(analysis.inhaleExhaleRatio, closeTo(2.0, 0.5),
               reason: 'Should detect proper inhale:exhale ratio');
        
        await subscription.cancel();
      });
    });
    
    group('Pattern Recognition', () {
      test('should identify normal breathing pattern', () async {
        final completer = Completer<BreathingAnalysis>();
        
        final subscription = detector.analysisStream.listen((analysis) {
          if (!completer.isCompleted) {
            completer.complete(analysis);
          }
        });
        
        final normalBreathing = _generateBreathingAudio(
          duration: 15.0,
          breathsPerMinute: 16, // Normal rate
          sampleRate: 44100,
        );
        
        detector.processAudioData(normalBreathing);
        
        final analysis = await completer.future.timeout(const Duration(seconds: 5));
        
        expect(analysis.pattern, equals(BreathingPattern.normal),
               reason: 'Should identify normal breathing pattern');
        
        await subscription.cancel();
      });
      
      test('should identify rapid breathing pattern', () async {
        final completer = Completer<BreathingAnalysis>();
        
        final subscription = detector.analysisStream.listen((analysis) {
          if (!completer.isCompleted) {
            completer.complete(analysis);
          }
        });
        
        final rapidBreathing = _generateBreathingAudio(
          duration: 10.0,
          breathsPerMinute: 25, // Rapid breathing
          sampleRate: 44100,
        );
        
        detector.processAudioData(rapidBreathing);
        
        final analysis = await completer.future.timeout(const Duration(seconds: 5));
        
        expect(analysis.pattern, equals(BreathingPattern.rapid),
               reason: 'Should identify rapid breathing pattern');
        
        await subscription.cancel();
      });
    });
    
    group('Insights Generation', () {
      test('should generate helpful insights', () async {
        final completer = Completer<BreathingAnalysis>();
        
        final subscription = detector.analysisStream.listen((analysis) {
          if (analysis.insights.isNotEmpty && !completer.isCompleted) {
            completer.complete(analysis);
          }
        });
        
        // Generate breathing that should trigger insights
        final problematicBreathing = _generateBreathingAudio(
          duration: 20.0,
          breathsPerMinute: 8, // Too slow
          sampleRate: 44100,
          irregularity: 0.3,
        );
        
        detector.processAudioData(problematicBreathing);
        
        final analysis = await completer.future.timeout(const Duration(seconds: 5));
        
        expect(analysis.insights, isNotEmpty,
               reason: 'Should generate insights for problematic breathing');
        
        final hasRateInsight = analysis.insights
            .any((insight) => insight.type == BreathingInsightType.rate);
        expect(hasRateInsight, isTrue,
               reason: 'Should identify rate issues');
        
        await subscription.cancel();
      });
      
      test('should provide actionable recommendations', () async {
        final completer = Completer<BreathingAnalysis>();
        
        final subscription = detector.analysisStream.listen((analysis) {
          if (analysis.insights.isNotEmpty && !completer.isCompleted) {
            completer.complete(analysis);
          }
        });
        
        final irregularBreathing = _generateBreathingAudio(
          duration: 15.0,
          breathsPerMinute: 12,
          sampleRate: 44100,
          irregularity: 0.4, // Irregular
        );
        
        detector.processAudioData(irregularBreathing);
        
        final analysis = await completer.future.timeout(const Duration(seconds: 5));
        
        for (final insight in analysis.insights) {
          expect(insight.recommendation, isNotEmpty,
                 reason: 'Each insight should have a recommendation');
          expect(insight.message, isNotEmpty,
                 reason: 'Each insight should have a message');
        }
        
        await subscription.cancel();
      });
    });
    
    group('Statistics', () {
      test('should provide accurate statistics', () async {
        // Process some breathing data first
        final breathingAudio = _generateBreathingAudio(
          duration: 30.0,
          breathsPerMinute: 15,
          sampleRate: 44100,
        );
        
        detector.processAudioData(breathingAudio);
        
        // Allow processing time
        await Future.delayed(const Duration(seconds: 1));
        
        final stats = detector.getCurrentStatistics();
        
        expect(stats, isNotNull);
        expect(stats.totalBreaths, greaterThanOrEqualTo(0));
        expect(stats.averageRate, greaterThanOrEqualTo(0));
        expect(stats.rhythmRegularity, greaterThanOrEqualTo(0));
        expect(stats.rhythmRegularity, lessThanOrEqualTo(1));
        expect(stats.efficiency, greaterThanOrEqualTo(0));
        expect(stats.efficiency, lessThanOrEqualTo(1));
      });
    });
    
    group('Performance', () {
      test('should process audio efficiently', () async {
        const chunkSize = 2048;
        final audioChunk = TestUtils.generateSineWave(
          frequency: 200.0,
          duration: chunkSize / 44100,
          sampleRate: 44100,
        );
        
        final stopwatch = Stopwatch()..start();
        
        detector.processAudioData(audioChunk);
        
        stopwatch.stop();
        
        // Should process much faster than real-time
        final realTimeMs = (chunkSize / 44100 * 1000).round();
        expect(stopwatch.elapsedMilliseconds, lessThan(realTimeMs),
               reason: 'Should process faster than real-time');
      });
      
      test('should handle continuous processing', () async {
        const numChunks = 50;
        const chunkSize = 1024;
        
        for (int i = 0; i < numChunks; i++) {
          final chunk = TestUtils.generateSineWave(
            frequency: 100.0 + (i % 10) * 20,
            duration: chunkSize / 44100,
            sampleRate: 44100,
          );
          
          detector.processAudioData(chunk);
          
          // Small delay to simulate real-time processing
          await Future.delayed(const Duration(milliseconds: 10));
        }
        
        // Should complete without errors or memory issues
      });
    });
    
    group('Error Handling', () {
      test('should handle invalid audio data gracefully', () {
        // Test with NaN values
        final invalidAudio = [double.nan, double.infinity, -double.infinity];
        
        expect(() => detector.processAudioData(invalidAudio), returnsNormally);
      });
      
      test('should handle extremely large values', () {
        final extremeAudio = [1e10, -1e10, 1e20];
        
        expect(() => detector.processAudioData(extremeAudio), returnsNormally);
      });
      
      test('should handle rapid successive calls', () async {
        final audioChunk = TestUtils.generateSineWave(
          frequency: 100.0,
          duration: 0.1,
          sampleRate: 44100,
        );
        
        // Rapid successive calls
        for (int i = 0; i < 100; i++) {
          detector.processAudioData(audioChunk);
        }
        
        // Should handle without crashing
      });
    });
  });
}

// Helper functions to generate test breathing patterns

List<double> _generateBreathingAudio({
  required double duration,
  required double breathsPerMinute,
  required int sampleRate,
  double irregularity = 0.1,
}) {
  final sampleCount = (duration * sampleRate).round();
  final audioData = <double>[];
  final random = math.Random(42);
  
  final breathPeriod = 60.0 / breathsPerMinute;
  
  for (int i = 0; i < sampleCount; i++) {
    final t = i / sampleRate;
    
    // Add irregularity to breath timing
    final irregularityFactor = 1.0 + irregularity * (random.nextDouble() * 2.0 - 1.0);
    final adjustedT = t * irregularityFactor;
    
    final cyclePosition = (adjustedT % breathPeriod) / breathPeriod;
    
    double amplitude;
    if (cyclePosition < 0.4) {
      // Inhale phase - increasing amplitude
      amplitude = math.sin(cyclePosition * math.pi / 0.4) * 0.5;
    } else if (cyclePosition < 0.5) {
      // Hold phase
      amplitude = 0.5;
    } else {
      // Exhale phase - decreasing amplitude
      final exhalePos = (cyclePosition - 0.5) / 0.5;
      amplitude = 0.5 * (1.0 - exhalePos);
    }
    
    // Generate breathing sound (mix of low frequencies)
    double sample = 0.0;
    sample += amplitude * math.sin(2 * math.pi * 80 * t);   // Fundamental
    sample += amplitude * 0.5 * math.sin(2 * math.pi * 160 * t); // Harmonic
    sample += amplitude * 0.3 * math.sin(2 * math.pi * 240 * t); // Harmonic
    
    // Add some noise for realism
    sample += 0.05 * (random.nextDouble() * 2.0 - 1.0);
    
    audioData.add(sample);
  }
  
  return audioData;
}

List<double> _generateInhalePattern({
  required double duration,
  required int sampleRate,
}) {
  final sampleCount = (duration * sampleRate).round();
  final audioData = <double>[];
  
  for (int i = 0; i < sampleCount; i++) {
    final t = i / sampleCount; // Normalized time 0-1
    final amplitude = t; // Increasing amplitude
    
    // Breathing sound with increasing amplitude
    double sample = 0.0;
    sample += amplitude * math.sin(2 * math.pi * 100 * t * duration);
    sample += amplitude * 0.5 * math.sin(2 * math.pi * 200 * t * duration);
    
    audioData.add(sample);
  }
  
  return audioData;
}

List<double> _generateExhalePattern({
  required double duration,
  required int sampleRate,
}) {
  final sampleCount = (duration * sampleRate).round();
  final audioData = <double>[];
  
  for (int i = 0; i < sampleCount; i++) {
    final t = i / sampleCount; // Normalized time 0-1
    final amplitude = 1.0 - t; // Decreasing amplitude
    
    // Breathing sound with decreasing amplitude
    double sample = 0.0;
    sample += amplitude * math.sin(2 * math.pi * 120 * t * duration);
    sample += amplitude * 0.4 * math.sin(2 * math.pi * 180 * t * duration);
    
    audioData.add(sample);
  }
  
  return audioData;
}

List<double> _generateEfficientBreathing({
  required double duration,
  required int sampleRate,
}) {
  final sampleCount = (duration * sampleRate).round();
  final audioData = <double>[];
  
  const breathsPerMinute = 12;
  const breathPeriod = 60.0 / breathsPerMinute; // 5 seconds per breath
  const inhaleDuration = breathPeriod / 3; // 1.67 seconds
  const exhaleDuration = breathPeriod * 2 / 3; // 3.33 seconds (2:1 ratio)
  
  for (int i = 0; i < sampleCount; i++) {
    final t = i / sampleRate;
    final cyclePosition = t % breathPeriod;
    
    double amplitude;
    if (cyclePosition < inhaleDuration) {
      // Inhale phase
      final inhalePos = cyclePosition / inhaleDuration;
      amplitude = math.sin(inhalePos * math.pi / 2) * 0.6;
    } else {
      // Exhale phase
      final exhalePos = (cyclePosition - inhaleDuration) / exhaleDuration;
      amplitude = 0.6 * (1.0 - exhalePos);
    }
    
    // Generate breathing sound
    double sample = 0.0;
    sample += amplitude * math.sin(2 * math.pi * 90 * t);
    sample += amplitude * 0.3 * math.sin(2 * math.pi * 180 * t);
    
    audioData.add(sample);
  }
  
  return audioData;
}