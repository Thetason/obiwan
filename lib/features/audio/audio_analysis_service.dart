import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:fftea/fftea.dart';
import 'package:pitch_detector_dart/pitch_detector_dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class AudioAnalysisService {
  static const int sampleRate = 44100;
  static const int bufferSize = 4096;
  
  final PitchDetector _pitchDetector = PitchDetector(sampleRate, bufferSize);
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
    
    // Perform pitch detection
    final pitchResult = _pitchDetector.getPitch(buffer);
    final double frequency = pitchResult?.pitch ?? 0.0;
    final double confidence = pitchResult?.probability ?? 0.0;
    
    // Convert frequency to note
    final String note = _frequencyToNote(frequency);
    
    // Perform FFT for spectrum analysis
    final spectrum = _performFFT(buffer);
    
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
        final real = fftResult[i].real;
        final imag = fftResult[i].imaginary;
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
final audioAnalysisServiceProvider = Provider<AudioAnalysisService>((ref) {
  return AudioAnalysisService();
});

final audioAnalysisStreamProvider = StreamProvider<AudioAnalysisResult?>((ref) {
  final analysisService = ref.read(audioAnalysisServiceProvider);
  final audioDataStream = ref.watch(audioDataStreamProvider);
  
  return audioDataStream.when(
    data: (audioData) async* {
      final result = analysisService.analyzeAudioData(audioData);
      if (result != null) {
        yield result;
      }
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  ).asBroadcastStream();
});

// Import audio data stream from capture service
import 'audio_capture_service.dart';