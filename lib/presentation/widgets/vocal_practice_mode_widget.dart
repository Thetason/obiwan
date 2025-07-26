import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/vocal_analysis.dart';
import '../../features/training_modules/structured_vocal_training.dart';
import '../../features/ai_coaching/expert_knowledge_base.dart';
import '../../features/ai_coaching/smart_feedback_engine.dart';
import '../../core/theme/app_theme.dart';

/// 보컬 연습 모드 위젯
class VocalPracticeModeWidget extends ConsumerStatefulWidget {
  final bool isActive;
  final VocalAnalysis? currentAnalysis;
  final Function(TrainingMode) onModeChanged;
  final Function(TrainingDifficulty) onDifficultyChanged;

  const VocalPracticeModeWidget({
    super.key,
    required this.isActive,
    this.currentAnalysis,
    required this.onModeChanged,
    required this.onDifficultyChanged,
  });

  @override
  ConsumerState<VocalPracticeModeWidget> createState() => _VocalPracticeModeWidgetState();
}

class _VocalPracticeModeWidgetState extends ConsumerState<VocalPracticeModeWidget> {
  final StructuredVocalTraining _trainingSystem = StructuredVocalTraining();
  final SmartFeedbackEngine _feedbackEngine = SmartFeedbackEngine();
  
  TrainingMode _selectedMode = TrainingMode.breathing;
  TrainingDifficulty _selectedDifficulty = TrainingDifficulty.beginner;
  bool _isTrainingActive = false;
  TrainingSessionResult? _lastSessionResult;
  String _currentGuidance = '';

  @override
  void initState() {
    super.initState();
    _updateGuidance();
  }

