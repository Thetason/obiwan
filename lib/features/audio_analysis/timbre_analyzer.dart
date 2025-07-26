import 'dart:math' as math;
import 'dart:typed_data';
import 'package:fftea/fftea.dart';

/// Advanced voice timbre analyzer using spectral features
class TimbreAnalyzer {
  static const int fftSize = 2048;
  static const int mfccCount = 13;
  static const int melFilterCount = 40;
  
  final int sampleRate;
  final FFT fft;
  
  // Mel filterbank
  late List<List<double>> melFilterbank;
  
  TimbreAnalyzer({this.sampleRate = 16000}) 
    : fft = FFT(fftSize) {
    _initializeMelFilterbank();
  }
  
  /// Analyze timbre characteristics from audio samples
  Future<TimbreAnalysis> analyzeTimbre(List<double> audioSamples) async {
    // Extract various spectral features
    final spectralCentroid = await _computeSpectralCentroid(audioSamples);
    final spectralRolloff = await _computeSpectralRolloff(audioSamples);
    final spectralFlux = await _computeSpectralFlux(audioSamples);
    final spectralFlatness = await _computeSpectralFlatness(audioSamples);
    final mfccFeatures = await _computeMFCC(audioSamples);
    final formants = await _extractFormants(audioSamples);
    final harmonicFeatures = await _analyzeHarmonics(audioSamples);
    
    // Compute timbre descriptors
    final brightness = _calculateBrightness(spectralCentroid);
    final warmth = _calculateWarmth(spectralCentroid, formants);
    final roughness = _calculateRoughness(spectralFlux, harmonicFeatures);
    final breathiness = _calculateBreathiness(spectralFlatness, harmonicFeatures);
    
    // Voice quality assessment
    final voiceQuality = _assessVoiceQuality(
      brightness: brightness,
      warmth: warmth,
      roughness: roughness,
      breathiness: breathiness,
      formants: formants,
    );
    
    return TimbreAnalysis(
      spectralCentroid: spectralCentroid,
      spectralRolloff: spectralRolloff,
      spectralFlux: spectralFlux,
      spectralFlatness: spectralFlatness,
      mfccCoefficients: mfccFeatures,
      formants: formants,
      brightness: brightness,
      warmth: warmth,
      roughness: roughness,
      breathiness: breathiness,
      voiceQuality: voiceQuality,
      harmonicRatio: harmonicFeatures['harmonicRatio'] ?? 0.0,
      shimmer: harmonicFeatures['shimmer'] ?? 0.0,
      jitter: harmonicFeatures['jitter'] ?? 0.0,
    );
  }
  
  /// Initialize Mel filterbank for MFCC computation
  void _initializeMelFilterbank() {
    melFilterbank = List.generate(melFilterCount, (_) => List.filled(fftSize ~/ 2 + 1, 0.0));
    
    final melMin = _hzToMel(0);
    final melMax = _hzToMel(sampleRate / 2);
    final melPoints = List.generate(melFilterCount + 2, (i) => 
      melMin + i * (melMax - melMin) / (melFilterCount + 1)
    );
    
    final hzPoints = melPoints.map((mel) => _melToHz(mel)).toList();
    final binPoints = hzPoints.map((hz) => 
      ((fftSize + 1) * hz / sampleRate).floor()
    ).toList();
    
    for (int i = 1; i <= melFilterCount; i++) {
      for (int j = binPoints[i - 1]; j < binPoints[i]; j++) {
        if (j < melFilterbank[i - 1].length) {
          melFilterbank[i - 1][j] = 
            (j - binPoints[i - 1]) / (binPoints[i] - binPoints[i - 1]);
        }
      }
      
      for (int j = binPoints[i]; j < binPoints[i + 1]; j++) {
        if (j < melFilterbank[i - 1].length) {
          melFilterbank[i - 1][j] = 
            (binPoints[i + 1] - j) / (binPoints[i + 1] - binPoints[i]);
        }
      }
    }
  }
  
