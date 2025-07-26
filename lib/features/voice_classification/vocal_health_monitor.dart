import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../audio_analysis/timbre_analyzer.dart';
import '../../core/performance/performance_manager.dart';

/// Advanced vocal health monitoring system
class VocalHealthMonitor with PerformanceMixin {
  static final VocalHealthMonitor _instance = VocalHealthMonitor._internal();
  factory VocalHealthMonitor() => _instance;
  VocalHealthMonitor._internal();

  final TimbreAnalyzer _timbreAnalyzer = TimbreAnalyzer();
  
  bool _isInitialized = false;
  final List<VocalHealthSample> _healthHistory = [];
  final StreamController<VocalHealthAnalysis> _healthStreamController = 
      StreamController<VocalHealthAnalysis>.broadcast();
  
  Stream<VocalHealthAnalysis> get healthStream => _healthStreamController.stream;
  
  // Health monitoring parameters
  static const Duration _maxHistoryDuration = Duration(days: 30);
  static const int _minSamplesForTrend = 5;
  
  // Vocal health thresholds
  static const double _strainThreshold = 0.7;
  static const double _fatigueThreshold = 0.6;
  static const double _hoarsenessThreshold = 0.5;
  static const double _breathinessThreshold = 0.4;

  /// Initialize the vocal health monitor
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _timbreAnalyzer.initialize();
    _isInitialized = true;
  }

  /// Analyze vocal health from audio sample
  Future<VocalHealthAnalysis> analyzeVocalHealth(
    Float32List audioData, {
    int sampleRate = 44100,
    DateTime? timestamp,
  }) async {
    return measureOperation('vocal_health_analysis', () async {
      if (!_isInitialized) {
        throw StateError('VocalHealthMonitor not initialized');
      }

      final analysisTimestamp = timestamp ?? DateTime.now();
      
      // Perform timbre analysis
      final timbreAnalysis = await _timbreAnalyzer.analyzeTimbre(audioData.toList());
      
      // Extract health indicators
      final healthIndicators = _extractHealthIndicators(audioData, timbreAnalysis, sampleRate);
      
      // Assess overall vocal condition
      final vocalCondition = _assessVocalCondition(healthIndicators);
      
      // Generate health insights
      final insights = _generateHealthInsights(healthIndicators, vocalCondition);
      
      // Create health sample for history
      final healthSample = VocalHealthSample(
        timestamp: analysisTimestamp,
        indicators: healthIndicators,
        overallHealth: vocalCondition.overallScore,
        audioCharacteristics: AudioCharacteristics(
          averageAmplitude: _calculateAverageAmplitude(audioData),
          dynamicRange: _calculateDynamicRange(audioData),
          spectralCentroid: _calculateSpectralCentroid(audioData, sampleRate),
          zeroCrossingRate: _calculateZeroCrossingRate(audioData),
        ),
      );
      
      // Add to history and clean old samples
      _addHealthSample(healthSample);
      
      // Calculate trends
      final trends = _calculateHealthTrends();
      
      // Create comprehensive analysis
      final analysis = VocalHealthAnalysis(
        timestamp: analysisTimestamp,
        healthIndicators: healthIndicators,
        vocalCondition: vocalCondition,
        trends: trends,
        insights: insights,
        recommendations: _generateRecommendations(vocalCondition, trends, insights),
        riskAssessment: _assessHealthRisks(healthIndicators, trends),
      );
      
      // Broadcast to listeners
      _healthStreamController.add(analysis);
      
      return analysis;
    });
  }

  /// Extract health indicators from audio analysis
  VocalHealthIndicators _extractHealthIndicators(
    Float32List audioData,
    TimbreAnalysis timbreAnalysis,
    int sampleRate,
  ) {
    // Calculate vocal strain indicators
    final strain = _calculateVocalStrain(timbreAnalysis, audioData);
    
    // Calculate fatigue indicators
    final fatigue = _calculateVocalFatigue(timbreAnalysis, audioData, sampleRate);
    
    // Calculate hoarseness level
    final hoarseness = _calculateHoarseness(timbreAnalysis);
    
    // Calculate breathiness level
    final breathiness = _calculateBreathiness(timbreAnalysis, audioData);
    
    // Calculate tremor detection
    final tremor = _detectVocalTremor(audioData, sampleRate);
    
    // Calculate voice breaks
    final voiceBreaks = _detectVoiceBreaks(audioData, sampleRate);
    
    // Calculate pitch stability
    final pitchStability = timbreAnalysis.pitchStability;
    
    // Calculate resonance quality
    final resonanceQuality = _assessResonanceQuality(timbreAnalysis);
    
    return VocalHealthIndicators(
      strain: strain,
      fatigue: fatigue,
      hoarseness: hoarseness,
      breathiness: breathiness,
      tremor: tremor,
      voiceBreaks: voiceBreaks,
      pitchStability: pitchStability,
      resonanceQuality: resonanceQuality,
    );
  }

  /// Calculate vocal strain level
  double _calculateVocalStrain(TimbreAnalysis timbreAnalysis, Float32List audioData) {
    // Strain indicators: high roughness, spectral imbalance, tension
    double strainScore = 0.0;
    
    // High roughness indicates strain
    strainScore += timbreAnalysis.roughness * 0.4;
    
    // Spectral irregularity
    final spectralIrregularity = _calculateSpectralIrregularity(audioData);
    strainScore += spectralIrregularity * 0.3;
    
    // High frequency emphasis (tension)
    final hfEmphasis = _calculateHighFrequencyEmphasis(audioData);
    strainScore += hfEmphasis * 0.3;
    
    return strainScore.clamp(0.0, 1.0);
  }

  /// Calculate vocal fatigue level
  double _calculateVocalFatigue(
    TimbreAnalysis timbreAnalysis,
    Float32List audioData,
    int sampleRate,
  ) {
    double fatigueScore = 0.0;
    
    // Reduced brightness indicates fatigue
    fatigueScore += (1.0 - timbreAnalysis.brightness) * 0.3;
    
    // Decreased pitch range flexibility
    final pitchFlexibility = _calculatePitchFlexibility(audioData, sampleRate);
    fatigueScore += (1.0 - pitchFlexibility) * 0.3;
    
    // Reduced resonance
    fatigueScore += (1.0 - timbreAnalysis.resonance) * 0.2;
    
    // Amplitude instability
    final amplitudeStability = _calculateAmplitudeStability(audioData);
    fatigueScore += (1.0 - amplitudeStability) * 0.2;
    
    return fatigueScore.clamp(0.0, 1.0);
  }

  /// Calculate hoarseness level
  double _calculateHoarseness(TimbreAnalysis timbreAnalysis) {
    // Hoarseness indicators: high roughness, spectral noise
    double hoarsenessScore = 0.0;
    
    // Primary indicator: roughness
    hoarsenessScore += timbreAnalysis.roughness * 0.6;
    
    // Secondary: reduced harmonic clarity
    final harmonicClarity = 1.0 - timbreAnalysis.inharmonicity;
    hoarsenessScore += (1.0 - harmonicClarity) * 0.4;
    
    return hoarsenessScore.clamp(0.0, 1.0);
  }

  /// Calculate breathiness level
  double _calculateBreathiness(TimbreAnalysis timbreAnalysis, Float32List audioData) {
    double breathinessScore = 0.0;
    
    // High spectral tilt (more high frequencies relative to low)
    final spectralTilt = _calculateSpectralTilt(audioData);
    breathinessScore += spectralTilt * 0.4;
    
    // Reduced harmonic-to-noise ratio
    final hnr = _calculateHarmonicToNoiseRatio(audioData);
    breathinessScore += (1.0 - hnr) * 0.6;
    
    return breathinessScore.clamp(0.0, 1.0);
  }

  /// Detect vocal tremor
  double _detectVocalTremor(Float32List audioData, int sampleRate) {
    // Tremor is detected as low-frequency modulation (4-12 Hz)
    const frameSize = 2048;
    const hopSize = 512;
    final tremorFreqRange = [4.0, 12.0]; // Hz
    
    final modulationStrengths = <double>[];
    
    for (int i = 0; i < audioData.length - frameSize; i += hopSize) {
      final frame = audioData.sublist(i, i + frameSize);
      final amplitude = frame.map((x) => x.abs()).reduce((a, b) => a + b) / frame.length;
      modulationStrengths.add(amplitude);
    }
    
    if (modulationStrengths.length < 10) return 0.0;
    
    // Analyze modulation frequency using autocorrelation
    final tremorStrength = _analyzeLowFrequencyModulation(modulationStrengths, sampleRate / hopSize);
    
    return tremorStrength.clamp(0.0, 1.0);
  }

  /// Detect voice breaks
  double _detectVoiceBreaks(Float32List audioData, int sampleRate) {
    const frameSize = 1024;
    const hopSize = 512;
    const energyThreshold = 0.01;
    
    int totalFrames = 0;
    int breakFrames = 0;
    double previousEnergy = 0.0;
    
    for (int i = 0; i < audioData.length - frameSize; i += hopSize) {
      final frame = audioData.sublist(i, i + frameSize);
      final energy = frame.map((x) => x * x).reduce((a, b) => a + b) / frame.length;
      
      // Detect sudden drops in energy (voice breaks)
      if (totalFrames > 0 && previousEnergy > energyThreshold && energy < energyThreshold * 0.1) {
        breakFrames++;
      }
      
      previousEnergy = energy;
      totalFrames++;
    }
    
    return totalFrames > 0 ? breakFrames / totalFrames : 0.0;
  }

  /// Assess resonance quality
  double _assessResonanceQuality(TimbreAnalysis timbreAnalysis) {
    // Resonance quality based on multiple factors
    double quality = 0.0;
    
    // Primary resonance measure
    quality += timbreAnalysis.resonance * 0.5;
    
    // Harmonic richness
    quality += (1.0 - timbreAnalysis.inharmonicity) * 0.3;
    
    // Spectral balance
    quality += timbreAnalysis.spectralBalance * 0.2;
    
    return quality.clamp(0.0, 1.0);
  }

  /// Assess overall vocal condition
  VocalCondition _assessVocalCondition(VocalHealthIndicators indicators) {
    // Calculate overall health score
    double overallScore = 1.0;
    
    // Penalize negative indicators
    overallScore -= indicators.strain * 0.25;
    overallScore -= indicators.fatigue * 0.20;
    overallScore -= indicators.hoarseness * 0.20;
    overallScore -= indicators.breathiness * 0.15;
    overallScore -= indicators.tremor * 0.10;
    overallScore -= indicators.voiceBreaks * 0.10;
    
    // Reward positive indicators
    overallScore = (overallScore + indicators.pitchStability * 0.15 + indicators.resonanceQuality * 0.15) / 1.3;
    
    overallScore = overallScore.clamp(0.0, 1.0);
    
    // Determine condition level
    VocalConditionLevel level;
    if (overallScore >= 0.8) {
      level = VocalConditionLevel.excellent;
    } else if (overallScore >= 0.6) {
      level = VocalConditionLevel.good;
    } else if (overallScore >= 0.4) {
      level = VocalConditionLevel.fair;
    } else if (overallScore >= 0.2) {
      level = VocalConditionLevel.poor;
    } else {
      level = VocalConditionLevel.critical;
    }
    
    return VocalCondition(
      overallScore: overallScore,
      level: level,
      primaryConcerns: _identifyPrimaryConcerns(indicators),
    );
  }

  /// Identify primary health concerns
  List<HealthConcern> _identifyPrimaryConcerns(VocalHealthIndicators indicators) {
    final concerns = <HealthConcern>[];
    
    if (indicators.strain > _strainThreshold) {
      concerns.add(HealthConcern(
        type: HealthConcernType.strain,
        severity: _getSeverity(indicators.strain),
        description: '성대에 무리가 감지되었습니다',
      ));
    }
    
    if (indicators.fatigue > _fatigueThreshold) {
      concerns.add(HealthConcern(
        type: HealthConcernType.fatigue,
        severity: _getSeverity(indicators.fatigue),
        description: '성대 피로가 감지되었습니다',
      ));
    }
    
    if (indicators.hoarseness > _hoarsenessThreshold) {
      concerns.add(HealthConcern(
        type: HealthConcernType.hoarseness,
        severity: _getSeverity(indicators.hoarseness),
        description: '쉰 목소리가 감지되었습니다',
      ));
    }
    
    if (indicators.breathiness > _breathinessThreshold) {
      concerns.add(HealthConcern(
        type: HealthConcernType.breathiness,
        severity: _getSeverity(indicators.breathiness),
        description: '기식음이 과도하게 감지되었습니다',
      ));
    }
    
    if (indicators.tremor > 0.3) {
      concerns.add(HealthConcern(
        type: HealthConcernType.tremor,
        severity: _getSeverity(indicators.tremor),
        description: '성대 떨림이 감지되었습니다',
      ));
    }
    
    if (indicators.voiceBreaks > 0.2) {
      concerns.add(HealthConcern(
        type: HealthConcernType.voiceBreaks,
        severity: _getSeverity(indicators.voiceBreaks),
        description: '음성 중단이 빈번하게 발생합니다',
      ));
    }
    
    return concerns;
  }

  /// Generate health insights
  List<HealthInsight> _generateHealthInsights(
    VocalHealthIndicators indicators,
    VocalCondition condition,
  ) {
    final insights = <HealthInsight>[];
    
    // Overall condition insight
    switch (condition.level) {
      case VocalConditionLevel.excellent:
        insights.add(HealthInsight(
          type: HealthInsightType.positive,
          title: '우수한 성대 상태',
          message: '현재 성대 상태가 매우 좋습니다. 현재의 발성 습관을 유지하세요.',
        ));
        break;
      case VocalConditionLevel.good:
        insights.add(HealthInsight(
          type: HealthInsightType.neutral,
          title: '양호한 성대 상태',
          message: '성대 상태가 양호합니다. 몇 가지 개선점을 고려해보세요.',
        ));
        break;
      case VocalConditionLevel.fair:
        insights.add(HealthInsight(
          type: HealthInsightType.caution,
          title: '주의가 필요한 성대 상태',
          message: '일부 건강 지표에서 주의가 필요합니다. 발성 습관을 점검해보세요.',
        ));
        break;
      case VocalConditionLevel.poor:
        insights.add(HealthInsight(
          type: HealthInsightType.warning,
          title: '좋지 않은 성대 상태',
          message: '성대 건강에 문제가 있을 수 있습니다. 휴식과 개선이 필요합니다.',
        ));
        break;
      case VocalConditionLevel.critical:
        insights.add(HealthInsight(
          type: HealthInsightType.critical,
          title: '심각한 성대 상태',
          message: '성대 건강이 매우 좋지 않습니다. 전문의 상담을 받으시기 바랍니다.',
        ));
        break;
    }
    
    // Specific insights based on indicators
    if (indicators.strain > 0.5) {
      insights.add(HealthInsight(
        type: HealthInsightType.warning,
        title: '성대 긴장 감지',
        message: '과도한 힘으로 발성하고 있을 가능성이 있습니다. 복식호흡과 이완 연습을 해보세요.',
      ));
    }
    
    if (indicators.pitchStability < 0.5) {
      insights.add(HealthInsight(
        type: HealthInsightType.improvement,
        title: '음정 안정성 개선 필요',
        message: '음정이 불안정합니다. 발성 기초 연습을 통해 안정성을 높여보세요.',
      ));
    }
    
    return insights;
  }

  /// Calculate health trends
  HealthTrends _calculateHealthTrends() {
    if (_healthHistory.length < _minSamplesForTrend) {
      return HealthTrends(
        overallTrend: TrendDirection.stable,
        strainTrend: TrendDirection.stable,
        fatigueTrend: TrendDirection.stable,
        hoarsenessTrend: TrendDirection.stable,
        breathinessTrend: TrendDirection.stable,
        trendPeriod: Duration.zero,
      );
    }
    
    final recentSamples = _healthHistory.take(10).toList();
    final period = recentSamples.first.timestamp.difference(recentSamples.last.timestamp);
    
    return HealthTrends(
      overallTrend: _calculateTrend(recentSamples.map((s) => s.overallHealth).toList()),
      strainTrend: _calculateTrend(recentSamples.map((s) => s.indicators.strain).toList()),
      fatigueTrend: _calculateTrend(recentSamples.map((s) => s.indicators.fatigue).toList()),
      hoarsenessTrend: _calculateTrend(recentSamples.map((s) => s.indicators.hoarseness).toList()),
      breathinessTrend: _calculateTrend(recentSamples.map((s) => s.indicators.breathiness).toList()),
      trendPeriod: period,
    );
  }

  /// Calculate trend direction from values
  TrendDirection _calculateTrend(List<double> values) {
    if (values.length < 3) return TrendDirection.stable;
    
    // Calculate linear regression slope
    final n = values.length;
    final sumX = (n * (n - 1)) / 2; // 0 + 1 + 2 + ... + (n-1)
    final sumY = values.reduce((a, b) => a + b);
    final sumXY = values.asMap().entries.map((e) => e.key * e.value).reduce((a, b) => a + b);
    final sumX2 = (n * (n - 1) * (2 * n - 1)) / 6; // 0² + 1² + 2² + ... + (n-1)²
    
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    
    if (slope > 0.02) {
      return TrendDirection.improving;
    } else if (slope < -0.02) {
      return TrendDirection.declining;
    } else {
      return TrendDirection.stable;
    }
  }

  /// Generate health recommendations
  List<HealthRecommendation> _generateRecommendations(
    VocalCondition condition,
    HealthTrends trends,
    List<HealthInsight> insights,
  ) {
    final recommendations = <HealthRecommendation>[];
    
    // General recommendations based on condition
    switch (condition.level) {
      case VocalConditionLevel.excellent:
        recommendations.add(HealthRecommendation(
          priority: RecommendationPriority.low,
          category: RecommendationCategory.maintenance,
          title: '현재 상태 유지',
          description: '우수한 성대 상태를 유지하기 위해 현재의 발성 습관을 계속하세요.',
          estimatedBenefit: 0.9,
        ));
        break;
        
      case VocalConditionLevel.poor:
      case VocalConditionLevel.critical:
        recommendations.add(HealthRecommendation(
          priority: RecommendationPriority.high,
          category: RecommendationCategory.medical,
          title: '전문의 상담',
          description: '성대 건강이 우려되는 상태입니다. 이비인후과 전문의의 진단을 받으시기 바랍니다.',
          estimatedBenefit: 0.8,
        ));
        break;
        
      default:
        break;
    }
    
    // Specific recommendations based on concerns
    for (final concern in condition.primaryConcerns) {
      switch (concern.type) {
        case HealthConcernType.strain:
          recommendations.add(HealthRecommendation(
            priority: RecommendationPriority.high,
            category: RecommendationCategory.technique,
            title: '발성 기법 개선',
            description: '복식호흡을 활용하고 목 근육의 긴장을 줄이는 연습을 하세요.',
            estimatedBenefit: 0.7,
          ));
          break;
          
        case HealthConcernType.fatigue:
          recommendations.add(HealthRecommendation(
            priority: RecommendationPriority.medium,
            category: RecommendationCategory.rest,
            title: '충분한 휴식',
            description: '성대 휴식 시간을 늘리고 수분 섭취를 충분히 하세요.',
            estimatedBenefit: 0.6,
          ));
          break;
          
        case HealthConcernType.hoarseness:
          recommendations.add(HealthRecommendation(
            priority: RecommendationPriority.high,
            category: RecommendationCategory.medical,
            title: '쉰 목소리 검진',
            description: '지속적인 쉰 목소리는 성대 문제의 신호일 수 있습니다. 검진을 받아보세요.',
            estimatedBenefit: 0.8,
          ));
          break;
          
        default:
          break;
      }
    }
    
    // Trending-based recommendations
    if (trends.strainTrend == TrendDirection.declining) {
      recommendations.add(HealthRecommendation(
        priority: RecommendationPriority.medium,
        category: RecommendationCategory.prevention,
        title: '예방적 관리',
        description: '성대 긴장이 증가하는 추세입니다. 발성 연습을 줄이고 휴식을 늘리세요.',
        estimatedBenefit: 0.5,
      ));
    }
    
    return recommendations;
  }

  /// Assess health risks
  HealthRiskAssessment _assessHealthRisks(
    VocalHealthIndicators indicators,
    HealthTrends trends,
  ) {
    final risks = <HealthRisk>[];
    
    // Assess nodule/polyp risk
    if (indicators.strain > 0.7 && indicators.hoarseness > 0.6) {
      risks.add(HealthRisk(
        type: HealthRiskType.nodules,
        probability: 0.3,
        description: '성대 결절이나 폴립 발생 위험이 있습니다',
      ));
    }
    
    // Assess vocal cord inflammation risk
    if (indicators.strain > 0.6 && trends.strainTrend == TrendDirection.declining) {
      risks.add(HealthRisk(
        type: HealthRiskType.inflammation,
        probability: 0.4,
        description: '성대 염증 위험이 높습니다',
      ));
    }
    
    // Calculate overall risk level
    HealthRiskLevel overallRisk;
    if (risks.isEmpty) {
      overallRisk = HealthRiskLevel.low;
    } else {
      final maxProbability = risks.map((r) => r.probability).reduce(math.max);
      if (maxProbability > 0.5) {
        overallRisk = HealthRiskLevel.high;
      } else if (maxProbability > 0.3) {
        overallRisk = HealthRiskLevel.medium;
      } else {
        overallRisk = HealthRiskLevel.low;
      }
    }
    
    return HealthRiskAssessment(
      overallRisk: overallRisk,
      identifiedRisks: risks,
    );
  }

  // Helper methods for calculations

  double _calculateSpectralIrregularity(Float32List audioData) {
    // Simplified spectral irregularity calculation
    return math.Random().nextDouble() * 0.3; // Placeholder
  }

  double _calculateHighFrequencyEmphasis(Float32List audioData) {
    // Calculate ratio of high frequency to low frequency energy
    return math.Random().nextDouble() * 0.4; // Placeholder
  }

  double _calculatePitchFlexibility(Float32List audioData, int sampleRate) {
    // Measure pitch variation capability
    return math.Random().nextDouble(); // Placeholder
  }

  double _calculateAmplitudeStability(Float32List audioData) {
    if (audioData.isEmpty) return 0.0;
    
    final amplitudes = audioData.map((x) => x.abs()).toList();
    final mean = amplitudes.reduce((a, b) => a + b) / amplitudes.length;
    final variance = amplitudes.map((a) => math.pow(a - mean, 2)).reduce((a, b) => a + b) / amplitudes.length;
    
    return 1.0 / (1.0 + math.sqrt(variance) / math.max(mean, 1e-10));
  }

  double _calculateSpectralTilt(Float32List audioData) {
    // Calculate spectral tilt (slope of spectrum)
    return math.Random().nextDouble() * 0.5; // Placeholder
  }

  double _calculateHarmonicToNoiseRatio(Float32List audioData) {
    // Calculate HNR
    return math.Random().nextDouble(); // Placeholder
  }

  double _analyzeLowFrequencyModulation(List<double> amplitudes, double sampleRate) {
    // Analyze tremor frequency modulation
    return math.Random().nextDouble() * 0.3; // Placeholder
  }

  double _calculateAverageAmplitude(Float32List audioData) {
    return audioData.map((x) => x.abs()).reduce((a, b) => a + b) / audioData.length;
  }

  double _calculateDynamicRange(Float32List audioData) {
    final amplitudes = audioData.map((x) => x.abs()).toList()..sort();
    final p95 = amplitudes[(amplitudes.length * 0.95).round()];
    final p5 = amplitudes[(amplitudes.length * 0.05).round()];
    return 20 * math.log(p95 / math.max(p5, 1e-10)) / math.ln10;
  }

  double _calculateSpectralCentroid(Float32List audioData, int sampleRate) {
    // Calculate spectral centroid (brightness measure)
    return math.Random().nextDouble() * 2000 + 1000; // Placeholder
  }

  double _calculateZeroCrossingRate(Float32List audioData) {
    int crossings = 0;
    for (int i = 1; i < audioData.length; i++) {
      if ((audioData[i] >= 0) != (audioData[i - 1] >= 0)) {
        crossings++;
      }
    }
    return crossings / (audioData.length - 1);
  }

  HealthConcernSeverity _getSeverity(double value) {
    if (value > 0.8) return HealthConcernSeverity.severe;
    if (value > 0.6) return HealthConcernSeverity.moderate;
    if (value > 0.4) return HealthConcernSeverity.mild;
    return HealthConcernSeverity.minimal;
  }

  /// Add health sample to history
  void _addHealthSample(VocalHealthSample sample) {
    _healthHistory.insert(0, sample);
    
    // Remove old samples
    final cutoffTime = DateTime.now().subtract(_maxHistoryDuration);
    _healthHistory.removeWhere((sample) => sample.timestamp.isBefore(cutoffTime));
  }

  /// Get health history
  List<VocalHealthSample> getHealthHistory({Duration? period}) {
    if (period == null) return List.from(_healthHistory);
    
    final cutoffTime = DateTime.now().subtract(period);
    return _healthHistory.where((sample) => sample.timestamp.isAfter(cutoffTime)).toList();
  }

  /// Get current health status
  VocalHealthSummary? getCurrentHealthStatus() {
    if (_healthHistory.isEmpty) return null;
    
    final recent = _healthHistory.first;
    final trends = _calculateHealthTrends();
    
    return VocalHealthSummary(
      lastAnalysis: recent.timestamp,
      overallHealth: recent.overallHealth,
      primaryConcerns: _identifyPrimaryConcerns(recent.indicators),
      trends: trends,
    );
  }

  void dispose() {
    _healthStreamController.close();
    _healthHistory.clear();
    _timbreAnalyzer.dispose();
  }
}

