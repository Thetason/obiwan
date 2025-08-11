import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/pitch_colors.dart';

/// Vanido 스타일 피치 막대 시각화
/// 목표 음역을 반투명 띠로 표시하고 현재 피치 위치를 실시간으로 보여줌
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
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // 배경 그리드
            CustomPaint(
              size: Size.infinite,
              painter: _GridPainter(),
            ),
            
            // 목표 음역 띠 (반투명)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Center(
                  child: Transform.scale(
                    scale: isInRange ? _pulseAnimation.value : 1.0,
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: isInRange 
                            ? PitchColors.perfect.withOpacity(0.3)
                            : PitchColors.neutral.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isInRange 
                              ? PitchColors.perfect.withOpacity(0.6)
                              : PitchColors.neutral.withOpacity(0.4),
                          width: 2,
                        ),
                        boxShadow: isInRange ? [
                          BoxShadow(
                            color: PitchColors.perfect.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ] : null,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // 현재 피치 위치 표시
            if (widget.currentPitch > 0)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 50),
                top: 20,
                bottom: 20,
                left: MediaQuery.of(context).size.width * _getPitchPosition() - 30,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 6,
                  decoration: BoxDecoration(
                    color: PitchColors.fromAccuracy(accuracy)
                        .withOpacity(0.8 + (widget.confidence * 0.2)),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: PitchColors.fromAccuracy(accuracy).withOpacity(0.6),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            
            // 중앙 목표선
            Center(
              child: Container(
                width: 2,
                height: 60,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            
            // 상태 텍스트
            Positioned(
              top: 8,
              right: 16,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  color: isInRange ? PitchColors.perfect : Colors.white70,
                  fontSize: 12,
                  fontWeight: isInRange ? FontWeight.bold : FontWeight.normal,
                ),
                child: Text(
                  isInRange ? 'PERFECT!' : 
                  accuracy > 0.7 ? 'CLOSE' : 
                  widget.currentPitch > widget.targetPitch ? 'TOO HIGH' : 'TOO LOW',
                ),
              ),
            ),
            
            // 주파수 표시
            Positioned(
              bottom: 8,
              left: 16,
              child: Text(
                '${widget.currentPitch.toStringAsFixed(1)} Hz',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
            ),
            
            Positioned(
              bottom: 8,
              right: 16,
              child: Text(
                'Target: ${widget.targetPitch.toStringAsFixed(1)} Hz',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 배경 그리드 페인터
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    
    // 수직선 그리기
    for (int i = 1; i < 5; i++) {
      final x = size.width * (i / 5);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    // 수평선 그리기
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint..color = Colors.white.withOpacity(0.1),
    );
  }
  
  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}