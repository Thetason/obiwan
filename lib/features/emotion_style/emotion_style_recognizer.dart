import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../core/utils/random_utils.dart';

/// Real-time Emotion and Style Recognition System
/// CNN + RNN Hybrid Model for Vocal Analysis
class EmotionStyleRecognizer {
  static const int sampleRate = 16000;
  static const int windowSize = 512;
  static const int hopSize = 256;
  static const int melBins = 128;
  static const int cnnFilters = 64;
  static const int rnnHiddenSize = 128;
  static const int numEmotionClasses = 8;
  static const int numStyleClasses = 12;
  
  // CNN layers
  late List<CNNLayer> _cnnLayers;
  
  // RNN layers
  late List<RNNLayer> _rnnLayers;
  
  // Classification heads
  late ClassificationHead _emotionHead;
  late ClassificationHead _styleHead;
  
  // Real-time processing
  final List<List<double>> _featureBuffer = [];
  final List<EmotionPrediction> _emotionHistory = [];
  final List<StylePrediction> _styleHistory = [];
  
  // Smoothing parameters
  static const int historyLength = 10;
  static const double smoothingFactor = 0.7;
  
  EmotionStyleRecognizer() {
    _initializeModel();
  }
  
  void _initializeModel() {
    _initializeCNN();
    _initializeRNN();
    _initializeClassificationHeads();
    debugPrint('Emotion/Style Recognition System initialized');
  }
  
  void _initializeCNN() {
    _cnnLayers = [
      CNNLayer(inputChannels: 1, outputChannels: 32, kernelSize: 3, stride: 1),
      CNNLayer(inputChannels: 32, outputChannels: 64, kernelSize: 3, stride: 1),
      CNNLayer(inputChannels: 64, outputChannels: 128, kernelSize: 3, stride: 1),
      CNNLayer(inputChannels: 128, outputChannels: 256, kernelSize: 3, stride: 1),
    ];
  }
  
  void _initializeRNN() {
    _rnnLayers = [
      RNNLayer(inputSize: 256, hiddenSize: rnnHiddenSize, isBidirectional: true),
      RNNLayer(inputSize: rnnHiddenSize * 2, hiddenSize: rnnHiddenSize, isBidirectional: false),
    ];
  }
  
  void _initializeClassificationHeads() {
    _emotionHead = ClassificationHead(
      inputSize: rnnHiddenSize,
      numClasses: numEmotionClasses,
      classNames: ['Happy', 'Sad', 'Angry', 'Fear', 'Disgust', 'Surprise', 'Calm', 'Excited'],
    );
    
    _styleHead = ClassificationHead(
      inputSize: rnnHiddenSize,
      numClasses: numStyleClasses,
      classNames: ['Pop', 'Rock', 'Jazz', 'Classical', 'Folk', 'Blues', 'Country', 'R&B', 'Opera', 'Gospel', 'Musical', 'Alternative'],
    );
  }
  
