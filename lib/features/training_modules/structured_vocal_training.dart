import 'dart:async';
import 'dart:math' as math;
import '../../domain/entities/vocal_analysis.dart';
import '../ai_coaching/expert_knowledge_base.dart';

/// 보컬 연습 모드 타입
enum TrainingMode {
  breathing,    // 호흡법 연습
  pitch,        // 음정 정확도
  scales,       // 스케일 연습  
  resonance,    // 공명 연습
  expression,   // 표현력 연습
  freeStyle,    // 자유 연습
}

/// 연습 난이도
enum TrainingDifficulty {
  beginner,     // 초급
  intermediate, // 중급
  advanced,     // 고급
  expert,       // 전문가
}

/// 연습 세션 결과
class TrainingSessionResult {
  final TrainingMode mode;
  final TrainingDifficulty difficulty;
  final int score;
  final Duration duration;
  final List<VocalAnalysis> analyses;
  final Map<String, dynamic> metrics;
  final List<String> achievements;
  final String feedback;
  final DateTime timestamp;

  const TrainingSessionResult({
    required this.mode,
    required this.difficulty,
    required this.score,
    required this.duration,
    required this.analyses,
    required this.metrics,
    required this.achievements,
    required this.feedback,
    required this.timestamp,
  });
}

/// 체계적 보컬 트레이닝 시스템
class StructuredVocalTraining {
  final List<VocalAnalysis> _sessionAnalyses = [];
  final Map<TrainingMode, List<TrainingSessionResult>> _sessionHistory = {};
  
  Timer? _sessionTimer;
  DateTime? _sessionStartTime;
  TrainingMode? _currentMode;
  TrainingDifficulty? _currentDifficulty;
  
  /// 사용자 레벨에 맞는 연습 모드 추천
  TrainingMode recommendTrainingMode(String userLevel, List<VocalAnalysis> history) {
    switch (userLevel) {
      case 'beginner':
        return TrainingMode.breathing; // 호흡법부터
      case 'intermediate':
        return TrainingMode.pitch;     // 음정 정확도
      case 'advanced':
        return TrainingMode.resonance; // 공명 조절
      case 'expert':
        return TrainingMode.expression; // 표현력
      default:
        return TrainingMode.breathing;
    }
  }
  
