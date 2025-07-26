import 'dart:async';
import 'dart:math' as math;
import '../../domain/entities/vocal_analysis.dart';
import 'expert_knowledge_base.dart';

/// AI 기반 스마트 피드백 결과
class SmartFeedback {
  final String mainMessage;
  final List<String> specificTips;
  final FeedbackPriority priority;
  final FeedbackCategory category;
  final double confidence;
  final String encouragement;
  final Map<String, dynamic> metrics;

  const SmartFeedback({
    required this.mainMessage,
    required this.specificTips,
    required this.priority,
    required this.category,
    required this.confidence,
    required this.encouragement,
    required this.metrics,
  });
}

enum FeedbackPriority { critical, high, medium, low, celebration }
enum FeedbackCategory { pitch, breathing, resonance, posture, overall }

/// 학습 기반 AI 피드백 엔진
class SmartFeedbackEngine {
  // 사용자 학습 데이터
  final List<VocalAnalysis> _analysisHistory = [];
  final Map<FeedbackCategory, int> _improvementCounter = {};
  final Map<String, double> _userBaseline = {};
  
  // 학습 파라미터
  static const int _historyWindow = 20; // 최근 20개 분석 결과 활용
  static const double _improvementThreshold = 0.1; // 10% 향상시 축하
  
  /// 실시간 스마트 피드백 생성
  SmartFeedback generateSmartFeedback(VocalAnalysis currentAnalysis) {
    // 분석 히스토리에 추가
    _analysisHistory.add(currentAnalysis);
    if (_analysisHistory.length > _historyWindow) {
      _analysisHistory.removeAt(0);
    }
    
    // 베이스라인 업데이트
    _updateUserBaseline();
    
    // 개인화된 피드백 생성
    return _generatePersonalizedFeedback(currentAnalysis);
  }
  
  /// 사용자 베이스라인 학습
  void _updateUserBaseline() {
    if (_analysisHistory.length < 5) return;
    
    final recent = _analysisHistory.take(10).toList();
    
    _userBaseline['pitch_stability'] = recent
        .map((a) => a.pitchStability)
        .reduce((a, b) => a + b) / recent.length;
    
    _userBaseline['overall_score'] = recent
        .map((a) => a.overallScore.toDouble())
        .reduce((a, b) => a + b) / recent.length;
        
    final fundamentalFreqs = recent
        .where((a) => a.fundamentalFreq.isNotEmpty)
        .map((a) => a.fundamentalFreq.last)
        .where((f) => f > 0);
    
    if (fundamentalFreqs.isNotEmpty) {
      _userBaseline['average_pitch'] = fundamentalFreqs
          .reduce((a, b) => a + b) / fundamentalFreqs.length;
    }
  }
  
  /// 개인화된 피드백 생성
  SmartFeedback _generatePersonalizedFeedback(VocalAnalysis analysis) {
    // 다중 분석 수행
    final pitchAnalysis = _analyzePitchTrend(analysis);
    final breathingAnalysis = _analyzeBreathingPattern(analysis);
    final progressAnalysis = _analyzeProgress(analysis);
    final overallAnalysis = _analyzeOverallPerformance(analysis);
    
    // 우선순위 결정
    final feedbacks = [pitchAnalysis, breathingAnalysis, progressAnalysis, overallAnalysis];
    feedbacks.sort((a, b) => _getPriorityScore(b.priority).compareTo(_getPriorityScore(a.priority)));
    
    // 가장 중요한 피드백 선택하되, 개인화 요소 추가
    final primaryFeedback = feedbacks.first;
    
    return SmartFeedback(
      mainMessage: _personalizeMessage(primaryFeedback.mainMessage, analysis),
      specificTips: _generateSmartTips(analysis, primaryFeedback.category),
      priority: primaryFeedback.priority,
      category: primaryFeedback.category,
      confidence: _calculateConfidence(analysis),
      encouragement: _generateEncouragement(analysis),
      metrics: _generateMetrics(analysis),
    );
  }
  
