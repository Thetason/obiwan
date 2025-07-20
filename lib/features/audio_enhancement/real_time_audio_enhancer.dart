import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../core/utils/random_utils.dart';

/// Real-time Audio Enhancement System
/// Features: RNNoise-style denoising, voice enhancement, source separation
class RealTimeAudioEnhancer {
  static const int sampleRate = 48000;
  static const int frameSize = 480; // 10ms frames
  static const int hopSize = 240;
  static const int fftSize = 1024;
  static const int melBins = 64;
  static const int rnnHiddenSize = 128;
  
  // Enhancement modules
  late NoiseReductionModule _noiseReduction;
  late VoiceEnhancementModule _voiceEnhancement;
  late SourceSeparationModule _sourceSeparation;
  late SpectralProcessor _spectralProcessor;
  
  // Real-time processing buffers
  final List<double> _inputBuffer = [];
  final List<double> _outputBuffer = [];
  final List<List<double>> _spectralHistory = [];
  
  // Processing parameters
  double _noiseReductionStrength = 0.8;
  double _voiceEnhancementGain = 1.2;
  bool _enableSourceSeparation = true;
  
  RealTimeAudioEnhancer() {
    _initializeModules();
  }
  
  void _initializeModules() {
    _noiseReduction = NoiseReductionModule();
    _voiceEnhancement = VoiceEnhancementModule();
    _sourceSeparation = SourceSeparationModule();
    _spectralProcessor = SpectralProcessor();
    debugPrint('Real-time Audio Enhancement System initialized');
  }
  
  /// Main real-time processing pipeline
  Future<List<double>> processAudioRealTime(List<double> inputAudio) async {
    try {
      // Buffer management
      _inputBuffer.addAll(inputAudio);
      
      final processedFrames = <double>[];
      
      while (_inputBuffer.length >= frameSize) {
        // Extract frame
        final frame = _inputBuffer.sublist(0, frameSize);
        _inputBuffer.removeRange(0, frameSize);
        
        // Processing pipeline
        final enhancedFrame = await _processFrame(frame);
        processedFrames.addAll(enhancedFrame);
      }
      
      return processedFrames;
    } catch (e) {
      debugPrint('Real-time processing error: $e');
      return inputAudio; // Return original on error
    }
  }
  
  Future<List<double>> _processFrame(List<double> frame) async {
    // 1. Convert to frequency domain
    final spectrum = _spectralProcessor.forwardSTFT(frame);
    
    // 2. Noise reduction
    final denoisedSpectrum = await _noiseReduction.reduce(spectrum, _noiseReductionStrength);
    
    // 3. Voice enhancement
    final enhancedSpectrum = await _voiceEnhancement.enhance(denoisedSpectrum, _voiceEnhancementGain);
    
    // 4. Source separation (optional)
    final separatedSpectrum = _enableSourceSeparation
        ? await _sourceSeparation.separate(enhancedSpectrum)
        : enhancedSpectrum;
    
    // 5. Convert back to time domain
    final enhancedFrame = _spectralProcessor.inverseSTFT(separatedSpectrum);
    
    // 6. Update spectral history for adaptive processing
    _updateSpectralHistory(spectrum);
    
    return enhancedFrame;
  }
  
  void _updateSpectralHistory(List<Complex> spectrum) {
    final magnitudes = spectrum.map((c) => c.magnitude).toList();
    _spectralHistory.add(magnitudes);
    
    // Keep only recent history
    if (_spectralHistory.length > 50) {
      _spectralHistory.removeAt(0);
    }
  }
  
  /// Configure enhancement parameters
  void configureEnhancement({
    double? noiseReductionStrength,
    double? voiceEnhancementGain,
    bool? enableSourceSeparation,
  }) {
    _noiseReductionStrength = noiseReductionStrength ?? _noiseReductionStrength;
    _voiceEnhancementGain = voiceEnhancementGain ?? _voiceEnhancementGain;
    _enableSourceSeparation = enableSourceSeparation ?? _enableSourceSeparation;
  }
  
  /// Batch processing for non-real-time applications
  Future<List<double>> processAudioBatch(List<double> inputAudio) async {
    final outputAudio = <double>[];
    
    for (int i = 0; i < inputAudio.length - frameSize; i += hopSize) {
      final frame = inputAudio.sublist(i, i + frameSize);
      final processedFrame = await _processFrame(frame);
      
      // Overlap-add reconstruction
      _addOverlap(outputAudio, processedFrame, i);
    }
    
    return outputAudio;
  }
  
