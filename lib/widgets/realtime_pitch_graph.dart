import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../widgets/recording_flow_modal.dart';
import '../theme/pitch_colors.dart';

class RealtimePitchGraph extends StatefulWidget {
  final List<PitchPoint> pitchData;
  final bool isPlaying;
  final double? currentTime; // 현재 재생 시간
  
  const RealtimePitchGraph({
    Key? key,
    required this.pitchData,
    required this.isPlaying,
    this.currentTime,
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
      duration: const Duration(milliseconds: 1200), // 더 부드러운 펄스 애니메이션
      vsync: this,
    );
    
    if (widget.isPlaying) {
      _animationController.repeat(reverse: true);
    }
  }
  
  @override
  void didUpdateWidget(RealtimePitchGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _animationController.repeat(reverse: true);
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
    return Container(
      decoration: BoxDecoration(
        gradient: PitchColors.nikeBackground(),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: PitchColors.electricBlue.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return CustomPaint(
            painter: NikePitchGraphPainter(
              pitchData: widget.pitchData,
              animationValue: _animationController.value,
              isPlaying: widget.isPlaying,
              currentTime: widget.currentTime,
            ),
          );
        },
      ),
    );
  }
}

class NikePitchGraphPainter extends CustomPainter {
  final List<PitchPoint> pitchData;
  final double animationValue;
  final bool isPlaying;
  final double? currentTime;
  