  /// Compute spectral centroid (brightness indicator)
  Future<List<double>> _computeSpectralCentroid(List<double> audioSamples) async {
    final centroids = <double>[];
    final hopSize = fftSize ~/ 2;
    
    for (int start = 0; start <= audioSamples.length - fftSize; start += hopSize) {
      final frame = audioSamples.sublist(start, start + fftSize);
      final windowed = _applyWindow(frame);
      final spectrum = fft.realFft(Float32List.fromList(windowed));
      
      double weightedSum = 0;
      double magnitudeSum = 0;
      
      for (int i = 0; i < spectrum.length; i++) {
        final magnitude = _getMagnitude(spectrum[i]);
        final frequency = i * sampleRate / fftSize;
        weightedSum += frequency * magnitude;
        magnitudeSum += magnitude;
      }
      
      centroids.add(magnitudeSum > 0 ? weightedSum / magnitudeSum : 0);
    }
    
    return centroids;
  }
  
  /// Compute spectral rolloff (frequency below which 85% of energy is contained)
  Future<List<double>> _computeSpectralRolloff(List<double> audioSamples) async {
    final rolloffs = <double>[];
    final hopSize = fftSize ~/ 2;
    final threshold = 0.85;
    
    for (int start = 0; start <= audioSamples.length - fftSize; start += hopSize) {
      final frame = audioSamples.sublist(start, start + fftSize);
      final windowed = _applyWindow(frame);
      final spectrum = fft.realFft(Float32List.fromList(windowed));
      
      double totalEnergy = 0;
      final magnitudes = <double>[];
      
      for (final bin in spectrum) {
        final magnitude = _getMagnitude(bin);
        magnitudes.add(magnitude);
        totalEnergy += magnitude * magnitude;
      }
      
      double cumulativeEnergy = 0;
      int rolloffBin = 0;
      
      for (int i = 0; i < magnitudes.length; i++) {
        cumulativeEnergy += magnitudes[i] * magnitudes[i];
        if (cumulativeEnergy >= threshold * totalEnergy) {
          rolloffBin = i;
          break;
        }
      }
      
      rolloffs.add(rolloffBin * sampleRate / fftSize);
    }
    
    return rolloffs;
  }
  
  /// Compute spectral flux (measure of spectral change)
  Future<List<double>> _computeSpectralFlux(List<double> audioSamples) async {
    final fluxValues = <double>[];
    final hopSize = fftSize ~/ 2;
    List<double>? previousMagnitudes;
    
    for (int start = 0; start <= audioSamples.length - fftSize; start += hopSize) {
      final frame = audioSamples.sublist(start, start + fftSize);
      final windowed = _applyWindow(frame);
      final spectrum = fft.realFft(Float32List.fromList(windowed));
      
      final magnitudes = spectrum.map((bin) => _getMagnitude(bin)).toList();
      
      if (previousMagnitudes != null) {
        double flux = 0;
        for (int i = 0; i < magnitudes.length && i < previousMagnitudes.length; i++) {
          final diff = magnitudes[i] - previousMagnitudes[i];
          if (diff > 0) flux += diff * diff;
        }
        fluxValues.add(math.sqrt(flux));
      } else {
        fluxValues.add(0);
      }
      
      previousMagnitudes = magnitudes;
    }
    
    return fluxValues;
  }
  
  /// Compute spectral flatness (tonality measure)
  Future<List<double>> _computeSpectralFlatness(List<double> audioSamples) async {
    final flatnessValues = <double>[];
    final hopSize = fftSize ~/ 2;
    
    for (int start = 0; start <= audioSamples.length - fftSize; start += hopSize) {
      final frame = audioSamples.sublist(start, start + fftSize);
      final windowed = _applyWindow(frame);
      final spectrum = fft.realFft(Float32List.fromList(windowed));
      
      double geometricMean = 0;
      double arithmeticMean = 0;
      int count = 0;
      
      for (int i = 1; i < spectrum.length; i++) {
        final magnitude = _getMagnitude(spectrum[i]);
        if (magnitude > 0) {
          geometricMean += math.log(magnitude);
          arithmeticMean += magnitude;
          count++;
        }
      }
      
      if (count > 0 && arithmeticMean > 0) {
        geometricMean = math.exp(geometricMean / count);
        arithmeticMean = arithmeticMean / count;
        flatnessValues.add(geometricMean / arithmeticMean);
      } else {
        flatnessValues.add(0);
      }
    }
    
    return flatnessValues;
  }
  
