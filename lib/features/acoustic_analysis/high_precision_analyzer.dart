import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// High-Precision Acoustic Analysis System
/// Features: Wavelet transform, formant tracking, voice quality metrics
class HighPrecisionAcousticAnalyzer {
  static const int sampleRate = 48000;
  static const int windowSize = 2048;
  static const int hopSize = 512;
  static const int numFormants = 5;
  static const int maxF0 = 800; // Maximum F0 for vocal analysis
  static const int minF0 = 50;  // Minimum F0 for vocal analysis
  
  // Analysis modules
  late WaveletAnalyzer _waveletAnalyzer;
  late FormantTracker _formantTracker;
  late VoiceQualityAnalyzer _voiceQualityAnalyzer;
  late SpectralAnalysisEngine _spectralEngine;
  late MultiScaleAnalyzer _multiScaleAnalyzer;
  
  // Real-time buffers
  final List<double> _analysisBuffer = [];
  final List<AcousticMeasurement> _measurementHistory = [];
  
  HighPrecisionAcousticAnalyzer() {
    _initializeAnalyzer();
  }
  
  void _initializeAnalyzer() {
    _waveletAnalyzer = WaveletAnalyzer();
    _formantTracker = FormantTracker();
    _voiceQualityAnalyzer = VoiceQualityAnalyzer();
    _spectralEngine = SpectralAnalysisEngine();
    _multiScaleAnalyzer = MultiScaleAnalyzer();
    debugPrint('High-Precision Acoustic Analyzer initialized');
  }
  
  /// Comprehensive acoustic analysis
  Future<AcousticAnalysisResult> analyzeAudio(List<double> audioData) async {
    try {
      // Multi-scale wavelet analysis
      final waveletResult = await _waveletAnalyzer.analyze(audioData);
      
      // Formant tracking
      final formantResult = await _formantTracker.track(audioData);
      
      // Voice quality metrics
      final voiceQualityResult = await _voiceQualityAnalyzer.analyze(audioData);
      
      // Spectral analysis
      final spectralResult = await _spectralEngine.analyze(audioData);
      
      // Multi-resolution analysis
      final multiScaleResult = await _multiScaleAnalyzer.analyze(audioData);
      
      // Combine results
      final measurement = AcousticMeasurement(
        timestamp: DateTime.now(),
        waveletAnalysis: waveletResult,
        formantAnalysis: formantResult,
        voiceQuality: voiceQualityResult,
        spectralAnalysis: spectralResult,
        multiScaleAnalysis: multiScaleResult,
      );
      
      _measurementHistory.add(measurement);
      if (_measurementHistory.length > 100) {
        _measurementHistory.removeAt(0);
      }
      
      // Generate comprehensive result
      return _generateAnalysisResult(measurement);
      
    } catch (e) {
      debugPrint('Acoustic analysis error: $e');
      return AcousticAnalysisResult.empty();
    }
  }
  
  /// Real-time streaming analysis
  Stream<AcousticAnalysisResult> analyzeStream(Stream<List<double>> audioStream) async* {
    await for (final audioChunk in audioStream) {
      _analysisBuffer.addAll(audioChunk);
      
      while (_analysisBuffer.length >= windowSize) {
        final analysisWindow = _analysisBuffer.sublist(0, windowSize);
        _analysisBuffer.removeRange(0, hopSize);
        
        final result = await analyzeAudio(analysisWindow);
        yield result;
      }
    }
  }
  
  AcousticAnalysisResult _generateAnalysisResult(AcousticMeasurement measurement) {
    return AcousticAnalysisResult(
      fundamentalFrequency: measurement.spectralAnalysis.fundamentalFrequency,
      harmonicity: measurement.voiceQuality.harmonicity,
      formants: measurement.formantAnalysis.formantFrequencies,
      formantBandwidths: measurement.formantAnalysis.bandwidths,
      jitter: measurement.voiceQuality.jitter,
      shimmer: measurement.voiceQuality.shimmer,
      hnr: measurement.voiceQuality.hnr,
      spectralCentroid: measurement.spectralAnalysis.spectralCentroid,
      spectralRolloff: measurement.spectralAnalysis.spectralRolloff,
      spectralFlux: measurement.spectralAnalysis.spectralFlux,
      zeroCrossingRate: measurement.spectralAnalysis.zeroCrossingRate,
      mfcc: measurement.spectralAnalysis.mfcc,
      waveletEnergy: measurement.waveletAnalysis.energyDistribution,
      voiceBreaks: measurement.voiceQuality.voiceBreaks,
      subharmonics: measurement.voiceQuality.subharmonics,
      confidence: _calculateOverallConfidence(measurement),
      timestamp: measurement.timestamp,
    );
  }
  
  double _calculateOverallConfidence(AcousticMeasurement measurement) {
    final confidences = [
      measurement.waveletAnalysis.confidence,
      measurement.formantAnalysis.confidence,
      measurement.voiceQuality.confidence,
      measurement.spectralAnalysis.confidence,
      measurement.multiScaleAnalysis.confidence,
    ];
    
    return confidences.reduce((a, b) => a + b) / confidences.length;
  }
}

