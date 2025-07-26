import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/features/audio_analysis/pitch_correction_engine.dart';
import '../../utils/test_utils.dart';

void main() {
  group('PitchCorrectionEngine', () {
    late PitchCorrectionEngine engine;
    
    setUp(() {
      engine = PitchCorrectionEngine();
    });
    
    tearDown(() {
      engine.dispose();
    });
    
    group('Initialization', () {
      test('should initialize with default parameters', () {
        expect(engine.isEnabled, isTrue);
        expect(engine.correctionStrength, equals(0.8));
        expect(engine.currentScale, equals(Scale.chromatic));
      });
      
      test('should initialize successfully', () async {
        await engine.initialize();
        expect(engine.isInitialized, isTrue);
      });
    });
    
    group('Basic Pitch Correction', () {
      setUp(() async {
        await engine.initialize();
      });
      
      test('should process audio data without errors', () async {
        final inputAudio = TestUtils.generateSineWave(
          frequency: 440.0,
          duration: 1.0,
          sampleRate: 44100,
        );
        
        final pitchValues = List.generate(
          inputAudio.length ~/ 512, 
          (index) => 440.0 + (index * 2.0), // Slightly off-pitch
        );
        
        final result = await engine.processPitchCorrection(
          inputAudio,
          pitchValues,
        );
        
        expect(result, isNotNull);
        expect(result.length, equals(inputAudio.length));
        TestUtils.validateAudioData(result, maxAmplitude: 1.5);
      });
      
      test('should handle empty audio data gracefully', () async {
        final emptyAudio = Float32List(0);
        final emptyPitchValues = <double>[];
        
        final result = await engine.processPitchCorrection(
          emptyAudio,
          emptyPitchValues,
        );
        
        expect(result, isNotNull);
        expect(result.length, equals(0));
      });
      
      test('should handle single sample audio', () async {
        final singleSample = Float32List.fromList([0.5]);
        final singlePitch = [440.0];
        
        final result = await engine.processPitchCorrection(
          singleSample,
          singlePitch,
        );
        
        expect(result, isNotNull);
        expect(result.length, equals(1));
      });
      
      test('should correct pitch towards target scale', () async {
        // Generate slightly flat A4 (435 Hz instead of 440 Hz)
        final inputAudio = TestUtils.generateSineWave(
          frequency: 435.0,
          duration: 0.5,
          sampleRate: 44100,
        );
        
        final pitchValues = List.filled(
          inputAudio.length ~/ 512,
          435.0,
        );
        
        engine.setScale(Scale.equalTemperament);
        engine.setCorrectionStrength(1.0); // Maximum correction
        
        final result = await engine.processPitchCorrection(
          inputAudio,
          pitchValues,
        );
        
        // The corrected audio should have frequency content closer to 440 Hz
        final magnitude440 = TestUtils.getMagnitudeAtFrequency(result, 440.0, 44100);
        final magnitude435 = TestUtils.getMagnitudeAtFrequency(result, 435.0, 44100);
        
        expect(magnitude440, greaterThan(magnitude435 * 0.8), 
               reason: 'Pitch correction should shift energy towards 440 Hz');
      });
    });
    
    group('Scale Configuration', () {
      setUp(() async {
        await engine.initialize();
      });
      
      test('should set different scales correctly', () {
        engine.setScale(Scale.major);
        expect(engine.currentScale, equals(Scale.major));
        
        engine.setScale(Scale.minor);
        expect(engine.currentScale, equals(Scale.minor));
        
        engine.setScale(Scale.pentatonic);
        expect(engine.currentScale, equals(Scale.pentatonic));
      });
      
      test('should set key correctly', () {
        engine.setKey(Key.c);
        expect(engine.currentKey, equals(Key.c));
        
        engine.setKey(Key.fSharp);
        expect(engine.currentKey, equals(Key.fSharp));
      });
      
      test('should generate correct scale frequencies', () {
        engine.setScale(Scale.major);
        engine.setKey(Key.c);
        
        final scaleFreqs = engine.getScaleFrequencies();
        
        expect(scaleFreqs, isNotEmpty);
        expect(scaleFreqs, contains(closeTo(261.63, 0.1))); // C4
        expect(scaleFreqs, contains(closeTo(293.66, 0.1))); // D4
        expect(scaleFreqs, contains(closeTo(329.63, 0.1))); // E4
        expect(scaleFreqs, contains(closeTo(349.23, 0.1))); // F4
      });
    });
    
    group('Correction Strength', () {
      setUp(() async {
        await engine.initialize();
      });
      
      test('should set correction strength within valid range', () {
        engine.setCorrectionStrength(0.5);
        expect(engine.correctionStrength, equals(0.5));
        
        engine.setCorrectionStrength(1.0);
        expect(engine.correctionStrength, equals(1.0));
        
        engine.setCorrectionStrength(0.0);
        expect(engine.correctionStrength, equals(0.0));
      });
      
      test('should clamp correction strength to valid range', () {
        engine.setCorrectionStrength(-0.5);
        expect(engine.correctionStrength, equals(0.0));
        
        engine.setCorrectionStrength(1.5);
        expect(engine.correctionStrength, equals(1.0));
      });
      
      test('should apply different correction strengths', () async {
        final inputAudio = TestUtils.generateSineWave(
          frequency: 435.0, // Slightly flat A4
          duration: 0.5,
          sampleRate: 44100,
        );
        
        final pitchValues = List.filled(
          inputAudio.length ~/ 512,
          435.0,
        );
        
        // Test with low correction strength
        engine.setCorrectionStrength(0.2);
        final lowCorrectionResult = await engine.processPitchCorrection(
          inputAudio,
          pitchValues,
        );
        
        // Test with high correction strength  
        engine.setCorrectionStrength(0.9);
        final highCorrectionResult = await engine.processPitchCorrection(
          inputAudio,
          pitchValues,
        );
        
        // High correction should show more change from original
        final originalMag435 = TestUtils.getMagnitudeAtFrequency(inputAudio, 435.0, 44100);
        final lowMag435 = TestUtils.getMagnitudeAtFrequency(lowCorrectionResult, 435.0, 44100);
        final highMag435 = TestUtils.getMagnitudeAtFrequency(highCorrectionResult, 435.0, 44100);
        
        expect(highMag435, lessThan(lowMag435),
               reason: 'Higher correction strength should reduce original frequency content more');
      });
    });
    
    group('Pitch Detection Integration', () {
      setUp(() async {
        await engine.initialize();
      });
      
      test('should detect pitch accurately from sine wave', () async {
        final testFrequency = 523.25; // C5
        final inputAudio = TestUtils.generateSineWave(
          frequency: testFrequency,
          duration: 1.0,
          sampleRate: 44100,
        );
        
        final detectedPitches = await engine.detectPitchValues(inputAudio);
        
        expect(detectedPitches, isNotEmpty);
        
        // Check that detected pitches are close to expected frequency
        final averagePitch = detectedPitches.reduce((a, b) => a + b) / detectedPitches.length;
        expect(averagePitch, closeTo(testFrequency, 10.0),
               reason: 'Detected pitch should be close to input frequency');
      });
      
      test('should handle noisy audio', () async {
        final cleanSine = TestUtils.generateSineWave(
          frequency: 440.0,
          duration: 1.0,
          sampleRate: 44100,
        );
        
        final noise = TestUtils.generateWhiteNoise(
          amplitude: 0.1,
          duration: 1.0,
          sampleRate: 44100,
        );
        
        // Mix clean sine with noise
        final noisyAudio = Float32List(cleanSine.length);
        for (int i = 0; i < cleanSine.length; i++) {
          noisyAudio[i] = cleanSine[i] + noise[i];
        }
        
        final detectedPitches = await engine.detectPitchValues(noisyAudio);
        
        expect(detectedPitches, isNotEmpty);
        
        // Should still detect the fundamental frequency despite noise
        final averagePitch = detectedPitches.reduce((a, b) => a + b) / detectedPitches.length;
        expect(averagePitch, closeTo(440.0, 20.0),
               reason: 'Should detect fundamental frequency even with noise');
      });
    });
    
    group('Real-time Processing', () {
      setUp(() async {
        await engine.initialize();
      });
      
      test('should process audio chunks in real-time', () async {
        const chunkSize = 1024;
        const numChunks = 10;
        
        // Create continuous sine wave split into chunks
        final fullAudio = TestUtils.generateSineWave(
          frequency: 440.0,
          duration: numChunks * chunkSize / 44100,
          sampleRate: 44100,
        );
        
        final results = <Float32List>[];
        
        for (int i = 0; i < numChunks; i++) {
          final start = i * chunkSize;
          final end = math.min(start + chunkSize, fullAudio.length);
          final chunk = Float32List.sublistView(fullAudio, start, end);
          
          final pitchValues = [440.0 + (i * 2.0)]; // Slightly varying pitch
          
          final result = await engine.processPitchCorrection(chunk, pitchValues);
          results.add(result);
        }
        
        expect(results.length, equals(numChunks));
        
        for (final result in results) {
          TestUtils.validateAudioData(result, maxAmplitude: 1.5);
        }
      });
      
      test('should maintain consistent latency', () async {
        const chunkSize = 512;
        final testChunk = TestUtils.generateSineWave(
          frequency: 440.0,
          duration: chunkSize / 44100,
          sampleRate: 44100,
        );
        
        final pitchValues = [440.0];
        final latencies = <Duration>[];
        
        // Measure processing time for multiple chunks
        for (int i = 0; i < 10; i++) {
          final stopwatch = Stopwatch()..start();
          
          await engine.processPitchCorrection(testChunk, pitchValues);
          
          stopwatch.stop();
          latencies.add(stopwatch.elapsed);
        }
        
        // Check that latencies are consistent and reasonable
        final averageLatency = latencies
            .map((d) => d.inMicroseconds)
            .reduce((a, b) => a + b) / latencies.length;
        
        expect(averageLatency, lessThan(50000), // Less than 50ms
               reason: 'Processing latency should be reasonable for real-time use');
        
        // Check consistency (standard deviation should be low)
        final variance = latencies
            .map((d) => math.pow(d.inMicroseconds - averageLatency, 2))
            .reduce((a, b) => a + b) / latencies.length;
        final stdDev = math.sqrt(variance);
        
        expect(stdDev, lessThan(averageLatency * 0.5),
               reason: 'Processing latency should be consistent');
      });
    });
    
    group('Error Handling', () {
      setUp(() async {
        await engine.initialize();
      });
      
      test('should handle invalid pitch values gracefully', () async {
        final inputAudio = TestUtils.generateSineWave(
          frequency: 440.0,
          duration: 0.5,
          sampleRate: 44100,
        );
        
        // Test with NaN pitch values
        final invalidPitches = [double.nan, double.infinity, -1.0, 0.0];
        
        final result = await engine.processPitchCorrection(
          inputAudio,
          invalidPitches,
        );
        
        expect(result, isNotNull);
        expect(result.length, equals(inputAudio.length));
        TestUtils.validateAudioData(result);
      });
      
      test('should handle mismatched pitch values length', () async {
        final inputAudio = TestUtils.generateSineWave(
          frequency: 440.0,
          duration: 1.0,
          sampleRate: 44100,
        );
        
        // Too few pitch values
        final fewPitches = [440.0];
        
        final result = await engine.processPitchCorrection(
          inputAudio,
          fewPitches,
        );
        
        expect(result, isNotNull);
        expect(result.length, equals(inputAudio.length));
      });
      
      test('should handle extremly large audio input', () async {
        // Test with very large input (but not too large to cause memory issues in tests)
        final largeAudio = TestUtils.generateSineWave(
          frequency: 440.0,
          duration: 10.0, // 10 seconds
          sampleRate: 44100,
        );
        
        final pitchValues = List.filled(largeAudio.length ~/ 1024, 440.0);
        
        final result = await engine.processPitchCorrection(
          largeAudio,
          pitchValues,
        );
        
        expect(result, isNotNull);
        expect(result.length, equals(largeAudio.length));
      });
    });
    
    group('Performance Tests', () {
      setUp(() async {
        await engine.initialize();
      });
      
      test('should process typical audio chunk efficiently', () async {
        const chunkSize = 2048; // Typical audio buffer size
        final audioChunk = TestUtils.generateSineWave(
          frequency: 440.0,
          duration: chunkSize / 44100,
          sampleRate: 44100,
        );
        
        final pitchValues = [440.0];
        
        final stopwatch = Stopwatch()..start();
        
        await engine.processPitchCorrection(audioChunk, pitchValues);
        
        stopwatch.stop();
        
        // Should process 2048 samples in well under real-time
        // At 44.1kHz, 2048 samples = ~46ms of audio
        expect(stopwatch.elapsedMilliseconds, lessThan(46),
               reason: 'Should process faster than real-time');
      });
      
      test('should handle rapid successive calls', () async {
        const chunkSize = 512;
        final audioChunk = TestUtils.generateSineWave(
          frequency: 440.0,
          duration: chunkSize / 44100,
          sampleRate: 44100,
        );
        
        final pitchValues = [440.0];
        
        // Process multiple chunks rapidly
        for (int i = 0; i < 20; i++) {
          final result = await engine.processPitchCorrection(audioChunk, pitchValues);
          expect(result, isNotNull);
        }
        
        // Should not crash or produce errors
      });
    });
    
    group('Configuration Persistence', () {
      test('should maintain settings after processing', () async {
        await engine.initialize();
        
        engine.setScale(Scale.minor);
        engine.setKey(Key.fSharp);
        engine.setCorrectionStrength(0.6);
        
        final audioChunk = TestUtils.generateSineWave(
          frequency: 440.0,
          duration: 0.1,
          sampleRate: 44100,
        );
        
        await engine.processPitchCorrection(audioChunk, [440.0]);
        
        // Settings should persist after processing
        expect(engine.currentScale, equals(Scale.minor));
        expect(engine.currentKey, equals(Key.fSharp));
        expect(engine.correctionStrength, equals(0.6));
      });
    });
  });
}

import 'dart:math' as math;