import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:fftea/fftea.dart';

/// Advanced breathing pattern detection and analysis system
class AdvancedBreathingDetector {
  static const int _sampleRate = 44100;
  static const int _frameSize = 2048;
  static const int _hopSize = 512;
  static const double _breathingFrequencyMin = 0.1; // 6 breaths per minute
  static const double _breathingFrequencyMax = 2.0; // 120 breaths per minute
  
  final StreamController<BreathingAnalysis> _analysisController = 
      StreamController<BreathingAnalysis>.broadcast();
  
  Stream<BreathingAnalysis> get analysisStream => _analysisController.stream;
  
  late FFT _fft;
  final List<double> _audioBuffer = [];
  final List<double> _energyHistory = [];
  final List<double> _spectralCentroidHistory = [];
  final List<BreathingEvent> _breathingEvents = [];
  
  // Advanced analysis parameters
  final List<double> _lowPassFilter = [];
  final List<double> _highPassFilter = [];
  double _noiseFloor = 0.0;
  double _currentEnergy = 0.0;
  bool _isInhaling = false;
  bool _isExhaling = false;
  DateTime? _lastBreathTime;
  
  // Breathing pattern tracking
  final List<double> _breathingRates = [];
  final List<Duration> _inhaleDurations = [];
  final List<Duration> _exhaleDurations = [];
  final List<Duration> _pauseDurations = [];
  
  // Machine learning features for breath detection
  final List<double> _spectralFeatures = [];
  final List<double> _temporalFeatures = [];
  final List<double> _cepstralFeatures = [];
  
  bool _isInitialized = false;
  Timer? _analysisTimer;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _fft = FFT(_frameSize);
    _initializeFilters();
    _startPeriodicAnalysis();
    
