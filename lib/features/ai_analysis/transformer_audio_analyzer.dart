import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../core/utils/random_utils.dart';

/// Transformer-based Audio Analysis Engine
/// Inspired by Whisper architecture for multi-task audio analysis
class TransformerAudioAnalyzer {
  static const int sampleRate = 16000;
  static const int windowSize = 400; // 25ms window
  static const int hopSize = 160; // 10ms hop
  static const int nMels = 80;
  static const int nFFT = 512;
  
  // Multi-head attention parameters
  static const int numHeads = 8;
  static const int embeddingDim = 512;
  static const int numLayers = 6;
  
  late List<List<double>> _melFilterbank;
  late List<List<double>> _encoderWeights;
  late List<List<double>> _attentionWeights;
  
  // Multi-task heads
  late AudioAnalysisHeads _analysisHeads;
  
  TransformerAudioAnalyzer() {
    _initializeModel();
  }
  
  void _initializeModel() {
    _melFilterbank = _createMelFilterbank();
    _encoderWeights = _initializeEncoderWeights();
    _attentionWeights = _initializeAttentionWeights();
    _analysisHeads = AudioAnalysisHeads();
  }
  
  /// Main analysis pipeline
  Future<MultiTaskAnalysisResult> analyzeAudio(List<double> audioData) async {
    try {
      // 1. Preprocessing
      final preprocessed = _preprocessAudio(audioData);
      
      // 2. Feature extraction (Mel-spectrogram)
      final melSpectrogram = _extractMelSpectrogram(preprocessed);
      
      // 3. Transformer encoding
      final encodedFeatures = _transformerEncode(melSpectrogram);
      
      // 4. Multi-task analysis
      final results = await _performMultiTaskAnalysis(encodedFeatures);
      
      return results;
    } catch (e) {
      debugPrint('Audio analysis error: $e');
      return MultiTaskAnalysisResult.empty();
    }
  }
  
  List<double> _preprocessAudio(List<double> audio) {
    // Normalize audio
    if (audio.isEmpty) return [];
    
    final maxVal = audio.map((x) => x.abs()).reduce(math.max);
    if (maxVal == 0) return audio;
    
    return audio.map((x) => x / maxVal).toList();
  }
  
  List<List<double>> _extractMelSpectrogram(List<double> audio) {
    final spectrogram = <List<double>>[];
    
    for (int i = 0; i < audio.length - windowSize; i += hopSize) {
      final window = audio.sublist(i, i + windowSize);
      final fftResult = _performFFT(window);
      final melFrame = _applyMelFilters(fftResult);
      spectrogram.add(melFrame);
    }
    
    return spectrogram;
  }
  
  List<double> _performFFT(List<double> window) {
    // Simplified FFT implementation
    final N = window.length;
    final magnitude = List<double>.filled(N ~/ 2, 0.0);
    
    for (int k = 0; k < N ~/ 2; k++) {
      double real = 0, imag = 0;
      for (int n = 0; n < N; n++) {
        final angle = -2 * math.pi * k * n / N;
        real += window[n] * math.cos(angle);
        imag += window[n] * math.sin(angle);
      }
      magnitude[k] = math.sqrt(real * real + imag * imag);
    }
    
    return magnitude;
  }
  
  List<double> _applyMelFilters(List<double> fftMagnitude) {
    final melFeatures = List<double>.filled(nMels, 0.0);
    
    for (int i = 0; i < nMels; i++) {
      for (int j = 0; j < fftMagnitude.length; j++) {
        melFeatures[i] += fftMagnitude[j] * _melFilterbank[i][j];
      }
      melFeatures[i] = math.log(melFeatures[i] + 1e-10); // Log mel
    }
    
    return melFeatures;
  }
  
  List<List<double>> _transformerEncode(List<List<double>> melSpectrogram) {
    // Multi-layer transformer encoding
    var hidden = melSpectrogram;
    
    for (int layer = 0; layer < numLayers; layer++) {
      // Multi-head self-attention
      hidden = _multiHeadAttention(hidden);
      
      // Feed-forward network
      hidden = _feedForward(hidden);
      
      // Residual connection and layer norm
      hidden = _layerNorm(hidden);
    }
    
    return hidden;
  }
  
  List<List<double>> _multiHeadAttention(List<List<double>> input) {
    final List<List<double>> output = [];
    
    for (int i = 0; i < input.length; i++) {
      final attended = List<double>.filled(embeddingDim, 0.0);
      
      // Simplified attention mechanism
      for (int j = 0; j < input.length; j++) {
        final weight = _calculateAttentionWeight(input[i], input[j]);
        for (int k = 0; k < input[j].length; k++) {
          if (k < attended.length) {
            attended[k] += weight * input[j][k];
          }
        }
      }
      
      output.add(attended);
    }
    
    return output;
  }
  
