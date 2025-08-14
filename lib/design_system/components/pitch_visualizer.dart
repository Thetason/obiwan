import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../tokens.dart';

/// Shadcn 스타일의 피치 시각화 컴포넌트
/// 
/// 보컬 트레이닝에 특화된 실시간 피치 표시 위젯
/// 미니멀하고 접근성이 뛰어난 shadcn 디자인 철학 적용
class PitchVisualizer extends StatefulWidget {
  final double currentPitch;        // 현재 피치 (Hz)
  final double targetPitch;         // 목표 피치 (Hz)
  final double confidence;          // 신뢰도 (0.0-1.0)
  final bool isActive;             // 활성 상태
  final double minPitch;           // 최소 피치 범위
  final double maxPitch;           // 최대 피치 범위
  final VoidCallback? onTap;       // 탭 이벤트
  
  const PitchVisualizer({
    super.key,
    required this.currentPitch,
    required this.targetPitch,
    this.confidence = 1.0,
    this.isActive = true,
    this.minPitch = 200.0,
    this.maxPitch = 800.0,
    this.onTap,
  });

  @override
  State<PitchVisualizer> createState() => _PitchVisualizerState();
}

class _PitchVisualizerState extends State<PitchVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isActive) {
      _animationController.repeat(reverse: true);
    }
  }
  
  @override
  void didUpdateWidget(PitchVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: DesignTokens.card,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          border: Border.all(
            color: DesignTokens.border,
            width: 1,
          ),
        ),
        child: CustomPaint(
          painter: _PitchVisualizerPainter(
            currentPitch: widget.currentPitch,
            targetPitch: widget.targetPitch,
            confidence: widget.confidence,
            minPitch: widget.minPitch,
            maxPitch: widget.maxPitch,
            isActive: widget.isActive,
            pulseScale: _pulseAnimation.value,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PitchVisualizerPainter extends CustomPainter {
  final double currentPitch;
  final double targetPitch;
  final double confidence;
  final double minPitch;
  final double maxPitch;
  final bool isActive;
  final double pulseScale;

  _PitchVisualizerPainter({
    required this.currentPitch,
    required this.targetPitch,
    required this.confidence,
    required this.minPitch,
    required this.maxPitch,
    required this.isActive,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // 배경 그리드 그리기
    _drawGrid(canvas, size);
    
    // 목표 피치 라인 그리기
    _drawTargetLine(canvas, size, centerY);
    
    // 현재 피치 표시
    if (currentPitch > 0 && isActive) {
      _drawCurrentPitch(canvas, size, centerX, centerY);
    }
    
    // 정확도 표시
    _drawAccuracyIndicator(canvas, size, centerX);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DesignTokens.border
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // 수평 그리드 라인 (피치 레벨)
    for (int i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(
        Offset(DesignTokens.space4, y),
        Offset(size.width - DesignTokens.space4, y),
        paint,
      );
    }
  }

  void _drawTargetLine(Canvas canvas, Size size, double centerY) {
    final targetY = _pitchToY(targetPitch, size);
    
    final paint = Paint()
      ..color = DesignTokens.pitchTarget
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 목표 피치 라인
    canvas.drawLine(
      Offset(DesignTokens.space4, targetY),
      Offset(size.width - DesignTokens.space4, targetY),
      paint,
    );
    
    // 목표 피치 범위 (±10Hz)
    final targetRangePaint = Paint()
      ..color = DesignTokens.muted
      ..style = PaintingStyle.fill;
      
    final rangeTop = _pitchToY(targetPitch + 10, size);
    final rangeBottom = _pitchToY(targetPitch - 10, size);
    
    canvas.drawRect(
      Rect.fromLTRB(
        DesignTokens.space4,
        rangeTop,
        size.width - DesignTokens.space4,
        rangeBottom,
      ),
      targetRangePaint,
    );
  }

  void _drawCurrentPitch(Canvas canvas, Size size, double centerX, double centerY) {
    final currentY = _pitchToY(currentPitch, size);
    final accuracy = _calculateAccuracy();
    final color = DesignTokens.pitchAccuracyColor(accuracy);
    
    // 현재 피치 점 그리기
    final dotPaint = Paint()
      ..color = DesignTokens.withConfidence(color, confidence)
      ..style = PaintingStyle.fill;
    
    final dotRadius = 8 * pulseScale * confidence;
    canvas.drawCircle(
      Offset(centerX, currentY),
      dotRadius,
      dotPaint,
    );
    
    // 현재 피치 라인 그리기
    final linePaint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(DesignTokens.space4, currentY),
      Offset(size.width - DesignTokens.space4, currentY),
      linePaint,
    );
    
    // 피치 값 텍스트 표시
    _drawPitchText(canvas, centerX + 20, currentY, '${currentPitch.toStringAsFixed(1)} Hz', color);
  }

  void _drawAccuracyIndicator(Canvas canvas, Size size, double centerX) {
    final accuracy = _calculateAccuracy();
    final color = DesignTokens.pitchAccuracyColor(accuracy);
    
    // 정확도 바 배경
    final barRect = Rect.fromLTWH(
      DesignTokens.space4,
      size.height - DesignTokens.space6 - 4,
      size.width - DesignTokens.space4 * 2,
      4,
    );
    
    final backgroundPaint = Paint()
      ..color = DesignTokens.muted
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(2)),
      backgroundPaint,
    );
    
    // 정확도 바 진행률
    final progressRect = Rect.fromLTWH(
      DesignTokens.space4,
      size.height - DesignTokens.space6 - 4,
      (size.width - DesignTokens.space4 * 2) * accuracy,
      4,
    );
    
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(progressRect, const Radius.circular(2)),
      progressPaint,
    );
    
    // 정확도 텍스트
    final accuracyText = '${(accuracy * 100).toStringAsFixed(0)}%';
    _drawPitchText(
      canvas,
      size.width - DesignTokens.space4 - 40,
      size.height - DesignTokens.space6 - 16,
      accuracyText,
      color,
    );
  }

  void _drawPitchText(Canvas canvas, double x, double y, String text, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: DesignTokens.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(canvas, Offset(x, y - textPainter.height / 2));
  }

  double _pitchToY(double pitch, Size size) {
    if (pitch <= 0) return size.height / 2;
    
    final normalizedPitch = (pitch.clamp(minPitch, maxPitch) - minPitch) / (maxPitch - minPitch);
    return size.height - (normalizedPitch * size.height * 0.8 + size.height * 0.1);
  }

  double _calculateAccuracy() {
    if (currentPitch <= 0) return 0.0;
    
    final diff = (currentPitch - targetPitch).abs();
    const maxDiff = 50.0; // 50Hz 이상 차이나면 0% 정확도
    
    return (1.0 - (diff / maxDiff)).clamp(0.0, 1.0);
  }

  @override
  bool shouldRepaint(_PitchVisualizerPainter oldDelegate) {
    return currentPitch != oldDelegate.currentPitch ||
           confidence != oldDelegate.confidence ||
           isActive != oldDelegate.isActive ||
           pulseScale != oldDelegate.pulseScale;
  }
}