  /// Real-time emotion and style recognition
  Future<EmotionStyleResult> recognizeRealTime(List<double> audioChunk) async {
    try {
      // Extract features
      final features = await _extractFeatures(audioChunk);
      if (features.isEmpty) {
        return EmotionStyleResult.empty();
      }
      
      // Add to buffer for temporal analysis
      _featureBuffer.add(features);
      if (_featureBuffer.length > historyLength) {
        _featureBuffer.removeAt(0);
      }
      
      // CNN forward pass
      final cnnOutput = _forwardCNN(features);
      
      // RNN forward pass with temporal context
      final rnnOutput = _forwardRNN([cnnOutput]);
      
      // Classification
      final emotionPrediction = _emotionHead.classify(rnnOutput);
      final stylePrediction = _styleHead.classifyStyle(rnnOutput);
      
      // Temporal smoothing
      final smoothedEmotion = _smoothEmotionPrediction(emotionPrediction);
      final smoothedStyle = _smoothStylePrediction(stylePrediction);
      
      return EmotionStyleResult(
        emotion: smoothedEmotion,
        style: smoothedStyle,
        confidence: (smoothedEmotion.confidence + smoothedStyle.confidence) / 2,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Recognition error: $e');
      return EmotionStyleResult.empty();
    }
  }
  
  /// Batch processing for detailed analysis
  Future<EmotionStyleResult> analyzeBatch(List<double> audioData) async {
    final results = <EmotionStyleResult>[];
    
    // Process in chunks
    for (int i = 0; i < audioData.length - windowSize; i += hopSize) {
      final chunk = audioData.sublist(i, i + windowSize);
      final result = await recognizeRealTime(chunk);
      if (result.confidence > 0.5) {
        results.add(result);
      }
    }
    
    // Aggregate results
    return _aggregateResults(results);
  }
  
  Future<List<double>> _extractFeatures(List<double> audioChunk) async {
    // Multi-feature extraction pipeline
    final spectralFeatures = _extractSpectralFeatures(audioChunk);
    final prosodyFeatures = _extractProsodyFeatures(audioChunk);
    final voiceQualityFeatures = _extractVoiceQualityFeatures(audioChunk);
    
    // Combine features
    final combinedFeatures = <double>[];
    combinedFeatures.addAll(spectralFeatures);
    combinedFeatures.addAll(prosodyFeatures);
    combinedFeatures.addAll(voiceQualityFeatures);
    
    return combinedFeatures;
  }
  
  List<double> _extractSpectralFeatures(List<double> audio) {
    // Mel-frequency cepstral coefficients (MFCC)
    final mfcc = _computeMFCC(audio);
    
    // Spectral centroid, rolloff, flux
    final spectralCentroid = _computeSpectralCentroid(audio);
    final spectralRolloff = _computeSpectralRolloff(audio);
    final spectralFlux = _computeSpectralFlux(audio);
    
    // Chroma features
    final chroma = _computeChromaFeatures(audio);
    
    final features = <double>[];
    features.addAll(mfcc);
    features.addAll([spectralCentroid, spectralRolloff, spectralFlux]);
    features.addAll(chroma);
    
    return features;
  }
  
  List<double> _extractProsodyFeatures(List<double> audio) {
    // Fundamental frequency (F0) features
    final f0 = _estimateF0(audio);
    final f0Mean = f0.isNotEmpty ? f0.reduce((a, b) => a + b) / f0.length : 0.0;
    final f0Std = _computeStandardDeviation(f0);
    final f0Range = f0.isNotEmpty ? f0.reduce(math.max) - f0.reduce(math.min) : 0.0;
    
    // Energy features
    final energy = _computeEnergy(audio);
    final energyMean = energy.isNotEmpty ? energy.reduce((a, b) => a + b) / energy.length : 0.0;
    final energyStd = _computeStandardDeviation(energy);
    
    // Rhythm and tempo features
    final tempo = _estimateTempo(audio);
    final rhythmRegularity = _computeRhythmRegularity(audio);
    
    return [f0Mean, f0Std, f0Range, energyMean, energyStd, tempo, rhythmRegularity];
  }
  
  List<double> _extractVoiceQualityFeatures(List<double> audio) {
    // Jitter and shimmer
    final jitter = _computeJitter(audio);
    final shimmer = _computeShimmer(audio);
    
    // Harmonic-to-noise ratio
    final hnr = _computeHNR(audio);
    
    // Breathiness measure
    final breathiness = _computeBreathiness(audio);
    
    // Vocal strain indicators
    final strain = _computeVocalStrain(audio);
    
    return [jitter, shimmer, hnr, breathiness, strain];
  }
  
  List<double> _computeMFCC(List<double> audio) {
    // Simplified MFCC computation
    final spectrum = _computeFFT(audio);
    final melSpectrum = _applyMelFilterbank(spectrum);
    final logMel = melSpectrum.map((x) => math.log(x + 1e-10)).toList();
    return _computeDCT(logMel).take(13).toList();
  }
  
  List<double> _computeFFT(List<double> audio) {
    final N = audio.length;
    final magnitude = List<double>.filled(N ~/ 2, 0.0);
    
    for (int k = 0; k < N ~/ 2; k++) {
      double real = 0, imag = 0;
      for (int n = 0; n < N; n++) {
        final angle = -2 * math.pi * k * n / N;
        real += audio[n] * math.cos(angle);
        imag += audio[n] * math.sin(angle);
      }
      magnitude[k] = math.sqrt(real * real + imag * imag);
    }
    
    return magnitude;
  }
  
  List<double> _applyMelFilterbank(List<double> spectrum) {
    const numFilters = 26;
    final melSpectrum = List<double>.filled(numFilters, 0.0);
    
    for (int i = 0; i < numFilters; i++) {
      final filterStart = (i * spectrum.length / numFilters).floor();
      final filterEnd = ((i + 1) * spectrum.length / numFilters).floor();
      
      for (int j = filterStart; j < filterEnd && j < spectrum.length; j++) {
        final weight = 1.0 - (j - filterStart) / (filterEnd - filterStart);
        melSpectrum[i] += spectrum[j] * weight;
      }
    }
    
    return melSpectrum;
  }
  
  List<double> _computeDCT(List<double> input) {
    final N = input.length;
    final output = List<double>.filled(N, 0.0);
    
    for (int k = 0; k < N; k++) {
      for (int n = 0; n < N; n++) {
        output[k] += input[n] * math.cos(math.pi * k * (2 * n + 1) / (2 * N));
      }
    }
    
    return output;
  }
  
  double _computeSpectralCentroid(List<double> audio) {
    final spectrum = _computeFFT(audio);
    double weightedSum = 0;
    double totalMagnitude = 0;
    
    for (int i = 0; i < spectrum.length; i++) {
      weightedSum += i * spectrum[i];
      totalMagnitude += spectrum[i];
    }
    
    return totalMagnitude > 0 ? weightedSum / totalMagnitude : 0.0;
  }
  
  double _computeSpectralRolloff(List<double> audio) {
    final spectrum = _computeFFT(audio);
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
  
  double _computeSpectralFlux(List<double> audio) {
    if (_featureBuffer.isEmpty) return 0.0;
    
    final currentSpectrum = _computeFFT(audio);
    final previousSpectrum = _computeFFT(_featureBuffer.last.take(audio.length).toList());
    
    double flux = 0;
    for (int i = 0; i < math.min(currentSpectrum.length, previousSpectrum.length); i++) {
      final diff = currentSpectrum[i] - previousSpectrum[i];
      flux += diff > 0 ? diff : 0;
    }
    
    return flux;
  }
  
  List<double> _computeChromaFeatures(List<double> audio) {
    const chromaBins = 12;
    final chroma = List<double>.filled(chromaBins, 0.0);
    final spectrum = _computeFFT(audio);
    
    for (int i = 1; i < spectrum.length; i++) {
      final frequency = i * sampleRate / (2 * spectrum.length);
      final noteIndex = _frequencyToChromaIndex(frequency);
      chroma[noteIndex] += spectrum[i];
    }
    
    // Normalize
    final sum = chroma.fold<double>(0, (a, b) => a + b);
    return sum > 0 ? chroma.map((x) => x / sum).toList() : chroma;
  }
  
  int _frequencyToChromaIndex(double frequency) {
    if (frequency <= 0) return 0;
    final noteNumber = 12 * (math.log(frequency / 440) / math.ln2) + 9;
    return (noteNumber % 12).round().abs() % 12;
  }
  
  List<double> _estimateF0(List<double> audio) {
    // Autocorrelation-based F0 estimation
    final f0Values = <double>[];
    const minPeriod = 50; // ~320 Hz
    const maxPeriod = 400; // ~40 Hz
    
    for (int i = 0; i < audio.length - maxPeriod; i += hopSize) {
      final segment = audio.sublist(i, math.min(i + windowSize, audio.length));
      final f0 = _autocorrelationF0(segment, minPeriod, maxPeriod);
      f0Values.add(f0);
    }
    
    return f0Values;
  }
  
  double _autocorrelationF0(List<double> segment, int minPeriod, int maxPeriod) {
    double maxCorrelation = 0;
    int bestPeriod = minPeriod;
    
    for (int period = minPeriod; period <= maxPeriod && period < segment.length / 2; period++) {
      double correlation = 0;
      for (int i = 0; i < segment.length - period; i++) {
        correlation += segment[i] * segment[i + period];
      }
      
      if (correlation > maxCorrelation) {
        maxCorrelation = correlation;
        bestPeriod = period;
      }
    }
    
    return sampleRate.toDouble() / bestPeriod;
  }
  
  List<double> _computeEnergy(List<double> audio) {
    final energyValues = <double>[];
    
    for (int i = 0; i < audio.length - windowSize; i += hopSize) {
      final segment = audio.sublist(i, i + windowSize);
      final energy = segment.fold<double>(0, (sum, val) => sum + val * val);
      energyValues.add(energy);
    }
    
    return energyValues;
  }
  
  double _estimateTempo(List<double> audio) {
    final energy = _computeEnergy(audio);
    final diff = <double>[];
    
    for (int i = 1; i < energy.length; i++) {
      diff.add((energy[i] - energy[i - 1]).abs());
    }
    
    // Simplified tempo estimation using peak detection
    int peakCount = 0;
    for (int i = 1; i < diff.length - 1; i++) {
      if (diff[i] > diff[i - 1] && diff[i] > diff[i + 1] && diff[i] > 0.1) {
        peakCount++;
      }
    }
    
    final duration = audio.length / sampleRate;
    return duration > 0 ? (peakCount / duration) * 60 : 0; // BPM
  }
  
  double _computeRhythmRegularity(List<double> audio) {
    final energy = _computeEnergy(audio);
    if (energy.length < 3) return 0.0;
    
    final intervals = <double>[];
    for (int i = 1; i < energy.length - 1; i++) {
      if (energy[i] > energy[i - 1] && energy[i] > energy[i + 1]) {
        intervals.add(i.toDouble());
      }
    }
    
    if (intervals.length < 2) return 0.0;
    
    final diffs = <double>[];
    for (int i = 1; i < intervals.length; i++) {
      diffs.add(intervals[i] - intervals[i - 1]);
    }
    
    final meanDiff = diffs.reduce((a, b) => a + b) / diffs.length;
    final variance = diffs.map((x) => math.pow(x - meanDiff, 2)).reduce((a, b) => a + b) / diffs.length;
    
    return 1.0 / (1.0 + variance);
  }
  
  double _computeJitter(List<double> audio) {
    final f0Values = _estimateF0(audio);
    if (f0Values.length < 2) return 0.0;
    
    double jitterSum = 0;
    for (int i = 1; i < f0Values.length; i++) {
      if (f0Values[i] > 0 && f0Values[i - 1] > 0) {
        jitterSum += (f0Values[i] - f0Values[i - 1]).abs() / f0Values[i - 1];
      }
    }
    
    return jitterSum / (f0Values.length - 1);
  }
  
  double _computeShimmer(List<double> audio) {
    final energy = _computeEnergy(audio);
    if (energy.length < 2) return 0.0;
    
    double shimmerSum = 0;
    for (int i = 1; i < energy.length; i++) {
      if (energy[i] > 0 && energy[i - 1] > 0) {
        shimmerSum += (energy[i] - energy[i - 1]).abs() / energy[i - 1];
      }
    }
    
    return shimmerSum / (energy.length - 1);
  }
  
  double _computeHNR(List<double> audio) {
    final spectrum = _computeFFT(audio);
    final f0 = _autocorrelationF0(audio, 50, 400);
    
    if (f0 <= 0) return 0.0;
    
    // Simplified HNR calculation
    final harmonicBins = <int>[];
    for (int h = 1; h <= 5; h++) {
      final bin = (h * f0 * spectrum.length / (sampleRate / 2)).round();
      if (bin < spectrum.length) harmonicBins.add(bin);
    }
    
    double harmonicEnergy = 0;
    double totalEnergy = spectrum.fold<double>(0, (sum, val) => sum + val * val);
    
    for (final bin in harmonicBins) {
      harmonicEnergy += spectrum[bin] * spectrum[bin];
    }
    
    final noiseEnergy = totalEnergy - harmonicEnergy;
    return noiseEnergy > 0 ? 20 * math.log(harmonicEnergy / noiseEnergy) / math.ln10 : 100;
  }
  
  double _computeBreathiness(List<double> audio) {
    final spectrum = _computeFFT(audio);
    final highFreqEnergy = spectrum.sublist(spectrum.length ~/ 2).fold<double>(0, (sum, val) => sum + val * val);
    final totalEnergy = spectrum.fold<double>(0, (sum, val) => sum + val * val);
    
    return totalEnergy > 0 ? highFreqEnergy / totalEnergy : 0.0;
  }
  
  double _computeVocalStrain(List<double> audio) {
    final jitter = _computeJitter(audio);
    final shimmer = _computeShimmer(audio);
    final hnr = _computeHNR(audio);
    
    // Combine indicators (higher values indicate more strain)
    return (jitter * 10 + shimmer * 10 + math.max(0, 20 - hnr) / 20) / 3;
  }
  
  double _computeStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / values.length;
    return math.sqrt(variance);
  }
  
  List<double> _forwardCNN(List<double> features) {
    var input = [features]; // Add channel dimension
    
    for (final layer in _cnnLayers) {
      input = layer.forward(input);
    }
    
    // Global average pooling
    return input.isNotEmpty ? input.first : [];
  }
  
  List<double> _forwardRNN(List<List<double>> sequence) {
    var hidden = sequence;
    
    for (final layer in _rnnLayers) {
      hidden = layer.forward(hidden);
    }
    
    // Return last hidden state
    return hidden.isNotEmpty ? hidden.last : [];
  }
  
  EmotionPrediction _smoothEmotionPrediction(EmotionPrediction current) {
    _emotionHistory.add(current);
    if (_emotionHistory.length > historyLength) {
      _emotionHistory.removeAt(0);
    }
    
    if (_emotionHistory.length == 1) return current;
    
    // Exponential smoothing
    final weights = <double>[];
    double totalWeight = 0;
    for (int i = 0; i < _emotionHistory.length; i++) {
      final weight = math.pow(smoothingFactor, _emotionHistory.length - 1 - i);
      weights.add(weight.toDouble());
      totalWeight += weight;
    }
    
    final smoothedProbabilities = List<double>.filled(_emotionHistory.first.probabilities.length, 0.0);
    for (int i = 0; i < _emotionHistory.length; i++) {
      final normalizedWeight = weights[i] / totalWeight;
      for (int j = 0; j < smoothedProbabilities.length; j++) {
        smoothedProbabilities[j] += _emotionHistory[i].probabilities[j] * normalizedWeight;
      }
    }
    
    final maxIndex = smoothedProbabilities.indexOf(smoothedProbabilities.reduce(math.max));
    return EmotionPrediction(
      emotion: _emotionHead.classNames[maxIndex],
      confidence: smoothedProbabilities[maxIndex],
      probabilities: smoothedProbabilities,
    );
  }
  
  StylePrediction _smoothStylePrediction(StylePrediction current) {
    _styleHistory.add(current);
    if (_styleHistory.length > historyLength) {
      _styleHistory.removeAt(0);
    }
    
    if (_styleHistory.length == 1) return current;
    
    // Similar smoothing for style
    final weights = <double>[];
    double totalWeight = 0;
    for (int i = 0; i < _styleHistory.length; i++) {
      final weight = math.pow(smoothingFactor, _styleHistory.length - 1 - i);
      weights.add(weight.toDouble());
      totalWeight += weight;
    }
    
    final smoothedProbabilities = List<double>.filled(_styleHistory.first.probabilities.length, 0.0);
    for (int i = 0; i < _styleHistory.length; i++) {
      final normalizedWeight = weights[i] / totalWeight;
      for (int j = 0; j < smoothedProbabilities.length; j++) {
        smoothedProbabilities[j] += _styleHistory[i].probabilities[j] * normalizedWeight;
      }
    }
    
    final maxIndex = smoothedProbabilities.indexOf(smoothedProbabilities.reduce(math.max));
    return StylePrediction(
      style: _styleHead.classNames[maxIndex],
      confidence: smoothedProbabilities[maxIndex],
      probabilities: smoothedProbabilities,
    );
  }
  
  EmotionStyleResult _aggregateResults(List<EmotionStyleResult> results) {
    if (results.isEmpty) return EmotionStyleResult.empty();
    if (results.length == 1) return results.first;
    
    // Aggregate emotions
    final emotionCounts = <String, int>{};
    final emotionConfidences = <String, List<double>>{};
    
    for (final result in results) {
      emotionCounts[result.emotion.emotion] = (emotionCounts[result.emotion.emotion] ?? 0) + 1;
      emotionConfidences.putIfAbsent(result.emotion.emotion, () => []).add(result.emotion.confidence);
    }
    
    String dominantEmotion = '';
    double maxEmotionCount = 0;
    for (final entry in emotionCounts.entries) {
      if (entry.value > maxEmotionCount) {
        maxEmotionCount = entry.value.toDouble();
        dominantEmotion = entry.key;
      }
    }
    
    // Aggregate styles
    final styleCounts = <String, int>{};
    final styleConfidences = <String, List<double>>{};
    
    for (final result in results) {
      styleCounts[result.style.style] = (styleCounts[result.style.style] ?? 0) + 1;
      styleConfidences.putIfAbsent(result.style.style, () => []).add(result.style.confidence);
    }
    
    String dominantStyle = '';
    double maxStyleCount = 0;
    for (final entry in styleCounts.entries) {
      if (entry.value > maxStyleCount) {
        maxStyleCount = entry.value.toDouble();
        dominantStyle = entry.key;
      }
    }
    
    // Calculate aggregated confidences
    final emotionConfidence = (emotionConfidences[dominantEmotion]?.reduce((a, b) => a + b) ?? 0.0) / (emotionConfidences[dominantEmotion]?.length ?? 1);
    final styleConfidence = (styleConfidences[dominantStyle]?.reduce((a, b) => a + b) ?? 0.0) / (styleConfidences[dominantStyle]?.length ?? 1);
    
    return EmotionStyleResult(
      emotion: EmotionPrediction(
        emotion: dominantEmotion,
        confidence: emotionConfidence,
        probabilities: [],
      ),
      style: StylePrediction(
        style: dominantStyle,
        confidence: styleConfidence,
        probabilities: [],
      ),
      confidence: (emotionConfidence + styleConfidence) / 2,
      timestamp: DateTime.now(),
    );
  }
}

// Neural network components
class CNNLayer {
  final int inputChannels;
  final int outputChannels;
  final int kernelSize;
  final int stride;
  late List<List<List<double>>> weights;
  late List<double> biases;
  