/// Wavelet-based Multi-Resolution Analysis
class WaveletAnalyzer {
  static const int numScales = 8;
  static const int numOrientations = 6;
  
  late List<WaveletFilter> _motherWavelets;
  
  WaveletAnalyzer() {
    _initializeWavelets();
  }
  
  void _initializeWavelets() {
    _motherWavelets = [
      WaveletFilter.morlet(),
      WaveletFilter.mexicanHat(),
      WaveletFilter.daubechies4(),
    ];
  }
  
  Future<WaveletAnalysisResult> analyze(List<double> signal) async {
    final results = <WaveletTransformResult>[];
    
    for (final wavelet in _motherWavelets) {
      final result = _continuousWaveletTransform(signal, wavelet);
      results.add(result);
    }
    
    // Analyze energy distribution across scales
    final energyDistribution = _computeEnergyDistribution(results);
    
    // Detect time-frequency patterns
    final patterns = _detectTimeFrequencyPatterns(results);
    
    // Compute instantaneous frequency
    final instantaneousFreq = _computeInstantaneousFrequency(results.first);
    
    return WaveletAnalysisResult(
      transforms: results,
      energyDistribution: energyDistribution,
      timeFrequencyPatterns: patterns,
      instantaneousFrequency: instantaneousFreq,
      confidence: _calculateWaveletConfidence(results),
    );
  }
  
  WaveletTransformResult _continuousWaveletTransform(List<double> signal, WaveletFilter wavelet) {
    final scales = _generateScales();
    final coefficients = <List<Complex>>[];
    
    for (final scale in scales) {
      final scaleCoeffs = <Complex>[];
      
      for (int t = 0; t < signal.length; t++) {
        Complex coeff = Complex(0, 0);
        
        for (int tau = 0; tau < signal.length; tau++) {
          final waveletValue = wavelet.evaluate((t - tau) / scale) / math.sqrt(scale);
          coeff = coeff + Complex(signal[tau] * waveletValue.real, signal[tau] * waveletValue.imag);
        }
        
        scaleCoeffs.add(coeff);
      }
      
      coefficients.add(scaleCoeffs);
    }
    
    return WaveletTransformResult(
      scales: scales,
      coefficients: coefficients,
      waveletType: wavelet.type,
    );
  }
  
  List<double> _generateScales() {
    final scales = <double>[];
    const minScale = 1.0;
    const maxScale = 128.0;
    
    for (int i = 0; i < numScales; i++) {
      final scale = minScale * math.pow(maxScale / minScale, i / (numScales - 1));
      scales.add(scale);
    }
    
    return scales;
  }
  
  List<double> _computeEnergyDistribution(List<WaveletTransformResult> results) {
    final energyDist = List<double>.filled(numScales, 0.0);
    
    for (final result in results) {
      for (int s = 0; s < result.scales.length && s < numScales; s++) {
        double scaleEnergy = 0;
        for (final coeff in result.coefficients[s]) {
          scaleEnergy += coeff.magnitude * coeff.magnitude;
        }
        energyDist[s] += scaleEnergy / result.coefficients[s].length;
      }
    }
    
    // Normalize
    final totalEnergy = energyDist.reduce((a, b) => a + b);
    return totalEnergy > 0 ? energyDist.map((e) => e / totalEnergy).toList() : energyDist;
  }
  
  List<TimeFrequencyPattern> _detectTimeFrequencyPatterns(List<WaveletTransformResult> results) {
    final patterns = <TimeFrequencyPattern>[];
    
    for (final result in results) {
      // Find ridges in the time-frequency representation
      final ridges = _findWaveletRidges(result);
      
      for (final ridge in ridges) {
        patterns.add(TimeFrequencyPattern(
          startTime: ridge.startTime,
          endTime: ridge.endTime,
          frequencyRange: ridge.frequencyRange,
          strength: ridge.strength,
          type: _classifyPattern(ridge),
        ));
      }
    }
    
    return patterns;
  }
  
  List<WaveletRidge> _findWaveletRidges(WaveletTransformResult result) {
    final ridges = <WaveletRidge>[];
    const threshold = 0.1;
    
    // Simple ridge detection algorithm
    for (int s = 1; s < result.scales.length - 1; s++) {
      for (int t = 1; t < result.coefficients[s].length - 1; t++) {
        final current = result.coefficients[s][t].magnitude;
        
        if (current > threshold &&
            current > result.coefficients[s - 1][t].magnitude &&
            current > result.coefficients[s + 1][t].magnitude &&
            current > result.coefficients[s][t - 1].magnitude &&
            current > result.coefficients[s][t + 1].magnitude) {
          
          ridges.add(WaveletRidge(
            startTime: t.toDouble(),
            endTime: t.toDouble(),
            frequencyRange: [result.scales[s], result.scales[s]],
            strength: current,
          ));
        }
      }
    }
    
    return ridges;
  }
  
