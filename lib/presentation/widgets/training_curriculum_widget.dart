import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/vocal_analysis.dart';
import '../../features/training_modules/structured_vocal_training.dart';
import '../../features/ai_coaching/expert_knowledge_base.dart';
import '../../core/theme/app_theme.dart';

/// 훈련 단계 정보
class TrainingStage {
  final String id;
  final String title;
  final String description;
  final int durationWeeks;
  final List<String> goals;
  final Map<String, dynamic> successCriteria;
  final List<TrainingMode> includedModes;
  final String icon;
  
  const TrainingStage({
    required this.id,
    required this.title,
    required this.description,
    required this.durationWeeks,
    required this.goals,
    required this.successCriteria,
    required this.includedModes,
    required this.icon,
  });
}

/// 단계별 트레이닝 커리큘럼 위젯
class TrainingCurriculumWidget extends ConsumerStatefulWidget {
  final String currentUserLevel;
  final List<VocalAnalysis> userHistory;
  final Function(TrainingStage, TrainingMode) onStageSelected;

  const TrainingCurriculumWidget({
    super.key,
    required this.currentUserLevel,
    required this.userHistory,
    required this.onStageSelected,
  });

  @override
  ConsumerState<TrainingCurriculumWidget> createState() => _TrainingCurriculumWidgetState();
}

class _TrainingCurriculumWidgetState extends ConsumerState<TrainingCurriculumWidget> {
  int _currentStageIndex = 0;
  bool _showDetailedView = false;