  CNNLayer({
    required this.inputChannels,
    required this.outputChannels,
    required this.kernelSize,
    required this.stride,
  }) {
    _initializeWeights();
  }
  
  void _initializeWeights() {
    final random = math.Random(42);
    weights = List.generate(outputChannels, (_) =>
      List.generate(inputChannels, (_) =>
        List.generate(kernelSize, (_) => random.nextGaussian() * 0.1)
      )
    );
    biases = List.generate(outputChannels, (_) => random.nextGaussian() * 0.01);
  }
  
  List<List<double>> forward(List<List<double>> input) {
    final output = <List<double>>[];
    
    for (int outCh = 0; outCh < outputChannels; outCh++) {
      final channelOutput = <double>[];
      
      for (int i = 0; i < input.first.length - kernelSize + 1; i += stride) {
        double sum = biases[outCh];
        
        for (int inCh = 0; inCh < math.min(inputChannels, input.length); inCh++) {
          for (int k = 0; k < kernelSize; k++) {
            if (i + k < input[inCh].length) {
              sum += input[inCh][i + k] * weights[outCh][inCh][k];
            }
          }
        }
        
        channelOutput.add(math.max(0, sum)); // ReLU activation
      }
      
      output.add(channelOutput);
    }
    
    return output;
  }
}

class RNNLayer {
  final int inputSize;
  final int hiddenSize;
  final bool isBidirectional;
  late List<List<double>> weightIh; // input to hidden
  late List<List<double>> weightHh; // hidden to hidden
  late List<double> biasIh;
  late List<double> biasHh;
  
