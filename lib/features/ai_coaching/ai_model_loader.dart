import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../core/utils/performance_optimizer.dart';

/// AI Model Loader for loading and managing machine learning models
class AIModelLoader {
  static final AIModelLoader _instance = AIModelLoader._internal();
  factory AIModelLoader() => _instance;
  AIModelLoader._internal();
  
  final Map<String, ModelData> _loadedModels = {};
  final PerformanceOptimizer _performanceOptimizer = PerformanceOptimizer();
  
  bool _isInitialized = false;
  
  /// Initialize the model loader
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _performanceOptimizer.initialize();
      await _loadCoreModels();
      _isInitialized = true;
      
      if (kDebugMode) {
        debugPrint('[AIModelLoader] Initialized successfully');
      }
    } catch (e) {
      debugPrint('[AIModelLoader] Initialization failed: $e');
      _isInitialized = false;
    }
  }
  
  /// Load core models that are essential for the app
  Future<void> _loadCoreModels() async {
    // Load lightweight placeholder models
    await Future.wait([
      _loadPlaceholderModel('pitch_detector', ModelType.audio),
      _loadPlaceholderModel('emotion_classifier', ModelType.classification),
      _loadPlaceholderModel('style_analyzer', ModelType.classification),
      _loadPlaceholderModel('coaching_generator', ModelType.text),
    ]);
  }
  
  /// Load a specific model by name
  Future<ModelData?> loadModel(String modelName, {ModelType? type}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    // Check if model is already loaded
    if (_loadedModels.containsKey(modelName)) {
      final model = _loadedModels[modelName]!;
      model.lastAccessed = DateTime.now();
      return model;
    }
    
    try {
      final modelData = await _loadModelFromAssets(modelName, type);
      if (modelData != null) {
        _loadedModels[modelName] = modelData;
        _manageMemory();
        return modelData;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AIModelLoader] Failed to load model $modelName: $e');
      }
    }
    
    // Return placeholder model if real model fails to load
    return await _loadPlaceholderModel(modelName, type ?? ModelType.audio);
  }
  
  /// Load model from assets
  Future<ModelData?> _loadModelFromAssets(String modelName, ModelType? type) async {
    try {
      final assetPath = 'assets/models/$modelName.tflite';
      
      // Check if asset exists (this will throw if it doesn't)
      final ByteData data = await rootBundle.load(assetPath);
      final modelBytes = data.buffer.asUint8List();
      
      // Load model metadata if available
      Map<String, dynamic>? metadata;
      try {
        final metadataPath = 'assets/models/$modelName.json';
        final metadataString = await rootBundle.loadString(metadataPath);
        metadata = jsonDecode(metadataString) as Map<String, dynamic>;
      } catch (e) {
        // Metadata is optional
        if (kDebugMode) {
          debugPrint('[AIModelLoader] No metadata found for $modelName');
        }
      }
      
      return ModelData(
        name: modelName,
        type: type ?? _inferModelType(modelName),
        data: modelBytes,
        metadata: metadata,
        size: modelBytes.length,
        loadedAt: DateTime.now(),
        lastAccessed: DateTime.now(),
        isPlaceholder: false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AIModelLoader] Asset not found: assets/models/$modelName.tflite');
      }
      return null;
    }
  }
  
  /// Create a placeholder model for development/testing
  Future<ModelData> _loadPlaceholderModel(String modelName, ModelType? type) async {
    final modelType = type ?? _inferModelType(modelName);
    final placeholderSize = _getPlaceholderSize(modelType);
    
    // Create placeholder data
    final placeholderData = Uint8List(placeholderSize);
    
    // Fill with deterministic pseudo-data for consistency
    for (int i = 0; i < placeholderSize; i++) {
      placeholderData[i] = (i * 37 + modelName.hashCode) % 256;
    }
    
    final metadata = {
      'name': modelName,
      'type': modelType.name,
      'version': '1.0.0-placeholder',
      'input_shape': _getDefaultInputShape(modelType),
      'output_shape': _getDefaultOutputShape(modelType),
      'description': 'Placeholder model for $modelName',
      'created_at': DateTime.now().toIso8601String(),
    };
    
    return ModelData(
      name: modelName,
      type: modelType,
      data: placeholderData,
      metadata: metadata,
      size: placeholderSize,
      loadedAt: DateTime.now(),
      lastAccessed: DateTime.now(),
      isPlaceholder: true,
    );
  }
  
  /// Infer model type from model name
  ModelType _inferModelType(String modelName) {
    if (modelName.contains('pitch') || modelName.contains('audio')) {
      return ModelType.audio;
    } else if (modelName.contains('emotion') || modelName.contains('style') || 
               modelName.contains('classifier')) {
      return ModelType.classification;
    } else if (modelName.contains('coaching') || modelName.contains('generator') ||
               modelName.contains('text')) {
      return ModelType.text;
    } else if (modelName.contains('vision') || modelName.contains('image')) {
      return ModelType.vision;
    } else {
      return ModelType.audio; // Default for vocal training app
    }
  }
  
  /// Get placeholder size based on model type
  int _getPlaceholderSize(ModelType type) {
    switch (type) {
      case ModelType.audio:
        return 512 * 1024; // 512KB
      case ModelType.classification:
        return 256 * 1024; // 256KB
      case ModelType.text:
        return 1024 * 1024; // 1MB
      case ModelType.vision:
        return 2048 * 1024; // 2MB
    }
  }
  
  /// Get default input shape for model type
  List<int> _getDefaultInputShape(ModelType type) {
    switch (type) {
      case ModelType.audio:
        return [1, 16000]; // 1 second of 16kHz audio
      case ModelType.classification:
        return [1, 768]; // Feature vector
      case ModelType.text:
        return [1, 512]; // Token sequence
      case ModelType.vision:
        return [1, 224, 224, 3]; // Standard image input
    }
  }
  
  /// Get default output shape for model type
  List<int> _getDefaultOutputShape(ModelType type) {
    switch (type) {
      case ModelType.audio:
        return [1, 1]; // Single value (pitch, etc.)
      case ModelType.classification:
        return [1, 10]; // 10 classes
      case ModelType.text:
        return [1, 512]; // Generated sequence
      case ModelType.vision:
        return [1, 1000]; // ImageNet classes
    }
  }
  
  /// Unload a specific model to free memory
  void unloadModel(String modelName) {
    if (_loadedModels.containsKey(modelName)) {
      _loadedModels.remove(modelName);
      if (kDebugMode) {
        debugPrint('[AIModelLoader] Unloaded model: $modelName');
      }
    }
  }
  
  /// Manage memory by unloading least recently used models
  void _manageMemory() {
    final report = _performanceOptimizer.generatePerformanceReport();
    final memoryUsage = report['memoryUsage'] as int;
    
    // If memory usage is high, unload old models
    if (memoryUsage > 100 * 1024 * 1024 || _loadedModels.length > 10) {
      _unloadLRUModels();
    }
  }
  
  /// Unload least recently used models
  void _unloadLRUModels() {
    if (_loadedModels.length <= 3) return; // Keep at least 3 core models
    
    final sortedModels = _loadedModels.entries.toList()
      ..sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));
    
    // Unload the oldest models, keeping the 3 most recent
    final modelsToUnload = sortedModels.take(sortedModels.length - 3);
    
    for (final entry in modelsToUnload) {
      unloadModel(entry.key);
    }
  }
  
  /// Get loaded model information
  ModelData? getModelInfo(String modelName) {
    return _loadedModels[modelName];
  }
  
  /// Get all loaded models
  Map<String, ModelData> getAllLoadedModels() {
    return Map.unmodifiable(_loadedModels);
  }
  
  /// Check if a model is loaded
  bool isModelLoaded(String modelName) {
    return _loadedModels.containsKey(modelName);
  }
  
  /// Preload models for better performance
  Future<void> preloadModels(List<String> modelNames) async {
    final futures = modelNames.map((name) => loadModel(name));
    await Future.wait(futures);
  }
  
  /// Get memory usage of loaded models
  int getMemoryUsage() {
    return _loadedModels.values
        .map((model) => model.size)
        .fold(0, (sum, size) => sum + size);
  }
  
  /// Get model loading statistics
  Map<String, dynamic> getStatistics() {
    final totalModels = _loadedModels.length;
    final totalMemory = getMemoryUsage();
    final placeholderCount = _loadedModels.values
        .where((model) => model.isPlaceholder)
        .length;
    final realModelCount = totalModels - placeholderCount;
    
    return {
      'total_models': totalModels,
      'real_models': realModelCount,
      'placeholder_models': placeholderCount,
      'total_memory_bytes': totalMemory,
      'total_memory_mb': (totalMemory / (1024 * 1024)).toStringAsFixed(2),
      'is_initialized': _isInitialized,
      'model_names': _loadedModels.keys.toList(),
    };
  }
  
  /// Dispose all resources
  void dispose() {
    _loadedModels.clear();
    _isInitialized = false;
    
    if (kDebugMode) {
      debugPrint('[AIModelLoader] Disposed');
    }
  }
}