  /// 피치 트렌드 분석
  SmartFeedback _analyzePitchTrend(VocalAnalysis analysis) {
    final currentPitch = analysis.fundamentalFreq.isNotEmpty ? analysis.fundamentalFreq.last : 0.0;
    final stability = analysis.pitchStability;
    
    if (currentPitch == 0.0) {
      return SmartFeedback(
        mainMessage: "발성이 감지되지 않습니다",
        specificTips: ["더 명확하고 안정적으로 발성해보세요", "입을 적당히 벌리고 편안하게 소리내세요"],
        priority: FeedbackPriority.high,
        category: FeedbackCategory.pitch,
        confidence: 0.9,
        encouragement: "천천히, 자연스럽게 시작해보세요",
        metrics: {'current_pitch': currentPitch, 'stability': stability},
      );
    }
    
    if (stability < 0.3) {
      return SmartFeedback(
        mainMessage: "음정이 불안정합니다",
        specificTips: [
          "호흡을 더 깊고 안정적으로 유지하세요",
          "목에 힘을 빼고 편안하게 발성하세요",
          "한 음정에 집중해서 길게 유지해보세요"
        ],
        priority: FeedbackPriority.high,
        category: FeedbackCategory.pitch,
        confidence: 0.8,
        encouragement: "조금씩 안정성이 향상되고 있어요!",
        metrics: {'current_pitch': currentPitch, 'stability': stability},
      );
    }
    
    if (stability > 0.8) {
      return SmartFeedback(
        mainMessage: "훌륭한 음정 안정성입니다!",
        specificTips: [
          "이 상태를 유지하며 다른 음정도 연습해보세요",
          "음정 변화를 부드럽게 연결해보세요"
        ],
        priority: FeedbackPriority.celebration,
        category: FeedbackCategory.pitch,
        confidence: 0.95,
        encouragement: "완벽한 음정 컨트롤이에요! 👏",
        metrics: {'current_pitch': currentPitch, 'stability': stability},
      );
    }
    
    return SmartFeedback(
      mainMessage: "음정이 개선되고 있습니다",
      specificTips: [
        "현재 상태를 유지하며 조금 더 안정적으로 발성해보세요",
        "음정에 집중하며 천천히 연습하세요"
      ],
      priority: FeedbackPriority.medium,
      category: FeedbackCategory.pitch,
      confidence: 0.7,
      encouragement: "좋은 진전이에요!",
      metrics: {'current_pitch': currentPitch, 'stability': stability},
    );
  }
  
  /// 호흡 패턴 분석
  SmartFeedback _analyzeBreathingPattern(VocalAnalysis analysis) {
    final breathingType = analysis.breathingType;
    
    switch (breathingType) {
      case BreathingType.diaphragmatic:
        return SmartFeedback(
          mainMessage: "완벽한 복식호흡입니다!",
          specificTips: [
            "이 호흡법을 계속 유지하세요",
            "더 긴 프레이즈에도 적용해보세요"
          ],
          priority: FeedbackPriority.celebration,
          category: FeedbackCategory.breathing,
          confidence: 0.9,
          encouragement: "전문가 수준의 호흡법이에요! 🎵",
          metrics: {'breathing_type': breathingType.toString()},
        );
        
      case BreathingType.mixed:
        return SmartFeedback(
          mainMessage: "호흡이 개선되고 있습니다",
          specificTips: [
            "배를 더 의식적으로 사용해보세요",
            "어깨가 올라가지 않도록 주의하세요",
            "천천히 깊은 호흡을 연습하세요"
          ],
          priority: FeedbackPriority.medium,
          category: FeedbackCategory.breathing,
          confidence: 0.75,
          encouragement: "복식호흡에 가까워지고 있어요!",
          metrics: {'breathing_type': breathingType.toString()},
        );
        
      case BreathingType.chest:
        return SmartFeedback(
          mainMessage: "복식호흡으로 바꿔보세요",
          specificTips: [
            "손을 배에 올리고 배가 움직이는지 확인하세요",
            "어깨와 가슴보다 배를 움직여 호흡하세요",
            "코로 천천히 들이마시고 입으로 내쉬세요"
          ],
          priority: FeedbackPriority.high,
          category: FeedbackCategory.breathing,
          confidence: 0.85,
          encouragement: "호흡법만 바꿔도 큰 발전이 있을 거예요!",
          metrics: {'breathing_type': breathingType.toString()},
        );
    }
  }
  