    _isInitialized = true;
  }
  
  void _initializeFilters() {
    // Design low-pass filter for breathing frequency extraction
    const cutoffFreq = 5.0; // Hz
    const filterOrder = 64;
    
    for (int i = 0; i < filterOrder; i++) {
      final normalized = (i - filterOrder / 2) / (filterOrder / 2);
      final sinc = math.sin(math.pi * normalized * cutoffFreq / (_sampleRate / 2)) /
                   (math.pi * normalized);
      final window = 0.54 - 0.46 * math.cos(2 * math.pi * i / (filterOrder - 1));
      
      _lowPassFilter.add(i == filterOrder ~/ 2 ? cutoffFreq / (_sampleRate / 2) : sinc * window);
    }
    
    // High-pass filter for noise reduction
    for (int i = 0; i < filterOrder; i++) {
      _highPassFilter.add(i == filterOrder ~/ 2 ? 1.0 - _lowPassFilter[i] : -_lowPassFilter[i]);
    }
  }
  
  void _startPeriodicAnalysis() {
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _performPeriodicAnalysis();
    });
  }
  
  /// Process incoming audio data for breathing detection
  void processAudioData(List<double> audioData) {
    if (!_isInitialized) return;
    
    _audioBuffer.addAll(audioData);
    
    // Process when we have enough samples
    while (_audioBuffer.length >= _frameSize) {
      final frame = _audioBuffer.take(_frameSize).toList();
      _audioBuffer.removeRange(0, _hopSize);
      
      _processAudioFrame(frame);
    }
  }
  
  void _processAudioFrame(List<double> frame) {
    // Apply preprocessing
    final preprocessedFrame = _preprocessAudio(frame);
    
    // Extract energy features
    final energy = _calculateRMSEnergy(preprocessedFrame);
    _currentEnergy = energy;
    _energyHistory.add(energy);
    
    // Maintain history length
    if (_energyHistory.length > 1000) {
      _energyHistory.removeAt(0);
    }
    
    // Extract spectral features
    final spectralFeatures = _extractSpectralFeatures(preprocessedFrame);
    _spectralCentroidHistory.add(spectralFeatures['centroid']!);
    
    // Maintain spectral history
    if (_spectralCentroidHistory.length > 500) {
      _spectralCentroidHistory.removeAt(0);
    }
    
    // Update noise floor estimation
    _updateNoiseFloor(energy);
    
    // Detect breathing events
    _detectBreathingEvents(energy, spectralFeatures);
  }
  
  List<double> _preprocessAudio(List<double> frame) {
    // Apply high-pass filter to remove DC and low-frequency noise
    final filtered = _applyFilter(frame, _highPassFilter);
    
    // Apply windowing function
    final windowed = <double>[];
    for (int i = 0; i < frame.length; i++) {
      final window = 0.5 - 0.5 * math.cos(2 * math.pi * i / (frame.length - 1));
      windowed.add(filtered[i] * window);
    }
    
    return windowed;
  }
  
  List<double> _applyFilter(List<double> signal, List<double> filter) {
    final filtered = <double>[];
    
    for (int i = 0; i < signal.length; i++) {
      double sum = 0.0;
      
      for (int j = 0; j < filter.length; j++) {
        final signalIndex = i - j;
        if (signalIndex >= 0) {
          sum += signal[signalIndex] * filter[j];
        }
      }
      
      filtered.add(sum);
    }
    
    return filtered;
  }
  
  double _calculateRMSEnergy(List<double> frame) {
    double sum = 0.0;
    for (final sample in frame) {
      sum += sample * sample;
    }
    return math.sqrt(sum / frame.length);
  }
  
  Map<String, double> _extractSpectralFeatures(List<double> frame) {
    // Compute FFT
    final float32Frame = Float32List.fromList(frame);
    final spectrum = _fft.realFft(float32Frame);
    
    // Calculate magnitudes
    final magnitudes = spectrum.map((complex) =>
        math.sqrt(complex.x * complex.x + complex.y * complex.y)).toList();
    
    // Calculate spectral centroid
    double weightedSum = 0.0;
    double magnitudeSum = 0.0;
    
    for (int i = 0; i < magnitudes.length; i++) {
      final frequency = i * _sampleRate / _frameSize;
      weightedSum += frequency * magnitudes[i];
      magnitudeSum += magnitudes[i];
    }
    
    final spectralCentroid = magnitudeSum > 0 ? weightedSum / magnitudeSum : 0.0;
    
    // Calculate spectral rolloff
    final targetEnergy = magnitudeSum * 0.85;
    double cumulativeEnergy = 0.0;
    int rolloffBin = 0;
    
    for (int i = 0; i < magnitudes.length; i++) {
      cumulativeEnergy += magnitudes[i];
      if (cumulativeEnergy >= targetEnergy) {
        rolloffBin = i;
        break;
      }
    }
    
    final spectralRolloff = rolloffBin * _sampleRate / _frameSize;
    
    // Calculate spectral flux
    static List<double> previousMagnitudes = [];
    double spectralFlux = 0.0;
    
    if (previousMagnitudes.isNotEmpty && previousMagnitudes.length == magnitudes.length) {
      for (int i = 0; i < magnitudes.length; i++) {
        final diff = magnitudes[i] - previousMagnitudes[i];
        spectralFlux += math.max(0, diff);
      }
    }
    
    previousMagnitudes = List.from(magnitudes);
    
    return {
      'centroid': spectralCentroid,
      'rolloff': spectralRolloff,
      'flux': spectralFlux,
      'energy': magnitudeSum,
    };
  }
  
  void _updateNoiseFloor(double energy) {
    // Adaptive noise floor estimation using minimum statistics
    const alpha = 0.001;
    
    if (_noiseFloor == 0.0) {
      _noiseFloor = energy;
    } else {
      _noiseFloor = _noiseFloor * (1 - alpha) + math.min(energy, _noiseFloor) * alpha;
    }
  }
  
  void _detectBreathingEvents(double energy, Map<String, double> spectralFeatures) {
    if (_energyHistory.length < 10) return;
    
    // Calculate relative energy
    final relativeEnergy = _noiseFloor > 0 ? energy / _noiseFloor : 1.0;
    
    // Detect breathing phases using multiple criteria
    final isBreathingDetected = _isBreathingActivity(relativeEnergy, spectralFeatures);
    
    if (isBreathingDetected) {
      final breathType = _classifyBreathType(energy, spectralFeatures);
      _recordBreathingEvent(breathType);
    }
  }
  
  bool _isBreathingActivity(double relativeEnergy, Map<String, double> spectralFeatures) {
    // Multi-criteria breathing detection
    final energyThreshold = relativeEnergy > 2.0;
    final spectralCharacteristics = _hasBreathingSpectralPattern(spectralFeatures);
    final temporalPattern = _hasBreathingTemporalPattern();
    
    return energyThreshold && spectralCharacteristics && temporalPattern;
  }
  
  bool _hasBreathingSpectralPattern(Map<String, double> spectralFeatures) {
    // Breathing typically has energy in lower frequencies with specific spectral characteristics
    final centroid = spectralFeatures['centroid']!;
    final rolloff = spectralFeatures['rolloff']!;
    
    // Breathing sounds typically have centroid below 2000 Hz
    final centroidInRange = centroid < 2000;
    
    // Check for typical breathing frequency content
    final rolloffInRange = rolloff < 4000;
    
    return centroidInRange && rolloffInRange;
  }
  
  bool _hasBreathingTemporalPattern() {
    if (_energyHistory.length < 50) return false;
    
    // Analyze recent energy pattern for breathing characteristics
    final recentEnergy = _energyHistory.takeLast(50).toList();
    
    // Calculate energy variance to detect breathing patterns
    final mean = recentEnergy.reduce((a, b) => a + b) / recentEnergy.length;
    final variance = recentEnergy.map((e) => math.pow(e - mean, 2)).reduce((a, b) => a + b) / recentEnergy.length;
    
    // Breathing patterns should show moderate variance
    return variance > 0.001 && variance < 0.1;
  }
  
  BreathType _classifyBreathType(double energy, Map<String, double> spectralFeatures) {
    final flux = spectralFeatures['flux']!;
    
    // Use spectral flux and energy trends to classify breath type
    if (_energyHistory.length >= 10) {
      final recentTrend = _calculateEnergyTrend();
      
      if (recentTrend > 0.1 && flux > 0.01) {
        return BreathType.inhale;
      } else if (recentTrend < -0.1) {
        return BreathType.exhale;
      }
    }
    
    return BreathType.pause;
  }
  
  double _calculateEnergyTrend() {
    if (_energyHistory.length < 10) return 0.0;
    
    final recent = _energyHistory.takeLast(10).toList();
    final first = recent.take(5).reduce((a, b) => a + b) / 5;
    final last = recent.skip(5).reduce((a, b) => a + b) / 5;
    
    return (last - first) / first;
  }
  
  void _recordBreathingEvent(BreathType type) {
    final now = DateTime.now();
    
    final event = BreathingEvent(
      type: type,
      timestamp: now,
      energy: _currentEnergy,
      duration: _lastBreathTime != null ? now.difference(_lastBreathTime!) : Duration.zero,
    );
    
    _breathingEvents.add(event);
    _lastBreathTime = now;
    
    // Maintain event history
    if (_breathingEvents.length > 1000) {
      _breathingEvents.removeAt(0);
    }
    
    // Update breathing statistics
    _updateBreathingStatistics(event);
  }
  
  void _updateBreathingStatistics(BreathingEvent event) {
    switch (event.type) {
      case BreathType.inhale:
        _inhaleDurations.add(event.duration);
        break;
      case BreathType.exhale:
        _exhaleDurations.add(event.duration);
        break;
      case BreathType.pause:
        _pauseDurations.add(event.duration);
        break;
    }
    
    // Maintain statistics length
    const maxHistory = 100;
    if (_inhaleDurations.length > maxHistory) _inhaleDurations.removeAt(0);
    if (_exhaleDurations.length > maxHistory) _exhaleDurations.removeAt(0);
    if (_pauseDurations.length > maxHistory) _pauseDurations.removeAt(0);
  }
  
  void _performPeriodicAnalysis() {
    if (_breathingEvents.length < 5) return;
    
    final analysis = _generateBreathingAnalysis();
    _analysisController.add(analysis);
  }
  
  BreathingAnalysis _generateBreathingAnalysis() {
    final now = DateTime.now();
    final recentEvents = _breathingEvents
        .where((e) => now.difference(e.timestamp).inMinutes < 5)
        .toList();
    
    // Calculate breathing rate
    final breathingRate = _calculateBreathingRate(recentEvents);
    
    // Calculate rhythm regularity
    final rhythmRegularity = _calculateRhythmRegularity();
    
    // Assess breathing efficiency
    final efficiency = _assessBreathingEfficiency();
    
    // Detect breathing patterns
    final pattern = _detectBreathingPattern();
    
    // Generate insights and recommendations
    final insights = _generateBreathingInsights(breathingRate, rhythmRegularity, efficiency);
    
    return BreathingAnalysis(
      breathingRate: breathingRate,
      rhythmRegularity: rhythmRegularity,
      efficiency: efficiency,
      pattern: pattern,
      insights: insights,
      timestamp: now,
      recentEvents: List.from(recentEvents),
      inhaleDuration: _calculateAverageDuration(_inhaleDurations),
      exhaleDuration: _calculateAverageDuration(_exhaleDurations),
      inhaleExhaleRatio: _calculateInhaleExhaleRatio(),
    );
  }
  
  double _calculateBreathingRate(List<BreathingEvent> events) {
    if (events.length < 2) return 0.0;
    
    final inhaleEvents = events.where((e) => e.type == BreathType.inhale).toList();
    
    if (inhaleEvents.length < 2) return 0.0;
    
    final timeSpan = inhaleEvents.last.timestamp.difference(inhaleEvents.first.timestamp);
    return (inhaleEvents.length - 1) * 60 / timeSpan.inSeconds;
  }
  
  double _calculateRhythmRegularity() {
    if (_inhaleDurations.length < 5) return 0.0;
    
    final durations = _inhaleDurations.takeLast(10).map((d) => d.inMilliseconds.toDouble()).toList();
    
    if (durations.isEmpty) return 0.0;
    
    final mean = durations.reduce((a, b) => a + b) / durations.length;
    final variance = durations.map((d) => math.pow(d - mean, 2)).reduce((a, b) => a + b) / durations.length;
    final standardDeviation = math.sqrt(variance);
    
    // Regularity is inverse of coefficient of variation
    return mean > 0 ? 1.0 / (1.0 + standardDeviation / mean) : 0.0;
  }
  
  double _assessBreathingEfficiency() {
    if (_inhaleDurations.isEmpty || _exhaleDurations.isEmpty) return 0.0;
    
    final avgInhale = _calculateAverageDuration(_inhaleDurations).inMilliseconds;
    final avgExhale = _calculateAverageDuration(_exhaleDurations).inMilliseconds;
    
    // Ideal inhale:exhale ratio is around 1:2
    final ratio = avgExhale / math.max(avgInhale, 1);
    final idealRatio = 2.0;
    
    // Efficiency based on how close to ideal ratio
    return 1.0 / (1.0 + math.pow(ratio - idealRatio, 2));
  }
  
  BreathingPattern _detectBreathingPattern() {
    if (_breathingEvents.length < 10) return BreathingPattern.unknown;
    
    final recentEvents = _breathingEvents.takeLast(20).toList();
    final inhaleCount = recentEvents.where((e) => e.type == BreathType.inhale).length;
    final exhaleCount = recentEvents.where((e) => e.type == BreathType.exhale).length;
    final pauseCount = recentEvents.where((e) => e.type == BreathType.pause).length;
    
    // Analyze pattern characteristics
    if (pauseCount > inhaleCount + exhaleCount) {
      return BreathingPattern.interrupted;
    } else if (inhaleCount > exhaleCount * 1.5) {
      return BreathingPattern.shallow;
    } else if (exhaleCount > inhaleCount * 1.5) {
      return BreathingPattern.rapid;
    } else {
      return BreathingPattern.normal;
    }
  }
  
  List<BreathingInsight> _generateBreathingInsights(
    double breathingRate,
    double rhythmRegularity,
    double efficiency,
  ) {
    final insights = <BreathingInsight>[];
    
    // Rate insights
    if (breathingRate < 12) {
      insights.add(BreathingInsight(
        type: BreathingInsightType.rate,
        message: '호흡이 느립니다. 조금 더 자연스럽게 호흡해보세요.',
        severity: InsightSeverity.info,
        recommendation: '편안한 자세에서 자연스러운 호흡 리듬을 찾아보세요.',
      ));
    } else if (breathingRate > 20) {
      insights.add(BreathingInsight(
        type: BreathingInsightType.rate,
        message: '호흡이 빠릅니다. 긴장을 풀고 천천히 호흡해보세요.',
        severity: InsightSeverity.warning,
        recommendation: '4초 들이마시고 6초 내쉬는 연습을 해보세요.',
      ));
    }
    
    // Regularity insights
    if (rhythmRegularity < 0.7) {
      insights.add(BreathingInsight(
        type: BreathingInsightType.rhythm,
        message: '호흡 리듬이 불규칙합니다.',
        severity: InsightSeverity.warning,
        recommendation: '메트로놈에 맞춰 규칙적인 호흡 연습을 해보세요.',
      ));
    }
    
    // Efficiency insights
    if (efficiency < 0.6) {
      insights.add(BreathingInsight(
        type: BreathingInsightType.technique,
        message: '호흡 효율성을 개선할 수 있습니다.',
        severity: InsightSeverity.info,
        recommendation: '복식호흡과 날숨을 들숨보다 길게 하는 연습을 해보세요.',
      ));
    }
    
    return insights;
  }
  
  Duration _calculateAverageDuration(List<Duration> durations) {
    if (durations.isEmpty) return Duration.zero;
    
    final totalMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
    return Duration(milliseconds: totalMs ~/ durations.length);
  }
  
  double _calculateInhaleExhaleRatio() {
    if (_inhaleDurations.isEmpty || _exhaleDurations.isEmpty) return 1.0;
    
    final avgInhale = _calculateAverageDuration(_inhaleDurations).inMilliseconds;
    final avgExhale = _calculateAverageDuration(_exhaleDurations).inMilliseconds;
    
    return avgExhale / math.max(avgInhale, 1);
  }
  
  /// Get current breathing statistics
  BreathingStatistics getCurrentStatistics() {
    return BreathingStatistics(
      totalBreaths: _breathingEvents.length,
      averageRate: _breathingEvents.isNotEmpty ? _calculateBreathingRate(_breathingEvents.takeLast(20).toList()) : 0.0,
      rhythmRegularity: _calculateRhythmRegularity(),
      efficiency: _assessBreathingEfficiency(),
      sessionsToday: _getSessionsToday(),
      improvementTrend: _calculateImprovementTrend(),
    );
  }
  
  int _getSessionsToday() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    
    return _breathingEvents
        .where((e) => e.timestamp.isAfter(todayStart))
        .length;
  }
  
  double _calculateImprovementTrend() {
    // Calculate improvement over the last week
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    
    final recentEvents = _breathingEvents
        .where((e) => e.timestamp.isAfter(weekAgo))
        .toList();
    
    if (recentEvents.length < 10) return 0.0;
    
    final firstHalf = recentEvents.take(recentEvents.length ~/ 2);
    final secondHalf = recentEvents.skip(recentEvents.length ~/ 2);
    
    final firstHalfRate = _calculateBreathingRate(firstHalf.toList());
    final secondHalfRate = _calculateBreathingRate(secondHalf.toList());
    
    return secondHalfRate - firstHalfRate;
  }
  
  void dispose() {
    _analysisTimer?.cancel();
    _analysisController.close();
  }
}