  /// Compute MFCC (Mel-frequency cepstral coefficients)
  Future<List<List<double>>> _computeMFCC(List<double> audioSamples) async {
    final mfccFrames = <List<double>>[];
    final hopSize = fftSize ~/ 2;
    
    for (int start = 0; start <= audioSamples.length - fftSize; start += hopSize) {
      final frame = audioSamples.sublist(start, start + fftSize);
      final windowed = _applyWindow(frame);
      final spectrum = fft.realFft(Float32List.fromList(windowed));
      
      // Apply mel filterbank
      final melEnergies = List<double>.filled(melFilterCount, 0);
      for (int i = 0; i < melFilterCount; i++) {
        for (int j = 0; j < spectrum.length && j < melFilterbank[i].length; j++) {
          final magnitude = _getMagnitude(spectrum[j]);
          melEnergies[i] += magnitude * magnitude * melFilterbank[i][j];
        }
        melEnergies[i] = math.log(melEnergies[i] + 1e-10);
      }
      
      // DCT to get MFCCs
      final mfcc = List<double>.filled(mfccCount, 0);
      for (int i = 0; i < mfccCount; i++) {
        for (int j = 0; j < melFilterCount; j++) {
          mfcc[i] += melEnergies[j] * 
            math.cos(math.pi * i * (j + 0.5) / melFilterCount);
        }
        mfcc[i] *= math.sqrt(2.0 / melFilterCount);
      }
      
      mfccFrames.add(mfcc);
    }
    
    return mfccFrames;
  }
  
  /// Extract formant frequencies using LPC
  Future<List<double>> _extractFormants(List<double> audioSamples) async {
    // Simplified formant extraction using peak detection
    final formants = <double>[];
    
    // Use middle portion of audio for stable analysis
    final midStart = audioSamples.length ~/ 2 - fftSize ~/ 2;
    if (midStart < 0 || midStart + fftSize > audioSamples.length) {
      return [700, 1220, 2600]; // Default formants
    }
    
    final frame = audioSamples.sublist(midStart, midStart + fftSize);
    final windowed = _applyWindow(frame);
    final spectrum = fft.realFft(Float32List.fromList(windowed));
    
    // Smooth spectrum for formant detection
    final smoothedMagnitudes = <double>[];
    for (int i = 0; i < spectrum.length; i++) {
      double sum = 0;
      int count = 0;
      for (int j = math.max(0, i - 2); j < math.min(spectrum.length, i + 3); j++) {
        sum += _getMagnitude(spectrum[j]);
        count++;
      }
      smoothedMagnitudes.add(sum / count);
    }
    
    // Find peaks (formants)
    for (int i = 1; i < smoothedMagnitudes.length - 1; i++) {
      if (smoothedMagnitudes[i] > smoothedMagnitudes[i - 1] &&
          smoothedMagnitudes[i] > smoothedMagnitudes[i + 1]) {
        final frequency = i * sampleRate / fftSize;
        if (frequency > 200 && frequency < 5000) {
          formants.add(frequency);
          if (formants.length >= 4) break;
        }
      }
    }
    
    // Ensure we have at least 3 formants
    while (formants.length < 3) {
      formants.add(formants.isEmpty ? 700 : formants.last + 500);
    }
    
    return formants.take(4).toList();
  }
  
  /// Analyze harmonic structure
  Future<Map<String, double>> _analyzeHarmonics(List<double> audioSamples) async {
    final hopSize = fftSize ~/ 2;
    final harmonicRatios = <double>[];
    final shimmerValues = <double>[];
    final jitterValues = <double>[];
    
    List<double>? previousAmplitudes;
    double? previousPeriod;
    
    for (int start = 0; start <= audioSamples.length - fftSize; start += hopSize) {
      final frame = audioSamples.sublist(start, start + fftSize);
      
      // Estimate fundamental frequency
      final f0 = _estimateFundamentalFrequency(frame);
      if (f0 > 0) {
        final windowed = _applyWindow(frame);
        final spectrum = fft.realFft(Float32List.fromList(windowed));
        
        // Calculate harmonic ratio
        double harmonicEnergy = 0;
        double totalEnergy = 0;
        
        for (int h = 1; h <= 10; h++) {
          final harmonicBin = (h * f0 * fftSize / sampleRate).round();
          if (harmonicBin < spectrum.length) {
            harmonicEnergy += _getMagnitude(spectrum[harmonicBin]);
          }
        }
        
        for (final bin in spectrum) {
          totalEnergy += _getMagnitude(bin);
        }
        
        if (totalEnergy > 0) {
          harmonicRatios.add(harmonicEnergy / totalEnergy);
        }
        
        // Calculate shimmer (amplitude variation)
        final amplitude = frame.map((s) => s.abs()).reduce(math.max);
        if (previousAmplitudes != null && previousAmplitudes.isNotEmpty) {
          final variation = (amplitude - previousAmplitudes.last).abs() / 
                           ((amplitude + previousAmplitudes.last) / 2);
          shimmerValues.add(variation * 100);
        }
        if (previousAmplitudes == null) previousAmplitudes = [];
        previousAmplitudes.add(amplitude);
        
        // Calculate jitter (frequency variation)
        final period = sampleRate / f0;
        if (previousPeriod != null) {
          final variation = (period - previousPeriod).abs() / 
                           ((period + previousPeriod) / 2);
          jitterValues.add(variation * 100);
        }
        previousPeriod = period;
      }
    }
    
    return {
      'harmonicRatio': harmonicRatios.isEmpty ? 0 : 
        harmonicRatios.reduce((a, b) => a + b) / harmonicRatios.length,
      'shimmer': shimmerValues.isEmpty ? 0 : 
        shimmerValues.reduce((a, b) => a + b) / shimmerValues.length,
      'jitter': jitterValues.isEmpty ? 0 : 
        jitterValues.reduce((a, b) => a + b) / jitterValues.length,
    };
  }
  
