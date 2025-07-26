import 'dart:math' as math;
import '../../domain/entities/vocal_analysis.dart';

/// 보컬 전문가 지식 기반 데이터셋
class ExpertKnowledgeBase {
  
  /// 음정 정확도 기준 (전문가 표준)
  static const Map<String, Map<String, dynamic>> pitchAccuracyStandards = {
    'professional': {
      'tolerance_cents': 3.0,      // ±3 cent 이내
      'stability_min': 0.95,       // 95% 이상 안정성
      'description': '프로 보컬리스트 수준',
    },
    'advanced': {
      'tolerance_cents': 8.0,      // ±8 cent 이내  
      'stability_min': 0.85,       // 85% 이상 안정성
      'description': '고급 아마추어 수준',
    },
    'intermediate': {
      'tolerance_cents': 15.0,     // ±15 cent 이내
      'stability_min': 0.70,       // 70% 이상 안정성
      'description': '중급 학습자 수준',
    },
    'beginner': {
      'tolerance_cents': 25.0,     // ±25 cent 이내
      'stability_min': 0.50,       // 50% 이상 안정성
      'description': '초급 학습자 수준',
    },
  };

  /// 호흡법 평가 기준
  static const Map<BreathingType, Map<String, dynamic>> breathingStandards = {
    BreathingType.diaphragmatic: {
      'score': 100,
      'description': '완벽한 복식호흡',
      'characteristics': [
        '배가 주로 움직임',
        '어깨와 가슴 움직임 최소',
        '안정적이고 깊은 호흡',
        '긴 프레이즈 가능'
      ],
      'feedback': '이상적인 호흡법입니다. 계속 유지하세요!',
    },
    BreathingType.mixed: {
      'score': 70,
      'description': '혼합 호흡 (개선 필요)',
      'characteristics': [
        '배와 가슴이 함께 움직임',
        '부분적으로 복식호흡 활용',
        '중간 정도의 안정성'
      ],
      'feedback': '복식호흡 비중을 더 늘려보세요.',
    },
    BreathingType.chest: {
      'score': 40,
      'description': '흉식호흡 (교정 필요)',
      'characteristics': [
        '주로 가슴과 어깨 움직임',
        '얕고 불안정한 호흡',
        '긴 프레이즈 어려움'
      ],
      'feedback': '복식호흡으로 바꾸는 것이 필요합니다.',
    },
  };

  /// 공명 위치별 특성 및 평가
  static const Map<ResonancePosition, Map<String, dynamic>> resonanceStandards = {
    ResonancePosition.head: {
      'optimal_range': [350.0, 800.0],  // Hz
      'description': '두성 - 높은 음역에 적합',
      'characteristics': [
        '맑고 밝은 음색',
        '높은 음역에서 효율적',
        'F2 포먼트 2000Hz 이상'
      ],
      'usage': '고음역, 클래식, 발라드',
      'score_weight': 0.9,
    },
    ResonancePosition.mixed: {
      'optimal_range': [200.0, 600.0],  // Hz
      'description': '혼합 공명 - 균형잡힌 음색',
      'characteristics': [
        '풍부하고 균형잡힌 음색',
        '중음역에서 최적',
        '포먼트 균등 분포'
      ],
      'usage': '팝, R&B, 대부분 장르',
      'score_weight': 1.0,
    },
    ResonancePosition.throat: {
      'optimal_range': [100.0, 300.0],  // Hz
      'description': '목 공명 - 낮은 음역',
      'characteristics': [
        '깊고 무거운 음색',
        '저음역에서 효과적',
        'F1 포먼트 400Hz 이하'
      ],
      'usage': '저음역, 블루스, 재즈',
      'score_weight': 0.8,
    },
    ResonancePosition.mouth: {
      'optimal_range': [250.0, 500.0],  // Hz
      'description': '구강 공명 - 중간 음역',
      'characteristics': [
        '명확한 발음',
        '중음역 중심',
        '말하기와 유사한 공명'
      ],
      'usage': '대화형 가창, 뮤지컬',
      'score_weight': 0.85,
    },
  };

