/// Test configuration and setup utilities for vocal trainer application
class TestConfig {
  // Test timeouts
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration longTimeout = Duration(minutes: 2);
  static const Duration integrationTimeout = Duration(minutes: 5);
  
  // Audio test parameters
  static const int testSampleRate = 44100;
  static const double testDuration = 1.0;
  static const double testAmplitude = 0.5;
  static const double testFrequency = 440.0;
  
  // Performance test parameters
  static const int performanceIterations = 100;
  static const Duration maxProcessingLatency = Duration(milliseconds: 50);
  static const double maxMemoryUsageMB = 500.0;
  
  // Tolerance values for floating point comparisons
  static const double audioTolerance = 1e-6;
  static const double frequencyTolerance = 0.1;
  static const double scoreTolerance = 0.05;
  static const double timeTolerance = 0.1;
  
  // Mock data parameters
  static const int mockSessionCount = 10;
  static const int mockRecordingCount = 5;
  static const double mockScoreMin = 0.6;
  static const double mockScoreMax = 0.95;
  
  // Error testing parameters
  static const List<double> invalidAudioValues = [
    double.nan,
    double.infinity,
    -double.infinity,
    1e20,
    -1e20,
  ];
  
  // Breathing test parameters
  static const double breathingRateMin = 8.0; // breaths per minute
  static const double breathingRateMax = 25.0;
  static const double breathingRegularityMin = 0.3;
  static const double breathingEfficiencyMin = 0.4;
  
  // Pitch test parameters
  static const double pitchAccuracyMin = 0.5;
  static const double fundamentalFrequencyMin = 80.0; // Hz
  static const double fundamentalFrequencyMax = 1000.0; // Hz
  
  /// Get test environment configuration
  static Map<String, dynamic> getEnvironmentConfig() {
    return {
      'test_mode': true,
      'disable_analytics': true,
      'mock_external_services': true,
      'enable_performance_monitoring': true,
      'log_level': 'debug',
    };
  }
  
  /// Get test database configuration
  static Map<String, dynamic> getDatabaseConfig() {
    return {
      'use_memory_database': true,
      'enable_logging': false,
      'auto_create_tables': true,
    };
  }
  
  /// Get audio processing test configuration
  static Map<String, dynamic> getAudioConfig() {
    return {
      'sample_rate': testSampleRate,
      'buffer_size': 1024,
      'channels': 1,
      'bit_depth': 32,
      'use_mock_input': true,
    };
  }
  
  /// Get performance test configuration
  static Map<String, dynamic> getPerformanceConfig() {
    return {
      'enable_profiling': true,
      'memory_monitoring': true,
      'latency_tracking': true,
      'max_memory_mb': maxMemoryUsageMB,
      'max_latency_ms': maxProcessingLatency.inMilliseconds,
    };
  }
}

/// Test categories for organizing test suites
enum TestCategory {
  unit,
  integration,
  performance,
  ui,
  audio,
  breathing,
  pitch,
  session,
  progress,
  error,
}

/// Test priority levels
enum TestPriority {
  critical,
  high,
  medium,
  low,
}

/// Test annotation for marking test characteristics
class TestInfo {
  final TestCategory category;
  final TestPriority priority;
  final Duration? timeout;
  final List<String> tags;
  final String? description;
  
  const TestInfo({
    required this.category,
    required this.priority,
    this.timeout,
    this.tags = const [],
    this.description,
  });
}

/// Test suite configuration
class TestSuite {
  final String name;
  final TestCategory category;
  final List<String> testFiles;
  final Duration timeout;
  final Map<String, dynamic> config;
  
  const TestSuite({
    required this.name,
    required this.category,
    required this.testFiles,
    required this.timeout,
    required this.config,
  });
  
