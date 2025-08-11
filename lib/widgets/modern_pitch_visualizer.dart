import 'package:flutter/material.dart';
import 'dart:math' as math;

class ModernPitchVisualizer extends StatefulWidget {
  final double currentPitch;
  final double targetPitch;
  final bool isRecording;
  final List<PitchPoint> pitchHistory;
  
  const ModernPitchVisualizer({
    Key? key,
    required this.currentPitch,
    required this.targetPitch,
    required this.isRecording,
    this.pitchHistory = const [],
  }) : super(key: key);

  @override
  State<ModernPitchVisualizer> createState() => _ModernPitchVisualizerState();
}

class _ModernPitchVisualizerState extends State<ModernPitchVisualizer>
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.linear,
    ));
    
    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
    }
  }
  
  @override
  void didUpdateWidget(ModernPitchVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseController.stop();
      _waveController.stop();
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildPitchMeter(),
          const SizedBox(height: 20),
          _buildPitchChart(),
          const SizedBox(height: 20),
          _buildStatus(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return const Text(
      '실시간 음정 분석',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2937),
      ),
    );
  }
  
  Widget _buildPitchMeter() {
    final pitchDiff = (widget.currentPitch - widget.targetPitch).abs();
    final isOnPitch = pitchDiff < 20;
    final position = _calculatePosition();
    
    return Column(
      children: [
        // Pitch meter bar
        Stack(
          alignment: Alignment.center,
          children: [
            // Background gradient
            Container(
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  colors: [
                    Colors.red.shade300,
                    Colors.yellow.shade300,
                    Colors.green.shade300,
                    Colors.yellow.shade300,
                    Colors.red.shade300,
                  ],
                  stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                ),
              ),
            ),
            
            // Target indicator
            Positioned(
              left: MediaQuery.of(context).size.width * 0.5 - 48,
              child: Container(
                width: 2,
                height: 20,
                color: const Color(0xFF6366F1),
              ),
            ),
            
            // Current pitch indicator
            if (widget.isRecording)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 150),
                left: position * (MediaQuery.of(context).size.width - 96),
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnPitch ? Colors.green : Colors.orange,
                          boxShadow: [
                            BoxShadow(
                              color: (isOnPitch ? Colors.green : Colors.orange)
                                  .withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
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
        const SizedBox(height: 8),
        
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '낮음',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '목표: ${widget.targetPitch.toStringAsFixed(0)}Hz',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6366F1),
              ),
            ),
            Text(
              '높음',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildPitchChart() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: PitchChartPainter(
          pitchHistory: widget.pitchHistory,
          targetPitch: widget.targetPitch,
          isAnimating: widget.isRecording,
          animationValue: _waveAnimation.value,
        ),
        child: Container(),
      ),
    );
  }
  
  Widget _buildStatus() {
    if (!widget.isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '녹음을 시작하세요',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      );
    }
    
    final pitchDiff = (widget.currentPitch - widget.targetPitch).abs();
    final isOnPitch = pitchDiff < 20;
    
    String status;
    Color statusColor;
    IconData statusIcon;
    
    if (isOnPitch) {
      status = '완벽해요!';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (pitchDiff < 50) {
      status = '거의 맞아요';
      statusColor = Colors.orange;
      statusIcon = Icons.adjust;
    } else {
      status = '조정이 필요해요';
      statusColor = Colors.red;
      statusIcon = Icons.warning;
    }
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
  
  double _calculatePosition() {
    final diff = widget.currentPitch - widget.targetPitch;
    final normalizedDiff = diff / 100; // Normalize to -1 to 1 range
    return (normalizedDiff + 1) / 2; // Convert to 0 to 1 range
  }
}

class PitchPoint {
  final double time;
  final double pitch;
  final double confidence;
  
  PitchPoint({
    required this.time,
    required this.pitch,
    required this.confidence,
  });
}

class PitchChartPainter extends CustomPainter {
  final List<PitchPoint> pitchHistory;
  final double targetPitch;
  final bool isAnimating;
  final double animationValue;
  
  PitchChartPainter({
    required this.pitchHistory,
    required this.targetPitch,
    required this.isAnimating,
    required this.animationValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid
    _drawGrid(canvas, size);
    
    // Draw target line
    _drawTargetLine(canvas, size);
    
    // Draw pitch curve
    if (pitchHistory.isNotEmpty) {
      _drawPitchCurve(canvas, size);
    }
  }
  
  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 1;
    
    // Horizontal lines
    for (int i = 0; i <= 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
    
    // Vertical lines
    for (int i = 0; i <= 10; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }
  
  void _drawTargetLine(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6366F1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final targetY = size.height / 2;
    
    final path = Path()
      ..moveTo(0, targetY)
      ..lineTo(size.width, targetY);
    
    canvas.drawPath(
      _dashPath(path, [5, 5]),
      paint,
    );
  }
  
  void _drawPitchCurve(Canvas canvas, Size size) {
    if (pitchHistory.length < 2) return;
    
    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    final gradient = LinearGradient(
      colors: [
        const Color(0xFF8B5CF6),
        const Color(0xFF6366F1),
      ],
    );
    
    paint.shader = gradient.createShader(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
    
    for (int i = 0; i < pitchHistory.length; i++) {
      final point = pitchHistory[i];
      final x = (i / (pitchHistory.length - 1)) * size.width;
      final normalizedPitch = (point.pitch - targetPitch + 100) / 200;
      final y = (1 - normalizedPitch) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevPoint = pitchHistory[i - 1];
        final prevX = ((i - 1) / (pitchHistory.length - 1)) * size.width;
        final prevNormalizedPitch = (prevPoint.pitch - targetPitch + 100) / 200;
        final prevY = (1 - prevNormalizedPitch) * size.height;
        
        final controlX1 = prevX + (x - prevX) / 3;
        final controlY1 = prevY;
        final controlX2 = prevX + 2 * (x - prevX) / 3;
        final controlY2 = y;
        
        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // Draw current point
    if (isAnimating && pitchHistory.isNotEmpty) {
      final lastPoint = pitchHistory.last;
      final x = size.width;
      final normalizedPitch = (lastPoint.pitch - targetPitch + 100) / 200;
      final y = (1 - normalizedPitch) * size.height;
      
      final pointPaint = Paint()
        ..color = const Color(0xFF6366F1)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(x, y),
        6 + math.sin(animationValue * 2 * math.pi) * 2,
        pointPaint,
      );
    }
  }
  
  Path _dashPath(Path source, List<double> dashArray) {
    final path = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final len = dashArray[(draw ? 0 : 1) % dashArray.length];
        if (draw) {
          path.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return path;
  }
  
  @override
  bool shouldRepaint(PitchChartPainter oldDelegate) {
    return pitchHistory != oldDelegate.pitchHistory ||
           animationValue != oldDelegate.animationValue;
  }
}