  /// 진행도 분석
  SmartFeedback _analyzeProgress(VocalAnalysis analysis) {
    if (_analysisHistory.length < 10) {
      return SmartFeedback(
        mainMessage: "데이터를 수집 중입니다",
        specificTips: ["계속 연습하시면 개인 맞춤 피드백을 제공하겠습니다"],
        priority: FeedbackPriority.low,
        category: FeedbackCategory.overall,
        confidence: 0.5,
        encouragement: "좋은 시작이에요!",
        metrics: {'sessions': _analysisHistory.length},
      );
    }
    
    final oldAverage = _analysisHistory.take(5).map((a) => a.overallScore).reduce((a, b) => a + b) / 5;
    final recentAverage = _analysisHistory.skip(_analysisHistory.length - 5).map((a) => a.overallScore).reduce((a, b) => a + b) / 5;
    
    final improvement = (recentAverage - oldAverage) / oldAverage;
    
    if (improvement > _improvementThreshold) {
      return SmartFeedback(
        mainMessage: "놀라운 발전입니다!",
        specificTips: [
          "최근 ${(improvement * 100).toStringAsFixed(1)}% 향상되었습니다",
          "이 상태를 유지하며 새로운 도전을 해보세요"
        ],
        priority: FeedbackPriority.celebration,
        category: FeedbackCategory.overall,
        confidence: 0.9,
        encouragement: "정말 대단한 실력 향상이에요! 🌟",
        metrics: {'improvement': improvement, 'old_avg': oldAverage, 'recent_avg': recentAverage},
      );
    }
    
    return SmartFeedback(
      mainMessage: "꾸준히 발전하고 있습니다",
      specificTips: ["지금까지의 노력이 결실을 맺고 있어요"],
      priority: FeedbackPriority.low,
      category: FeedbackCategory.overall,
      confidence: 0.7,
      encouragement: "꾸준함이 실력을 만듭니다!",
      metrics: {'improvement': improvement},
    );
  }
  
  /// 종합 성능 분석
  SmartFeedback _analyzeOverallPerformance(VocalAnalysis analysis) {
    final score = analysis.overallScore;
    
    if (score >= 90) {
      return SmartFeedback(
        mainMessage: "완벽한 퍼포먼스입니다!",
        specificTips: [
          "전문가 수준의 발성이에요",
          "이 실력을 다양한 곡에 적용해보세요"
        ],
        priority: FeedbackPriority.celebration,
        category: FeedbackCategory.overall,
        confidence: 0.95,
        encouragement: "정말 훌륭합니다! 프로 수준이에요! 🎤",
        metrics: {'overall_score': score},
      );
    } else if (score >= 70) {
      return SmartFeedback(
        mainMessage: "매우 좋은 실력입니다",
        specificTips: [
          "조금만 더 세밀하게 다듬으면 완벽해질 거예요",
          "특정 부분에 집중해서 연습해보세요"
        ],
        priority: FeedbackPriority.medium,
        category: FeedbackCategory.overall,
        confidence: 0.8,
        encouragement: "거의 다 왔어요! 조금만 더!",
        metrics: {'overall_score': score},
      );
    } else if (score >= 50) {
      return SmartFeedback(
        mainMessage: "기본기를 다지고 있습니다",
        specificTips: [
          "호흡과 자세에 더 집중해보세요",
          "기본 발성 연습을 반복하세요"
        ],
        priority: FeedbackPriority.medium,
        category: FeedbackCategory.overall,
        confidence: 0.75,
        encouragement: "기초가 탄탄해지고 있어요!",
        metrics: {'overall_score': score},
      );
    } else {
      return SmartFeedback(
        mainMessage: "차근차근 연습해봅시다",
        specificTips: [
          "기본 호흡법부터 천천히 익혀보세요",
          "편안한 자세로 간단한 발성부터 시작하세요"
        ],
        priority: FeedbackPriority.high,
        category: FeedbackCategory.overall,
        confidence: 0.9,
        encouragement: "모든 전문가도 이 단계를 거쳤어요. 천천히 해봅시다!",
        metrics: {'overall_score': score},
      );
    }
  }
  
  /// 메시지 개인화
  String _personalizeMessage(String baseMessage, VocalAnalysis analysis) {
    final sessionCount = _analysisHistory.length;
    
    if (sessionCount > 50) {
      return "🎵 경험자님, $baseMessage";
    } else if (sessionCount > 20) {
      return "🎶 $baseMessage";
    } else if (sessionCount > 5) {
      return "🎤 $baseMessage";
    } else {
      return "🌟 $baseMessage";
    }
  }
  