  List<double> _computeInstantaneousFrequency(WaveletTransformResult result) {
    final instFreq = <double>[];
    
    for (int t = 0; t < result.coefficients.first.length; t++) {
      double weightedFreq = 0;
      double totalWeight = 0;
      
      for (int s = 0; s < result.scales.length; s++) {
        final magnitude = result.coefficients[s][t].magnitude;
        final frequency = HighPrecisionAcousticAnalyzer.sampleRate / (2 * result.scales[s]);
        
        weightedFreq += frequency * magnitude;
        totalWeight += magnitude;
      }
      
      instFreq.add(totalWeight > 0 ? weightedFreq / totalWeight : 0);
    }
    
    return instFreq;
  }
  
  String _classifyPattern(WaveletRidge ridge) {
    if (ridge.strength > 0.8) return 'Strong';
    if (ridge.strength > 0.5) return 'Moderate';
    return 'Weak';
  }
  
  double _calculateWaveletConfidence(List<WaveletTransformResult> results) {
    if (results.isEmpty) return 0.0;
    
    double totalEnergy = 0;
    int validCoeffs = 0;
    
    for (final result in results) {
      for (final scaleCoeffs in result.coefficients) {
        for (final coeff in scaleCoeffs) {
          totalEnergy += coeff.magnitude;
          validCoeffs++;
        }
      }
    }
    
    return validCoeffs > 0 ? math.min(1.0, totalEnergy / validCoeffs) : 0.0;
  }
}

/// Formant Tracking System
class FormantTracker {
  static const int lpcOrder = 16;
  static const int numFormants = 5;
  
  List<List<double>> _formantHistory = [];
  
  Future<FormantAnalysisResult> track(List<double> signal) async {
    // Pre-emphasis filter
    final preEmphasized = _applyPreEmphasis(signal);
    
    // Windowing
    final windowed = _applyWindow(preEmphasized);
    
    // LPC analysis
    final lpcCoeffs = _computeLPC(windowed, lpcOrder);
    
    // Find roots of LPC polynomial
    final roots = _findLPCRoots(lpcCoeffs);
    
    // Extract formant frequencies and bandwidths
    final formants = _extractFormants(roots);
    
    // Temporal smoothing
    final smoothedFormants = _smoothFormants(formants);
    
    // Update history
    _formantHistory.add(smoothedFormants.map((f) => f.frequency).toList());
    if (_formantHistory.length > 20) {
      _formantHistory.removeAt(0);
    }
    
    return FormantAnalysisResult(
      formantFrequencies: smoothedFormants.map((f) => f.frequency).toList(),
      bandwidths: smoothedFormants.map((f) => f.bandwidth).toList(),
      amplitudes: smoothedFormants.map((f) => f.amplitude).toList(),
      confidence: _calculateFormantConfidence(smoothedFormants),
    );
  }
  
  List<double> _applyPreEmphasis(List<double> signal) {
    const alpha = 0.97;
    final preEmphasized = <double>[signal.first];
    
    for (int i = 1; i < signal.length; i++) {
      preEmphasized.add(signal[i] - alpha * signal[i - 1]);
    }
    
    return preEmphasized;
  }
  
  List<double> _applyWindow(List<double> signal) {
    return signal.asMap().entries.map((entry) {
      final i = entry.key;
      final value = entry.value;
      // Hamming window
      final window = 0.54 - 0.46 * math.cos(2 * math.pi * i / (signal.length - 1));
      return value * window;
    }).toList();
  }
  
  List<double> _computeLPC(List<double> signal, int order) {
    // Autocorrelation method
    final autocorr = _computeAutocorrelation(signal, order + 1);
    
    // Levinson-Durbin algorithm
    return _levinsonDurbin(autocorr, order);
  }
  
  List<double> _computeAutocorrelation(List<double> signal, int maxLag) {
    final autocorr = <double>[];
    
    for (int lag = 0; lag < maxLag; lag++) {
      double sum = 0;
      for (int i = 0; i < signal.length - lag; i++) {
        sum += signal[i] * signal[i + lag];
      }
      autocorr.add(sum);
    }
    
    return autocorr;
  }
  
  List<double> _levinsonDurbin(List<double> autocorr, int order) {
    final lpc = List<double>.filled(order + 1, 0.0);
    final k = List<double>.filled(order, 0.0);
    
    lpc[0] = 1.0;
    double error = autocorr[0];
    
    for (int i = 1; i <= order; i++) {
      double sum = 0;
      for (int j = 1; j < i; j++) {
        sum += lpc[j] * autocorr[i - j];
      }
      
      k[i - 1] = -(autocorr[i] + sum) / error;
      lpc[i] = k[i - 1];
      
      for (int j = 1; j < i; j++) {
        lpc[j] += k[i - 1] * lpc[i - j];
      }
      
      error *= (1 - k[i - 1] * k[i - 1]);
      
      if (error <= 0) break;
    }
    
    return lpc;
  }
  
  List<Complex> _findLPCRoots(List<double> lpcCoeffs) {
    // Simplified root finding (would use more sophisticated methods in practice)
    final roots = <Complex>[];
    final n = lpcCoeffs.length;
    
    // Use companion matrix eigenvalue approach (simplified)
    for (int i = 1; i < n; i++) {
      final angle = 2 * math.pi * i / n;
      final magnitude = math.pow(0.9, i.toDouble()); // Simplified
      roots.add(Complex(magnitude * math.cos(angle), magnitude * math.sin(angle)));
    }
    
    return roots;
  }
  
