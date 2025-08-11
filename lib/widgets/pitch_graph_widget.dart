import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/pitch_analysis_service.dart';

/// 시간별 피치 그래프 위젯
class PitchGraphWidget extends StatefulWidget {
  final List<PitchDataPoint> pitchData;
  final double width;
  final double height;
  final bool showNoteLines;
  final bool showVibrato;
  final Color primaryColor;
  final Color backgroundColor;

  const PitchGraphWidget({
    super.key,
    required this.pitchData,
    this.width = 350,
    this.height = 200,
    this.showNoteLines = true,
    this.showVibrato = true,
    this.primaryColor = const Color(0xFF007AFF),
    this.backgroundColor = const Color(0xFF1C1C1E),
  });

  @override
  State<PitchGraphWidget> createState() => _PitchGraphWidgetState();
}

class _PitchGraphWidgetState extends State<PitchGraphWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
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
    if (widget.pitchData.isEmpty) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.graphic_eq, size: 48, color: Colors.white38),
              SizedBox(height: 12),
              Text(
                '피치 데이터 없음',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // 헤더
          _buildHeader(),
          
          // 그래프
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(widget.width - 32, widget.height - 80),
                    painter: PitchGraphPainter(
                      pitchData: widget.pitchData,
                      progress: _animation.value,
                      showNoteLines: widget.showNoteLines,
                      primaryColor: widget.primaryColor,
                    ),
                  );
                },
              ),
            ),
          ),
          
          // 하단 정보
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final stats = PitchAnalysisService.getPitchStatistics(widget.pitchData);
    final avgFreq = stats['averageFrequency'] as double;
    final stability = stats['stability'] as double;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.primaryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.show_chart, color: widget.primaryColor, size: 20),
          const SizedBox(width: 8),
          Text(
            '피치 분석 그래프',
            style: TextStyle(
              color: widget.primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '평균: ${avgFreq.toStringAsFixed(1)}Hz',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          _buildStabilityIndicator(stability),
        ],
      ),
    );
  }

  Widget _buildStabilityIndicator(double stability) {
    Color color = Colors.red;
    String label = '불안정';
    
    if (stability > 0.8) {
      color = Colors.green;
      label = '매우 안정';
    } else if (stability > 0.6) {
      color = Colors.blue;
      label = '안정';
    } else if (stability > 0.4) {
      color = Colors.orange;
      label = '보통';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final stats = PitchAnalysisService.getPitchStatistics(widget.pitchData);
    final duration = stats['totalDuration'] as double;
    final stablePercentage = stats['stablePercentage'] as double;
    final freqRange = stats['frequencyRange'] as double;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem('시간', '${duration.toStringAsFixed(1)}s'),
          _buildStatItem('안정도', '${(stablePercentage * 100).toStringAsFixed(0)}%'),
          _buildStatItem('음역대', '${freqRange.toStringAsFixed(0)}Hz'),
          _buildStatItem('포인트', '${widget.pitchData.length}개'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: widget.primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

/// 피치 그래프 페인터
class PitchGraphPainter extends CustomPainter {
  final List<PitchDataPoint> pitchData;
  final double progress;
  final bool showNoteLines;
  final Color primaryColor;

  PitchGraphPainter({
    required this.pitchData,
    required this.progress,
    required this.showNoteLines,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pitchData.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill;

    // 배경 그리드
    _drawGrid(canvas, size);
    
    // 노트 가이드라인
    if (showNoteLines) {
      _drawNoteLines(canvas, size);
    }
    
    // 피치 곡선
    _drawPitchCurve(canvas, size, paint);
    
    // 신뢰도 영역
    _drawConfidenceArea(canvas, size, fillPaint);
    
    // 불안정한 구간 표시
    _drawUnstableRegions(canvas, size, fillPaint);
    
    // 현재 진행 표시선
    _drawProgressLine(canvas, size, paint);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5;

    // 세로 선 (시간축)
    for (int i = 0; i <= 10; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    // 가로 선 (주파수축)
    for (int i = 0; i <= 8; i++) {
      final y = size.height * i / 8;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
  }

  void _drawNoteLines(Canvas canvas, Size size) {
    // 주요 음계 주파수 (C4, D4, E4, F4, G4, A4, B4, C5 등)
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

    final noteNames = ['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5'];
    
    final frequencies = pitchData.map((p) => p.frequency).toList();
    if (frequencies.isEmpty) return;
    
    final minFreq = frequencies.reduce(math.min);
    final maxFreq = frequencies.reduce(math.max);
    double freqRange = maxFreq - minFreq;
    
    // 주파수 범위가 너무 작은 경우 조정
    double adjustedMinFreq = minFreq;
    double adjustedMaxFreq = maxFreq;
    
    if (freqRange < 50) {
      final centerFreq = (minFreq + maxFreq) / 2;
      adjustedMinFreq = centerFreq - 25;
      adjustedMaxFreq = centerFreq + 25;
      freqRange = 50;
    }

    final notePaint = Paint()
      ..color = primaryColor.withOpacity(0.3)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < noteFrequencies.length; i++) {
      final freq = noteFrequencies[i];
      if (freq >= adjustedMinFreq && freq <= adjustedMaxFreq) {
        final y = size.height - (freq - adjustedMinFreq) / freqRange * size.height;
        
        // 노트 라인
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          notePaint,
        );

        // 노트 이름
        textPainter.text = TextSpan(
          text: noteNames[i],
          style: TextStyle(
            color: primaryColor.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(4, y - 12));
      }
    }
  }

  void _drawPitchCurve(Canvas canvas, Size size, Paint paint) {
    if (pitchData.length < 2) return;

    final frequencies = pitchData.map((p) => p.frequency).toList();
    if (frequencies.isEmpty) return;
    
    final minFreq = frequencies.reduce(math.min);
    final maxFreq = frequencies.reduce(math.max);
    final freqRange = maxFreq - minFreq;
    
    // 주파수 범위가 너무 작으면 최소 범위 설정
    if (freqRange < 50) {
      final centerFreq = (minFreq + maxFreq) / 2;
      final adjustedMinFreq = centerFreq - 25;
      final adjustedMaxFreq = centerFreq + 25;
      return _drawPitchCurveWithRange(canvas, size, paint, adjustedMinFreq, adjustedMaxFreq);
    }
    
    final minTime = pitchData.first.timeSeconds;
    final maxTime = pitchData.last.timeSeconds;
    final timeRange = maxTime - minTime;
    
    // 시간 범위가 0이면 그리지 않음
    if (timeRange <= 0) return;

    final path = Path();
    final gradientPath = Path();
    bool isFirstPoint = true;

    final visiblePoints = (pitchData.length * progress).round();
    
    for (int i = 0; i < visiblePoints && i < pitchData.length; i++) {
      final point = pitchData[i];
      
      final x = (point.timeSeconds - minTime) / timeRange * size.width;
      final y = size.height - (point.frequency - minFreq) / freqRange * size.height;
      
      // 신뢰도에 따른 색상 조정
      final confidence = point.confidence;
      Color pointColor = primaryColor;
      
      if (confidence > 0.8) {
        pointColor = const Color(0xFF34C759); // 녹색 - 높은 신뢰도
      } else if (confidence > 0.6) {
        pointColor = primaryColor; // 파랑 - 보통 신뢰도
      } else if (confidence > 0.4) {
        pointColor = const Color(0xFFFF9500); // 주황 - 낮은 신뢰도
      } else {
        pointColor = const Color(0xFFFF3B30); // 빨강 - 매우 낮은 신뢰도
      }

      paint.color = pointColor;
      
      if (isFirstPoint) {
        path.moveTo(x, y);
        gradientPath.moveTo(x, size.height);
        gradientPath.lineTo(x, y);
        isFirstPoint = false;
      } else {
        path.lineTo(x, y);
        gradientPath.lineTo(x, y);
      }
      
      // 안정적인 포인트에 더 큰 점 그리기
      if (point.isStable) {
        canvas.drawCircle(Offset(x, y), 2, Paint()..color = pointColor);
      }
    }

    // 메인 곡선 그리기
    paint
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    
    canvas.drawPath(path, paint);
    
    // 그라데이션 채우기
    gradientPath.lineTo(
      (pitchData[math.min(visiblePoints - 1, pitchData.length - 1)].timeSeconds - minTime) / timeRange * size.width,
      size.height,
    );
    gradientPath.close();
    
    final gradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withOpacity(0.3),
          primaryColor.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawPath(gradientPath, gradient);
  }

  void _drawPitchCurveWithRange(Canvas canvas, Size size, Paint paint, double minFreq, double maxFreq) {
    final freqRange = maxFreq - minFreq;
    if (freqRange <= 0) return;
    
    final minTime = pitchData.first.timeSeconds;
    final maxTime = pitchData.last.timeSeconds;
    final timeRange = maxTime - minTime;
    if (timeRange <= 0) return;

    final path = Path();
    final gradientPath = Path();
    bool isFirstPoint = true;

    final visiblePoints = (pitchData.length * progress).round();
    
    for (int i = 0; i < visiblePoints && i < pitchData.length; i++) {
      final point = pitchData[i];
      
      final x = (point.timeSeconds - minTime) / timeRange * size.width;
      final y = size.height - (point.frequency - minFreq) / freqRange * size.height;
      
      // 신뢰도에 따른 색상 조정
      final confidence = point.confidence;
      Color pointColor = primaryColor;
      
      if (confidence > 0.8) {
        pointColor = const Color(0xFF34C759); // 녹색
      } else if (confidence > 0.6) {
        pointColor = primaryColor; // 파랑
      } else if (confidence > 0.4) {
        pointColor = const Color(0xFFFF9500); // 주황
      } else {
        pointColor = const Color(0xFFFF3B30); // 빨강
      }

      paint.color = pointColor;
      
      if (isFirstPoint) {
        path.moveTo(x, y);
        gradientPath.moveTo(x, size.height);
        gradientPath.lineTo(x, y);
        isFirstPoint = false;
      } else {
        path.lineTo(x, y);
        gradientPath.lineTo(x, y);
      }
      
      // 안정적인 포인트에 더 큰 점 그리기
      if (point.isStable) {
        canvas.drawCircle(Offset(x, y), 2, Paint()..color = pointColor);
      }
    }

    // 메인 곡선 그리기
    paint
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    
    canvas.drawPath(path, paint);
    
    // 그라데이션 채우기
    gradientPath.lineTo(
      (pitchData[math.min(visiblePoints - 1, pitchData.length - 1)].timeSeconds - minTime) / timeRange * size.width,
      size.height,
    );
    gradientPath.close();
    
    final gradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withOpacity(0.3),
          primaryColor.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawPath(gradientPath, gradient);
  }

  void _drawConfidenceArea(Canvas canvas, Size size, Paint paint) {
    // 신뢰도가 낮은 구간을 음영으로 표시
    final minTime = pitchData.first.timeSeconds;
    final maxTime = pitchData.last.timeSeconds;
    final timeRange = maxTime - minTime;

    paint.color = Colors.red.withOpacity(0.1);
    
    for (int i = 0; i < pitchData.length - 1; i++) {
      final point = pitchData[i];
      if (point.confidence < 0.4) {
        final x1 = (point.timeSeconds - minTime) / timeRange * size.width;
        final x2 = (pitchData[i + 1].timeSeconds - minTime) / timeRange * size.width;
        
        canvas.drawRect(
          Rect.fromLTRB(x1, 0, x2, size.height),
          paint,
        );
      }
    }
  }

  void _drawUnstableRegions(Canvas canvas, Size size, Paint paint) {
    // 불안정한 구간을 점선으로 표시
    final minTime = pitchData.first.timeSeconds;
    final maxTime = pitchData.last.timeSeconds;
    final timeRange = maxTime - minTime;

    paint
      ..color = Colors.orange.withOpacity(0.5)
      ..strokeWidth = 1;

    for (final point in pitchData) {
      if (!point.isStable) {
        final x = (point.timeSeconds - minTime) / timeRange * size.width;
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          paint,
        );
      }
    }
  }

  void _drawProgressLine(Canvas canvas, Size size, Paint paint) {
    final progressX = size.width * progress;
    
    paint
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(progressX, 0),
      Offset(progressX, size.height),
      paint,
    );
    
    // 진행 표시 점
    canvas.drawCircle(
      Offset(progressX, size.height / 2),
      4,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant PitchGraphPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.pitchData != pitchData ||
           oldDelegate.primaryColor != primaryColor;
  }
}