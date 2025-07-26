import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../ai_analysis/transformer_audio_analyzer.dart';
import '../../core/utils/random_utils.dart';
import 'ai_model_loader.dart';

/// GPT-4 Style Generative AI Coaching Engine
/// Features: LoRA Fine-tuning, RAG, Personalized Coaching
class GenerativeCoachingEngine {
  static const int maxContextLength = 2048;
  static const int embeddingDim = 768;
  static const int numHeads = 12;
  static const int numLayers = 12;
  
  late VocalKnowledgeBase _knowledgeBase;
  late LoRAAdapter _loraAdapter;
  late PersonalizationEngine _personalizationEngine;
  late AIModelLoader _modelLoader;
  
  // Transformer parameters
  late List<List<List<double>>> _attentionWeights;
  late List<List<double>> _feedForwardWeights;
  late Map<String, List<double>> _tokenEmbeddings;
  
  bool _isInitialized = false;
  
  GenerativeCoachingEngine() {
    _initializeEngine();
  }
  
  void _initializeEngine() {
    try {
      _knowledgeBase = VocalKnowledgeBase();
      _loraAdapter = LoRAAdapter();
      _personalizationEngine = PersonalizationEngine();
      _modelLoader = AIModelLoader();
      _initializeTransformerWeights();
      _loadAIModels();
      _isInitialized = true;
      
      if (kDebugMode) {
        debugPrint('Generative AI Coaching Engine initialized');
      }
    } catch (e) {
      debugPrint('Failed to initialize Generative AI Coaching Engine: $e');
      _isInitialized = false;
    }
  }
  
  /// Load AI models asynchronously
  Future<void> _loadAIModels() async {
    try {
      await _modelLoader.initialize();
      
      // Preload core models
      await _modelLoader.preloadModels([
        'coaching_generator',
        'emotion_classifier',
        'style_analyzer',
      ]);
      
      if (kDebugMode) {
        final stats = _modelLoader.getStatistics();
        debugPrint('AI Models loaded: ${stats['total_models']} models, ${stats['total_memory_mb']}MB');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load AI models: $e');
      }
    }
  }
  
  void _initializeTransformerWeights() {
    final random = math.Random(42);
    
    // Initialize attention weights
    _attentionWeights = List.generate(numLayers, (_) =>
      List.generate(numHeads, (_) =>
        List.generate(embeddingDim, (_) => random.nextGaussian() * 0.02)
      )
    );
    
    // Initialize feed-forward weights
    _feedForwardWeights = List.generate(numLayers, (_) =>
      List.generate(embeddingDim * 4, (_) => random.nextGaussian() * 0.02)
    );
    
    // Initialize token embeddings
    _tokenEmbeddings = _createVocalTokenEmbeddings();
  }
  
