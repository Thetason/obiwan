import 'package:flutter/material.dart';
import 'dart:math' as math;

class RippleVisualization extends StatefulWidget {
  final double audioLevel;
  final bool isRecording;
  final Color primaryColor;
  final Color secondaryColor;

  const RippleVisualization({
    super.key,
    required this.audioLevel,
    required this.isRecording,
    this.primaryColor = const Color(0xFF6366F1),
    this.secondaryColor = const Color(0xFF8B5CF6),
  });

  @override
  State<RippleVisualization> createState() => _RippleVisualizationState();
}

class _RippleVisualizationState extends State<RippleVisualization>
    with TickerProviderStateMixin {
  late List<AnimationController> _rippleControllers;
  late List<Animation<double>> _rippleAnimations;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // 다중 리플 효과를 위한 컨트롤러들
    _rippleControllers = List.generate(
      5,
      (index) => AnimationController(
        duration: Duration(milliseconds: 1500 + (index * 200)),
        vsync: this,
      ),
    );

    _rippleAnimations = _rippleControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
    }).toList();

    // 중앙 마이크 아이콘 펄스 효과
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(RippleVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isRecording && !oldWidget.isRecording) {
      _startRipples();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _stopRipples();
    }

    // 음성 레벨에 따른 펄스 효과
    if (widget.audioLevel > 0.1 && widget.isRecording) {
      _pulseController.forward().then((_) => _pulseController.reverse());
    }
  }

  void _startRipples() {
    for (int i = 0; i < _rippleControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted && widget.isRecording) {
          _rippleControllers[i].repeat();
        }
      });
    }
  }

  void _stopRipples() {
    for (var controller in _rippleControllers) {
      controller.stop();
      controller.reset();
    }
    _pulseController.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 배경 리플 효과들
          ...List.generate(_rippleControllers.length, (index) {
            return AnimatedBuilder(
              animation: _rippleAnimations[index],
              builder: (context, child) {
                final double scale = _rippleAnimations[index].value *
                    (1.0 + widget.audioLevel * 0.5);
                final double opacity = (1.0 - _rippleAnimations[index].value) *
                    (widget.isRecording ? 1.0 : 0.0) *
                    (0.6 + widget.audioLevel * 0.4);

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 200 + (index * 20),
                    height: 200 + (index * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.primaryColor.withOpacity(opacity * 0.3),
                        width: 2 + widget.audioLevel * 3,
                      ),
                      gradient: RadialGradient(
                        colors: [
                          widget.primaryColor.withOpacity(opacity * 0.1),
                          widget.secondaryColor.withOpacity(opacity * 0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // 중앙 마이크 아이콘과 레벨 표시
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value * (1.0 + widget.audioLevel * 0.3),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.primaryColor.withOpacity(0.9),
                        widget.secondaryColor.withOpacity(0.9),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.primaryColor.withOpacity(0.3),
                        blurRadius: 20 + widget.audioLevel * 10,
                        spreadRadius: 5 + widget.audioLevel * 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.isRecording ? Icons.mic : Icons.mic_off,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              );
            },
          ),

          // 음성 레벨 표시 바
          if (widget.isRecording)
            Positioned(
              bottom: 20,
              child: AudioLevelBar(
                level: widget.audioLevel,
                color: widget.primaryColor,
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _rippleControllers) {
      controller.dispose();
    }
    _pulseController.dispose();
    super.dispose();
  }
}

class AudioLevelBar extends StatelessWidget {
  final double level;
  final Color color;

  const AudioLevelBar({
    super.key,
    required this.level,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: color.withOpacity(0.2),
      ),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 200 * level,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.6),
                  color,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}