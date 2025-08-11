import 'package:flutter/material.dart';
import 'dart:math' as math;

class RealtimeVisualFeedback extends StatefulWidget {
  final double currentFrequency;
  final double targetFrequency;
  final double audioLevel;
  final bool isActive;
  
  const RealtimeVisualFeedback({
    Key? key,
    required this.currentFrequency,
    this.targetFrequency = 440.0,
    required this.audioLevel,
    required this.isActive,
  }) : super(key: key);
  
  @override
  State<RealtimeVisualFeedback> createState() => _RealtimeVisualFeedbackState();
}

class _RealtimeVisualFeedbackState extends State<RealtimeVisualFeedback>
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _glowController;
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    if (widget.isActive) {
      _startAnimations();
    }
  }
  
  void _startAnimations() {
    _pulseController.repeat(reverse: true);
    _waveController.repeat();
    _glowController.repeat(reverse: true);
  }
  
  void _stopAnimations() {
    _pulseController.stop();
    _waveController.stop();
    _glowController.stop();
  }
  
  @override
  void didUpdateWidget(RealtimeVisualFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive && !oldWidget.isActive) {
      _startAnimations();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopAnimations();
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _glowController.dispose();
    super.dispose();
  }
  
  // 음정 정확도 계산 (0 ~ 100)
  double _calculateAccuracy() {
    if (widget.currentFrequency == 0) return 0;
    
    final diff = (widget.currentFrequency - widget.targetFrequency).abs();
    final percentage = math.max(0.0, 100.0 - (diff / widget.targetFrequency * 100));
    return percentage;
  }
  
  // 음정에 따른 색상
  Color _getFrequencyColor() {
    final accuracy = _calculateAccuracy();
    
    if (accuracy >= 95) {
      return const Color(0xFF00E676); // 완벽 - 밝은 초록
    } else if (accuracy >= 85) {
      return const Color(0xFF66BB6A); // 매우 좋음 - 초록
    } else if (accuracy >= 70) {
      return const Color(0xFFFFEB3B); // 좋음 - 노랑
    } else if (accuracy >= 50) {
      return const Color(0xFFFFA726); // 보통 - 주황
    } else {
      return const Color(0xFFEF5350); // 개선 필요 - 빨강
    }
  }
  
  // 음이름 변환
  String _frequencyToNote(double frequency) {
    if (frequency == 0) return '--';
    
    final notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final a4 = 440.0;
    final c0 = a4 * math.pow(2, -4.75);
    
    if (frequency <= 0) return '--';
    
    final halfSteps = 12 * (math.log(frequency / c0) / math.log(2));
    final octave = (halfSteps / 12).floor();
    final noteIndex = (halfSteps % 12).round();
    
    return '${notes[noteIndex % 12]}$octave';
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();
    
    final accuracy = _calculateAccuracy();
    final color = _getFrequencyColor();
    final noteName = _frequencyToNote(widget.currentFrequency);
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 큰 중앙 시각화
          SizedBox(
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 배경 원형 그리드
                _buildCircularGrid(),
                
                // 음파 효과
                _buildSoundWaves(color),
                
                // 중앙 피치 표시
                _buildCentralDisplay(noteName, color, accuracy),
                
                // 타겟 가이드라인
                _buildTargetGuideline(),
                
                // 현재 위치 표시
                _buildCurrentPositionIndicator(color),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 하단 정보 패널
          _buildInfoPanel(accuracy, color),
        ],
      ),
    );
  }
  
  Widget _buildCircularGrid() {
    return CustomPaint(
      size: const Size(280, 280),
      painter: CircularGridPainter(),
    );
  }
  
  Widget _buildSoundWaves(Color color) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Stack(
          children: List.generate(3, (index) {
            final delay = index * 0.3;
            final progress = (_waveController.value + delay) % 1.0;
            
            return Center(
              child: Container(
                width: 100 + (progress * 180),
                height: 100 + (progress * 180),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity((1 - progress) * 0.3),
                    width: 2 + (widget.audioLevel * 3),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
  
  Widget _buildCentralDisplay(String noteName, Color color, double accuracy) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.1 * widget.audioLevel);
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withOpacity(0.9),
                  color.withOpacity(0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  noteName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.currentFrequency.round()}Hz',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${accuracy.round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildTargetGuideline() {
    return CustomPaint(
      size: const Size(280, 280),
      painter: TargetGuidelinePainter(
        targetFrequency: widget.targetFrequency,
        currentFrequency: widget.currentFrequency,
      ),
    );
  }
  
  Widget _buildCurrentPositionIndicator(Color color) {
    final angle = _calculateAngle();
    
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Transform.rotate(
          angle: angle,
          child: Container(
            alignment: Alignment.topCenter,
            child: Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.8),
                    blurRadius: 10 + (_glowController.value * 10),
                    spreadRadius: 2 + (_glowController.value * 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  double _calculateAngle() {
    if (widget.currentFrequency == 0) return 0;
    
    // 주파수를 각도로 변환 (200Hz ~ 800Hz를 -π ~ π로 매핑)
    final normalized = (widget.currentFrequency - 200) / 600;
    return (normalized * 2 * math.pi) - math.pi;
  }
  
  Widget _buildInfoPanel(double accuracy, Color color) {
    final diff = widget.currentFrequency - widget.targetFrequency;
    String guidance = '';
    IconData icon = Icons.music_note;
    
    if (diff.abs() < 5) {
      guidance = '완벽해요! 유지하세요!';
      icon = Icons.star;
    } else if (diff > 0) {
      guidance = '조금 낮춰보세요 ↓';
      icon = Icons.arrow_downward;
    } else {
      guidance = '조금 높여보세요 ↑';
      icon = Icons.arrow_upward;
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Text(
                guidance,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 주파수 미터
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // 목표 위치
                Positioned(
                  left: MediaQuery.of(context).size.width * 0.5 - 40,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // 현재 위치
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 100),
                  left: _calculateMeterPosition(context) - 20,
                  top: 5,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 상세 정보
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDetailItem('현재', '${widget.currentFrequency.round()}Hz', color),
              _buildDetailItem('목표', '${widget.targetFrequency.round()}Hz', Colors.white70),
              _buildDetailItem('차이', '${diff.abs().round()}Hz', 
                diff.abs() < 10 ? Colors.green : Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
  
  double _calculateMeterPosition(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 80;
    final normalized = (widget.currentFrequency - 200) / 600;
    return normalized.clamp(0, 1) * width;
  }
  
  Widget _buildDetailItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// 원형 그리드 페인터
class CircularGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    final center = Offset(size.width / 2, size.height / 2);
    
    // 동심원 그리기
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, i * 35.0, paint);
    }
    
    // 방사형 선 그리기
    for (int i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final start = Offset(
        center.dx + 35 * math.cos(angle),
        center.dy + 35 * math.sin(angle),
      );
      final end = Offset(
        center.dx + 140 * math.cos(angle),
        center.dy + 140 * math.sin(angle),
      );
      canvas.drawLine(start, end, paint);
    }
  }
  
  @override
  bool shouldRepaint(CircularGridPainter oldDelegate) => false;
}

// 타겟 가이드라인 페인터
class TargetGuidelinePainter extends CustomPainter {
  final double targetFrequency;
  final double currentFrequency;
  
  TargetGuidelinePainter({
    required this.targetFrequency,
    required this.currentFrequency,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    final center = Offset(size.width / 2, size.height / 2);
    final targetAngle = _frequencyToAngle(targetFrequency);
    
    // 타겟 방향 화살표
    paint.color = Colors.white.withOpacity(0.5);
    
    final arrowEnd = Offset(
      center.dx + 120 * math.cos(targetAngle - math.pi / 2),
      center.dy + 120 * math.sin(targetAngle - math.pi / 2),
    );
    
    canvas.drawLine(center, arrowEnd, paint);
    
    // 화살표 머리
    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(arrowEnd.dx, arrowEnd.dy);
    path.lineTo(
      arrowEnd.dx - 10 * math.cos(targetAngle - math.pi / 2 + 0.3),
      arrowEnd.dy - 10 * math.sin(targetAngle - math.pi / 2 + 0.3),
    );
    path.lineTo(
      arrowEnd.dx - 10 * math.cos(targetAngle - math.pi / 2 - 0.3),
      arrowEnd.dy - 10 * math.sin(targetAngle - math.pi / 2 - 0.3),
    );
    path.close();
    
    canvas.drawPath(path, arrowPaint);
  }
  
  double _frequencyToAngle(double frequency) {
    final normalized = (frequency - 200) / 600;
    return (normalized * 2 * math.pi) - math.pi;
  }
  
  @override
  bool shouldRepaint(TargetGuidelinePainter oldDelegate) {
    return oldDelegate.targetFrequency != targetFrequency ||
           oldDelegate.currentFrequency != currentFrequency;
  }
}