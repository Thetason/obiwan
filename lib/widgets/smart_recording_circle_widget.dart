import 'package:flutter/material.dart';
import 'dart:math' as math;

enum RecordingState { idle, countdown, recording, processing }
enum VoiceQuality { excellent, good, fair, poor, tooQuiet, tooLoud }

class SmartRecordingCircleWidget extends StatefulWidget {
  final bool isRecording;
  final double audioLevel; // 0.0 to 1.0
  final double rmsValue; // RMS for quality analysis
  final VoidCallback? onTouchStart;
  final VoidCallback? onTouchEnd;
  final RecordingState recordingState;

  const SmartRecordingCircleWidget({
    super.key,
    required this.isRecording,
    required this.audioLevel,
    this.rmsValue = 0.0,
    this.onTouchStart,
    this.onTouchEnd,
    this.recordingState = RecordingState.idle,
  });

  @override
  State<SmartRecordingCircleWidget> createState() => _SmartRecordingCircleWidgetState();
}

class _SmartRecordingCircleWidgetState extends State<SmartRecordingCircleWidget>
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late AnimationController _breathingController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<double> _breathingAnimation;
  
  Duration recordingDuration = Duration.zero;
  VoiceQuality currentQuality = VoiceQuality.fair;
  String feedbackMessage = "터치하고 홀드하여 녹음하세요";

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startBreathingAnimation();
  }

  void _initializeAnimations() {
    // 부드러운 펄스 애니메이션 (대기 상태)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 리플 효과 (녹음 중)
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    // 호흡 가이드 애니메이션
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );
    _breathingAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
  }

  void _startBreathingAnimation() {
    if (!widget.isRecording) {
      _pulseController.repeat(reverse: true);
      _breathingController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SmartRecordingCircleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.stop();
        _breathingController.stop();
        _rippleController.repeat();
        _startRecordingTimer();
      } else {
        _rippleController.stop();
        _startBreathingAnimation();
        recordingDuration = Duration.zero;
      }
    }

    // 실시간 음성 품질 분석
    _analyzeVoiceQuality();
  }

  void _analyzeVoiceQuality() {
    if (!widget.isRecording) return;

    final level = widget.audioLevel;
    final rms = widget.rmsValue;

    if (level < 0.1) {
      currentQuality = VoiceQuality.tooQuiet;
      feedbackMessage = "조금 더 크게 불러주세요";
    } else if (level > 0.9) {
      currentQuality = VoiceQuality.tooLoud;
      feedbackMessage = "너무 큰 소리예요, 조금만 작게요";
    } else if (rms > 0.08 && level > 0.4) {
      currentQuality = VoiceQuality.excellent;
      feedbackMessage = "완벽한 톤으로 부르고 계시네요! 🎵";
    } else if (rms > 0.05 && level > 0.3) {
      currentQuality = VoiceQuality.good;
      feedbackMessage = "좋은 톤으로 부르고 계세요!";
    } else if (level > 0.2) {
      currentQuality = VoiceQuality.fair;
      feedbackMessage = "계속 불러주세요";
    } else {
      currentQuality = VoiceQuality.poor;
      feedbackMessage = "더 안정적으로 불러보세요";
    }

    setState(() {});
  }

  void _startRecordingTimer() {
    // 녹음 시간 추적
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (widget.isRecording && mounted) {
        setState(() {
          recordingDuration += const Duration(milliseconds: 100);
        });
        return true;
      }
      return false;
    });
  }

  Color _getQualityColor() {
    switch (currentQuality) {
      case VoiceQuality.excellent:
        return const Color(0xFF00D4AA); // Teal green
      case VoiceQuality.good:
        return const Color(0xFF0099FF); // Bright blue
      case VoiceQuality.fair:
        return const Color(0xFF6366F1); // Indigo
      case VoiceQuality.poor:
        return const Color(0xFFFF9500); // Orange
      case VoiceQuality.tooQuiet:
        return const Color(0xFFFF6B35); // Orange-red
      case VoiceQuality.tooLoud:
        return const Color(0xFFFF3B30); // Red
    }
  }

  double _getCircleSize() {
    if (!widget.isRecording) {
      return 180.0;
    }
    
    // 오디오 레벨에 따른 동적 크기 (120-220)
    final levelScale = 120.0 + (widget.audioLevel * 100.0);
    return levelScale.clamp(120.0, 220.0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 호흡 가이드 (녹음 전)
        if (!widget.isRecording)
          _buildBreathingGuide(),
        
        const SizedBox(height: 40),
        
        // 스마트 녹음 원
        _buildSmartCircle(),
        
        const SizedBox(height: 32),
        
        // 진도 바 & 시간
        if (widget.isRecording)
          _buildProgressBar(),
        
        const SizedBox(height: 24),
        
        // 실시간 피드백
        _buildFeedbackMessage(),
        
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildBreathingGuide() {
    return AnimatedBuilder(
      animation: _breathingAnimation,
      builder: (context, child) {
        return Container(
          width: 200,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(8, (index) {
              final delay = index * 0.1;
              final animValue = (_breathingAnimation.value + delay) % 2.0;
              final opacity = (math.sin(animValue * math.pi) * 0.5 + 0.5).clamp(0.2, 1.0);
              
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(opacity),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildSmartCircle() {
    return GestureDetector(
      onTapDown: (_) => widget.onTouchStart?.call(),
      onTapUp: (_) => widget.onTouchEnd?.call(),
      onTapCancel: () => widget.onTouchEnd?.call(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _rippleAnimation]),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // 외부 리플 효과 (녹음 중)
              if (widget.isRecording)
                ...List.generate(3, (index) {
                  final delay = index * 0.3;
                  final rippleValue = (_rippleAnimation.value - delay).clamp(0.0, 1.0);
                  
                  return Container(
                    width: _getCircleSize() + (rippleValue * 80),
                    height: _getCircleSize() + (rippleValue * 80),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getQualityColor().withOpacity(0.3 * (1 - rippleValue)),
                        width: 2,
                      ),
                    ),
                  );
                }),
              
              // 메인 원
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.isRecording 
                    ? _getCircleSize() 
                    : 180.0 * _pulseAnimation.value,
                height: widget.isRecording 
                    ? _getCircleSize() 
                    : 180.0 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _getQualityColor().withOpacity(0.8),
                      _getQualityColor().withOpacity(0.4),
                      _getQualityColor().withOpacity(0.1),
                    ],
                    stops: const [0.0, 0.7, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getQualityColor().withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: widget.isRecording ? 5 : 2,
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: widget.isRecording ? 48 : 40,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (recordingDuration.inMilliseconds / 15000.0).clamp(0.0, 1.0);
    final timeText = "${(recordingDuration.inMilliseconds / 1000).toStringAsFixed(1)}초";
    
    return Column(
      children: [
        Container(
          width: 280,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.white.withOpacity(0.2),
          ),
          child: Row(
            children: [
              Expanded(
                flex: (progress * 100).round(),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: _getQualityColor(),
                  ),
                ),
              ),
              Expanded(
                flex: ((1 - progress) * 100).round(),
                child: Container(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          timeText,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackMessage() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(feedbackMessage),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getQualityColor().withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          feedbackMessage,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _breathingController.dispose();
    super.dispose();
  }
}