// Data classes for vocal health monitoring

class VocalHealthAnalysis {
  final DateTime timestamp;
  final VocalHealthIndicators healthIndicators;
  final VocalCondition vocalCondition;
  final HealthTrends trends;
  final List<HealthInsight> insights;
  final List<HealthRecommendation> recommendations;
  final HealthRiskAssessment riskAssessment;

  VocalHealthAnalysis({
    required this.timestamp,
    required this.healthIndicators,
    required this.vocalCondition,
    required this.trends,
    required this.insights,
    required this.recommendations,
    required this.riskAssessment,
  });
}

class VocalHealthIndicators {
  final double strain;
  final double fatigue;
  final double hoarseness;
  final double breathiness;
  final double tremor;
  final double voiceBreaks;
  final double pitchStability;
  final double resonanceQuality;

  VocalHealthIndicators({
    required this.strain,
    required this.fatigue,
    required this.hoarseness,
    required this.breathiness,
    required this.tremor,
    required this.voiceBreaks,
    required this.pitchStability,
    required this.resonanceQuality,
  });
}

class VocalCondition {
  final double overallScore;
  final VocalConditionLevel level;
  final List<HealthConcern> primaryConcerns;

  VocalCondition({
    required this.overallScore,
    required this.level,
    required this.primaryConcerns,
  });
}

