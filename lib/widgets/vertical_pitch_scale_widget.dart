import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/pitch_analysis_service.dart'; // PitchDataPoint import

/// 🎼 세로 음계 스케일 위젯
/// 
/// 사용자가 제공한 이미지 스타일의 세로 음계 표시 + 분석된 음정 시각화
class VerticalPitchScaleWidget extends StatelessWidget {
  final List<PitchDataPoint> pitchData;
  final double width;
  final double height;
  final Color primaryColor;
  final Color backgroundColor;

  const VerticalPitchScaleWidget({
    Key? key,
    required this.pitchData,
    this.width = 300,
    this.height = 400,
    this.primaryColor = const Color(0xFF5B8DEE),
    this.backgroundColor = const Color(0xFFF5F5F7),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CustomPaint(
        painter: VerticalPitchScalePainter(
          pitchData: pitchData,
          primaryColor: primaryColor,
        ),
        size: Size(width, height),
      ),
    );
  }
}

/// 🎨 세로 음계 스케일 페인터
class VerticalPitchScalePainter extends CustomPainter {
  final List<PitchDataPoint> pitchData;
  final Color primaryColor;

  // 표시할 음계 범위 (3옥타브)
  static const List<String> noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];
  
  // 표시할 옥타브 범위
  static const int minOctave = 3;  // C3부터
  static const int maxOctave = 6;  // B6까지

  VerticalPitchScalePainter({
    required this.pitchData,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final leftMargin = 50.0;
    final rightMargin = 30.0;
    final topMargin = 20.0;
    final bottomMargin = 20.0;
    
    final scaleWidth = size.width - leftMargin - rightMargin;
    final scaleHeight = size.height - topMargin - bottomMargin;

    // 음계 라인 그리기
    _drawNoteLines(canvas, size, leftMargin, topMargin, scaleWidth, scaleHeight);
    
    // 음계 이름 표시
    _drawNoteLabels(canvas, size, leftMargin, topMargin, scaleHeight);
    
    // 분석된 음정 표시 ("Mum" 스타일)
    _drawDetectedNotes(canvas, size, leftMargin, topMargin, scaleWidth, scaleHeight);
    
    // 멜로디 라인 그리기
    _drawMelodyLine(canvas, size, leftMargin, topMargin, scaleWidth, scaleHeight);
  }

  /// 음계 라인 그리기
  void _drawNoteLines(Canvas canvas, Size size, double leftMargin, double topMargin, double scaleWidth, double scaleHeight) {
    final noteCount = (maxOctave - minOctave + 1) * 12;
    final lineSpacing = scaleHeight / noteCount;
    
    final linePaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..strokeWidth = 0.5;
    
    final majorLinePaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= noteCount; i++) {
      final y = topMargin + (i * lineSpacing);
      final noteIndex = i % 12;
      final isWhiteKey = ![1, 3, 6, 8, 10].contains(noteIndex); // C, D, E, F, G, A, B
      
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(leftMargin + scaleWidth, y),
        isWhiteKey ? majorLinePaint : linePaint,
      );
    }
  }

  /// 음계 이름 라벨
  void _drawNoteLabels(Canvas canvas, Size size, double leftMargin, double topMargin, double scaleHeight) {
    final noteCount = (maxOctave - minOctave + 1) * 12;
    final lineSpacing = scaleHeight / noteCount;

    for (int octave = maxOctave; octave >= minOctave; octave--) {
      for (int noteIndex = 11; noteIndex >= 0; noteIndex--) {
        final globalIndex = ((maxOctave - octave) * 12) + (11 - noteIndex);
        final y = topMargin + (globalIndex * lineSpacing);
        final noteName = noteNames[noteIndex];
        final isWhiteKey = ![1, 3, 6, 8, 10].contains(noteIndex);
        
        // 흰건반만 라벨 표시 (가독성)
        if (isWhiteKey) {
          _drawText(
            canvas,
            '$noteName$octave',
            Offset(10, y - 8),
            Color(0xFF1D1D1F).withOpacity(0.7),
            12,
          );
        }
      }
    }
  }

  /// 감지된 음정 표시 (정교한 음정 분석 결과)
  void _drawDetectedNotes(Canvas canvas, Size size, double leftMargin, double topMargin, double scaleWidth, double scaleHeight) {
    if (pitchData.isEmpty) return;

    final noteCount = (maxOctave - minOctave + 1) * 12;
    final lineSpacing = scaleHeight / noteCount;
    final totalDuration = pitchData.isNotEmpty ? pitchData.last.timeSeconds : 1.0;
    
    // 시간대별로 그룹화하여 더 정교한 분석
    final timeSlots = <double, List<PitchDataPoint>>{};
    final slotDuration = 0.1; // 100ms 단위로 그룹화
    
    for (final pitch in pitchData) {
      if (pitch.frequency < 80 || pitch.confidence < 0.3) continue;
      
      final slot = (pitch.timeSeconds / slotDuration).floor() * slotDuration;
      timeSlots[slot] ??= [];
      timeSlots[slot]!.add(pitch);
    }
    
    // 각 시간 슬롯의 대표 음정 계산
    for (final entry in timeSlots.entries) {
      final slot = entry.key;
      final pitches = entry.value;
      
      if (pitches.isEmpty) continue;
      
      // 가중 평균으로 대표 주파수 계산 (신뢰도 가중치)
      double weightedFreq = 0.0;
      double totalWeight = 0.0;
      double maxConfidence = 0.0;
      
      for (final pitch in pitches) {
        final weight = pitch.confidence;
        weightedFreq += pitch.frequency * weight;
        totalWeight += weight;
        maxConfidence = math.max(maxConfidence, pitch.confidence);
      }
      
      if (totalWeight == 0) continue;
      
      final avgFrequency = weightedFreq / totalWeight;
      final notePosition = _frequencyToNotePosition(avgFrequency);
      
      if (notePosition < 0 || notePosition >= noteCount) continue;
      
      final y = topMargin + (notePosition * lineSpacing);
      final x = leftMargin + (slot / totalDuration) * scaleWidth;
      
      // 음정 정확도에 따른 시각화
      _drawPreciseNoteMarker(canvas, Offset(x, y), avgFrequency, maxConfidence, pitches.length);
    }
  }

  /// 정교한 음정 마커 그리기
  void _drawPreciseNoteMarker(Canvas canvas, Offset position, double frequency, double confidence, int dataPoints) {
    // 음정 정확도 계산
    final noteName = _getNoteName(frequency);
    final isAccurate = confidence > 0.7;
    
    // 신뢰도와 정확도에 따른 색상 및 크기
    Color markerColor;
    double size;
    
    if (confidence > 0.8) {
      markerColor = const Color(0xFF34C759); // 높은 신뢰도: 초록
      size = 8.0;
    } else if (confidence > 0.6) {
      markerColor = const Color(0xFF007AFF); // 중간 신뢰도: 파랑
      size = 6.0;
    } else {
      markerColor = const Color(0xFFFF9500); // 낮은 신뢰도: 주황
      size = 4.0;
    }
    
    // 데이터 포인트 수에 따른 투명도 (더 많은 데이터 = 더 진한 색)
    final opacity = (dataPoints / 10.0).clamp(0.3, 1.0);
    
    // 원형 마커
    final markerPaint = Paint()
      ..color = markerColor.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(position, size, markerPaint);
    
    // 테두리
    final borderPaint = Paint()
      ..color = markerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    canvas.drawCircle(position, size, borderPaint);
    
    // 음정 이름 표시 (높은 신뢰도일 때만)
    if (confidence > 0.7) {
      _drawText(
        canvas,
        noteName,
        Offset(position.dx + size + 4, position.dy - 6),
        markerColor,
        10,
        FontWeight.w600,
      );
    }
  }
  
  /// 주파수를 음정 이름으로 변환
  String _getNoteName(double frequency) {
    if (frequency < 80) return '';
    
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final a4 = 440.0;
    final c0 = a4 * math.pow(2, -4.75);
    
    if (frequency <= c0) return '';
    
    final h = 12 * (math.log(frequency / c0) / math.ln2);
    final octave = (h / 12).floor();
    final noteIndex = (h % 12).round() % 12;
    
    return '${notes[noteIndex]}$octave';
  }

  /// 멜로디 라인 그리기
  void _drawMelodyLine(Canvas canvas, Size size, double leftMargin, double topMargin, double scaleWidth, double scaleHeight) {
    if (pitchData.length < 2) return;

    final noteCount = (maxOctave - minOctave + 1) * 12;
    final lineSpacing = scaleHeight / noteCount;
    final totalDuration = pitchData.last.timeSeconds;
    
    final path = Path();
    final linePaint = Paint()
      ..color = const Color(0xFFFF6B9D) // 분홍색 멜로디 라인
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    bool isFirstPoint = true;
    
    for (final pitch in pitchData) {
      if (pitch.frequency < 80 || pitch.confidence < 0.5) continue;
      
      final notePosition = _frequencyToNotePosition(pitch.frequency);
      if (notePosition < 0 || notePosition >= noteCount) continue;
      
      final x = leftMargin + (pitch.timeSeconds / totalDuration) * scaleWidth;
      final y = topMargin + (notePosition * lineSpacing);
      
      if (isFirstPoint) {
        path.moveTo(x, y);
        isFirstPoint = false;
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, linePaint);
  }

  /// 주파수를 음계 위치로 변환 (0 = 최고음, noteCount = 최저음)
  double _frequencyToNotePosition(double frequency) {
    final c3Frequency = 130.81; // C3 주파수
    const totalSemitones = (maxOctave - minOctave + 1) * 12;
    
    // 주파수를 semitone으로 변환
    final semitones = 12 * (math.log(frequency / c3Frequency) / math.ln2);
    
    // 위치 계산 (높은 음이 위쪽)
    return totalSemitones - semitones;
  }

  /// 텍스트 그리기 헬퍼
  void _drawText(Canvas canvas, String text, Offset position, Color color, double fontSize, [FontWeight? fontWeight]) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight ?? FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(VerticalPitchScalePainter oldDelegate) {
    return oldDelegate.pitchData != pitchData ||
           oldDelegate.primaryColor != primaryColor;
  }
}

/// PitchDataPoint는 기존 pitch_analysis_service.dart에서 import됨