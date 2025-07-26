import 'dart:math' as math;
import 'dart:typed_data';

/// Audio format conversion utilities for consistent audio processing
class AudioFormatConverter {
  /// Convert Float32 audio samples to Int16 format
  static List<int> float32ToInt16(List<double> float32Samples) {
    final int16Samples = <int>[];
    
    for (final sample in float32Samples) {
      // Clamp to [-1.0, 1.0] range
      final clampedSample = sample.clamp(-1.0, 1.0);
      
      // Convert to 16-bit signed integer
      final int16Value = (clampedSample * 32767).round();
      int16Samples.add(int16Value);
    }
    
    return int16Samples;
  }
  
  /// Convert Int16 audio samples to Float32 format
  static List<double> int16ToFloat32(List<int> int16Samples) {
    final float32Samples = <double>[];
    
    for (final sample in int16Samples) {
      // Convert from 16-bit signed integer to float
      final float32Value = sample / 32767.0;
      float32Samples.add(float32Value);
    }
    
    return float32Samples;
  }
  
  /// Normalize audio samples to prevent clipping
  static List<double> normalize(List<double> samples) {
    if (samples.isEmpty) return samples;
    
    // Find peak amplitude
    double peak = 0.0;
    for (final sample in samples) {
      final abs = sample.abs();
      if (abs > peak) {
        peak = abs;
      }
    }
    
    // Avoid division by zero
    if (peak == 0.0) return samples;
    
    // Normalize to 0.95 to leave some headroom
    final scale = 0.95 / peak;
    return samples.map((sample) => sample * scale).toList();
  }
  
  /// Apply gain (volume adjustment) to audio samples
  static List<double> applyGain(List<double> samples, double gainDb) {
    if (gainDb == 0.0) return samples;
    
    // Convert dB to linear scale
    final gainLinear = math.pow(10, gainDb / 20.0);
    
    return samples.map((sample) => sample * gainLinear).toList();
  }
  
  /// Remove DC offset from audio samples
  static List<double> removeDcOffset(List<double> samples) {
    if (samples.isEmpty) return samples;
    
    // Calculate DC offset (average value)
    final sum = samples.reduce((a, b) => a + b);
    final dcOffset = sum / samples.length;
    
    // Remove DC offset
    return samples.map((sample) => sample - dcOffset).toList();
  }
  
  /// Apply a simple high-pass filter to remove low frequencies
  static List<double> highPassFilter(List<double> samples, double cutoffFreq, double sampleRate) {
    if (samples.isEmpty || cutoffFreq <= 0) return samples;
    
    // Simple RC high-pass filter
    final rc = 1.0 / (2.0 * math.pi * cutoffFreq);
    final dt = 1.0 / sampleRate;
    final alpha = rc / (rc + dt);
    
    final filtered = <double>[];
    double previousInput = 0.0;
    double previousOutput = 0.0;
    
    for (final sample in samples) {
      final output = alpha * (previousOutput + sample - previousInput);
      filtered.add(output);
      
      previousInput = sample;
      previousOutput = output;
    }
    
    return filtered;
  }
  
  /// Apply a simple low-pass filter to remove high frequencies
  static List<double> lowPassFilter(List<double> samples, double cutoffFreq, double sampleRate) {
    if (samples.isEmpty || cutoffFreq <= 0) return samples;
    
    // Simple RC low-pass filter
    final rc = 1.0 / (2.0 * math.pi * cutoffFreq);
    final dt = 1.0 / sampleRate;
    final alpha = dt / (rc + dt);
    
    final filtered = <double>[];
    double previousOutput = 0.0;
    
    for (final sample in samples) {
      final output = alpha * sample + (1 - alpha) * previousOutput;
      filtered.add(output);
      previousOutput = output;
    }
    
    return filtered;
  }
  
