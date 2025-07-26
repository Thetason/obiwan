import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../features/training_modules/vocal_range_trainer.dart';

class VocalRangeTrainerWidget extends StatefulWidget {
  final VocalRangeTrainer trainer;
  final VocalRange? currentRange;
  final Function(double)? onPitchDetected;
  
  const VocalRangeTrainerWidget({
    Key? key,
    required this.trainer,
    this.currentRange,
    this.onPitchDetected,
  }) : super(key: key);
  
  @override
  State<VocalRangeTrainerWidget> createState() => _VocalRangeTrainerWidgetState();
}

class _VocalRangeTrainerWidgetState extends State<VocalRangeTrainerWidget>
    with TickerProviderStateMixin {
  StreamSubscription<RangeTrainingProgress>? _progressSubscription;
  RangeTrainingProgress? _currentProgress;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  
  // Training settings
  RangeTrainingGoal _selectedGoal = RangeTrainingGoal.extend;
  int _difficulty = 1;
  bool _isTraining = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _subscribeToProgress();
  }
  
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut,
    ));
  }
  
  void _subscribeToProgress() {
    _progressSubscription = widget.trainer.progressStream.listen((progress) {
      setState(() {
        _currentProgress = progress;
      });
      
      if (progress.status == TrainingStatus.inProgress && 
          progress.currentFeedback?.isOnTarget == true) {
        _pulseController.forward().then((_) => _pulseController.reverse());
      }
      
      if (progress.status == TrainingStatus.completed) {
        _progressController.forward();
        _isTraining = false;
      }
    });
  }
  
  @override
  void dispose() {
    _progressSubscription?.cancel();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.currentRange != null) _buildRangeDisplay(),
        const SizedBox(height: 16),
        _buildTrainingControls(),
        const SizedBox(height: 16),
        if (_isTraining && _currentProgress != null) ...[
          _buildTrainingProgress(),
          const SizedBox(height: 16),
          _buildExerciseDisplay(),
        ] else ...[
          _buildGoalSelection(),
          const SizedBox(height: 16),
          _buildDifficultySelection(),
        ],
        if (_currentProgress?.sessionSummary != null) ...[
          const SizedBox(height: 16),
          _buildSessionSummary(),
        ],
      ],
    );
  }
  
  Widget _buildRangeDisplay() {
    final range = widget.currentRange!;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '현재 음역',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRangeIndicator(
                    label: '최저음',
                    note: range.lowestNote,
                    color: Colors.blue,
                    icon: Icons.keyboard_arrow_down,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRangeIndicator(
                    label: '최고음',
                    note: range.highestNote,
                    color: Colors.red,
                    icon: Icons.keyboard_arrow_up,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRangeVisualizer(range),
            const SizedBox(height: 12),
            Text(
              '총 음역: ${range.totalSemitones} 반음 (${(range.totalSemitones / 12).toStringAsFixed(1)} 옥타브)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRangeIndicator({
    required String label,
    required String note,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRangeVisualizer(VocalRange range) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.grey[200],
      ),
      child: Stack(
        children: [
          // Total range background
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.3),
                  Colors.purple.withOpacity(0.3),
                  Colors.red.withOpacity(0.3),
                ],
              ),
            ),
          ),
          // Comfortable range indicator
          Positioned(
            left: 0.25 * MediaQuery.of(context).size.width * 0.8,
            right: 0.25 * MediaQuery.of(context).size.width * 0.8,
            top: 8,
            bottom: 8,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.green.withOpacity(0.6),
              ),
            ),
          ),
          // Labels
          Positioned.fill(
            child: Center(
              child: Text(
                '편안한 음역',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrainingControls() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isTraining ? _stopTraining : _startTraining,
            icon: Icon(_isTraining ? Icons.stop : Icons.play_arrow),
            label: Text(_isTraining ? '훈련 중지' : '훈련 시작'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: _isTraining ? Colors.red : Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildGoalSelection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '훈련 목표',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RangeTrainingGoal.values.map((goal) {
                final isSelected = _selectedGoal == goal;
                return ChoiceChip(
                  label: Text(_getGoalName(goal)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedGoal = goal;
                      });
                    }
                  },
                  selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? Theme.of(context).primaryColor : null,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              _getGoalDescription(_selectedGoal),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDifficultySelection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '난이도',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _difficulty.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _getDifficultyName(_difficulty),
                    onChanged: (value) {
                      setState(() {
                        _difficulty = value.round();
                      });
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getDifficultyColor(_difficulty).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getDifficultyName(_difficulty),
                    style: TextStyle(
                      color: _getDifficultyColor(_difficulty),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrainingProgress() {
    final progress = _currentProgress!;
    final completionRatio = progress.completedExercises / progress.session.exercises.length;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '진행 상황',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${progress.completedExercises}/${progress.session.exercises.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: completionRatio,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
              minHeight: 8,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildProgressMetric(
                    label: '정확도',
                    value: '${(progress.accuracy * 100).round()}%',
                    color: _getAccuracyColor(progress.accuracy),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildProgressMetric(
                    label: '목표',
                    value: _getGoalName(progress.session.goal),
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProgressMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExerciseDisplay() {
    final currentExercise = _currentProgress?.session.currentExercise;
    if (currentExercise == null) return const SizedBox.shrink();
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.1),
                    Theme.of(context).primaryColor.withOpacity(0.05),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    currentExercise.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentExercise.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _buildNoteDisplay(currentExercise),
                  const SizedBox(height: 20),
                  if (_currentProgress?.currentFeedback != null)
                    _buildFeedbackDisplay(_currentProgress!.currentFeedback!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _completeExercise,
                    child: const Text('다음 연습'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildNoteDisplay(RangeExercise exercise) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).primaryColor,
          width: 3,
        ),
        color: Theme.of(context).primaryColor.withOpacity(0.1),
      ),
      child: Column(
        children: [
          Text(
            exercise.startNote,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          if (exercise.startNote != exercise.endNote) ...[
            const SizedBox(height: 4),
            Icon(
              Icons.arrow_downward,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 4),
            Text(
              exercise.endNote,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildFeedbackDisplay(ExerciseFeedback feedback) {
    final color = feedback.isOnTarget ? Colors.green : Colors.orange;
    final icon = feedback.isOnTarget ? Icons.check_circle : Icons.adjust;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '${(feedback.accuracy * 100).round()}% 정확도',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSessionSummary() {
    final summary = _currentProgress!.sessionSummary!;
    
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _progressAnimation.value,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.withOpacity(0.1),
                    Colors.blue.withOpacity(0.1),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.celebration,
                    size: 48,
                    color: Colors.gold,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '훈련 완료!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryMetrics(summary),
                  const SizedBox(height: 16),
                  if (summary.achievements.isNotEmpty) ...[
                    _buildAchievements(summary.achievements),
                    const SizedBox(height: 16),
                  ],
                  _buildRecommendations(summary.recommendations),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildSummaryMetrics(SessionSummary summary) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryMetric(
            label: '정확도',
            value: '${(summary.accuracy * 100).round()}%',
            color: _getAccuracyColor(summary.accuracy),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryMetric(
            label: '완료율',
            value: '${(summary.completedExercises / summary.totalExercises * 100).round()}%',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryMetric(
            label: '시간',
            value: '${summary.duration.inMinutes}분',
            color: Colors.purple,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAchievements(List<String> achievements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '달성',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: achievements.map((achievement) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.gold.withOpacity(0.3)),
            ),
            child: Text(
              achievement,
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }
  
  Widget _buildRecommendations(List<String> recommendations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '개선 제안',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...recommendations.map((recommendation) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recommendation,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
  
  void _startTraining() async {
    if (widget.currentRange == null) return;
    
    setState(() {
      _isTraining = true;
    });
    
    await widget.trainer.startTrainingSession(
      currentRange: widget.currentRange!,
      goal: _selectedGoal,
      difficulty: _difficulty,
    );
  }
  
  void _stopTraining() {
    setState(() {
      _isTraining = false;
    });
    // In a real implementation, we would call a stop method on the trainer
  }
  
  void _completeExercise() {
    widget.trainer.completeCurrentExercise();
  }
  
  String _getGoalName(RangeTrainingGoal goal) {
    switch (goal) {
      case RangeTrainingGoal.extend:
        return '음역 확장';
      case RangeTrainingGoal.strengthen:
        return '음역 강화';
      case RangeTrainingGoal.smooth:
        return '연결 개선';
      case RangeTrainingGoal.balance:
        return '균형 조정';
    }
  }
  
  String _getGoalDescription(RangeTrainingGoal goal) {
    switch (goal) {
      case RangeTrainingGoal.extend:
        return '현재 음역을 점진적으로 확장합니다.';
      case RangeTrainingGoal.strengthen:
        return '기존 음역에서 안정성과 힘을 기릅니다.';
      case RangeTrainingGoal.smooth:
        return '음정 간의 부드러운 연결을 개선합니다.';
      case RangeTrainingGoal.balance:
        return '전체 음역에서 균등한 소리를 만듭니다.';
    }
  }
  
  String _getDifficultyName(int difficulty) {
    switch (difficulty) {
      case 1:
        return '초급';
      case 2:
        return '초중급';
      case 3:
        return '중급';
      case 4:
        return '중고급';
      case 5:
        return '고급';
      default:
        return '중급';
    }
  }
  
  Color _getDifficultyColor(int difficulty) {
    switch (difficulty) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.lightGreen;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.deepOrange;
      case 5:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
  
  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.8) return Colors.green;
    if (accuracy >= 0.6) return Colors.orange;
    return Colors.red;
  }
}