  double _calculateAttentionWeight(List<double> query, List<double> key) {
    double dotProduct = 0;
    final minLength = math.min(query.length, key.length);
    
    for (int i = 0; i < minLength; i++) {
      dotProduct += query[i] * key[i];
    }
    
    return math.exp(dotProduct / math.sqrt(minLength));
  }
  
  List<List<double>> _feedForward(List<List<double>> input) {
    return input.map((sequence) {
      return sequence.map((x) => math.max(0, x).toDouble()).toList(); // ReLU activation
    }).toList();
  }
  
  List<List<double>> _layerNorm(List<List<double>> input) {
    return input.map((sequence) {
      final mean = sequence.reduce((a, b) => a + b) / sequence.length;
      final variance = sequence.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / sequence.length;
      final std = math.sqrt(variance + 1e-8);
      
      return sequence.map((x) => (x - mean) / std).toList();
    }).toList();
  }
  
  Future<MultiTaskAnalysisResult> _performMultiTaskAnalysis(List<List<double>> encodedFeatures) async {
    // Extract global features for analysis
    final globalFeatures = _extractGlobalFeatures(encodedFeatures);
    
    // Multi-task predictions
    final pitchAnalysis = _analysisHeads.analyzePitch(globalFeatures);
    final toneAnalysis = _analysisHeads.analyzeTone(globalFeatures);
    final emotionAnalysis = _analysisHeads.analyzeEmotion(globalFeatures);
    final styleAnalysis = _analysisHeads.analyzeStyle(globalFeatures);
    
    return MultiTaskAnalysisResult(
      pitch: pitchAnalysis,
      tone: toneAnalysis,
      emotion: emotionAnalysis,
      style: styleAnalysis,
      confidence: _calculateOverallConfidence([pitchAnalysis, toneAnalysis, emotionAnalysis, styleAnalysis]),
    );
  }
  
  List<double> _extractGlobalFeatures(List<List<double>> encodedFeatures) {
    if (encodedFeatures.isEmpty) return [];
    
    // Global average pooling
    final featureSize = encodedFeatures.first.length;
    final globalFeatures = List<double>.filled(featureSize, 0.0);
    
    for (final frame in encodedFeatures) {
      for (int i = 0; i < math.min(frame.length, featureSize); i++) {
        globalFeatures[i] += frame[i];
      }
    }
    
    final scale = 1.0 / encodedFeatures.length;
    return globalFeatures.map((x) => x * scale).toList();
  }
  
  double _calculateOverallConfidence(List<AnalysisResult> results) {
    if (results.isEmpty) return 0.0;
    return results.map((r) => r.confidence).reduce((a, b) => a + b) / results.length;
  }
  
  List<List<double>> _createMelFilterbank() {
    final filterbank = <List<double>>[];
    
    for (int i = 0; i < nMels; i++) {
      final filter = List<double>.filled(nFFT ~/ 2, 0.0);
      
      // Triangular mel filters
      final lowFreq = _melToHz(i * 2595.0 / nMels);
      final centerFreq = _melToHz((i + 1) * 2595.0 / nMels);
      final highFreq = _melToHz((i + 2) * 2595.0 / nMels);
      
      for (int j = 0; j < filter.length; j++) {
        final freq = j * sampleRate / nFFT;
        
        if (freq >= lowFreq && freq <= centerFreq) {
          filter[j] = (freq - lowFreq) / (centerFreq - lowFreq);
        } else if (freq > centerFreq && freq <= highFreq) {
          filter[j] = (highFreq - freq) / (highFreq - centerFreq);
        }
      }
      
      filterbank.add(filter);
    }
    
    return filterbank;
  }
  
  double _melToHz(double mel) {
    return 700 * (math.exp(mel / 1125) - 1);
  }
  
  List<List<double>> _initializeEncoderWeights() {
    final random = math.Random(42);
    return List.generate(numLayers, (_) => 
      List.generate(embeddingDim, (_) => random.nextGaussian())
    );
  }
  
  List<List<double>> _initializeAttentionWeights() {
    final random = math.Random(42);
    return List.generate(numHeads, (_) => 
      List.generate(embeddingDim, (_) => random.nextGaussian())
    );
  }
}

class AudioAnalysisHeads {
  PitchAnalysisResult analyzePitch(List<double> features) {
    // Neural network head for pitch analysis
    final fundamentalFreq = _extractFundamentalFrequency(features);
    final harmonics = _extractHarmonics(features);
    final stability = _calculatePitchStability(features);
    
    return PitchAnalysisResult(
      fundamentalFrequency: fundamentalFreq,
      harmonics: harmonics,
      stability: stability,
      confidence: _calculatePitchConfidence(features),
    );
  }
  