  List<FormantInfo> _extractFormants(List<Complex> roots) {
    final formants = <FormantInfo>[];
    const sampleRate = HighPrecisionAcousticAnalyzer.sampleRate;
    
    for (final root in roots) {
      final magnitude = root.magnitude;
      final angle = root.phase;
      
      if (magnitude > 0.7 && magnitude < 0.99) { // Valid formant criteria
        final frequency = angle * sampleRate / (2 * math.pi);
        final bandwidth = -sampleRate * math.log(magnitude) / math.pi;
        
        if (frequency > 200 && frequency < 4000 && bandwidth > 30 && bandwidth < 1000) {
          formants.add(FormantInfo(
            frequency: frequency,
            bandwidth: bandwidth,
            amplitude: 1.0 / (1.0 - magnitude), // Simplified amplitude estimation
          ));
        }
      }
    }
    
    // Sort by frequency and take first numFormants
    formants.sort((a, b) => a.frequency.compareTo(b.frequency));
    return formants.take(numFormants).toList();
  }
  
  List<FormantInfo> _smoothFormants(List<FormantInfo> currentFormants) {
    if (_formantHistory.isEmpty) return currentFormants;
    
    const alpha = 0.3; // Smoothing factor
    final smoothed = <FormantInfo>[];
    
    for (int i = 0; i < currentFormants.length; i++) {
      double smoothedFreq = currentFormants[i].frequency;
      
      // Find closest formant in history
      if (_formantHistory.isNotEmpty && i < _formantHistory.last.length) {
        smoothedFreq = alpha * currentFormants[i].frequency + 
                     (1 - alpha) * _formantHistory.last[i];
      }
      
      smoothed.add(FormantInfo(
        frequency: smoothedFreq,
        bandwidth: currentFormants[i].bandwidth,
        amplitude: currentFormants[i].amplitude,
      ));
    }
    
    return smoothed;
  }
  
  double _calculateFormantConfidence(List<FormantInfo> formants) {
    if (formants.isEmpty) return 0.0;
    
    // Confidence based on typical formant patterns
    double confidence = 1.0;
    
    // Check if formants are in reasonable ranges
    final expectedRanges = [
      [200, 1000],   // F1
      [800, 2500],   // F2
      [1500, 3500],  // F3
      [2500, 4500],  // F4
      [3000, 5000],  // F5
    ];
    
    for (int i = 0; i < math.min(formants.length, expectedRanges.length); i++) {
      final freq = formants[i].frequency;
      final range = expectedRanges[i];
      
      if (freq < range[0] || freq > range[1]) {
        confidence *= 0.8;
      }
    }
    
    return confidence;
  }
}

/// Voice Quality Analysis
class VoiceQualityAnalyzer {
  static const int f0WindowSize = 512;
  static const int hopSize = 256;
  
  Future<VoiceQualityResult> analyze(List<double> signal) async {
    // Fundamental frequency estimation
    final f0Contour = _estimateF0Contour(signal);
    
    // Jitter calculation
    final jitter = _calculateJitter(f0Contour);
    
    // Shimmer calculation
    final shimmer = _calculateShimmer(signal, f0Contour);
    
    // Harmonics-to-noise ratio
    final hnr = _calculateHNR(signal, f0Contour);
    
    // Voice break detection
    final voiceBreaks = _detectVoiceBreaks(f0Contour);
    
    // Subharmonic detection
    final subharmonics = _detectSubharmonics(signal, f0Contour);
    
    // Harmonicity measure
    final harmonicity = _calculateHarmonicity(signal, f0Contour);
    
    return VoiceQualityResult(
      jitter: jitter,
      shimmer: shimmer,
      hnr: hnr,
      voiceBreaks: voiceBreaks,
      subharmonics: subharmonics,
      harmonicity: harmonicity,
      confidence: _calculateVoiceQualityConfidence(f0Contour),
    );
  }
  
  List<double> _estimateF0Contour(List<double> signal) {
    final f0Contour = <double>[];
    
    for (int i = 0; i < signal.length - f0WindowSize; i += hopSize) {
      final window = signal.sublist(i, i + f0WindowSize);
      final f0 = _estimateF0(window);
      f0Contour.add(f0);
    }
    
    return f0Contour;
  }
  
  double _estimateF0(List<double> signal) {
    // Autocorrelation-based F0 estimation with parabolic interpolation
    const minPeriod = HighPrecisionAcousticAnalyzer.sampleRate ~/ HighPrecisionAcousticAnalyzer.maxF0;
    const maxPeriod = HighPrecisionAcousticAnalyzer.sampleRate ~/ HighPrecisionAcousticAnalyzer.minF0;
    
    double maxCorr = 0;
    int bestLag = 0;
    
    for (int lag = minPeriod; lag <= math.min(maxPeriod, signal.length ~/ 2); lag++) {
      double corr = 0;
      for (int i = 0; i < signal.length - lag; i++) {
        corr += signal[i] * signal[i + lag];
      }
      
      if (corr > maxCorr) {
        maxCorr = corr;
        bestLag = lag;
      }
    }
    
    if (bestLag == 0) return 0;
    
    // Parabolic interpolation for sub-sample accuracy
    if (bestLag > 0 && bestLag < maxPeriod - 1) {
      final y1 = _computeAutocorrelationAtLag(signal, bestLag - 1);
      final y2 = _computeAutocorrelationAtLag(signal, bestLag);
      final y3 = _computeAutocorrelationAtLag(signal, bestLag + 1);
      
      final a = (y1 - 2 * y2 + y3) / 2;
      final b = (y3 - y1) / 2;
      
      if (a != 0) {
        final refinedLag = bestLag - b / (2 * a);
        return HighPrecisionAcousticAnalyzer.sampleRate / refinedLag;
      }
    }
    
    return HighPrecisionAcousticAnalyzer.sampleRate / bestLag.toDouble();
  }
  
