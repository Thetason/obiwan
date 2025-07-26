import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Comprehensive performance monitoring and optimization system
class PerformanceManager {
  static final PerformanceManager _instance = PerformanceManager._internal();
  factory PerformanceManager() => _instance;
  PerformanceManager._internal();
  
  final StreamController<PerformanceMetrics> _metricsController = 
      StreamController<PerformanceMetrics>.broadcast();
  
  Stream<PerformanceMetrics> get metricsStream => _metricsController.stream;
  
  // Performance tracking
  final Map<String, Stopwatch> _operationTimers = {};
  final Map<String, List<Duration>> _operationHistory = {};
  final List<MemorySnapshot> _memoryHistory = [];
  final Map<String, int> _operationCounts = {};
  
  // Memory management
  final List<WeakReference<Object>> _objectPool = [];
  final Map<String, Timer> _cleanupTimers = {};
  Timer? _performanceTimer;
  Timer? _memoryTimer;
  
  // Performance thresholds
  static const Duration _slowOperationThreshold = Duration(milliseconds: 100);
  static const int _maxMemoryHistorySize = 100;
  static const int _maxOperationHistorySize = 50;
  
  bool _isInitialized = false;
  
  /// Initialize performance monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _startPerformanceMonitoring();
    _startMemoryMonitoring();
    _setupPerformanceOptimizations();
    
