import 'dart:math' as math;
import 'dart:typed_data';
import 'package:fftea/fftea.dart';

/// Real-time vocal effects processor with reverb, compression, and EQ
class VocalEffectsProcessor {
  static const int bufferSize = 2048;
  static const int sampleRate = 44100;
  
  // Effect processors
  late ReverbProcessor _reverb;
  late CompressorProcessor _compressor;
  late EqualizerProcessor _equalizer;
  late LimiterProcessor _limiter;
  
  // Effect chains
  final List<AudioEffect> _effectChain = [];
  
  // Processing state
  final List<double> _inputBuffer = [];
  final List<double> _outputBuffer = [];
  
  VocalEffectsProcessor() {
    _initializeEffects();
  }
  
  void _initializeEffects() {
    _reverb = ReverbProcessor(sampleRate: sampleRate);
    _compressor = CompressorProcessor(sampleRate: sampleRate);
    _equalizer = EqualizerProcessor(sampleRate: sampleRate);
    _limiter = LimiterProcessor(sampleRate: sampleRate);
    
    // Default effect chain
    _effectChain.addAll([
      _equalizer,
      _compressor,
      _reverb,
      _limiter,
    ]);
  }
  
  /// Process audio samples with current effects chain
  Future<Float32List> processAudio(Float32List inputSamples) async {
    Float32List processedSamples = Float32List.fromList(inputSamples);
    
    // Apply effects in order
    for (final effect in _effectChain) {
      if (effect.isEnabled) {
        processedSamples = await effect.process(processedSamples);
      }
    }
    
    return processedSamples;
  }
  
  /// Update reverb settings
  void updateReverbSettings(ReverbSettings settings) {
    _reverb.updateSettings(settings);
  }
  
  /// Update compressor settings
  void updateCompressorSettings(CompressorSettings settings) {
    _compressor.updateSettings(settings);
  }
  
  /// Update equalizer settings
  void updateEqualizerSettings(EqualizerSettings settings) {
    _equalizer.updateSettings(settings);
  }
  
  /// Enable/disable specific effects
  void setEffectEnabled(EffectType type, bool enabled) {
    switch (type) {
      case EffectType.reverb:
        _reverb.isEnabled = enabled;
        break;
      case EffectType.compressor:
        _compressor.isEnabled = enabled;
        break;
      case EffectType.equalizer:
        _equalizer.isEnabled = enabled;
        break;
      case EffectType.limiter:
        _limiter.isEnabled = enabled;
        break;
    }
  }
  
  /// Get current effect settings
  VocalEffectsSettings getCurrentSettings() {
    return VocalEffectsSettings(
      reverbSettings: _reverb.currentSettings,
      compressorSettings: _compressor.currentSettings,
      equalizerSettings: _equalizer.currentSettings,
      reverbEnabled: _reverb.isEnabled,
      compressorEnabled: _compressor.isEnabled,
      equalizerEnabled: _equalizer.isEnabled,
      limiterEnabled: _limiter.isEnabled,
    );
  }
  
  /// Apply preset configurations
  void applyPreset(VocalEffectPreset preset) {
    switch (preset) {
      case VocalEffectPreset.natural:
        _applyNaturalPreset();
        break;
      case VocalEffectPreset.warm:
        _applyWarmPreset();
        break;
      case VocalEffectPreset.bright:
        _applyBrightPreset();
        break;
      case VocalEffectPreset.radio:
        _applyRadioPreset();
        break;
      case VocalEffectPreset.studio:
        _applyStudioPreset();
        break;
    }
  }
  
  void _applyNaturalPreset() {
    updateEqualizerSettings(const EqualizerSettings(
      lowGain: 0.0,
      midGain: 1.0,
      highGain: 0.0,
    ));
    
    updateCompressorSettings(const CompressorSettings(
      threshold: -12.0,
      ratio: 2.0,
      attack: 5.0,
      release: 50.0,
      makeupGain: 2.0,
    ));
    
    updateReverbSettings(const ReverbSettings(
      roomSize: 0.3,
      damping: 0.5,
      wetLevel: 0.1,
      dryLevel: 0.9,
      width: 1.0,
    ));
    
    setEffectEnabled(EffectType.equalizer, true);
    setEffectEnabled(EffectType.compressor, true);
    setEffectEnabled(EffectType.reverb, true);
    setEffectEnabled(EffectType.limiter, true);
  }
  
