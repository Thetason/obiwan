import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_trainer_ai/domain/entities/vocal_analysis.dart';
import 'package:vocal_trainer_ai/features/ai_coaching/expert_knowledge_base.dart';
import 'package:vocal_trainer_ai/features/ai_coaching/smart_feedback_engine.dart';
import 'package:vocal_trainer_ai/features/training_modules/structured_vocal_training.dart';

/// 전문가 지식 기반 검증 테스트
/// 
/// 이 테스트들은 AI 시스템이 전문가 수준의 정확한 피드백을 제공하는지 검증합니다.
/// 실제 보컬 전문가들의 평가 기준을 바탕으로 작성되었습니다.
void main() {
  group('Expert Knowledge Base Validation', () {
    late SmartFeedbackEngine feedbackEngine;
    late StructuredVocalTraining trainingSystem;

    setUp(() {
      feedbackEngine = SmartFeedbackEngine();
      trainingSystem = StructuredVocalTraining();
    });

    group('Expert Test Cases', () {
      test('Perfect Pitch Test - Professional Level', () {
        // 완벽한 음정 테스트 (전문가 수준)
        final perfectAnalysis = VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [440.0], // 정확한 A4
          pitchStability: 0.98, // 98% 안정성
          breathingType: BreathingType.diaphragmatic,
          resonancePosition: ResonancePosition.mixed,
          vibratoQuality: VibratoQuality.medium,
          mouthOpening: MouthOpening.medium,
          spectralTilt: 0.0,
          overallScore: 95,
        );

        final score = ExpertEvaluationEngine.calculateExpertScore(perfectAnalysis);
        final feedback = feedbackEngine.generateSmartFeedback(perfectAnalysis);

        // 전문가 수준 점수 기대
        expect(score, greaterThanOrEqualTo(90));
        expect(feedback.priority, equals(FeedbackPriority.celebration));
        expect(feedback.mainMessage, contains('완벽'));
        expect(feedback.confidence, greaterThan(0.9));
      });

      test('Beginner Chest Breathing - Needs Improvement', () {
        // 초보자 흉식호흡 테스트
        final beginnerAnalysis = VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [435.0], // 약간 낮은 A4 (-20 cents)
          pitchStability: 0.65, // 65% 안정성
          breathingType: BreathingType.chest, // 흉식호흡
          resonancePosition: ResonancePosition.throat,
          vibratoQuality: VibratoQuality.none,
          mouthOpening: MouthOpening.narrow,
          spectralTilt: 0.1,
          overallScore: 45,
        );

        final score = ExpertEvaluationEngine.calculateExpertScore(beginnerAnalysis);
        final feedback = feedbackEngine.generateSmartFeedback(beginnerAnalysis);

        // 초보자 수준 점수 및 호흡법 개선 피드백 기대
        expect(score, lessThan(60));
        expect(feedback.category, equals(FeedbackCategory.breathing));
        expect(feedback.priority, equals(FeedbackPriority.high));
        expect(feedback.mainMessage, contains('호흡'));
        expect(feedback.specificTips, isNotEmpty);
      });

      test('Intermediate Mixed Breathing - Good Progress', () {
        // 중급자 혼합 호흡 테스트
        final intermediateAnalysis = VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [445.0], // 약간 높은 A4 (+20 cents)
          pitchStability: 0.78, // 78% 안정성
          breathingType: BreathingType.mixed, // 혼합 호흡
          resonancePosition: ResonancePosition.mixed,
          vibratoQuality: VibratoQuality.light,
          mouthOpening: MouthOpening.medium,
          spectralTilt: 0.05,
          overallScore: 72,
        );

        final score = ExpertEvaluationEngine.calculateExpertScore(intermediateAnalysis);
        final feedback = feedbackEngine.generateSmartFeedback(intermediateAnalysis);

        // 중급자 수준 점수 및 긍정적 피드백 기대
        expect(score, inInclusiveRange(60, 80));
        expect(feedback.priority, anyOf(
          equals(FeedbackPriority.medium),
          equals(FeedbackPriority.celebration),
        ));
        expect(feedback.encouragement, isNotEmpty);
      });
    });

    group('Pitch Accuracy Standards', () {
      test('Professional Pitch Tolerance', () {
        const professionalStandards = ExpertKnowledgeBase.pitchAccuracyStandards['professional']!;
        expect(professionalStandards['tolerance_cents'], equals(3.0));
        expect(professionalStandards['stability_min'], equals(0.95));
      });

      test('Pitch Deviation Detection', () {
        // 큰 음정 편차 테스트
        final badPitchAnalysis = VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [470.0], // A4에서 +115 cents 편차
          pitchStability: 0.3, // 30% 안정성
          breathingType: BreathingType.diaphragmatic,
          resonancePosition: ResonancePosition.mixed,
          vibratoQuality: VibratoQuality.none,
          mouthOpening: MouthOpening.medium,
          spectralTilt: 0.2,
          overallScore: 35,
        );

        final feedback = feedbackEngine.generateSmartFeedback(badPitchAnalysis);
        
        expect(feedback.category, equals(FeedbackCategory.pitch));
        expect(feedback.priority, equals(FeedbackPriority.high));
        expect(feedback.mainMessage, contains('불안정'));
      });
    });

    group('Breathing Technique Validation', () {
      test('Diaphragmatic Breathing Recognition', () {
        final breathingStandards = ExpertKnowledgeBase.breathingStandards[BreathingType.diaphragmatic]!;
        expect(breathingStandards['score'], equals(100));
        expect(breathingStandards['description'], equals('완벽한 복식호흡'));
      });

      test('Breathing Feedback Accuracy', () {
        final diaphragmaticAnalysis = VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [440.0],
          pitchStability: 0.85,
          breathingType: BreathingType.diaphragmatic,
          resonancePosition: ResonancePosition.mixed,
          vibratoQuality: VibratoQuality.light,
          mouthOpening: MouthOpening.medium,
          spectralTilt: 0.0,
          overallScore: 85,
        );

        final feedback = feedbackEngine.generateSmartFeedback(diaphragmaticAnalysis);
        
        // 복식호흡에 대한 긍정적 피드백 기대
        if (feedback.category == FeedbackCategory.breathing) {
          expect(feedback.priority, equals(FeedbackPriority.celebration));
          expect(feedback.mainMessage, contains('완벽'));
        }
      });
    });

    group('Resonance Position Analysis', () {
      test('Resonance Standards Validation', () {
        const headResonance = ExpertKnowledgeBase.resonanceStandards[ResonancePosition.head]!;
        expect(headResonance['optimal_range'], equals([350.0, 800.0]));
        expect(headResonance['score_weight'], equals(0.9));
        
        const throatResonance = ExpertKnowledgeBase.resonanceStandards[ResonancePosition.throat]!;
        expect(throatResonance['optimal_range'], equals([100.0, 300.0]));
        expect(throatResonance['score_weight'], equals(0.8));
      });

      test('Resonance Appropriateness for Pitch Range', () {
        // 고음역에서 두성 공명
        final highPitchAnalysis = VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [659.25], // E5
          pitchStability: 0.8,
          breathingType: BreathingType.diaphragmatic,
          resonancePosition: ResonancePosition.head, // 적절한 공명
          vibratoQuality: VibratoQuality.light,
          mouthOpening: MouthOpening.medium,
          spectralTilt: 0.0,
          overallScore: 80,
        );

        final score = ExpertEvaluationEngine.calculateExpertScore(highPitchAnalysis);
        expect(score, greaterThan(70)); // 적절한 공명 사용으로 좋은 점수
      });
    });

    group('Vibrato Quality Assessment', () {
      test('Vibrato Standards Validation', () {
        const lightVibrato = ExpertKnowledgeBase.vibratoStandards[VibratoQuality.light]!;
        expect(lightVibrato['score'], equals(85));
        expect(lightVibrato['frequency_range'], equals([4.5, 6.0]));
        
        const heavyVibrato = ExpertKnowledgeBase.vibratoStandards[VibratoQuality.heavy]!;
        expect(heavyVibrato['score'], equals(70)); // 과도한 비브라토는 낮은 점수
      });
    });

    group('Training Session Evaluation', () {
      test('Breathing Training Session', () {
        trainingSystem.startTrainingSession(TrainingMode.breathing, TrainingDifficulty.beginner);
        
        // 복식호흡 연습 세션 시뮬레이션
        final practiceAnalyses = [
          VocalAnalysis(
            timestamp: DateTime.now(),
            fundamentalFreq: [440.0],
            pitchStability: 0.7,
            breathingType: BreathingType.chest, // 처음엔 흉식
            resonancePosition: ResonancePosition.throat,
            vibratoQuality: VibratoQuality.none,
            mouthOpening: MouthOpening.medium,
            spectralTilt: 0.1,
            overallScore: 50,
          ),
          VocalAnalysis(
            timestamp: DateTime.now(),
            fundamentalFreq: [440.0],
            pitchStability: 0.75,
            breathingType: BreathingType.mixed, // 개선됨
            resonancePosition: ResonancePosition.mixed,
            vibratoQuality: VibratoQuality.none,
            mouthOpening: MouthOpening.medium,
            spectralTilt: 0.05,
            overallScore: 65,
          ),
          VocalAnalysis(
            timestamp: DateTime.now(),
            fundamentalFreq: [440.0],
            pitchStability: 0.8,
            breathingType: BreathingType.diaphragmatic, // 최종 달성
            resonancePosition: ResonancePosition.mixed,
            vibratoQuality: VibratoQuality.none,
            mouthOpening: MouthOpening.medium,
            spectralTilt: 0.0,
            overallScore: 80,
          ),
        ];

        for (final analysis in practiceAnalyses) {
          trainingSystem.addAnalysis(analysis);
        }

        final result = trainingSystem.endTrainingSession();
        
        expect(result.mode, equals(TrainingMode.breathing));
        expect(result.score, greaterThan(70)); // 개선된 점수
        expect(result.achievements, isNotEmpty); // 성취 달성
        expect(result.feedback, contains('호흡')); // 호흡 관련 피드백
      });

      test('Pitch Training Session', () {
        trainingSystem.startTrainingSession(TrainingMode.pitch, TrainingDifficulty.intermediate);
        
        // 음정 연습 세션 - 점진적 개선
        final pitchPracticeAnalyses = List.generate(10, (index) {
          final stability = 0.5 + (index * 0.05); // 점진적 안정성 향상
          return VocalAnalysis(
            timestamp: DateTime.now(),
            fundamentalFreq: [440.0],
            pitchStability: stability.clamp(0.0, 1.0),
            breathingType: BreathingType.diaphragmatic,
            resonancePosition: ResonancePosition.mixed,
            vibratoQuality: VibratoQuality.none,
            mouthOpening: MouthOpening.medium,
            spectralTilt: 0.0,
            overallScore: (50 + (index * 3)).clamp(0, 100),
          );
        });

        for (final analysis in pitchPracticeAnalyses) {
          trainingSystem.addAnalysis(analysis);
        }

        final result = trainingSystem.endTrainingSession();
        
        expect(result.mode, equals(TrainingMode.pitch));
        expect(result.metrics['improvement_trend'], greaterThan(0)); // 향상 추세
      });
    });

    group('User Level Determination', () {
      test('Expert Level Recognition', () {
        final expertAnalyses = List.generate(10, (index) => VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [440.0],
          pitchStability: 0.95 + (index * 0.005), // 95%+ 안정성
          breathingType: BreathingType.diaphragmatic,
          resonancePosition: ResonancePosition.mixed,
          vibratoQuality: VibratoQuality.medium,
          mouthOpening: MouthOpening.medium,
          spectralTilt: 0.0,
          overallScore: 90 + index, // 90+ 점수
        ));

        final userLevel = ExpertEvaluationEngine.determineUserLevel(expertAnalyses);
        expect(userLevel, equals('expert'));
      });

      test('Beginner Level Recognition', () {
        final beginnerAnalyses = List.generate(10, (index) => VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [430.0 + (index * 2)], // 불안정한 피치
          pitchStability: 0.4 + (index * 0.02), // 낮은 안정성
          breathingType: BreathingType.chest,
          resonancePosition: ResonancePosition.throat,
          vibratoQuality: VibratoQuality.none,
          mouthOpening: MouthOpening.narrow,
          spectralTilt: 0.15,
          overallScore: 30 + index, // 낮은 점수
        ));

        final userLevel = ExpertEvaluationEngine.determineUserLevel(beginnerAnalyses);
        expect(userLevel, equals('beginner'));
      });
    });

    group('AI Learning Weights Validation', () {
      test('Learning Weights Sum to 1.0', () {
        final weights = ExpertKnowledgeBase.aiLearningWeights;
        final totalWeight = weights.values.reduce((a, b) => a + b);
        expect(totalWeight, closeTo(1.0, 0.001));
      });

      test('Pitch Accuracy has Highest Weight', () {
        final weights = ExpertKnowledgeBase.aiLearningWeights;
        final pitchWeight = weights['pitch_accuracy']!;
        
        expect(pitchWeight, equals(0.35)); // 35% 가중치
        expect(pitchWeight, greaterThan(weights['breathing_technique']!));
        expect(pitchWeight, greaterThan(weights['resonance_control']!));
      });
    });

    group('Feedback Priority System', () {
      test('Critical Error Detection', () {
        final criticalErrorAnalysis = VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [400.0], // 40Hz 편차 (매우 큰 편차)
          pitchStability: 0.2, // 20% 안정성
          breathingType: BreathingType.chest,
          resonancePosition: ResonancePosition.throat,
          vibratoQuality: VibratoQuality.heavy, // 과도한 비브라토
          mouthOpening: MouthOpening.narrow,
          spectralTilt: 0.3,
          overallScore: 25,
        );

        final feedback = feedbackEngine.generateSmartFeedback(criticalErrorAnalysis);
        
        expect(feedback.priority, anyOf(
          equals(FeedbackPriority.critical),
          equals(FeedbackPriority.high),
        ));
        expect(feedback.specificTips.length, greaterThanOrEqualTo(2));
      });

      test('Celebration Feedback for Excellence', () {
        final excellentAnalysis = VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [440.0],
          pitchStability: 0.98,
          breathingType: BreathingType.diaphragmatic,
          resonancePosition: ResonancePosition.mixed,
          vibratoQuality: VibratoQuality.medium,
          mouthOpening: MouthOpening.medium,
          spectralTilt: 0.0,
          overallScore: 95,
        );

        final feedback = feedbackEngine.generateSmartFeedback(excellentAnalysis);
        
        expect(feedback.priority, equals(FeedbackPriority.celebration));
        expect(feedback.encouragement, contains('!'));
        expect(feedback.confidence, greaterThan(0.9));
      });
    });

    group('Genre-Specific Standards', () {
      test('Classical Genre Requirements', () {
        const classicalStandards = ExpertKnowledgeBase.genreStandards['classical']!;
        expect(classicalStandards['breathing'], equals(BreathingType.diaphragmatic));
        expect(classicalStandards['resonance'], equals(ResonancePosition.head));
        expect(classicalStandards['vibrato'], equals(VibratoQuality.medium));
        expect(classicalStandards['pitch_tolerance'], equals(3.0));
      });

      test('Jazz Genre Flexibility', () {
        const jazzStandards = ExpertKnowledgeBase.genreStandards['jazz']!;
        expect(jazzStandards['pitch_tolerance'], equals(15.0)); // 재즈는 의도적 변형 허용
        expect(jazzStandards['vibrato'], equals(VibratoQuality.light));
      });
    });

    tearDown(() {
      feedbackEngine.clearHistory();
    });
  });
}