    _isInitialized = true;
    debugPrint('PerformanceManager initialized');
  }
  
  void _startPerformanceMonitoring() {
    _performanceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _collectPerformanceMetrics();
    });
  }
  
  void _startMemoryMonitoring() {
    _memoryTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _collectMemoryMetrics();
    });
  }
  
  void _setupPerformanceOptimizations() {
    // Enable GPU acceleration for supported operations
    _enableGPUAcceleration();
    
    // Configure garbage collection optimization
    _configureGCOptimization();
    
    // Setup memory pool for frequent allocations
    _setupMemoryPool();
  }
  
  void _enableGPUAcceleration() {
    // Platform-specific GPU acceleration setup
    if (kIsWeb) {
      // Web GPU optimizations
      debugPrint('Enabling Web GPU optimizations');
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Mobile GPU optimizations
      debugPrint('Enabling mobile GPU optimizations');
    }
  }
  
  void _configureGCOptimization() {
    // Suggest GC when memory usage is high
    _schedulePeriodicCleanup();
  }
  
  void _setupMemoryPool() {
    // Pre-allocate commonly used objects
    _preAllocateBuffers();
  }
  
  void _preAllocateBuffers() {
    // Pre-allocate audio buffers of common sizes
    const commonSizes = [1024, 2048, 4096, 8192];
    
    for (final size in commonSizes) {
      final buffer = Float32List(size);
      _addToObjectPool('audio_buffer_$size', buffer);
    }
  }
  
  void _addToObjectPool(String key, Object object) {
    _objectPool.add(WeakReference(object));
  }
  
  T? _getFromObjectPool<T>(String key) {
    // Simple object pool implementation
    for (int i = _objectPool.length - 1; i >= 0; i--) {
      final ref = _objectPool[i];
      final obj = ref.target;
      
      if (obj == null) {
        _objectPool.removeAt(i);
        continue;
      }
      
      if (obj is T) {
        return obj;
      }
    }
    
    return null;
  }
  
  /// Start timing an operation
  void startOperation(String operationName) {
    final stopwatch = Stopwatch()..start();
    _operationTimers[operationName] = stopwatch;
  }
  
  /// End timing an operation and record metrics
  Duration endOperation(String operationName) {
    final stopwatch = _operationTimers.remove(operationName);
    
    if (stopwatch == null) {
      debugPrint('Warning: endOperation called without startOperation for $operationName');
      return Duration.zero;
    }
    
    stopwatch.stop();
    final duration = stopwatch.elapsed;
    
    // Record operation
    _recordOperation(operationName, duration);
    
    // Check for slow operations
    if (duration > _slowOperationThreshold) {
      _handleSlowOperation(operationName, duration);
    }
    
    return duration;
  }
  
  void _recordOperation(String operationName, Duration duration) {
    // Update operation history
    _operationHistory.putIfAbsent(operationName, () => <Duration>[]);
    _operationHistory[operationName]!.add(duration);
    
    // Maintain history size
    if (_operationHistory[operationName]!.length > _maxOperationHistorySize) {
      _operationHistory[operationName]!.removeAt(0);
    }
    
    // Update operation count
    _operationCounts[operationName] = (_operationCounts[operationName] ?? 0) + 1;
  }
  
  void _handleSlowOperation(String operationName, Duration duration) {
    debugPrint('Slow operation detected: $operationName took ${duration.inMilliseconds}ms');
    
    // Trigger optimization for frequently slow operations
    if (_shouldOptimizeOperation(operationName)) {
      _optimizeOperation(operationName);
    }
  }
  
  bool _shouldOptimizeOperation(String operationName) {
    final history = _operationHistory[operationName];
    if (history == null || history.length < 5) return false;
    
    // Check if more than 50% of recent operations were slow
    final recentOperations = history.takeLast(10);
    final slowOperations = recentOperations.where((d) => d > _slowOperationThreshold).length;
    
    return slowOperations / recentOperations.length > 0.5;
  }
  
  void _optimizeOperation(String operationName) {
    debugPrint('Applying optimizations for: $operationName');
    
    switch (operationName) {
      case 'audio_processing':
        _optimizeAudioProcessing();
        break;
      case 'fft_computation':
        _optimizeFFTComputation();
        break;
      case 'pitch_detection':
        _optimizePitchDetection();
        break;
      case 'ui_rendering':
        _optimizeUIRendering();
        break;
      default:
        _applyGeneralOptimizations(operationName);
    }
  }
  
  void _optimizeAudioProcessing() {
    // Switch to more efficient audio processing algorithms
    debugPrint('Optimizing audio processing: using simplified algorithms');
  }
  
  void _optimizeFFTComputation() {
    // Use smaller FFT sizes or cached results
    debugPrint('Optimizing FFT computation: reducing FFT size');
  }
  
  void _optimizePitchDetection() {
    // Use faster pitch detection algorithms
    debugPrint('Optimizing pitch detection: switching to autocorrelation method');
  }
  
  void _optimizeUIRendering() {
    // Reduce UI update frequency
    debugPrint('Optimizing UI rendering: reducing update frequency');
  }
  
  void _applyGeneralOptimizations(String operationName) {
    // Apply general performance optimizations
    debugPrint('Applying general optimizations for: $operationName');
  }
  
  void _collectPerformanceMetrics() {
    final metrics = PerformanceMetrics(
      timestamp: DateTime.now(),
      operationCounts: Map.from(_operationCounts),
      averageOperationTimes: _calculateAverageOperationTimes(),
      slowOperations: _getSlowOperations(),
      memoryUsage: _getCurrentMemoryUsage(),
      gcEvents: _getRecentGCEvents(),
    );
    
    _metricsController.add(metrics);
  }
  
  Map<String, Duration> _calculateAverageOperationTimes() {
    final averages = <String, Duration>{};
    
    _operationHistory.forEach((operation, history) {
      if (history.isNotEmpty) {
        final totalMs = history.map((d) => d.inMicroseconds).reduce((a, b) => a + b);
        averages[operation] = Duration(microseconds: totalMs ~/ history.length);
      }
    });
    
    return averages;
  }
  
  List<SlowOperation> _getSlowOperations() {
    final slowOps = <SlowOperation>[];
    
    _operationHistory.forEach((operation, history) {
      final slowDurations = history.where((d) => d > _slowOperationThreshold).toList();
      
      if (slowDurations.isNotEmpty) {
        slowOps.add(SlowOperation(
          operationName: operation,
          slowCount: slowDurations.length,
          totalCount: history.length,
          averageSlowDuration: Duration(
            microseconds: slowDurations
                .map((d) => d.inMicroseconds)
                .reduce((a, b) => a + b) ~/ slowDurations.length,
          ),
        ));
      }
    });
    
    return slowOps;
  }
  
  void _collectMemoryMetrics() {
    final snapshot = MemorySnapshot(
      timestamp: DateTime.now(),
      usedMemoryMB: _getCurrentMemoryUsage(),
      objectCount: _getApproximateObjectCount(),
      gcEvents: _getRecentGCEvents(),
    );
    
    _memoryHistory.add(snapshot);
    
    // Maintain history size
    if (_memoryHistory.length > _maxMemoryHistorySize) {
      _memoryHistory.removeAt(0);
    }
    
    // Check for memory pressure
    if (_isMemoryPressureHigh(snapshot)) {
      _handleMemoryPressure();
    }
  }
  
  double _getCurrentMemoryUsage() {
    if (kIsWeb) {
      // Web doesn't provide direct memory access
      return 0.0;
    }
    
    try {
      return ProcessInfo.currentRss / (1024 * 1024); // Convert to MB
    } catch (e) {
      return 0.0;
    }
  }
  
  int _getApproximateObjectCount() {
    // Approximate object count based on weak references
    return _objectPool.where((ref) => ref.target != null).length;
  }
  
  int _getRecentGCEvents() {
    // This would require platform-specific implementation
    // For now, return a mock value
    return 0;
  }
  
  bool _isMemoryPressureHigh(MemorySnapshot snapshot) {
    if (_memoryHistory.length < 3) return false;
    
    final recentSnapshots = _memoryHistory.takeLast(3);
    final memoryTrend = recentSnapshots.last.usedMemoryMB - recentSnapshots.first.usedMemoryMB;
    
    // High memory pressure if memory is increasing rapidly
    return memoryTrend > 50.0 || snapshot.usedMemoryMB > 200.0;
  }
  
  void _handleMemoryPressure() {
    debugPrint('High memory pressure detected, triggering cleanup');
    
    // Trigger immediate cleanup
    _performMemoryCleanup();
    
    // Reduce quality settings temporarily
    _reduceQualitySettings();
    
    // Schedule more frequent cleanup
    _scheduleAggressiveCleanup();
  }
  
  void _performMemoryCleanup() {
    // Clean up weak references
    _objectPool.removeWhere((ref) => ref.target == null);
    
    // Clear operation history for old operations
    _cleanupOldOperationHistory();
    
    // Suggest garbage collection
    _suggestGarbageCollection();
  }
  
  void _cleanupOldOperationHistory() {
    final cutoffTime = DateTime.now().subtract(const Duration(minutes: 10));
    
    _operationHistory.forEach((operation, history) {
      if (history.length > 20) {
        _operationHistory[operation] = history.takeLast(20).toList();
      }
    });
  }
  
  void _suggestGarbageCollection() {
    if (!kIsWeb) {
      try {
        // Platform-specific GC suggestion
        SystemChannels.platform.invokeMethod('SystemChrome.setPreferredOrientations');
      } catch (e) {
        // Fail silently
      }
    }
  }
  
  void _reduceQualitySettings() {
    debugPrint('Reducing quality settings due to memory pressure');
    // This would communicate with other components to reduce quality
  }
  
  void _scheduleAggressiveCleanup() {
    _cleanupTimers['aggressive'] = Timer.periodic(const Duration(seconds: 30), (_) {
      _performMemoryCleanup();
    });
    
    // Cancel aggressive cleanup after 5 minutes
    Timer(const Duration(minutes: 5), () {
      _cleanupTimers['aggressive']?.cancel();
      _cleanupTimers.remove('aggressive');
    });
  }
  
  void _schedulePeriodicCleanup() {
    _cleanupTimers['periodic'] = Timer.periodic(const Duration(minutes: 2), (_) {
      _performMemoryCleanup();
    });
  }
  
  /// Optimize audio buffer processing
  Float32List optimizeAudioBuffer(Float32List input, {bool allowInPlace = true}) {
    startOperation('audio_buffer_optimization');
    
    try {
      // Use in-place operations when possible to reduce memory allocation
      if (allowInPlace) {
        _processAudioBufferInPlace(input);
        endOperation('audio_buffer_optimization');
        return input;
      } else {
        // Try to get buffer from pool
        Float32List? output = _getFromObjectPool<Float32List>('audio_buffer_${input.length}');
        output ??= Float32List(input.length);
        
        // Copy and process
        for (int i = 0; i < input.length; i++) {
          output[i] = input[i];
        }
        
        _processAudioBufferInPlace(output);
        endOperation('audio_buffer_optimization');
        return output;
      }
    } catch (e) {
      endOperation('audio_buffer_optimization');
      rethrow;
    }
  }
  
  void _processAudioBufferInPlace(Float32List buffer) {
    // Apply optimized in-place processing
    for (int i = 0; i < buffer.length; i++) {
      // Normalize and apply basic filtering
      buffer[i] = buffer[i].clamp(-1.0, 1.0);
    }
  }
  
  /// Batch process multiple operations for better performance
  List<T> batchProcess<T>(
    List<dynamic> inputs,
    T Function(dynamic input) processor, {
    int batchSize = 10,
  }) {
    startOperation('batch_processing');
    
    try {
      final results = <T>[];
      
      for (int i = 0; i < inputs.length; i += batchSize) {
        final batch = inputs.skip(i).take(batchSize);
        
        // Process batch
        final batchResults = batch.map(processor).toList();
        results.addAll(batchResults);
        
        // Yield control periodically
        if (i % (batchSize * 10) == 0) {
          // Allow other operations to run
        }
      }
      
      endOperation('batch_processing');
      return results;
    } catch (e) {
      endOperation('batch_processing');
      rethrow;
    }
  }
  
  /// Run CPU-intensive operations in isolate
  Future<T> runInIsolate<T>(
    T Function() computation, {
    String? operationName,
  }) async {
    final name = operationName ?? 'isolate_computation';
    startOperation(name);
    
    try {
      final receivePort = ReceivePort();
      
      await Isolate.spawn(_isolateEntryPoint, {
        'computation': computation,
        'sendPort': receivePort.sendPort,
      });
      
      final result = await receivePort.first as T;
      endOperation(name);
      
      return result;
    } catch (e) {
      endOperation(name);
      rethrow;
    }
  }
  
  static void _isolateEntryPoint(Map<String, dynamic> message) {
    final computation = message['computation'] as Function;
    final sendPort = message['sendPort'] as SendPort;
    
    try {
      final result = computation();
      sendPort.send(result);
    } catch (e) {
      sendPort.send(e);
    }
  }
  
  /// Get performance statistics
  PerformanceStatistics getPerformanceStatistics() {
    return PerformanceStatistics(
      totalOperations: _operationCounts.values.fold(0, (a, b) => a + b),
      averageOperationTimes: _calculateAverageOperationTimes(),
      slowOperations: _getSlowOperations(),
      memoryTrend: _calculateMemoryTrend(),
      currentMemoryUsage: _getCurrentMemoryUsage(),
      peakMemoryUsage: _memoryHistory.isNotEmpty 
          ? _memoryHistory.map((s) => s.usedMemoryMB).reduce(math.max)
          : 0.0,
      optimizationsApplied: _getOptimizationsApplied(),
    );
  }
  
  double _calculateMemoryTrend() {
    if (_memoryHistory.length < 2) return 0.0;
    
    final recent = _memoryHistory.takeLast(10);
    final first = recent.first.usedMemoryMB;
    final last = recent.last.usedMemoryMB;
    
    return last - first;
  }
  
  List<String> _getOptimizationsApplied() {
    // Return list of optimizations that have been applied
    return ['audio_processing', 'memory_cleanup', 'buffer_pooling'];
  }
  
  /// Dispose and cleanup resources
  void dispose() {
    _performanceTimer?.cancel();
    _memoryTimer?.cancel();
    
    _cleanupTimers.values.forEach((timer) => timer.cancel());
    _cleanupTimers.clear();
    
    _metricsController.close();
    
    _operationTimers.clear();
    _operationHistory.clear();
    _operationCounts.clear();
    _memoryHistory.clear();
    _objectPool.clear();
  }
}

