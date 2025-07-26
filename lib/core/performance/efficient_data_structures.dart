import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'performance_manager.dart';

/// Collection of memory-efficient and performance-optimized data structures
/// specifically designed for audio processing and vocal training applications

/// Fixed-size ring buffer optimized for audio streaming
class AudioRingBuffer with PerformanceMixin {
  final Float32List _buffer;
  final int _capacity;
  int _head = 0;
  int _tail = 0;
  int _size = 0;
  
  AudioRingBuffer(this._capacity) : _buffer = Float32List(_capacity);
  
  int get capacity => _capacity;
  int get length => _size;
  bool get isEmpty => _size == 0;
  bool get isFull => _size == _capacity;
  double get fillRatio => _size / _capacity;
  
  /// Add a single sample
  void add(double sample) {
    _buffer[_head] = sample;
    _head = (_head + 1) % _capacity;
    
    if (_size < _capacity) {
      _size++;
    } else {
      _tail = (_tail + 1) % _capacity;
    }
  }
  
  /// Add multiple samples efficiently
  void addAll(List<double> samples) {
    measureOperation('ring_buffer_add_all', () {
      for (final sample in samples) {
        add(sample);
      }
    });
  }
  
  /// Get the latest sample without removing it
  double? get latest {
    if (isEmpty) return null;
    return _buffer[(_head - 1 + _capacity) % _capacity];
  }
  
  /// Get the oldest sample without removing it
  double? get oldest {
    if (isEmpty) return null;
    return _buffer[_tail];
  }
  
  /// Get a range of samples as a new Float32List
  Float32List getRange(int start, int count) {
    return measureOperation('ring_buffer_get_range', () {
      if (start < 0 || start >= _size || count <= 0) {
        return Float32List(0);
      }
      
      final actualCount = math.min(count, _size - start);
      final result = Float32List(actualCount);
      
      for (int i = 0; i < actualCount; i++) {
        final index = (_tail + start + i) % _capacity;
        result[i] = _buffer[index];
      }
      
      return result;
    });
  }
  
  /// Get all data as Float32List (creates copy)
  Float32List toList() {
    return getRange(0, _size);
  }
  
  /// Clear all data
  void clear() {
    _size = 0;
    _head = 0;
    _tail = 0;
  }
  
  /// Calculate RMS of current buffer contents
  double get rms {
    if (isEmpty) return 0.0;
    
    return measureOperation('ring_buffer_rms', () {
      double sum = 0.0;
      for (int i = 0; i < _size; i++) {
        final index = (_tail + i) % _capacity;
        final value = _buffer[index];
        sum += value * value;
      }
      return math.sqrt(sum / _size);
    });
  }
}

/// Optimized sliding window for real-time analysis
class SlidingWindow<T> with PerformanceMixin {
  final List<T> _buffer;
  final int _maxSize;
  int _currentSize = 0;
  int _oldestIndex = 0;
  
  SlidingWindow(this._maxSize) : _buffer = List.filled(_maxSize, null, growable: false);
  
  int get maxSize => _maxSize;
  int get currentSize => _currentSize;
  bool get isFull => _currentSize == _maxSize;
  
  /// Add item to window
  void add(T item) {
    measureOperation('sliding_window_add', () {
      if (_currentSize < _maxSize) {
        _buffer[_currentSize] = item;
        _currentSize++;
      } else {
        _buffer[_oldestIndex] = item;
        _oldestIndex = (_oldestIndex + 1) % _maxSize;
      }
    });
  }
  
  /// Get item at index (0 = oldest, currentSize-1 = newest)
  T? operator [](int index) {
    if (index < 0 || index >= _currentSize) return null;
    
    if (_currentSize < _maxSize) {
      return _buffer[index];
    } else {
      final actualIndex = (_oldestIndex + index) % _maxSize;
      return _buffer[actualIndex];
    }
  }
  
  /// Get newest item
  T? get newest {
    if (_currentSize == 0) return null;
    
    if (_currentSize < _maxSize) {
      return _buffer[_currentSize - 1];
    } else {
      final newestIndex = (_oldestIndex - 1 + _maxSize) % _maxSize;
      return _buffer[newestIndex];
    }
  }
  
  /// Get oldest item
  T? get oldest {
    if (_currentSize == 0) return null;
    return this[0];
  }
  
  /// Convert to list (newest first)
  List<T> toList({bool newestFirst = false}) {
    return measureOperation('sliding_window_to_list', () {
      final result = <T>[];
      
      for (int i = 0; i < _currentSize; i++) {
        final item = this[newestFirst ? _currentSize - 1 - i : i];
        if (item != null) result.add(item);
      }
      
      return result;
    });
  }
  
