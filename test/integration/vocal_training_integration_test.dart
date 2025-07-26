import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/audio_analysis/pitch_correction_engine.dart';
import '../../lib/features/audio_analysis/timbre_analyzer.dart';
import '../../lib/features/breathing_detection/advanced_breathing_detector.dart';
import '../../lib/features/session_management/recording_session_manager.dart';
import '../../lib/features/progress_tracking/progress_dashboard.dart';
import '../../lib/features/exercise_generation/ai_exercise_generator.dart';
import '../../lib/core/error_handling/error_handler.dart';
import '../../lib/core/performance/performance_manager.dart';
import '../utils/test_utils.dart';

void main() {
  group('Vocal Training System Integration Tests', () {
    late RecordingSessionManager sessionManager;
    late ProgressDashboard progressDashboard;
    late AIExerciseGenerator exerciseGenerator;
    late PitchCorrectionEngine pitchEngine;
    late TimbreAnalyzer timbreAnalyzer;
    late AdvancedBreathingDetector breathingDetector;
    late PerformanceManager performanceManager;
    
    setUpAll(() async {
      // Initialize error handling
      ErrorHandler();
      
      // Initialize performance monitoring
      performanceManager = PerformanceManager();
      await performanceManager.initialize();
    });
    
    setUp(() async {
      // Initialize core components
      sessionManager = RecordingSessionManager();
      await sessionManager.initialize();
      
      progressDashboard = ProgressDashboard(sessionManager);
      exerciseGenerator = AIExerciseGenerator(progressDashboard);
      
      // Initialize audio analysis components
      pitchEngine = PitchCorrectionEngine();
      await pitchEngine.initialize();
      
      timbreAnalyzer = TimbreAnalyzer();
      await timbreAnalyzer.initialize();
      
      breathingDetector = AdvancedBreathingDetector();
      await breathingDetector.initialize();
    });
    
    tearDown(() {
      sessionManager.dispose();
      pitchEngine.dispose();
      timbreAnalyzer.dispose();
      breathingDetector.dispose();
    });
    
    tearDownAll(() {
      performanceManager.dispose();
    });
    
    group('Complete Vocal Training Workflow', () {
      test('should complete full training session workflow', () async {
        // 1. Create a new training session
        final session = await sessionManager.createSession(
          name: 'Integration Test Session',
          type: SessionType.practice,
          metadata: {'test': true},
        );
        
        expect(session, isNotNull);
        expect(session.name, equals('Integration Test Session'));
        expect(session.type, equals(SessionType.practice));
        
        // 2. Generate exercises for the session
        final exercises = await exerciseGenerator.generatePersonalizedExercises(
          count: 3,
        );
        
        expect(exercises, isNotEmpty);
        expect(exercises.length, equals(3));
        
        // 3. Simulate recording and analysis for each exercise
        for (int i = 0; i < exercises.length; i++) {
          final exercise = exercises[i];
          exercise.start();
          
          // Start recording
          await sessionManager.startRecording(session.id);
          
          // Generate test audio based on exercise type
          final audioData = _generateExerciseAudio(exercise);
          
          // Analyze the audio
          final pitchValues = await pitchEngine.detectPitchValues(audioData);
          final correctedAudio = await pitchEngine.processPitchCorrection(
            audioData, 
            pitchValues,
          );
          
          final timbreAnalysis = await timbreAnalyzer.analyzeTimbre(
            correctedAudio.toList(),
          );
          
          // Create analysis result
          final analysisResult = VocalAnalysisResult(
            overallScore: 0.7 + (i * 0.1), // Improving scores
            pitchAccuracy: timbreAnalysis.pitchStability,
            rhythmAccuracy: 0.8,
            toneQuality: timbreAnalysis.brightness * 0.5 + timbreAnalysis.warmth * 0.5,
            detailedMetrics: {
              'breathing': 0.75,
              'resonance': timbreAnalysis.resonance,
              'articulation': 0.8,
              'vibrato': timbreAnalysis.vibrato,
            },
            suggestions: timbreAnalysis.recommendations,
          );
          
          // Stop recording with analysis
          await sessionManager.stopRecording(
            session.id,
            correctedAudio,
            analysis: analysisResult,
          );
          
          exercise.complete(
            score: analysisResult.overallScore,
            feedbackItems: analysisResult.suggestions,
          );
          
          // Verify exercise completion
          expect(exercise.isCompleted, isTrue);
          expect(exercise.performanceScore, equals(analysisResult.overallScore));
        }
        
        // 4. Verify session data
        final updatedSession = sessionManager.getSession(session.id);
        expect(updatedSession, isNotNull);
        expect(updatedSession!.recordings.length, equals(3));
        expect(updatedSession.averageScore, greaterThan(0.0));
        
        // 5. Check progress tracking
        await Future.delayed(const Duration(milliseconds: 500)); // Allow progress update
        
        final stats = sessionManager.getSessionStatistics();
        expect(stats.totalSessions, greaterThanOrEqualTo(1));
        expect(stats.totalRecordings, greaterThanOrEqualTo(3));
        expect(stats.averageAccuracy, greaterThan(0.0));
      });
      
      test('should handle breathing analysis integration', () async {
        final session = await sessionManager.createSession(
          name: 'Breathing Test Session',
          type: SessionType.practice,
        );
        
        // Generate breathing exercise
        final breathingExercises = await exerciseGenerator.generatePersonalizedExercises(
          count: 1,
          focusCategory: ExerciseCategory.breathing,
        );
        
        expect(breathingExercises, isNotEmpty);
        
        final exercise = breathingExercises.first;
        exercise.start();
        
        await sessionManager.startRecording(session.id);
        
        // Generate breathing audio pattern
        final breathingAudio = TestUtils.generateBreathingPattern(
          rate: 15.0,
          duration: 30.0,
        );
        
        // Convert to audio format and process
        final audioData = Float32List(breathingAudio.length * 100); // Upsample
        for (int i = 0; i < audioData.length; i++) {
          final breathingIndex = (i / 100).floor().clamp(0, breathingAudio.length - 1);
          audioData[i] = breathingAudio[breathingIndex] * 0.1; // Scale amplitude
        }
        
        // Process with breathing detector
        breathingDetector.processAudioData(audioData.toList());
        
        // Wait for analysis
        await Future.delayed(const Duration(seconds: 1));
        
        final breathingStats = breathingDetector.getCurrentStatistics();
        expect(breathingStats.averageRate, greaterThan(0));
        
        // Create comprehensive analysis
        final analysisResult = VocalAnalysisResult(
          overallScore: 0.8,
          pitchAccuracy: 0.7,
          rhythmAccuracy: 0.9,
          toneQuality: 0.75,
          detailedMetrics: {
            'breathing': breathingStats.efficiency,
            'breathing_rate': breathingStats.averageRate,
            'breathing_regularity': breathingStats.rhythmRegularity,
          },
          suggestions: ['호흡이 안정적입니다', '조금 더 깊게 숨쉬어보세요'],
        );
        
        await sessionManager.stopRecording(
          session.id,
          audioData,
          analysis: analysisResult,
        );
        
        exercise.complete(score: analysisResult.overallScore);
        
        // Verify breathing metrics are included
        final updatedSession = sessionManager.getSession(session.id);
        final recording = updatedSession!.recordings.first;
        
        expect(recording.analysis!.detailedMetrics.containsKey('breathing'), isTrue);
        expect(recording.analysis!.detailedMetrics['breathing_rate'], greaterThan(0));
      });
    });
    
    group('Error Handling Integration', () {
      test('should handle audio processing errors gracefully', () async {
        final session = await sessionManager.createSession(
          name: 'Error Test Session',
          type: SessionType.practice,
        );
        
        await sessionManager.startRecording(session.id);
        
        // Generate problematic audio (all zeros - silence)
        final silentAudio = Float32List(44100); // 1 second of silence
        
        // This should not crash the system
        final pitchValues = await pitchEngine.detectPitchValues(silentAudio);
        expect(pitchValues, isNotNull);
        
        final correctedAudio = await pitchEngine.processPitchCorrection(
          silentAudio,
          pitchValues,
        );
        expect(correctedAudio, isNotNull);
        
        // Should complete recording even with problematic audio
        await sessionManager.stopRecording(session.id, correctedAudio);
        
        final updatedSession = sessionManager.getSession(session.id);
        expect(updatedSession!.recordings.length, equals(1));
      });
      
      test('should recover from component failures', () async {
        final session = await sessionManager.createSession(
          name: 'Recovery Test Session',
          type: SessionType.practice,
        );
        
        // Test with invalid audio data
        final invalidAudio = Float32List.fromList([
          double.nan,
          double.infinity,
          -double.infinity,
          1e20,
          -1e20,
        ]);
        
        await sessionManager.startRecording(session.id);
        
        // Components should handle invalid data gracefully
        try {
          final pitchValues = await pitchEngine.detectPitchValues(invalidAudio);
          final correctedAudio = await pitchEngine.processPitchCorrection(
            invalidAudio,
            pitchValues,
          );
          
          await sessionManager.stopRecording(session.id, correctedAudio);
        } catch (e) {
          // Even if individual components fail, session should still exist
        }
        
        final updatedSession = sessionManager.getSession(session.id);
        expect(updatedSession, isNotNull);
      });
    });
    
    group('Performance Integration', () {
      test('should maintain performance under load', () async {
        const numSessions = 10;
        const recordingsPerSession = 5;
        
        final stopwatch = Stopwatch()..start();
        
        for (int s = 0; s < numSessions; s++) {
          final session = await sessionManager.createSession(
            name: 'Performance Test Session $s',
            type: SessionType.practice,
          );
          
          for (int r = 0; r < recordingsPerSession; r++) {
            await sessionManager.startRecording(session.id);
            
            // Generate realistic audio data
            final audioData = TestUtils.generateComplexAudio(
              frequencies: [220.0, 440.0, 880.0],
              amplitudes: [0.3, 0.5, 0.2],
              duration: 2.0,
              sampleRate: 44100,
              noiseLevel: 0.05,
            );
            
            // Process through pipeline
            final pitchValues = await pitchEngine.detectPitchValues(audioData);
            final correctedAudio = await pitchEngine.processPitchCorrection(
              audioData,
              pitchValues,
            );
            
            final timbreAnalysis = await timbreAnalyzer.analyzeTimbre(
              correctedAudio.toList(),
            );
            
            final analysisResult = VocalAnalysisResult(
              overallScore: 0.7,
              pitchAccuracy: timbreAnalysis.pitchStability,
              rhythmAccuracy: 0.8,
              toneQuality: timbreAnalysis.brightness * 0.5 + timbreAnalysis.warmth * 0.5,
              detailedMetrics: {
                'brightness': timbreAnalysis.brightness,
                'warmth': timbreAnalysis.warmth,
                'roughness': timbreAnalysis.roughness,
              },
              suggestions: timbreAnalysis.recommendations,
            );
            
            await sessionManager.stopRecording(
              session.id,
              correctedAudio,
              analysis: analysisResult,
            );
          }
        }
        
        stopwatch.stop();
        
        // Should complete all sessions in reasonable time
        expect(stopwatch.elapsedSeconds, lessThan(60),
               reason: 'Should process all sessions within 60 seconds');
        
        // Verify all sessions were created
        final allSessions = sessionManager.getAllSessions();
        expect(allSessions.length, greaterThanOrEqualTo(numSessions));
        
        // Check performance statistics
        final performanceStats = performanceManager.getPerformanceStatistics();
        expect(performanceStats.totalOperations, greaterThan(0));
        
        // Memory usage should be reasonable
        expect(performanceStats.currentMemoryUsage, lessThan(500), // Less than 500MB
               reason: 'Memory usage should be reasonable');
      });
      
      test('should handle real-time processing simulation', () async {
        final session = await sessionManager.createSession(
          name: 'Real-time Test Session',
          type: SessionType.practice,
        );
        
        await sessionManager.startRecording(session.id);
        
        const chunkSize = 1024;
        const numChunks = 100;
        const targetLatency = Duration(milliseconds: 50);
        
        final processedChunks = <Float32List>[];
        final latencies = <Duration>[];
        
        for (int i = 0; i < numChunks; i++) {
          final stopwatch = Stopwatch()..start();
          
          // Generate audio chunk
          final audioChunk = TestUtils.generateSineWave(
            frequency: 440.0 + (i * 2), // Slight frequency variation
            duration: chunkSize / 44100,
            sampleRate: 44100,
          );
          
          // Process chunk through pipeline
          final pitchValues = await pitchEngine.detectPitchValues(audioChunk);
          final correctedChunk = await pitchEngine.processPitchCorrection(
            audioChunk,
            pitchValues,
          );
          
          processedChunks.add(correctedChunk);
          
          stopwatch.stop();
          latencies.add(stopwatch.elapsed);
          
          // Should process faster than target latency
          expect(stopwatch.elapsed, lessThan(targetLatency),
                 reason: 'Chunk $i should process within target latency');
        }
        
        // Combine all chunks
        final totalSamples = processedChunks.fold<int>(
          0, (sum, chunk) => sum + chunk.length);
        final combinedAudio = Float32List(totalSamples);
        
        int offset = 0;
        for (final chunk in processedChunks) {
          combinedAudio.setRange(offset, offset + chunk.length, chunk);
          offset += chunk.length;
        }
        
        await sessionManager.stopRecording(session.id, combinedAudio);
        
        // Verify processing consistency
        final averageLatency = latencies
            .map((d) => d.inMicroseconds)
            .reduce((a, b) => a + b) / latencies.length;
        
        expect(averageLatency, lessThan(targetLatency.inMicroseconds),
               reason: 'Average processing latency should be acceptable');
        
        final updatedSession = sessionManager.getSession(session.id);
        expect(updatedSession!.recordings.length, equals(1));
      });
    });
    
    group('Data Persistence Integration', () {
      test('should persist and restore session data', () async {
        // Create session with analysis data
        final originalSession = await sessionManager.createSession(
          name: 'Persistence Test Session',
          type: SessionType.lesson,
          metadata: {'instructor': 'Test Teacher', 'level': 'intermediate'},
        );
        
        await sessionManager.startRecording(originalSession.id);
        
        final audioData = TestUtils.generateSineWave(
          frequency: 440.0,
          duration: 1.0,
          sampleRate: 44100,
        );
        
        final analysisResult = VocalAnalysisResult(
          overallScore: 0.85,
          pitchAccuracy: 0.9,
          rhythmAccuracy: 0.8,
          toneQuality: 0.85,
          detailedMetrics: {
            'breathing': 0.75,
            'resonance': 0.8,
            'articulation': 0.9,
          },
          suggestions: ['Great pitch control!', 'Work on breath support'],
        );
        
        await sessionManager.stopRecording(
          originalSession.id,
          audioData,
          analysis: analysisResult,
        );
        
        // Export session data
        final exportedData = await sessionManager.exportSessionData(originalSession.id);
        
        expect(exportedData, isNotNull);
        expect(exportedData['session'], isNotNull);
        expect(exportedData['recordings'], isNotNull);
        
        // Verify exported data contains analysis
        final recordings = exportedData['recordings'] as List;
        expect(recordings, isNotEmpty);
        
        final firstRecording = recordings.first as Map<String, dynamic>;
        expect(firstRecording['analysis'], isNotNull);
        
        final analysis = firstRecording['analysis'] as Map<String, dynamic>;
        expect(analysis['overallScore'], equals(0.85));
        expect(analysis['suggestions'], contains('Great pitch control!'));
        
        // Create new session manager and import data
        final newSessionManager = RecordingSessionManager();
        await newSessionManager.initialize();
        
        await newSessionManager.importSessionData(exportedData);
        
        // Verify imported session
        final importedSessions = newSessionManager.getAllSessions();
        expect(importedSessions, isNotEmpty);
        
        final importedSession = importedSessions
            .firstWhere((s) => s.id == originalSession.id);
        
        expect(importedSession.name, equals('Persistence Test Session'));
        expect(importedSession.type, equals(SessionType.lesson));
        expect(importedSession.metadata['instructor'], equals('Test Teacher'));
        expect(importedSession.recordings.length, equals(1));
        
        final importedRecording = importedSession.recordings.first;
        expect(importedRecording.analysis, isNotNull);
        expect(importedRecording.analysis!.overallScore, equals(0.85));
        
        newSessionManager.dispose();
      });
    });
  });
}