  /// 스마트 팁 생성
  List<String> _generateSmartTips(VocalAnalysis analysis, FeedbackCategory category) {
    final tips = <String>[];
    
    // 개인 히스토리 기반 팁
    if (_userBaseline.containsKey('pitch_stability')) {
      final currentStability = analysis.pitchStability;
      final averageStability = _userBaseline['pitch_stability']!;
      
      if (currentStability < averageStability * 0.8) {
        tips.add("평소보다 음정이 불안해요. 천천히 집중해보세요");
      }
    }
    
    // 공명 위치 기반 팁
    switch (analysis.resonancePosition) {
      case ResonancePosition.throat:
        tips.add("목 공명: 목에 힘을 빼고 자연스럽게 발성하세요");
        break;
      case ResonancePosition.mouth:
        tips.add("구강 공명: 입 모양을 더 정확하게 만들어보세요");
        break;
      case ResonancePosition.head:
        tips.add("두성 공명: 높은 음역에서 안정적인 발성이에요");
        break;
      case ResonancePosition.mixed:
        tips.add("혼합 공명: 다양한 음역을 잘 활용하고 계세요");
        break;
    }
    
    // 시간대별 팁
    final hour = DateTime.now().hour;
    if (hour < 10) {
      tips.add("💪 아침 연습: 목을 충분히 풀어주세요");
    } else if (hour > 20) {
      tips.add("🌙 저녁 연습: 무리하지 말고 부드럽게 연습하세요");
    }
    
    return tips.take(3).toList();
  }
  
  /// 신뢰도 계산
  double _calculateConfidence(VocalAnalysis analysis) {
    double confidence = 0.5;
    
    // 음성 품질이 좋을수록 높은 신뢰도
    if (analysis.fundamentalFreq.isNotEmpty && analysis.fundamentalFreq.last > 0) {
      confidence += 0.2;
    }
    
    // 안정적인 피치일수록 높은 신뢰도
    confidence += analysis.pitchStability * 0.3;
    
    // 데이터가 충분할수록 높은 신뢰도
    confidence += math.min(_analysisHistory.length / 20.0, 1.0) * 0.2;
    
    return confidence.clamp(0.0, 1.0);
  }
  
  /// 격려 메시지 생성
  String _generateEncouragement(VocalAnalysis analysis) {
    final encouragements = [
      "계속 이렇게 해보세요!",
      "좋은 방향으로 가고 있어요!",
      "실력이 늘고 있는 게 보여요!",
      "꾸준히 연습하는 모습이 멋져요!",
      "조금씩 발전하고 있어요!",
      "이 페이스로 계속 해봅시다!",
      "정말 열심히 하고 계시네요!",
      "음성이 점점 안정적이 되고 있어요!",
    ];
    
    final index = (analysis.overallScore + _analysisHistory.length) % encouragements.length;
    return encouragements[index];
  }
  
  /// 성능 지표 생성
  Map<String, dynamic> _generateMetrics(VocalAnalysis analysis) {
    return {
      'session_count': _analysisHistory.length,
      'current_score': analysis.overallScore,
      'pitch_stability': analysis.pitchStability,
      'breathing_type': analysis.breathingType.toString(),
      'resonance_position': analysis.resonancePosition.toString(),
      'improvement_trend': _calculateImprovementTrend(),
      'user_level': _getUserLevel(),
    };
  }
  
  /// 개선 추세 계산
  double _calculateImprovementTrend() {
    if (_analysisHistory.length < 6) return 0.0;
    
    final recent3 = _analysisHistory.skip(_analysisHistory.length - 3).map((a) => a.overallScore.toDouble()).toList();
    final previous3 = _analysisHistory.skip(_analysisHistory.length - 6).take(3).map((a) => a.overallScore.toDouble()).toList();
    
    final recentAvg = recent3.reduce((a, b) => a + b) / recent3.length;
    final previousAvg = previous3.reduce((a, b) => a + b) / previous3.length;
    
    return (recentAvg - previousAvg) / previousAvg;
  }
  
  /// 전문가 기준 사용자 레벨 판정
  String _getUserLevel() {
    return ExpertEvaluationEngine.determineUserLevel(_analysisHistory);
  }
  
  /// 우선순위 점수 계산
  int _getPriorityScore(FeedbackPriority priority) {
    switch (priority) {
      case FeedbackPriority.critical: return 5;
      case FeedbackPriority.high: return 4;
      case FeedbackPriority.medium: return 3;
      case FeedbackPriority.low: return 2;
      case FeedbackPriority.celebration: return 6; // 축하는 최우선
    }
  }
  
  /// 히스토리 클리어
  void clearHistory() {
    _analysisHistory.clear();
    _improvementCounter.clear();
    _userBaseline.clear();
  }
  
  /// 통계 정보 반환
  Map<String, dynamic> getStatistics() {
    if (_analysisHistory.isEmpty) return {};
    
    return {
      'total_sessions': _analysisHistory.length,
      'average_score': _analysisHistory.map((a) => a.overallScore).reduce((a, b) => a + b) / _analysisHistory.length,
      'user_level': _getUserLevel(),
      'improvement_trend': _calculateImprovementTrend(),
      'user_baseline': Map.from(_userBaseline),
    };
  }
}