import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

/// 2D 해부학적 보컬 가이드 시각화
class Anatomical2DVisualizer extends StatefulWidget {
  final double pitchValue;
  final double breathingIntensity;
  final String resonancePosition;
  final bool isVocalizing;
  final Map<String, double> formants;

  const Anatomical2DVisualizer({
    super.key,
    this.pitchValue = 0.0,
    this.breathingIntensity = 0.0,
    this.resonancePosition = 'throat',
    this.isVocalizing = false,
    this.formants = const {},
  });

  @override
  State<Anatomical2DVisualizer> createState() => _Anatomical2DVisualizerState();
}

class _Anatomical2DVisualizerState extends State<Anatomical2DVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _vocalCordsController;
  late AnimationController _resonanceController;
  
  late Animation<double> _breathingAnimation;
  late Animation<double> _vocalCordsAnimation;
  late Animation<double> _resonanceAnimation;

  @override
  void initState() {
    super.initState();
    
    // 호흡 애니메이션 (들숨/날숨)
    _breathingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    
    _breathingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));
    
    // 성대 진동 애니메이션
    _vocalCordsController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    );
    
    _vocalCordsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_vocalCordsController);
    
    // 공명 위치 애니메이션
    _resonanceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _resonanceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _resonanceController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(Anatomical2DVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 발성 상태에 따라 성대 애니메이션 제어
    if (widget.isVocalizing && !oldWidget.isVocalizing) {
      _vocalCordsController.repeat(reverse: true);
    } else if (!widget.isVocalizing && oldWidget.isVocalizing) {
      _vocalCordsController.stop();
    }
    
    // 공명 위치 변경시 애니메이션
    if (widget.resonancePosition != oldWidget.resonancePosition) {
      _resonanceController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _vocalCordsController.dispose();
    _resonanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: Listenable.merge([
            _breathingAnimation,
            _vocalCordsAnimation,
            _resonanceAnimation,
          ]),
          builder: (context, child) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: VocalAnatomyPainter(
                breathingPhase: _breathingAnimation.value,
                vocalCordsVibration: widget.isVocalizing ? _vocalCordsAnimation.value : 0.0,
                resonancePosition: widget.resonancePosition,
                resonanceIntensity: _resonanceAnimation.value,
                pitchValue: widget.pitchValue,
                formants: widget.formants,
              ),
            );
          },
        );
      },
    );
  }
}

/// 보컬 해부학 그리기 클래스
class VocalAnatomyPainter extends CustomPainter {
  final double breathingPhase;
  final double vocalCordsVibration;
  final String resonancePosition;
  final double resonanceIntensity;
  final double pitchValue;
  final Map<String, double> formants;

  VocalAnatomyPainter({
    required this.breathingPhase,
    required this.vocalCordsVibration,
    required this.resonancePosition,
    required this.resonanceIntensity,
    required this.pitchValue,
    required this.formants,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // 배경
    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(centerX, centerY),
        size.width * 0.5,
        [
          Colors.blue.shade900.withOpacity(0.1),
          Colors.black.withOpacity(0.3),
        ],
        [0.0, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    // 1. 폐와 횡격막 그리기
    _drawLungsAndDiaphragm(canvas, size, centerX, centerY);
    
    // 2. 기도와 후두 그리기
    _drawAirwayAndLarynx(canvas, size, centerX, centerY);
    
    // 3. 성대 그리기
    _drawVocalCords(canvas, size, centerX, centerY);
    
    // 4. 구강과 비강 그리기
    _drawOralAndNasalCavity(canvas, size, centerX, centerY);
    
    // 5. 혀와 입술 그리기
    _drawTongueAndLips(canvas, size, centerX, centerY);
    
    // 6. 공명 영역 표시
    _drawResonanceAreas(canvas, size, centerX, centerY);
    
    // 7. 공기 흐름 표시
    _drawAirFlow(canvas, size, centerX, centerY);
    
    // 8. 측정값 표시
    _drawMeasurements(canvas, size);
  }

  void _drawLungsAndDiaphragm(Canvas canvas, Size size, double centerX, double centerY) {
    final lungsPaint = Paint()
      ..color = Colors.pink.shade200.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    final lungsOutline = Paint()
      ..color = Colors.pink.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // 좌우 폐
    final lungWidth = size.width * 0.25;
    final lungHeight = size.height * 0.3;
    final lungY = centerY + size.height * 0.15;
    
    // 호흡에 따른 확장/수축
    final expansionFactor = 1.0 + (breathingPhase * 0.15);
    
    // 왼쪽 폐
    final leftLung = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX - lungWidth * 0.7, lungY),
        width: lungWidth * expansionFactor,
        height: lungHeight * expansionFactor,
      ),
      const Radius.circular(20),
    );
    
