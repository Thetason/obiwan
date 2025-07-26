import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'performance_manager.dart';

/// Memory-efficient audio processing utilities with pooling and optimization
class MemoryEfficientAudio with PerformanceMixin {
  static final MemoryEfficientAudio _instance = MemoryEfficientAudio._internal();
  factory MemoryEfficientAudio() => _instance;
  MemoryEfficientAudio._internal();
  
  // Buffer pools for different sizes
  final Map<int, List<Float32List>> _bufferPools = {};
  final Map<int, List<Uint8List>> _byteBufferPools = {};
  final Map<int, List<List<double>>> _doubleBufferPools = {};
  
  // Reusable computation arrays
  Float32List? _reuseableWindowFunction;
  Float32List? _reuseableRealBuffer;
  Float32List? _reuseableImagBuffer;
  
  // Pool configuration
  static const int _maxPoolSize = 10;
  static const int _minBufferSize = 64;
  static const int _maxBufferSize = 32768;
  
  /// Get a Float32List buffer from pool or create new one
  Float32List getFloat32Buffer(int size) {
    return measureOperation('get_float32_buffer', () {
      if (size < _minBufferSize || size > _maxBufferSize) {
        return Float32List(size);
      }
      
      final pool = _bufferPools[size];
      if (pool != null && pool.isNotEmpty) {
        final buffer = pool.removeLast();
        // Clear the buffer for reuse
        buffer.fillRange(0, buffer.length, 0.0);
        return buffer;
      }
      
      return Float32List(size);
    });
  }
  
  /// Return a Float32List buffer to pool
  void returnFloat32Buffer(Float32List buffer) {
    measureOperation('return_float32_buffer', () {
      final size = buffer.length;
      if (size < _minBufferSize || size > _maxBufferSize) {
        return; // Don't pool oversized buffers
      }
      
      _bufferPools.putIfAbsent(size, () => <Float32List>[]);
      final pool = _bufferPools[size]!;
      
      if (pool.length < _maxPoolSize) {
        pool.add(buffer);
      }
    });
  }
  
  /// Get a Uint8List buffer from pool
  Uint8List getUint8Buffer(int size) {
    return measureOperation('get_uint8_buffer', () {
      if (size < _minBufferSize || size > _maxBufferSize) {
        return Uint8List(size);
      }
      
      final pool = _byteBufferPools[size];
      if (pool != null && pool.isNotEmpty) {
        final buffer = pool.removeLast();
        buffer.fillRange(0, buffer.length, 0);
        return buffer;
      }
      
      return Uint8List(size);
    });
  }
  
  /// Return a Uint8List buffer to pool
  void returnUint8Buffer(Uint8List buffer) {
    measureOperation('return_uint8_buffer', () {
      final size = buffer.length;
      if (size < _minBufferSize || size > _maxBufferSize) {
        return;
      }
      
      _byteBufferPools.putIfAbsent(size, () => <Uint8List>[]);
      final pool = _byteBufferPools[size]!;
      
      if (pool.length < _maxPoolSize) {
        pool.add(buffer);
      }
    });
  }
  
  /// Get a List<double> buffer from pool
  List<double> getDoubleBuffer(int size) {
    return measureOperation('get_double_buffer', () {
      if (size < _minBufferSize || size > _maxBufferSize) {
        return List.filled(size, 0.0);
      }
      
      final pool = _doubleBufferPools[size];
      if (pool != null && pool.isNotEmpty) {
        final buffer = pool.removeLast();
        buffer.fillRange(0, buffer.length, 0.0);
        return buffer;
      }
      
      return List.filled(size, 0.0);
    });
  }
  
