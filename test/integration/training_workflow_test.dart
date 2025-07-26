import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_trainer_ai/domain/entities/vocal_analysis.dart';
import 'package:vocal_trainer_ai/features/ai_coaching/expert_knowledge_base.dart';
import 'package:vocal_trainer_ai/features/ai_coaching/smart_feedback_engine.dart';
import 'package:vocal_trainer_ai/features/training_modules/structured_vocal_training.dart';

/// 전체 트레이닝 워크플로우 통합 테스트
/// 
/// 이 테스트는 실제 사용자의 학습 여정을 시뮬레이션하여
/// AI 시스템의 종합적인 동작을 검증합니다.
void main() {
  group('Complete Training Workflow Integration Tests', () {
    late SmartFeedbackEngine feedbackEngine;
    late StructuredVocalTraining trainingSystem;

    setUp(() {
      feedbackEngine = SmartFeedbackEngine();
      trainingSystem = StructuredVocalTraining();
    });

    test('Beginner to Intermediate Journey - 4 Week Simulation', () async {
      print('\n=== 초급자 → 중급자 학습 여정 시뮬레이션 ===');
      
      // 1주차: 호흡법 기초 연습
      print('\n📅 1주차: 호흡법 기초 연습');
      trainingSystem.startTrainingSession(TrainingMode.breathing, TrainingDifficulty.beginner);
      
      final week1Sessions = _generateWeeklyProgressSessions(
        startScore: 35,
        endScore: 55,
        primaryImprovement: 'breathing',
        sessionCount: 7,
      );
      
      for (int i = 0; i < week1Sessions.length; i++) {
        final session = week1Sessions[i];
        trainingSystem.addAnalysis(session);
        final feedback = feedbackEngine.generateSmartFeedback(session);
        
        print('  세션 ${i + 1}: 점수 ${session.overallScore}, 호흡: ${session.breathingType.name}');
        print('    피드백: ${feedback.mainMessage}');
        
        if (i == 0) {
          // 첫 세션에서는 호흡법 개선 필요
          expect(feedback.category, equals(FeedbackCategory.breathing));
          expect(feedback.priority, equals(FeedbackPriority.high));
        }
      }
      
      final week1Result = trainingSystem.endTrainingSession();
      print('  1주차 결과: ${week1Result.score}점, 피드백: ${week1Result.feedback}');
      expect(week1Result.score, greaterThan(50));
      
      // 2주차: 음정 정확도 연습
      print('\n📅 2주차: 음정 정확도 연습');
      trainingSystem.startTrainingSession(TrainingMode.pitch, TrainingDifficulty.beginner);
      
      final week2Sessions = _generateWeeklyProgressSessions(
        startScore: 55,
        endScore: 65,
        primaryImprovement: 'pitch',
        sessionCount: 7,
      );
      
      for (final session in week2Sessions) {
        trainingSystem.addAnalysis(session);
        final feedback = feedbackEngine.generateSmartFeedback(session);
        print('  피치 안정성: ${(session.pitchStability * 100).toInt()}%, 피드백: ${feedback.mainMessage}');
      }
      
      final week2Result = trainingSystem.endTrainingSession();
      print('  2주차 결과: ${week2Result.score}점');
      expect(week2Result.score, greaterThan(60));
      
      // 3주차: 스케일 연습
      print('\n📅 3주차: 스케일 연습');
      trainingSystem.startTrainingSession(TrainingMode.scales, TrainingDifficulty.intermediate);
      
      final week3Sessions = _generateWeeklyProgressSessions(
        startScore: 65,
        endScore: 72,
        primaryImprovement: 'scales',
        sessionCount: 7,
      );
      
      for (final session in week3Sessions) {
        trainingSystem.addAnalysis(session);
      }
      
      final week3Result = trainingSystem.endTrainingSession();
      print('  3주차 결과: ${week3Result.score}점');
      expect(week3Result.score, greaterThan(65));
      
      // 4주차: 종합 연습
      print('\n📅 4주차: 종합 연습');
      trainingSystem.startTrainingSession(TrainingMode.freeStyle, TrainingDifficulty.intermediate);
      
      final week4Sessions = _generateWeeklyProgressSessions(
        startScore: 72,
        endScore: 78,
        primaryImprovement: 'overall',
        sessionCount: 7,
      );
      
      for (final session in week4Sessions) {
        trainingSystem.addAnalysis(session);
      }
      
      final week4Result = trainingSystem.endTrainingSession();
      print('  4주차 결과: ${week4Result.score}점');
      expect(week4Result.score, greaterThan(70));
      
      // 최종 레벨 평가
      final allSessions = [
        ...week1Sessions,
        ...week2Sessions,
        ...week3Sessions,
        ...week4Sessions,
      ];
      
      final finalLevel = ExpertEvaluationEngine.determineUserLevel(allSessions);
      print('\n🎯 최종 레벨: $finalLevel');
      expect(finalLevel, anyOf(equals('intermediate'), equals('advanced')));
      
      // 통계 검증
      final stats = trainingSystem.getTrainingStatistics();
      print('\n📊 최종 통계:');
      stats.forEach((mode, data) {
        print('  $mode: ${data}');
      });
      
      expect(stats.keys.length, greaterThanOrEqualTo(3)); // 최소 3개 모드 연습
    });

    test('Advanced User Skill Refinement - Specialized Training', () async {
      print('\n=== 고급자 스킬 정제 과정 시뮬레이션 ===');
      
      // 고급자 수준의 초기 분석
      final advancedBaselineSession = VocalAnalysis(
        timestamp: DateTime.now(),
        fundamentalFreq: [440.0],
        pitchStability: 0.85,
        breathingType: BreathingType.diaphragmatic,
        resonancePosition: ResonancePosition.mixed,
        vibratoQuality: VibratoQuality.light,
        mouthOpening: MouthOpening.medium,
        spectralTilt: 0.02,
        overallScore: 78,
      );
      
      final initialFeedback = feedbackEngine.generateSmartFeedback(advancedBaselineSession);
      print('초기 평가: ${initialFeedback.mainMessage}');
      expect(initialFeedback.priority, anyOf(
        equals(FeedbackPriority.medium),
        equals(FeedbackPriority.celebration),
      ));
      
      // 공명 연습 (고급 과정)
      print('\n🎭 공명 조절 전문 과정');
      trainingSystem.startTrainingSession(TrainingMode.resonance, TrainingDifficulty.advanced);
      
      final resonanceSessions = _generateAdvancedResonanceTraining();
      for (final session in resonanceSessions) {
        trainingSystem.addAnalysis(session);
        final feedback = feedbackEngine.generateSmartFeedback(session);
        print('  공명 위치: ${session.resonancePosition.name}, 점수: ${session.overallScore}');
      }
      
      final resonanceResult = trainingSystem.endTrainingSession();
      print('공명 훈련 결과: ${resonanceResult.score}점');
      expect(resonanceResult.score, greaterThan(75));
      
      // 표현력 연습 (전문가 과정)
      print('\n🎨 표현력 마스터 과정');
      trainingSystem.startTrainingSession(TrainingMode.expression, TrainingDifficulty.expert);
      
      final expressionSessions = _generateAdvancedExpressionTraining();
      for (final session in expressionSessions) {
        trainingSystem.addAnalysis(session);
        final feedback = feedbackEngine.generateSmartFeedback(session);
        print('  비브라토: ${session.vibratoQuality.name}, 표현 점수: ${session.overallScore}');
      }
      
      final expressionResult = trainingSystem.endTrainingSession();
      print('표현력 훈련 결과: ${expressionResult.score}점');
      expect(expressionResult.score, greaterThan(80));
      
      // 종합 평가
      final allAdvancedSessions = [...resonanceSessions, ...expressionSessions];
      final finalLevel = ExpertEvaluationEngine.determineUserLevel(allAdvancedSessions);
      print('\n🏆 최종 레벨: $finalLevel');
      expect(finalLevel, anyOf(equals('advanced'), equals('expert')));
    });

    test('Learning Algorithm Adaptation - Personalized Feedback Evolution', () async {
      print('\n=== AI 학습 알고리즘 적응 테스트 ===');
      
      // 개인화 학습 과정 시뮬레이션
      final userSessions = <VocalAnalysis>[];
      
      // 1단계: 초기 베이스라인 설정
      print('\n📊 베이스라인 설정 단계');
      for (int i = 0; i < 10; i++) {
        final session = VocalAnalysis(
          timestamp: DateTime.now().subtract(Duration(minutes: i * 5)),
          fundamentalFreq: [440.0 + (i * 0.5)], // 약간의 변동
          pitchStability: 0.6 + (i * 0.02), // 점진적 개선
          breathingType: BreathingType.mixed,
          resonancePosition: ResonancePosition.mouth,
          vibratoQuality: VibratoQuality.none,
          mouthOpening: MouthOpening.medium,
          spectralTilt: 0.08 - (i * 0.005),
          overallScore: 55 + i,
        );
        
        userSessions.add(session);
        final feedback = feedbackEngine.generateSmartFeedback(session);
        
        if (i == 0) {
          print('  초기 피드백: ${feedback.mainMessage}');
          expect(feedback.confidence, lessThan(0.8)); // 초기에는 낮은 신뢰도
        } else if (i == 9) {
          print('  베이스라인 완성 피드백: ${feedback.mainMessage}');
          expect(feedback.confidence, greaterThan(0.7)); // 데이터 누적 후 높은 신뢰도
        }
      }
      
      // 2단계: 개인화된 피드백 테스트
      print('\n🎯 개인화 피드백 단계');
      
      // 사용자가 특정 문제를 반복할 때
      final problemSession = VocalAnalysis(
        timestamp: DateTime.now(),
        fundamentalFreq: [445.0], // 베이스라인보다 높은 피치
        pitchStability: 0.5, // 베이스라인보다 낮은 안정성
        breathingType: BreathingType.chest, // 퇴보된 호흡
        resonancePosition: ResonancePosition.throat,
        vibratoQuality: VibratoQuality.none,
        mouthOpening: MouthOpening.narrow,
        spectralTilt: 0.1,
        overallScore: 45,
      );
      
      final personalizedFeedback = feedbackEngine.generateSmartFeedback(problemSession);
      print('  개인화된 피드백: ${personalizedFeedback.mainMessage}');
      print('  구체적 팁: ${personalizedFeedback.specificTips.join(", ")}');
      
      // 개인 베이스라인과 비교한 피드백이어야 함
      expect(personalizedFeedback.specificTips, isNotEmpty);
      expect(personalizedFeedback.priority, equals(FeedbackPriority.high));
      
      // 3단계: 향상 감지 및 축하 피드백
      print('\n🎉 향상 감지 단계');
      
      final improvedSession = VocalAnalysis(
        timestamp: DateTime.now(),
        fundamentalFreq: [440.0],
        pitchStability: 0.85, // 큰 향상
        breathingType: BreathingType.diaphragmatic, // 개선된 호흡
        resonancePosition: ResonancePosition.mixed,
        vibratoQuality: VibratoQuality.light,
        mouthOpening: MouthOpening.medium,
        spectralTilt: 0.02,
        overallScore: 82,
      );
      
      final improvementFeedback = feedbackEngine.generateSmartFeedback(improvedSession);
      print('  향상 감지 피드백: ${improvementFeedback.mainMessage}');
      print('  격려 메시지: ${improvementFeedback.encouragement}');
      
      expect(improvementFeedback.priority, anyOf(
        equals(FeedbackPriority.celebration),
        equals(FeedbackPriority.medium),
      ));
      expect(improvementFeedback.encouragement, isNotEmpty);
    });

    test('Multi-Modal Training Integration', () async {
      print('\n=== 다중 모드 통합 훈련 테스트 ===');
      
      // 동시 다중 기술 개발 시뮬레이션
      trainingSystem.startTrainingSession(TrainingMode.freeStyle, TrainingDifficulty.intermediate);
      
      final multiModalSessions = [
        // 호흡 + 음정 조합
        VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [440.0],
          pitchStability: 0.8,
          breathingType: BreathingType.diaphragmatic,
          resonancePosition: ResonancePosition.mixed,
          vibratoQuality: VibratoQuality.none,
          mouthOpening: MouthOpening.medium,
          spectralTilt: 0.03,
          overallScore: 75,
        ),
        // 공명 + 표현력 조합
        VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [523.25], // C5
          pitchStability: 0.78,
          breathingType: BreathingType.diaphragmatic,
          resonancePosition: ResonancePosition.head, // 고음에 적합한 공명
          vibratoQuality: VibratoQuality.light,
          mouthOpening: MouthOpening.wide,
          spectralTilt: 0.01,
          overallScore: 78,
        ),
        // 종합 기술 적용
        VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [330.0], // E4
          pitchStability: 0.82,
          breathingType: BreathingType.diaphragmatic,
          resonancePosition: ResonancePosition.mixed,
          vibratoQuality: VibratoQuality.medium,
          mouthOpening: MouthOpening.medium,
          spectralTilt: 0.0,
          overallScore: 84,
        ),
      ];
      
      for (int i = 0; i < multiModalSessions.length; i++) {
        final session = multiModalSessions[i];
        trainingSystem.addAnalysis(session);
        final feedback = feedbackEngine.generateSmartFeedback(session);
        
        print('  다중모드 세션 ${i + 1}: ${session.overallScore}점');
        print('    종합 피드백: ${feedback.mainMessage}');
        
        // 다중 기술이 종합적으로 평가되어야 함
        expect(session.overallScore, greaterThan(70));
      }
      
      final multiModalResult = trainingSystem.endTrainingSession();
      print('\n다중모드 훈련 결과: ${multiModalResult.score}점');
      print('성취사항: ${multiModalResult.achievements.join(", ")}');
      
      expect(multiModalResult.score, greaterThan(75));
      expect(multiModalResult.achievements, isNotEmpty);
    });

    test('Error Recovery and Adaptation Workflow', () async {
      print('\n=== 오류 복구 및 적응 워크플로우 테스트 ===');
      
      // 심각한 문제가 있는 세션
      final criticalErrorSession = VocalAnalysis(
        timestamp: DateTime.now(),
        fundamentalFreq: [380.0], // 매우 낮은 피치 (60 cents 편차)
        pitchStability: 0.2, // 매우 불안정
        breathingType: BreathingType.chest,
        resonancePosition: ResonancePosition.throat,
        vibratoQuality: VibratoQuality.heavy, // 과도한 비브라토
        mouthOpening: MouthOpening.narrow,
        spectralTilt: 0.25,
        overallScore: 15,
      );
      
      final criticalFeedback = feedbackEngine.generateSmartFeedback(criticalErrorSession);
      print('위험 감지: ${criticalFeedback.mainMessage}');
      print('긴급 조치: ${criticalFeedback.specificTips.join(", ")}');
      
      expect(criticalFeedback.priority, equals(FeedbackPriority.critical));
      expect(criticalFeedback.specificTips.length, greaterThanOrEqualTo(2));
      
      // 점진적 개선 과정
      print('\n📈 점진적 복구 과정');
      final recoverySessions = _generateRecoverySequence();
      
      for (int i = 0; i < recoverySessions.length; i++) {
        final session = recoverySessions[i];
        final feedback = feedbackEngine.generateSmartFeedback(session);
        
        print('  복구 ${i + 1}: 점수 ${session.overallScore} -> ${feedback.mainMessage}');
        
        if (i == 0) {
          expect(feedback.priority, anyOf(
            equals(FeedbackPriority.high),
            equals(FeedbackPriority.critical),
          ));
        } else if (i == recoverySessions.length - 1) {
          expect(feedback.priority, anyOf(
            equals(FeedbackPriority.medium),
            equals(FeedbackPriority.celebration),
          ));
        }
      }
      
      print('복구 완료: 정상 수준 달성');
    });

    tearDown(() {
      feedbackEngine.clearHistory();
    });
  });
}

