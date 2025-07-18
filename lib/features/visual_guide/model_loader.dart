import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'dart:typed_data';

class ModelLoader {
  static const Map<String, String> modelPaths = {
    'human_torso': 'assets/models/human_torso.glb',
    'vocal_tract': 'assets/models/vocal_tract.glb',
    'breathing_guide': 'assets/models/breathing_guide.glb',
  };
  
  static const Map<String, Map<String, String>> animationPaths = {
    'human_torso': {
      'breathe_deep': 'breathe_deep',
      'breathe_shallow': 'breathe_shallow',
      'posture_correct': 'posture_correct',
    },
    'vocal_tract': {
      'tongue_high': 'tongue_high',
      'tongue_low': 'tongue_low',
      'mouth_open': 'mouth_open',
      'mouth_close': 'mouth_close',
    },
    'breathing_guide': {
      'diaphragm_expand': 'diaphragm_expand',
      'chest_minimize': 'chest_minimize',
    }
  };
  
  final Map<String, Model3D> _modelCache = {};
  final Map<String, Uint8List> _binaryCache = {};
  
  static final ModelLoader _instance = ModelLoader._internal();
  factory ModelLoader() => _instance;
  ModelLoader._internal();
  
  Future<Model3D> loadModel(String modelKey) async {
    if (_modelCache.containsKey(modelKey)) {
      return _modelCache[modelKey]!;
    }
    
    final modelPath = modelPaths[modelKey];
    if (modelPath == null) {
      throw ModelLoadException('Model not found: $modelKey');
    }
    
    try {
      // 모델 바이너리 로드
      final binary = await _loadModelBinary(modelPath);
      
      // 모델 생성
      final model = Model3D(
        key: modelKey,
        path: modelPath,
        binary: binary,
        animations: animationPaths[modelKey] ?? {},
      );
      
      // 캐시 저장
      _modelCache[modelKey] = model;
      
      return model;
    } catch (e) {
      throw ModelLoadException('Failed to load model $modelKey: $e');
    }
  }
  
  Future<Uint8List> _loadModelBinary(String assetPath) async {
    if (_binaryCache.containsKey(assetPath)) {
      return _binaryCache[assetPath]!;
    }
    
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      
      _binaryCache[assetPath] = bytes;
      return bytes;
    } catch (e) {
      // 기본 모델 생성 (모델 파일이 없는 경우)
      return _createDefaultModel(assetPath);
    }
  }
  
  Uint8List _createDefaultModel(String assetPath) {
    // 기본 GLB 헤더 생성 (간단한 큐브 모델)
    // 실제 구현에서는 더 복잡한 기본 모델 생성
    final buffer = ByteData(1024);
    
    // GLB 헤더 작성
    buffer.setUint32(0, 0x46546C67, Endian.little); // 'glTF'
    buffer.setUint32(4, 2, Endian.little); // version
    buffer.setUint32(8, 1024, Endian.little); // length
    
    // JSON chunk header
    buffer.setUint32(12, 512, Endian.little); // chunk length
    buffer.setUint32(16, 0x4E4F534A, Endian.little); // 'JSON'
    
    // 기본 JSON 데이터 작성 (단순화된 glTF JSON)
    final json = '''{
      "asset": {"version": "2.0"},
      "scenes": [{"nodes": [0]}],
      "nodes": [{"mesh": 0}],
      "meshes": [{"primitives": [{"attributes": {"POSITION": 0}}]}],
      "accessors": [{"bufferView": 0, "componentType": 5126, "count": 8, "type": "VEC3"}],
      "bufferViews": [{"buffer": 0, "byteLength": 96}],
      "buffers": [{"byteLength": 96}]
    }''';
    
    final jsonBytes = json.codeUnits;
    for (int i = 0; i < jsonBytes.length && i < 492; i++) {
      buffer.setUint8(20 + i, jsonBytes[i]);
    }
    
    // Binary chunk header
    buffer.setUint32(532, 96, Endian.little); // chunk length
    buffer.setUint32(536, 0x004E4942, Endian.little); // 'BIN\0'
    
    // 기본 큐브 vertices 데이터
    final vertices = [
      -1.0, -1.0, -1.0,  1.0, -1.0, -1.0,  1.0,  1.0, -1.0, -1.0,  1.0, -1.0,
      -1.0, -1.0,  1.0,  1.0, -1.0,  1.0,  1.0,  1.0,  1.0, -1.0,  1.0,  1.0,
    ];
    
    for (int i = 0; i < vertices.length; i++) {
      buffer.setFloat32(540 + i * 4, vertices[i], Endian.little);
    }
    
    return buffer.buffer.asUint8List();
  }
  
  Future<void> preloadModels() async {
    // 앱 시작 시 주요 모델들 미리 로드
    final futures = modelPaths.keys.map((key) => loadModel(key));
    await Future.wait(futures);
  }
  
  void clearCache() {
    _modelCache.clear();
    _binaryCache.clear();
  }
  
  List<String> getAvailableAnimations(String modelKey) {
    final animations = animationPaths[modelKey];
    return animations?.keys.toList() ?? [];
  }
  
  bool isModelLoaded(String modelKey) {
    return _modelCache.containsKey(modelKey);
  }
  
  int getCacheSize() {
    int size = 0;
    for (final bytes in _binaryCache.values) {
      size += bytes.length;
    }
    return size;
  }
}

class Model3D {
  final String key;
  final String path;
  final Uint8List binary;
  final Map<String, String> animations;
  
  Model3D({
    required this.key,
    required this.path,
    required this.binary,
    required this.animations,
  });
  
  bool hasAnimation(String animationName) {
    return animations.containsKey(animationName);
  }
  
  String? getAnimationPath(String animationName) {
    return animations[animationName];
  }
  
  List<String> get availableAnimations => animations.keys.toList();
  
  @override
  String toString() {
    return 'Model3D(key: $key, path: $path, animations: ${animations.keys.join(', ')})';
  }
}

class ModelLoadException implements Exception {
  final String message;
  ModelLoadException(this.message);
  
  @override
  String toString() => 'ModelLoadException: $message';
}