  /// Apply function to all items and return results
  List<R> map<R>(R Function(T item) f) {
    return measureOperation('sliding_window_map', () {
      final result = <R>[];
      for (int i = 0; i < _currentSize; i++) {
        final item = this[i];
        if (item != null) result.add(f(item));
      }
      return result;
    });
  }
  
  void clear() {
    _currentSize = 0;
    _oldestIndex = 0;
  }
}

/// Memory-efficient frequency bin storage
class FrequencyBins with PerformanceMixin {
  final Float32List _magnitudes;
  final Float32List _phases;
  final int _binCount;
  final double _sampleRate;
  final int _fftSize;
  
  FrequencyBins(this._binCount, this._sampleRate, this._fftSize)
      : _magnitudes = Float32List(_binCount),
        _phases = Float32List(_binCount);
  
  int get binCount => _binCount;
  double get frequencyResolution => _sampleRate / _fftSize;
  
  /// Set magnitude and phase for a bin
  void setBin(int index, double magnitude, double phase) {
    if (index >= 0 && index < _binCount) {
      _magnitudes[index] = magnitude;
      _phases[index] = phase;
    }
  }
  
  /// Get magnitude at bin index
  double getMagnitude(int index) {
    return (index >= 0 && index < _binCount) ? _magnitudes[index] : 0.0;
  }
  
  /// Get phase at bin index
  double getPhase(int index) {
    return (index >= 0 && index < _binCount) ? _phases[index] : 0.0;
  }
  
  /// Get frequency for bin index
  double getFrequency(int index) {
    return index * frequencyResolution;
  }
  
  /// Find bin index for frequency
  int getBinForFrequency(double frequency) {
    return (frequency / frequencyResolution).round().clamp(0, _binCount - 1);
  }
  
  /// Get magnitude at specific frequency
  double getMagnitudeAtFrequency(double frequency) {
    final binIndex = getBinForFrequency(frequency);
    return getMagnitude(binIndex);
  }
  
  /// Find peak frequency within a range
  double findPeakFrequency(double minFreq, double maxFreq) {
    return measureOperation('frequency_bins_find_peak', () {
      final minBin = getBinForFrequency(minFreq);
      final maxBin = getBinForFrequency(maxFreq);
      
      int peakBin = minBin;
      double peakMagnitude = getMagnitude(minBin);
      
      for (int i = minBin + 1; i <= maxBin; i++) {
        final magnitude = getMagnitude(i);
        if (magnitude > peakMagnitude) {
          peakMagnitude = magnitude;
          peakBin = i;
        }
      }
      
      return getFrequency(peakBin);
    });
  }
  
  /// Calculate spectral centroid
  double get spectralCentroid {
    return measureOperation('frequency_bins_centroid', () {
      double weightedSum = 0.0;
      double magnitudeSum = 0.0;
      
      for (int i = 0; i < _binCount; i++) {
        final magnitude = _magnitudes[i];
        final frequency = getFrequency(i);
        
        weightedSum += frequency * magnitude;
        magnitudeSum += magnitude;
      }
      
      return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0.0;
    });
  }
  
  /// Clear all bins
  void clear() {
    _magnitudes.fillRange(0, _binCount, 0.0);
    _phases.fillRange(0, _binCount, 0.0);
  }
}

/// Efficient sparse array for storing pitch track data
class SparseArray<T> with PerformanceMixin {
  final Map<int, T> _data = {};
  final T? _defaultValue;
  int _maxIndex = -1;
  
  SparseArray({T? defaultValue}) : _defaultValue = defaultValue;
  
  int get maxIndex => _maxIndex;
  int get count => _data.length;
  Iterable<int> get indices => _data.keys;
  bool get isEmpty => _data.isEmpty;
  
  /// Set value at index
  void operator []=(int index, T value) {
    if (value != _defaultValue) {
      _data[index] = value;
      if (index > _maxIndex) _maxIndex = index;
    } else {
      _data.remove(index);
    }
  }
  
  /// Get value at index
  T? operator [](int index) {
    return _data[index] ?? _defaultValue;
  }
  
  /// Check if index has a non-default value
  bool hasValueAt(int index) {
    return _data.containsKey(index);
  }
  
  /// Get all non-default values as a map
  Map<int, T> get nonDefaultValues => Map.from(_data);
  
  /// Convert to dense list up to maxIndex
  List<T?> toDenseList() {
    return measureOperation('sparse_array_to_dense', () {
      if (_maxIndex < 0) return [];
      
      final result = List<T?>.filled(_maxIndex + 1, _defaultValue);
      _data.forEach((index, value) {
        result[index] = value;
      });
      return result;
    });
  }
  
