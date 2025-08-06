import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/analysis_result.dart';

class SmartFeedbackSystem extends StatefulWidget {
  final DualResult? analysisResult;
  final double targetPitch;
  final bool isActive;
  final Color primaryColor;
  final Color secondaryColor;

  const SmartFeedbackSystem({
    super.key,
    this.analysisResult,
    required this.targetPitch,
    required this.isActive,
    this.primaryColor = const Color(0xFF6366F1),
    this.secondaryColor = const Color(0xFF8B5CF6),
  });

  @override
  State<SmartFeedbackSystem> createState() => _SmartFeedbackSystemState();
}

class _SmartFeedbackSystemState extends State<SmartFeedbackSystem>
    with TickerProviderStateMixin {
  late AnimationController _feedbackController;
  late AnimationController _pulseController;
  late Animation<double> _feedbackAnimation;
  late Animation<double> _pulseAnimation;

  FeedbackType _currentFeedback = FeedbackType.waiting;
  String _feedbackMessage = "음성을 입력해주세요";
  IconData _feedbackIcon = Icons.mic_none;
  Color _feedbackColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    
    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _feedbackAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _feedbackController, curve: Curves.elasticOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(SmartFeedbackSystem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.analysisResult != oldWidget.analysisResult) {
      _updateFeedback();
    }
  }

  void _updateFeedback() {
    final result = widget.analysisResult;
    if (result == null || !widget.isActive) {
      _setFeedback(FeedbackType.waiting, "음성을 입력해주세요", Icons.mic_none, Colors.grey);
      return;
    }

    if (result.frequency <= 0) {
      _setFeedback(FeedbackType.noSignal, "소리가 감지되지 않아요", Icons.hearing_disabled, Colors.orange);
      return;
    }

    if (result.isChord) {
      _setFeedback(
        FeedbackType.chord,
        "화음 감지! ${result.detectedPitches.length}개 음성",
        Icons.queue_music,
        const Color(0xFF8B5CF6)
      );
      return;
    }

    // 단일 음성 피드백
    final cents = _calculateCents(result.frequency, widget.targetPitch);
    final absCents = cents.abs();
    
    if (absCents < 5) {
      _setFeedback(FeedbackType.perfect, "완벽해요! 🎯", Icons.star, const Color(0xFF10B981));
      _startSuccessAnimation();
    } else if (absCents < 15) {
      if (cents > 0) {
        _setFeedback(FeedbackType.slightlyHigh, "조금 높아요 ⬇️", Icons.keyboard_arrow_down, const Color(0xFFF59E0B));
      } else {
        _setFeedback(FeedbackType.slightlyLow, "조금 낮아요 ⬆️", Icons.keyboard_arrow_up, const Color(0xFFF59E0B));
      }
    } else if (absCents < 30) {
      if (cents > 0) {
        _setFeedback(FeedbackType.tooHigh, "높아요 🔻", Icons.expand_less, const Color(0xFFEF4444));
      } else {
        _setFeedback(FeedbackType.tooLow, "낮아요 🔺", Icons.expand_more, const Color(0xFFEF4444));
      }
    } else {
      if (cents > 0) {
        _setFeedback(FeedbackType.wayTooHigh, "너무 높아요! 🔻", Icons.keyboard_double_arrow_down, const Color(0xFFDC2626));
      } else {
        _setFeedback(FeedbackType.wayTooLow, "너무 낮아요! 🔺", Icons.keyboard_double_arrow_up, const Color(0xFFDC2626));
      }
    }
  }

  void _setFeedback(FeedbackType type, String message, IconData icon, Color color) {
    if (_currentFeedback != type) {
      setState(() {
        _currentFeedback = type;
        _feedbackMessage = message;
        _feedbackIcon = icon;
        _feedbackColor = color;
      });
      
      _feedbackController.reset();
      _feedbackController.forward();
      
      if (type == FeedbackType.perfect) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  void _startSuccessAnimation() {
    _pulseController.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _pulseController.stop();
        _pulseController.reset();
      }
    });
  }

  double _calculateCents(double frequency, double targetFreq) {
    return 1200 * math.log(frequency / targetFreq) / math.log(2);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_feedbackAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _currentFeedback == FeedbackType.perfect 
            ? _pulseAnimation.value 
            : _feedbackAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _feedbackColor.withOpacity(0.2),
                  _feedbackColor.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _feedbackColor.withOpacity(0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _feedbackColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFeedbackIcon(),
                const SizedBox(height: 16),
                _buildFeedbackMessage(),
                const SizedBox(height: 12),
                _buildDetailedInfo(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedbackIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_feedbackColor, _feedbackColor.withOpacity(0.7)],
        ),
        boxShadow: [
          BoxShadow(
            color: _feedbackColor.withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Icon(
        _feedbackIcon,
        color: Colors.white,
        size: 40,
      ),
    );
  }

  Widget _buildFeedbackMessage() {
    return Text(
      _feedbackMessage,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: _feedbackColor,
        shadows: [
          Shadow(
            color: _feedbackColor.withOpacity(0.5),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedInfo() {
    final result = widget.analysisResult;
    if (result == null || result.frequency <= 0) {
      return const SizedBox.shrink();
    }

    final cents = _calculateCents(result.frequency, widget.targetPitch);
    
    return Column(
      children: [
        Text(
          "${result.frequency.toStringAsFixed(1)} Hz",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        if (!result.isChord && result.frequency > 0) ...[
          const SizedBox(height: 4),
          Text(
            "${cents.toStringAsFixed(1)} cents ${cents > 0 ? '높음' : '낮음'}",
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
        const SizedBox(height: 8),
        _buildConfidenceBar(result.confidence),
      ],
    );
  }

  Widget _buildConfidenceBar(double confidence) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "신뢰도",
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            Text(
              "${(confidence * 100).toStringAsFixed(0)}%",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: confidence > 0.8 
                  ? const Color(0xFF10B981)
                  : confidence > 0.5
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: Colors.white.withOpacity(0.2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: confidence,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: [
                    confidence > 0.8 
                      ? const Color(0xFF10B981)
                      : confidence > 0.5
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444),
                    (confidence > 0.8 
                      ? const Color(0xFF10B981)
                      : confidence > 0.5
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444)).withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}

enum FeedbackType {
  waiting,
  noSignal,
  perfect,
  slightlyHigh,
  slightlyLow,
  tooHigh,
  tooLow,
  wayTooHigh,
  wayTooLow,
  chord,
}

class VoiceCoachFeedback extends StatefulWidget {
  final DualResult? analysisResult;
  final bool isActive;
  final List<String> personalizedTips;

  const VoiceCoachFeedback({
    super.key,
    this.analysisResult,
    required this.isActive,
    this.personalizedTips = const [],
  });

  @override
  State<VoiceCoachFeedback> createState() => _VoiceCoachFeedbackState();
}

class _VoiceCoachFeedbackState extends State<VoiceCoachFeedback>
    with SingleTickerProviderStateMixin {
  late AnimationController _tipController;
  late Animation<double> _tipAnimation;
  
  int _currentTipIndex = 0;
  final List<String> _defaultTips = [
    "복식호흡을 사용해보세요",
    "턱과 목의 힘을 빼세요",
    "입을 충분히 벌려주세요",
    "공명강을 활용해보세요",
    "정확한 발음을 의식하세요",
  ];

  @override
  void initState() {
    super.initState();
    
    _tipController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _tipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tipController, curve: Curves.easeOut),
    );
    
    _startTipRotation();
  }

  void _startTipRotation() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _nextTip();
        _startTipRotation();
      }
    });
  }

  void _nextTip() {
    setState(() {
      _currentTipIndex = (_currentTipIndex + 1) % _getTips().length;
    });
    _tipController.reset();
    _tipController.forward();
  }

  List<String> _getTips() {
    return widget.personalizedTips.isNotEmpty 
      ? widget.personalizedTips 
      : _defaultTips;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _tipAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _tipAnimation.value)),
          child: Opacity(
            opacity: _tipAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getTips()[_currentTipIndex],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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

  @override
  void dispose() {
    _tipController.dispose();
    super.dispose();
  }
}