  /// 입 모양별 포먼트 기준값
  static const Map<MouthOpening, Map<String, dynamic>> mouthShapeStandards = {
    MouthOpening.narrow: {
      'f1_range': [200.0, 350.0],
      'f2_range': [1800.0, 2500.0],
      'vowels': ['i', 'u'],
      'description': '좁은 입 모양 - 닫힌 모음',
    },
    MouthOpening.medium: {
      'f1_range': [350.0, 550.0],
      'f2_range': [1200.0, 1800.0],
      'vowels': ['e', 'o'],
      'description': '중간 입 모양 - 중간 모음',
    },
    MouthOpening.wide: {
      'f1_range': [550.0, 800.0],
      'f2_range': [1000.0, 1500.0],
      'vowels': ['a'],
      'description': '넓은 입 모양 - 열린 모음',
    },
  };

  /// 비브라토 품질 기준
  static const Map<VibratoQuality, Map<String, dynamic>> vibratoStandards = {
    VibratoQuality.none: {
      'score': 60,
      'description': '비브라토 없음',
      'feedback': '롱톤에서 자연스러운 비브라토를 연습해보세요.',
    },
    VibratoQuality.light: {
      'score': 85,
      'description': '가벼운 비브라토',
      'frequency_range': [4.5, 6.0],  // Hz
      'feedback': '좋은 비브라토입니다. 조금 더 깊이를 더해보세요.',
    },
    VibratoQuality.medium: {
      'score': 95,
      'description': '적절한 비브라토',
      'frequency_range': [5.0, 7.0],  // Hz
      'feedback': '완벽한 비브라토입니다!',
    },
    VibratoQuality.heavy: {
      'score': 70,
      'description': '과도한 비브라토',
      'frequency_range': [7.0, 10.0], // Hz
      'feedback': '비브라토가 조금 강해요. 더 자연스럽게 해보세요.',
    },
  };

  /// 전문가 레벨 종합 평가 기준
  static const Map<String, Map<String, dynamic>> overallLevelStandards = {
    'expert': {
      'score_range': [90, 100],
      'requirements': {
        'pitch_stability': 0.95,
        'breathing': BreathingType.diaphragmatic,
        'vibrato': [VibratoQuality.light, VibratoQuality.medium],
      },
      'description': '전문가 수준',
      'feedback': '프로페셔널한 실력입니다!',
    },
    'advanced': {
      'score_range': [75, 89],
      'requirements': {
        'pitch_stability': 0.85,
        'breathing': [BreathingType.diaphragmatic, BreathingType.mixed],
      },
      'description': '고급 수준',
      'feedback': '매우 좋은 실력이에요. 조금만 더!',
    },
    'intermediate': {
      'score_range': [60, 74],
      'requirements': {
        'pitch_stability': 0.70,
      },
      'description': '중급 수준',
      'feedback': '꾸준히 발전하고 있어요!',
    },
    'beginner': {
      'score_range': [0, 59],
      'description': '초급 수준',
      'feedback': '기초부터 차근차근 연습해봅시다!',
    },
  };

  /// 장르별 보컬 특성 기준
  static const Map<String, Map<String, dynamic>> genreStandards = {
    'classical': {
      'breathing': BreathingType.diaphragmatic,
      'resonance': ResonancePosition.head,
      'vibrato': VibratoQuality.medium,
      'pitch_tolerance': 3.0,
      'description': '클래식 성악',
    },
    'pop': {
      'breathing': [BreathingType.diaphragmatic, BreathingType.mixed],
      'resonance': ResonancePosition.mixed,
      'vibrato': [VibratoQuality.light, VibratoQuality.medium],
      'pitch_tolerance': 8.0,
      'description': '팝 음악',
    },
    'jazz': {
      'breathing': BreathingType.diaphragmatic,
      'resonance': [ResonancePosition.throat, ResonancePosition.mixed],
      'vibrato': VibratoQuality.light,
      'pitch_tolerance': 15.0, // 재즈는 의도적 변형 허용
      'description': '재즈',
    },
    'rock': {
      'breathing': BreathingType.mixed,
      'resonance': ResonancePosition.throat,
      'vibrato': [VibratoQuality.none, VibratoQuality.light],
      'pitch_tolerance': 12.0,
      'description': '록 음악',
    },
  };