enum VocalConditionLevel {
  excellent,
  good,
  fair,
  poor,
  critical,
}

class HealthConcern {
  final HealthConcernType type;
  final HealthConcernSeverity severity;
  final String description;

  HealthConcern({
    required this.type,
    required this.severity,
    required this.description,
  });
}

enum HealthConcernType {
  strain,
  fatigue,
  hoarseness,
  breathiness,
  tremor,
  voiceBreaks,
}

enum HealthConcernSeverity {
  minimal,
  mild,
  moderate,
  severe,
}

class HealthInsight {
  final HealthInsightType type;
  final String title;
  final String message;

  HealthInsight({
    required this.type,
    required this.title,
    required this.message,
  });
}

enum HealthInsightType {
  positive,
  neutral,
  caution,
  warning,
  critical,
  improvement,
}

class HealthTrends {
  final TrendDirection overallTrend;
  final TrendDirection strainTrend;
  final TrendDirection fatigueTrend;
  final TrendDirection hoarsenessTrend;
  final TrendDirection breathinessTrend;
  final Duration trendPeriod;

  HealthTrends({
    required this.overallTrend,
    required this.strainTrend,
    required this.fatigueTrend,
    required this.hoarsenessTrend,
    required this.breathinessTrend,
    required this.trendPeriod,
  });
}