  // 전문가 지식 기반 훈련 단계 정의
  static const List<TrainingStage> _trainingStages = [
    TrainingStage(
      id: 'stage_1_breathing',
      title: '1단계: 기초 호흡법',
      description: '모든 보컬 테크닉의 기초인 올바른 호흡법을 익힙니다.',
      durationWeeks: 2,
      goals: [
        '복식호흡 완전 습득',
        '15초 이상 안정적 발성',
        '호흡 일관성 확보',
      ],
      successCriteria: {
        'breathing_type': 'diaphragmatic',
        'stability_duration': 15.0,
        'consistency_score': 0.8,
      },
      includedModes: [TrainingMode.breathing],
      icon: '💨',
    ),
    TrainingStage(
      id: 'stage_2_pitch',
      title: '2단계: 음정 정확도',
      description: '정확한 피치 컨트롤과 음정 안정성을 개발합니다.',
      durationWeeks: 3,
      goals: [
        '±15 cent 이내 음정 정확도',
        '70% 이상 피치 안정성',
        '기본 스케일 완주',
      ],
      successCriteria: {
        'pitch_tolerance': 15.0,
        'pitch_stability': 0.70,
        'scale_completion': true,
      },
      includedModes: [TrainingMode.pitch, TrainingMode.scales],
      icon: '🎵',
    ),
    TrainingStage(
      id: 'stage_3_resonance',
      title: '3단계: 공명과 음색',
      description: '다양한 공명 위치를 활용하여 풍부한 음색을 개발합니다.',
      durationWeeks: 4,
      goals: [
        '3가지 이상 공명 위치 활용',
        '포먼트 의식적 조절',
        '음역대별 적절한 공명 사용',
      ],
      successCriteria: {
        'resonance_variety': 3,
        'formant_control': 0.7,
        'appropriateness_score': 0.8,
      },
      includedModes: [TrainingMode.resonance],
      icon: '🎭',
    ),
    TrainingStage(
      id: 'stage_4_expression',
      title: '4단계: 표현과 비브라토',
      description: '감정 표현과 자연스러운 비브라토 기법을 익힙니다.',
      durationWeeks: 4,
      goals: [
        '자연스러운 비브라토',
        '감정 표현 기법',
        '다이나믹 레인지 조절',
      ],
      successCriteria: {
        'vibrato_quality': 'light_to_medium',
        'expression_score': 80,
        'dynamic_range': 0.3,
      },
      includedModes: [TrainingMode.expression],
      icon: '🎭',
    ),
    TrainingStage(
      id: 'stage_5_integration',
      title: '5단계: 종합 응용',
      description: '모든 기법을 통합하여 완성도 높은 보컬 실력을 완성합니다.',
      durationWeeks: 6,
      goals: [
        '모든 기법 통합 활용',
        '일관된 고품질 퍼포먼스',
        '개인적 스타일 개발',
      ],
      successCriteria: {
        'overall_score': 85,
        'consistency': 0.9,
        'style_development': true,
      },
      includedModes: [TrainingMode.freeStyle, TrainingMode.expression],
      icon: '🎤',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _determineCurrentStage();
  }

  void _determineCurrentStage() {
    // 사용자 레벨과 히스토리를 바탕으로 현재 단계 결정
    switch (widget.currentUserLevel) {
      case 'beginner':
        _currentStageIndex = 0;
        break;
      case 'intermediate':
        _currentStageIndex = 1;
        break;
      case 'advanced':
        _currentStageIndex = 2;
        break;
      case 'expert':
        _currentStageIndex = 4;
        break;
      default:
        _currentStageIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassmorphismDecoration,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildProgressIndicator(),
            const SizedBox(height: 20),
            Expanded(
              child: _showDetailedView 
                  ? _buildDetailedStageView()
                  : _buildStageOverview(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.school,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '단계별 트레이닝 커리큘럼',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '전문가 검증 학습 과정',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _showDetailedView = !_showDetailedView;
            });
          },
          icon: Icon(
            _showDetailedView ? Icons.view_list : Icons.view_module,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '전체 진행도',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_currentStageIndex + 1}/${_trainingStages.length} 단계',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStageIndex + 1) / _trainingStages.length,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStageOverview() {
    return ListView.builder(
      itemCount: _trainingStages.length,
      itemBuilder: (context, index) {
        final stage = _trainingStages[index];
        final isCompleted = index < _currentStageIndex;
        final isCurrent = index == _currentStageIndex;
        final isLocked = index > _currentStageIndex;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: isCurrent 
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.2),
                      AppTheme.accentColor.withOpacity(0.1),
                    ],
                  )
                : null,
            color: !isCurrent ? AppTheme.surfaceColor.withOpacity(0.3) : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrent 
                  ? AppTheme.primaryColor.withOpacity(0.5)
                  : AppTheme.borderColor,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: isCompleted 
                    ? AppTheme.successGradient
                    : isCurrent
                        ? AppTheme.primaryGradient
                        : null,
                color: isLocked ? AppTheme.textMuted.withOpacity(0.3) : null,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 24)
                    : isLocked
                        ? const Icon(Icons.lock, color: Colors.white, size: 20)
                        : Text(
                            stage.icon,
                            style: const TextStyle(fontSize: 24),
                          ),
              ),
            ),
            title: Text(
              stage.title,
              style: TextStyle(
                color: isLocked ? AppTheme.textMuted : AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  stage.description,
                  style: TextStyle(
                    color: isLocked ? AppTheme.textMuted : AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 12,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${stage.durationWeeks}주 과정',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.flag,
                      size: 12,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${stage.goals.length}개 목표',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: !isLocked
                ? Icon(
                    Icons.arrow_forward_ios,
                    color: AppTheme.textMuted,
                    size: 16,
                  )
                : null,
            onTap: !isLocked
                ? () {
                    widget.onStageSelected(stage, stage.includedModes.first);
                  }
                : null,
          ),
        );
      },
    );
  }

  Widget _buildDetailedStageView() {
    final currentStage = _trainingStages[_currentStageIndex];
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Stage Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      currentStage.icon,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentStage.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            currentStage.description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStageInfo('기간', '${currentStage.durationWeeks}주'),
                    const SizedBox(width: 20),
                    _buildStageInfo('목표', '${currentStage.goals.length}개'),
                    const SizedBox(width: 20),
                    _buildStageInfo('모드', '${currentStage.includedModes.length}개'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Learning Goals
          Text(
            '🎯 학습 목표',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...currentStage.goals.map((goal) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: AppTheme.successColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    goal,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
          const SizedBox(height: 20),
          
          // Training Modes
          Text(
            '🎵 연습 모드',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: currentStage.includedModes.map((mode) => GestureDetector(
              onTap: () {
                widget.onStageSelected(currentStage, mode);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getModeIcon(mode),
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getModeDisplayName(mode),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),
          
          // Success Criteria
          Text(
            '✅ 성공 기준',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: currentStage.successCriteria.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.analytics,
                        color: AppTheme.warningColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.key}: ${entry.value}',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageInfo(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  IconData _getModeIcon(TrainingMode mode) {
    switch (mode) {
      case TrainingMode.breathing: return Icons.air;
      case TrainingMode.pitch: return Icons.music_note;
      case TrainingMode.scales: return Icons.piano;
      case TrainingMode.resonance: return Icons.graphic_eq;
      case TrainingMode.expression: return Icons.emoji_emotions;
      case TrainingMode.freeStyle: return Icons.mic;
    }
  }

  String _getModeDisplayName(TrainingMode mode) {
    switch (mode) {
      case TrainingMode.breathing: return '호흡법';
      case TrainingMode.pitch: return '음정';
      case TrainingMode.scales: return '스케일';
      case TrainingMode.resonance: return '공명';
      case TrainingMode.expression: return '표현력';
      case TrainingMode.freeStyle: return '자유연습';
    }
  }
}