  /// 연습 단계별 목표 설정
  static const Map<String, Map<String, dynamic>> practiceStageGoals = {
    'stage_1_breathing': {
      'title': '기초 호흡법',
      'duration_weeks': 2,
      'goals': [
        '복식호흡 습득',
        '15초 이상 안정적 발성',
        '호흡 분산도 0.05 이하',
      ],
      'success_criteria': {
        'breathing_type': BreathingType.diaphragmatic,
        'stability_duration': 15.0,
      },
    },
    'stage_2_pitch': {
      'title': '음정 정확도',
      'duration_weeks': 3,
      'goals': [
        '±15 cent 이내 음정',
        '70% 이상 피치 안정성',
        '기본 스케일 연주',
      ],
      'success_criteria': {
        'pitch_tolerance': 15.0,
        'pitch_stability': 0.70,
      },
    },
    'stage_3_resonance': {
      'title': '공명과 음색',
      'duration_weeks': 4,
      'goals': [
        '다양한 공명 위치 활용',
        '포먼트 의식적 조절',
        '음역대별 적절한 공명',
      ],
      'success_criteria': {
        'resonance_control': 3, // 3가지 이상 공명 활용
      },
    },
    'stage_4_expression': {
      'title': '표현과 비브라토',
      'duration_weeks': 4,
      'goals': [
        '자연스러운 비브라토',
        '감정 표현 기법',
        '다이나믹 조절',
      ],
      'success_criteria': {
        'vibrato_quality': [VibratoQuality.light, VibratoQuality.medium],
        'expression_score': 80,
      },
    },
  };

  /// 실시간 피드백 우선순위 매트릭스
  static const Map<String, Map<String, dynamic>> feedbackPriorityMatrix = {
    'critical_errors': {
      'weight': 1.0,
      'conditions': [
        'pitch_deviation > 25 cents',
        'breathing_type == chest && duration > 10s',
        'voice_strain_detected',
      ],
      'immediate_feedback': true,
    },
    'technique_improvement': {
      'weight': 0.8,
      'conditions': [
        'pitch_stability < user_baseline * 0.8',
        'breathing_inconsistency > threshold',
      ],
      'immediate_feedback': true,
    },
    'optimization_tips': {
      'weight': 0.6,
      'conditions': [
        'good_performance && room_for_improvement',
        'genre_specific_suggestions',
      ],
      'immediate_feedback': false,
    },
    'encouragement': {
      'weight': 0.4,
      'conditions': [
        'improvement_detected',
        'goal_achieved',
        'consistent_practice',
      ],
      'immediate_feedback': false,
    },
  };

  /// 전문가 검증 테스트 케이스
  static const List<Map<String, dynamic>> expertTestCases = [
    {
      'name': 'perfect_pitch_test',
      'input': {
        'fundamental_freq': [440.0], // A4
        'pitch_stability': 0.98,
        'breathing_type': BreathingType.diaphragmatic,
      },
      'expected_score': 95,
      'expected_feedback': '완벽한 음정과 호흡입니다!',
    },
    {
      'name': 'beginner_chest_breathing',
      'input': {
        'fundamental_freq': [435.0], // 약간 낮은 A4
        'pitch_stability': 0.65,
        'breathing_type': BreathingType.chest,
      },
      'expected_score': 45,
      'expected_feedback': '복식호흡으로 바꿔보세요',
    },
    {
      'name': 'intermediate_improvement',
      'input': {
        'fundamental_freq': [445.0], // 약간 높은 A4
        'pitch_stability': 0.78,
        'breathing_type': BreathingType.mixed,
      },
      'expected_score': 72,
      'expected_feedback': '좋은 진전이에요!',
    },
  ];

  /// 음성학 기반 포먼트 분석 기준
  static const Map<String, Map<String, dynamic>> formantAnalysisStandards = {
    'vowel_identification': {
      'a': {'f1': 730, 'f2': 1090},
      'e': {'f1': 530, 'f2': 1840},
      'i': {'f1': 270, 'f2': 2290},
      'o': {'f1': 570, 'f2': 840},
      'u': {'f1': 300, 'f2': 870},
    },
    'quality_metrics': {
      'clarity': 'f2_f1_ratio > 2.0',
      'brightness': 'f2 > 1500',
      'depth': 'f1 < 400',
    },
  };

  /// AI 학습을 위한 가중치 설정
  static const Map<String, double> aiLearningWeights = {
    'pitch_accuracy': 0.35,        // 35% - 가장 중요
    'breathing_technique': 0.25,   // 25% - 기초 중요도
    'resonance_control': 0.20,     // 20% - 음색 품질
    'expression_vibrato': 0.15,    // 15% - 표현력
    'overall_stability': 0.05,     // 5% - 전체적 안정성
  };