  /// Estimate fundamental frequency using autocorrelation
  double _estimateFundamentalFrequency(List<double> frame) {
    final minPeriod = sampleRate ~/ 500; // 500 Hz max
    final maxPeriod = sampleRate ~/ 50;  // 50 Hz min
    
    double maxCorrelation = 0;
    int bestLag = 0;
    
    for (int lag = minPeriod; lag < math.min(maxPeriod, frame.length ~/ 2); lag++) {
      double correlation = 0;
      for (int i = 0; i < frame.length - lag; i++) {
        correlation += frame[i] * frame[i + lag];
      }
      
      if (correlation > maxCorrelation) {
        maxCorrelation = correlation;
        bestLag = lag;
      }
    }
    
    return bestLag > 0 ? sampleRate / bestLag : 0;
  }
  
  /// Calculate brightness from spectral centroid
  double _calculateBrightness(List<double> spectralCentroid) {
    if (spectralCentroid.isEmpty) return 0;
    
    final avgCentroid = spectralCentroid.reduce((a, b) => a + b) / spectralCentroid.length;
    // Normalize to 0-1 range (assuming max useful frequency is 8000 Hz)
    return (avgCentroid / 8000).clamp(0.0, 1.0);
  }
  
  /// Calculate warmth from spectral features
  double _calculateWarmth(List<double> spectralCentroid, List<double> formants) {
    if (spectralCentroid.isEmpty || formants.isEmpty) return 0.5;
    
    final avgCentroid = spectralCentroid.reduce((a, b) => a + b) / spectralCentroid.length;
    final f1 = formants[0];
    
    // Lower centroid and lower F1 indicate warmth
    final centroidScore = 1.0 - (avgCentroid / 4000).clamp(0.0, 1.0);
    final formantScore = 1.0 - (f1 / 1000).clamp(0.0, 1.0);
    
    return (centroidScore * 0.6 + formantScore * 0.4);
  }
  
  /// Calculate roughness from spectral flux and harmonics
  double _calculateRoughness(List<double> spectralFlux, Map<String, double> harmonics) {
    if (spectralFlux.isEmpty) return 0;
    
    final avgFlux = spectralFlux.reduce((a, b) => a + b) / spectralFlux.length;
    final shimmer = harmonics['shimmer'] ?? 0;
    
    // Higher flux and shimmer indicate roughness
    final fluxScore = (avgFlux / 100).clamp(0.0, 1.0);
    final shimmerScore = (shimmer / 10).clamp(0.0, 1.0);
    
    return (fluxScore * 0.5 + shimmerScore * 0.5);
  }
  
  /// Calculate breathiness from spectral flatness and harmonic ratio
  double _calculateBreathiness(List<double> spectralFlatness, Map<String, double> harmonics) {
    if (spectralFlatness.isEmpty) return 0;
    
    final avgFlatness = spectralFlatness.reduce((a, b) => a + b) / spectralFlatness.length;
    final harmonicRatio = harmonics['harmonicRatio'] ?? 0;
    
    // Higher flatness and lower harmonic ratio indicate breathiness
    final flatnessScore = avgFlatness;
    final harmonicScore = 1.0 - harmonicRatio;
    
    return (flatnessScore * 0.6 + harmonicScore * 0.4);
  }
  
