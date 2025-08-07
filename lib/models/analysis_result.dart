/// 피치 분석 결과 모델들
class AnalysisResult {
  final double frequency;
  final double confidence;
  final DateTime timestamp;
  final String engine; // 'CREPE' or 'SPICE' or 'FUSED'
  
  AnalysisResult({
    required this.frequency,
    required this.confidence,
    required this.timestamp,
    required this.engine,
  });
}

/// CREPE 분석 결과
class CrepeResult extends AnalysisResult {
  final double stability;
  final double voicedRatio;
  final double processingTimeMs;
  
  CrepeResult({
    required super.frequency,
    required super.confidence,
    required super.timestamp,
    required this.stability,
    required this.voicedRatio,
    required this.processingTimeMs,
  }) : super(engine: 'CREPE');
  
  factory CrepeResult.fromJson(Map<String, dynamic> json) {
    final stats = json['statistics'];
    final params = json['parameters'];
    
    return CrepeResult(
      frequency: stats['average_frequency'].toDouble(),
      confidence: stats['average_confidence'].toDouble(),
      timestamp: DateTime.now(),
      stability: stats['pitch_stability'].toDouble(),
      voicedRatio: stats['voiced_ratio'].toDouble(),
      processingTimeMs: params['inference_time_ms'].toDouble(),
    );
  }
}

/// SPICE 분석 결과
class SpiceResult extends AnalysisResult {
  final List<MultiplePitch> multiplePitches;
  final int detectedPitchCount;
  final double processingTimeMs;
  
  SpiceResult({
    required super.frequency,
    required super.confidence,
    required super.timestamp,
    required this.multiplePitches,
    required this.detectedPitchCount,
    required this.processingTimeMs,
  }) : super(engine: 'SPICE');
  
  factory SpiceResult.fromJson(Map<String, dynamic> json) {
    final stats = json['statistics'];
    final params = json['parameters'];
    final pitches = (json['multiple_pitches'] as List?)
        ?.map((p) => MultiplePitch.fromJson(p))
        .toList() ?? [];
    
    return SpiceResult(
      frequency: stats['average_frequency'].toDouble(),
      confidence: stats['average_confidence'].toDouble(),
      timestamp: DateTime.now(),
      multiplePitches: pitches,
      detectedPitchCount: stats['pitch_count'],
      processingTimeMs: params['inference_time_ms'].toDouble(),
    );
  }
  
  bool get isChord => multiplePitches.length > 1;
}

/// 다중 피치 정보
class MultiplePitch {
  final double frequency;
  final double strength;
  final double confidence;
  
  MultiplePitch({
    required this.frequency,
    required this.strength,
    required this.confidence,
  });
  
  factory MultiplePitch.fromJson(Map<String, dynamic> json) {
    return MultiplePitch(
      frequency: json['frequency'].toDouble(),
      strength: json['strength'].toDouble(),
      confidence: json['confidence'].toDouble(),
    );
  }
}

/// 듀얼 엔진 융합 결과
class DualResult extends AnalysisResult {
  final CrepeResult? crepeResult;
  final SpiceResult? spiceResult;
  final String recommendedEngine;
  final double analysisQuality;
  final double? timeSeconds; // 시간별 분석용
  
  DualResult({
    required super.frequency,
    required super.confidence,
    required super.timestamp,
    this.crepeResult,
    this.spiceResult,
    required this.recommendedEngine,
    required this.analysisQuality,
    this.timeSeconds, // 선택적 시간 정보
  }) : super(engine: 'FUSED');
  
  bool get hasCrepe => crepeResult != null;
  bool get hasSpice => spiceResult != null;
  bool get hasBoth => hasCrepe && hasSpice;
  
  List<MultiplePitch> get detectedPitches => 
      spiceResult?.multiplePitches ?? [];
  
  bool get isChord => detectedPitches.length > 1;
}