  /// 개인화 학습 파라미터
  static const Map<String, dynamic> personalizationConfig = {
    'adaptation_rate': 0.1,          // 10% 학습률
    'baseline_update_threshold': 5,   // 5회 세션 후 베이스라인 업데이트
    'improvement_sensitivity': 0.05,  // 5% 향상 감지 임계값
    'confidence_threshold': 0.8,      // 80% 신뢰도 이상만 학습 반영
  };
}

/// 전문가 지식 기반 평가 엔진
class ExpertEvaluationEngine {
  
  /// 전문가 기준으로 종합 점수 계산
  static int calculateExpertScore(VocalAnalysis analysis) {
    double totalScore = 0.0;
    
    // 1. 음정 정확도 평가
    final pitchScore = _evaluatePitchAccuracy(analysis);
    totalScore += pitchScore * ExpertKnowledgeBase.aiLearningWeights['pitch_accuracy']!;
    
    // 2. 호흡법 평가
    final breathingScore = _evaluateBreathing(analysis);
    totalScore += breathingScore * ExpertKnowledgeBase.aiLearningWeights['breathing_technique']!;
    
    // 3. 공명 평가
    final resonanceScore = _evaluateResonance(analysis);
    totalScore += resonanceScore * ExpertKnowledgeBase.aiLearningWeights['resonance_control']!;
    
    // 4. 표현력 평가
    final expressionScore = _evaluateExpression(analysis);
    totalScore += expressionScore * ExpertKnowledgeBase.aiLearningWeights['expression_vibrato']!;
    
    // 5. 전체 안정성 평가
    final stabilityScore = _evaluateStability(analysis);
    totalScore += stabilityScore * ExpertKnowledgeBase.aiLearningWeights['overall_stability']!;
    
    return (totalScore * 100).round().clamp(0, 100);
  }
  
  /// 사용자 레벨 판정
  static String determineUserLevel(List<VocalAnalysis> history) {
    if (history.length < 5) return 'beginner';
    
    final averageScore = history.map((a) => calculateExpertScore(a))
        .reduce((a, b) => a + b) / history.length;
    
    for (final entry in ExpertKnowledgeBase.overallLevelStandards.entries) {
      final range = entry.value['score_range'] as List<int>;
      if (averageScore >= range[0] && averageScore <= range[1]) {
        return entry.key;
      }
    }
    
    return 'beginner';
  }
  
  /// 개인별 목표 설정
  static Map<String, dynamic> setPersonalizedGoals(String userLevel, List<VocalAnalysis> history) {
    final goals = <String, dynamic>{};
    
    // 현재 레벨 기준 다음 단계 목표 설정
    switch (userLevel) {
      case 'beginner':
        goals['primary'] = 'breathing_improvement';
        goals['target_breathing'] = BreathingType.diaphragmatic;
        goals['target_stability'] = 0.6;
        break;
      case 'intermediate':
        goals['primary'] = 'pitch_accuracy';
        goals['target_tolerance'] = 10.0;
        goals['target_stability'] = 0.8;
        break;
      case 'advanced':
        goals['primary'] = 'expression_refinement';
        goals['target_vibrato'] = VibratoQuality.medium;
        goals['target_score'] = 90;
        break;
      case 'expert':
        goals['primary'] = 'consistency_maintenance';
        goals['target_score'] = 95;
        break;
    }
    
    return goals;
  }
  
  // Private helper methods
  static double _evaluatePitchAccuracy(VocalAnalysis analysis) {
    final stability = analysis.pitchStability;
    
    if (stability >= 0.95) return 100.0;
    if (stability >= 0.85) return 85.0;
    if (stability >= 0.70) return 70.0;
    if (stability >= 0.50) return 50.0;
    return 30.0;
  }
  
  static double _evaluateBreathing(VocalAnalysis analysis) {
    final standards = ExpertKnowledgeBase.breathingStandards[analysis.breathingType];
    return (standards?['score'] as int?)?.toDouble() ?? 40.0;
  }
  
  static double _evaluateResonance(VocalAnalysis analysis) {
    final standards = ExpertKnowledgeBase.resonanceStandards[analysis.resonancePosition];
    final weight = (standards?['score_weight'] as double?) ?? 0.5;
    return weight * 100;
  }
  
  static double _evaluateExpression(VocalAnalysis analysis) {
    final standards = ExpertKnowledgeBase.vibratoStandards[analysis.vibratoQuality];
    return (standards?['score'] as int?)?.toDouble() ?? 60.0;
  }
  
  static double _evaluateStability(VocalAnalysis analysis) {
    return analysis.pitchStability * 100;
  }
}