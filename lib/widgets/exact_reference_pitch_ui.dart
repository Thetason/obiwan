import 'package:flutter/material.dart';
import 'dart:math' as math;

class ExactReferencePitchUI extends StatefulWidget {
  final List<PitchBlock> pitchBlocks;
  final double width;
  final double height;
  
  const ExactReferencePitchUI({
    super.key,
    required this.pitchBlocks,
    this.width = 800,
    this.height = 300,
  });

  @override
  State<ExactReferencePitchUI> createState() => _ExactReferencePitchUIState();
}

class PitchBlock {
  final String noteName;
  final double frequency;
  final double startTime;
  final double duration;
  final double confidence;
  
  PitchBlock({
    required this.noteName,
    required this.frequency,
    required this.startTime,
    required this.duration,
    required this.confidence,
  });
}

class _ExactReferencePitchUIState extends State<ExactReferencePitchUI>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: CustomPaint(
        painter: ExactReferencePainter(
          pitchBlocks: widget.pitchBlocks,
          animation: _animationController,
        ),
        size: Size(widget.width, widget.height),
      ),
    );
  }
}

class ExactReferencePainter extends CustomPainter {
  final List<PitchBlock> pitchBlocks;
  final AnimationController animation;
  
  ExactReferencePainter({
    required this.pitchBlocks,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 왼쪽 세로 색상 스케일 그리기
    _drawVerticalColorScale(canvas, size);
    
    // 2. 왼쪽 음표 라벨들 그리기
    _drawNoteLabels(canvas, size);
    
    // 3. 오른쪽 시간 격자선 그리기
    _drawTimeGrid(canvas, size);
    
    // 4. 피치 블록들 그리기
    _drawPitchBlocks(canvas, size);
    
    // 5. 주황색 연결 곡선 그리기
    _drawConnectionCurve(canvas, size);
    
    // 6. 현재 위치 점 그리기
    _drawCurrentPosition(canvas, size);
  }
  
  void _drawVerticalColorScale(Canvas canvas, Size size) {
    const double leftWidth = 80.0;
    
    // 세로 그라디언트 (보라→파랑→초록→노랑→주황→빨강)
    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFDC2626), // 빨강 (높은 음)
        Color(0xFFEA580C), // 주황
        Color(0xFFF59E0B), // 노랑
        Color(0xFF10B981), // 초록
        Color(0xFF3B82F6), // 파랑
        Color(0xFF8B5CF6), // 보라 (낮은 음)
      ],
    );
    
    final rect = Rect.fromLTWH(0, 0, leftWidth, size.height);
    final paint = Paint()..shader = gradient.createShader(rect);
    
    canvas.drawRect(rect, paint);
  }
  
  void _drawNoteLabels(Canvas canvas, Size size) {
    const double leftWidth = 80.0;
    
    // F♯3부터 C4까지의 음표들
    final notes = [
      {'name': 'C4', 'y': 0.1},
      {'name': 'B3', 'y': 0.2},
      {'name': 'A♯3', 'y': 0.3},
      {'name': 'A3', 'y': 0.4},
      {'name': 'G♯3', 'y': 0.5},
      {'name': 'G3', 'y': 0.6},
      {'name': 'F♯3', 'y': 0.9},
    ];
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    for (final note in notes) {
      final y = note['y'] as double;
      
      // 배경 박스
      final bgPaint = Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(leftWidth * 0.5, size.height * y),
          width: 45,
          height: 20,
        ),
        const Radius.circular(4),
      );
      
      canvas.drawRRect(bgRect, bgPaint);
      
      // 텍스트
      textPainter.text = TextSpan(
        text: note['name'] as String,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          leftWidth * 0.5 - textPainter.width * 0.5,
          size.height * y - textPainter.height * 0.5,
        ),
      );
    }
  }
  
  void _drawTimeGrid(Canvas canvas, Size size) {
    const double leftWidth = 80.0;
    final rightArea = size.width - leftWidth;
    
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB).withOpacity(0.5)
      ..strokeWidth = 1;
    
    // 세로 격자선들 (1초 간격)
    for (int i = 0; i <= 10; i++) {
      final x = leftWidth + (rightArea * i / 10);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }
  }
  
  void _drawPitchBlocks(Canvas canvas, Size size) {
    const double leftWidth = 80.0;
    final rightArea = size.width - leftWidth;
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    for (int i = 0; i < pitchBlocks.length; i++) {
      final block = pitchBlocks[i];
      
      // 블록 위치 계산
      final x = leftWidth + (rightArea * block.startTime / 10.0);
      final width = math.max(60.0, rightArea * block.duration / 10.0);
      final y = _frequencyToY(block.frequency, size.height);
      
      // 신뢰도에 따른 색상
      final color = _getBlockColor(block.confidence);
      
      // 애니메이션 지연
      final animationValue = ((animation.value * 3 - i * 0.2).clamp(0.0, 1.0));
      if (animationValue <= 0) continue;
      
      // 블록 그리기
      final blockPaint = Paint()
        ..color = color.withOpacity(animationValue)
        ..style = PaintingStyle.fill;
      
      final blockRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + width * 0.5, y),
          width: width * animationValue,
          height: 28,
        ),
        const Radius.circular(6),
      );
      
      canvas.drawRRect(blockRect, blockPaint);
      
      // 그림자
      final shadowPaint = Paint()
        ..color = color.withOpacity(0.3 * animationValue)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + width * 0.5, y + 2),
            width: width * animationValue,
            height: 28,
          ),
          const Radius.circular(6),
        ),
        shadowPaint,
      );
      
      // 블록 텍스트
      if (animationValue > 0.5 && width > 40) {
        textPainter.text = TextSpan(
          text: block.noteName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        );
        
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            x + width * 0.5 - textPainter.width * 0.5,
            y - textPainter.height * 0.5,
          ),
        );
      }
    }
  }
  
  void _drawConnectionCurve(Canvas canvas, Size size) {
    if (pitchBlocks.length < 2) return;
    
    const double leftWidth = 80.0;
    final rightArea = size.width - leftWidth;
    
    final path = Path();
    bool isFirst = true;
    
    for (final block in pitchBlocks) {
      final x = leftWidth + (rightArea * (block.startTime + block.duration * 0.5) / 10.0);
      final y = _frequencyToY(block.frequency, size.height);
      
      if (isFirst) {
        path.moveTo(x, y);
        isFirst = false;
      } else {
        path.lineTo(x, y);
      }
    }
    
    final curvePaint = Paint()
      ..color = const Color(0xFFEA580C).withOpacity(animation.value)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawPath(path, curvePaint);
  }
  
  void _drawCurrentPosition(Canvas canvas, Size size) {
    if (pitchBlocks.isEmpty) return;
    
    const double leftWidth = 80.0;
    final rightArea = size.width - leftWidth;
    final lastBlock = pitchBlocks.last;
    
    final x = leftWidth + (rightArea * (lastBlock.startTime + lastBlock.duration * 0.5) / 10.0);
    final y = _frequencyToY(lastBlock.frequency, size.height);
    
    // 외곽 원
    final outerPaint = Paint()
      ..color = Colors.black.withOpacity(animation.value)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(x, y), 6 * animation.value, outerPaint);
    
    // 내부 원
    final innerPaint = Paint()
      ..color = Colors.white.withOpacity(animation.value)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(x, y), 3 * animation.value, innerPaint);
  }
  
  double _frequencyToY(double frequency, double height) {
    // F♯3 = 185Hz (하단), C4 = 261Hz (상단)
    const double minFreq = 185.0;
    const double maxFreq = 261.0;
    
    final normalizedFreq = ((frequency - minFreq) / (maxFreq - minFreq)).clamp(0.0, 1.0);
    return height - (normalizedFreq * height * 0.8) - height * 0.1;
  }
  
  Color _getBlockColor(double confidence) {
    if (confidence >= 0.8) return const Color(0xFF10B981); // 초록
    if (confidence >= 0.6) return const Color(0xFF3B82F6); // 파랑  
    if (confidence >= 0.4) return const Color(0xFF8B5CF6); // 보라
    return const Color(0xFFEA580C); // 주황
  }

  @override
  bool shouldRepaint(ExactReferencePainter oldDelegate) {
    return oldDelegate.animation != animation ||
           oldDelegate.pitchBlocks != pitchBlocks;
  }
}