  void _applyWarmPreset() {
    updateEqualizerSettings(const EqualizerSettings(
      lowGain: 2.0,
      midGain: 1.5,
      highGain: -1.0,
    ));
    
    updateCompressorSettings(const CompressorSettings(
      threshold: -10.0,
      ratio: 3.0,
      attack: 10.0,
      release: 100.0,
      makeupGain: 3.0,
    ));
    
    updateReverbSettings(const ReverbSettings(
      roomSize: 0.5,
      damping: 0.7,
      wetLevel: 0.15,
      dryLevel: 0.85,
      width: 0.8,
    ));
    
    setEffectEnabled(EffectType.equalizer, true);
    setEffectEnabled(EffectType.compressor, true);
    setEffectEnabled(EffectType.reverb, true);
    setEffectEnabled(EffectType.limiter, true);
  }
  
  void _applyBrightPreset() {
    updateEqualizerSettings(const EqualizerSettings(
      lowGain: -1.0,
      midGain: 1.0,
      highGain: 3.0,
    ));
    
    updateCompressorSettings(const CompressorSettings(
      threshold: -8.0,
      ratio: 4.0,
      attack: 2.0,
      release: 30.0,
      makeupGain: 4.0,
    ));
    
    updateReverbSettings(const ReverbSettings(
      roomSize: 0.2,
      damping: 0.3,
      wetLevel: 0.05,
      dryLevel: 0.95,
      width: 1.0,
    ));
    
    setEffectEnabled(EffectType.equalizer, true);
    setEffectEnabled(EffectType.compressor, true);
    setEffectEnabled(EffectType.reverb, true);
    setEffectEnabled(EffectType.limiter, true);
  }
  
  void _applyRadioPreset() {
    updateEqualizerSettings(const EqualizerSettings(
      lowGain: -3.0,
      midGain: 4.0,
      highGain: 2.0,
    ));
    
    updateCompressorSettings(const CompressorSettings(
      threshold: -6.0,
      ratio: 6.0,
      attack: 1.0,
      release: 20.0,
      makeupGain: 6.0,
    ));
    
    updateReverbSettings(const ReverbSettings(
      roomSize: 0.1,
      damping: 0.8,
      wetLevel: 0.02,
      dryLevel: 0.98,
      width: 0.5,
    ));
    
    setEffectEnabled(EffectType.equalizer, true);
    setEffectEnabled(EffectType.compressor, true);
    setEffectEnabled(EffectType.reverb, true);
    setEffectEnabled(EffectType.limiter, true);
  }
  
  void _applyStudioPreset() {
    updateEqualizerSettings(const EqualizerSettings(
      lowGain: 1.0,
      midGain: 2.0,
      highGain: 1.5,
    ));
    
    updateCompressorSettings(const CompressorSettings(
      threshold: -15.0,
      ratio: 3.5,
      attack: 3.0,
      release: 75.0,
      makeupGain: 4.0,
    ));
    
    updateReverbSettings(const ReverbSettings(
      roomSize: 0.4,
      damping: 0.4,
      wetLevel: 0.12,
      dryLevel: 0.88,
      width: 0.9,
    ));
    
    setEffectEnabled(EffectType.equalizer, true);
    setEffectEnabled(EffectType.compressor, true);
    setEffectEnabled(EffectType.reverb, true);
    setEffectEnabled(EffectType.limiter, true);
  }
}

/// Base class for audio effects
abstract class AudioEffect {
  bool isEnabled = true;
  
  Future<Float32List> process(Float32List input);
}

/// Reverb processor using Freeverb algorithm
class ReverbProcessor extends AudioEffect {
  final int sampleRate;
  ReverbSettings currentSettings = const ReverbSettings();
  
