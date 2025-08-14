import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../tokens/colors.dart';
import '../tokens/typography.dart';
import '../tokens/spacing.dart';
import '../tokens/animations.dart';

class VJProgressRing extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final List<Color>? gradient;
  final Color? backgroundColor;
  final Widget? child;
  final bool animate;
  final Duration? animationDuration;

  const VJProgressRing({
    Key? key,
    required this.progress,
    this.size = 120,
    this.strokeWidth = 8,
    this.gradient,
    this.backgroundColor,
    this.child,
    this.animate = true,
    this.animationDuration,
  }) : super(key: key);

  @override
  State<VJProgressRing> createState() => _VJProgressRingState();
}

class _VJProgressRingState extends State<VJProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  double _currentProgress = 0;

  @override
  void initState() {
    super.initState();
    _currentProgress = widget.animate ? 0 : widget.progress;
    
    _controller = AnimationController(
      duration: widget.animationDuration ?? VJAnimations.durationSlow,
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: VJAnimations.curveDefault,
    ));
    
    _progressAnimation.addListener(() {
      setState(() {
        _currentProgress = _progressAnimation.value;
      });
    });
    
    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(VJProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      if (widget.animate) {
        _progressAnimation = Tween<double>(
          begin: _currentProgress,
          end: widget.progress,
        ).animate(CurvedAnimation(
          parent: _controller,
          curve: VJAnimations.curveDefault,
        ));
        _controller.forward(from: 0);
      } else {
        setState(() {
          _currentProgress = widget.progress;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _ProgressRingPainter(
              progress: _currentProgress,
              strokeWidth: widget.strokeWidth,
              gradient: widget.gradient ?? [VJColors.primary, VJColors.secondary],
              backgroundColor: widget.backgroundColor ?? VJColors.gray100,
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final List<Color> gradient;
  final Color backgroundColor;

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.gradient,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    // Draw background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Draw progress arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepAngle = 2 * math.pi * progress;
    
    final progressPaint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    if (gradient.length > 1) {
      progressPaint.shader = SweepGradient(
        colors: gradient,
        startAngle: 0,
        endAngle: 2 * math.pi,
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);
    } else {
      progressPaint.color = gradient.first;
    }
    
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Convenience widget for displaying percentage
class VJProgressRingWithLabel extends StatelessWidget {
  final double progress;
  final double size;
  final String? label;
  final bool showPercentage;

  const VJProgressRingWithLabel({
    Key? key,
    required this.progress,
    this.size = 120,
    this.label,
    this.showPercentage = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return VJProgressRing(
      progress: progress,
      size: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPercentage)
            Text(
              '${(progress * 100).toInt()}%',
              style: VJTypography.headlineMedium.copyWith(
                color: VJColors.gray900,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (label != null) ...[
            SizedBox(height: VJSpacing.xxs),
            Text(
              label!,
              style: VJTypography.labelSmall.copyWith(
                color: VJColors.gray500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}