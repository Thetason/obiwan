import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../tokens/colors.dart';
import '../tokens/typography.dart';
import '../tokens/spacing.dart';

class PitchPoint {
  final double time;
  final double frequency;
  final double confidence;
  final String? note;

  PitchPoint({
    required this.time,
    required this.frequency,
    required this.confidence,
    this.note,
  });
}

class VJPitchGraph extends StatefulWidget {
  final List<PitchPoint> pitchData;
  final double? targetPitch;
  final double height;
  final bool showGuides;
  final bool animateEntry;
  final Color? lineColor;
  final double? currentTime;

  const VJPitchGraph({
    Key? key,
    required this.pitchData,
    this.targetPitch,
    this.height = 200,
    this.showGuides = true,
    this.animateEntry = true,
    this.lineColor,
    this.currentTime,
  }) : super(key: key);

  @override
  State<VJPitchGraph> createState() => _VJPitchGraphState();
}

class _VJPitchGraphState extends State<VJPitchGraph>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    
    if (widget.animateEntry) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: VJColors.surfaceLight,
        borderRadius: BorderRadius.circular(VJSpacing.radiusMd),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VJSpacing.radiusMd),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: _PitchGraphPainter(
                pitchData: widget.pitchData,
                targetPitch: widget.targetPitch,
                showGuides: widget.showGuides,
                lineColor: widget.lineColor ?? VJColors.primary,
                animationProgress: _animation.value,
                currentTime: widget.currentTime,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PitchGraphPainter extends CustomPainter {
  final List<PitchPoint> pitchData;
  final double? targetPitch;
  final bool showGuides;
  final Color lineColor;
  final double animationProgress;
  final double? currentTime;

  _PitchGraphPainter({
    required this.pitchData,
    this.targetPitch,
    required this.showGuides,
    required this.lineColor,
    required this.animationProgress,
    this.currentTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pitchData.isEmpty) return;

    // Calculate frequency range
    final frequencies = pitchData.map((p) => p.frequency).toList();
    double minFreq = frequencies.reduce(math.min);
    double maxFreq = frequencies.reduce(math.max);
    
    // Add padding to the range
    final range = maxFreq - minFreq;
    minFreq -= range * 0.1;
    maxFreq += range * 0.1;
    
    // Include target pitch in range if provided
    if (targetPitch != null) {
      minFreq = math.min(minFreq, targetPitch! - 20);
      maxFreq = math.max(maxFreq, targetPitch! + 20);
    }

    // Draw guide lines
    if (showGuides) {
      _drawGuideLines(canvas, size, minFreq, maxFreq);
    }

    // Draw target pitch line
    if (targetPitch != null) {
      _drawTargetLine(canvas, size, minFreq, maxFreq);
    }

    // Draw pitch curve
    _drawPitchCurve(canvas, size, minFreq, maxFreq);

    // Draw current time indicator
    if (currentTime != null) {
      _drawCurrentTimeIndicator(canvas, size);
    }
  }

  void _drawGuideLines(Canvas canvas, Size size, double minFreq, double maxFreq) {
    final paint = Paint()
      ..color = VJColors.gray300
      ..strokeWidth = 1;

    // Draw horizontal guide lines for common notes
    final noteFrequencies = [
      261.63, // C4
      293.66, // D4
      329.63, // E4
      349.23, // F4
      392.00, // G4
      440.00, // A4
      493.88, // B4
      523.25, // C5
    ];

    for (final freq in noteFrequencies) {
      if (freq >= minFreq && freq <= maxFreq) {
        final y = size.height - ((freq - minFreq) / (maxFreq - minFreq)) * size.height;
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          paint..color = VJColors.gray200,
        );
      }
    }
  }

  void _drawTargetLine(Canvas canvas, Size size, double minFreq, double maxFreq) {
    if (targetPitch == null) return;
    
    final y = size.height - ((targetPitch! - minFreq) / (maxFreq - minFreq)) * size.height;
    
    final paint = Paint()
      ..color = VJColors.success.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // Draw dashed line
    const dashWidth = 5.0;
    const dashSpace = 5.0;
    double startX = 0;
    
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(math.min(startX + dashWidth, size.width), y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  void _drawPitchCurve(Canvas canvas, Size size, double minFreq, double maxFreq) {
    if (pitchData.isEmpty) return;

    final path = Path();
    final fillPath = Path();
    
    // Calculate time range
    final times = pitchData.map((p) => p.time).toList();
    final minTime = times.reduce(math.min);
    final maxTime = times.reduce(math.max);
    final timeRange = maxTime - minTime;
    
    // Create points
    final points = <Offset>[];
    for (int i = 0; i < pitchData.length; i++) {
      final point = pitchData[i];
      final x = ((point.time - minTime) / timeRange) * size.width;
      final y = size.height - ((point.frequency - minFreq) / (maxFreq - minFreq)) * size.height;
      
      // Apply animation
      final animatedY = size.height + (y - size.height) * animationProgress;
      points.add(Offset(x, animatedY));
    }
    
    // Draw smooth curve
    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      fillPath.moveTo(points.first.dx, size.height);
      fillPath.lineTo(points.first.dx, points.first.dy);
      
      for (int i = 0; i < points.length - 1; i++) {
        final current = points[i];
        final next = points[i + 1];
        final controlPoint1 = Offset(
          current.dx + (next.dx - current.dx) / 3,
          current.dy,
        );
        final controlPoint2 = Offset(
          current.dx + (next.dx - current.dx) * 2 / 3,
          next.dy,
        );
        
        path.cubicTo(
          controlPoint1.dx, controlPoint1.dy,
          controlPoint2.dx, controlPoint2.dy,
          next.dx, next.dy,
        );
        
        fillPath.cubicTo(
          controlPoint1.dx, controlPoint1.dy,
          controlPoint2.dx, controlPoint2.dy,
          next.dx, next.dy,
        );
      }
      
      // Complete fill path
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();
    }
    
    // Draw fill gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withOpacity(0.2),
          lineColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(fillPath, fillPaint);
    
    // Draw line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    canvas.drawPath(path, linePaint);
    
    // Draw confidence dots
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final confidence = pitchData[i].confidence;
      
      if (confidence > 0.7) {
        final dotPaint = Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(point, 3, dotPaint);
      }
    }
  }

  void _drawCurrentTimeIndicator(Canvas canvas, Size size) {
    if (currentTime == null || pitchData.isEmpty) return;
    
    final times = pitchData.map((p) => p.time).toList();
    final minTime = times.reduce(math.min);
    final maxTime = times.reduce(math.max);
    final timeRange = maxTime - minTime;
    
    final x = ((currentTime! - minTime) / timeRange) * size.width;
    
    final paint = Paint()
      ..color = VJColors.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      paint,
    );
    
    // Draw glow effect
    final glowPaint = Paint()
      ..color = VJColors.accent.withOpacity(0.3)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(_PitchGraphPainter oldDelegate) {
    return oldDelegate.pitchData != pitchData ||
           oldDelegate.animationProgress != animationProgress ||
           oldDelegate.currentTime != currentTime;
  }
}