  // Freeverb parameters
  static const List<int> combDelays = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617];
  static const List<int> allpassDelays = [556, 441, 341, 225];
  
  // Delay lines
  final List<List<double>> combDelayLines = [];
  final List<List<double>> allpassDelayLines = [];
  final List<int> combIndices = List.filled(8, 0);
  final List<int> allpassIndices = List.filled(4, 0);
  final List<double> combFeedback = List.filled(8, 0);
  final List<double> combFilterStates = List.filled(8, 0);
  
  ReverbProcessor({required this.sampleRate}) {
    _initializeDelayLines();
  }
  
  void _initializeDelayLines() {
    // Initialize comb delay lines
    for (int i = 0; i < combDelays.length; i++) {
      final adjustedDelay = (combDelays[i] * sampleRate / 44100).round();
      combDelayLines.add(List.filled(adjustedDelay, 0.0));
      combFeedback[i] = 0.84;
    }
    
    // Initialize allpass delay lines
    for (int i = 0; i < allpassDelays.length; i++) {
      final adjustedDelay = (allpassDelays[i] * sampleRate / 44100).round();
      allpassDelayLines.add(List.filled(adjustedDelay, 0.0));
    }
  }
  
  void updateSettings(ReverbSettings settings) {
    currentSettings = settings;
    
    // Update feedback based on room size
    for (int i = 0; i < combFeedback.length; i++) {
      combFeedback[i] = 0.7 + (settings.roomSize * 0.2);
    }
  }
  
  @override
  Future<Float32List> process(Float32List input) async {
    final output = Float32List(input.length);
    
    for (int i = 0; i < input.length; i++) {
      double reverbOutput = 0.0;
      
      // Process through comb filters
      for (int c = 0; c < combDelayLines.length; c++) {
        final delayLine = combDelayLines[c];
        final delayOutput = delayLine[combIndices[c]];
        
        // Lowpass filter for damping
        combFilterStates[c] = delayOutput * (1 - currentSettings.damping) + 
                             combFilterStates[c] * currentSettings.damping;
        
        // Feedback
        delayLine[combIndices[c]] = input[i] + combFilterStates[c] * combFeedback[c];
        
        combIndices[c] = (combIndices[c] + 1) % delayLine.length;
        reverbOutput += delayOutput;
      }
      
      // Process through allpass filters
      for (int a = 0; a < allpassDelayLines.length; a++) {
        final delayLine = allpassDelayLines[a];
        final delayOutput = delayLine[allpassIndices[a]];
        final allpassInput = reverbOutput;
        
        delayLine[allpassIndices[a]] = allpassInput + delayOutput * 0.5;
        reverbOutput = delayOutput - allpassInput * 0.5;
        
        allpassIndices[a] = (allpassIndices[a] + 1) % delayLine.length;
      }
      
      // Mix dry and wet signals
      output[i] = input[i] * currentSettings.dryLevel + 
                  reverbOutput * currentSettings.wetLevel * currentSettings.width;
    }
    
    return output;
  }
}

/// Dynamic range compressor
class CompressorProcessor extends AudioEffect {
  final int sampleRate;
  CompressorSettings currentSettings = const CompressorSettings();
  
  // Compressor state
  double _envelope = 0.0;
  double _attackCoeff = 0.0;
  double _releaseCoeff = 0.0;
  
  CompressorProcessor({required this.sampleRate}) {
    _updateCoefficients();
  }
  
  void updateSettings(CompressorSettings settings) {
    currentSettings = settings;
    _updateCoefficients();
  }
  
  void _updateCoefficients() {
    _attackCoeff = math.exp(-1.0 / (currentSettings.attack * 0.001 * sampleRate));
    _releaseCoeff = math.exp(-1.0 / (currentSettings.release * 0.001 * sampleRate));
  }
  
  @override
  Future<Float32List> process(Float32List input) async {
    final output = Float32List(input.length);
    
    for (int i = 0; i < input.length; i++) {
      final inputLevel = input[i].abs();
      
      // Envelope follower
      final targetEnv = inputLevel;
      if (targetEnv > _envelope) {
        _envelope = targetEnv + (_envelope - targetEnv) * _attackCoeff;
      } else {
        _envelope = targetEnv + (_envelope - targetEnv) * _releaseCoeff;
      }
      
      // Convert to dB
      final envelopeDb = 20 * math.log(_envelope + 1e-10) / math.ln10;
      
      // Calculate gain reduction
      double gainReduction = 0.0;
      if (envelopeDb > currentSettings.threshold) {
        final overThreshold = envelopeDb - currentSettings.threshold;
        gainReduction = overThreshold * (1.0 - 1.0 / currentSettings.ratio);
      }
      
      // Convert back to linear and apply
      final compressionGain = math.pow(10, -gainReduction / 20) * 
                             math.pow(10, currentSettings.makeupGain / 20);
      
      output[i] = input[i] * compressionGain;
    }
    
    return output;
  }
}

