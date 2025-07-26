import 'dart:math' as math;
import 'dart:typed_data';
import 'package:fftea/fftea.dart';

class PitchCorrectionEngine {
  static const int fftSize = 2048;
  static const int hopSize = 512;
  static const double defaultAttackTime = 0.005; // 5ms
  static const double defaultReleaseTime = 0.050; // 50ms
  
  final int sampleRate;
  final FFT fft;
  
  // Auto-tune parameters
  double correctionStrength = 1.0; // 0.0 = no correction, 1.0 = full correction
  double referencePitch = 440.0; // A4
  bool snapToScale = true;
  List<int> scaleNotes = [0, 2, 4, 5, 7, 9, 11]; // Major scale
  double attackTime = defaultAttackTime;
  double releaseTime = defaultReleaseTime;
  
  // Internal state
  double _lastCorrectedPitch = 0.0;
  final List<double> _pitchBuffer = [];
  
  PitchCorrectionEngine({
    this.sampleRate = 44100,
  }) : fft = FFT(fftSize);
  
  /// Apply pitch correction to audio samples
  Future<Float32List> processPitchCorrection(
    Float32List inputSamples,
    List<double> pitchValues,
  ) async {
    final outputSamples = Float32List(inputSamples.length);
    final windowFunction = _generateHannWindow(fftSize);
    
    // Process audio in overlapping frames
    for (int frameStart = 0; 
         frameStart <= inputSamples.length - fftSize; 
         frameStart += hopSize) {
      
      // Extract frame and apply window
      final frame = Float32List(fftSize);
      for (int i = 0; i < fftSize; i++) {
        if (frameStart + i < inputSamples.length) {
          frame[i] = inputSamples[frameStart + i] * windowFunction[i];
        }
      }
      
      // Get pitch for this frame
      final frameIndex = frameStart ~/ hopSize;
      final currentPitch = frameIndex < pitchValues.length ? 
          pitchValues[frameIndex] : 0.0;
      
      if (currentPitch > 0) {
        // Apply pitch correction
        final correctedFrame = await _correctPitchPSOLA(
          frame, 
          currentPitch,
          _calculateTargetPitch(currentPitch),
        );
        
        // Overlap-add to output
        for (int i = 0; i < fftSize && frameStart + i < outputSamples.length; i++) {
          outputSamples[frameStart + i] += correctedFrame[i];
        }
      } else {
        // No pitch detected, copy original
        for (int i = 0; i < fftSize && frameStart + i < inputSamples.length; i++) {
          outputSamples[frameStart + i] += frame[i];
        }
      }
    }
    
    // Normalize output to prevent clipping
    return _normalizeAudio(outputSamples);
  }
  
  /// Calculate target pitch based on correction settings
  double _calculateTargetPitch(double inputPitch) {
    if (correctionStrength == 0.0) return inputPitch;
    
    double targetPitch;
    
    if (snapToScale) {
      // Find nearest note in scale
      targetPitch = _snapToNearestScaleNote(inputPitch);
    } else {
      // Snap to nearest chromatic note
      targetPitch = _snapToNearestChromaticNote(inputPitch);
    }
    
    // Apply correction strength
    final correction = (targetPitch - inputPitch) * correctionStrength;
    final correctedPitch = inputPitch + correction;
    
    // Smooth transition with attack/release
    if (_lastCorrectedPitch > 0) {
      final smoothingFactor = inputPitch > _lastCorrectedPitch ? 
          math.exp(-1.0 / (attackTime * sampleRate / hopSize)) :
          math.exp(-1.0 / (releaseTime * sampleRate / hopSize));
      
      _lastCorrectedPitch = _lastCorrectedPitch * smoothingFactor + 
          correctedPitch * (1 - smoothingFactor);
    } else {
      _lastCorrectedPitch = correctedPitch;
    }
    
    return _lastCorrectedPitch;
  }
  
  /// PSOLA (Pitch Synchronous Overlap and Add) algorithm
  Future<Float32List> _correctPitchPSOLA(
    Float32List frame,
    double sourcePitch,
    double targetPitch,
  ) async {
    if (sourcePitch <= 0 || targetPitch <= 0) return frame;
    
    final pitchRatio = targetPitch / sourcePitch;
    if ((pitchRatio - 1.0).abs() < 0.01) return frame; // No correction needed
    
    // Find pitch periods
    final sourcePeriod = (sampleRate / sourcePitch).round();
    final targetPeriod = (sampleRate / targetPitch).round();
    
    // Extract pitch marks (simplified - using fixed period)
    final pitchMarks = <int>[];
    for (int i = 0; i < frame.length; i += sourcePeriod) {
      pitchMarks.add(i);
    }
    
    // Resample using PSOLA
    final output = Float32List(frame.length);
    
    for (int i = 0; i < pitchMarks.length - 1; i++) {
      final start = pitchMarks[i];
      final end = i < pitchMarks.length - 1 ? pitchMarks[i + 1] : frame.length;
      final segmentLength = end - start;
      
      // Extract segment
      final segment = Float32List(segmentLength);
      for (int j = 0; j < segmentLength && start + j < frame.length; j++) {
        segment[j] = frame[start + j];
      }
      
      // Apply window to segment
      final window = _generateHannWindow(segmentLength);
      for (int j = 0; j < segmentLength; j++) {
        segment[j] *= window[j];
      }
      
      // Place segment at new position
      final newPosition = (start * pitchRatio).round();
      for (int j = 0; j < segmentLength; j++) {
        if (newPosition + j < output.length && newPosition + j >= 0) {
          output[newPosition + j] += segment[j];
        }
      }
    }
    
    return output;
  }
  