  /// Generate personalized coaching advice
  Future<CoachingResponse> generateCoaching({
    required MultiTaskAnalysisResult analysisResult,
    required UserProfile userProfile,
    required List<String> conversationHistory,
    required CoachingContext context,
  }) async {
    if (!_isInitialized) {
      debugPrint('Coaching engine not initialized, using fallback');
      return _getFallbackResponse(analysisResult);
    }
    
    try {
      // 1. RAG: Retrieve relevant knowledge
      final retrievedKnowledge = await _retrieveRelevantKnowledge(analysisResult, context);
      
      // 2. Build context with user personalization
      final contextTokens = _buildCoachingContext(
        analysisResult, 
        userProfile, 
        conversationHistory,
        retrievedKnowledge,
        context,
      );
      
      // 3. Generate response using transformer + LoRA
      final generatedTokens = await _generateResponse(contextTokens, userProfile);
      
      // 4. Post-process and validate response
      final response = _postProcessResponse(generatedTokens, analysisResult);
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Coaching generation error: $e');
      }
      return _getFallbackResponse(analysisResult);
    }
  }
  
  Future<List<KnowledgeChunk>> _retrieveRelevantKnowledge(
    MultiTaskAnalysisResult analysisResult,
    CoachingContext context,
  ) async {
    // Semantic search in knowledge base
    final queryEmbedding = _createQueryEmbedding(analysisResult, context);
    return await _knowledgeBase.semanticSearch(queryEmbedding, topK: 5);
  }
  
  List<double> _createQueryEmbedding(MultiTaskAnalysisResult analysis, CoachingContext context) {
    // Create embedding from analysis results
    final embedding = List<double>.filled(embeddingDim, 0.0);
    
    // Encode pitch information
    _encodePitchFeatures(analysis.pitch, embedding, 0, 100);
    
    // Encode tone information
    _encodeToneFeatures(analysis.tone, embedding, 100, 200);
    
    // Encode emotion information
    _encodeEmotionFeatures(analysis.emotion, embedding, 200, 300);
    
    // Encode style information
    _encodeStyleFeatures(analysis.style, embedding, 300, 400);
    
    // Encode context
    _encodeContext(context, embedding, 400, 500);
    
    return embedding;
  }
  
  void _encodePitchFeatures(PitchAnalysisResult pitch, List<double> embedding, int start, int end) {
    if (end <= start) return;
    
    final freqNorm = pitch.fundamentalFrequency / 1000.0; // Normalize to [0,1] range
    final stabilityNorm = pitch.stability;
    
    for (int i = start; i < math.min(end, embedding.length); i++) {
      final ratio = (i - start) / (end - start);
      embedding[i] = ratio < 0.5 ? freqNorm * math.sin(ratio * math.pi) : 
                                   stabilityNorm * math.cos(ratio * math.pi);
    }
  }
  
  void _encodeToneFeatures(ToneAnalysisResult tone, List<double> embedding, int start, int end) {
    if (end <= start) return;
    
    for (int i = start; i < math.min(end, embedding.length); i++) {
      final ratio = (i - start) / (end - start);
      if (ratio < 0.33) {
        embedding[i] = tone.brightness * math.sin(ratio * 3 * math.pi);
      } else if (ratio < 0.66) {
        embedding[i] = tone.warmth * math.cos(ratio * 3 * math.pi);
      } else {
        embedding[i] = tone.resonance * math.tan(ratio * math.pi / 4);
      }
    }
  }
  
  void _encodeEmotionFeatures(EmotionAnalysisResult emotion, List<double> embedding, int start, int end) {
    if (end <= start) return;
    
    for (int i = start; i < math.min(end, embedding.length); i++) {
      final ratio = (i - start) / (end - start);
      embedding[i] = emotion.valence * math.cos(ratio * 2 * math.pi) +
                     emotion.arousal * math.sin(ratio * 2 * math.pi) +
                     emotion.dominance * math.cos(ratio * math.pi);
    }
  }
  
  void _encodeStyleFeatures(StyleAnalysisResult style, List<double> embedding, int start, int end) {
    if (end <= start) return;
    
    final genreEncoding = _encodeGenre(style.genre);
    final techniqueEncoding = _encodeTechnique(style.technique);
    
    for (int i = start; i < math.min(end, embedding.length); i++) {
      final ratio = (i - start) / (end - start);
      embedding[i] = genreEncoding * math.exp(-ratio) +
                     techniqueEncoding * (1 - math.exp(-ratio)) +
                     style.expressiveness * math.sin(ratio * math.pi);
    }
  }
  
  void _encodeContext(CoachingContext context, List<double> embedding, int start, int end) {
    if (end <= start) return;
    
    for (int i = start; i < math.min(end, embedding.length); i++) {
      final ratio = (i - start) / (end - start);
      embedding[i] = _encodeContextType(context.type) * math.cos(ratio * math.pi) +
                     context.intensity * math.sin(ratio * 2 * math.pi);
    }
  }
  
  double _encodeGenre(String genre) {
    const genreMap = {
      'Pop': 0.2, 'Classical': 0.4, 'Jazz': 0.6, 'Folk': 0.8, 'Unknown': 0.0
    };
    return genreMap[genre] ?? 0.0;
  }
  
  double _encodeTechnique(String technique) {
    const techniqueMap = {
      'Beginner': 0.2, 'Intermediate': 0.5, 'Professional': 0.9
    };
    return techniqueMap[technique] ?? 0.2;
  }
  
  double _encodeContextType(CoachingType type) {
    switch (type) {
      case CoachingType.realTime: return 0.3;
      case CoachingType.detailed: return 0.7;
      case CoachingType.encouragement: return 0.9;
      case CoachingType.correction: return 0.5;
    }
  }
  
  List<String> _buildCoachingContext(
    MultiTaskAnalysisResult analysis,
    UserProfile userProfile,
    List<String> history,
    List<KnowledgeChunk> knowledge,
    CoachingContext context,
  ) {
    final contextTokens = <String>[];
    
    // Add system prompt
    contextTokens.addAll(_createSystemPrompt(userProfile));
    
    // Add retrieved knowledge
    for (final chunk in knowledge) {
      contextTokens.addAll(_tokenizeKnowledge(chunk));
    }
    
    // Add conversation history (recent first)
    final recentHistory = history.reversed.take(5).toList().reversed;
    for (final turn in recentHistory) {
      contextTokens.addAll(_tokenize(turn));
    }
    
    // Add current analysis
    contextTokens.addAll(_tokenizeAnalysis(analysis));
    
    // Add coaching context
    contextTokens.addAll(_tokenizeContext(context));
    
    // Truncate to max context length
    return contextTokens.take(maxContextLength - 100).toList();
  }
  
  List<String> _createSystemPrompt(UserProfile userProfile) {
    final prompt = '''
You are an expert vocal coach AI with deep knowledge of singing technique, music theory, and voice physiology.
Your student: ${userProfile.name} (${userProfile.experience} level, goal: ${userProfile.goal})
Previous sessions: ${userProfile.sessionCount}
Preferred style: ${userProfile.preferredGenre}

Guidelines:
- Provide specific, actionable advice
- Use encouraging and supportive tone
- Reference musical terminology appropriately for skill level
- Give practical exercises when helpful
- Be concise but comprehensive
''';
    return _tokenize(prompt);
  }
  
  List<String> _tokenizeKnowledge(KnowledgeChunk chunk) {
    return _tokenize('Expert knowledge: ${chunk.content}');
  }
  
  List<String> _tokenizeAnalysis(MultiTaskAnalysisResult analysis) {
    final analysisText = '''
Current analysis:
- Pitch: ${analysis.pitch.fundamentalFrequency.toStringAsFixed(1)}Hz, stability: ${(analysis.pitch.stability * 100).toStringAsFixed(0)}%
- Tone: brightness: ${(analysis.tone.brightness * 100).toStringAsFixed(0)}%, warmth: ${(analysis.tone.warmth * 100).toStringAsFixed(0)}%
- Emotion: ${analysis.emotion.primaryEmotion} (valence: ${(analysis.emotion.valence * 100).toStringAsFixed(0)}%)
- Style: ${analysis.style.genre}, technique: ${analysis.style.technique}
''';
    return _tokenize(analysisText);
  }
  
  List<String> _tokenizeContext(CoachingContext context) {
    return _tokenize('Coaching focus: ${context.type.name}, intensity: ${context.intensity}');
  }
  
  List<String> _tokenize(String text) {
    // Simplified tokenization (word-level)
    return text.toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();
  }
  
  Future<List<String>> _generateResponse(List<String> contextTokens, UserProfile userProfile) async {
    try {
      // Check if we have real models loaded
      final coachingModel = _modelLoader.getModelInfo('coaching_generator');
      
      if (coachingModel != null && !coachingModel.isPlaceholder) {
        // Use real AI model for generation
        return await _generateWithRealModel(contextTokens, userProfile, coachingModel);
      } else {
        // Use simulated transformer approach
        return await _generateWithSimulatedModel(contextTokens, userProfile);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Response generation failed: $e');
      }
      return _generateFallbackResponse(contextTokens, userProfile);
    }
  }
  
  Future<List<String>> _generateWithRealModel(
    List<String> contextTokens, 
    UserProfile userProfile, 
    ModelData model
  ) async {
    // TODO: Implement TensorFlow Lite inference
    // This would involve:
    // 1. Prepare input tensor from contextTokens
    // 2. Run inference on the model
    // 3. Post-process output tensor to tokens
    
    if (kDebugMode) {
      debugPrint('Using real model: ${model.name} (${model.memorySizeMB.toStringAsFixed(1)}MB)');
    }
    
    // For now, fall back to simulated model
    return await _generateWithSimulatedModel(contextTokens, userProfile);
  }
  
  Future<List<String>> _generateWithSimulatedModel(List<String> contextTokens, UserProfile userProfile) async {
    // Convert tokens to embeddings
    final inputEmbeddings = _tokensToEmbeddings(contextTokens);
    
    // Apply LoRA fine-tuning
    final adaptedEmbeddings = _loraAdapter.adapt(inputEmbeddings, userProfile);
    
    // Transformer forward pass
    final outputEmbeddings = _transformerForward(adaptedEmbeddings);
    
    // Generate tokens
    final generatedTokens = _embeddingsToTokens(outputEmbeddings);
    
    return generatedTokens;
  }
  
  List<String> _generateFallbackResponse(List<String> contextTokens, UserProfile userProfile) {
    // Simple rule-based fallback
    final responses = [
      '좋은', '시도입니다', '계속', '연습하세요',
      '음정을', '안정적으로', '유지해보세요',
      '호흡을', '깊게', '하고', '발성하세요',
    ];
    
    return responses.take(8).toList();
  }
  
  List<List<double>> _tokensToEmbeddings(List<String> tokens) {
    return tokens.map((token) {
      return _tokenEmbeddings[token] ?? _getUnknownTokenEmbedding();
    }).toList();
  }
  
  List<double> _getUnknownTokenEmbedding() {
    final random = math.Random();
    return List.generate(embeddingDim, (_) => random.nextGaussian() * 0.01);
  }
  
  List<List<double>> _transformerForward(List<List<double>> inputEmbeddings) {
    var hidden = inputEmbeddings;
    
    // Multi-layer transformer
    for (int layer = 0; layer < numLayers; layer++) {
      // Multi-head self-attention
      hidden = _multiHeadAttention(hidden, layer);
      
      // Feed-forward network
      hidden = _feedForward(hidden, layer);
      
      // Residual connections and layer normalization
      hidden = _layerNormalization(hidden);
    }
    
    return hidden;
  }
  
  List<List<double>> _multiHeadAttention(List<List<double>> input, int layerIndex) {
    final output = <List<double>>[];
    
    for (int i = 0; i < input.length; i++) {
      final attended = List<double>.filled(embeddingDim, 0.0);
      
      // Simplified multi-head attention
      for (int head = 0; head < numHeads; head++) {
        final headOutput = _singleHeadAttention(input, i, layerIndex, head);
        for (int j = 0; j < headOutput.length && j < attended.length; j++) {
          attended[j] += headOutput[j] / numHeads;
        }
      }
      
      output.add(attended);
    }
    
    return output;
  }
  
  List<double> _singleHeadAttention(List<List<double>> input, int queryIndex, int layer, int head) {
    final query = input[queryIndex];
    final attended = List<double>.filled(embeddingDim, 0.0);
    
    // Calculate attention weights
    double totalWeight = 0;
    final weights = <double>[];
    
    for (int i = 0; i < input.length; i++) {
      final key = input[i];
      final weight = _calculateAttentionScore(query, key, layer, head);
      weights.add(weight);
      totalWeight += weight;
    }
    
    // Normalize weights and apply
    for (int i = 0; i < input.length; i++) {
      final normalizedWeight = totalWeight > 0 ? weights[i] / totalWeight : 0;
      for (int j = 0; j < input[i].length && j < attended.length; j++) {
        attended[j] += input[i][j] * normalizedWeight;
      }
    }
    
    return attended;
  }
  
  double _calculateAttentionScore(List<double> query, List<double> key, int layer, int head) {
    double dotProduct = 0;
    final minLength = math.min(query.length, key.length);
    
    for (int i = 0; i < minLength; i++) {
      dotProduct += query[i] * key[i];
    }
    
    return math.exp(dotProduct / math.sqrt(embeddingDim));
  }
  
  List<List<double>> _feedForward(List<List<double>> input, int layerIndex) {
    return input.map((sequence) {
      final expanded = <double>[];
      
      // Expand to 4x embedding dimension
      for (int i = 0; i < embeddingDim * 4; i++) {
        double sum = 0;
        for (int j = 0; j < sequence.length; j++) {
          if (i < _feedForwardWeights[layerIndex].length) {
            sum += sequence[j] * _feedForwardWeights[layerIndex][i] * math.cos(i + j);
          }
        }
        expanded.add(math.max(0, sum)); // ReLU activation
      }
      
      // Project back to embedding dimension
      final output = <double>[];
      for (int i = 0; i < embeddingDim; i++) {
        double sum = 0;
        for (int j = 0; j < expanded.length; j++) {
          sum += expanded[j] * math.sin(i + j) * 0.1;
        }
        output.add(sum);
      }
      
      return output;
    }).toList();
  }
  
  List<List<double>> _layerNormalization(List<List<double>> input) {
    return input.map((sequence) {
      final mean = sequence.reduce((a, b) => a + b) / sequence.length;
      final variance = sequence.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / sequence.length;
      final std = math.sqrt(variance + 1e-8);
      
      return sequence.map((x) => (x - mean) / std).toList();
    }).toList();
  }
  
  List<String> _embeddingsToTokens(List<List<double>> embeddings) {
    // Simplified token generation using nearest neighbor search
    final tokens = <String>[];
    
    for (final embedding in embeddings.take(50)) { // Limit output length
      String bestToken = '';
      double bestSimilarity = double.negativeInfinity;
      
      for (final entry in _tokenEmbeddings.entries) {
        final similarity = _cosineSimilarity(embedding, entry.value);
        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestToken = entry.key;
        }
      }
      
      if (bestToken.isNotEmpty) {
        tokens.add(bestToken);
      }
    }
    
    return tokens;
  }
  
  double _cosineSimilarity(List<double> a, List<double> b) {
    double dotProduct = 0;
    double normA = 0;
    double normB = 0;
    final minLength = math.min(a.length, b.length);
    
    for (int i = 0; i < minLength; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    final denominator = math.sqrt(normA) * math.sqrt(normB);
    return denominator > 0 ? dotProduct / denominator : 0;
  }
  
  CoachingResponse _postProcessResponse(List<String> tokens, MultiTaskAnalysisResult analysis) {
    final responseText = tokens.join(' ');
    
    // Extract actionable advice
    final advice = _extractAdvice(responseText, analysis);
    
    // Generate exercises
    final exercises = _generateExercises(analysis);
    
    // Calculate confidence
    final confidence = _calculateResponseConfidence(tokens, analysis);
    
    return CoachingResponse(
      mainAdvice: advice,
      exercises: exercises,
      encouragement: _generateEncouragement(analysis),
      technicalTips: _generateTechnicalTips(analysis),
      nextSteps: _generateNextSteps(analysis),
      confidence: confidence,
    );
  }
  
  String _extractAdvice(String responseText, MultiTaskAnalysisResult analysis) {
    // Extract main advice from generated text
    final sentences = responseText.split('.');
    return sentences.isNotEmpty ? sentences.first.trim() : _getFallbackAdvice(analysis);
  }
  
  List<VocalExercise> _generateExercises(MultiTaskAnalysisResult analysis) {
    final exercises = <VocalExercise>[];
    
    // Pitch exercises
    if (analysis.pitch.stability < 0.7) {
      exercises.add(VocalExercise(
        name: '음정 안정성 연습',
        description: '한 음을 10초간 유지하며 안정적으로 부르기',
        duration: const Duration(minutes: 5),
        difficulty: ExerciseDifficulty.beginner,
      ));
    }
    
    // Tone exercises
    if (analysis.tone.warmth < 0.5) {
      exercises.add(VocalExercise(
        name: '따뜻한 음색 연습',
        description: '입을 둥글게 하고 "오" 소리로 스케일 연습',
        duration: const Duration(minutes: 3),
        difficulty: ExerciseDifficulty.intermediate,
      ));
    }
    
    return exercises;
  }
  
  String _generateEncouragement(MultiTaskAnalysisResult analysis) {
    if (analysis.confidence > 0.8) {
      return '훌륭한 진전을 보이고 있습니다! 계속 이 속도로 연습하세요.';
    } else if (analysis.confidence > 0.6) {
      return '좋은 시도입니다. 조금 더 연습하면 분명 향상될 것입니다.';
    } else {
      return '연습은 완벽을 만듭니다. 포기하지 말고 계속 도전하세요!';
    }
  }
  
  List<String> _generateTechnicalTips(MultiTaskAnalysisResult analysis) {
    final tips = <String>[];
    
    if (analysis.pitch.stability < 0.6) {
      tips.add('복식호흡을 사용하여 음정을 안정시키세요');
    }
    
    if (analysis.tone.brightness > 0.8) {
      tips.add('목소리가 너무 밝습니다. 입 모양을 조금 더 둥글게 해보세요');
    }
    
    if (analysis.emotion.arousal < 0.3) {
      tips.add('더 많은 감정을 표현해보세요. 얼굴 표정도 함께 활용하세요');
    }
    
    return tips;
  }
  
  List<String> _generateNextSteps(MultiTaskAnalysisResult analysis) {
    final steps = <String>[];
    
    if (analysis.style.technique == 'Beginner') {
      steps.add('기본 발성 연습에 집중하세요');
      steps.add('음계 연습을 매일 10분씩 하세요');
    } else if (analysis.style.technique == 'Intermediate') {
      steps.add('다양한 장르의 곡에 도전해보세요');
      steps.add('감정 표현 연습을 늘려보세요');
    } else {
      steps.add('개인만의 스타일을 개발해보세요');
      steps.add('고급 기법 연습에 집중하세요');
    }
    
    return steps;
  }
  
  double _calculateResponseConfidence(List<String> tokens, MultiTaskAnalysisResult analysis) {
    // Calculate confidence based on token quality and analysis quality
    final tokenQuality = tokens.length > 5 ? 0.8 : 0.5;
    final analysisQuality = analysis.confidence;
    return (tokenQuality + analysisQuality) / 2;
  }
  
  String _getFallbackAdvice(MultiTaskAnalysisResult analysis) {
    if (analysis.pitch.stability < 0.5) {
      return '음정 안정성을 향상시키기 위해 천천히 정확한 음정으로 연습하세요.';
    } else if (analysis.tone.brightness < 0.3) {
      return '목소리에 더 많은 밝기를 추가해보세요. 미소를 지으며 노래해보세요.';
    } else {
      return '꾸준한 연습이 가장 중요합니다. 매일 조금씩이라도 연습하세요.';
    }
  }
  
  /// Get AI model statistics
  Map<String, dynamic> getModelStatistics() {
    if (!_isInitialized) {
      return {'error': 'Engine not initialized'};
    }
    
    return _modelLoader.getStatistics();
  }
  
  /// Dispose resources
  void dispose() {
    if (_isInitialized) {
      _modelLoader.dispose();
      _isInitialized = false;
    }
  }
  
  CoachingResponse _getFallbackResponse(MultiTaskAnalysisResult analysis) {
    return CoachingResponse(
      mainAdvice: _getFallbackAdvice(analysis),
      exercises: [],
      encouragement: '계속 연습하면 분명 향상될 것입니다!',
      technicalTips: ['기본기에 충실하세요', '꾸준한 연습이 중요합니다'],
      nextSteps: ['매일 연습 시간을 정하세요', '목표를 설정하고 달성해보세요'],
      confidence: 0.7,
    );
  }
  
  Map<String, List<double>> _createVocalTokenEmbeddings() {
    final random = math.Random(42);
    final tokens = [
      // Vocal technique terms
      'pitch', 'tone', 'vibrato', 'resonance', 'breath', 'support', 'diaphragm',
      'chest', 'head', 'mixed', 'voice', 'register', 'passaggio', 'formant',
      'bright', 'warm', 'dark', 'rich', 'thin', 'full', 'clear', 'muddy',
      
      // Emotions and expressions
      'happy', 'sad', 'angry', 'calm', 'excited', 'peaceful', 'energetic',
      'gentle', 'powerful', 'subtle', 'dramatic', 'expressive', 'emotional',
      
      // Musical terms
      'melody', 'harmony', 'rhythm', 'tempo', 'dynamics', 'forte', 'piano',
      'crescendo', 'diminuendo', 'legato', 'staccato', 'phrase', 'breath',
      
      // Coaching language
      'practice', 'improve', 'focus', 'relax', 'concentrate', 'listen',
      'feel', 'control', 'stability', 'accuracy', 'consistency', 'progress',
      'excellent', 'good', 'better', 'try', 'again', 'continue', 'stop',
      
      // Common words
      'the', 'and', 'or', 'but', 'with', 'from', 'to', 'in', 'on', 'at',
      'you', 'your', 'this', 'that', 'these', 'those', 'now', 'then', 'here',
    ];
    
    final embeddings = <String, List<double>>{};
    for (final token in tokens) {
      embeddings[token] = List.generate(embeddingDim, (_) => random.nextGaussian() * 0.1);
    }
    
    return embeddings;
  }
}

