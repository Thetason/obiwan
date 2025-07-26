import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../core/performance/performance_manager.dart';

/// Comprehensive audio preprocessing filters for vocal training applications
class AdvancedAudioFilters with PerformanceMixin {
  static final AdvancedAudioFilters _instance = AdvancedAudioFilters._internal();
  factory AdvancedAudioFilters() => _instance;
  AdvancedAudioFilters._internal();
  
  // Filter coefficients cache
  final Map<String, List<double>> _filterCache = {};
  
  // Reusable buffers for processing
  Float32List? _tempBuffer1;
  Float32List? _tempBuffer2;
  
  /// Initialize the filter system
  void initialize() {
    // Pre-compute common filter coefficients
    _precomputeFilters();
  }
  
  void _precomputeFilters() {
    // Pre-compute Butterworth filters for common frequencies
    final commonCutoffs = [80.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0];
    
    for (final cutoff in commonCutoffs) {
      _filterCache['lowpass_${cutoff.round()}'] = _designButterworthLowpass(cutoff, 44100, 2);
      _filterCache['highpass_${cutoff.round()}'] = _designButterworthHighpass(cutoff, 44100, 2);
    }
  }
  
  /// Apply high-pass filter to remove low-frequency noise and rumble
  Float32List applyHighPassFilter(
    Float32List input, {
    double cutoffFrequency = 80.0,
    int sampleRate = 44100,
    int order = 2,
    bool inPlace = false,
  }) {
    return measureOperation('highpass_filter', () {
      final filterKey = 'highpass_${cutoffFrequency.round()}';
      List<double> coefficients;
      
      if (_filterCache.containsKey(filterKey)) {
        coefficients = _filterCache[filterKey]!;
      } else {
        coefficients = _designButterworthHighpass(cutoffFrequency, sampleRate, order);
        _filterCache[filterKey] = coefficients;
      }
      
      return _applyIIRFilter(input, coefficients, inPlace: inPlace);
    });
  }
  
  /// Apply low-pass filter to remove high-frequency noise
  Float32List applyLowPassFilter(
    Float32List input, {
    double cutoffFrequency = 8000.0,
    int sampleRate = 44100,
    int order = 2,
    bool inPlace = false,
  }) {
    return measureOperation('lowpass_filter', () {
      final filterKey = 'lowpass_${cutoffFrequency.round()}';
      List<double> coefficients;
      
      if (_filterCache.containsKey(filterKey)) {
        coefficients = _filterCache[filterKey]!;
      } else {
        coefficients = _designButterworthLowpass(cutoffFrequency, sampleRate, order);
        _filterCache[filterKey] = coefficients;
      }
      
      return _applyIIRFilter(input, coefficients, inPlace: inPlace);
    });
  }
  
  /// Apply band-pass filter for vocal frequency range
  Float32List applyBandPassFilter(
    Float32List input, {
    double lowCutoff = 80.0,
    double highCutoff = 8000.0,
    int sampleRate = 44100,
    int order = 2,
    bool inPlace = false,
  }) {
    return measureOperation('bandpass_filter', () {
      // Apply high-pass then low-pass for band-pass effect
      final highpassed = applyHighPassFilter(
        input,
        cutoffFrequency: lowCutoff,
        sampleRate: sampleRate,
        order: order,
        inPlace: inPlace,
      );
      
      return applyLowPassFilter(
        highpassed,
        cutoffFrequency: highCutoff,
        sampleRate: sampleRate,
        order: order,
        inPlace: true, // Can modify in-place since we own the buffer
      );
    });
  }
  