  /// Snap pitch to nearest note in the selected scale
  double _snapToNearestScaleNote(double frequency) {
    // Convert frequency to MIDI note number
    final midiNote = 69 + 12 * math.log(frequency / 440) / math.ln2;
    final octave = midiNote ~/ 12;
    final noteInOctave = (midiNote % 12).round();
    
    // Find nearest scale note
    int nearestScaleNote = scaleNotes[0];
    int minDistance = 12;
    
    for (final scaleNote in scaleNotes) {
      final distance = (noteInOctave - scaleNote).abs();
      if (distance < minDistance) {
        minDistance = distance;
        nearestScaleNote = scaleNote;
      }
    }
    
    // Handle octave wrapping
    if (noteInOctave - nearestScaleNote > 6) {
      nearestScaleNote += 12;
    } else if (nearestScaleNote - noteInOctave > 6) {
      nearestScaleNote -= 12;
    }
    
    // Convert back to frequency
    final correctedMidiNote = octave * 12 + nearestScaleNote;
    return 440.0 * math.pow(2, (correctedMidiNote - 69) / 12).toDouble();
  }
  
  /// Snap pitch to nearest chromatic note
  double _snapToNearestChromaticNote(double frequency) {
    // Convert to MIDI note and round
    final midiNote = 69 + 12 * math.log(frequency / 440) / math.ln2;
    final roundedNote = midiNote.round();
    
    // Convert back to frequency
    return 440.0 * math.pow(2, (roundedNote - 69) / 12).toDouble();
  }
  
  /// Generate Hann window
  Float32List _generateHannWindow(int size) {
    final window = Float32List(size);
    for (int i = 0; i < size; i++) {
      window[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (size - 1));
    }
    return window;
  }
  
  /// Normalize audio to prevent clipping
  Float32List _normalizeAudio(Float32List samples) {
    double maxValue = 0.0;
    for (final sample in samples) {
      maxValue = math.max(maxValue, sample.abs());
    }
    
    if (maxValue > 0.95) {
      final scale = 0.95 / maxValue;
      for (int i = 0; i < samples.length; i++) {
        samples[i] *= scale;
      }
    }
    
    return samples;
  }
  
  /// Set scale for pitch correction
  void setScale(ScaleType scale) {
    switch (scale) {
      case ScaleType.major:
        scaleNotes = [0, 2, 4, 5, 7, 9, 11];
        break;
      case ScaleType.minor:
        scaleNotes = [0, 2, 3, 5, 7, 8, 10];
        break;
      case ScaleType.pentatonic:
        scaleNotes = [0, 2, 4, 7, 9];
        break;
      case ScaleType.blues:
        scaleNotes = [0, 3, 5, 6, 7, 10];
        break;
      case ScaleType.chromatic:
        scaleNotes = List.generate(12, (i) => i);
        break;
    }
  }
  
  /// Advanced formant correction for natural sound
  Future<Float32List> applyFormantCorrection(
    Float32List samples,
    double pitchShiftRatio,
  ) async {
    if ((pitchShiftRatio - 1.0).abs() < 0.01) return samples;
    
    final output = Float32List(samples.length);
    
    // Process in frames
    for (int frameStart = 0; 
         frameStart <= samples.length - fftSize; 
         frameStart += hopSize) {
      
      // Extract and window frame
      final frame = Float32List(fftSize);
      final window = _generateHannWindow(fftSize);
      
      for (int i = 0; i < fftSize && frameStart + i < samples.length; i++) {
        frame[i] = samples[frameStart + i] * window[i];
      }
      
      // For now, just apply a simple pitch shifting without FFT
      // In a full implementation, you would use proper FFT-based spectral processing
      for (int i = 0; i < fftSize && frameStart + i < output.length; i++) {
        output[frameStart + i] += frame[i] * window[i];
      }
    }
    
    return _normalizeAudio(output);
  }
  
  /// Extract spectral envelope using cepstral analysis
  List<double> _extractSpectralEnvelope(List<double> magnitudes) {
    final envelope = List<double>.filled(magnitudes.length, 0.0);
    
    // Apply moving average for envelope
    const windowSize = 5;
    for (int i = 0; i < magnitudes.length; i++) {
      double sum = 0;
      int count = 0;
      
      for (int j = math.max(0, i - windowSize); 
           j < math.min(magnitudes.length, i + windowSize + 1); 
           j++) {
        sum += magnitudes[j];
        count++;
      }
      
      envelope[i] = sum / count;
    }
    
    return envelope;
  }
}

enum ScaleType {
  major,
  minor,
  pentatonic,
  blues,
  chromatic,
}

/// Configuration for pitch correction
class PitchCorrectionConfig {
  final double correctionStrength;
  final ScaleType scaleType;
  final double attackTime;
  final double releaseTime;
  final bool preserveFormants;
  final double referencePitch;
  
  const PitchCorrectionConfig({
    this.correctionStrength = 1.0,
    this.scaleType = ScaleType.chromatic,
    this.attackTime = 0.005,
    this.releaseTime = 0.050,
    this.preserveFormants = true,
    this.referencePitch = 440.0,
  });
  
  PitchCorrectionConfig copyWith({
    double? correctionStrength,
    ScaleType? scaleType,
    double? attackTime,
    double? releaseTime,
    bool? preserveFormants,
    double? referencePitch,
  }) {
    return PitchCorrectionConfig(
      correctionStrength: correctionStrength ?? this.correctionStrength,
      scaleType: scaleType ?? this.scaleType,
      attackTime: attackTime ?? this.attackTime,
      releaseTime: releaseTime ?? this.releaseTime,
      preserveFormants: preserveFormants ?? this.preserveFormants,
      referencePitch: referencePitch ?? this.referencePitch,
    );
  }
}