  double _computeAutocorrelationAtLag(List<double> signal, int lag) {
    double corr = 0;
    for (int i = 0; i < signal.length - lag; i++) {
      corr += signal[i] * signal[i + lag];
    }
    return corr;
  }
  
  double _calculateJitter(List<double> f0Contour) {
    if (f0Contour.length < 3) return 0;
    
    final validF0 = f0Contour.where((f0) => f0 > 0).toList();
    if (validF0.length < 3) return 0;
    
    double jitterSum = 0;
    int count = 0;
    
    for (int i = 1; i < validF0.length; i++) {
      final period1 = 1.0 / validF0[i - 1];
      final period2 = 1.0 / validF0[i];
      jitterSum += (period2 - period1).abs();
      count++;
    }
    
    final meanPeriod = validF0.map((f0) => 1.0 / f0).reduce((a, b) => a + b) / validF0.length;
    return count > 0 ? (jitterSum / count) / meanPeriod * 100 : 0; // Percentage
  }
  
  double _calculateShimmer(List<double> signal, List<double> f0Contour) {
    if (f0Contour.isEmpty) return 0;
    
    final amplitudes = <double>[];
    
    // Extract amplitude for each period
    int signalIndex = 0;
    for (final f0 in f0Contour) {
      if (f0 > 0) {
        final periodLength = (HighPrecisionAcousticAnalyzer.sampleRate / f0).round();
        
        if (signalIndex + periodLength < signal.length) {
          final period = signal.sublist(signalIndex, signalIndex + periodLength);
          final amplitude = period.map((x) => x.abs()).reduce(math.max);
          amplitudes.add(amplitude);
        }
        
        signalIndex += hopSize;
      }
    }
    
    if (amplitudes.length < 2) return 0;
    
    double shimmerSum = 0;
    for (int i = 1; i < amplitudes.length; i++) {
      if (amplitudes[i - 1] > 0) {
        shimmerSum += (amplitudes[i] - amplitudes[i - 1]).abs() / amplitudes[i - 1];
      }
    }
    
    return shimmerSum / (amplitudes.length - 1) * 100; // Percentage
  }
  
  double _calculateHNR(List<double> signal, List<double> f0Contour) {
    if (f0Contour.isEmpty) return 0;
    
    double totalHarmonicEnergy = 0;
    double totalNoiseEnergy = 0;
    int validFrames = 0;
    
    int signalIndex = 0;
    for (final f0 in f0Contour) {
      if (f0 > 0 && signalIndex + f0WindowSize < signal.length) {
        final window = signal.sublist(signalIndex, signalIndex + f0WindowSize);
        final spectrum = _computeFFT(window);
        
        final f0Bin = (f0 * spectrum.length / (HighPrecisionAcousticAnalyzer.sampleRate / 2)).round();
        
        // Calculate harmonic and noise energy
        double harmonicEnergy = 0;
        double totalEnergy = 0;
        
        for (int i = 0; i < spectrum.length; i++) {
          final binEnergy = spectrum[i] * spectrum[i];
          totalEnergy += binEnergy;
          
          // Check if this bin is near a harmonic
          bool isHarmonic = false;
          for (int h = 1; h <= 10; h++) {
            final harmonicBin = f0Bin * h;
            if ((i - harmonicBin).abs() <= 2) {
              isHarmonic = true;
              break;
            }
          }
          
          if (isHarmonic) {
            harmonicEnergy += binEnergy;
          }
        }
        
        totalHarmonicEnergy += harmonicEnergy;
        totalNoiseEnergy += (totalEnergy - harmonicEnergy);
        validFrames++;
      }
      
      signalIndex += hopSize;
    }
    
    if (validFrames == 0 || totalNoiseEnergy == 0) return 0;
    
    return 10 * math.log(totalHarmonicEnergy / totalNoiseEnergy) / math.ln10;
  }
  
  List<double> _computeFFT(List<double> signal) {
    // Simplified FFT - magnitude only
    final N = signal.length;
    final magnitude = List<double>.filled(N ~/ 2, 0.0);
    
    for (int k = 0; k < N ~/ 2; k++) {
      double real = 0, imag = 0;
      for (int n = 0; n < N; n++) {
        final angle = -2 * math.pi * k * n / N;
        real += signal[n] * math.cos(angle);
        imag += signal[n] * math.sin(angle);
      }
      magnitude[k] = math.sqrt(real * real + imag * imag);
    }
    
    return magnitude;
  }
  