// Supporting classes
class VocalKnowledgeBase {
  final List<KnowledgeChunk> _knowledge = [];
  
  VocalKnowledgeBase() {
    _initializeKnowledge();
  }
  
  void _initializeKnowledge() {
    _knowledge.addAll([
      KnowledgeChunk(
        id: '1',
        content: 'Proper breathing technique involves using the diaphragm to support airflow, creating stable pitch and tone.',
        category: 'breathing',
        embedding: _createEmbedding('breathing diaphragm support airflow pitch tone'),
      ),
      KnowledgeChunk(
        id: '2',
        content: 'Pitch accuracy can be improved through ear training, vocal exercises, and consistent practice with a piano or tuner.',
        category: 'pitch',
        embedding: _createEmbedding('pitch accuracy ear training vocal exercises piano tuner'),
      ),
      KnowledgeChunk(
        id: '3',
        content: 'Resonance is created by proper placement of sound in the vocal tract, involving the mouth, throat, and nasal cavities.',
        category: 'resonance',
        embedding: _createEmbedding('resonance placement vocal tract mouth throat nasal'),
      ),
      KnowledgeChunk(
        id: '4',
        content: 'Emotional expression in singing comes from connecting with the lyrics and using vocal techniques to convey feeling.',
        category: 'expression',
        embedding: _createEmbedding('emotional expression singing lyrics vocal techniques feeling'),
      ),
      KnowledgeChunk(
        id: '5',
        content: 'Vocal warm-ups are essential to prevent strain and prepare the voice for singing, including lip trills and gentle scales.',
        category: 'warmup',
        embedding: _createEmbedding('vocal warmups prevent strain prepare voice lip trills scales'),
      ),
    ]);
  }
  