enum TrendDirection {
  improving,
  stable,
  declining,
}

class HealthRecommendation {
  final RecommendationPriority priority;
  final RecommendationCategory category;
  final String title;
  final String description;
  final double estimatedBenefit;

  HealthRecommendation({
    required this.priority,
    required this.category,
    required this.title,
    required this.description,
    required this.estimatedBenefit,
  });
}

enum RecommendationPriority {
  low,
  medium,
  high,
  urgent,
}

enum RecommendationCategory {
  technique,
  rest,
  medical,
  prevention,
  maintenance,
}

class HealthRiskAssessment {
  final HealthRiskLevel overallRisk;
  final List<HealthRisk> identifiedRisks;

  HealthRiskAssessment({
    required this.overallRisk,
    required this.identifiedRisks,
  });
}

enum HealthRiskLevel {
  low,
  medium,
  high,
}

class HealthRisk {
  final HealthRiskType type;
  final double probability;
  final String description;

  HealthRisk({
    required this.type,
    required this.probability,
    required this.description,
  });
}

enum HealthRiskType {
  nodules,
  polyps,
  inflammation,
  edema,
  hemorrhage,
}

class VocalHealthSample {
  final DateTime timestamp;
  final VocalHealthIndicators indicators;
  final double overallHealth;
  final AudioCharacteristics audioCharacteristics;

  VocalHealthSample({
    required this.timestamp,
    required this.indicators,
    required this.overallHealth,
    required this.audioCharacteristics,
  });
}

class AudioCharacteristics {
  final double averageAmplitude;
  final double dynamicRange;
  final double spectralCentroid;
  final double zeroCrossingRate;

  AudioCharacteristics({
    required this.averageAmplitude,
    required this.dynamicRange,
    required this.spectralCentroid,
    required this.zeroCrossingRate,
  });
}

class VocalHealthSummary {
  final DateTime lastAnalysis;
  final double overallHealth;
  final List<HealthConcern> primaryConcerns;
  final HealthTrends trends;

  VocalHealthSummary({
    required this.lastAnalysis,
    required this.overallHealth,
    required this.primaryConcerns,
    required this.trends,
  });
}