  static const List<TestSuite> allSuites = [
    TestSuite(
      name: 'Audio Processing Tests',
      category: TestCategory.audio,
      testFiles: [
        'features/audio_analysis/pitch_correction_engine_test.dart',
        'features/audio_analysis/timbre_analyzer_test.dart',
        'features/audio_visualization/spectrogram_visualizer_test.dart',
      ],
      timeout: Duration(minutes: 10),
      config: {
        'audio_enabled': true,
        'performance_monitoring': true,
      },
    ),
    
    TestSuite(
      name: 'Breathing Detection Tests',
      category: TestCategory.breathing,
      testFiles: [
        'features/breathing_detection/advanced_breathing_detector_test.dart',
        'features/breathing_detection/breathing_training_ui_test.dart',
      ],
      timeout: Duration(minutes: 5),
      config: {
        'breathing_analysis': true,
        'real_time_processing': true,
      },
    ),
    
    TestSuite(
      name: 'Session Management Tests',
      category: TestCategory.session,
      testFiles: [
        'features/session_management/recording_session_manager_test.dart',
        'features/progress_tracking/progress_dashboard_test.dart',
      ],
      timeout: Duration(minutes: 3),
      config: {
        'database_enabled': true,
        'cloud_sync_mock': true,
      },
    ),
    
    TestSuite(
      name: 'Integration Tests',
      category: TestCategory.integration,
      testFiles: [
        'integration/vocal_training_integration_test.dart',
        'integration/performance_integration_test.dart',
      ],
      timeout: Duration(minutes: 15),
      config: {
        'full_system': true,
        'performance_monitoring': true,
        'error_simulation': true,
      },
    ),
    
    TestSuite(
      name: 'Performance Tests',
      category: TestCategory.performance,
      testFiles: [
        'performance/audio_processing_performance_test.dart',
        'performance/memory_usage_test.dart',
        'performance/real_time_processing_test.dart',
      ],
      timeout: Duration(minutes: 20),
      config: {
        'performance_profiling': true,
        'memory_monitoring': true,
        'stress_testing': true,
      },
    ),
    
    TestSuite(
      name: 'Error Handling Tests',
      category: TestCategory.error,
      testFiles: [
        'core/error_handling/error_handler_test.dart',
        'core/error_handling/error_recovery_test.dart',
        'core/validation/validation_utils_test.dart',
      ],
      timeout: Duration(minutes: 5),
      config: {
        'error_simulation': true,
        'recovery_testing': true,
      },
    ),
  ];
}

/// Test data generators
class TestDataGenerator {
  static Map<String, dynamic> generateSessionData({
    String? id,
    String? name,
    String? userId,
    int recordingCount = 3,
  }) {
    return {
      'id': id ?? 'test_session_${DateTime.now().millisecondsSinceEpoch}',
      'name': name ?? 'Test Session',
      'userId': userId ?? 'test_user',
      'type': 'practice',
      'createdAt': DateTime.now().toIso8601String(),
      'recordings': List.generate(recordingCount, (i) => {
        'id': 'recording_$i',
        'duration': 30 + (i * 10),
        'analysis': {
          'overallScore': 0.7 + (i * 0.05),
          'pitchAccuracy': 0.8,
          'rhythmAccuracy': 0.75,
          'toneQuality': 0.7,
        },
      }),
    };
  }
  
  static Map<String, dynamic> generateProgressData({
    double overallScore = 0.75,
    double improvement = 0.1,
    int practiceStreak = 7,
  }) {
    return {
      'overallMetrics': {
        'totalScore': overallScore,
        'improvement': improvement,
        'consistency': 0.8,
        'practiceStreak': practiceStreak,
        'totalPracticeTime': Duration(hours: 25).inMilliseconds,
      },
      'skillMetrics': {
        'pitch_accuracy': {
          'current': 0.8,
          'trend': 0.05,
          'level': 'intermediate',
        },
        'breathing': {
          'current': 0.75,
          'trend': 0.1,
          'level': 'intermediate',
        },
      },
    };
  }
  
