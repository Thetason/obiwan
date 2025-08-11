import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../widgets/recording_flow_modal.dart';

class RealtimePitchGraph extends StatefulWidget {
  final List<PitchPoint> pitchData;
  final bool isPlaying;
  
  const RealtimePitchGraph({
    Key? key,
    required this.pitchData,
    required this.isPlaying,
  }) : super(key: key);
  
  @override
  State<RealtimePitchGraph> createState() => _RealtimePitchGraphState();
}

class _RealtimePitchGraphState extends State<RealtimePitchGraph>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    if (widget.isPlaying) {
      _animationController.repeat();
    }
  }
  
  @override
  void didUpdateWidget(RealtimePitchGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _animationController.repeat();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _animationController.stop();
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          painter: PitchGraphPainter(
            pitchData: widget.pitchData,
            animationValue: _animationController.value,
          ),
        );
      },
    );
  }
}

class PitchGraphPainter extends CustomPainter {
  final List<PitchPoint> pitchData;
  final double animationValue;
  
  PitchGraphPainter({
    required this.pitchData,
    required this.animationValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // 배경 그리드 그리기
    _drawGrid(canvas, size);
    
    // 음정 노트 레이블
    _drawNoteLabels(canvas, size);
    
    // 피치 곡선 그리기
    if (pitchData.isNotEmpty) {
      _drawPitchCurve(canvas, size);
    }
    
    // 현재 피치 포인트 강조
    if (pitchData.isNotEmpty) {
      _drawCurrentPoint(canvas, size);
    }
  }
  
  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;
    
    // 수평선 (음정 구분)
    const noteLines = [220, 330, 440, 550, 660]; // A3, E4, A4, C#5, E5
    for (final freq in noteLines) {
      final y = _frequencyToY(freq.toDouble(), size);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
    
    // 수직선 (시간 구분)
    const timeLines = 10;
    for (int i = 0; i <= timeLines; i++) {
      final x = size.width * i / timeLines;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }
  }
  
  void _drawNoteLabels(Canvas canvas, Size size) {
    const notes = [
      {'freq': 220, 'note': 'A3'},
      {'freq': 330, 'note': 'E4'},
      {'freq': 440, 'note': 'A4'},
      {'freq': 550, 'note': 'C#5'},
      {'freq': 660, 'note': 'E5'},
    ];
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    for (final note in notes) {
      final y = _frequencyToY((note['freq'] as int).toDouble(), size);
      
      textPainter.text = TextSpan(
        text: note['note'] as String,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - 10));
    }
  }
  
  void _drawPitchCurve(Canvas canvas, Size size) {
    if (pitchData.length < 2) return;
    
    final path = Path();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    // 첫 점으로 이동 (안전한 접근)
    if (pitchData.isEmpty) return;
    final firstPoint = pitchData.first;
    final firstX = _timeToX(firstPoint.time, size);
    final firstY = _frequencyToY(firstPoint.frequency, size);
    path.moveTo(firstX, firstY);
    
    // 나머지 점들 연결 (안전한 범위 체크)
    for (int i = 1; i < pitchData.length; i++) {
      if (i >= pitchData.length) break; // 추가 안전성 체크
      
      final point = pitchData[i];
      final x = _timeToX(point.time, size);
      final y = _frequencyToY(point.frequency, size);
      
      // 베지어 곡선으로 부드럽게 연결
      if (i > 0 && (i - 1) < pitchData.length) {
        final prevPoint = pitchData[i - 1];
        final prevX = _timeToX(prevPoint.time, size);
        final prevY = _frequencyToY(prevPoint.frequency, size);
        
        final controlX1 = prevX + (x - prevX) / 3;
        final controlY1 = prevY;
        final controlX2 = x - (x - prevX) / 3;
        final controlY2 = y;
        
        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }
    
    // 그라데이션 적용
    paint.shader = LinearGradient(
      colors: [
        const Color(0xFF7C4DFF),
        const Color(0xFF9C88FF),
        const Color(0xFFFF6B6B),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawPath(path, paint);
    
    // 신뢰도에 따른 투명도로 그림자 효과
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    for (int i = 1; i < pitchData.length; i++) {
      final point = pitchData[i];
      glowPaint.color = const Color(0xFF7C4DFF).withOpacity(point.confidence * 0.3);
      
      final x = _timeToX(point.time, size);
      final y = _frequencyToY(point.frequency, size);
      
      if (i > 0) {
        final prevPoint = pitchData[i - 1];
        final prevX = _timeToX(prevPoint.time, size);
        final prevY = _frequencyToY(prevPoint.frequency, size);
        
        canvas.drawLine(Offset(prevX, prevY), Offset(x, y), glowPaint);
      }
    }
  }
  
  void _drawCurrentPoint(Canvas canvas, Size size) {
    if (pitchData.isEmpty) return;
    
    final lastPoint = pitchData.last;
    final x = _timeToX(lastPoint.time, size);
    final y = _frequencyToY(lastPoint.frequency, size);
    
    // 펄스 애니메이션 효과
    final pulseRadius = 8 + animationValue * 4;
    
    // 외부 원 (펄스)
    final pulsePaint = Paint()
      ..color = const Color(0xFF7C4DFF).withOpacity(1 - animationValue)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(x, y), pulseRadius, pulsePaint);
    
    // 내부 원
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(x, y), 6, centerPaint);
    
    final borderPaint = Paint()
      ..color = const Color(0xFF7C4DFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(Offset(x, y), 6, borderPaint);
    
    // 현재 주파수 표시
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${lastPoint.frequency.round()}Hz',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x - 20, y - 25));
  }
  
  double _frequencyToY(double frequency, Size size) {
    // 주파수 범위: 100Hz ~ 800Hz
    const minFreq = 100.0;
    const maxFreq = 800.0;
    
    final normalized = (frequency - minFreq) / (maxFreq - minFreq);
    return size.height - (normalized * size.height);
  }
  
  double _timeToX(double time, Size size) {
    // 시간 범위: 0 ~ 10초
    const maxTime = 10.0;
    return (time / maxTime) * size.width;
  }
  
  @override
  bool shouldRepaint(PitchGraphPainter oldDelegate) {
    return oldDelegate.pitchData != pitchData ||
           oldDelegate.animationValue != animationValue;
  }
}