/// 컴팩트한 피치 인디케이터
/// 
/// 작은 공간에서 피치 정확도를 표시하는 미니 컴포넌트
class CompactPitchIndicator extends StatelessWidget {
  final double accuracy;
  final bool isActive;
  final double size;

  const CompactPitchIndicator({
    super.key,
    required this.accuracy,
    this.isActive = true,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final color = DesignTokens.pitchAccuracyColor(accuracy);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? color : DesignTokens.muted,
        border: Border.all(
          color: DesignTokens.border,
          width: 1,
        ),
      ),
      child: isActive ? Icon(
        _getAccuracyIcon(),
        size: size * 0.6,
        color: Colors.white,
      ) : null,
    );
  }

  IconData _getAccuracyIcon() {
    if (accuracy >= 0.95) return Icons.check;
    if (accuracy >= 0.85) return Icons.trending_up;
    if (accuracy >= 0.70) return Icons.remove;
    return Icons.close;
  }
}

/// 사용 예시:
/// 
/// ```dart
/// // 메인 피치 시각화
/// PitchVisualizer(
///   currentPitch: 442.5,
///   targetPitch: 440.0,
///   confidence: 0.85,
///   isActive: true,
/// )
/// 
/// // 컴팩트 인디케이터
/// CompactPitchIndicator(
///   accuracy: 0.92,
///   isActive: true,
/// )
/// ```