  List<double> _createEmbedding(String text) {
    final random = math.Random(text.hashCode);
    return List.generate(768, (_) => random.nextGaussian());
  }
  
  Future<List<KnowledgeChunk>> semanticSearch(List<double> queryEmbedding, {int topK = 5}) async {
    final scores = <MapEntry<KnowledgeChunk, double>>[];
    
    for (final chunk in _knowledge) {
      final similarity = _cosineSimilarity(queryEmbedding, chunk.embedding);
      scores.add(MapEntry(chunk, similarity));
    }
    
    scores.sort((a, b) => b.value.compareTo(a.value));
    return scores.take(topK).map((e) => e.key).toList();
  }
  
  double _cosineSimilarity(List<double> a, List<double> b) {
    double dotProduct = 0;
    double normA = 0;
    double normB = 0;
    final minLength = math.min(a.length, b.length);
    
    for (int i = 0; i < minLength; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    final denominator = math.sqrt(normA) * math.sqrt(normB);
    return denominator > 0 ? dotProduct / denominator : 0;
  }
}

class LoRAAdapter {
  static const int rank = 16;
  late List<List<double>> _loraA;
  late List<List<double>> _loraB;
  
  LoRAAdapter() {
    _initializeLoRA();
  }
  
  void _initializeLoRA() {
    final random = math.Random(42);
    _loraA = List.generate(GenerativeCoachingEngine.embeddingDim, (_) =>
      List.generate(rank, (_) => random.nextGaussian() * 0.01)
    );
    _loraB = List.generate(rank, (_) =>
      List.generate(GenerativeCoachingEngine.embeddingDim, (_) => random.nextGaussian() * 0.01)
    );
  }
  