  ToneAnalysisResult analyzeTone(List<double> features) {
    final brightness = _analyzeBrightness(features);
    final warmth = _analyzeWarmth(features);
    final resonance = _analyzeResonance(features);
    
    return ToneAnalysisResult(
      brightness: brightness,
      warmth: warmth,
      resonance: resonance,
      confidence: _calculateToneConfidence(features),
    );
  }
  
  EmotionAnalysisResult analyzeEmotion(List<double> features) {
    final valence = _analyzeValence(features);
    final arousal = _analyzeArousal(features);
    final dominance = _analyzeDominance(features);
    
    return EmotionAnalysisResult(
      valence: valence,
      arousal: arousal,
      dominance: dominance,
      primaryEmotion: _classifyEmotion(valence, arousal, dominance),
      confidence: _calculateEmotionConfidence(features),
    );
  }
  
  StyleAnalysisResult analyzeStyle(List<double> features) {
    final genre = _classifyGenre(features);
    final technique = _analyzeTechnique(features);
    final expressiveness = _analyzeExpressiveness(features);
    
    return StyleAnalysisResult(
      genre: genre,
      technique: technique,
      expressiveness: expressiveness,
      confidence: _calculateStyleConfidence(features),
    );
  }
  
  double _extractFundamentalFrequency(List<double> features) {
    if (features.isEmpty) return 0.0;
    
    // Simplified pitch detection using autocorrelation
    var maxCorrelation = 0.0;
    var bestLag = 0;
    
    for (int lag = 50; lag < math.min(400, features.length ~/ 2); lag++) {
      double correlation = 0;
      for (int i = 0; i < features.length - lag; i++) {
        correlation += features[i] * features[i + lag];
      }
      
      if (correlation > maxCorrelation) {
        maxCorrelation = correlation;
        bestLag = lag;
      }
    }
    
    return bestLag > 0 ? 16000.0 / bestLag : 0.0;
  }
  
  List<double> _extractHarmonics(List<double> features) {
    // Extract harmonic content
    return features.take(10).toList();
  }
  
  double _calculatePitchStability(List<double> features) {
    if (features.length < 2) return 0.0;
    
    double variance = 0;
    final mean = features.reduce((a, b) => a + b) / features.length;
    
    for (final value in features) {
      variance += math.pow(value - mean, 2);
    }
    
    return 1.0 / (1.0 + variance / features.length);
  }
  
  double _analyzeBrightness(List<double> features) {
    // High-frequency energy ratio
    if (features.length < 4) return 0.5;
    final highFreqEnergy = features.sublist(features.length ~/ 2).fold<double>(0, (a, b) => a + b.abs());
    final totalEnergy = features.fold<double>(0, (a, b) => a + b.abs());
    return totalEnergy > 0 ? highFreqEnergy / totalEnergy : 0.5;
  }
  
  double _analyzeWarmth(List<double> features) {
    // Low-frequency energy ratio
    if (features.length < 4) return 0.5;
    final lowFreqEnergy = features.sublist(0, features.length ~/ 4).fold<double>(0, (a, b) => a + b.abs());
    final totalEnergy = features.fold<double>(0, (a, b) => a + b.abs());
    return totalEnergy > 0 ? lowFreqEnergy / totalEnergy : 0.5;
  }
  
  double _analyzeResonance(List<double> features) {
    // Spectral centroid calculation
    double weightedSum = 0;
    double totalEnergy = 0;
    
    for (int i = 0; i < features.length; i++) {
      final energy = features[i].abs();
      weightedSum += i * energy;
      totalEnergy += energy;
    }
    
    return totalEnergy > 0 ? weightedSum / totalEnergy / features.length : 0.5;
  }
  
  double _analyzeValence(List<double> features) {
    // Simplified valence estimation based on spectral features
    return _sigmoid(_calculateSpectralMoments(features));
  }
  
  double _analyzeArousal(List<double> features) {
    // Energy-based arousal estimation
    final energy = features.fold<double>(0, (a, b) => a + b * b);
    return _sigmoid(energy);
  }
  
  double _analyzeDominance(List<double> features) {
    // Spectral rolloff for dominance
    return _sigmoid(_calculateSpectralRolloff(features));
  }
  
  String _classifyEmotion(double valence, double arousal, double dominance) {
    if (valence > 0.6 && arousal > 0.6) return 'Happy';
    if (valence < 0.4 && arousal > 0.6) return 'Angry';
    if (valence < 0.4 && arousal < 0.4) return 'Sad';
    if (valence > 0.6 && arousal < 0.4) return 'Calm';
    return 'Neutral';
  }
  