  RNNLayer({
    required this.inputSize,
    required this.hiddenSize,
    required this.isBidirectional,
  }) {
    _initializeWeights();
  }
  
  void _initializeWeights() {
    final random = math.Random(42);
    
    weightIh = List.generate(hiddenSize, (_) =>
      List.generate(inputSize, (_) => random.nextGaussian() * 0.1)
    );
    weightHh = List.generate(hiddenSize, (_) =>
      List.generate(hiddenSize, (_) => random.nextGaussian() * 0.1)
    );
    biasIh = List.generate(hiddenSize, (_) => random.nextGaussian() * 0.01);
    biasHh = List.generate(hiddenSize, (_) => random.nextGaussian() * 0.01);
  }
  
  List<List<double>> forward(List<List<double>> sequence) {
    final outputs = <List<double>>[];
    var hidden = List<double>.filled(hiddenSize, 0.0);
    
    // Forward pass
    for (final input in sequence) {
      hidden = _stepForward(input, hidden);
      outputs.add(List.from(hidden));
    }
    
    if (isBidirectional) {
      // Backward pass
      final backwardOutputs = <List<double>>[];
      var backwardHidden = List<double>.filled(hiddenSize, 0.0);
      
      for (int i = sequence.length - 1; i >= 0; i--) {
        backwardHidden = _stepForward(sequence[i], backwardHidden);
        backwardOutputs.insert(0, List.from(backwardHidden));
      }
      
      // Concatenate forward and backward outputs
      for (int i = 0; i < outputs.length; i++) {
        outputs[i].addAll(backwardOutputs[i]);
      }
    }
    
    return outputs;
  }
  
