import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/pitch_colors.dart';

/// Force 테마 글로우 효과 (스타워즈 컨셉)
class ForceGlowEffect extends StatefulWidget {
  final bool isLightSide;  // true: 라이트사이드(파랑), false: 다크사이드(빨강)
  final double intensity;   // 0.0 ~ 1.0
  final Widget child;
  
  const ForceGlowEffect({
    Key? key,
    required this.isLightSide,
    this.intensity = 1.0,
    required this.child,
  }) : super(key: key);
  
  @override
  State<ForceGlowEffect> createState() => _ForceGlowEffectState();
}

class _ForceGlowEffectState extends State<ForceGlowEffect>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
    
    if (widget.intensity > 0) {
      _controller.repeat();
    }
  }
  
  @override
  void didUpdateWidget(ForceGlowEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.intensity > 0 && !_controller.isAnimating) {
      _controller.repeat();
    } else if (widget.intensity == 0 && _controller.isAnimating) {
      _controller.stop();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.intensity == 0) {
      return widget.child;
    }
    
    final glowColor = widget.isLightSide 
        ? PitchColors.forceLight 
        : PitchColors.forceDark;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // 배경 글로우 효과
            Transform.scale(
              scale: 1.2 * _pulseAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      glowColor.withOpacity(widget.intensity * 0.3 * _pulseAnimation.value),
                      glowColor.withOpacity(widget.intensity * 0.1 * _pulseAnimation.value),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            
            // 회전하는 파티클 효과
            Transform.rotate(
              angle: _rotationAnimation.value,
              child: CustomPaint(
                size: const Size(200, 200),
                painter: _ForceParticlePainter(
                  color: glowColor,
                  intensity: widget.intensity,
                  progress: _pulseAnimation.value,
                ),
              ),
            ),
            
            // 메인 콘텐츠
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withOpacity(widget.intensity * 0.6),
                    blurRadius: 20 * _pulseAnimation.value,
                    spreadRadius: 5 * _pulseAnimation.value,
                  ),
                ],
              ),
              child: widget.child,
            ),
          ],
        );
      },
    );
  }
}

// Force 파티클 페인터
class _ForceParticlePainter extends CustomPainter {
  final Color color;
  final double intensity;
  final double progress;
  
  _ForceParticlePainter({
    required this.color,
    required this.intensity,
    required this.progress,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withOpacity(intensity * 0.3 * progress)
      ..style = PaintingStyle.fill;
    
    // 파티클 그리기
    final random = math.Random(42); // 고정 시드로 일관성 유지
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      final distance = 40 + (20 * progress);
      final particleSize = 2 + (random.nextDouble() * 3);
      
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      
      canvas.drawCircle(
        Offset(x, y),
        particleSize,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(_ForceParticlePainter oldDelegate) {
    return progress != oldDelegate.progress || 
           intensity != oldDelegate.intensity;
  }
}

/// 라이트세이버 효과 위젯
class LightsaberEffect extends StatefulWidget {
  final Color color;
  final double width;
  final double height;
  final bool isActive;
  
  const LightsaberEffect({
    Key? key,
    required this.color,
    this.width = 4,
    this.height = 100,
    this.isActive = true,
  }) : super(key: key);
  
  @override
  State<LightsaberEffect> createState() => _LightsaberEffectState();
}

class _LightsaberEffectState extends State<LightsaberEffect>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _glowAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }
  
  @override
  void didUpdateWidget(LightsaberEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }
    
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.width / 2),
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.8 * _glowAnimation.value),
                blurRadius: 10 * _glowAnimation.value,
                spreadRadius: 2 * _glowAnimation.value,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.5 * _glowAnimation.value),
                blurRadius: 2,
                spreadRadius: 0,
              ),
            ],
          ),
        );
      },
    );
  }
}