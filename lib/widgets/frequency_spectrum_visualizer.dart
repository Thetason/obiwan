import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/universal_pitch_analyzer.dart';

/// 주파수 스펙트럼 시각화 위젯
/// 20Hz ~ 20kHz 전체 가청주파수 범위 표시
class FrequencySpectrumVisualizer extends StatefulWidget {
  final SpectrumAnalysisResult? analysisResult;
  final double width;
  final double height;
  
  const FrequencySpectrumVisualizer({
    super.key,
    this.analysisResult,
    this.width = 800,
    this.height = 400,
  });

  @override
  State<FrequencySpectrumVisualizer> createState() => _FrequencySpectrumVisualizerState();
}

class _FrequencySpectrumVisualizerState extends State<FrequencySpectrumVisualizer>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return CustomPaint(
              size: Size(widget.width, widget.height),
              painter: SpectrumPainter(
                analysisResult: widget.analysisResult,
                animationValue: _animation.value,
              ),
            );
          },
        ),
      ),
    );
  }
}

class SpectrumPainter extends CustomPainter {
  final SpectrumAnalysisResult? analysisResult;
  final double animationValue;
  
  SpectrumPainter({
    this.analysisResult,
    required this.animationValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // 배경 그라디언트
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black,
        Colors.grey.shade900,
      ],
    );
    
    final bgPaint = Paint()
      ..shader = bgGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    // 주파수 축 그리기 (로그 스케일)
    _drawFrequencyAxis(canvas, size);
    
    // 스펙트럼 데이터 그리기
    if (analysisResult != null) {
      _drawSpectrum(canvas, size);
      _drawPrimaryFrequency(canvas, size);
      _drawHarmonics(canvas, size);
      _drawVocalInfo(canvas, size);
    }
  }
  
  void _drawFrequencyAxis(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 1;
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    // 주요 주파수 마커 (로그 스케일)
    final frequencies = [20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000];
    
    for (final freq in frequencies) {
      // 로그 스케일로 x 위치 계산
      final x = _frequencyToX(freq.toDouble(), size.width);
      
      // 수직선
      canvas.drawLine(
        Offset(x, size.height - 30),
        Offset(x, size.height - 25),
        paint,
      );
      
      // 레이블
      String label;
      if (freq < 1000) {
        label = '${freq}Hz';
      } else {
        label = '${freq ~/ 1000}kHz';
      }
      
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - 20),
      );
    }
    
    // x축
    canvas.drawLine(
      Offset(0, size.height - 30),
      Offset(size.width, size.height - 30),
      paint,
    );
  }
  
  void _drawSpectrum(Canvas canvas, Size size) {
    if (analysisResult == null) return;
    
    final spectrumData = analysisResult!.spectrumData;
    if (spectrumData.isEmpty) return;
    
    // 스펙트럼 바 그리기
    for (final point in spectrumData) {
      final x = _frequencyToX(point.frequency, size.width);
      final barHeight = point.amplitude * (size.height - 50) * animationValue;
      
      // 주파수 대역별 색상
      Color barColor;
      if (point.frequency < 80) {
        barColor = Colors.purple; // Sub-Bass
      } else if (point.frequency < 250) {
        barColor = Colors.blue; // Bass
      } else if (point.frequency < 500) {
        barColor = Colors.cyan; // Low-Mid
      } else if (point.frequency < 1000) {
        barColor = Colors.green; // Mid
      } else if (point.frequency < 2000) {
        barColor = Colors.yellow; // High-Mid
      } else if (point.frequency < 4000) {
        barColor = Colors.orange; // High
      } else {
        barColor = Colors.red; // Brilliance
      }
      
      final barPaint = Paint()
        ..color = barColor.withOpacity(0.7)
        ..style = PaintingStyle.fill;
      
      // 바 그리기
      final barWidth = size.width / 50; // 50개 바
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x - barWidth / 2,
            size.height - 30 - barHeight,
            barWidth,
            barHeight,
          ),
          const Radius.circular(2),
        ),
        barPaint,
      );
    }
  }
  
  void _drawPrimaryFrequency(Canvas canvas, Size size) {
    if (analysisResult == null) return;
    
    final primaryFreq = analysisResult!.primaryFrequency;
    if (primaryFreq <= 0) return;
    
    final x = _frequencyToX(primaryFreq, size.width);
    
    // 주 주파수 라인
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height - 30),
      linePaint,
    );
    
    // 주파수 레이블
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${primaryFreq.toStringAsFixed(1)}Hz\n${UniversalPitchAnalyzer().frequencyToNote(primaryFreq)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    
    // 배경 박스
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        x - textPainter.width / 2 - 5,
        10,
        textPainter.width + 10,
        textPainter.height + 5,
      ),
      const Radius.circular(4),
    );
    
    canvas.drawRRect(
      bgRect,
      Paint()..color = Colors.black.withOpacity(0.7),
    );
    
    textPainter.paint(canvas, Offset(x - textPainter.width / 2, 12));
  }
  
  void _drawHarmonics(Canvas canvas, Size size) {
    if (analysisResult == null) return;
    
    final harmonics = analysisResult!.harmonics;
    if (harmonics.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.yellow.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    for (final harmonic in harmonics) {
      final x = _frequencyToX(harmonic.frequency, size.width);
      
      // 하모닉 라인 (점선)
      for (double y = 0; y < size.height - 30; y += 5) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + 2),
          paint,
        );
      }
    }
  }
  
  void _drawVocalInfo(Canvas canvas, Size size) {
    if (analysisResult == null) return;
    
    final vocal = analysisResult!.vocalCharacteristics;
    
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '음역: ${vocal.voiceType}\n',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: '음색: ${vocal.timbre}\n',
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 12,
            ),
          ),
          TextSpan(
            text: '비브라토: ${(vocal.vibrato * 100).toStringAsFixed(1)}%\n',
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 12,
            ),
          ),
          TextSpan(
            text: '밝기: ${(vocal.brightness * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 12,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    // 배경 박스
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width - textPainter.width - 20,
        10,
        textPainter.width + 10,
        textPainter.height + 10,
      ),
      const Radius.circular(6),
    );
    
    canvas.drawRRect(
      bgRect,
      Paint()..color = Colors.black.withOpacity(0.8),
    );
    
    textPainter.paint(
      canvas,
      Offset(size.width - textPainter.width - 15, 15),
    );
  }
  
  /// 주파수를 X 좌표로 변환 (로그 스케일)
  double _frequencyToX(double frequency, double width) {
    if (frequency <= 0) return 0;
    
    // 로그 스케일: 20Hz ~ 20kHz
    const minLog = 1.301; // log10(20)
    const maxLog = 4.301; // log10(20000)
    
    final logFreq = math.log(frequency) / math.ln10;
    final normalized = (logFreq - minLog) / (maxLog - minLog);
    
    return normalized.clamp(0.0, 1.0) * width;
  }
  
  @override
  bool shouldRepaint(covariant SpectrumPainter oldDelegate) {
    return oldDelegate.analysisResult != analysisResult ||
           oldDelegate.animationValue != animationValue;
  }
}