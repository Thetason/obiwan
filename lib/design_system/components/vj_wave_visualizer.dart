import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/animations.dart';

enum WaveStyle {
  bars,
  line,
  dots,
  smooth,
}

class VJWaveVisualizer extends StatefulWidget {
  final List<double> audioData;
  final WaveStyle style;
  final Color? color;
  final List<Color>? gradient;
  final double height;
  final bool animate;
  final bool isPlaying;
  final double? playbackPosition; // 0.0 to 1.0

  const VJWaveVisualizer({
    Key? key,
    required this.audioData,
    this.style = WaveStyle.bars,
    this.color,
    this.gradient,
    this.height = 100,
    this.animate = true,
    this.isPlaying = false,
    this.playbackPosition,
  }) : super(key: key);

  @override
  State<VJWaveVisualizer> createState() => _VJWaveVisualizerState();
}

class _VJWaveVisualizerState extends State<VJWaveVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _playbackController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: VJAnimations.durationVerySlow,
      vsync: this,
    );
    
    _playbackController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    if (widget.animate && widget.isPlaying) {
      _animationController.repeat();
      _playbackController.repeat();
    }
  }

  @override
  void didUpdateWidget(VJWaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _animationController.repeat();
      _playbackController.repeat();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _animationController.stop();
      _playbackController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _playbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      child: AnimatedBuilder(
        animation: Listenable.merge([_animationController, _playbackController]),
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: _WaveformPainter(
              audioData: widget.audioData,
              style: widget.style,
              color: widget.color ?? VJColors.primary,
              gradient: widget.gradient,
              animationValue: _animationController.value,
              playbackPosition: widget.playbackPosition,
              isPlaying: widget.isPlaying,
            ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> audioData;
  final WaveStyle style;
  final Color color;
  final List<Color>? gradient;
  final double animationValue;
  final double? playbackPosition;
  final bool isPlaying;

  _WaveformPainter({
    required this.audioData,
    required this.style,
    required this.color,
    this.gradient,
    required this.animationValue,
    this.playbackPosition,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (audioData.isEmpty) return;

    switch (style) {
      case WaveStyle.bars:
        _drawBars(canvas, size);
        break;
      case WaveStyle.line:
        _drawLine(canvas, size);
        break;
      case WaveStyle.dots:
        _drawDots(canvas, size);
        break;
      case WaveStyle.smooth:
        _drawSmoothWave(canvas, size);
        break;
    }

    // Draw playback position indicator
    if (playbackPosition != null) {
      final x = size.width * playbackPosition!;
      final paint = Paint()
        ..color = VJColors.accent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  void _drawBars(Canvas canvas, Size size) {
    final barCount = math.min(50, audioData.length);
    final barWidth = size.width / barCount;
    final barSpacing = barWidth * 0.2;
    final actualBarWidth = barWidth - barSpacing;
    
    for (int i = 0; i < barCount; i++) {
      final dataIndex = (i * audioData.length / barCount).floor();
      final amplitude = audioData[dataIndex].abs().clamp(0.0, 1.0);
      
      // Add animation effect
      final animatedAmplitude = isPlaying
          ? amplitude * (0.8 + 0.2 * math.sin(animationValue * 2 * math.pi + i * 0.1))
          : amplitude;
      
      final barHeight = animatedAmplitude * size.height * 0.8;
      final x = i * barWidth + barSpacing / 2;
      final y = (size.height - barHeight) / 2;
      
      final paint = Paint()
        ..style = PaintingStyle.fill;
      
      // Apply gradient or color
      if (gradient != null && gradient!.length > 1) {
        final gradientPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient!,
          ).createShader(Rect.fromLTWH(x, y, actualBarWidth, barHeight));
        paint.shader = gradientPaint.shader;
      } else {
        paint.color = color.withOpacity(
          playbackPosition != null && i / barCount < playbackPosition! ? 0.3 : 1.0
        );
      }
      
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, actualBarWidth, barHeight),
        Radius.circular(actualBarWidth / 2),
      );
      
      canvas.drawRRect(rect, paint);
    }
  }

  void _drawLine(Canvas canvas, Size size) {
    final path = Path();
    final pointCount = math.min(200, audioData.length);
    
    for (int i = 0; i < pointCount; i++) {
      final dataIndex = (i * audioData.length / pointCount).floor();
      final amplitude = audioData[dataIndex];
      
      final x = (i / pointCount) * size.width;
      final y = size.height / 2 + amplitude * size.height / 2 * 0.8;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    canvas.drawPath(path, paint);
  }

  void _drawDots(Canvas canvas, Size size) {
    final dotCount = math.min(30, audioData.length);
    final dotSpacing = size.width / dotCount;
    
    for (int i = 0; i < dotCount; i++) {
      final dataIndex = (i * audioData.length / dotCount).floor();
      final amplitude = audioData[dataIndex].abs().clamp(0.0, 1.0);
      
      final x = i * dotSpacing + dotSpacing / 2;
      final y = size.height / 2;
      final radius = 2 + amplitude * 6;
      
      final paint = Paint()
        ..color = color.withOpacity(0.6 + amplitude * 0.4)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _drawSmoothWave(Canvas canvas, Size size) {
    final path = Path();
    final pointCount = math.min(100, audioData.length);
    
    final points = <Offset>[];
    for (int i = 0; i < pointCount; i++) {
      final dataIndex = (i * audioData.length / pointCount).floor();
      final amplitude = audioData[dataIndex];
      
      final x = (i / pointCount) * size.width;
      final y = size.height / 2 + amplitude * size.height / 2 * 0.8;
      
      points.add(Offset(x, y));
    }
    
    // Draw smooth bezier curve through points
    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      
      for (int i = 1; i < points.length - 1; i++) {
        final xc = (points[i].dx + points[i + 1].dx) / 2;
        final yc = (points[i].dy + points[i + 1].dy) / 2;
        path.quadraticBezierTo(points[i].dx, points[i].dy, xc, yc);
      }
      
      if (points.length > 1) {
        path.lineTo(points.last.dx, points.last.dy);
      }
    }
    
    // Fill area under curve
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height / 2)
      ..close();
    
    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(fillPath, fillPaint);
    
    // Draw line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.audioData != audioData ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.playbackPosition != playbackPosition;
  }
}