/// 테스트 데이터 생성 헬퍼 함수들

List<VocalAnalysis> _generateWeeklyProgressSessions({
  required int startScore,
  required int endScore,
  required String primaryImprovement,
  required int sessionCount,
}) {
  return List.generate(sessionCount, (index) {
    final progress = index / (sessionCount - 1);
    final score = startScore + ((endScore - startScore) * progress);
    
    late BreathingType breathingType;
    late double pitchStability;
    late ResonancePosition resonancePosition;
    late VibratoQuality vibratoQuality;
    
    switch (primaryImprovement) {
      case 'breathing':
        breathingType = progress < 0.3 ? BreathingType.chest :
                      progress < 0.7 ? BreathingType.mixed :
                      BreathingType.diaphragmatic;
        pitchStability = 0.5 + (progress * 0.2);
        resonancePosition = ResonancePosition.throat;
        vibratoQuality = VibratoQuality.none;
        break;
      case 'pitch':
        breathingType = BreathingType.mixed;
        pitchStability = 0.4 + (progress * 0.4);
        resonancePosition = ResonancePosition.mouth;
        vibratoQuality = VibratoQuality.none;
        break;
      case 'scales':
        breathingType = BreathingType.diaphragmatic;
        pitchStability = 0.6 + (progress * 0.25);
        resonancePosition = ResonancePosition.mixed;
        vibratoQuality = VibratoQuality.none;
        break;
      default:
        breathingType = BreathingType.diaphragmatic;
        pitchStability = 0.65 + (progress * 0.2);
        resonancePosition = ResonancePosition.mixed;
        vibratoQuality = progress > 0.7 ? VibratoQuality.light : VibratoQuality.none;
    }
    
    return VocalAnalysis(
      timestamp: DateTime.now().subtract(Duration(days: sessionCount - index)),
      fundamentalFreq: [440.0 + (index % 3 - 1)], // 약간의 변동
      pitchStability: pitchStability,
      breathingType: breathingType,
      resonancePosition: resonancePosition,
      vibratoQuality: vibratoQuality,
      mouthOpening: MouthOpening.medium,
      spectralTilt: 0.1 - (progress * 0.08),
      overallScore: score.round(),
    );
  });
}