  static List<double> generateBreathingPattern({
    double rate = 15.0,
    double duration = 60.0,
    double regularity = 0.9,
  }) {
    final samples = <double>[];
    final sampleRate = 10; // 10 Hz
    final sampleCount = (duration * sampleRate).round();
    final breathPeriod = 60.0 / rate;
    
    for (int i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final cyclePos = (t % breathPeriod) / breathPeriod;
      
      // Add regularity variation
      final variation = (1.0 - regularity) * (0.5 - (i % 10) / 20.0);
      final adjustedPos = (cyclePos + variation).clamp(0.0, 1.0);
      
      double value;
      if (adjustedPos < 0.4) {
        // Inhale
        value = adjustedPos / 0.4;
      } else if (adjustedPos < 0.6) {
        // Hold
        value = 1.0;
      } else {
        // Exhale
        value = 1.0 - ((adjustedPos - 0.6) / 0.4);
      }
      
      samples.add(value);
    }
    
    return samples;
  }
}

/// Test validation utilities
class TestValidator {
  static void validateAudioMetrics(Map<String, dynamic> metrics) {
    assert(metrics.containsKey('pitchAccuracy'), 'Missing pitch accuracy');
    assert(metrics.containsKey('rhythmAccuracy'), 'Missing rhythm accuracy');
    assert(metrics.containsKey('toneQuality'), 'Missing tone quality');
    
    final pitchAccuracy = metrics['pitchAccuracy'] as double;
    assert(pitchAccuracy >= 0.0 && pitchAccuracy <= 1.0, 'Invalid pitch accuracy range');
    
    final rhythmAccuracy = metrics['rhythmAccuracy'] as double;
    assert(rhythmAccuracy >= 0.0 && rhythmAccuracy <= 1.0, 'Invalid rhythm accuracy range');
    
    final toneQuality = metrics['toneQuality'] as double;
    assert(toneQuality >= 0.0 && toneQuality <= 1.0, 'Invalid tone quality range');
  }
  
  static void validateBreathingMetrics(Map<String, dynamic> metrics) {
    assert(metrics.containsKey('rate'), 'Missing breathing rate');
    assert(metrics.containsKey('regularity'), 'Missing breathing regularity');
    assert(metrics.containsKey('efficiency'), 'Missing breathing efficiency');
    
    final rate = metrics['rate'] as double;
    assert(rate >= TestConfig.breathingRateMin && rate <= TestConfig.breathingRateMax, 
           'Breathing rate out of valid range');
    
    final regularity = metrics['regularity'] as double;
    assert(regularity >= 0.0 && regularity <= 1.0, 'Invalid regularity range');
    
    final efficiency = metrics['efficiency'] as double;
    assert(efficiency >= 0.0 && efficiency <= 1.0, 'Invalid efficiency range');
  }
  
  static void validateSessionData(Map<String, dynamic> sessionData) {
    assert(sessionData.containsKey('id'), 'Missing session ID');
    assert(sessionData.containsKey('name'), 'Missing session name');
    assert(sessionData.containsKey('createdAt'), 'Missing creation timestamp');
    assert(sessionData.containsKey('recordings'), 'Missing recordings');
    
    final recordings = sessionData['recordings'] as List;
    for (final recording in recordings) {
      final recordingMap = recording as Map<String, dynamic>;
      assert(recordingMap.containsKey('id'), 'Missing recording ID');
      assert(recordingMap.containsKey('duration'), 'Missing recording duration');
    }
  }
  
  static void validatePerformanceMetrics(Map<String, dynamic> metrics) {
    assert(metrics.containsKey('processingTime'), 'Missing processing time');
    assert(metrics.containsKey('memoryUsage'), 'Missing memory usage');
    
    final processingTime = metrics['processingTime'] as int; // milliseconds
    assert(processingTime >= 0, 'Invalid processing time');
    
    final memoryUsage = metrics['memoryUsage'] as double; // MB
    assert(memoryUsage >= 0, 'Invalid memory usage');
    assert(memoryUsage < TestConfig.maxMemoryUsageMB, 'Memory usage too high');
  }
}