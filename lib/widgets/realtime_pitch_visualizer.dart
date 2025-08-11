import 'package:flutter/material.dart';
import 'dart:math' as math;

class RealtimePitchVisualizer extends StatelessWidget {
  final double frequency;
  final double targetFrequency;
  final double confidence;
  final int cents;
  final String note;
  final bool isActive;
  final AnimationController pulseAnimation;
  final AnimationController glowAnimation;
  
  const RealtimePitchVisualizer({
    super.key,
    required this.frequency,
    required this.targetFrequency,
    required this.confidence,
    required this.cents,
    required this.note,
    required this.isActive,
    required this.pulseAnimation,
    required this.glowAnimation,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Rings
          _buildConcentricRings(),
          
          // Pitch Accuracy Indicator
          _buildAccuracyRing(),
          
          // Center Display
          _buildCenterDisplay(),
          
          // Cents Indicator
          _buildCentsIndicator(),
        ],
      ),
    );
  }
  
  Widget _buildConcentricRings() {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(3, (index) {
            final scale = 1.0 + (pulseAnimation.value * 0.1 * (index + 1));
            final opacity = isActive 
              ? (1.0 - (index * 0.3)) * (1.0 - pulseAnimation.value * 0.3)
              : 0.2;
            
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 250 - (index * 50),
                height: 250 - (index * 50),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _getAccuracyColor().withOpacity(opacity),
                    width: 1,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
  
  Widget _buildAccuracyRing() {
    final accuracy = cents.abs() <= 50 ? 1.0 - (cents.abs() / 50) : 0.0;
    
    return CustomPaint(
      size: const Size(200, 200),
      painter: AccuracyRingPainter(
        accuracy: accuracy,
        isActive: isActive,
        color: _getAccuracyColor(),
      ),
    );
  }
  
  Widget _buildCenterDisplay() {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        return Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _getAccuracyColor().withOpacity(0.1),
                _getAccuracyColor().withOpacity(0.05),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: _getAccuracyColor().withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getAccuracyColor().withOpacity(glowAnimation.value * 0.5),
                blurRadius: 20,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Note Display
              Text(
                note,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: _getAccuracyColor(),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              
              // Frequency Display
              Text(
                frequency > 0 ? '${frequency.toStringAsFixed(1)} Hz' : '—',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Confidence Bar
              Container(
                width: 80,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: confidence,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildCentsIndicator() {
    if (!isActive || frequency <= 0) return const SizedBox();
    
    return Positioned(
      bottom: 30,
      child: Column(
        children: [
          // Cents Meter
          Container(
            width: 200,
            height: 40,
            child: CustomPaint(
              painter: CentsMeterPainter(
                cents: cents,
                color: _getAccuracyColor(),
              ),
            ),
          ),
          
          // Cents Text
          Text(
            cents > 0 ? '+$cents¢' : '$cents¢',
            style: TextStyle(
              color: _getAccuracyColor(),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getAccuracyColor() {
    if (!isActive || frequency <= 0) return Colors.grey;
    
    final absCents = cents.abs();
    if (absCents <= 5) {
      return Colors.greenAccent;
    } else if (absCents <= 10) {
      return Colors.yellowAccent;
    } else if (absCents <= 20) {
      return Colors.orange;
    } else {
      return Colors.redAccent;
    }
  }
}

// Accuracy Ring Painter
class AccuracyRingPainter extends CustomPainter {
  final double accuracy;
  final bool isActive;
  final Color color;
  
  AccuracyRingPainter({
    required this.accuracy,
    required this.isActive,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Background ring
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = Colors.white.withOpacity(0.1);
    
    canvas.drawCircle(center, radius, bgPaint);
    
    // Accuracy arc
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          color.withOpacity(0.3),
          color,
          color.withOpacity(0.3),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    final sweepAngle = accuracy * math.pi * 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }
  
  @override
  bool shouldRepaint(AccuracyRingPainter oldDelegate) =>
      accuracy != oldDelegate.accuracy || isActive != oldDelegate.isActive;
}

// Cents Meter Painter
class CentsMeterPainter extends CustomPainter {
  final int cents;
  final Color color;
  
  CentsMeterPainter({
    required this.cents,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // Draw scale lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1;
    
    for (int i = -50; i <= 50; i += 10) {
      final x = centerX + (i * size.width / 100);
      final height = i == 0 ? 15.0 : (i % 50 == 0 ? 10.0 : 5.0);
      
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        linePaint,
      );
    }
    
    // Draw center line
    final centerPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2;
    
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      centerPaint,
    );
    
    // Draw indicator
    final clampedCents = cents.clamp(-50, 50);
    final indicatorX = centerX + (clampedCents * size.width / 100);
    
    final indicatorPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(indicatorX, 0)
      ..lineTo(indicatorX - 5, 10)
      ..lineTo(indicatorX + 5, 10)
      ..close();
    
    canvas.drawPath(path, indicatorPaint);
    
    // Draw glow
    canvas.drawCircle(
      Offset(indicatorX, 5),
      3,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }
  
  @override
  bool shouldRepaint(CentsMeterPainter oldDelegate) =>
      cents != oldDelegate.cents;
}