List<VocalAnalysis> _generateAdvancedResonanceTraining() {
  final resonancePositions = [
    ResonancePosition.throat,
    ResonancePosition.mouth,
    ResonancePosition.mixed,
    ResonancePosition.head,
  ];
  
  return List.generate(8, (index) {
    final resonance = resonancePositions[index % resonancePositions.length];
    final appropriateScore = resonance == ResonancePosition.mixed ? 85 : 78;
    
    return VocalAnalysis(
      timestamp: DateTime.now().subtract(Duration(minutes: index * 10)),
      fundamentalFreq: [440.0],
      pitchStability: 0.82,
      breathingType: BreathingType.diaphragmatic,
      resonancePosition: resonance,
      vibratoQuality: VibratoQuality.light,
      mouthOpening: MouthOpening.medium,
      spectralTilt: 0.02,
      overallScore: appropriateScore + (index % 3),
    );
  });
}

List<VocalAnalysis> _generateAdvancedExpressionTraining() {
  final vibratoQualities = [
    VibratoQuality.none,
    VibratoQuality.light,
    VibratoQuality.medium,
    VibratoQuality.heavy,
  ];
  
  return List.generate(8, (index) {
    final vibrato = vibratoQualities[index % vibratoQualities.length];
    final score = vibrato == VibratoQuality.medium ? 88 :
                  vibrato == VibratoQuality.light ? 85 :
                  vibrato == VibratoQuality.heavy ? 75 : 70;
    
    return VocalAnalysis(
      timestamp: DateTime.now().subtract(Duration(minutes: index * 15)),
      fundamentalFreq: [440.0],
      pitchStability: 0.85,
      breathingType: BreathingType.diaphragmatic,
      resonancePosition: ResonancePosition.mixed,
      vibratoQuality: vibrato,
      mouthOpening: MouthOpening.medium,
      spectralTilt: 0.01,
      overallScore: score + (index % 3),
    );
  });
}

List<VocalAnalysis> _generateRecoverySequence() {
  return List.generate(6, (index) {
    final recovery = index / 5.0;
    
    return VocalAnalysis(
      timestamp: DateTime.now().subtract(Duration(minutes: (5 - index) * 5)),
      fundamentalFreq: [400.0 + (recovery * 40)], // 400Hz에서 440Hz로 개선
      pitchStability: 0.2 + (recovery * 0.5), // 20%에서 70%로 개선
      breathingType: recovery < 0.3 ? BreathingType.chest :
                    recovery < 0.7 ? BreathingType.mixed :
                    BreathingType.diaphragmatic,
      resonancePosition: recovery < 0.5 ? ResonancePosition.throat : ResonancePosition.mixed,
      vibratoQuality: recovery > 0.8 ? VibratoQuality.light : VibratoQuality.none,
      mouthOpening: MouthOpening.medium,
      spectralTilt: 0.25 - (recovery * 0.2),
      overallScore: (15 + (recovery * 55)).round(), // 15점에서 70점으로 개선
    );
  });
}