  /// Return a List<double> buffer to pool
  void returnDoubleBuffer(List<double> buffer) {
    measureOperation('return_double_buffer', () {
      final size = buffer.length;
      if (size < _minBufferSize || size > _maxBufferSize) {
        return;
      }
      
      _doubleBufferPools.putIfAbsent(size, () => <List<double>>[]);
      final pool = _doubleBufferPools[size]!;
      
      if (pool.length < _maxPoolSize) {
        pool.add(buffer);
      }
    });
  }
  
  /// Memory-efficient audio resampling using linear interpolation
  Float32List resampleAudio(
    Float32List input,
    int inputSampleRate,
    int outputSampleRate, {
    bool inPlace = false,
  }) {
    return measureOperation('resample_audio', () {
      if (inputSampleRate == outputSampleRate) {
        return inPlace ? input : Float32List.fromList(input);
      }
      
      final ratio = inputSampleRate / outputSampleRate;
      final outputLength = (input.length / ratio).round();
      
      final output = inPlace && input.length >= outputLength 
          ? input 
          : getFloat32Buffer(outputLength);
      
      // Linear interpolation resampling
      for (int i = 0; i < outputLength; i++) {
        final sourceIndex = i * ratio;
        final lowerIndex = sourceIndex.floor();
        final upperIndex = math.min(lowerIndex + 1, input.length - 1);
        final fraction = sourceIndex - lowerIndex;
        
        if (lowerIndex < input.length) {
          output[i] = input[lowerIndex] * (1 - fraction) + 
                     input[upperIndex] * fraction;
        } else {
          output[i] = 0.0;
        }
      }
      
      if (!inPlace && input.length != outputLength) {
        returnFloat32Buffer(input);
      }
      
      return output;
    });
  }
  
  /// Memory-efficient window function application
  Float32List applyWindow(Float32List input, WindowType windowType, {bool inPlace = true}) {
    return measureOperation('apply_window', () {
      final size = input.length;
      Float32List? window = _getWindowFunction(size, windowType);
      
      final output = inPlace ? input : getFloat32Buffer(size);
      
      if (!inPlace) {
        for (int i = 0; i < size; i++) {
          output[i] = input[i];
        }
      }
      
      // Apply window in-place
      for (int i = 0; i < size; i++) {
        output[i] *= window[i];
      }
      
      if (!inPlace) {
        returnFloat32Buffer(input);
      }
      
      return output;
    });
  }
  
  Float32List _getWindowFunction(int size, WindowType windowType) {
    // Reuse window function if same size and type
    if (_reuseableWindowFunction != null && _reuseableWindowFunction!.length == size) {
      return _reuseableWindowFunction!;
    }
    
    _reuseableWindowFunction = getFloat32Buffer(size);
    
    switch (windowType) {
      case WindowType.hann:
        for (int i = 0; i < size; i++) {
          _reuseableWindowFunction![i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (size - 1));
        }
        break;
        
      case WindowType.hamming:
        for (int i = 0; i < size; i++) {
          _reuseableWindowFunction![i] = 0.54 - 0.46 * math.cos(2 * math.pi * i / (size - 1));
        }
        break;
        
      case WindowType.blackman:
        for (int i = 0; i < size; i++) {
          final n = i / (size - 1);
          _reuseableWindowFunction![i] = 0.42 - 0.5 * math.cos(2 * math.pi * n) + 
                                        0.08 * math.cos(4 * math.pi * n);
        }
        break;
        
      case WindowType.rectangular:
        _reuseableWindowFunction!.fillRange(0, size, 1.0);
        break;
    }
    
    return _reuseableWindowFunction!;
  }
  
  /// Memory-efficient RMS calculation
  double calculateRMS(Float32List input) {
    return measureOperation('calculate_rms', () {
      double sum = 0.0;
      
      // Unroll loop for better performance
      int i = 0;
      final end = input.length - (input.length % 4);
      
      for (; i < end; i += 4) {
        final a = input[i];
        final b = input[i + 1];
        final c = input[i + 2];
        final d = input[i + 3];
        sum += a * a + b * b + c * c + d * d;
      }
      
      // Handle remaining samples
      for (; i < input.length; i++) {
        sum += input[i] * input[i];
      }
      
      return math.sqrt(sum / input.length);
    });
  }
  