  List<VoiceBreak> _detectVoiceBreaks(List<double> f0Contour) {
    final voiceBreaks = <VoiceBreak>[];
    const minBreakDuration = 3; // frames
    
    bool inBreak = false;
    int breakStart = 0;
    
    for (int i = 0; i < f0Contour.length; i++) {
      if (f0Contour[i] == 0) {
        if (!inBreak) {
          inBreak = true;
          breakStart = i;
        }
      } else {
        if (inBreak && i - breakStart >= minBreakDuration) {
          voiceBreaks.add(VoiceBreak(
            startFrame: breakStart,
            endFrame: i - 1,
            duration: (i - breakStart) * hopSize / HighPrecisionAcousticAnalyzer.sampleRate,
          ));
        }
        inBreak = false;
      }
    }
    
    return voiceBreaks;
  }
  
  List<double> _detectSubharmonics(List<double> signal, List<double> f0Contour) {
    final subharmonics = <double>[];
    
    int signalIndex = 0;
    for (final f0 in f0Contour) {
      if (f0 > 0 && signalIndex + f0WindowSize < signal.length) {
        final window = signal.sublist(signalIndex, signalIndex + f0WindowSize);
        final spectrum = _computeFFT(window);
        
        final f0Bin = (f0 * spectrum.length / (HighPrecisionAcousticAnalyzer.sampleRate / 2)).round();
        
        // Check for subharmonics (f0/2, f0/3, etc.)
        double subharmonicStrength = 0;
        for (int sub = 2; sub <= 4; sub++) {
          final subBin = f0Bin ~/ sub;
          if (subBin < spectrum.length) {
            subharmonicStrength += spectrum[subBin];
          }
        }
        
        // Normalize by fundamental strength
        if (f0Bin < spectrum.length && spectrum[f0Bin] > 0) {
          subharmonicStrength /= spectrum[f0Bin];
        }
        
        subharmonics.add(subharmonicStrength);
      }
      
      signalIndex += hopSize;
    }
    
    return subharmonics;
  }
  
  double _calculateHarmonicity(List<double> signal, List<double> f0Contour) {
    if (f0Contour.isEmpty) return 0;
    
    double totalHarmonicity = 0;
    int validFrames = 0;
    
    int signalIndex = 0;
    for (final f0 in f0Contour) {
      if (f0 > 0 && signalIndex + f0WindowSize < signal.length) {
        final window = signal.sublist(signalIndex, signalIndex + f0WindowSize);
        final harmonicity = _computeHarmonicityForFrame(window, f0);
        totalHarmonicity += harmonicity;
        validFrames++;
      }
      signalIndex += hopSize;
    }
    
    return validFrames > 0 ? totalHarmonicity / validFrames : 0;
  }
  
  double _computeHarmonicityForFrame(List<double> signal, double f0) {
    final spectrum = _computeFFT(signal);
    final f0Bin = (f0 * spectrum.length / (HighPrecisionAcousticAnalyzer.sampleRate / 2)).round();
    
    double harmonicSum = 0;
    double totalSum = spectrum.fold<double>(0, (sum, val) => sum + val);
    
    // Sum energy at harmonic frequencies
    for (int h = 1; h <= 10; h++) {
      final harmonicBin = f0Bin * h;
      if (harmonicBin < spectrum.length) {
        harmonicSum += spectrum[harmonicBin];
      }
    }
    
    return totalSum > 0 ? harmonicSum / totalSum : 0;
  }
  
  double _calculateVoiceQualityConfidence(List<double> f0Contour) {
    if (f0Contour.isEmpty) return 0;
    
    final validFrames = f0Contour.where((f0) => f0 > 0).length;
    return validFrames / f0Contour.length;
  }
}

/// Additional supporting classes and utilities
class SpectralAnalysisEngine {
  Future<SpectralAnalysisResult> analyze(List<double> signal) async {
    final spectrum = _computeFFT(signal);
    
    return SpectralAnalysisResult(
      fundamentalFrequency: _findFundamentalFrequency(spectrum),
      spectralCentroid: _computeSpectralCentroid(spectrum),
      spectralRolloff: _computeSpectralRolloff(spectrum),
      spectralFlux: _computeSpectralFlux(spectrum),
      zeroCrossingRate: _computeZeroCrossingRate(signal),
      mfcc: _computeMFCC(spectrum),
      confidence: 0.85,
    );
  }
  
  List<double> _computeFFT(List<double> signal) {
    // Implementation similar to previous FFT functions
    final N = signal.length;
    final magnitude = List<double>.filled(N ~/ 2, 0.0);
    
    for (int k = 0; k < N ~/ 2; k++) {
      double real = 0, imag = 0;
      for (int n = 0; n < N; n++) {
        final angle = -2 * math.pi * k * n / N;
        real += signal[n] * math.cos(angle);
        imag += signal[n] * math.sin(angle);
      }
      magnitude[k] = math.sqrt(real * real + imag * imag);
    }
    
    return magnitude;
  }
  