/// 3-band equalizer
class EqualizerProcessor extends AudioEffect {
  final int sampleRate;
  EqualizerSettings currentSettings = const EqualizerSettings();
  
  // Biquad filter coefficients and states
  final List<BiquadFilter> filters = [];
  
  EqualizerProcessor({required this.sampleRate}) {
    _initializeFilters();
  }
  
  void _initializeFilters() {
    // Low shelf (80 Hz)
    filters.add(BiquadFilter.lowShelf(sampleRate, 80, 0.7, 0));
    
    // Mid peaking (1000 Hz)
    filters.add(BiquadFilter.peaking(sampleRate, 1000, 1.0, 0));
    
    // High shelf (8000 Hz)
    filters.add(BiquadFilter.highShelf(sampleRate, 8000, 0.7, 0));
  }
  
  void updateSettings(EqualizerSettings settings) {
    currentSettings = settings;
    
    // Update filter gains
    filters[0] = BiquadFilter.lowShelf(sampleRate, 80, 0.7, settings.lowGain);
    filters[1] = BiquadFilter.peaking(sampleRate, 1000, 1.0, settings.midGain);
    filters[2] = BiquadFilter.highShelf(sampleRate, 8000, 0.7, settings.highGain);
  }
  
  @override
  Future<Float32List> process(Float32List input) async {
    Float32List output = Float32List.fromList(input);
    
    // Apply each filter in series
    for (final filter in filters) {
      output = filter.process(output);
    }
    
    return output;
  }
}

/// Limiter to prevent clipping
class LimiterProcessor extends AudioEffect {
  final int sampleRate;
  static const double threshold = 0.95;
  static const double attack = 0.001; // 1ms
  static const double release = 0.01;  // 10ms
  
  double _envelope = 0.0;
  late double _attackCoeff;
  late double _releaseCoeff;
  
  LimiterProcessor({required this.sampleRate}) {
    _attackCoeff = math.exp(-1.0 / (attack * sampleRate));
    _releaseCoeff = math.exp(-1.0 / (release * sampleRate));
  }
  
  @override
  Future<Float32List> process(Float32List input) async {
    final output = Float32List(input.length);
    
    for (int i = 0; i < input.length; i++) {
      final inputLevel = input[i].abs();
      
      // Envelope follower
      final targetEnv = inputLevel;
      if (targetEnv > _envelope) {
        _envelope = targetEnv + (_envelope - targetEnv) * _attackCoeff;
      } else {
        _envelope = targetEnv + (_envelope - targetEnv) * _releaseCoeff;
      }
      
      // Calculate limiting gain
      double gain = 1.0;
      if (_envelope > threshold) {
        gain = threshold / _envelope;
      }
      
      output[i] = input[i] * gain;
    }
    
    return output;
  }
}

/// Biquad filter implementation
class BiquadFilter {
  final double b0, b1, b2, a1, a2;
  double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  
  BiquadFilter(this.b0, this.b1, this.b2, this.a1, this.a2);
  