  /// 연습 세션 시작
  void startTrainingSession(TrainingMode mode, TrainingDifficulty difficulty) {
    _currentMode = mode;
    _currentDifficulty = difficulty;
    _sessionStartTime = DateTime.now();
    _sessionAnalyses.clear();
    
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // 세션 진행 상황 체크
    });
    
    print('🎤 ${_getModeDescription(mode)} 연습 시작 (${_getDifficultyDescription(difficulty)})');
  }
  
  /// 연습 세션 종료
  TrainingSessionResult endTrainingSession() {
    final duration = _sessionStartTime != null 
        ? DateTime.now().difference(_sessionStartTime!)
        : Duration.zero;
    
    _sessionTimer?.cancel();
    
    final result = _evaluateSession();
    
    // 히스토리에 저장
    _sessionHistory[_currentMode] ??= [];
    _sessionHistory[_currentMode]!.add(result);
    
    return result;
  }
  
  /// 분석 데이터 추가
  void addAnalysis(VocalAnalysis analysis) {
    _sessionAnalyses.add(analysis);
  }
  
  /// 연습 모드별 실시간 가이드
  String getRealtimeGuidance(TrainingMode mode, VocalAnalysis? currentAnalysis) {
    if (currentAnalysis == null) {
      return _getInitialGuidance(mode);
    }
    
    switch (mode) {
      case TrainingMode.breathing:
        return _getBreathingGuidance(currentAnalysis);
      case TrainingMode.pitch:
        return _getPitchGuidance(currentAnalysis);
      case TrainingMode.scales:
        return _getScalesGuidance(currentAnalysis);
      case TrainingMode.resonance:
        return _getResonanceGuidance(currentAnalysis);
      case TrainingMode.expression:
        return _getExpressionGuidance(currentAnalysis);
      case TrainingMode.freeStyle:
        return _getFreeStyleGuidance(currentAnalysis);
    }
  }
  
  /// 연습 목표 설정
  Map<String, dynamic> getTrainingGoals(TrainingMode mode, TrainingDifficulty difficulty) {
    final baseGoals = _getBaseGoalsForMode(mode);
    final difficultyMultiplier = _getDifficultyMultiplier(difficulty);
    
    final goals = <String, dynamic>{};
    
    for (final entry in baseGoals.entries) {
      if (entry.value is num) {
        goals[entry.key] = (entry.value as num) * difficultyMultiplier;
      } else {
        goals[entry.key] = entry.value;
      }
    }
    
    return goals;
  }
  
  /// 세션 평가
  TrainingSessionResult _evaluateSession() {
    final mode = _currentMode!;
    final difficulty = _currentDifficulty!;
    final duration = DateTime.now().difference(_sessionStartTime!);
    
    // 모드별 평가
    final score = _calculateSessionScore(mode);
    final metrics = _calculateSessionMetrics(mode);
    final achievements = _checkAchievements(mode, score);
    final feedback = _generateSessionFeedback(mode, score);
    
    return TrainingSessionResult(
      mode: mode,
      difficulty: difficulty,
      score: score,
      duration: duration,
      analyses: List.from(_sessionAnalyses),
      metrics: metrics,
      achievements: achievements,
      feedback: feedback,
      timestamp: DateTime.now(),
    );
  }
  
  /// 모드별 점수 계산
  int _calculateSessionScore(TrainingMode mode) {
    if (_sessionAnalyses.isEmpty) return 0;
    
    switch (mode) {
      case TrainingMode.breathing:
        return _calculateBreathingScore();
      case TrainingMode.pitch:
        return _calculatePitchScore();
      case TrainingMode.scales:
        return _calculateScalesScore();
      case TrainingMode.resonance:
        return _calculateResonanceScore();
      case TrainingMode.expression:
        return _calculateExpressionScore();
      case TrainingMode.freeStyle:
        return _calculateOverallScore();
    }
  }
  
  /// 호흡법 점수 계산
  int _calculateBreathingScore() {
    final diaphragmaticCount = _sessionAnalyses
        .where((a) => a.breathingType == BreathingType.diaphragmatic)
        .length;
    
    final ratio = diaphragmaticCount / _sessionAnalyses.length;
    
    if (ratio >= 0.9) return 95;
    if (ratio >= 0.7) return 80;
    if (ratio >= 0.5) return 65;
    if (ratio >= 0.3) return 50;
    return 30;
  }
  
  /// 음정 점수 계산
  int _calculatePitchScore() {
    final avgStability = _sessionAnalyses
        .map((a) => a.pitchStability)
        .reduce((a, b) => a + b) / _sessionAnalyses.length;
    
    return (avgStability * 100).round().clamp(0, 100);
  }
  
  /// 스케일 점수 계산
  int _calculateScalesScore() {
    // 음정 정확도 + 일관성
    final pitchScore = _calculatePitchScore();
    final consistencyScore = _calculateConsistencyScore();
    
    return ((pitchScore * 0.7) + (consistencyScore * 0.3)).round();
  }
  
  /// 공명 점수 계산
  int _calculateResonanceScore() {
    final resonanceVariety = _sessionAnalyses
        .map((a) => a.resonancePosition)
        .toSet()
        .length;
    
    // 다양한 공명 사용 = 높은 점수
    final varietyScore = math.min(resonanceVariety * 25, 100);
    
    // 적절한 공명 사용 평가
    final appropriatenessScore = _evaluateResonanceAppropriateness();
    
    return ((varietyScore * 0.4) + (appropriatenessScore * 0.6)).round();
  }
  
  /// 표현력 점수 계산
  int _calculateExpressionScore() {
    final vibratoScore = _evaluateVibratoUsage();
    final dynamicScore = _evaluateDynamicRange();
    
    return ((vibratoScore * 0.5) + (dynamicScore * 0.5)).round();
  }
  
  /// 종합 점수 계산
  int _calculateOverallScore() {
    return _sessionAnalyses
        .map((a) => ExpertEvaluationEngine.calculateExpertScore(a))
        .reduce((a, b) => a + b) ~/ _sessionAnalyses.length;
  }
  
  /// 일관성 점수 계산
  int _calculateConsistencyScore() {
    if (_sessionAnalyses.length < 2) return 100;
    
    final stabilities = _sessionAnalyses.map((a) => a.pitchStability).toList();
    final variance = _calculateVariance(stabilities);
    
    // 낮은 분산 = 높은 일관성
    final consistencyScore = math.max(0, 100 - (variance * 1000));
    return consistencyScore.round();
  }
  
  /// 공명 적절성 평가
  int _evaluateResonanceAppropriateness() {
    int appropriateCount = 0;
    
    for (final analysis in _sessionAnalyses) {
      final pitch = analysis.fundamentalFreq.isNotEmpty ? analysis.fundamentalFreq.last : 0;
      final expectedResonance = _getExpectedResonance(pitch);
      
      if (analysis.resonancePosition == expectedResonance) {
        appropriateCount++;
      }
    }
    
    return (appropriateCount / _sessionAnalyses.length * 100).round();
  }
  
  /// 비브라토 사용 평가
  int _evaluateVibratoUsage() {
    final appropriateVibratoCount = _sessionAnalyses
        .where((a) => a.vibratoQuality == VibratoQuality.light || 
                     a.vibratoQuality == VibratoQuality.medium)
        .length;
    
    return (appropriateVibratoCount / _sessionAnalyses.length * 100).round();
  }
  
  /// 다이나믹 레인지 평가
  int _evaluateDynamicRange() {
    if (_sessionAnalyses.isEmpty) return 0;
    
    final amplitudes = _sessionAnalyses.map((a) => a.spectralTilt.abs()).toList();
    final maxAmplitude = amplitudes.reduce(math.max);
    final minAmplitude = amplitudes.reduce(math.min);
    
    final dynamicRange = maxAmplitude - minAmplitude;
    
    // 적절한 다이나믹 레인지 = 높은 점수
    if (dynamicRange > 0.3) return 90;
    if (dynamicRange > 0.2) return 75;
    if (dynamicRange > 0.1) return 60;
    return 40;
  }
  
  /// 세션 메트릭스 계산
  Map<String, dynamic> _calculateSessionMetrics(TrainingMode mode) {
    final metrics = <String, dynamic>{
      'total_analyses': _sessionAnalyses.length,
      'average_score': _calculateOverallScore(),
      'improvement_trend': _calculateSessionImprovementTrend(),
    };
    
    switch (mode) {
      case TrainingMode.breathing:
        metrics['diaphragmatic_ratio'] = _sessionAnalyses
            .where((a) => a.breathingType == BreathingType.diaphragmatic)
            .length / _sessionAnalyses.length;
        break;
      case TrainingMode.pitch:
        metrics['average_stability'] = _sessionAnalyses
            .map((a) => a.pitchStability)
            .reduce((a, b) => a + b) / _sessionAnalyses.length;
        break;
      case TrainingMode.resonance:
        metrics['resonance_variety'] = _sessionAnalyses
            .map((a) => a.resonancePosition)
            .toSet()
            .length;
        break;
      // 다른 모드들도 추가...
    }
    
    return metrics;
  }
  
  /// 성취 확인
  List<String> _checkAchievements(TrainingMode mode, int score) {
    final achievements = <String>[];
    
    // 점수 기반 성취
    if (score >= 95) achievements.add('🏆 완벽한 연습!');
    if (score >= 85) achievements.add('🌟 우수한 실력!');
    if (score >= 70) achievements.add('👏 좋은 연습!');
    
    // 모드별 특별 성취
    switch (mode) {
      case TrainingMode.breathing:
        final diaphragmaticRatio = _sessionAnalyses
            .where((a) => a.breathingType == BreathingType.diaphragmatic)
            .length / _sessionAnalyses.length;
        if (diaphragmaticRatio >= 0.9) {
          achievements.add('💨 호흡법 마스터!');
        }
        break;
      case TrainingMode.pitch:
        final avgStability = _sessionAnalyses
            .map((a) => a.pitchStability)
            .reduce((a, b) => a + b) / _sessionAnalyses.length;
        if (avgStability >= 0.9) {
          achievements.add('🎵 완벽한 음정!');
        }
        break;
      // 다른 모드들도 추가...
    }
    
    // 연속 연습 성취
    if (_sessionHistory[mode] != null && _sessionHistory[mode]!.length >= 7) {
      achievements.add('🔥 일주일 연속 연습!');
    }
    
    return achievements;
  }
  
  /// 세션 피드백 생성
  String _generateSessionFeedback(TrainingMode mode, int score) {
    final feedback = StringBuffer();
    
    // 기본 피드백
    if (score >= 90) {
      feedback.write('탁월한 연습이었습니다! ');
    } else if (score >= 75) {
      feedback.write('매우 좋은 연습이었어요! ');
    } else if (score >= 60) {
      feedback.write('꾸준히 발전하고 있어요! ');
    } else {
      feedback.write('계속 연습하면 분명 늘 거예요! ');
    }
    
    // 모드별 구체적 피드백
    switch (mode) {
      case TrainingMode.breathing:
        final diaphragmaticRatio = _sessionAnalyses
            .where((a) => a.breathingType == BreathingType.diaphragmatic)
            .length / _sessionAnalyses.length;
        if (diaphragmaticRatio < 0.5) {
          feedback.write('복식호흡에 더 집중해보세요.');
        } else {
          feedback.write('호흡법이 많이 개선되었어요!');
        }
        break;
      case TrainingMode.pitch:
        final avgStability = _sessionAnalyses
            .map((a) => a.pitchStability)
            .reduce((a, b) => a + b) / _sessionAnalyses.length;
        if (avgStability < 0.7) {
          feedback.write('음정 안정성을 더 연습해보세요.');
        } else {
          feedback.write('음정이 매우 안정적이에요!');
        }
        break;
      // 다른 모드들도 추가...
    }
    
    return feedback.toString();
  }
  
  // Helper methods
  String _getModeDescription(TrainingMode mode) {
    switch (mode) {
      case TrainingMode.breathing: return '호흡법 연습';
      case TrainingMode.pitch: return '음정 연습';
      case TrainingMode.scales: return '스케일 연습';
      case TrainingMode.resonance: return '공명 연습';
      case TrainingMode.expression: return '표현력 연습';
      case TrainingMode.freeStyle: return '자유 연습';
    }
  }
  
  String _getDifficultyDescription(TrainingDifficulty difficulty) {
    switch (difficulty) {
      case TrainingDifficulty.beginner: return '초급';
      case TrainingDifficulty.intermediate: return '중급';
      case TrainingDifficulty.advanced: return '고급';
      case TrainingDifficulty.expert: return '전문가';
    }
  }
  
  String _getInitialGuidance(TrainingMode mode) {
    switch (mode) {
      case TrainingMode.breathing:
        return '편안한 자세로 앉아서 손을 배에 올리고 천천히 숨을 들이마셔보세요.';
      case TrainingMode.pitch:
        return '기준 음을 듣고 같은 높이로 "아" 소리를 내보세요.';
      case TrainingMode.scales:
        return '도-레-미-파-솔 순서로 천천히 불러보세요.';
      case TrainingMode.resonance:
        return '같은 음정으로 다양한 모음(아, 에, 이, 오, 우)을 연습해보세요.';
      case TrainingMode.expression:
        return '감정을 담아서 자유롭게 노래해보세요.';
      case TrainingMode.freeStyle:
        return '편안하게 원하는 대로 발성해보세요.';
    }
  }
  
  String _getBreathingGuidance(VocalAnalysis analysis) {
    switch (analysis.breathingType) {
      case BreathingType.diaphragmatic:
        return '완벽한 복식호흡이에요! 이 상태를 유지하세요.';
      case BreathingType.mixed:
        return '배를 더 의식하고 어깨 움직임을 줄여보세요.';
      case BreathingType.chest:
        return '어깨가 올라가지 않도록 하고 배로 숨을 쉬어보세요.';
    }
  }
  
  String _getPitchGuidance(VocalAnalysis analysis) {
    if (analysis.pitchStability > 0.9) {
      return '완벽한 음정입니다! 다음 음정으로 넘어가세요.';
    } else if (analysis.pitchStability > 0.7) {
      return '거의 정확해요! 조금 더 안정적으로 유지해보세요.';
    } else {
      return '음정을 더 정확하게 맞춰보세요. 천천히 집중해서.';
    }
  }
  
  String _getScalesGuidance(VocalAnalysis analysis) {
    // 스케일 진행에 따른 가이드
    return '다음 음으로 부드럽게 연결해보세요.';
  }
  
  String _getResonanceGuidance(VocalAnalysis analysis) {
    switch (analysis.resonancePosition) {
      case ResonancePosition.throat:
        return '목 공명이에요. 구강 공명도 시도해보세요.';
      case ResonancePosition.mouth:
        return '구강 공명이에요. 두성도 연습해보세요.';
      case ResonancePosition.head:
        return '두성 공명이에요. 다른 공명 위치도 시도해보세요.';
      case ResonancePosition.mixed:
        return '좋은 혼합 공명이에요!';
    }
  }
  
  String _getExpressionGuidance(VocalAnalysis analysis) {
    return '감정을 더 담아서 표현해보세요. 비브라토도 자연스럽게.';
  }
  
  String _getFreeStyleGuidance(VocalAnalysis analysis) {
    return '자유롭게 표현하세요! 모든 기법을 자연스럽게 사용해보세요.';
  }
  
  Map<String, dynamic> _getBaseGoalsForMode(TrainingMode mode) {
    switch (mode) {
      case TrainingMode.breathing:
        return {'diaphragmatic_ratio': 0.8, 'stability': 0.7};
      case TrainingMode.pitch:
        return {'pitch_stability': 0.8, 'accuracy_cents': 10.0};
      case TrainingMode.scales:
        return {'pitch_stability': 0.85, 'consistency': 0.8};
      case TrainingMode.resonance:
        return {'resonance_variety': 3, 'appropriateness': 0.7};
      case TrainingMode.expression:
        return {'vibrato_quality': 0.8, 'dynamic_range': 0.3};
      case TrainingMode.freeStyle:
        return {'overall_score': 75};
    }
  }
  
  double _getDifficultyMultiplier(TrainingDifficulty difficulty) {
    switch (difficulty) {
      case TrainingDifficulty.beginner: return 0.8;
      case TrainingDifficulty.intermediate: return 1.0;
      case TrainingDifficulty.advanced: return 1.2;
      case TrainingDifficulty.expert: return 1.5;
    }
  }
  
  ResonancePosition _getExpectedResonance(double pitch) {
    if (pitch < 200) return ResonancePosition.throat;
    if (pitch < 400) return ResonancePosition.mixed;
    if (pitch < 600) return ResonancePosition.mouth;
    return ResonancePosition.head;
  }
  
  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => math.pow(v - mean, 2)).toList();
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }
  
  double _calculateSessionImprovementTrend() {
    if (_sessionAnalyses.length < 6) return 0;
    
    final firstHalf = _sessionAnalyses.take(_sessionAnalyses.length ~/ 2)
        .map((a) => ExpertEvaluationEngine.calculateExpertScore(a));
    final secondHalf = _sessionAnalyses.skip(_sessionAnalyses.length ~/ 2)
        .map((a) => ExpertEvaluationEngine.calculateExpertScore(a));
    
    final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
    
    return (secondAvg - firstAvg) / firstAvg;
  }
  
  /// 통계 정보 반환
  Map<String, dynamic> getTrainingStatistics() {
    final stats = <String, dynamic>{};
    
    for (final mode in TrainingMode.values) {
      final sessions = _sessionHistory[mode] ?? [];
      if (sessions.isNotEmpty) {
        stats[mode.toString()] = {
          'total_sessions': sessions.length,
          'average_score': sessions.map((s) => s.score).reduce((a, b) => a + b) / sessions.length,
          'best_score': sessions.map((s) => s.score).reduce(math.max),
          'total_time': sessions.map((s) => s.duration.inMinutes).reduce((a, b) => a + b),
        };
      }
    }
    
    return stats;
  }
}