  /// Find first index with non-default value after given index
  int? findNextIndex(int afterIndex) {
    for (final index in _data.keys) {
      if (index > afterIndex) return index;
    }
    return null;
  }
  
  /// Find last index with non-default value before given index
  int? findPreviousIndex(int beforeIndex) {
    int? result;
    for (final index in _data.keys) {
      if (index < beforeIndex) {
        result = index;
      } else {
        break;
      }
    }
    return result;
  }
  
  void clear() {
    _data.clear();
    _maxIndex = -1;
  }
}

/// Efficient cache with LRU eviction
class LRUCache<K, V> with PerformanceMixin {
  final int _maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap();
  
  LRUCache(this._maxSize);
  
  int get maxSize => _maxSize;
  int get currentSize => _cache.length;
  bool get isFull => _cache.length >= _maxSize;
  
  /// Get value for key
  V? get(K key) {
    return measureOperation('lru_cache_get', () {
      final value = _cache.remove(key);
      if (value != null) {
        _cache[key] = value; // Move to end (most recent)
      }
      return value;
    });
  }
  
  /// Put value for key
  void put(K key, V value) {
    measureOperation('lru_cache_put', () {
      if (_cache.containsKey(key)) {
        _cache.remove(key);
      } else if (_cache.length >= _maxSize) {
        // Remove least recently used
        _cache.remove(_cache.keys.first);
      }
      
      _cache[key] = value;
    });
  }
  
  /// Check if key exists
  bool containsKey(K key) => _cache.containsKey(key);
  
  /// Remove key
  V? remove(K key) => _cache.remove(key);
  
  /// Clear all entries
  void clear() => _cache.clear();
  
  /// Get all keys in LRU order (least recent first)
  List<K> get keysLRU => _cache.keys.toList();
}

/// Time-series data structure optimized for audio metrics
class TimeSeries<T> with PerformanceMixin {
  final List<TimePoint<T>> _points = [];
  final Duration _maxAge;
  final int _maxPoints;
  
  TimeSeries({
    Duration maxAge = const Duration(minutes: 10),
    int maxPoints = 1000,
  }) : _maxAge = maxAge, _maxPoints = maxPoints;
  
  int get length => _points.length;
  bool get isEmpty => _points.isEmpty;
  
  /// Add data point with timestamp
  void add(T value, {DateTime? timestamp}) {
    measureOperation('timeseries_add', () {
      final time = timestamp ?? DateTime.now();
      _points.add(TimePoint(time, value));
      
      // Remove old points
      _cleanup();
    });
  }
  
  void _cleanup() {
    final cutoffTime = DateTime.now().subtract(_maxAge);
    
    // Remove points older than maxAge
    _points.removeWhere((point) => point.timestamp.isBefore(cutoffTime));
    
    // Limit number of points
    if (_points.length > _maxPoints) {
      final excess = _points.length - _maxPoints;
      _points.removeRange(0, excess);
    }
  }
  
  /// Get points within time range
  List<TimePoint<T>> getRange(DateTime start, DateTime end) {
    return measureOperation('timeseries_get_range', () {
      return _points.where((point) => 
          point.timestamp.isAfter(start) && point.timestamp.isBefore(end)).toList();
    });
  }
  
  /// Get latest N points
  List<TimePoint<T>> getLatest(int count) {
    final startIndex = math.max(0, _points.length - count);
    return _points.sublist(startIndex);
  }
  
  /// Get points from last duration
  List<TimePoint<T>> getLastDuration(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    return _points.where((point) => point.timestamp.isAfter(cutoff)).toList();
  }
  
  /// Calculate average over time range (for numeric types)
  double? averageInRange(DateTime start, DateTime end) {
    if (T != double && T != int) return null;
    
    return measureOperation('timeseries_average', () {
      final rangePoints = getRange(start, end);
      if (rangePoints.isEmpty) return null;
      
      double sum = 0.0;
      for (final point in rangePoints) {
        if (point.value is num) {
          sum += (point.value as num).toDouble();
        }
      }
      
      return sum / rangePoints.length;
    });
  }
  
  void clear() => _points.clear();
}

/// Time point for TimeSeries
class TimePoint<T> {
  final DateTime timestamp;
  final T value;
  
  TimePoint(this.timestamp, this.value);
  
  @override
  String toString() => 'TimePoint(${timestamp.toIso8601String()}, $value)';
}

/// Memory-efficient histogram for frequency analysis
class Histogram with PerformanceMixin {
  final List<int> _bins;
  final double _minValue;
  final double _maxValue;
  final double _binWidth;
  int _count = 0;
  
