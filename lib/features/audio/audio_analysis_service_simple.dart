import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:fftea/fftea.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_capture_service.dart';

class AudioAnalysisResult {
  final double frequency;
  final double amplitude;
  final String note;
  final double confidence;
  final List<double> spectrum;
  final DateTime timestamp;

  AudioAnalysisResult({
    required this.frequency,
    required this.amplitude,
    required this.note,
    required this.confidence,
    required this.spectrum,
    required this.timestamp,
  });
}

class SimpleAudioAnalysisService {
  static const int sampleRate = 44100;
  static const int bufferSize = 4096;
  
  final FFT _fft = FFT(bufferSize);
  
  List<double> _audioBuffer = [];
  
  // Note names for frequency to note conversion
  static const List<String> noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  AudioAnalysisResult? analyzeAudioData(Uint8List audioData) {
    try {
      // Convert audio bytes to double samples
      final samples = _convertBytesToSamples(audioData);
      _audioBuffer.addAll(samples);
      
      // Process when we have enough data
      if (_audioBuffer.length >= bufferSize) {
        final processData = _audioBuffer.take(bufferSize).toList();
        _audioBuffer.removeRange(0, bufferSize ~/ 2); // 50% overlap
        
        return _processAudioBuffer(processData);
      }
      
      return null;
    } catch (e) {
      print('❌ Audio analysis error: $e');
      return null;
    }
  }

  List<double> _convertBytesToSamples(Uint8List bytes) {
    final samples = <double>[];
    
    // Convert 16-bit PCM to double samples (-1.0 to 1.0)
    for (int i = 0; i < bytes.length - 1; i += 2) {
      final int sample = (bytes[i + 1] << 8) | bytes[i];
      final double normalizedSample = sample.toSigned(16) / 32768.0;
      samples.add(normalizedSample);
    }
    
    return samples;
  }

  AudioAnalysisResult _processAudioBuffer(List<double> buffer) {
    // Calculate RMS amplitude
    final double amplitude = _calculateRMS(buffer);
    
    // Perform FFT for spectrum analysis and find dominant frequency
    final spectrum = _performFFT(buffer);
    final frequency = _findDominantFrequency(spectrum);
    
    // Simple pitch detection confidence based on spectral peak clarity
    final confidence = _calculateConfidence(spectrum, frequency);
    
    // Convert frequency to note
    final String note = _frequencyToNote(frequency);
    
    return AudioAnalysisResult(
      frequency: frequency,
      amplitude: amplitude,
      note: note,
      confidence: confidence,
      spectrum: spectrum,
      timestamp: DateTime.now(),
    );
  }

  double _calculateRMS(List<double> samples) {
    double sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    return sqrt(sum / samples.length);
  }

  double _findDominantFrequency(List<double> spectrum) {
    if (spectrum.isEmpty) return 0.0;
    
    // Find the index of the maximum magnitude
    int maxIndex = 0;
    double maxMagnitude = spectrum[0];
    
    // Only look at frequencies between 80Hz and 2000Hz (typical vocal range)
    final minBin = (80 * bufferSize / sampleRate).floor();
    final maxBin = (2000 * bufferSize / sampleRate).floor().clamp(0, spectrum.length - 1);
    
    for (int i = minBin; i < maxBin; i++) {
      if (spectrum[i] > maxMagnitude) {
        maxMagnitude = spectrum[i];
        maxIndex = i;
      }
    }
    
    // Convert bin index to frequency
    final frequency = maxIndex * sampleRate / bufferSize;
    
    // Only return frequency if magnitude is significant
    return maxMagnitude > 0.01 ? frequency : 0.0;
  }

  double _calculateConfidence(List<double> spectrum, double frequency) {
    if (frequency <= 0 || spectrum.isEmpty) return 0.0;
    
    final bin = (frequency * bufferSize / sampleRate).round();
    if (bin >= spectrum.length) return 0.0;
    
    final peakMagnitude = spectrum[bin];
    
    // Calculate average magnitude of neighboring bins
    double avgMagnitude = 0.0;
    int count = 0;
    final radius = 5;
    
    for (int i = max(0, bin - radius); i <= min(spectrum.length - 1, bin + radius); i++) {
      if (i != bin) {
        avgMagnitude += spectrum[i];
        count++;
      }
    }
    
    if (count > 0) {
      avgMagnitude /= count;
      // Confidence is the ratio of peak to average, normalized
      return (peakMagnitude / (peakMagnitude + avgMagnitude)).clamp(0.0, 1.0);
    }
    
    return 0.5;
  }

  String _frequencyToNote(double frequency) {
    if (frequency <= 0) return 'N/A';
    
    // A4 = 440 Hz, calculate semitones from A4
    final double a4 = 440.0;
    final double semitones = 12 * log(frequency / a4) / ln2;
    final int noteIndex = (semitones.round() + 9) % 12; // A = 9
    final int octave = ((semitones + 9) / 12).floor() + 4;
    
    return '${noteNames[noteIndex]}$octave';
  }

  List<double> _performFFT(List<double> buffer) {
    try {
      // Apply window function (Hanning)
      final windowed = _applyHanningWindow(buffer);
      
      // Perform FFT
      final fftResult = _fft.realFft(windowed);
      
      // Calculate magnitude spectrum
      final spectrum = <double>[];
      for (int i = 0; i < fftResult.length ~/ 2; i++) {
        // Access Float64x2 components differently for web compatibility
        final Float64x2 complex = fftResult[i];
        final real = complex.x;
        final imag = complex.y;
        final magnitude = sqrt(real * real + imag * imag);
        spectrum.add(magnitude);
      }
      
      return spectrum;
    } catch (e) {
      print('❌ FFT error: $e');
      return List.filled(bufferSize ~/ 2, 0.0);
    }
  }

  List<double> _applyHanningWindow(List<double> samples) {
    final windowed = <double>[];
    final n = samples.length;
    
    for (int i = 0; i < n; i++) {
      final window = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
      windowed.add(samples[i] * window);
    }
    
    return windowed;
  }
}

// Riverpod providers
final simpleAudioAnalysisServiceProvider = Provider<SimpleAudioAnalysisService>((ref) {
  return SimpleAudioAnalysisService();
});

final simpleAudioAnalysisStreamProvider = StreamProvider<AudioAnalysisResult?>((ref) {
  final analysisService = ref.read(simpleAudioAnalysisServiceProvider);
  final audioDataStream = ref.watch(audioDataStreamProvider);
  
  return audioDataStream.when(
    data: (audioData) {
      return Stream.fromFuture(Future(() {
        return analysisService.analyzeAudioData(audioData);
      }));
    },
    loading: () => Stream<AudioAnalysisResult?>.empty(),
    error: (_, __) => Stream<AudioAnalysisResult?>.empty(),
  );
});