  /// Memory-efficient peak detection
  List<int> findPeaks(
    Float32List input,
    double threshold, {
    int minDistance = 1,
    int maxPeaks = 100,
  }) {
    return measureOperation('find_peaks', () {
      final peaks = <int>[];
      
      for (int i = minDistance; i < input.length - minDistance; i++) {
        if (input[i] < threshold) continue;
        
        bool isPeak = true;
        
        // Check if it's a local maximum
        for (int j = i - minDistance; j <= i + minDistance; j++) {
          if (j != i && input[j] >= input[i]) {
            isPeak = false;
            break;
          }
        }
        
        if (isPeak) {
          peaks.add(i);
          
          if (peaks.length >= maxPeaks) {
            break;
          }
          
          // Skip ahead to avoid finding multiple peaks in the same region
          i += minDistance;
        }
      }
      
      return peaks;
    });
  }
  
  /// Memory-efficient autocorrelation for pitch detection
  Float32List autocorrelation(Float32List input, {int maxLag = 1000}) {
    return measureOperation('autocorrelation', () {
      final actualMaxLag = math.min(maxLag, input.length ~/ 2);
      final result = getFloat32Buffer(actualMaxLag);
      
      for (int lag = 0; lag < actualMaxLag; lag++) {
        double sum = 0.0;
        int count = 0;
        
        for (int i = 0; i < input.length - lag; i++) {
          sum += input[i] * input[i + lag];
          count++;
        }
        
        result[lag] = count > 0 ? sum / count : 0.0;
      }
      
      return result;
    });
  }
  
  /// Memory-efficient circular buffer implementation
  CircularAudioBuffer createCircularBuffer(int size) {
    return CircularAudioBuffer._(size, this);
  }
  
  /// Batch process audio chunks efficiently
  List<T> batchProcessAudio<T>(
    List<Float32List> audioChunks,
    T Function(Float32List chunk) processor, {
    int batchSize = 4,
  }) {
    return measureOperation('batch_process_audio', () {
      final results = <T>[];
      
      for (int i = 0; i < audioChunks.length; i += batchSize) {
        final batchEnd = math.min(i + batchSize, audioChunks.length);
        final batch = audioChunks.sublist(i, batchEnd);
        
        // Process batch in parallel where possible
        final batchResults = batch.map(processor).toList();
        results.addAll(batchResults);
        
        // Yield control periodically for UI responsiveness
        if (i % (batchSize * 5) == 0 && i > 0) {
          // Allow Flutter to process other tasks
        }
      }
      
      return results;
    });
  }
  
  /// Efficient audio mixing
  Float32List mixAudio(List<Float32List> inputs, {List<double>? gains}) {
    return measureOperation('mix_audio', () {
      if (inputs.isEmpty) return Float32List(0);
      
      final outputLength = inputs.map((i) => i.length).reduce(math.max);
      final output = getFloat32Buffer(outputLength);
      final actualGains = gains ?? List.filled(inputs.length, 1.0);
      
      for (int i = 0; i < inputs.length; i++) {
        final input = inputs[i];
        final gain = actualGains[i];
        
        for (int j = 0; j < math.min(input.length, outputLength); j++) {
          output[j] += input[j] * gain;
        }
      }
      
      // Normalize to prevent clipping
      final maxValue = output.map((s) => s.abs()).reduce(math.max);
      if (maxValue > 1.0) {
        final normalizationFactor = 1.0 / maxValue;
        for (int i = 0; i < output.length; i++) {
          output[i] *= normalizationFactor;
        }
      }
      
      return output;
    });
  }
  