// Helper function to generate appropriate audio for different exercise types
Float32List _generateExerciseAudio(VocalExercise exercise) {
  switch (exercise.category) {
    case ExerciseCategory.breathing:
      // Generate breathing-like low frequency audio
      return TestUtils.generateSineWave(
        frequency: 100.0,
        amplitude: 0.3,
        duration: 5.0,
        sampleRate: 44100,
      );
      
    case ExerciseCategory.pitch:
      // Generate scale-like audio
      return TestUtils.generateComplexAudio(
        frequencies: [261.63, 293.66, 329.63, 349.23, 392.00], // C major scale
        amplitudes: [0.2, 0.2, 0.2, 0.2, 0.2],
        duration: 8.0,
        sampleRate: 44100,
      );
      
    case ExerciseCategory.warmup:
      // Generate lip trill-like audio
      return TestUtils.generateSineWave(
        frequency: 200.0,
        amplitude: 0.4,
        duration: 3.0,
        sampleRate: 44100,
      );
      
    case ExerciseCategory.articulation:
      // Generate speech-like audio with multiple frequencies
      return TestUtils.generateComplexAudio(
        frequencies: [200.0, 400.0, 800.0, 1600.0],
        amplitudes: [0.4, 0.3, 0.2, 0.1],
        duration: 6.0,
        sampleRate: 44100,
        noiseLevel: 0.1,
      );
      
    default:
      // Default to simple sine wave
      return TestUtils.generateSineWave(
        frequency: 440.0,
        amplitude: 0.5,
        duration: 4.0,
        sampleRate: 44100,
      );
  }
}