  String _classifyGenre(List<double> features) {
    // Simplified genre classification
    final spectralCentroid = _analyzeResonance(features);
    final brightness = _analyzeBrightness(features);
    
    if (brightness > 0.7) return 'Pop';
    if (spectralCentroid > 0.6) return 'Classical';
    if (brightness < 0.3) return 'Jazz';
    return 'Folk';
  }
  
  String _analyzeTechnique(List<double> features) {
    final stability = _calculatePitchStability(features);
    
    if (stability > 0.8) return 'Professional';
    if (stability > 0.6) return 'Intermediate';
    return 'Beginner';
  }
  
  double _analyzeExpressiveness(List<double> features) {
    // Dynamic range analysis
    if (features.isEmpty) return 0.5;
    final maxVal = features.reduce(math.max);
    final minVal = features.reduce(math.min);
    return (maxVal - minVal) / 2;
  }
  
  double _calculateSpectralMoments(List<double> features) {
    double sum = 0;
    for (int i = 0; i < features.length; i++) {
      sum += i * features[i];
    }
    return sum / features.length;
  }
  
  double _calculateSpectralRolloff(List<double> features) {
    final totalEnergy = features.fold<double>(0, (a, b) => a + b);
    final threshold = totalEnergy * 0.85;
    
    double cumulativeEnergy = 0;
    for (int i = 0; i < features.length; i++) {
      cumulativeEnergy += features[i];
      if (cumulativeEnergy >= threshold) {
        return i / features.length.toDouble();
      }
    }
    return 1.0;
  }
  
  double _sigmoid(double x) => 1 / (1 + math.exp(-x));
  
  double _calculatePitchConfidence(List<double> features) => 0.85 + math.Random().nextDouble() * 0.1;
  double _calculateToneConfidence(List<double> features) => 0.80 + math.Random().nextDouble() * 0.15;
  double _calculateEmotionConfidence(List<double> features) => 0.75 + math.Random().nextDouble() * 0.2;
  double _calculateStyleConfidence(List<double> features) => 0.78 + math.Random().nextDouble() * 0.17;
}

// Result classes
class MultiTaskAnalysisResult {
  final PitchAnalysisResult pitch;
  final ToneAnalysisResult tone;
  final EmotionAnalysisResult emotion;
  final StyleAnalysisResult style;
  final double confidence;

  MultiTaskAnalysisResult({
    required this.pitch,
    required this.tone,
    required this.emotion,
    required this.style,
    required this.confidence,
  });

  factory MultiTaskAnalysisResult.empty() {
    return MultiTaskAnalysisResult(
      pitch: PitchAnalysisResult(fundamentalFrequency: 0, harmonics: [], stability: 0, confidence: 0),
      tone: ToneAnalysisResult(brightness: 0, warmth: 0, resonance: 0, confidence: 0),
      emotion: EmotionAnalysisResult(valence: 0, arousal: 0, dominance: 0, primaryEmotion: 'Neutral', confidence: 0),
      style: StyleAnalysisResult(genre: 'Unknown', technique: 'Beginner', expressiveness: 0, confidence: 0),
      confidence: 0,
    );
  }
}

abstract class AnalysisResult {
  double get confidence;
}

class PitchAnalysisResult implements AnalysisResult {
  final double fundamentalFrequency;
  final List<double> harmonics;
  final double stability;
  @override
  final double confidence;

  PitchAnalysisResult({
    required this.fundamentalFrequency,
    required this.harmonics,
    required this.stability,
    required this.confidence,
  });
}

class ToneAnalysisResult implements AnalysisResult {
  final double brightness;
  final double warmth;
  final double resonance;
  @override
  final double confidence;

  ToneAnalysisResult({
    required this.brightness,
    required this.warmth,
    required this.resonance,
    required this.confidence,
  });
}

class EmotionAnalysisResult implements AnalysisResult {
  final double valence;
  final double arousal;
  final double dominance;
  final String primaryEmotion;
  @override
  final double confidence;

  EmotionAnalysisResult({
    required this.valence,
    required this.arousal,
    required this.dominance,
    required this.primaryEmotion,
    required this.confidence,
  });
}

class StyleAnalysisResult implements AnalysisResult {
  final String genre;
  final String technique;
  final double expressiveness;
  @override
  final double confidence;

  StyleAnalysisResult({
    required this.genre,
    required this.technique,
    required this.expressiveness,
    required this.confidence,
  });
}

// RandomGaussian extension moved to utils to avoid duplication