/// 테스트 실행 도우미 함수들
class TestHelper {
  /// 특정 레벨의 분석 데이터 생성
  static VocalAnalysis generateAnalysisForLevel(String level) {
    switch (level) {
      case 'expert':
        return VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [440.0],
          pitchStability: 0.96,
          breathingType: BreathingType.diaphragmatic,
          resonancePosition: ResonancePosition.mixed,
          vibratoQuality: VibratoQuality.medium,
          mouthOpening: MouthOpening.medium,
          spectralTilt: 0.0,
          overallScore: 92,
        );
      case 'advanced':
        return VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [442.0],
          pitchStability: 0.87,
          breathingType: BreathingType.diaphragmatic,
          resonancePosition: ResonancePosition.mixed,
          vibratoQuality: VibratoQuality.light,
          mouthOpening: MouthOpening.medium,
          spectralTilt: 0.02,
          overallScore: 82,
        );
      case 'intermediate':
        return VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [445.0],
          pitchStability: 0.72,
          breathingType: BreathingType.mixed,
          resonancePosition: ResonancePosition.mouth,
          vibratoQuality: VibratoQuality.light,
          mouthOpening: MouthOpening.medium,
          spectralTilt: 0.05,
          overallScore: 68,
        );
      case 'beginner':
      default:
        return VocalAnalysis(
          timestamp: DateTime.now(),
          fundamentalFreq: [435.0],
          pitchStability: 0.55,
          breathingType: BreathingType.chest,
          resonancePosition: ResonancePosition.throat,
          vibratoQuality: VibratoQuality.none,
          mouthOpening: MouthOpening.narrow,
          spectralTilt: 0.12,
          overallScore: 48,
        );
    }
  }

  /// 진행도 시뮬레이션 데이터 생성
  static List<VocalAnalysis> generateProgressionData(int sessionCount) {
    return List.generate(sessionCount, (index) {
      final progress = index / sessionCount;
      final baseScore = 40 + (progress * 50); // 40에서 90으로 진행
      final stability = 0.4 + (progress * 0.5); // 40%에서 90%로 진행
      
      return VocalAnalysis(
        timestamp: DateTime.now().subtract(Duration(days: sessionCount - index)),
        fundamentalFreq: [440.0 - (10 * (1 - progress))], // 음정 점진적 개선
        pitchStability: stability,
        breathingType: progress > 0.3 ? BreathingType.mixed : BreathingType.chest,
        resonancePosition: progress > 0.6 ? ResonancePosition.mixed : ResonancePosition.throat,
        vibratoQuality: progress > 0.8 ? VibratoQuality.light : VibratoQuality.none,
        mouthOpening: MouthOpening.medium,
        spectralTilt: 0.1 * (1 - progress),
        overallScore: baseScore.round(),
      );
    });
  }
}