// Data models for breathing analysis

class BreathingEvent {
  final BreathType type;
  final DateTime timestamp;
  final double energy;
  final Duration duration;
  
  BreathingEvent({
    required this.type,
    required this.timestamp,
    required this.energy,
    required this.duration,
  });
}

class BreathingAnalysis {
  final double breathingRate;
  final double rhythmRegularity;
  final double efficiency;
  final BreathingPattern pattern;
  final List<BreathingInsight> insights;
  final DateTime timestamp;
  final List<BreathingEvent> recentEvents;
  final Duration inhaleDuration;
  final Duration exhaleDuration;
  final double inhaleExhaleRatio;
  
  BreathingAnalysis({
    required this.breathingRate,
    required this.rhythmRegularity,
    required this.efficiency,
    required this.pattern,
    required this.insights,
    required this.timestamp,
    required this.recentEvents,
    required this.inhaleDuration,
    required this.exhaleDuration,
    required this.inhaleExhaleRatio,
  });
}

class BreathingInsight {
  final BreathingInsightType type;
  final String message;
  final InsightSeverity severity;
  final String recommendation;
  
  BreathingInsight({
    required this.type,
    required this.message,
    required this.severity,
    required this.recommendation,
  });
}

class BreathingStatistics {
  final int totalBreaths;
  final double averageRate;
  final double rhythmRegularity;
  final double efficiency;
  final int sessionsToday;
  final double improvementTrend;
  
  BreathingStatistics({
    required this.totalBreaths,
    required this.averageRate,
    required this.rhythmRegularity,
    required this.efficiency,
    required this.sessionsToday,
    required this.improvementTrend,
  });
}

enum BreathType {
  inhale,
  exhale,
  pause,
}

enum BreathingPattern {
  normal,
  shallow,
  deep,
  rapid,
  slow,
  interrupted,
  unknown,
}

enum BreathingInsightType {
  rate,
  rhythm,
  technique,
  efficiency,
  pattern,
}

enum InsightSeverity {
  info,
  warning,
  critical,
}