  void _addOverlap(List<double> output, List<double> frame, int offset) {
    // Ensure output buffer is large enough
    while (output.length < offset + frame.length) {
      output.add(0.0);
    }
    
    // Apply window function and add
    for (int i = 0; i < frame.length; i++) {
      final window = _hannWindow(i, frame.length);
      output[offset + i] += frame[i] * window;
    }
  }
  
  double _hannWindow(int n, int N) {
    return 0.5 * (1 - math.cos(2 * math.pi * n / (N - 1)));
  }
}

/// RNNoise-inspired Noise Reduction Module
class NoiseReductionModule {
  static const int numBands = 22;
  static const int rnnStateSize = 128;
  
  late List<List<double>> _rnnWeights;
  late List<double> _rnnBias;
  late List<double> _rnnState;
  late List<double> _noiseProfile;
  
  NoiseReductionModule() {
    _initializeRNN();
  }
  
  void _initializeRNN() {
    final random = math.Random(42);
    
    _rnnWeights = List.generate(rnnStateSize, (_) =>
      List.generate(numBands + rnnStateSize, (_) => random.nextGaussian() * 0.1)
    );
    _rnnBias = List.generate(rnnStateSize, (_) => random.nextGaussian() * 0.01);
    _rnnState = List.filled(rnnStateSize, 0.0);
    _noiseProfile = List.filled(numBands, 0.1);
  }
  
  Future<List<Complex>> reduce(List<Complex> spectrum, double strength) async {
    // Convert to frequency bands
    final bands = _spectralToBands(spectrum);
    
    // Update noise profile
    _updateNoiseProfile(bands);
    
    // RNN-based gain estimation
    final gains = _estimateGains(bands);
    
    // Apply gains to spectrum
    return _applyGains(spectrum, gains, strength);
  }
  
  List<double> _spectralToBands(List<Complex> spectrum) {
    final bands = List<double>.filled(numBands, 0.0);
    final binPerBand = spectrum.length / numBands;
    
    for (int i = 0; i < numBands; i++) {
      final startBin = (i * binPerBand).floor();
      final endBin = ((i + 1) * binPerBand).floor();
      
      double energy = 0;
      for (int j = startBin; j < endBin && j < spectrum.length; j++) {
        energy += spectrum[j].magnitude * spectrum[j].magnitude;
      }
      
      bands[i] = 10 * math.log(energy + 1e-10) / math.ln10; // dB
    }
    
    return bands;
  }
  
  void _updateNoiseProfile(List<double> bands) {
    const alpha = 0.01; // Slow adaptation
    
    for (int i = 0; i < numBands; i++) {
      // Minimum statistics for noise estimation
      if (bands[i] < _noiseProfile[i]) {
        _noiseProfile[i] = alpha * bands[i] + (1 - alpha) * _noiseProfile[i];
      } else {
        _noiseProfile[i] = (1 - alpha * 0.1) * _noiseProfile[i] + alpha * 0.1 * bands[i];
      }
    }
  }
  
  List<double> _estimateGains(List<double> bands) {
    // Prepare RNN input
    final input = <double>[];
    input.addAll(bands);
    input.addAll(_rnnState);
    
    // RNN forward pass
    final newState = List<double>.filled(rnnStateSize, 0.0);
    for (int i = 0; i < rnnStateSize; i++) {
      double sum = _rnnBias[i];
      for (int j = 0; j < input.length && j < _rnnWeights[i].length; j++) {
        sum += input[j] * _rnnWeights[i][j];
      }
      newState[i] = _sigmoid(sum);
    }
    
    _rnnState = newState;
    
    // Convert RNN output to gains
    final gains = <double>[];
    for (int i = 0; i < numBands; i++) {
      final snr = bands[i] - _noiseProfile[i];
      final baseGain = _sigmoid(snr - 6); // 6 dB threshold
      final rnnGain = _rnnState[i % rnnStateSize];
      gains.add(baseGain * rnnGain);
    }
    
    return gains;
  }
  
  List<Complex> _applyGains(List<Complex> spectrum, List<double> gains, double strength) {
    final enhanced = <Complex>[];
    final binPerBand = spectrum.length / gains.length;
    
    for (int i = 0; i < spectrum.length; i++) {
      final bandIndex = (i / binPerBand).floor().clamp(0, gains.length - 1);
      final gain = gains[bandIndex];
      final finalGain = 1.0 - strength * (1.0 - gain);
      
      enhanced.add(Complex(
        spectrum[i].real * finalGain,
        spectrum[i].imag * finalGain,
      ));
    }
    
    return enhanced;
  }
  