  @override
  void didUpdateWidget(VocalPracticeModeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentAnalysis != null && _isTrainingActive) {
      _trainingSystem.addAnalysis(widget.currentAnalysis!);
      _updateGuidance();
    }
  }

  void _updateGuidance() {
    setState(() {
      _currentGuidance = _trainingSystem.getRealtimeGuidance(
        _selectedMode, 
        widget.currentAnalysis
      );
    });
  }

  void _startTrainingSession() {
    setState(() {
      _isTrainingActive = true;
      _lastSessionResult = null;
    });
    _trainingSystem.startTrainingSession(_selectedMode, _selectedDifficulty);
    _updateGuidance();
  }

  void _endTrainingSession() {
    if (_isTrainingActive) {
      final result = _trainingSystem.endTrainingSession();
      setState(() {
        _isTrainingActive = false;
        _lastSessionResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600,
      decoration: AppTheme.glassmorphismDecoration,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildModeSelector(),
            const SizedBox(height: 16),
            _buildDifficultySelector(),
            const SizedBox(height: 16),
            _buildTrainingControls(),
            const SizedBox(height: 16),
            Expanded(child: _buildContent()),
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
                '체계적 보컬 트레이닝',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '전문가 기준 맞춤형 연습',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (_isTrainingActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.successColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.successColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '연습 중',
                  style: TextStyle(
                    color: AppTheme.successColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '연습 모드',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TrainingMode.values.map((mode) {
            final isSelected = mode == _selectedMode;
            return GestureDetector(
              onTap: () {
                if (!_isTrainingActive) {
                  setState(() {
                    _selectedMode = mode;
                  });
                  widget.onModeChanged(mode);
                  _updateGuidance();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.primaryGradient : null,
                  color: !isSelected ? AppTheme.surfaceColor.withOpacity(0.5) : null,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : AppTheme.borderColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getModeIcon(mode),
                      size: 16,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getModeDisplayName(mode),
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDifficultySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '난이도',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: TrainingDifficulty.values.map((difficulty) {
            final isSelected = difficulty == _selectedDifficulty;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (!_isTrainingActive) {
                    setState(() {
                      _selectedDifficulty = difficulty;
                    });
                    widget.onDifficultyChanged(difficulty);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppTheme.accentGradient : null,
                    color: !isSelected ? AppTheme.surfaceColor.withOpacity(0.3) : null,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : AppTheme.borderColor,
                    ),
                  ),
                  child: Text(
                    _getDifficultyDisplayName(difficulty),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTrainingControls() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isTrainingActive ? _endTrainingSession : _startTrainingSession,
            icon: Icon(_isTrainingActive ? Icons.stop : Icons.play_arrow),
            label: Text(_isTrainingActive ? '연습 종료' : '연습 시작'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isTrainingActive ? AppTheme.errorColor : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Icon(
            Icons.info_outline,
            color: AppTheme.textSecondary,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_lastSessionResult != null) {
      return _buildSessionResult();
    } else if (_isTrainingActive) {
      return _buildActiveTraining();
    } else {
      return _buildTrainingInfo();
    }
  }

  Widget _buildActiveTraining() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withOpacity(0.1),
                AppTheme.accentColor.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '실시간 가이드',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _currentGuidance,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.currentAnalysis != null) _buildCurrentAnalysis(),
      ],
    );
  }

  Widget _buildCurrentAnalysis() {
    final analysis = widget.currentAnalysis!;
    final feedback = _feedbackEngine.generateSmartFeedback(analysis);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: AppTheme.accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'AI 분석 결과',
                style: TextStyle(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPriorityColor(feedback.priority).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(feedback.confidence * 100).toInt()}% 신뢰도',
                  style: TextStyle(
                    color: _getPriorityColor(feedback.priority),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            feedback.mainMessage,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...feedback.specificTips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildSessionResult() {
    final result = _lastSessionResult!;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.successColor.withOpacity(0.2),
                  AppTheme.primaryColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.celebration,
                  color: AppTheme.successColor,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  '연습 완료!',
                  style: TextStyle(
                    color: AppTheme.successColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '점수: ${result.score}/100',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          if (result.achievements.isNotEmpty) ...[
            Text(
              '🏆 성취',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...result.achievements.map((achievement) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
              ),
              child: Text(
                achievement,
                style: TextStyle(
                  color: AppTheme.warningColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )).toList(),
            const SizedBox(height: 16),
          ],
          
          Text(
            '💬 피드백',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Text(
              result.feedback,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _lastSessionResult = null;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('새 연습 시작'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingInfo() {
    final goals = _trainingSystem.getTrainingGoals(_selectedMode, _selectedDifficulty);
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '연습 목표',
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
              color: AppTheme.surfaceColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getModeDescription(_selectedMode),
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getModeDetailDescription(_selectedMode),
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                ...goals.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: AppTheme.successColor,
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
                )).toList(),
              ],
            ),
          ),
        ],
      ),
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

  String _getDifficultyDisplayName(TrainingDifficulty difficulty) {
    switch (difficulty) {
      case TrainingDifficulty.beginner: return '초급';
      case TrainingDifficulty.intermediate: return '중급';
      case TrainingDifficulty.advanced: return '고급';
      case TrainingDifficulty.expert: return '전문가';
    }
  }

  String _getModeDescription(TrainingMode mode) {
    switch (mode) {
      case TrainingMode.breathing: return '올바른 호흡법 연습';
      case TrainingMode.pitch: return '정확한 음정 연습';
      case TrainingMode.scales: return '음계 연습';
      case TrainingMode.resonance: return '공명 조절 연습';
      case TrainingMode.expression: return '감정 표현 연습';
      case TrainingMode.freeStyle: return '자유로운 발성 연습';
    }
  }

  String _getModeDetailDescription(TrainingMode mode) {
    switch (mode) {
      case TrainingMode.breathing: 
        return '복식호흡을 익히고 안정적인 발성을 위한 기초를 다집니다.';
      case TrainingMode.pitch: 
        return '정확한 음정을 유지하고 피치 안정성을 향상시킵니다.';
      case TrainingMode.scales: 
        return '도레미파솔 음계를 정확하고 일관되게 연주합니다.';
      case TrainingMode.resonance: 
        return '다양한 공명 위치를 활용하여 풍부한 음색을 만듭니다.';
      case TrainingMode.expression: 
        return '감정을 담은 표현력과 자연스러운 비브라토를 연습합니다.';
      case TrainingMode.freeStyle: 
        return '모든 기법을 종합하여 자유롭게 노래합니다.';
    }
  }

  Color _getPriorityColor(FeedbackPriority priority) {
    switch (priority) {
      case FeedbackPriority.critical: return AppTheme.errorColor;
      case FeedbackPriority.high: return AppTheme.warningColor;
      case FeedbackPriority.medium: return AppTheme.primaryColor;
      case FeedbackPriority.low: return AppTheme.textMuted;
      case FeedbackPriority.celebration: return AppTheme.successColor;
    }
  }
}