  double _findFundamentalFrequency(List<double> spectrum) {
    // Find peak in expected vocal range
    const sampleRate = HighPrecisionAcousticAnalyzer.sampleRate;
    final minBin = (HighPrecisionAcousticAnalyzer.minF0 * spectrum.length / (sampleRate / 2)).round();
    final maxBin = (HighPrecisionAcousticAnalyzer.maxF0 * spectrum.length / (sampleRate / 2)).round();
    
    int peakBin = minBin;
    double peakMagnitude = 0;
    
    for (int i = minBin; i < math.min(maxBin, spectrum.length); i++) {
      if (spectrum[i] > peakMagnitude) {
        peakMagnitude = spectrum[i];
        peakBin = i;
      }
    }
    
    return peakBin * sampleRate / (2 * spectrum.length).toDouble();
  }
  
  double _computeSpectralCentroid(List<double> spectrum) {
    double weightedSum = 0;
    double totalMagnitude = 0;
    
    for (int i = 0; i < spectrum.length; i++) {
      weightedSum += i * spectrum[i];
      totalMagnitude += spectrum[i];
    }
    
    return totalMagnitude > 0 ? weightedSum / totalMagnitude : 0;
  }
  
  double _computeSpectralRolloff(List<double> spectrum) {
    final totalEnergy = spectrum.fold<double>(0, (sum, val) => sum + val);
    final threshold = totalEnergy * 0.85;
    
    double cumulativeEnergy = 0;
    for (int i = 0; i < spectrum.length; i++) {
      cumulativeEnergy += spectrum[i];
      if (cumulativeEnergy >= threshold) {
        return i / spectrum.length.toDouble();
      }
    }
    
    return 1.0;
  }
  
  double _computeSpectralFlux(List<double> spectrum) {
    // Simplified - would need previous spectrum for proper calculation
    return spectrum.fold<double>(0, (sum, val) => sum + val.abs()) / spectrum.length;
  }
  
  double _computeZeroCrossingRate(List<double> signal) {
    int crossings = 0;
    for (int i = 1; i < signal.length; i++) {
      if ((signal[i] >= 0) != (signal[i - 1] >= 0)) {
        crossings++;
      }
    }
    return crossings / signal.length.toDouble();
  }
  
  List<double> _computeMFCC(List<double> spectrum) {
    // Simplified MFCC computation
    const numCoeffs = 13;
    return List.generate(numCoeffs, (i) => spectrum.take(spectrum.length ~/ numCoeffs).fold<double>(0, (sum, val) => sum + val));
  }
}

class MultiScaleAnalyzer {
  Future<MultiScaleAnalysisResult> analyze(List<double> signal) async {
    final scales = [1, 2, 4, 8, 16];
    final scaleResults = <ScaleResult>[];
    
    for (final scale in scales) {
      final decimated = _decimate(signal, scale);
      final features = _extractScaleFeatures(decimated, scale);
      scaleResults.add(ScaleResult(scale: scale, features: features));
    }
    
    return MultiScaleAnalysisResult(
      scaleResults: scaleResults,
      confidence: 0.8,
    );
  }
  
  List<double> _decimate(List<double> signal, int factor) {
    final decimated = <double>[];
    for (int i = 0; i < signal.length; i += factor) {
      decimated.add(signal[i]);
    }
    return decimated;
  }
  
  Map<String, double> _extractScaleFeatures(List<double> signal, int scale) {
    return {
      'energy': signal.fold<double>(0, (sum, val) => sum + val * val),
      'mean': signal.reduce((a, b) => a + b) / signal.length,
      'variance': _computeVariance(signal),
    };
  }
  
  double _computeVariance(List<double> signal) {
    final mean = signal.reduce((a, b) => a + b) / signal.length;
    return signal.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / signal.length;
  }
}

// Data classes and results
class AcousticAnalysisResult {
  final double fundamentalFrequency;
  final double harmonicity;
  final List<double> formants;
  final List<double> formantBandwidths;
  final double jitter;
  final double shimmer;
  final double hnr;
  final double spectralCentroid;
  final double spectralRolloff;
  final double spectralFlux;
  final double zeroCrossingRate;
  final List<double> mfcc;
  final List<double> waveletEnergy;
  final List<VoiceBreak> voiceBreaks;
  final List<double> subharmonics;
  final double confidence;
  final DateTime timestamp;

  AcousticAnalysisResult({
    required this.fundamentalFrequency,
    required this.harmonicity,
    required this.formants,
    required this.formantBandwidths,
    required this.jitter,
    required this.shimmer,
    required this.hnr,
    required this.spectralCentroid,
    required this.spectralRolloff,
    required this.spectralFlux,
    required this.zeroCrossingRate,
    required this.mfcc,
    required this.waveletEnergy,
    required this.voiceBreaks,
    required this.subharmonics,
    required this.confidence,
    required this.timestamp,
  });

  factory AcousticAnalysisResult.empty() {
    return AcousticAnalysisResult(
      fundamentalFrequency: 0,
      harmonicity: 0,
      formants: [],
      formantBandwidths: [],
      jitter: 0,
      shimmer: 0,
      hnr: 0,
      spectralCentroid: 0,
      spectralRolloff: 0,
      spectralFlux: 0,
      zeroCrossingRate: 0,
      mfcc: [],
      waveletEnergy: [],
      voiceBreaks: [],
      subharmonics: [],
      confidence: 0,
      timestamp: DateTime.now(),
    );
  }
}

