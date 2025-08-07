import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../utils/pitch_color_system.dart';

/// 🎨 고급 실시간 피치 시각화 위젯
/// 
/// 아름다운 곡선과 음계별 색상으로 실시간 피치를 시각화합니다.
class AdvancedPitchVisualizer extends StatefulWidget {
  final List<PitchData> pitchHistory;
  final PitchData? currentPitch;
  final bool isRecording;
  final double audioLevel;
  final VoidCallback? onTouchStart;
  final VoidCallback? onTouchEnd;

  const AdvancedPitchVisualizer({
    Key? key,
    this.pitchHistory = const [],
    this.currentPitch,
    this.isRecording = false,
    this.audioLevel = 0.0,
    this.onTouchStart,
    this.onTouchEnd,
  }) : super(key: key);

  @override
  State<AdvancedPitchVisualizer> createState() => _AdvancedPitchVisualizerState();
}

class _AdvancedPitchVisualizerState extends State<AdvancedPitchVisualizer>
    with TickerProviderStateMixin {
  
  // 애니메이션 컨트롤러들
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  
  // 애니메이션들
  late Animation<double> _waveAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _particleAnimation;
  
  // 파티클 시스템
  List<Particle> _particles = [];
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateParticles();
  }

  void _initializeAnimations() {
    // 웨이브 애니메이션
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.linear),
    );
    _waveController.repeat();

    // 펄스 애니메이션  
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // 파티클 애니메이션
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeOut),
    );
  }

  void _generateParticles() {
    _particles = List.generate(20, (index) {
      return Particle(
        x: math.Random().nextDouble(),
        y: math.Random().nextDouble(),
        size: math.Random().nextDouble() * 4 + 2,
        speed: math.Random().nextDouble() * 0.02 + 0.01,
        phase: math.Random().nextDouble() * 2 * math.pi,
      );
    });
  }

  @override
  void didUpdateWidget(AdvancedPitchVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 좋은 피치 감지 시 파티클 효과 트리거
    if (widget.currentPitch != null && 
        widget.currentPitch!.confidence > 0.8 &&
        widget.currentPitch!.cents.abs() <= 10) {
      _triggerParticleEffect();
    }
  }

  void _triggerParticleEffect() {
    _particleController.reset();
    _particleController.forward();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => widget.onTouchStart?.call(),
      onTapUp: (_) => widget.onTouchEnd?.call(),
      onTapCancel: () => widget.onTouchEnd?.call(),
      child: Container(
        width: 300,
        height: 300,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _waveAnimation,
            _pulseAnimation,
            _particleAnimation,
          ]),
          builder: (context, child) {
            return CustomPaint(
              size: const Size(300, 300),
              painter: AdvancedPitchPainter(
                pitchHistory: widget.pitchHistory,
                currentPitch: widget.currentPitch,
                isRecording: widget.isRecording,
                audioLevel: widget.audioLevel,
                wavePhase: _waveAnimation.value,
                pulseScale: _pulseAnimation.value,
                particleAnimation: _particleAnimation.value,
                particles: _particles,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 🎨 고급 피치 페인터
class AdvancedPitchPainter extends CustomPainter {
  final List<PitchData> pitchHistory;
  final PitchData? currentPitch;
  final bool isRecording;
  final double audioLevel;
  final double wavePhase;
  final double pulseScale;
  final double particleAnimation;
  final List<Particle> particles;

  AdvancedPitchPainter({
    required this.pitchHistory,
    this.currentPitch,
    required this.isRecording,
    required this.audioLevel,
    required this.wavePhase,
    required this.pulseScale,
    required this.particleAnimation,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    
    // 배경 그라디언트
    _drawBackground(canvas, size, center, radius);
    
    // 실시간 피치 히스토리 곡선
    _drawPitchHistoryCurve(canvas, size, center, radius);
    
    // 중앙 피치 표시
    _drawCurrentPitch(canvas, center, radius);
    
    // 오디오 레벨 웨이브
    _drawAudioWaves(canvas, center, radius);
    
    // 파티클 효과 (완벽한 피치일 때)
    _drawParticles(canvas, size, center);
    
    // 중앙 정보 영역
    _drawCenterInfo(canvas, center);
  }

  void _drawBackground(Canvas canvas, Size size, Offset center, double radius) {
    // 동적 배경 그라디언트
    final gradient = PitchColorSystem.createPitchGradient(pitchHistory);
    
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    
    // 부드러운 원형 배경
    canvas.drawCircle(center, radius, paint);
    
    // 글로우 효과
    if (isRecording) {
      final glowPaint = Paint()
        ..color = (currentPitch?.color ?? Colors.grey).withOpacity(0.3 * pulseScale)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 15);
      
      canvas.drawCircle(center, radius * pulseScale, glowPaint);
    }
  }

  void _drawPitchHistoryCurve(Canvas canvas, Size size, Offset center, double radius) {
    if (pitchHistory.length < 2) return;
    
    final path = Path();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    // 히스토리를 원형으로 배치
    for (int i = 0; i < pitchHistory.length; i++) {
      final pitch = pitchHistory[i];
      if (pitch.frequency <= 0) continue;
      
      // 각도 계산 (시계방향)
      final angle = (i / pitchHistory.length) * 2 * math.pi - math.pi / 2;
      
      // 주파수를 반지름으로 변환 (80Hz~800Hz → 30~radius)
      final pitchRadius = _mapFrequencyToRadius(pitch.frequency, radius);
      
      final x = center.dx + pitchRadius * math.cos(angle);
      final y = center.dy + pitchRadius * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      
      // 각 포인트별 색상으로 점 그리기
      paint.color = pitch.color;
      canvas.drawCircle(Offset(x, y), 2 + pitch.confidence * 2, paint);
    }
    
    // 부드러운 곡선 연결
    paint
      ..color = currentPitch?.color.withOpacity(0.7) ?? Colors.grey.withOpacity(0.7)
      ..strokeWidth = 2;
    canvas.drawPath(path, paint);
  }

  void _drawCurrentPitch(Canvas canvas, Offset center, double radius) {
    if (currentPitch == null) return;
    
    final pitchRadius = _mapFrequencyToRadius(currentPitch!.frequency, radius);
    final paint = Paint()
      ..color = currentPitch!.color
      ..style = PaintingStyle.fill;
    
    // 현재 피치를 큰 원으로 표시
    canvas.drawCircle(
      center,
      (8 + currentPitch!.confidence * 8) * pulseScale,
      paint,
    );
    
    // 음계별 링
    _drawNoteRing(canvas, center, pitchRadius);
  }

  void _drawNoteRing(Canvas canvas, Offset center, double pitchRadius) {
    if (currentPitch == null) return;
    
    final ringPaint = Paint()
      ..color = currentPitch!.color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawCircle(center, pitchRadius, ringPaint);
    
    // 음계 이름 표시
    _drawNoteText(canvas, center, currentPitch!.noteName, currentPitch!.octave);
  }

  void _drawNoteText(Canvas canvas, Offset center, String noteName, int octave) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$noteName$octave',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.5),
              offset: const Offset(1, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    final offset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );
    
    textPainter.paint(canvas, offset);
  }

  void _drawAudioWaves(Canvas canvas, Offset center, double radius) {
    if (!isRecording || audioLevel <= 0) return;
    
    final wavePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // 3개 웨이브 링
    for (int ring = 0; ring < 3; ring++) {
      final waveRadius = radius * 0.3 + ring * 15;
      final path = Path();
      
      for (double angle = 0; angle <= 2 * math.pi; angle += 0.1) {
        final waveOffset = audioLevel * 5 * math.sin(angle * 4 + wavePhase + ring * 0.5);
        final x = center.dx + (waveRadius + waveOffset) * math.cos(angle);
        final y = center.dy + (waveRadius + waveOffset) * math.sin(angle);
        
        if (angle == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      
      canvas.drawPath(path, wavePaint);
    }
  }

  void _drawParticles(Canvas canvas, Size size, Offset center) {
    if (particleAnimation <= 0) return;
    
    final paint = Paint()..style = PaintingStyle.fill;
    
    for (final particle in particles) {
      final progress = particleAnimation;
      final x = center.dx + (particle.x - 0.5) * size.width * progress;
      final y = center.dy + (particle.y - 0.5) * size.height * progress;
      
      // 파티클 색상 (무지개 효과)
      final hue = (particle.phase + progress * 360) % 360;
      paint.color = HSVColor.fromAHSV(
        1.0 - progress, // 점차 투명해짐
        hue,
        0.8,
        1.0,
      ).toColor();
      
      canvas.drawCircle(
        Offset(x, y),
        particle.size * (1.0 - progress * 0.5),
        paint,
      );
    }
  }

  void _drawCenterInfo(Canvas canvas, Offset center) {
    // 중앙 "Obi-wan" 텍스트
    final textPainter = TextPainter(
      text: TextSpan(
        text: isRecording ? '🎤' : 'Obi-wan',
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: isRecording ? 32 : 16,
          fontWeight: FontWeight.w300,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    final offset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );
    
    textPainter.paint(canvas, offset);
    
    // 터치 가이드
    if (!isRecording) {
      final guidePainter = TextPainter(
        text: TextSpan(
          text: '터치하고 홀드하세요',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      guidePainter.layout();
      final guideOffset = Offset(
        center.dx - guidePainter.width / 2,
        center.dy + 25,
      );
      
      guidePainter.paint(canvas, guideOffset);
    }
  }

  /// 주파수를 반지름으로 매핑 (80Hz~800Hz → 30~radius)
  double _mapFrequencyToRadius(double frequency, double maxRadius) {
    if (frequency <= 0) return 30;
    
    // 로그 스케일로 매핑 (인간의 음감은 로그적)
    final minFreq = 80.0;
    final maxFreq = 800.0;
    final minRadius = 30.0;
    
    final logFreq = math.log(frequency.clamp(minFreq, maxFreq));
    final logMin = math.log(minFreq);
    final logMax = math.log(maxFreq);
    
    final ratio = (logFreq - logMin) / (logMax - logMin);
    return minRadius + ratio * (maxRadius - minRadius);
  }

  @override
  bool shouldRepaint(AdvancedPitchPainter oldDelegate) {
    return oldDelegate.pitchHistory != pitchHistory ||
           oldDelegate.currentPitch != currentPitch ||
           oldDelegate.isRecording != isRecording ||
           oldDelegate.audioLevel != audioLevel ||
           oldDelegate.wavePhase != wavePhase ||
           oldDelegate.pulseScale != pulseScale ||
           oldDelegate.particleAnimation != particleAnimation;
  }
}

/// 🌟 파티클 모델
class Particle {
  final double x;        // 0.0 ~ 1.0
  final double y;        // 0.0 ~ 1.0  
  final double size;     // 픽셀
  final double speed;    // 애니메이션 속도
  final double phase;    // 색상 위상

  const Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
  });
}