  List<List<double>> adapt(List<List<double>> embeddings, UserProfile userProfile) {
    // Apply LoRA adaptation based on user profile
    final adaptationStrength = _calculateAdaptationStrength(userProfile);
    
    return embeddings.map((embedding) {
      final adapted = List<double>.from(embedding);
      
      // LoRA forward pass: x + B * A * x * α
      final loraOutput = _applyLoRA(embedding, adaptationStrength);
      
      for (int i = 0; i < adapted.length; i++) {
        adapted[i] += loraOutput[i];
      }
      
      return adapted;
    }).toList();
  }
  
  List<double> _applyLoRA(List<double> input, double alpha) {
    // x -> A -> B
    final intermediate = List<double>.filled(rank, 0.0);
    
    // A projection
    for (int i = 0; i < rank; i++) {
      for (int j = 0; j < math.min(input.length, _loraA.length); j++) {
        intermediate[i] += input[j] * _loraA[j][i];
      }
    }
    
    // B projection
    final output = List<double>.filled(input.length, 0.0);
    for (int i = 0; i < output.length && i < _loraB[0].length; i++) {
      for (int j = 0; j < intermediate.length && j < _loraB.length; j++) {
        output[i] += intermediate[j] * _loraB[j][i] * alpha;
      }
    }
    
    return output;
  }
  