  /// Resample audio to a different sample rate using linear interpolation
  static List<double> resample(List<double> samples, double fromSampleRate, double toSampleRate) {
    if (samples.isEmpty || fromSampleRate == toSampleRate) {
      return samples;
    }
    
    final ratio = fromSampleRate / toSampleRate;
    final newLength = (samples.length / ratio).round();
    final resampled = <double>[];
    
    for (int i = 0; i < newLength; i++) {
      final sourceIndex = i * ratio;
      final sourceIndexFloor = sourceIndex.floor();
      final sourceIndexCeil = sourceIndexFloor + 1;
      
      if (sourceIndexCeil >= samples.length) {
        // Use last sample if we're at the end
        resampled.add(samples[samples.length - 1]);
      } else {
        // Linear interpolation
        final fraction = sourceIndex - sourceIndexFloor;
        final interpolated = samples[sourceIndexFloor] * (1.0 - fraction) + 
                           samples[sourceIndexCeil] * fraction;
        resampled.add(interpolated);
      }
    }
    
    return resampled;
  }
  
  /// Convert mono audio to stereo by duplicating the channel
  static List<List<double>> monoToStereo(List<double> monoSamples) {
    return [monoSamples, List<double>.from(monoSamples)];
  }
  
  /// Convert stereo audio to mono by averaging the channels
  static List<double> stereoToMono(List<double> leftChannel, List<double> rightChannel) {
    final length = math.min(leftChannel.length, rightChannel.length);
    final mono = <double>[];
    
    for (int i = 0; i < length; i++) {
      mono.add((leftChannel[i] + rightChannel[i]) * 0.5);
    }
    
    return mono;
  }
  
  /// Apply a fade in effect to audio samples
  static List<double> fadeIn(List<double> samples, double fadeDurationSeconds, double sampleRate) {
    if (samples.isEmpty || fadeDurationSeconds <= 0) return samples;
    
    final fadeSamples = (fadeDurationSeconds * sampleRate).round();
    final actualFadeSamples = math.min(fadeSamples, samples.length);
    
    final result = List<double>.from(samples);
    
    for (int i = 0; i < actualFadeSamples; i++) {
      final fadeGain = i / actualFadeSamples;
      result[i] *= fadeGain;
    }
    
    return result;
  }
  
  /// Apply a fade out effect to audio samples
  static List<double> fadeOut(List<double> samples, double fadeDurationSeconds, double sampleRate) {
    if (samples.isEmpty || fadeDurationSeconds <= 0) return samples;
    
    final fadeSamples = (fadeDurationSeconds * sampleRate).round();
    final actualFadeSamples = math.min(fadeSamples, samples.length);
    final startIndex = samples.length - actualFadeSamples;
    
    final result = List<double>.from(samples);
    
    for (int i = 0; i < actualFadeSamples; i++) {
      final fadeGain = (actualFadeSamples - i) / actualFadeSamples;
      result[startIndex + i] *= fadeGain;
    }
    
    return result;
  }
  
  /// Calculate RMS (Root Mean Square) value of audio samples
  static double calculateRms(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    
    double sumSquares = 0.0;
    for (final sample in samples) {
      sumSquares += sample * sample;
    }
    
    return math.sqrt(sumSquares / samples.length);
  }
  
  /// Calculate peak amplitude of audio samples
  static double calculatePeak(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    
    double peak = 0.0;
    for (final sample in samples) {
      final abs = sample.abs();
      if (abs > peak) {
        peak = abs;
      }
    }
    
    return peak;
  }
  
  /// Convert audio level to decibels
  static double linearToDb(double linearValue) {
    if (linearValue <= 0.0) return double.negativeInfinity;
    return 20.0 * math.log(linearValue) / math.ln10;
  }
  
  /// Convert decibels to linear audio level
  static double dbToLinear(double dbValue) {
    if (dbValue == double.negativeInfinity) return 0.0;
    return math.pow(10.0, dbValue / 20.0).toDouble();
  }
  
  /// Split audio samples into overlapping frames for analysis
  static List<List<double>> frameAudio(List<double> samples, int frameSize, int hopSize) {
    final frames = <List<double>>[];
    
    for (int i = 0; i + frameSize <= samples.length; i += hopSize) {
      final frame = samples.sublist(i, i + frameSize);
      frames.add(frame);
    }
    
    return frames;
  }
  
  /// Apply a Hamming window to audio samples
  static List<double> applyHammingWindow(List<double> samples) {
    if (samples.isEmpty) return samples;
    
    final windowed = <double>[];
    final length = samples.length;
    
    for (int i = 0; i < length; i++) {
      final windowValue = 0.54 - 0.46 * math.cos(2.0 * math.pi * i / (length - 1));
      windowed.add(samples[i] * windowValue);
    }
    
    return windowed;
  }
}