  List<double> _stepForward(List<double> input, List<double> hidden) {
    final newHidden = List<double>.filled(hiddenSize, 0.0);
    
    for (int i = 0; i < hiddenSize; i++) {
      double sum = biasIh[i] + biasHh[i];
      
      // Input to hidden
      for (int j = 0; j < math.min(input.length, inputSize); j++) {
        sum += input[j] * weightIh[i][j];
      }
      
      // Hidden to hidden
      for (int j = 0; j < hiddenSize; j++) {
        sum += hidden[j] * weightHh[i][j];
      }
      
      newHidden[i] = (math.exp(sum) - math.exp(-sum)) / (math.exp(sum) + math.exp(-sum)); // tanh implementation
    }
    
    return newHidden;
  }
}

class ClassificationHead {
  final int inputSize;
  final int numClasses;
  final List<String> classNames;
  late List<List<double>> weights;
  late List<double> biases;
  
  ClassificationHead({
    required this.inputSize,
    required this.numClasses,
    required this.classNames,
  }) {
    _initializeWeights();
  }
  
  void _initializeWeights() {
    final random = math.Random(42);
    weights = List.generate(numClasses, (_) =>
      List.generate(inputSize, (_) => random.nextGaussian() * 0.1)
    );
    biases = List.generate(numClasses, (_) => random.nextGaussian() * 0.01);
  }
  