  double _sigmoid(double x) => 1 / (1 + math.exp(-x));
}

/// Voice Enhancement Module
class VoiceEnhancementModule {
  late List<double> _formantFrequencies;
  late SpectralEnvelopeProcessor _envelopeProcessor;
  late HarmonicEnhancer _harmonicEnhancer;
  
  VoiceEnhancementModule() {
    _initializeEnhancement();
  }
  
  void _initializeEnhancement() {
    _formantFrequencies = [700, 1220, 2600, 3300, 4200]; // Typical formants
    _envelopeProcessor = SpectralEnvelopeProcessor();
    _harmonicEnhancer = HarmonicEnhancer();
  }
  
  Future<List<Complex>> enhance(List<Complex> spectrum, double gain) async {
    // 1. Formant enhancement
    var enhanced = _enhanceFormants(spectrum);
    
    // 2. Harmonic enhancement
    enhanced = _harmonicEnhancer.enhance(enhanced);
    
    // 3. Spectral envelope shaping
    enhanced = _envelopeProcessor.shape(enhanced);
    
    // 4. Apply overall gain
    enhanced = enhanced.map((c) => Complex(c.real * gain, c.imag * gain)).toList();
    
    return enhanced;
  }
  
  List<Complex> _enhanceFormants(List<Complex> spectrum) {
    final enhanced = List<Complex>.from(spectrum);
    const sampleRate = RealTimeAudioEnhancer.sampleRate;
    
    for (final formantFreq in _formantFrequencies) {
      final bin = (formantFreq * spectrum.length / (sampleRate / 2)).round();
      
      if (bin < spectrum.length) {
        // Enhance formant region
        final bandwidth = (100.0 * spectrum.length / (sampleRate / 2)).round(); // 100 Hz bandwidth
        
        for (int i = math.max(0, bin - bandwidth); i < math.min(spectrum.length, bin + bandwidth); i++) {
          final distance = (i - bin).abs();
          final enhancement = 1.0 + 0.3 * math.exp(-distance * distance / (bandwidth * bandwidth / 4));
          
          enhanced[i] = Complex(
            spectrum[i].real * enhancement,
            spectrum[i].imag * enhancement,
          );
        }
      }
    }
    
    return enhanced;
  }
}

/// Source Separation Module
class SourceSeparationModule {
  late MaskEstimator _maskEstimator;
  
  SourceSeparationModule() {
    _maskEstimator = MaskEstimator();
  }
  
  Future<List<Complex>> separate(List<Complex> spectrum) async {
    // Estimate vocal mask
    final vocalMask = await _maskEstimator.estimateVocalMask(spectrum);
    
    // Apply mask to extract vocals
    final separatedSpectrum = <Complex>[];
    for (int i = 0; i < spectrum.length; i++) {
      final mask = i < vocalMask.length ? vocalMask[i] : 0.0;
      separatedSpectrum.add(Complex(
        spectrum[i].real * mask,
        spectrum[i].imag * mask,
      ));
    }
    
    return separatedSpectrum;
  }
}

/// Spectral Processing Utilities
class SpectralProcessor {
  List<double> _window = [];
  
  SpectralProcessor() {
    _initializeWindow();
  }
  
  void _initializeWindow() {
    _window = List.generate(RealTimeAudioEnhancer.frameSize, (i) =>
      0.5 * (1 - math.cos(2 * math.pi * i / (RealTimeAudioEnhancer.frameSize - 1)))
    );
  }
  
  List<Complex> forwardSTFT(List<double> frame) {
    // Apply window
    final windowed = <double>[];
    for (int i = 0; i < frame.length; i++) {
      windowed.add(frame[i] * _window[i]);
    }
    
    // Zero-pad to FFT size
    while (windowed.length < RealTimeAudioEnhancer.fftSize) {
      windowed.add(0.0);
    }
    
    // Perform FFT
    return _fft(windowed);
  }
  
  List<double> inverseSTFT(List<Complex> spectrum) {
    // Perform IFFT
    final timeSignal = _ifft(spectrum);
    
    // Apply window and extract frame
    final frame = <double>[];
    for (int i = 0; i < math.min(timeSignal.length, RealTimeAudioEnhancer.frameSize); i++) {
      frame.add(timeSignal[i] * _window[i]);
    }
    
    return frame;
  }
  
