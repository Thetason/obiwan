import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/pitch_colors.dart';

/// 성공/실패 시 표시되는 애니메이션 오버레이
class SuccessAnimationOverlay extends StatefulWidget {
  final bool isSuccess;
  final VoidCallback? onComplete;
  
  const SuccessAnimationOverlay({
    Key? key,
    required this.isSuccess,
    this.onComplete,
  }) : super(key: key);
  
  @override
  State<SuccessAnimationOverlay> createState() => _SuccessAnimationOverlayState();
}

class _SuccessAnimationOverlayState extends State<SuccessAnimationOverlay>
    with TickerProviderStateMixin {
  
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _particleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  final List<_Particle> _particles = [];
  
  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    // 파티클 생성 (성공 시)
    if (widget.isSuccess) {
      _createParticles();
    }
    
    _startAnimation();
  }
  
  void _createParticles() {
    final random = math.Random();
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        angle: random.nextDouble() * 2 * math.pi,
        speed: 100 + random.nextDouble() * 200,
        size: 4 + random.nextDouble() * 8,
        color: [
          PitchColors.perfect,
          PitchColors.glowSuccess,
          PitchColors.forceLight,
        ][random.nextInt(3)],
      ));
    }
  }
  
  void _startAnimation() async {
    await _scaleController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _fadeController.forward();
    
    if (widget.isSuccess) {
      _particleController.forward();
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    widget.onComplete?.call();
  }
  
  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _particleController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // 메인 아이콘 애니메이션
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isSuccess 
                              ? PitchColors.perfect.withOpacity(0.2)
                              : PitchColors.off.withOpacity(0.2),
                          border: Border.all(
                            color: widget.isSuccess 
                                ? PitchColors.perfect
                                : PitchColors.off,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          widget.isSuccess 
                              ? Icons.check_rounded
                              : Icons.close_rounded,
                          size: 60,
                          color: widget.isSuccess 
                              ? PitchColors.perfect
                              : PitchColors.off,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // 파티클 효과 (성공 시)
            if (widget.isSuccess)
              AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  return CustomPaint(
                    size: size,
                    painter: _ParticlePainter(
                      particles: _particles,
                      progress: _particleController.value,
                      center: Offset(size.width / 2, size.height / 2),
                    ),
                  );
                },
              ),
            
            // 텍스트 메시지
            Positioned(
              bottom: size.height * 0.3,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Text(
                      widget.isSuccess ? 'Perfect!' : 'Try Again',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.isSuccess 
                            ? PitchColors.perfect
                            : PitchColors.off,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: (widget.isSuccess 
                                ? PitchColors.perfect
                                : PitchColors.off).withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 파티클 데이터 클래스
class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  
  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
}

// 파티클 페인터
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Offset center;
  
  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.center,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final distance = particle.speed * progress;
      final x = center.dx + math.cos(particle.angle) * distance;
      final y = center.dy + math.sin(particle.angle) * distance;
      
      final opacity = math.max(0, 1 - progress);
      final paint = Paint()
        ..color = particle.color.withOpacity(opacity * 0.8)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(x, y),
        particle.size * (1 - progress * 0.5),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}