  EmotionPrediction classify(List<double> input) {
    final logits = <double>[];
    
    for (int i = 0; i < numClasses; i++) {
      double sum = biases[i];
      for (int j = 0; j < math.min(input.length, inputSize); j++) {
        sum += input[j] * weights[i][j];
      }
      logits.add(sum);
    }
    
    // Softmax
    final maxLogit = logits.reduce(math.max);
    final expLogits = logits.map((x) => math.exp(x - maxLogit)).toList();
    final sumExp = expLogits.reduce((a, b) => a + b);
    final probabilities = expLogits.map((x) => x / sumExp).toList();
    
    // Get prediction
    final maxIndex = probabilities.indexOf(probabilities.reduce(math.max));
    
    return EmotionPrediction(
      emotion: classNames[maxIndex],
      confidence: probabilities[maxIndex],
      probabilities: probabilities,
    );
  }
  
  StylePrediction classifyStyle(List<double> input) {
    final logits = <double>[];
    
    for (int i = 0; i < numClasses; i++) {
      double sum = biases[i];
      for (int j = 0; j < math.min(input.length, inputSize); j++) {
        sum += input[j] * weights[i][j];
      }
      logits.add(sum);
    }
    
    // Softmax
    final maxLogit = logits.reduce(math.max);
    final expLogits = logits.map((x) => math.exp(x - maxLogit)).toList();
    final sumExp = expLogits.reduce((a, b) => a + b);
    final probabilities = expLogits.map((x) => x / sumExp).toList();
    
    // Get prediction
    final maxIndex = probabilities.indexOf(probabilities.reduce(math.max));
    
    return StylePrediction(
      style: classNames[maxIndex],
      confidence: probabilities[maxIndex],
      probabilities: probabilities,
    );
  }
}

// Result classes
class EmotionStyleResult {
  final EmotionPrediction emotion;
  final StylePrediction style;
  final double confidence;
  final DateTime timestamp;
  
  EmotionStyleResult({
    required this.emotion,
    required this.style,
    required this.confidence,
    required this.timestamp,
  });
  
  factory EmotionStyleResult.empty() {
    return EmotionStyleResult(
      emotion: EmotionPrediction(emotion: 'Neutral', confidence: 0.0, probabilities: []),
      style: StylePrediction(style: 'Unknown', confidence: 0.0, probabilities: []),
      confidence: 0.0,
      timestamp: DateTime.now(),
    );
  }
}

class EmotionPrediction {
  final String emotion;
  final double confidence;
  final List<double> probabilities;
  
  EmotionPrediction({
    required this.emotion,
    required this.confidence,
    required this.probabilities,
  });
}

class StylePrediction {
  final String style;
  final double confidence;
  final List<double> probabilities;
  
  StylePrediction({
    required this.style,
    required this.confidence,
    required this.probabilities,
  });
}

// RandomGaussian extension moved to utils to avoid duplication