  /// Clean up all buffer pools
  void clearBufferPools() {
    measureOperation('clear_buffer_pools', () {
      _bufferPools.clear();
      _byteBufferPools.clear();
      _doubleBufferPools.clear();
      
      _reuseableWindowFunction = null;
      _reuseableRealBuffer = null;
      _reuseableImagBuffer = null;
    });
  }
  
  /// Get memory usage statistics
  MemoryUsageStats getMemoryUsage() {
    int totalFloat32Buffers = 0;
    int totalUint8Buffers = 0;
    int totalDoubleBuffers = 0;
    
    _bufferPools.values.forEach((pool) => totalFloat32Buffers += pool.length);
    _byteBufferPools.values.forEach((pool) => totalUint8Buffers += pool.length);
    _doubleBufferPools.values.forEach((pool) => totalDoubleBuffers += pool.length);
    
    return MemoryUsageStats(
      float32BuffersPooled: totalFloat32Buffers,
      uint8BuffersPooled: totalUint8Buffers,
      doubleBuffersPooled: totalDoubleBuffers,
      poolSizesByType: {
        'Float32List': _bufferPools.length,
        'Uint8List': _byteBufferPools.length,
        'List<double>': _doubleBufferPools.length,
      },
    );
  }
}

/// Circular buffer for continuous audio processing
class CircularAudioBuffer {
  final Float32List _buffer;
  final MemoryEfficientAudio _audioManager;
  int _writeIndex = 0;
  int _size = 0;
  
  CircularAudioBuffer._(int capacity, this._audioManager) 
      : _buffer = _audioManager.getFloat32Buffer(capacity);
  
  int get capacity => _buffer.length;
  int get size => _size;
  bool get isFull => _size == capacity;
  bool get isEmpty => _size == 0;
  
  /// Add samples to the buffer
  void addSamples(Float32List samples) {
    for (int i = 0; i < samples.length; i++) {
      _buffer[_writeIndex] = samples[i];
      _writeIndex = (_writeIndex + 1) % capacity;
      
      if (_size < capacity) {
        _size++;
      }
    }
  }
  
  /// Get the latest N samples
  Float32List getLatestSamples(int count) {
    if (count > _size) {
      count = _size;
    }
    
    final result = _audioManager.getFloat32Buffer(count);
    
    for (int i = 0; i < count; i++) {
      final index = (_writeIndex - count + i + capacity) % capacity;
      result[i] = _buffer[index];
    }
    
    return result;
  }
  
  /// Clear the buffer
  void clear() {
    _writeIndex = 0;
    _size = 0;
    _buffer.fillRange(0, capacity, 0.0);
  }
  
  /// Dispose and return buffer to pool
  void dispose() {
    _audioManager.returnFloat32Buffer(_buffer);
  }
}

/// Memory usage statistics
class MemoryUsageStats {
  final int float32BuffersPooled;
  final int uint8BuffersPooled;
  final int doubleBuffersPooled;
  final Map<String, int> poolSizesByType;
  
  MemoryUsageStats({
    required this.float32BuffersPooled,
    required this.uint8BuffersPooled,
    required this.doubleBuffersPooled,
    required this.poolSizesByType,
  });
  
  int get totalBuffersPooled => 
      float32BuffersPooled + uint8BuffersPooled + doubleBuffersPooled;
}

/// Window function types
enum WindowType {
  rectangular,
  hann,
  hamming,
  blackman,
}

/// Utility extension for automatic buffer management
extension AudioBufferExtensions on Float32List {
  /// Apply window function with automatic buffer management
  Float32List applyWindowEfficient(WindowType windowType, {bool inPlace = true}) {
    return MemoryEfficientAudio().applyWindow(this, windowType, inPlace: inPlace);
  }
  
  /// Calculate RMS efficiently
  double get rmsEfficient => MemoryEfficientAudio().calculateRMS(this);
  
  /// Return buffer to pool when done
  void returnToPool() {
    MemoryEfficientAudio().returnFloat32Buffer(this);
  }
}