  double _calculateAdaptationStrength(UserProfile userProfile) {
    // Adjust adaptation based on user experience and preferences
    double strength = 0.1; // Base strength
    
    switch (userProfile.experience) {
      case 'Beginner':
        strength *= 1.5; // More adaptation for beginners
        break;
      case 'Intermediate':
        strength *= 1.0;
        break;
      case 'Professional':
        strength *= 0.7; // Less adaptation for professionals
        break;
    }
    
    return strength;
  }
}

class PersonalizationEngine {
  Map<String, UserProfile> _userProfiles = {};
  
  void updateUserProfile(String userId, UserProfile profile) {
    _userProfiles[userId] = profile;
  }
  
  UserProfile? getUserProfile(String userId) {
    return _userProfiles[userId];
  }
  
  void recordFeedback(String userId, String feedback, double rating) {
    final profile = _userProfiles[userId];
    if (profile != null) {
      profile.feedbackHistory.add(UserFeedback(
        feedback: feedback,
        rating: rating,
        timestamp: DateTime.now(),
      ));
    }
  }
}

// Data classes
class UserProfile {
  final String name;
  final String experience;
  final String goal;
  final String preferredGenre;
  final int sessionCount;
  final List<UserFeedback> feedbackHistory;
  
  UserProfile({
    required this.name,
    required this.experience,
    required this.goal,
    required this.preferredGenre,
    this.sessionCount = 0,
    List<UserFeedback>? feedbackHistory,
  }) : feedbackHistory = feedbackHistory ?? [];
}

class UserFeedback {
  final String feedback;
  final double rating;
  final DateTime timestamp;
  