    // 오른쪽 폐
    final rightLung = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX + lungWidth * 0.7, lungY),
        width: lungWidth * expansionFactor,
        height: lungHeight * expansionFactor,
      ),
      const Radius.circular(20),
    );
    
    canvas.drawRRect(leftLung, lungsPaint);
    canvas.drawRRect(rightLung, lungsPaint);
    canvas.drawRRect(leftLung, lungsOutline);
    canvas.drawRRect(rightLung, lungsOutline);
    
    // 횡격막
    final diaphragmPath = Path();
    final diaphragmY = lungY + lungHeight * 0.6 + (breathingPhase * 20);
    
    diaphragmPath.moveTo(centerX - size.width * 0.35, diaphragmY);
    diaphragmPath.quadraticBezierTo(
      centerX, diaphragmY - 20,
      centerX + size.width * 0.35, diaphragmY,
    );
    
    canvas.drawPath(
      diaphragmPath,
      Paint()
        ..color = Colors.red.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
  }

  void _drawAirwayAndLarynx(Canvas canvas, Size size, double centerX, double centerY) {
    final airwayPaint = Paint()
      ..color = Colors.cyan.shade100.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    final airwayOutline = Paint()
      ..color = Colors.cyan.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // 기도 경로
    final airwayPath = Path();
    final startY = centerY + size.height * 0.35;
    final endY = centerY - size.height * 0.1;
    
    airwayPath.moveTo(centerX - 15, startY);
    airwayPath.lineTo(centerX - 15, endY);
    airwayPath.quadraticBezierTo(
      centerX - 15, endY - 20,
      centerX - 25, endY - 30,
    );
    airwayPath.lineTo(centerX - 25, centerY - size.height * 0.35);
    airwayPath.lineTo(centerX + 25, centerY - size.height * 0.35);
    airwayPath.lineTo(centerX + 25, endY - 30);
    airwayPath.quadraticBezierTo(
      centerX + 15, endY - 20,
      centerX + 15, endY,
    );
    airwayPath.lineTo(centerX + 15, startY);
    airwayPath.close();
    
    canvas.drawPath(airwayPath, airwayPaint);
    canvas.drawPath(airwayPath, airwayOutline);
    
    // 후두 영역 강조
    final larynxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY - size.height * 0.05),
        width: 40,
        height: 30,
      ),
      const Radius.circular(10),
    );
    
    canvas.drawRRect(
      larynxRect,
      Paint()
        ..color = Colors.orange.shade200.withOpacity(0.7)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawVocalCords(Canvas canvas, Size size, double centerX, double centerY) {
    final cordsY = centerY - size.height * 0.05;
    
    // 성대 기본 형태
    final leftCordPaint = Paint()
      ..color = Colors.red.shade400
      ..style = PaintingStyle.fill;
    
    final rightCordPaint = Paint()
      ..color = Colors.red.shade400
      ..style = PaintingStyle.fill;
    
    // 진동에 따른 간격 조정
    final vibrationOffset = vocalCordsVibration * 3.0;
    final baseGap = 3.0 + (pitchValue / 100.0) * 2.0; // 음높이에 따라 간격 조정
    
    // 왼쪽 성대
    final leftCordPath = Path();
    leftCordPath.moveTo(centerX - baseGap - vibrationOffset, cordsY - 10);
    leftCordPath.quadraticBezierTo(
      centerX - baseGap - vibrationOffset - 5, cordsY,
      centerX - baseGap - vibrationOffset, cordsY + 10,
    );
    leftCordPath.lineTo(centerX - baseGap - vibrationOffset - 3, cordsY + 10);
    leftCordPath.quadraticBezierTo(
      centerX - baseGap - vibrationOffset - 8, cordsY,
      centerX - baseGap - vibrationOffset - 3, cordsY - 10,
    );
    leftCordPath.close();
    
    // 오른쪽 성대
    final rightCordPath = Path();
    rightCordPath.moveTo(centerX + baseGap + vibrationOffset, cordsY - 10);
    rightCordPath.quadraticBezierTo(
      centerX + baseGap + vibrationOffset + 5, cordsY,
      centerX + baseGap + vibrationOffset, cordsY + 10,
    );
    rightCordPath.lineTo(centerX + baseGap + vibrationOffset + 3, cordsY + 10);
    rightCordPath.quadraticBezierTo(
      centerX + baseGap + vibrationOffset + 8, cordsY,
      centerX + baseGap + vibrationOffset + 3, cordsY - 10,
    );
    rightCordPath.close();
    
    canvas.drawPath(leftCordPath, leftCordPaint);
    canvas.drawPath(rightCordPath, rightCordPaint);
    
    // 진동 시각화
    if (vocalCordsVibration > 0) {
      final vibrationPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.5 * vocalCordsVibration)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      canvas.drawCircle(
        Offset(centerX, cordsY),
        15 + vocalCordsVibration * 5,
        vibrationPaint,
      );
    }
  }

  void _drawOralAndNasalCavity(Canvas canvas, Size size, double centerX, double centerY) {
    // 구강
    final oralCavityPaint = Paint()
      ..color = Colors.purple.shade100.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final oralPath = Path();
    final oralStartY = centerY - size.height * 0.15;
    
    oralPath.moveTo(centerX - 20, oralStartY);
    oralPath.quadraticBezierTo(
      centerX - 40, oralStartY - 30,
      centerX - 50, oralStartY - 60,
    );
    oralPath.quadraticBezierTo(
      centerX - 55, oralStartY - 80,
      centerX - 40, oralStartY - 90,
    );
    oralPath.lineTo(centerX + 40, oralStartY - 90);
    oralPath.quadraticBezierTo(
      centerX + 55, oralStartY - 80,
      centerX + 50, oralStartY - 60,
    );
    oralPath.quadraticBezierTo(
      centerX + 40, oralStartY - 30,
      centerX + 20, oralStartY,
    );
    oralPath.close();
    
    canvas.drawPath(oralPath, oralCavityPaint);
    
    // 비강
    final nasalPaint = Paint()
      ..color = Colors.green.shade100.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final nasalPath = Path();
    nasalPath.moveTo(centerX - 15, oralStartY - 90);
    nasalPath.quadraticBezierTo(
      centerX, oralStartY - 110,
      centerX + 15, oralStartY - 90,
    );
    nasalPath.close();
    
    canvas.drawPath(nasalPath, nasalPaint);
  }

  void _drawTongueAndLips(Canvas canvas, Size size, double centerX, double centerY) {
    final tongueY = centerY - size.height * 0.2;
    
    // 혀
    final tonguePaint = Paint()
      ..color = Colors.pink.shade300
      ..style = PaintingStyle.fill;
    
    final tonguePath = Path();
    tonguePath.moveTo(centerX - 30, tongueY);
    tonguePath.quadraticBezierTo(
      centerX, tongueY - 20,
      centerX + 30, tongueY,
    );
    tonguePath.quadraticBezierTo(
      centerX + 20, tongueY + 10,
      centerX, tongueY + 15,
    );
    tonguePath.quadraticBezierTo(
      centerX - 20, tongueY + 10,
      centerX - 30, tongueY,
    );
    tonguePath.close();
    
    canvas.drawPath(tonguePath, tonguePaint);
    
    // 입술
    final lipsY = centerY - size.height * 0.25;
    final lipsPaint = Paint()
      ..color = Colors.red.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    // 상순
    final upperLipPath = Path();
    upperLipPath.moveTo(centerX - 40, lipsY);
    upperLipPath.quadraticBezierTo(
      centerX - 20, lipsY - 5,
      centerX, lipsY - 3,
    );
    upperLipPath.quadraticBezierTo(
      centerX + 20, lipsY - 5,
      centerX + 40, lipsY,
    );
    
    // 하순
    final lowerLipPath = Path();
    lowerLipPath.moveTo(centerX - 40, lipsY);
    lowerLipPath.quadraticBezierTo(
      centerX, lipsY + 8,
      centerX + 40, lipsY,
    );
    
    canvas.drawPath(upperLipPath, lipsPaint);
    canvas.drawPath(lowerLipPath, lipsPaint);
  }

  void _drawResonanceAreas(Canvas canvas, Size size, double centerX, double centerY) {
    final resonancePaint = Paint()
      ..style = PaintingStyle.fill;
    
    // 공명 위치에 따른 하이라이트
    switch (resonancePosition) {
      case 'throat':
        resonancePaint.shader = ui.Gradient.radial(
          Offset(centerX, centerY - size.height * 0.05),
          30,
          [
            Colors.orange.withOpacity(0.7 * resonanceIntensity),
            Colors.orange.withOpacity(0.1),
          ],
          [0.0, 1.0],
        );
        canvas.drawCircle(
          Offset(centerX, centerY - size.height * 0.05),
          30,
          resonancePaint,
        );
        break;
        
      case 'mouth':
        resonancePaint.shader = ui.Gradient.radial(
          Offset(centerX, centerY - size.height * 0.2),
          40,
          [
            Colors.purple.withOpacity(0.7 * resonanceIntensity),
            Colors.purple.withOpacity(0.1),
          ],
          [0.0, 1.0],
        );
        canvas.drawCircle(
          Offset(centerX, centerY - size.height * 0.2),
          40,
          resonancePaint,
        );
        break;
        
      case 'head':
        resonancePaint.shader = ui.Gradient.radial(
          Offset(centerX, centerY - size.height * 0.35),
          35,
          [
            Colors.blue.withOpacity(0.7 * resonanceIntensity),
            Colors.blue.withOpacity(0.1),
          ],
          [0.0, 1.0],
        );
        canvas.drawCircle(
          Offset(centerX, centerY - size.height * 0.35),
          35,
          resonancePaint,
        );
        break;
    }
  }

  void _drawAirFlow(Canvas canvas, Size size, double centerX, double centerY) {
    if (breathingPhase > 0.5) {
      // 날숨 - 위로 향하는 화살표
      final airFlowPaint = Paint()
        ..color = Colors.cyan.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      final arrowPath = Path();
      final startY = centerY + size.height * 0.3;
      final endY = centerY - size.height * 0.35;
      
      for (int i = 0; i < 3; i++) {
        final offsetX = (i - 1) * 15.0;
        arrowPath.moveTo(centerX + offsetX, startY);
        arrowPath.lineTo(centerX + offsetX, endY);
        
        // 화살표 머리
        arrowPath.moveTo(centerX + offsetX - 5, endY + 10);
        arrowPath.lineTo(centerX + offsetX, endY);
        arrowPath.lineTo(centerX + offsetX + 5, endY + 10);
      }
      
      canvas.drawPath(arrowPath, airFlowPaint);
    }
  }

  void _drawMeasurements(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    // 음높이 표시
    if (pitchValue > 0) {
      textPainter.text = TextSpan(
        text: '음높이: ${pitchValue.toStringAsFixed(1)} Hz',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(10, 10));
    }
    
    // 공명 위치 표시
    final resonanceText = {
      'throat': '목 공명',
      'mouth': '구강 공명',
      'head': '두성 공명',
      'mixed': '혼합 공명',
    }[resonancePosition] ?? '';
    
    textPainter.text = TextSpan(
      text: resonanceText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(10, 30));
    
    // 호흡 단계 표시
    final breathPhase = breathingPhase > 0.5 ? '날숨' : '들숨';
    textPainter.text = TextSpan(
      text: '호흡: $breathPhase',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(10, 50));
  }

  @override
  bool shouldRepaint(VocalAnatomyPainter oldDelegate) {
    return breathingPhase != oldDelegate.breathingPhase ||
        vocalCordsVibration != oldDelegate.vocalCordsVibration ||
        resonancePosition != oldDelegate.resonancePosition ||
        resonanceIntensity != oldDelegate.resonanceIntensity ||
        pitchValue != oldDelegate.pitchValue;
  }
}