  List<Complex> _fft(List<double> input) {
    final N = input.length;
    final output = <Complex>[];
    
    for (int k = 0; k < N; k++) {
      double real = 0, imag = 0;
      for (int n = 0; n < N; n++) {
        final angle = -2 * math.pi * k * n / N;
        real += input[n] * math.cos(angle);
        imag += input[n] * math.sin(angle);
      }
      output.add(Complex(real, imag));
    }
    
    return output;
  }
  
  List<double> _ifft(List<Complex> input) {
    final N = input.length;
    final output = <double>[];
    
    for (int n = 0; n < N; n++) {
      double sum = 0;
      for (int k = 0; k < N; k++) {
        final angle = 2 * math.pi * k * n / N;
        sum += input[k].real * math.cos(angle) - input[k].imag * math.sin(angle);
      }
      output.add(sum / N);
    }
    
    return output;
  }
}

/// Supporting Classes
class Complex {
  final double real;
  final double imag;
  
  Complex(this.real, this.imag);
  
  double get magnitude => math.sqrt(real * real + imag * imag);
  double get phase => math.atan2(imag, real);
  
  Complex operator +(Complex other) => Complex(real + other.real, imag + other.imag);
  Complex operator -(Complex other) => Complex(real - other.real, imag - other.imag);
  Complex operator *(Complex other) => Complex(
    real * other.real - imag * other.imag,
    real * other.imag + imag * other.real,
  );
}

class SpectralEnvelopeProcessor {
  List<Complex> shape(List<Complex> spectrum) {
    // Smooth spectral envelope shaping
    final smoothed = <Complex>[];
    const windowSize = 5;
    
    for (int i = 0; i < spectrum.length; i++) {
      double realSum = 0, imagSum = 0;
      int count = 0;
      
      for (int j = math.max(0, i - windowSize); j <= math.min(spectrum.length - 1, i + windowSize); j++) {
        realSum += spectrum[j].real;
        imagSum += spectrum[j].imag;
        count++;
      }
      
      smoothed.add(Complex(realSum / count, imagSum / count));
    }
    
    return smoothed;
  }
}

class HarmonicEnhancer {
  List<Complex> enhance(List<Complex> spectrum) {
    // Enhance harmonic structure
    final enhanced = List<Complex>.from(spectrum);
    
    // Find fundamental frequency
    final f0Bin = _findFundamentalBin(spectrum);
    
    if (f0Bin > 0) {
      // Enhance harmonics
      for (int h = 2; h <= 5; h++) {
        final harmonicBin = f0Bin * h;
        if (harmonicBin < spectrum.length) {
          enhanced[harmonicBin] = Complex(
            spectrum[harmonicBin].real * 1.2,
            spectrum[harmonicBin].imag * 1.2,
          );
        }
      }
    }
    
    return enhanced;
  }
  
  int _findFundamentalBin(List<Complex> spectrum) {
    // Simplified fundamental frequency detection
    int bestBin = 0;
    double maxMagnitude = 0;
    
    // Search in typical vocal range (80-400 Hz)
    const sampleRate = RealTimeAudioEnhancer.sampleRate;
    final minBin = (80.0 * spectrum.length / (sampleRate / 2)).round();
    final maxBin = (400.0 * spectrum.length / (sampleRate / 2)).round();
    
    for (int i = minBin; i < math.min(maxBin, spectrum.length); i++) {
      if (spectrum[i].magnitude > maxMagnitude) {
        maxMagnitude = spectrum[i].magnitude;
        bestBin = i;
      }
    }
    
    return bestBin;
  }
}

class MaskEstimator {
  Future<List<double>> estimateVocalMask(List<Complex> spectrum) async {
    final mask = <double>[];
    
    // Simplified vocal mask estimation
    for (int i = 0; i < spectrum.length; i++) {
      final frequency = i * RealTimeAudioEnhancer.sampleRate / (2 * spectrum.length);
      
      // Vocal frequency range weighting
      double weight = 0.5; // Base weight
      
      if (frequency >= 80 && frequency <= 2000) {
        weight = 1.0; // Full vocal range
      } else if (frequency > 2000 && frequency <= 8000) {
        weight = 0.7; // Upper harmonics
      } else {
        weight = 0.2; // Outside vocal range
      }
      
      // Apply magnitude-based weighting
      final magnitude = spectrum[i].magnitude;
      final threshold = 0.01;
      
      if (magnitude > threshold) {
        weight *= math.min(1.0, magnitude / threshold);
      } else {
        weight *= 0.1;
      }
      
      mask.add(weight);
    }
    
    return mask;
  }
}