  Histogram(this._minValue, this._maxValue, int binCount)
      : _bins = List.filled(binCount, 0),
        _binWidth = (_maxValue - _minValue) / binCount;
  
  int get binCount => _bins.length;
  int get totalCount => _count;
  double get minValue => _minValue;
  double get maxValue => _maxValue;
  
  /// Add value to histogram
  void add(double value) {
    measureOperation('histogram_add', () {
      final binIndex = _getBinIndex(value);
      if (binIndex >= 0 && binIndex < _bins.length) {
        _bins[binIndex]++;
        _count++;
      }
    });
  }
  
  int _getBinIndex(double value) {
    return ((value - _minValue) / _binWidth).floor();
  }
  
  /// Get count for bin
  int getBinCount(int index) {
    return (index >= 0 && index < _bins.length) ? _bins[index] : 0;
  }
  
  /// Get normalized frequency for bin
  double getBinFrequency(int index) {
    return _count > 0 ? getBinCount(index) / _count : 0.0;
  }
  
  /// Find mode (most frequent bin)
  int get modeBin {
    return measureOperation('histogram_mode', () {
      int maxBin = 0;
      int maxCount = _bins[0];
      
      for (int i = 1; i < _bins.length; i++) {
        if (_bins[i] > maxCount) {
          maxCount = _bins[i];
          maxBin = i;
        }
      }
      
      return maxBin;
    });
  }
  
  /// Get value for center of bin
  double getBinCenterValue(int index) {
    return _minValue + (index + 0.5) * _binWidth;
  }
  
  /// Calculate mean
  double get mean {
    return measureOperation('histogram_mean', () {
      if (_count == 0) return 0.0;
      
      double sum = 0.0;
      for (int i = 0; i < _bins.length; i++) {
        sum += getBinCenterValue(i) * _bins[i];
      }
      
      return sum / _count;
    });
  }
  
  void clear() {
    _bins.fillRange(0, _bins.length, 0);
    _count = 0;
  }
}

/// Priority queue optimized for audio processing tasks
class AudioPriorityQueue<T> with PerformanceMixin {
  final List<_PriorityItem<T>> _heap = [];
  final bool _isMaxHeap;
  
  AudioPriorityQueue({bool maxHeap = true}) : _isMaxHeap = maxHeap;
  
  int get length => _heap.length;
  bool get isEmpty => _heap.isEmpty;
  bool get isNotEmpty => _heap.isNotEmpty;
  
  /// Add item with priority
  void add(T item, double priority) {
    measureOperation('priority_queue_add', () {
      _heap.add(_PriorityItem(item, priority));
      _bubbleUp(_heap.length - 1);
    });
  }
  
  /// Remove and return highest priority item
  T? removeFirst() {
    return measureOperation('priority_queue_remove_first', () {
      if (_heap.isEmpty) return null;
      
      final result = _heap[0].item;
      
      if (_heap.length == 1) {
        _heap.clear();
      } else {
        _heap[0] = _heap.removeLast();
        _bubbleDown(0);
      }
      
      return result;
    });
  }
  
  /// Peek at highest priority item without removing
  T? get first => _heap.isNotEmpty ? _heap[0].item : null;
  
  void _bubbleUp(int index) {
    while (index > 0) {
      final parentIndex = (index - 1) ~/ 2;
      
      if (_shouldSwap(_heap[index], _heap[parentIndex])) {
        _swap(index, parentIndex);
        index = parentIndex;
      } else {
        break;
      }
    }
  }
  
  void _bubbleDown(int index) {
    while (true) {
      final leftChild = 2 * index + 1;
      final rightChild = 2 * index + 2;
      int target = index;
      
      if (leftChild < _heap.length && _shouldSwap(_heap[leftChild], _heap[target])) {
        target = leftChild;
      }
      
      if (rightChild < _heap.length && _shouldSwap(_heap[rightChild], _heap[target])) {
        target = rightChild;
      }
      
      if (target != index) {
        _swap(index, target);
        index = target;
      } else {
        break;
      }
    }
  }
  
  bool _shouldSwap(_PriorityItem<T> child, _PriorityItem<T> parent) {
    return _isMaxHeap 
        ? child.priority > parent.priority
        : child.priority < parent.priority;
  }
  
  void _swap(int i, int j) {
    final temp = _heap[i];
    _heap[i] = _heap[j];
    _heap[j] = temp;
  }
  
  void clear() => _heap.clear();
}

class _PriorityItem<T> {
  final T item;
  final double priority;
  
  _PriorityItem(this.item, this.priority);
}