  /// Assess overall voice quality
  VoiceQualityAssessment _assessVoiceQuality({
    required double brightness,
    required double warmth,
    required double roughness,
    required double breathiness,
    required List<double> formants,
  }) {
    // Calculate overall quality score
    final clarityScore = 1.0 - (roughness * 0.5 + breathiness * 0.5);
    final toneScore = (brightness + warmth) / 2;
    final overallScore = clarityScore * 0.6 + toneScore * 0.4;
    
    // Determine voice type
    String voiceType;
    if (brightness > 0.7 && warmth < 0.3) {
      voiceType = 'Bright/Sharp';
    } else if (brightness < 0.3 && warmth > 0.7) {
      voiceType = 'Warm/Dark';
    } else if (roughness > 0.6) {
      voiceType = 'Rough/Hoarse';
    } else if (breathiness > 0.6) {
      voiceType = 'Breathy/Airy';
    } else {
      voiceType = 'Balanced';
    }
    
    // Generate recommendations
    final recommendations = <String>[];
    if (roughness > 0.5) {
      recommendations.add('목의 긴장을 풀고 편안하게 발성해보세요');
    }
    if (breathiness > 0.5) {
      recommendations.add('성대 접촉을 늘려 더 명확한 소리를 만들어보세요');
    }
    if (brightness > 0.8) {
      recommendations.add('좀 더 부드럽고 따뜻한 톤을 만들어보세요');
    }
    if (warmth > 0.8) {
      recommendations.add('조금 더 밝고 선명한 톤을 시도해보세요');
    }
    
    return VoiceQualityAssessment(
      overallScore: overallScore,
      clarityScore: clarityScore,
      toneScore: toneScore,
      voiceType: voiceType,
      recommendations: recommendations,
    );
  }
  
  /// Apply Hamming window
  List<double> _applyWindow(List<double> frame) {
    final windowed = List<double>.filled(frame.length, 0);
    for (int i = 0; i < frame.length; i++) {
      windowed[i] = frame[i] * (0.54 - 0.46 * math.cos(2 * math.pi * i / (frame.length - 1)));
    }
    return windowed;
  }
  
  /// Get magnitude from complex number
  double _getMagnitude(Float32x2 complex) {
    return math.sqrt(complex.x * complex.x + complex.y * complex.y);
  }
  
  /// Convert Hz to Mel scale
  double _hzToMel(double hz) {
    return 2595 * math.log10(1 + hz / 700);
  }
  
  /// Convert Mel to Hz scale
  double _melToHz(double mel) {
    return 700 * (math.pow(10, mel / 2595) - 1);
  }
}

/// Timbre analysis results
class TimbreAnalysis {
  final List<double> spectralCentroid;
  final List<double> spectralRolloff;
  final List<double> spectralFlux;
  final List<double> spectralFlatness;
  final List<List<double>> mfccCoefficients;
  final List<double> formants;
  final double brightness;
  final double warmth;
  final double roughness;
  final double breathiness;
  final VoiceQualityAssessment voiceQuality;
  final double harmonicRatio;
  final double shimmer;
  final double jitter;
  
  const TimbreAnalysis({
    required this.spectralCentroid,
    required this.spectralRolloff,
    required this.spectralFlux,
    required this.spectralFlatness,
    required this.mfccCoefficients,
    required this.formants,
    required this.brightness,
    required this.warmth,
    required this.roughness,
    required this.breathiness,
    required this.voiceQuality,
    required this.harmonicRatio,
    required this.shimmer,
    required this.jitter,
  });
  
  Map<String, dynamic> toJson() => {
    'brightness': brightness,
    'warmth': warmth,
    'roughness': roughness,
    'breathiness': breathiness,
    'harmonicRatio': harmonicRatio,
    'shimmer': shimmer,
    'jitter': jitter,
    'formants': formants,
    'voiceType': voiceQuality.voiceType,
    'overallQuality': voiceQuality.overallScore,
  };
}

/// Voice quality assessment
class VoiceQualityAssessment {
  final double overallScore;
  final double clarityScore;
  final double toneScore;
  final String voiceType;
  final List<String> recommendations;
  
  const VoiceQualityAssessment({
    required this.overallScore,
    required this.clarityScore,
    required this.toneScore,
    required this.voiceType,
    required this.recommendations,
  });
}