import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/pitch_colors.dart';

/// Nike Run Club inspired compact pitch bar
/// Athletic style with neon colors and smooth animations
class PitchBarVisualizer extends StatefulWidget {
  final double currentPitch;      // 현재 주파수 (Hz)
  final double targetPitch;       // 목표 주파수 (Hz)
  final double tolerance;         // 허용 오차 (cents)
  final double confidence;        // 신뢰도 (0.0 ~ 1.0)
  final bool isActive;            // 활성 상태
  
  const PitchBarVisualizer({
    Key? key,
    required this.currentPitch,
    required this.targetPitch,
    this.tolerance = 50.0,  // 기본 50 cents 허용
    this.confidence = 1.0,
    this.isActive = true,
  }) : super(key: key);
  
  @override
  State<PitchBarVisualizer> createState() => _PitchBarVisualizerState();
}

class _PitchBarVisualizerState extends State<PitchBarVisualizer>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void didUpdateWidget(PitchBarVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 정확한 음을 맞췄을 때 펄스 효과
    if (widget.isActive && _isInRange()) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  bool _isInRange() {
    if (widget.currentPitch == 0 || widget.targetPitch == 0) return false;
    
    // cents 계산: 1200 * log2(f2/f1)
    final cents = 1200 * (math.log(widget.currentPitch / widget.targetPitch) / math.ln2);
    return cents.abs() <= widget.tolerance;
  }
  
  double _getPitchPosition() {
    if (widget.currentPitch == 0 || widget.targetPitch == 0) return 0.5;
    
    // 화면상 위치 계산 (목표 음을 중심으로)
    final cents = 1200 * (math.log(widget.currentPitch / widget.targetPitch) / math.ln2);
    final normalizedPosition = 0.5 + (cents / 200); // ±100 cents 범위
    return normalizedPosition.clamp(0.0, 1.0);
  }
  
  @override
  Widget build(BuildContext context) {
    final isInRange = _isInRange();
    final accuracy = isInRange ? 0.9 : (_getPitchPosition() - 0.5).abs() < 0.25 ? 0.7 : 0.3;
    
    return Container(
      height: 80, // Compact height for Nike style
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            PitchColors.cardDark.withOpacity(0.8),
            PitchColors.backgroundEnd.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isInRange ? PitchColors.neonGreen.withOpacity(0.6) : PitchColors.electricBlue.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Nike-style minimal grid
            CustomPaint(
              size: Size.infinite,
              painter: _NikeGridPainter(),
            ),
            
            // Nike-style target zone with athletic glow
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Center(
                  child: Transform.scale(
                    scale: isInRange ? _pulseAnimation.value : 1.0,
                    child: Container(
                      height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isInRange 
                              ? [PitchColors.neonGreen.withOpacity(0.4), PitchColors.neonGreen.withOpacity(0.2)]
                              : [PitchColors.electricBlue.withOpacity(0.3), PitchColors.electricBlue.withOpacity(0.1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isInRange 
                              ? PitchColors.neonGreen.withOpacity(0.8)
                              : PitchColors.electricBlue.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: isInRange ? [
                          BoxShadow(
                            color: PitchColors.neonGreen.withOpacity(0.6),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ] : null,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // Nike-style pitch position indicator
            if (widget.currentPitch > 0)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 50),
                top: 16,
                bottom: 16,
                left: MediaQuery.of(context).size.width * _getPitchPosition() - 40,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        PitchColors.fromAccuracy(accuracy),
                        PitchColors.fromAccuracy(accuracy).withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: PitchColors.fromAccuracy(accuracy).withOpacity(0.8),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            
            // Nike-style center target line
            Center(
              child: Container(
                width: 3,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.8),
                      Colors.white.withOpacity(0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            
            // Nike-style status indicator
            Positioned(
              top: 6,
              right: 12,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isInRange 
                      ? PitchColors.neonGreen.withOpacity(0.2)
                      : PitchColors.electricBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isInRange ? PitchColors.neonGreen : PitchColors.electricBlue,
                    width: 1,
                  ),
                ),
                child: Text(
                  isInRange ? 'PERFECT' : 
                  accuracy > 0.7 ? 'CLOSE' : 
                  widget.currentPitch > widget.targetPitch ? 'HIGH' : 'LOW',
                  style: TextStyle(
                    color: isInRange ? PitchColors.neonGreen : PitchColors.electricBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'SF Pro Display',
                  ),
                ),
              ),
            ),
            
            // Nike-style frequency display - left side
            Positioned(
              bottom: 6,
              left: 12,
              child: Text(
                '${widget.currentPitch.toStringAsFixed(1)}Hz',
                style: TextStyle(
                  color: PitchColors.fromAccuracy(accuracy).withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SF Pro Display',
                ),
              ),
            ),
            
            // Target frequency - right side
            Positioned(
              bottom: 6,
              right: 12,
              child: Text(
                '${widget.targetPitch.toStringAsFixed(0)}Hz',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Nike-style minimal grid painter
class _NikeGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final subtlePaint = Paint()
      ..color = PitchColors.electricBlue.withOpacity(0.1)
      ..strokeWidth = 0.5;
    
    // Minimal vertical lines
    for (int i = 1; i < 4; i++) {
      final x = size.width * (i / 4);
      canvas.drawLine(
        Offset(x, size.height * 0.2),
        Offset(x, size.height * 0.8),
        subtlePaint,
      );
    }
    
    // Single center horizontal line
    canvas.drawLine(
      Offset(size.width * 0.1, size.height / 2),
      Offset(size.width * 0.9, size.height / 2),
      subtlePaint..color = PitchColors.electricBlue.withOpacity(0.15),
    );
  }
  
  @override
  bool shouldRepaint(_NikeGridPainter oldDelegate) => false;
}