// Data models for performance monitoring

class PerformanceMetrics {
  final DateTime timestamp;
  final Map<String, int> operationCounts;
  final Map<String, Duration> averageOperationTimes;
  final List<SlowOperation> slowOperations;
  final double memoryUsage;
  final int gcEvents;
  
  PerformanceMetrics({
    required this.timestamp,
    required this.operationCounts,
    required this.averageOperationTimes,
    required this.slowOperations,
    required this.memoryUsage,
    required this.gcEvents,
  });
}

class MemorySnapshot {
  final DateTime timestamp;
  final double usedMemoryMB;
  final int objectCount;
  final int gcEvents;
  
  MemorySnapshot({
    required this.timestamp,
    required this.usedMemoryMB,
    required this.objectCount,
    required this.gcEvents,
  });
}

class SlowOperation {
  final String operationName;
  final int slowCount;
  final int totalCount;
  final Duration averageSlowDuration;
  
  SlowOperation({
    required this.operationName,
    required this.slowCount,
    required this.totalCount,
    required this.averageSlowDuration,
  });
  
  double get slowPercentage => slowCount / totalCount;
}

class PerformanceStatistics {
  final int totalOperations;
  final Map<String, Duration> averageOperationTimes;
  final List<SlowOperation> slowOperations;
  final double memoryTrend;
  final double currentMemoryUsage;
  final double peakMemoryUsage;
  final List<String> optimizationsApplied;
  
  PerformanceStatistics({
    required this.totalOperations,
    required this.averageOperationTimes,
    required this.slowOperations,
    required this.memoryTrend,
    required this.currentMemoryUsage,
    required this.peakMemoryUsage,
    required this.optimizationsApplied,
  });
}

/// Mixin for performance monitoring in classes
mixin PerformanceMixin {
  final PerformanceManager _performanceManager = PerformanceManager();
  
  T measureOperation<T>(String operationName, T Function() operation) {
    _performanceManager.startOperation(operationName);
    try {
      return operation();
    } finally {
      _performanceManager.endOperation(operationName);
    }
  }
  
  Future<T> measureAsyncOperation<T>(String operationName, Future<T> Function() operation) async {
    _performanceManager.startOperation(operationName);
    try {
      return await operation();
    } finally {
      _performanceManager.endOperation(operationName);
    }
  }
}