import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';

/// Interactive breathing coaching widget with visual guidance
class BreathingCoachingWidget extends StatefulWidget {
  final BreathingExerciseType exerciseType;
  final Duration inhaleTime;
  final Duration holdTime;
  final Duration exhaleTime;
  final int cycles;
  final bool autoStart;
  final VoidCallback? onExerciseComplete;
  final Function(BreathingPhase)? onPhaseChange;
  final bool showInstructions;
  
  const BreathingCoachingWidget({
    super.key,
    this.exerciseType = BreathingExerciseType.box,
    this.inhaleTime = const Duration(seconds: 4),
    this.holdTime = const Duration(seconds: 4),
    this.exhaleTime = const Duration(seconds: 4),
    this.cycles = 5,
    this.autoStart = false,
    this.onExerciseComplete,
    this.onPhaseChange,
    this.showInstructions = true,
  });

  @override
  State<BreathingCoachingWidget> createState() => _BreathingCoachingWidgetState();
}

class _BreathingCoachingWidgetState extends State<BreathingCoachingWidget>
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _progressController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _progressAnimation;
  
  BreathingPhase _currentPhase = BreathingPhase.ready;
  int _currentCycle = 0;
  bool _isActive = false;
  bool _isPaused = false;
  
  @override
  void initState() {
    super.initState();
    
    _breathingController = AnimationController(
      vsync: this,
    );
    
    _progressController = AnimationController(
      vsync: this,
    );
    
    _breathingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.linear,
    ));
    
    _breathingController.addStatusListener(_handleBreathingStatus);
    _progressController.addStatusListener(_handleProgressStatus);
    
    if (widget.autoStart) {
      _startExercise();
    }
  }

  void _handleBreathingStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _isActive) {
      _nextPhase();
    }
  }

  void _handleProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _isActive) {
      _currentCycle++;
      if (_currentCycle >= widget.cycles) {
        _completeExercise();
      } else {
        _progressController.reset();
        _startCycle();
      }
    }
  }

  void _startExercise() {
    setState(() {
      _isActive = true;
      _currentCycle = 0;
      _currentPhase = BreathingPhase.inhale;
    });
    
    _startCycle();
  }

  void _startCycle() {
    _progressController.forward();
    _startPhase(BreathingPhase.inhale);
  }

  void _startPhase(BreathingPhase phase) {
    setState(() => _currentPhase = phase);
    widget.onPhaseChange?.call(phase);
    
    Duration phaseDuration;
    switch (phase) {
      case BreathingPhase.inhale:
        phaseDuration = widget.inhaleTime;
        break;
      case BreathingPhase.hold:
        phaseDuration = widget.holdTime;
        break;
      case BreathingPhase.exhale:
        phaseDuration = widget.exhaleTime;
        break;
      case BreathingPhase.ready:
        return;
    }
    
    _breathingController.duration = phaseDuration;
    _breathingController.reset();
    _breathingController.forward();
  }

  void _nextPhase() {
    switch (_currentPhase) {
      case BreathingPhase.inhale:
        if (widget.exerciseType == BreathingExerciseType.box ||
            widget.exerciseType == BreathingExerciseType.triangle) {
          _startPhase(BreathingPhase.hold);
        } else {
          _startPhase(BreathingPhase.exhale);
        }
        break;
      case BreathingPhase.hold:
        _startPhase(BreathingPhase.exhale);
        break;
      case BreathingPhase.exhale:
        if (widget.exerciseType == BreathingExerciseType.triangle) {
          _startPhase(BreathingPhase.hold);
        } else {
          // Cycle complete, wait for progress controller
        }
        break;
      case BreathingPhase.ready:
        break;
    }
  }

  void _pauseExercise() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _breathingController.stop();
      _progressController.stop();
    } else {
      _breathingController.forward();
      _progressController.forward();
    }
  }

  void _stopExercise() {
    setState(() {
      _isActive = false;
      _isPaused = false;
      _currentPhase = BreathingPhase.ready;
      _currentCycle = 0;
    });
    
    _breathingController.stop();
    _progressController.stop();
    _breathingController.reset();
    _progressController.reset();
  }

  void _completeExercise() {
    _stopExercise();
    widget.onExerciseComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        // Exercise info
        if (widget.showInstructions)
          _buildInstructions(theme),
        
        const SizedBox(height: AppSpacing.xl),
        
        // Main breathing circle
        _buildBreathingCircle(theme),
        
        const SizedBox(height: AppSpacing.xl),
        
        // Progress and controls
        _buildProgressSection(theme),
        
        const SizedBox(height: AppSpacing.lg),
        
        // Control buttons
        _buildControlButtons(theme),
      ],
    );
  }

  Widget _buildInstructions(ThemeData theme) {
    final exerciseInfo = _getExerciseInfo();
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                exerciseInfo['icon'],
                color: exerciseInfo['color'],
                size: 28,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseInfo['name'],
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      exerciseInfo['description'],
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeInfo('들숨', widget.inhaleTime, AppTheme.customColors.breathingInhale),
              if (widget.holdTime.inSeconds > 0)
                _buildTimeInfo('멈춤', widget.holdTime, AppTheme.customColors.breathingHold),
              _buildTimeInfo('날숨', widget.exhaleTime, AppTheme.customColors.breathingExhale),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String label, Duration duration, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            label == '들숨' ? Icons.arrow_upward : 
            label == '멈춤' ? Icons.pause : Icons.arrow_downward,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          '${duration.inSeconds}초',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildBreathingCircle(ThemeData theme) {
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surface,
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
                width: 2,
              ),
            ),
          ),
          
          // Animated breathing circle
          AnimatedBuilder(
            animation: _breathingAnimation,
            builder: (context, child) {
              final scale = _getBreathingScale();
              final color = _getPhaseColor();
              
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withOpacity(0.3),
                        color.withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: color,
                      width: 3,
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Center content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: AppAnimations.medium,
                child: Icon(
                  _getPhaseIcon(),
                  key: ValueKey(_currentPhase),
                  size: 48,
                  color: _getPhaseColor(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AnimatedSwitcher(
                duration: AppAnimations.medium,
                child: Text(
                  _getPhaseText(),
                  key: ValueKey(_currentPhase),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _getPhaseColor(),
                  ),
                ),
              ),
              if (_isActive) ...[
                const SizedBox(height: AppSpacing.sm),
                AnimatedBuilder(
                  animation: _breathingAnimation,
                  builder: (context, child) {
                    final remaining = _getRemainingTime();
                    return Text(
                      '${remaining.inSeconds + 1}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '사이클 진행률',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_currentCycle + (_isActive ? 1 : 0)}/${widget.cycles}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            final totalProgress = (_currentCycle + _progressAnimation.value) / widget.cycles;
            return LinearProgressIndicator(
              value: totalProgress,
              backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              minHeight: 8,
            );
          },
        ),
      ],
    );
  }

  Widget _buildControlButtons(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (!_isActive)
          ElevatedButton.icon(
            onPressed: _startExercise,
            icon: const Icon(Icons.play_arrow),
            label: const Text('시작'),
          )
        else ...[
          ElevatedButton.icon(
            onPressed: _pauseExercise,
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            label: Text(_isPaused ? '재개' : '일시정지'),
          ),
          OutlinedButton.icon(
            onPressed: _stopExercise,
            icon: const Icon(Icons.stop),
            label: const Text('중지'),
          ),
        ],
      ],
    );
  }

  double _getBreathingScale() {
    switch (_currentPhase) {
      case BreathingPhase.inhale:
        return 0.8 + 0.4 * _breathingAnimation.value;
      case BreathingPhase.hold:
        return 1.2;
      case BreathingPhase.exhale:
        return 1.2 - 0.4 * _breathingAnimation.value;
      case BreathingPhase.ready:
        return 1.0;
    }
  }

  Color _getPhaseColor() {
    switch (_currentPhase) {
      case BreathingPhase.inhale:
        return AppTheme.customColors.breathingInhale;
      case BreathingPhase.hold:
        return AppTheme.customColors.breathingHold;
      case BreathingPhase.exhale:
        return AppTheme.customColors.breathingExhale;
      case BreathingPhase.ready:
        return Theme.of(context).colorScheme.outline;
    }
  }

  IconData _getPhaseIcon() {
    switch (_currentPhase) {
      case BreathingPhase.inhale:
        return Icons.keyboard_arrow_up;
      case BreathingPhase.hold:
        return Icons.pause;
      case BreathingPhase.exhale:
        return Icons.keyboard_arrow_down;
      case BreathingPhase.ready:
        return Icons.self_improvement;
    }
  }

  String _getPhaseText() {
    switch (_currentPhase) {
      case BreathingPhase.inhale:
        return '들숨';
      case BreathingPhase.hold:
        return '멈춤';
      case BreathingPhase.exhale:
        return '날숨';
      case BreathingPhase.ready:
        return '준비';
    }
  }

  Map<String, dynamic> _getExerciseInfo() {
    switch (widget.exerciseType) {
      case BreathingExerciseType.box:
        return {
          'name': '박스 호흡법',
          'description': '4-4-4-4 리듬으로 스트레스 완화',
          'icon': Icons.crop_square,
          'color': AppTheme.customColors.breathingInhale,
        };
      case BreathingExerciseType.triangle:
        return {
          'name': '삼각 호흡법',
          'description': '3단계 호흡으로 집중력 향상',
          'icon': Icons.change_history,
          'color': AppTheme.customColors.breathingExhale,
        };
      case BreathingExerciseType.fourSevenEight:
        return {
          'name': '4-7-8 호흡법',
          'description': '이완과 수면 유도에 효과적',
          'icon': Icons.bedtime,
          'color': AppTheme.customColors.breathingHold,
        };
    }
  }

  Duration _getRemainingTime() {
    Duration phaseDuration;
    switch (_currentPhase) {
      case BreathingPhase.inhale:
        phaseDuration = widget.inhaleTime;
        break;
      case BreathingPhase.hold:
        phaseDuration = widget.holdTime;
        break;
      case BreathingPhase.exhale:
        phaseDuration = widget.exhaleTime;
        break;
      case BreathingPhase.ready:
        return Duration.zero;
    }
    
    final elapsed = (1.0 - _breathingAnimation.value) * phaseDuration.inMilliseconds;
    return Duration(milliseconds: elapsed.round());
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _progressController.dispose();
    super.dispose();
  }
}

/// Breathing exercise types
enum BreathingExerciseType {
  box,         // 4-4-4-4
  triangle,    // 4-4-4
  fourSevenEight, // 4-7-8
}

/// Breathing phases
enum BreathingPhase {
  ready,
  inhale,
  hold,
  exhale,
}