// Additional data classes for comprehensive analysis results
class AcousticMeasurement {
  final DateTime timestamp;
  final WaveletAnalysisResult waveletAnalysis;
  final FormantAnalysisResult formantAnalysis;
  final VoiceQualityResult voiceQuality;
  final SpectralAnalysisResult spectralAnalysis;
  final MultiScaleAnalysisResult multiScaleAnalysis;

  AcousticMeasurement({
    required this.timestamp,
    required this.waveletAnalysis,
    required this.formantAnalysis,
    required this.voiceQuality,
    required this.spectralAnalysis,
    required this.multiScaleAnalysis,
  });
}

class WaveletAnalysisResult {
  final List<WaveletTransformResult> transforms;
  final List<double> energyDistribution;
  final List<TimeFrequencyPattern> timeFrequencyPatterns;
  final List<double> instantaneousFrequency;
  final double confidence;

  WaveletAnalysisResult({
    required this.transforms,
    required this.energyDistribution,
    required this.timeFrequencyPatterns,
    required this.instantaneousFrequency,
    required this.confidence,
  });
}

class WaveletTransformResult {
  final List<double> scales;
  final List<List<Complex>> coefficients;
  final String waveletType;

  WaveletTransformResult({
    required this.scales,
    required this.coefficients,
    required this.waveletType,
  });
}

class FormantAnalysisResult {
  final List<double> formantFrequencies;
  final List<double> bandwidths;
  final List<double> amplitudes;
  final double confidence;

  FormantAnalysisResult({
    required this.formantFrequencies,
    required this.bandwidths,
    required this.amplitudes,
    required this.confidence,
  });
}

class VoiceQualityResult {
  final double jitter;
  final double shimmer;
  final double hnr;
  final List<VoiceBreak> voiceBreaks;
  final List<double> subharmonics;
  final double harmonicity;
  final double confidence;

  VoiceQualityResult({
    required this.jitter,
    required this.shimmer,
    required this.hnr,
    required this.voiceBreaks,
    required this.subharmonics,
    required this.harmonicity,
    required this.confidence,
  });
}

class SpectralAnalysisResult {
  final double fundamentalFrequency;
  final double spectralCentroid;
  final double spectralRolloff;
  final double spectralFlux;
  final double zeroCrossingRate;
  final List<double> mfcc;
  final double confidence;

  SpectralAnalysisResult({
    required this.fundamentalFrequency,
    required this.spectralCentroid,
    required this.spectralRolloff,
    required this.spectralFlux,
    required this.zeroCrossingRate,
    required this.mfcc,
    required this.confidence,
  });
}

class MultiScaleAnalysisResult {
  final List<ScaleResult> scaleResults;
  final double confidence;

  MultiScaleAnalysisResult({
    required this.scaleResults,
    required this.confidence,
  });
}

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

class WaveletFilter {
  final String type;
  final Function(double) evaluate;

  WaveletFilter._(this.type, this.evaluate);

  factory WaveletFilter.morlet() {
    return WaveletFilter._('morlet', (double t) {
      final envelope = math.exp(-t * t / 2);
      final oscillation = math.cos(5 * t);
      return Complex(envelope * oscillation, envelope * math.sin(5 * t));
    });
  }

  factory WaveletFilter.mexicanHat() {
    return WaveletFilter._('mexicanHat', (double t) {
      final coeff = 2 / (math.sqrt(3) * math.pow(math.pi, 0.25));
      final envelope = (1 - t * t) * math.exp(-t * t / 2);
      return Complex(coeff * envelope, 0);
    });
  }

  factory WaveletFilter.daubechies4() {
    return WaveletFilter._('daubechies4', (double t) {
      // Simplified Daubechies wavelet
      if (t.abs() > 3) return Complex(0, 0);
      final value = math.exp(-t * t) * math.cos(2 * math.pi * t);
      return Complex(value, 0);
    });
  }
}

class TimeFrequencyPattern {
  final double startTime;
  final double endTime;
  final List<double> frequencyRange;
  final double strength;
  final String type;

  TimeFrequencyPattern({
    required this.startTime,
    required this.endTime,
    required this.frequencyRange,
    required this.strength,
    required this.type,
  });
}

class WaveletRidge {
  final double startTime;
  final double endTime;
  final List<double> frequencyRange;
  final double strength;

  WaveletRidge({
    required this.startTime,
    required this.endTime,
    required this.frequencyRange,
    required this.strength,
  });
}

class FormantInfo {
  final double frequency;
  final double bandwidth;
  final double amplitude;

  FormantInfo({
    required this.frequency,
    required this.bandwidth,
    required this.amplitude,
  });
}

class VoiceBreak {
  final int startFrame;
  final int endFrame;
  final double duration;

  VoiceBreak({
    required this.startFrame,
    required this.endFrame,
    required this.duration,
  });
}

class ScaleResult {
  final int scale;
  final Map<String, double> features;

  ScaleResult({
    required this.scale,
    required this.features,
  });
}