/// Model data container
class ModelData {
  final String name;
  final ModelType type;
  final Uint8List data;
  final Map<String, dynamic>? metadata;
  final int size;
  final DateTime loadedAt;
  DateTime lastAccessed;
  final bool isPlaceholder;
  
  ModelData({
    required this.name,
    required this.type,
    required this.data,
    this.metadata,
    required this.size,
    required this.loadedAt,
    required this.lastAccessed,
    required this.isPlaceholder,
  });
  
  /// Get model version from metadata
  String get version => metadata?['version'] ?? 'unknown';
  
  /// Get model description from metadata
  String get description => metadata?['description'] ?? 'No description';
  
  /// Get input shape from metadata
  List<int> get inputShape => 
      (metadata?['input_shape'] as List?)?.cast<int>() ?? [];
  
  /// Get output shape from metadata
  List<int> get outputShape => 
      (metadata?['output_shape'] as List?)?.cast<int>() ?? [];
  
  /// Calculate memory usage in MB
  double get memorySizeMB => size / (1024 * 1024);
  
  /// Check if model is recently used (within last 5 minutes)
  bool get isRecentlyUsed => 
      DateTime.now().difference(lastAccessed).inMinutes < 5;
  
  @override
  String toString() {
    return 'ModelData(name: $name, type: $type, size: ${memorySizeMB.toStringAsFixed(2)}MB, '
           'placeholder: $isPlaceholder, lastAccessed: $lastAccessed)';
  }
}

/// Model types for different AI tasks
enum ModelType {
  audio,        // Audio processing models (pitch detection, etc.)
  classification, // Classification models (emotion, style)
  text,         // Text generation models (coaching)
  vision,       // Computer vision models (posture analysis)
}