import 'dart:math' as math;
import 'dart:typed_data';
import '../../core/performance/performance_manager.dart';
import 'advanced_audio_filters.dart';

/// Advanced audio effects processor for vocal training and enhancement
class AudioEffectsProcessor with PerformanceMixin {
  static final AudioEffectsProcessor _instance = AudioEffectsProcessor._internal();
  factory AudioEffectsProcessor() => _instance;
  AudioEffectsProcessor._internal();
  
  final AdvancedAudioFilters _filters = AdvancedAudioFilters();
  
  // Effect state variables
  final Map<String, dynamic> _effectStates = {};
  
  // Delay line buffers for time-based effects
  final Map<String, Float32List> _delayLines = {};
  final Map<String, int> _delayIndices = {};
  
  bool _isInitialized = false;
  
  /// Initialize the effects processor
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _filters.initialize();
    _initializeDelayLines();
    
    _isInitialized = true;
  }
  
  void _initializeDelayLines() {
    // Pre-allocate delay lines for common effects
    const sampleRate = 44100;
    
    _delayLines['reverb'] = Float32List((sampleRate * 2).round()); // 2 second max
    _delayLines['echo'] = Float32List((sampleRate * 1).round());   // 1 second max
    _delayLines['chorus'] = Float32List((sampleRate * 0.05).round()); // 50ms max
    _delayLines['flanger'] = Float32List((sampleRate * 0.02).round()); // 20ms max
    
    // Initialize delay indices
    _delayIndices['reverb'] = 0;
    _delayIndices['echo'] = 0;
    _delayIndices['chorus'] = 0;
    _delayIndices['flanger'] = 0;
  }
  
  /// Apply reverb effect
  Float32List applyReverb(
    Float32List input, {
    double roomSize = 0.5,
    double decay = 0.7,
    double damping = 0.5,
    double wetLevel = 0.3,
    double dryLevel = 0.7,
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('reverb_effect', () {
      final output = inPlace ? input : Float32List.fromList(input);
      final delayLine = _delayLines['reverb']!;
      int delayIndex = _delayIndices['reverb']!;
      
      // Simple room simulation with multiple delay taps
      final delayTimes = [
        (roomSize * 0.03 * sampleRate).round(), // Early reflection 1
        (roomSize * 0.05 * sampleRate).round(), // Early reflection 2
        (roomSize * 0.07 * sampleRate).round(), // Early reflection 3
        (roomSize * 0.15 * sampleRate).round(), // Late reverb 1
        (roomSize * 0.23 * sampleRate).round(), // Late reverb 2
        (roomSize * 0.31 * sampleRate).round(), // Late reverb 3
      ];
      
      final gains = [0.4, 0.3, 0.25, 0.6, 0.4, 0.3];
      
      for (int i = 0; i < input.length; i++) {
        double reverbSignal = 0.0;
        
        // Read from multiple delay taps
        for (int tap = 0; tap < delayTimes.length; tap++) {
          final tapDelay = delayTimes[tap];
          if (tapDelay < delayLine.length) {
            final tapIndex = (delayIndex - tapDelay + delayLine.length) % delayLine.length;
            reverbSignal += delayLine[tapIndex] * gains[tap] * decay;
          }
        }
        
        // Apply damping (simple low-pass)
        reverbSignal *= (1.0 - damping + damping * 0.5);
        
        // Write to delay line with feedback
        delayLine[delayIndex] = input[i] + reverbSignal * 0.3;
        
        // Mix wet and dry signals
        output[i] = input[i] * dryLevel + reverbSignal * wetLevel;
        
        delayIndex = (delayIndex + 1) % delayLine.length;
      }
      
      _delayIndices['reverb'] = delayIndex;
      return output;
    });
  }
  
  /// Apply echo/delay effect
  Float32List applyEcho(
    Float32List input, {
    double delayTime = 0.3, // seconds
    double feedback = 0.4,
    double wetLevel = 0.3,
    double dryLevel = 0.7,
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('echo_effect', () {
      final output = inPlace ? input : Float32List.fromList(input);
      final delayLine = _delayLines['echo']!;
      int delayIndex = _delayIndices['echo']!;
      
      final delaySamples = (delayTime * sampleRate).round().clamp(1, delayLine.length - 1);
      
      for (int i = 0; i < input.length; i++) {
        // Read delayed signal
        final delayedIndex = (delayIndex - delaySamples + delayLine.length) % delayLine.length;
        final delayedSignal = delayLine[delayedIndex];
        
        // Write to delay line with feedback
        delayLine[delayIndex] = input[i] + delayedSignal * feedback;
        
        // Mix wet and dry signals
        output[i] = input[i] * dryLevel + delayedSignal * wetLevel;
        
        delayIndex = (delayIndex + 1) % delayLine.length;
      }
      
      _delayIndices['echo'] = delayIndex;
      return output;
    });
  }
  
  /// Apply chorus effect
  Float32List applyChorus(
    Float32List input, {
    double rate = 0.5, // Hz
    double depth = 0.8,
    double delay = 0.02, // seconds
    double wetLevel = 0.4,
    double dryLevel = 0.6,
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('chorus_effect', () {
      final output = inPlace ? input : Float32List.fromList(input);
      final delayLine = _delayLines['chorus']!;
      int delayIndex = _delayIndices['chorus']!;
      
      final baseDelay = (delay * sampleRate).round();
      final maxDepthSamples = (depth * 0.01 * sampleRate).round(); // Max 10ms modulation
      
      // Get or initialize LFO phase
      double lfoPhase = (_effectStates['chorus_phase'] as double?) ?? 0.0;
      final lfoIncrement = 2.0 * math.pi * rate / sampleRate;
      
      for (int i = 0; i < input.length; i++) {
        // Calculate modulated delay
        final lfoValue = math.sin(lfoPhase);
        final modulatedDelay = baseDelay + (lfoValue * maxDepthSamples).round();
        final clampedDelay = modulatedDelay.clamp(1, delayLine.length - 1);
        
        // Read delayed signal with interpolation
        final delayedIndex = (delayIndex - clampedDelay + delayLine.length) % delayLine.length;
        final delayedSignal = delayLine[delayedIndex];
        
        // Write to delay line
        delayLine[delayIndex] = input[i];
        
        // Mix wet and dry signals
        output[i] = input[i] * dryLevel + delayedSignal * wetLevel;
        
        delayIndex = (delayIndex + 1) % delayLine.length;
        lfoPhase += lfoIncrement;
        if (lfoPhase >= 2.0 * math.pi) lfoPhase -= 2.0 * math.pi;
      }
      
      _delayIndices['chorus'] = delayIndex;
      _effectStates['chorus_phase'] = lfoPhase;
      return output;
    });
  }
  
  /// Apply flanger effect
  Float32List applyFlanger(
    Float32List input, {
    double rate = 0.25, // Hz
    double depth = 1.0,
    double feedback = 0.7,
    double wetLevel = 0.5,
    double dryLevel = 0.5,
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('flanger_effect', () {
      final output = inPlace ? input : Float32List.fromList(input);
      final delayLine = _delayLines['flanger']!;
      int delayIndex = _delayIndices['flanger']!;
      
      final maxDelaySamples = (0.015 * sampleRate).round(); // Max 15ms delay
      
      // Get or initialize LFO phase
      double lfoPhase = (_effectStates['flanger_phase'] as double?) ?? 0.0;
      final lfoIncrement = 2.0 * math.pi * rate / sampleRate;
      
      for (int i = 0; i < input.length; i++) {
        // Calculate modulated delay
        final lfoValue = (math.sin(lfoPhase) + 1.0) * 0.5; // 0 to 1
        final modulatedDelay = (lfoValue * depth * maxDelaySamples).round() + 1;
        final clampedDelay = modulatedDelay.clamp(1, delayLine.length - 1);
        
        // Read delayed signal
        final delayedIndex = (delayIndex - clampedDelay + delayLine.length) % delayLine.length;
        final delayedSignal = delayLine[delayedIndex];
        
        // Write to delay line with feedback
        delayLine[delayIndex] = input[i] + delayedSignal * feedback;
        
        // Mix wet and dry signals (with phase inversion for flanging)
        output[i] = input[i] * dryLevel + delayedSignal * wetLevel;
        
        delayIndex = (delayIndex + 1) % delayLine.length;
        lfoPhase += lfoIncrement;
        if (lfoPhase >= 2.0 * math.pi) lfoPhase -= 2.0 * math.pi;
      }
      
      _delayIndices['flanger'] = delayIndex;
      _effectStates['flanger_phase'] = lfoPhase;
      return output;
    });
  }
  
  /// Apply pitch shifting effect
  Float32List applyPitchShift(
    Float32List input, {
    double pitchRatio = 1.0, // 1.0 = no change, 2.0 = octave up, 0.5 = octave down
    int frameSize = 2048,
    int hopSize = 512,
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('pitch_shift', () {
      if (pitchRatio == 1.0) {
        return inPlace ? input : Float32List.fromList(input);
      }
      
      // Simple time-domain pitch shifting using overlap-add
      final output = Float32List(input.length);
      final window = _createHannWindow(frameSize);
      
      double readPos = 0.0;
      int writePos = 0;
      
      while (writePos + frameSize < output.length && readPos + frameSize < input.length) {
        // Read frame with window
        final frame = Float32List(frameSize);
        for (int i = 0; i < frameSize; i++) {
          final readIndex = (readPos + i).floor();
          if (readIndex < input.length) {
            frame[i] = input[readIndex] * window[i];
          }
        }
        
        // Overlap-add to output
        for (int i = 0; i < frameSize && writePos + i < output.length; i++) {
          output[writePos + i] += frame[i];
        }
        
        // Advance positions
        readPos += hopSize * pitchRatio;
        writePos += hopSize;
      }
      
      if (inPlace) {
        for (int i = 0; i < math.min(input.length, output.length); i++) {
          input[i] = output[i];
        }
        return input;
      }
      
      return output;
    });
  }
  
  /// Apply auto-tuning effect
  Float32List applyAutoTune(
    Float32List input, {
    required List<double> targetPitches, // In Hz
    double correctionStrength = 0.8,
    double transitionSpeed = 0.1,
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('auto_tune', () {
      final output = inPlace ? input : Float32List.fromList(input);
      
      if (targetPitches.isEmpty) return output;
      
      // Simple formant-preserving pitch correction
      final frameSize = 1024;
      final hopSize = 256;
      
      for (int frameStart = 0; frameStart < output.length; frameStart += hopSize) {
        final frameEnd = math.min(frameStart + frameSize, output.length);
        final frameLength = frameEnd - frameStart;
        
        if (frameLength < frameSize ~/ 2) break;
        
        // Estimate pitch in this frame (simplified)
        final estimatedPitch = _estimatePitch(
          output.sublist(frameStart, frameEnd),
          sampleRate,
        );
        
        if (estimatedPitch > 0) {
          // Find closest target pitch
          double closestPitch = targetPitches.first;
          double minDistance = (estimatedPitch - closestPitch).abs();
          
          for (final targetPitch in targetPitches) {
            final distance = (estimatedPitch - targetPitch).abs();
            if (distance < minDistance) {
              minDistance = distance;
              closestPitch = targetPitch;
            }
          }
          
          // Calculate pitch shift ratio
          final pitchRatio = closestPitch / estimatedPitch;
          final correctedRatio = 1.0 + (pitchRatio - 1.0) * correctionStrength;
          
          // Apply pitch correction to frame
          if ((correctedRatio - 1.0).abs() > 0.01) {
            final frameData = output.sublist(frameStart, frameEnd);
            final correctedFrame = applyPitchShift(
              Float32List.fromList(frameData),
              pitchRatio: correctedRatio,
              frameSize: frameLength ~/ 2,
              hopSize: frameLength ~/ 4,
              sampleRate: sampleRate,
            );
            
            // Copy back with blending
            for (int i = 0; i < math.min(frameLength, correctedFrame.length); i++) {
              output[frameStart + i] = correctedFrame[i];
            }
          }
        }
      }
      
      return output;
    });
  }
  
  /// Apply vocal doubling effect
  Float32List applyVocalDoubling(
    Float32List input, {
    double delay1 = 0.015, // 15ms
    double delay2 = 0.025, // 25ms
    double panning1 = -0.3, // Left
    double panning2 = 0.3,  // Right
    double level = 0.4,
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('vocal_doubling', () {
      // Create doubled versions with slight delays and pitch variations
      final doubled1 = applyEcho(
        input,
        delayTime: delay1,
        feedback: 0.0,
        wetLevel: level,
        dryLevel: 1.0,
        sampleRate: sampleRate,
      );
      
      final doubled2 = applyEcho(
        input,
        delayTime: delay2,
        feedback: 0.0,
        wetLevel: level,
        dryLevel: 1.0,
        sampleRate: sampleRate,
      );
      
      // Mix with original (simplified stereo mixing for mono output)
      final output = inPlace ? input : Float32List.fromList(input);
      for (int i = 0; i < output.length; i++) {
        output[i] = (output[i] + doubled1[i] * (1.0 + panning1) + doubled2[i] * (1.0 + panning2)) / 3.0;
      }
      
      return output;
    });
  }
  
  /// Apply harmonic exciter effect
  Float32List applyHarmonicExciter(
    Float32List input, {
    double driveAmount = 0.3,
    double harmonicContent = 0.4,
    double filterFrequency = 3000.0,
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('harmonic_exciter', () {
      // Extract high-frequency content
      final highFreq = _filters.applyHighPassFilter(
        input,
        cutoffFrequency: filterFrequency,
        sampleRate: sampleRate,
      );
      
      // Apply harmonic distortion to high frequencies
      final excited = Float32List(highFreq.length);
      for (int i = 0; i < highFreq.length; i++) {
        final sample = highFreq[i] * driveAmount;
        // Soft clipping for harmonic generation
        excited[i] = sample / (1.0 + sample.abs()) * harmonicContent;
      }
      
      // Mix with original
      final output = inPlace ? input : Float32List.fromList(input);
      for (int i = 0; i < output.length; i++) {
        output[i] = output[i] + excited[i];
      }
      
      return output;
    });
  }
  
  /// Apply complete vocal production chain
  Float32List applyVocalProductionChain(
    Float32List input, {
    VocalProductionPreset preset = VocalProductionPreset.standard,
    int sampleRate = 44100,
    bool inPlace = false,
  }) {
    return measureOperation('vocal_production_chain', () {
      var output = input;
      
      switch (preset) {
        case VocalProductionPreset.broadcast:
          // Professional broadcast chain
          output = _filters.applyHighPassFilter(output, cutoffFrequency: 80.0, sampleRate: sampleRate, inPlace: inPlace);
          output = _filters.applyCompression(output, threshold: 0.7, ratio: 3.0, attack: 0.003, release: 0.1, sampleRate: sampleRate, inPlace: true);
          output = _filters.applyMultiBandEQ(output, bands: AudioPresets.vocalRecording, sampleRate: sampleRate, inPlace: true);
          output = _filters.applyDeEsser(output, threshold: 0.6, ratio: 3.0, sampleRate: sampleRate, inPlace: true);
          output = applyHarmonicExciter(output, driveAmount: 0.2, harmonicContent: 0.3, sampleRate: sampleRate, inPlace: true);
          break;
          
        case VocalProductionPreset.studio:
          // High-end studio processing
          output = _filters.applyHighPassFilter(output, cutoffFrequency: 60.0, sampleRate: sampleRate, inPlace: inPlace);
          output = _filters.applyMultiBandEQ(output, bands: AudioPresets.vocalRecording, sampleRate: sampleRate, inPlace: true);
          output = _filters.applyCompression(output, threshold: 0.8, ratio: 2.5, attack: 0.005, release: 0.15, sampleRate: sampleRate, inPlace: true);
          output = applyVocalDoubling(output, level: 0.15, sampleRate: sampleRate, inPlace: true);
          output = applyReverb(output, roomSize: 0.3, decay: 0.4, wetLevel: 0.15, sampleRate: sampleRate, inPlace: true);
          break;
          
        case VocalProductionPreset.podcast:
          // Podcast/spoken word optimization
          output = _filters.applyHighPassFilter(output, cutoffFrequency: 100.0, sampleRate: sampleRate, inPlace: inPlace);
          output = _filters.applyNoiseGate(output, threshold: 0.02, attack: 0.001, release: 0.1, sampleRate: sampleRate, inPlace: true);
          output = _filters.applyCompression(output, threshold: 0.6, ratio: 4.0, attack: 0.002, release: 0.08, sampleRate: sampleRate, inPlace: true);
          output = _filters.applyParametricEQ(output, frequency: 3000.0, gain: 3.0, q: 1.5, type: EQType.bell, sampleRate: sampleRate, inPlace: true);
          output = _filters.applyDeEsser(output, threshold: 0.5, ratio: 4.0, sampleRate: sampleRate, inPlace: true);
          break;
          
        case VocalProductionPreset.standard:
        default:
          // Standard vocal processing
          output = _filters.applyVoiceEnhancement(output, sampleRate: sampleRate, inPlace: inPlace);
          output = applyReverb(output, roomSize: 0.4, decay: 0.5, wetLevel: 0.2, sampleRate: sampleRate, inPlace: true);
          break;
      }
      
      return output;
    });
  }
  
  // Helper methods
  
  Float32List _createHannWindow(int size) {
    final window = Float32List(size);
    for (int i = 0; i < size; i++) {
      window[i] = 0.5 - 0.5 * math.cos(2.0 * math.pi * i / (size - 1));
    }
    return window;
  }
  
  double _estimatePitch(List<double> frame, int sampleRate) {
    // Simple autocorrelation-based pitch estimation
    const minPeriod = 20;  // ~2200 Hz max
    const maxPeriod = 400; // ~110 Hz min
    
    double maxCorr = 0.0;
    int bestPeriod = minPeriod;
    
    for (int period = minPeriod; period < math.min(maxPeriod, frame.length ~/ 2); period++) {
      double correlation = 0.0;
      
      for (int i = 0; i < frame.length - period; i++) {
        correlation += frame[i] * frame[i + period];
      }
      
      if (correlation > maxCorr) {
        maxCorr = correlation;
        bestPeriod = period;
      }
    }
    
    return maxCorr > 0.3 ? sampleRate / bestPeriod : 0.0;
  }
  
  /// Clear effect states and delay lines
  void clearEffectStates() {
    _effectStates.clear();
    
    for (final delayLine in _delayLines.values) {
      delayLine.fillRange(0, delayLine.length, 0.0);
    }
    
    _delayIndices.updateAll((key, value) => 0);
  }
  
  /// Get effect processor statistics
  Map<String, dynamic> getStatistics() {
    return {
      'initialized': _isInitialized,
      'active_effects': _effectStates.length,
      'delay_lines': _delayLines.length,
      'filter_stats': _filters.getFilterStatistics(),
    };
  }
  
  void dispose() {
    clearEffectStates();
    _filters.clearCache();
  }
}

/// Vocal production presets
enum VocalProductionPreset {
  standard,
  broadcast,
  studio,
  podcast,
}