  factory BiquadFilter.lowShelf(int sampleRate, double frequency, double q, double gainDb) {
    final A = math.pow(10, gainDb / 40);
    final w = 2 * math.pi * frequency / sampleRate;
    final sinW = math.sin(w);
    final cosW = math.cos(w);
    final alpha = sinW / (2 * q);
    final beta = math.sqrt(A) / q;
    
    final b0 = A * ((A + 1) - (A - 1) * cosW + beta * sinW);
    final b1 = 2 * A * ((A - 1) - (A + 1) * cosW);
    final b2 = A * ((A + 1) - (A - 1) * cosW - beta * sinW);
    final a0 = (A + 1) + (A - 1) * cosW + beta * sinW;
    final a1 = -2 * ((A - 1) + (A + 1) * cosW);
    final a2 = (A + 1) + (A - 1) * cosW - beta * sinW;
    
    return BiquadFilter(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
  }
  
  factory BiquadFilter.highShelf(int sampleRate, double frequency, double q, double gainDb) {
    final A = math.pow(10, gainDb / 40);
    final w = 2 * math.pi * frequency / sampleRate;
    final sinW = math.sin(w);
    final cosW = math.cos(w);
    final alpha = sinW / (2 * q);
    final beta = math.sqrt(A) / q;
    
    final b0 = A * ((A + 1) + (A - 1) * cosW + beta * sinW);
    final b1 = -2 * A * ((A - 1) + (A + 1) * cosW);
    final b2 = A * ((A + 1) + (A - 1) * cosW - beta * sinW);
    final a0 = (A + 1) - (A - 1) * cosW + beta * sinW;
    final a1 = 2 * ((A - 1) - (A + 1) * cosW);
    final a2 = (A + 1) - (A - 1) * cosW - beta * sinW;
    
    return BiquadFilter(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
  }
  
  factory BiquadFilter.peaking(int sampleRate, double frequency, double q, double gainDb) {
    final A = math.pow(10, gainDb / 40);
    final w = 2 * math.pi * frequency / sampleRate;
    final sinW = math.sin(w);
    final cosW = math.cos(w);
    final alpha = sinW / (2 * q);
    
    final b0 = 1 + alpha * A;
    final b1 = -2 * cosW;
    final b2 = 1 - alpha * A;
    final a0 = 1 + alpha / A;
    final a1 = -2 * cosW;
    final a2 = 1 - alpha / A;
    
    return BiquadFilter(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
  }
  
  Float32List process(Float32List input) {
    final output = Float32List(input.length);
    
    for (int i = 0; i < input.length; i++) {
      final x0 = input[i];
      final y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      
      output[i] = y0;
      
      // Update delay line
      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
    }
    
    return output;
  }
}

// Data classes
class VocalEffectsSettings {
  final ReverbSettings reverbSettings;
  final CompressorSettings compressorSettings;
  final EqualizerSettings equalizerSettings;
  final bool reverbEnabled;
  final bool compressorEnabled;
  final bool equalizerEnabled;
  final bool limiterEnabled;
  
  const VocalEffectsSettings({
    required this.reverbSettings,
    required this.compressorSettings,
    required this.equalizerSettings,
    this.reverbEnabled = true,
    this.compressorEnabled = true,
    this.equalizerEnabled = true,
    this.limiterEnabled = true,
  });
}

class ReverbSettings {
  final double roomSize;    // 0.0 - 1.0
  final double damping;     // 0.0 - 1.0
  final double wetLevel;    // 0.0 - 1.0
  final double dryLevel;    // 0.0 - 1.0
  final double width;       // 0.0 - 1.0
  
  const ReverbSettings({
    this.roomSize = 0.5,
    this.damping = 0.5,
    this.wetLevel = 0.3,
    this.dryLevel = 0.7,
    this.width = 1.0,
  });
}

class CompressorSettings {
  final double threshold;   // dB (-60 to 0)
  final double ratio;       // 1.0 to 20.0
  final double attack;      // ms (0.1 to 100)
  final double release;     // ms (1 to 1000)
  final double makeupGain;  // dB (0 to 20)
  
  const CompressorSettings({
    this.threshold = -12.0,
    this.ratio = 4.0,
    this.attack = 5.0,
    this.release = 50.0,
    this.makeupGain = 0.0,
  });
}

class EqualizerSettings {
  final double lowGain;     // dB (-12 to 12)
  final double midGain;     // dB (-12 to 12)
  final double highGain;    // dB (-12 to 12)
  
  const EqualizerSettings({
    this.lowGain = 0.0,
    this.midGain = 0.0,
    this.highGain = 0.0,
  });
}

// Enums
enum EffectType {
  reverb,
  compressor,
  equalizer,
  limiter,
}

enum VocalEffectPreset {
  natural,
  warm,
  bright,
  radio,
  studio,
}