  NikePitchGraphPainter({
    required this.pitchData,
    required this.animationValue,
    required this.isPlaying,
    this.currentTime,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Add padding to prevent overlapping
    const double leftPadding = 50;
    const double rightPadding = 20;
    const double topPadding = 30;
    const double bottomPadding = 40;
    
    final graphArea = Rect.fromLTRB(
      leftPadding, 
      topPadding, 
      size.width - rightPadding, 
      size.height - bottomPadding
    );
    
    // 배경 그리드 그리기
    _drawGrid(canvas, graphArea);
    
    // 음정 노트 레이블 (왼쪽)
    _drawNoteLabels(canvas, graphArea);
    
    // 시간 레이블 (하단)
    _drawTimeLabels(canvas, graphArea, size);
    
    // 피치 곡선 그리기
    if (pitchData.isNotEmpty) {
      _drawPitchCurve(canvas, graphArea);
    }
    
    // 현재 피치 포인트 강조
    if (pitchData.isNotEmpty) {
      _drawCurrentPoint(canvas, graphArea);
    }
  }
  
  void _drawGrid(Canvas canvas, Rect graphArea) {
    // Nike-style minimal grid with neon accents
    final subtleGridPaint = Paint()
      ..color = PitchColors.electricBlue.withOpacity(0.1)
      ..strokeWidth = 0.5;
    
    final accentGridPaint = Paint()
      ..color = PitchColors.electricBlue.withOpacity(0.3)
      ..strokeWidth = 1.5;
    
    // Main pitch levels - only show key notes to avoid clutter
    const noteFrequencies = [
      {'freq': 220, 'note': 'A3'}, // 라
      {'freq': 262, 'note': 'C4'}, // 도 (중앙 도)
      {'freq': 330, 'note': 'E4'}, // 미
      {'freq': 440, 'note': 'A4'}, // 라 (기준음)
      {'freq': 523, 'note': 'C5'}, // 도
      {'freq': 659, 'note': 'E5'}, // 미
    ];
    
    for (final noteInfo in noteFrequencies) {
      final freq = (noteInfo['freq'] as num).toDouble();
      final y = _frequencyToY(freq, graphArea);
      final paint = freq == 440.0 ? accentGridPaint : subtleGridPaint;
      
      canvas.drawLine(
        Offset(graphArea.left, y),
        Offset(graphArea.right, y),
        paint,
      );
    }
    
    // Minimal time grid lines
    const timeIntervals = [0, 2.5, 5, 7.5, 10];
    for (final timeSeconds in timeIntervals) {
      final x = _timeToX(timeSeconds.toDouble(), graphArea);
      final paint = timeSeconds == 0 || timeSeconds == 10 ? accentGridPaint : subtleGridPaint;
      
      canvas.drawLine(
        Offset(x, graphArea.top),
        Offset(x, graphArea.bottom),
        paint,
      );
    }
  }
  
  void _drawNoteLabels(Canvas canvas, Rect graphArea) {
    const notes = [
      {'freq': 220, 'note': 'A3'},
      {'freq': 262, 'note': 'C4'},
      {'freq': 330, 'note': 'E4'},
      {'freq': 440, 'note': 'A4'}, // 기준음
      {'freq': 523, 'note': 'C5'},
      {'freq': 659, 'note': 'E5'},
    ];
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    for (final note in notes) {
      final freq = (note['freq'] as int).toDouble();
      final y = _frequencyToY(freq, graphArea);
      
      // Nike-style reference note highlighting
      final isReference = freq == 440.0;
      
      textPainter.text = TextSpan(
        text: '${note['note']} ${freq.round()}Hz',
        style: TextStyle(
          color: isReference 
              ? PitchColors.electricBlue
              : Colors.white.withOpacity(0.8),
          fontSize: isReference ? 12 : 10,
          fontWeight: isReference ? FontWeight.bold : FontWeight.w600,
          fontFamily: 'SF Pro Display',
        ),
      );
      textPainter.layout();
      
      // Position label on the left side with proper spacing
      const double labelX = 8;
      final double labelY = y - textPainter.height / 2;
      
      // Nike-style label backgrounds with neon accent
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelX - 6, 
          labelY - 3, 
          textPainter.width + 12, 
          textPainter.height + 6
        ),
        const Radius.circular(8),
      );
      final bgPaint = Paint()
        ..color = isReference 
            ? PitchColors.electricBlue.withOpacity(0.15)
            : PitchColors.cardDark.withOpacity(0.8)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(bgRect, bgPaint);
      
      textPainter.paint(canvas, Offset(labelX, labelY));
    }
  }
  
  void _drawTimeLabels(Canvas canvas, Rect graphArea, Size size) {
    final timePainter = TextPainter(textDirection: TextDirection.ltr);
    const timeIntervals = [0, 2.5, 5, 7.5, 10];
    
    for (final timeSeconds in timeIntervals) {
      final x = _timeToX(timeSeconds.toDouble(), graphArea);
      
      timePainter.text = TextSpan(
        text: '${timeSeconds == timeSeconds.toInt() ? timeSeconds.toInt() : timeSeconds}s',
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      timePainter.layout();
      
      // Position at bottom with proper spacing
      final labelX = x - timePainter.width / 2;
      final labelY = size.height - 25;
      
      // Background for better readability
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelX - 4, 
          labelY - 2, 
          timePainter.width + 8, 
          timePainter.height + 4
        ),
        const Radius.circular(3),
      );
      final bgPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(bgRect, bgPaint);
      
      timePainter.paint(canvas, Offset(labelX, labelY));
    }
  }
  
  void _drawPitchCurve(Canvas canvas, Rect graphArea) {
    if (pitchData.length < 2) return;
    
    final path = Path();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    // 첫 점으로 이동
    final firstPoint = pitchData.first;
    final firstX = _timeToX(firstPoint.time, graphArea);
    final firstY = _frequencyToY(firstPoint.frequency, graphArea);
    path.moveTo(firstX, firstY);
    
    // 나머지 점들 연결 - 부드러운 곡선
    for (int i = 1; i < pitchData.length; i++) {
      final point = pitchData[i];
      final x = _timeToX(point.time, graphArea);
      final y = _frequencyToY(point.frequency, graphArea);
      
      if (i > 0) {
        final prevPoint = pitchData[i - 1];
        final prevX = _timeToX(prevPoint.time, graphArea);
        final prevY = _frequencyToY(prevPoint.frequency, graphArea);
        
        // 부드러운 곡선을 위한 베지어 제어점
        final controlX1 = prevX + (x - prevX) * 0.5;
        final controlY1 = prevY;
        final controlX2 = x - (x - prevX) * 0.5;
        final controlY2 = y;
        
        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }
    
    // Nike Run Club style neon gradient for the pitch line
    paint.shader = PitchColors.dataVisualizationGradient().createShader(graphArea);
    
    // Add glow effect
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          PitchColors.electricBlue.withOpacity(0.3),
          PitchColors.neonGreen.withOpacity(0.3),
          PitchColors.hotPink.withOpacity(0.3),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(graphArea)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    // Draw glow first, then main line
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
    
    // 데이터 포인트 시각화
    for (int i = 0; i < pitchData.length; i++) {
      final point = pitchData[i];
      final x = _timeToX(point.time, graphArea);
      final y = _frequencyToY(point.frequency, graphArea);
      
      // 신뢰도에 따른 점 크기와 투명도
      final pointSize = 2 + (point.confidence * 2);
      final pointPaint = Paint()
        ..color = const Color(0xFF7C4DFF).withOpacity(0.3 + point.confidence * 0.7)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), pointSize, pointPaint);
    }
  }
  
  void _drawCurrentPoint(Canvas canvas, Rect graphArea) {
    if (pitchData.isEmpty) return;
    
    // 현재 시간에 해당하는 포인트 찾기
    PitchPoint currentPoint;
    
    if (currentTime != null && isPlaying) {
      // 재생 중이면 현재 시간에 가장 가까운 포인트 찾기
      currentPoint = pitchData.last; // 기본값
      double minTimeDiff = double.infinity;
      
      for (final point in pitchData) {
        final timeDiff = (point.time - currentTime!).abs();
        if (timeDiff < minTimeDiff) {
          minTimeDiff = timeDiff;
          currentPoint = point;
        }
      }
    } else {
      // 재생 중이 아니면 마지막 포인트 사용
      currentPoint = pitchData.last;
    }
    
    final x = _timeToX(currentPoint.time, graphArea);
    final y = _frequencyToY(currentPoint.frequency, graphArea);
    
    // 그래프 영역 내에서만 그리기
    if (x < graphArea.left || x > graphArea.right || y < graphArea.top || y > graphArea.bottom) {
      return;
    }
    
    // Nike-style confidence-based colors
    final confidence = currentPoint.confidence;
    final baseColor = confidence > 0.8 
        ? PitchColors.neonGreen     // High confidence - neon green
        : confidence > 0.5 
            ? PitchColors.electricBlue  // Medium confidence - electric blue
            : PitchColors.warning;      // Low confidence - orange
    
    if (isPlaying) {
      // Nike-style athletic pulse animation
      final pulseRadius = 15 + animationValue * 12;
      
      // Multi-layer glow effect for premium feel
      final outerGlowPaint = Paint()
        ..color = baseColor.withOpacity((1 - animationValue) * 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      
      canvas.drawCircle(Offset(x, y), pulseRadius, outerGlowPaint);
      
      // Inner glow ring
      final innerGlowPaint = Paint()
        ..color = baseColor.withOpacity(0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), 10, innerGlowPaint);
    }
    
    // Nike-style center indicator
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(x, y), 8, centerPaint);
    
    final borderPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawCircle(Offset(x, y), 8, borderPaint);
    
    // 현재 주파수와 음정 표시 (위쪽 여백이 있는 경우에만)
    if (y > graphArea.top + 60) {
      final noteName = _frequencyToNote(currentPoint.frequency);
      final frequencyText = '${currentPoint.frequency.round()}Hz';
      
      final textPainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: noteName,
              style: TextStyle(
                color: baseColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: '\n$frequencyText',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();
      
      // 텍스트 위치 계산 (화면 경계 고려)
      double textX = x - textPainter.width / 2;
      double textY = y - 50;
      
      // 화면 경계 체크
      if (textX < graphArea.left + 5) textX = graphArea.left + 5;
      if (textX + textPainter.width > graphArea.right - 5) {
        textX = graphArea.right - textPainter.width - 5;
      }
      
      // 텍스트 배경
      final textBgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(textX - 6, textY - 2, textPainter.width + 12, textPainter.height + 4),
        const Radius.circular(6),
      );
      final textBgPaint = Paint()
        ..color = Colors.black.withOpacity(0.8)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(textBgRect, textBgPaint);
      
      // 테두리
      final borderBgPaint = Paint()
        ..color = baseColor.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRRect(textBgRect, borderBgPaint);
      
      textPainter.paint(canvas, Offset(textX, textY));
    }
  }
  
  double _frequencyToY(double frequency, Rect graphArea) {
    // 주파수 범위: 150Hz ~ 700Hz (vocal range)
    const minFreq = 150.0;
    const maxFreq = 700.0;
    
    final clampedFreq = frequency.clamp(minFreq, maxFreq);
    final normalized = (clampedFreq - minFreq) / (maxFreq - minFreq);
    return graphArea.bottom - (normalized * graphArea.height);
  }
  
  double _timeToX(double time, Rect graphArea) {
    // 시간 범위: 0 ~ 10초
    const maxTime = 10.0;
    final clampedTime = time.clamp(0.0, maxTime);
    return graphArea.left + (clampedTime / maxTime) * graphArea.width;
  }
  
  String _frequencyToNote(double frequency) {
    // A4 = 440Hz를 기준으로 계산
    const double a4 = 440.0;
    const List<String> noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    
    // 주파수가 너무 낮거나 높으면 빈 문자열 반환
    if (frequency < 80 || frequency > 2000) return '';
    
    // A4(440Hz)로부터 몇 개의 반음(semitone) 떨어져 있는지 계산
    final double semitonesFromA4 = 12 * (math.log(frequency / a4) / math.ln2);
    final int semitoneIndex = semitonesFromA4.round();
    
    // A4는 인덱스 9 (A)
    final int noteIndex = (9 + semitoneIndex) % 12;
    final int octave = 4 + ((9 + semitoneIndex) ~/ 12);
    
    // 음정 이름과 옥타브 조합
    final String noteName = noteNames[noteIndex < 0 ? noteIndex + 12 : noteIndex];
    return '$noteName$octave';
  }
  
  @override
  bool shouldRepaint(NikePitchGraphPainter oldDelegate) {
    return oldDelegate.pitchData != pitchData ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.currentTime != currentTime ||
           oldDelegate.isPlaying != isPlaying;
  }
}