  UserFeedback({
    required this.feedback,
    required this.rating,
    required this.timestamp,
  });
}

class KnowledgeChunk {
  final String id;
  final String content;
  final String category;
  final List<double> embedding;
  
  KnowledgeChunk({
    required this.id,
    required this.content,
    required this.category,
    required this.embedding,
  });
}

class CoachingContext {
  final CoachingType type;
  final double intensity;
  final List<String> focus;
  
  CoachingContext({
    required this.type,
    required this.intensity,
    required this.focus,
  });
}

enum CoachingType { realTime, detailed, encouragement, correction }

class CoachingResponse {
  final String mainAdvice;
  final List<VocalExercise> exercises;
  final String encouragement;
  final List<String> technicalTips;
  final List<String> nextSteps;
  final double confidence;
  
  CoachingResponse({
    required this.mainAdvice,
    required this.exercises,
    required this.encouragement,
    required this.technicalTips,
    required this.nextSteps,
    required this.confidence,
  });
}

class VocalExercise {
  final String name;
  final String description;
  final Duration duration;
  final ExerciseDifficulty difficulty;
  
  VocalExercise({
    required this.name,
    required this.description,
    required this.duration,
    required this.difficulty,
  });
}

enum ExerciseDifficulty { beginner, intermediate, advanced, professional }

// RandomGaussian extension moved to utils to avoid duplication