  /// Apply notch filter to remove specific frequency (e.g., 50/60Hz hum)
  Float32List applyNotchFilter(
    Float32List input, {
    double notchFrequency = 60.0,
    double bandwidth = 2.0,
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('notch_filter', () {
      final coefficients = _designNotchFilter(notchFrequency, bandwidth, sampleRate);
      return _applyIIRFilter(input, coefficients, inPlace: inPlace);
    });
  }
  
  /// Apply dynamic range compression
  Float32List applyCompression(
    Float32List input, {
    double threshold = 0.7,
    double ratio = 4.0,
    double attack = 0.003, // 3ms
    double release = 0.1, // 100ms
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('compression', () {
      final output = inPlace ? input : Float32List.fromList(input);
      
      double envelope = 0.0;
      final attackCoeff = math.exp(-1.0 / (attack * sampleRate));
      final releaseCoeff = math.exp(-1.0 / (release * sampleRate));
      
      for (int i = 0; i < output.length; i++) {
        final sample = output[i].abs();
        
        // Envelope follower
        if (sample > envelope) {
          envelope = sample + (envelope - sample) * attackCoeff;
        } else {
          envelope = sample + (envelope - sample) * releaseCoeff;
        }
        
        // Apply compression
        if (envelope > threshold) {
          final excess = envelope - threshold;
          final compressedExcess = excess / ratio;
          final gainReduction = (threshold + compressedExcess) / envelope;
          output[i] *= gainReduction;
        }
      }
      
      return output;
    });
  }
  
  /// Apply noise gate to reduce background noise
  Float32List applyNoiseGate(
    Float32List input, {
    double threshold = 0.01,
    double ratio = 10.0,
    double attack = 0.001, // 1ms
    double release = 0.05, // 50ms
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('noise_gate', () {
      final output = inPlace ? input : Float32List.fromList(input);
      
      double envelope = 0.0;
      final attackCoeff = math.exp(-1.0 / (attack * sampleRate));
      final releaseCoeff = math.exp(-1.0 / (release * sampleRate));
      
      for (int i = 0; i < output.length; i++) {
        final sample = output[i].abs();
        
        // Envelope follower
        if (sample > envelope) {
          envelope = sample + (envelope - sample) * attackCoeff;
        } else {
          envelope = sample + (envelope - sample) * releaseCoeff;
        }
        
        // Apply gating
        if (envelope < threshold) {
          final gateReduction = math.pow(envelope / threshold, 1.0 / ratio);
          output[i] *= gateReduction.toDouble();
        }
      }
      
      return output;
    });
  }
  
  /// Apply de-esser to reduce sibilance
  Float32List applyDeEsser(
    Float32List input, {
    double frequency = 6000.0,
    double threshold = 0.5,
    double ratio = 3.0,
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('de_esser', () {
      // First, extract high-frequency content
      final highFreq = applyHighPassFilter(
        input,
        cutoffFrequency: frequency,
        sampleRate: sampleRate,
      );
      
      // Apply compression to high frequencies
      final compressedHigh = applyCompression(
        highFreq,
        threshold: threshold,
        ratio: ratio,
        attack: 0.001,
        release: 0.01,
        sampleRate: sampleRate,
        inPlace: true,
      );
      
      // Apply low-pass to get low frequencies
      final lowFreq = applyLowPassFilter(
        input,
        cutoffFrequency: frequency,
        sampleRate: sampleRate,
      );
      
      // Combine processed high frequencies with low frequencies
      final output = inPlace ? input : Float32List(input.length);
      for (int i = 0; i < output.length; i++) {
        output[i] = lowFreq[i] + compressedHigh[i];
      }
      
      return output;
    });
  }
  
  /// Apply parametric EQ
  Float32List applyParametricEQ(
    Float32List input, {
    double frequency = 1000.0,
    double gain = 0.0, // dB
    double q = 1.0,
    EQType type = EQType.bell,
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('parametric_eq', () {
      final coefficients = _designParametricEQ(frequency, gain, q, type, sampleRate);
      return _applyIIRFilter(input, coefficients, inPlace: inPlace);
    });
  }
  
  /// Apply multi-band EQ with multiple bands
  Float32List applyMultiBandEQ(
    Float32List input, {
    required List<EQBand> bands,
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('multiband_eq', () {
      var output = inPlace ? input : Float32List.fromList(input);
      
      for (final band in bands) {
        output = applyParametricEQ(
          output,
          frequency: band.frequency,
          gain: band.gain,
          q: band.q,
          type: band.type,
          sampleRate: sampleRate,
          inPlace: true,
        );
      }
      
      return output;
    });
  }
  
  /// Apply adaptive noise reduction
  Float32List applyAdaptiveNoiseReduction(
    Float32List input, {
    double noiseFloor = 0.001,
    double adaptationRate = 0.1,
    int frameSize = 1024,
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('adaptive_noise_reduction', () {
      final output = inPlace ? input : Float32List.fromList(input);
      
      // Simple spectral subtraction approach
      for (int frameStart = 0; frameStart < output.length; frameStart += frameSize) {
        final frameEnd = math.min(frameStart + frameSize, output.length);
        final frameLength = frameEnd - frameStart;
        
        if (frameLength < frameSize ~/ 2) break;
        
        // Calculate frame energy
        double frameEnergy = 0.0;
        for (int i = frameStart; i < frameEnd; i++) {
          frameEnergy += output[i] * output[i];
        }
        frameEnergy /= frameLength;
        
        // Estimate noise level
        double noiseEstimate = noiseFloor + adaptationRate * (frameEnergy - noiseFloor);
        
        // Apply noise reduction
        if (frameEnergy > noiseEstimate * 2) {
          final gainFactor = math.sqrt(math.max(0.1, 
              (frameEnergy - noiseEstimate) / frameEnergy));
          
          for (int i = frameStart; i < frameEnd; i++) {
            output[i] *= gainFactor;
          }
        } else {
          // Strong noise reduction for quiet frames
          for (int i = frameStart; i < frameEnd; i++) {
            output[i] *= 0.1;
          }
        }
      }
      
      return output;
    });
  }
  
  /// Apply automatic gain control (AGC)
  Float32List applyAGC(
    Float32List input, {
    double targetLevel = 0.7,
    double maxGain = 10.0,
    double attackTime = 0.01,
    double releaseTime = 0.5,
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('agc', () {
      final output = inPlace ? input : Float32List.fromList(input);
      
      double currentGain = 1.0;
      double envelope = 0.0;
      
      final attackCoeff = math.exp(-1.0 / (attackTime * sampleRate));
      final releaseCoeff = math.exp(-1.0 / (releaseTime * sampleRate));
      
      for (int i = 0; i < output.length; i++) {
        final sample = output[i].abs();
        
        // Envelope follower
        if (sample > envelope) {
          envelope = sample + (envelope - sample) * attackCoeff;
        } else {
          envelope = sample + (envelope - sample) * releaseCoeff;
        }
        
        // Calculate required gain
        final targetGain = envelope > 0 ? targetLevel / envelope : maxGain;
        final clampedGain = targetGain.clamp(1.0 / maxGain, maxGain);
        
        // Smooth gain changes
        if (clampedGain < currentGain) {
          currentGain += (clampedGain - currentGain) * (1.0 - attackCoeff);
        } else {
          currentGain += (clampedGain - currentGain) * (1.0 - releaseCoeff);
        }
        
        output[i] *= currentGain;
      }
      
      return output;
    });
  }
  
  /// Apply voice enhancement filter optimized for human voice
  Float32List applyVoiceEnhancement(
    Float32List input, {
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('voice_enhancement', () {
      // Multi-stage voice enhancement
      
      // 1. Remove low-frequency rumble
      var output = applyHighPassFilter(
        input,
        cutoffFrequency: 80.0,
        sampleRate: sampleRate,
        inPlace: inPlace,
      );
      
      // 2. Gentle boost in voice fundamentals (100-300 Hz)
      output = applyParametricEQ(
        output,
        frequency: 200.0,
        gain: 2.0,
        q: 1.5,
        type: EQType.bell,
        sampleRate: sampleRate,
        inPlace: true,
      );
      
      // 3. Boost presence frequencies (2-4 kHz)
      output = applyParametricEQ(
        output,
        frequency: 3000.0,
        gain: 3.0,
        q: 2.0,
        type: EQType.bell,
        sampleRate: sampleRate,
        inPlace: true,
      );
      
      // 4. Gentle de-essing
      output = applyDeEsser(
        output,
        frequency: 6000.0,
        threshold: 0.6,
        ratio: 2.5,
        sampleRate: sampleRate,
        inPlace: true,
      );
      
      // 5. Gentle compression
      output = applyCompression(
        output,
        threshold: 0.7,
        ratio: 3.0,
        attack: 0.005,
        release: 0.1,
        sampleRate: sampleRate,
        inPlace: true,
      );
      
      // 6. Remove excessive high frequencies
      output = applyLowPassFilter(
        output,
        cutoffFrequency: 12000.0,
        sampleRate: sampleRate,
        inPlace: true,
      );
      
      return output;
    });
  }
  
  /// Apply real-time processing chain for live vocal coaching
  Float32List applyRealTimeProcessing(
    Float32List input, {
    int sampleRate = 44100,
    bool inPlace = true, // Usually true for real-time processing
  }) {
    return measureOperation('realtime_processing', () {
      // Optimized processing chain for minimal latency
      
      var output = input;
      
      // 1. Quick noise gate
      output = applyNoiseGate(
        output,
        threshold: 0.005,
        attack: 0.001,
        release: 0.02,
        sampleRate: sampleRate,
        inPlace: inPlace,
      );
      
      // 2. High-pass filter
      output = applyHighPassFilter(
        output,
        cutoffFrequency: 80.0,
        sampleRate: sampleRate,
        order: 1, // Lower order for less latency
        inPlace: true,
      );
      
      // 3. Light compression
      output = applyCompression(
        output,
        threshold: 0.8,
        ratio: 2.0,
        attack: 0.002,
        release: 0.05,
        sampleRate: sampleRate,
        inPlace: true,
      );
      
      return output;
    });
  }
  
  // Private helper methods for filter design
  
  List<double> _designButterworthLowpass(double cutoff, int sampleRate, int order) {
    // Simplified second-order Butterworth lowpass
    final nyquist = sampleRate / 2.0;
    final normalizedCutoff = cutoff / nyquist;
    final c = 1.0 / math.tan(math.pi * normalizedCutoff);
    final c2 = c * c;
    final c2Plus1 = c2 + 1.0;
    final sqrt2c = math.sqrt(2.0) * c;
    
    final a0 = c2Plus1 + sqrt2c;
    final a1 = 2.0 * (1.0 - c2) / a0;
    final a2 = (c2Plus1 - sqrt2c) / a0;
    final b0 = 1.0 / a0;
    final b1 = 2.0 * b0;
    final b2 = b0;
    
    return [b0, b1, b2, a1, a2];
  }
  
  List<double> _designButterworthHighpass(double cutoff, int sampleRate, int order) {
    // Simplified second-order Butterworth highpass
    final nyquist = sampleRate / 2.0;
    final normalizedCutoff = cutoff / nyquist;
    final c = math.tan(math.pi * normalizedCutoff);
    final c2 = c * c;
    final c2Plus1 = c2 + 1.0;
    final sqrt2c = math.sqrt(2.0) * c;
    
    final a0 = c2Plus1 + sqrt2c;
    final a1 = 2.0 * (c2 - 1.0) / a0;
    final a2 = (c2Plus1 - sqrt2c) / a0;
    final b0 = 1.0 / a0;
    final b1 = -2.0 * b0;
    final b2 = b0;
    
    return [b0, b1, b2, a1, a2];
  }
  
  List<double> _designNotchFilter(double frequency, double bandwidth, int sampleRate) {
    final nyquist = sampleRate / 2.0;
    final normalizedFreq = frequency / nyquist;
    final normalizedBW = bandwidth / nyquist;
    
    final r = 1.0 - 3.0 * normalizedBW;
    final cosFreq = math.cos(2.0 * math.pi * normalizedFreq);
    
    final b0 = 1.0;
    final b1 = -2.0 * cosFreq;
    final b2 = 1.0;
    final a1 = -2.0 * r * cosFreq;
    final a2 = r * r;
    
    return [b0, b1, b2, a1, a2];
  }
  
  List<double> _designParametricEQ(
    double frequency,
    double gain,
    double q,
    EQType type,
    int sampleRate,
  ) {
    final nyquist = sampleRate / 2.0;
    final omega = 2.0 * math.pi * frequency / sampleRate;
    final sinOmega = math.sin(omega);
    final cosOmega = math.cos(omega);
    final alpha = sinOmega / (2.0 * q);
    final a = math.pow(10.0, gain / 40.0);
    
    double b0, b1, b2, a0, a1, a2;
    
    switch (type) {
      case EQType.bell:
        b0 = 1.0 + alpha * a;
        b1 = -2.0 * cosOmega;
        b2 = 1.0 - alpha * a;
        a0 = 1.0 + alpha / a;
        a1 = -2.0 * cosOmega;
        a2 = 1.0 - alpha / a;
        break;
        
      case EQType.highShelf:
        final s = 1.0;
        final beta = math.sqrt(a) / q;
        
        b0 = a * ((a + 1.0) + (a - 1.0) * cosOmega + beta * sinOmega);
        b1 = -2.0 * a * ((a - 1.0) + (a + 1.0) * cosOmega);
        b2 = a * ((a + 1.0) + (a - 1.0) * cosOmega - beta * sinOmega);
        a0 = (a + 1.0) - (a - 1.0) * cosOmega + beta * sinOmega;
        a1 = 2.0 * ((a - 1.0) - (a + 1.0) * cosOmega);
        a2 = (a + 1.0) - (a - 1.0) * cosOmega - beta * sinOmega;
        break;
        
      case EQType.lowShelf:
        final s = 1.0;
        final beta = math.sqrt(a) / q;
        
        b0 = a * ((a + 1.0) - (a - 1.0) * cosOmega + beta * sinOmega);
        b1 = 2.0 * a * ((a - 1.0) - (a + 1.0) * cosOmega);
        b2 = a * ((a + 1.0) - (a - 1.0) * cosOmega - beta * sinOmega);
        a0 = (a + 1.0) + (a - 1.0) * cosOmega + beta * sinOmega;
        a1 = -2.0 * ((a - 1.0) + (a + 1.0) * cosOmega);
        a2 = (a + 1.0) + (a - 1.0) * cosOmega - beta * sinOmega;
        break;
    }
    
    // Normalize by a0
    return [b0/a0, b1/a0, b2/a0, a1/a0, a2/a0];
  }
  
  Float32List _applyIIRFilter(
    Float32List input,
    List<double> coefficients, {
    bool inPlace = false,
  }) {
    final output = inPlace ? input : Float32List(input.length);
    
    if (coefficients.length < 5) {
      throw ArgumentError('IIR filter requires at least 5 coefficients');
    }
    
    final b0 = coefficients[0], b1 = coefficients[1], b2 = coefficients[2];
    final a1 = coefficients[3], a2 = coefficients[4];
    
    double x1 = 0.0, x2 = 0.0;
    double y1 = 0.0, y2 = 0.0;
    
    for (int i = 0; i < input.length; i++) {
      final x0 = input[i];
      final y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      
      output[i] = y0;
      
      // Update delay line
      x2 = x1; x1 = x0;
      y2 = y1; y1 = y0;
    }
    
    return output;
  }
  
  /// Get filter response at given frequency
  double getFilterResponse(List<double> coefficients, double frequency, int sampleRate) {
    if (coefficients.length < 5) return 1.0;
    
    final omega = 2.0 * math.pi * frequency / sampleRate;
    final z = math.exp(-omega * math.sqrt(-1).real);
    
    // Calculate H(z) = (b0 + b1*z^-1 + b2*z^-2) / (1 + a1*z^-1 + a2*z^-2)
    final b0 = coefficients[0], b1 = coefficients[1], b2 = coefficients[2];
    final a1 = coefficients[3], a2 = coefficients[4];
    
    final numeratorReal = b0 + b1 * math.cos(omega) + b2 * math.cos(2 * omega);
    final numeratorImag = -b1 * math.sin(omega) - b2 * math.sin(2 * omega);
    
    final denominatorReal = 1.0 + a1 * math.cos(omega) + a2 * math.cos(2 * omega);
    final denominatorImag = -a1 * math.sin(omega) - a2 * math.sin(2 * omega);
    
    final numeratorMag = math.sqrt(numeratorReal * numeratorReal + numeratorImag * numeratorImag);
    final denominatorMag = math.sqrt(denominatorReal * denominatorReal + denominatorImag * denominatorImag);
    
    return numeratorMag / denominatorMag;
  }
  
  /// Clear filter cache to free memory
  void clearCache() {
    _filterCache.clear();
    _tempBuffer1 = null;
    _tempBuffer2 = null;
  }
  
  /// Get filter statistics
  Map<String, dynamic> getFilterStatistics() {
    return {
      'cached_filters': _filterCache.length,
      'cache_keys': _filterCache.keys.toList(),
      'memory_usage_mb': _filterCache.length * 0.001, // Approximate
    };
  }
}

/// EQ band configuration
class EQBand {
  final double frequency;
  final double gain; // dB
  final double q;
  final EQType type;
  
  const EQBand({
    required this.frequency,
    required this.gain,
    this.q = 1.0,
    this.type = EQType.bell,
  });
}

/// EQ filter types
enum EQType {
  bell,
  highShelf,
  lowShelf,
}

/// Audio processing preset configurations
class AudioPresets {
  /// Vocal recording preset
  static List<EQBand> get vocalRecording => [
    const EQBand(frequency: 80, gain: -6, q: 0.7, type: EQType.lowShelf),  // Remove rumble
    const EQBand(frequency: 200, gain: 2, q: 1.5),                        // Warmth
    const EQBand(frequency: 1000, gain: -1, q: 2.0),                      // Reduce muddiness
    const EQBand(frequency: 3000, gain: 3, q: 2.0),                       // Presence
    const EQBand(frequency: 10000, gain: 2, q: 1.0, type: EQType.highShelf), // Air
  ];
  
  /// Live performance preset
  static List<EQBand> get livePerformance => [
    const EQBand(frequency: 100, gain: -3, q: 0.7, type: EQType.lowShelf),
    const EQBand(frequency: 500, gain: -2, q: 3.0), // Reduce feedback
    const EQBand(frequency: 2500, gain: 4, q: 1.5), // Cut through mix
    const EQBand(frequency: 8000, gain: 2, q: 1.0, type: EQType.highShelf),
  ];
  
  /// Vocal training preset
  static List<EQBand> get vocalTraining => [
    const EQBand(frequency: 80, gain: -9, q: 0.7, type: EQType.lowShelf),  // Heavy rumble removal
    const EQBand(frequency: 250, gain: 1, q: 1.0),                        // Slight warmth
    const EQBand(frequency: 2000, gain: 2, q: 1.5),                       // Clarity
    const EQBand(frequency: 4000, gain: 3, q: 2.0),                       // Articulation
  ];
}