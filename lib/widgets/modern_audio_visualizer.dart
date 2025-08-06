import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:typed_data';

class ModernAudioVisualizer extends StatefulWidget {
  final Float32List? audioData;
  final bool isActive;
  final double amplitude;
  final Color primaryColor;
  final Color secondaryColor;

  const ModernAudioVisualizer({
    super.key,
    this.audioData,
    required this.isActive,
    required this.amplitude,
    this.primaryColor = const Color(0xFF6366F1),
    this.secondaryColor = const Color(0xFF8B5CF6),
  });

  @override
  State<ModernAudioVisualizer> createState() => _ModernAudioVisualizerState();
}

class _ModernAudioVisualizerState extends State<ModernAudioVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  late List<double> _frequencyBands;
  
  @override
  void initState() {
    super.initState();
    _frequencyBands = List.generate(32, (index) => 0.0);
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    );
    
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );
    
    if (widget.isActive) {
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(ModernAudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive && !oldWidget.isActive) {
      _waveController.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _waveController.stop();
    }

    if (widget.audioData != null) {
      _updateFrequencyBands();
    }
  }

  void _updateFrequencyBands() {
    if (widget.audioData == null || widget.audioData!.isEmpty) return;

    final data = widget.audioData!;
    final bandSize = data.length ~/ _frequencyBands.length;
    
    for (int i = 0; i < _frequencyBands.length; i++) {
      double sum = 0.0;
      final start = i * bandSize;
      final end = math.min(start + bandSize, data.length);
      
      for (int j = start; j < end; j++) {
        sum += data[j].abs();
      }
      
      final average = sum / (end - start);
      final smoothed = _frequencyBands[i] * 0.7 + average * 0.3;
      _frequencyBands[i] = smoothed.clamp(0.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 배경 그라데이션
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.primaryColor.withOpacity(0.1),
                  widget.secondaryColor.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // 주파수 바 시각화
          AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(double.infinity, 200),
                painter: FrequencyBarsPainter(
                  frequencyBands: _frequencyBands,
                  amplitude: widget.amplitude,
                  primaryColor: widget.primaryColor,
                  secondaryColor: widget.secondaryColor,
                  isActive: widget.isActive,
                ),
              );
            },
          ),

          // 중앙 웨이브폼
          if (widget.isActive)
            AnimatedBuilder(
              animation: _waveAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 100),
                  painter: WaveformPainter(
                    audioData: widget.audioData,
                    amplitude: widget.amplitude,
                    primaryColor: widget.primaryColor,
                    animationValue: _waveAnimation.value,
                  ),
                );
              },
            ),

          // 진폭 표시기
          Positioned(
            top: 16,
            right: 16,
            child: AmplitudeIndicator(
              amplitude: widget.amplitude,
              color: widget.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }
}

class FrequencyBarsPainter extends CustomPainter {
  final List<double> frequencyBands;
  final double amplitude;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isActive;

  FrequencyBarsPainter({
    required this.frequencyBands,
    required this.amplitude,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final paint = Paint()
      ..style = PaintingStyle.fill;

    final barWidth = size.width / frequencyBands.length;
    final maxHeight = size.height * 0.8;

    for (int i = 0; i < frequencyBands.length; i++) {
      final barHeight = frequencyBands[i] * maxHeight * (1.0 + amplitude);
      final x = i * barWidth;
      final y = (size.height - barHeight) / 2;

      // 그라데이션 색상 계산
      final t = i / frequencyBands.length;
      final color = Color.lerp(primaryColor, secondaryColor, t)!;
      
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.8),
          color.withOpacity(0.3),
        ],
      ).createShader(Rect.fromLTWH(x, y, barWidth - 2, barHeight));

      // 둥근 모서리 바
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 1, y, barWidth - 2, barHeight),
        const Radius.circular(2),
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WaveformPainter extends CustomPainter {
  final Float32List? audioData;
  final double amplitude;
  final Color primaryColor;
  final double animationValue;

  WaveformPainter({
    this.audioData,
    required this.amplitude,
    required this.primaryColor,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (audioData == null || audioData!.isEmpty) return;

    final paint = Paint()
      ..color = primaryColor.withOpacity(0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    final centerY = size.height / 2;
    final stepX = size.width / audioData!.length;

    path.moveTo(0, centerY);

    for (int i = 0; i < audioData!.length; i++) {
      final x = i * stepX;
      final y = centerY + (audioData![i] * size.height * 0.4 * (1.0 + amplitude));
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);

    // 글로우 효과
    paint
      ..color = primaryColor.withOpacity(0.3)
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AmplitudeIndicator extends StatelessWidget {
  final double amplitude;
  final Color color;

  const AmplitudeIndicator({
    super.key,
    required this.amplitude,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.2),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.graphic_eq,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            "${(amplitude * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}