import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import '../../theme/app_theme.dart';

/// Real-time audio waveform visualization widget
class AudioWaveformWidget extends StatefulWidget {
  final List<double> audioData;
  final double height;
  final Color? waveColor;
  final Color? backgroundColor;
  final double strokeWidth;
  final bool isRealTime;
  final Duration animationDuration;
  final int maxDataPoints;
  final bool showGradient;
  final double sensitivity;
  final WaveformStyle style;
  
  const AudioWaveformWidget({
    super.key,
    required this.audioData,
    this.height = 120.0,
    this.waveColor,
    this.backgroundColor,
    this.strokeWidth = 2.0,
    this.isRealTime = true,
    this.animationDuration = const Duration(milliseconds: 50),
    this.maxDataPoints = 200,
    this.showGradient = true,
    this.sensitivity = 1.0,
    this.style = WaveformStyle.bars,
  });

  @override
  State<AudioWaveformWidget> createState() => _AudioWaveformWidgetState();
}

class _AudioWaveformWidgetState extends State<AudioWaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  List<double> _displayData = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _updateDisplayData();
    
    if (widget.isRealTime) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(AudioWaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioData != widget.audioData) {
      _updateDisplayData();
    }
  }

  void _updateDisplayData() {
    if (widget.audioData.isEmpty) {
      _displayData = List.filled(widget.maxDataPoints, 0.0);
      return;
    }
    
    final data = widget.audioData.map((v) => v * widget.sensitivity).toList();
    
    if (widget.isRealTime) {
      // Real-time mode: show latest data points
      if (data.length <= widget.maxDataPoints) {
        _displayData = data + List.filled(widget.maxDataPoints - data.length, 0.0);
      } else {
        _displayData = data.sublist(data.length - widget.maxDataPoints);
      }
    } else {
      // Static mode: downsample to fit maxDataPoints
      if (data.length <= widget.maxDataPoints) {
        _displayData = data;
      } else {
        _displayData = _downsampleData(data, widget.maxDataPoints);
      }
    }
  }

  List<double> _downsampleData(List<double> data, int targetLength) {
    if (data.length <= targetLength) return data;
    
    final result = <double>[];
    final stepSize = data.length / targetLength;
    
    for (int i = 0; i < targetLength; i++) {
      final startIdx = (i * stepSize).floor();
      final endIdx = ((i + 1) * stepSize).floor().clamp(startIdx + 1, data.length);
      
      // Calculate RMS for this segment
      double sum = 0.0;
      for (int j = startIdx; j < endIdx; j++) {
        sum += data[j] * data[j];
      }
      result.add(math.sqrt(sum / (endIdx - startIdx)));
    }
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waveColor = widget.waveColor ?? AppTheme.customColors.waveformPrimary;
    final backgroundColor = widget.backgroundColor ?? 
        theme.colorScheme.surface.withOpacity(0.5);
    
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: _WaveformPainter(
                data: _displayData,
                color: waveColor,
                strokeWidth: widget.strokeWidth,
                style: widget.style,
                showGradient: widget.showGradient,
                animationValue: widget.isRealTime ? _animationController.value : 1.0,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

/// Waveform display styles
enum WaveformStyle {
  bars,      // Vertical bars
  line,      // Connected line
  filled,    // Filled area
  dots,      // Dots at peaks
  mirror,    // Mirrored bars
}

/// Custom painter for waveform visualization
class _WaveformPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double strokeWidth;
  final WaveformStyle style;
  final bool showGradient;
  final double animationValue;

  _WaveformPainter({
    required this.data,
    required this.color,
    required this.strokeWidth,
    required this.style,
    required this.showGradient,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;
    final barWidth = width / data.length;
    
    switch (style) {
      case WaveformStyle.bars:
        _drawBars(canvas, size, paint, centerY, barWidth);
        break;
      case WaveformStyle.line:
        _drawLine(canvas, size, paint, centerY, barWidth);
        break;
      case WaveformStyle.filled:
        _drawFilled(canvas, size, paint, centerY, barWidth);
        break;
      case WaveformStyle.dots:
        _drawDots(canvas, size, paint, centerY, barWidth);
        break;
      case WaveformStyle.mirror:
        _drawMirror(canvas, size, paint, centerY, barWidth);
        break;
    }
  }

  void _drawBars(Canvas canvas, Size size, Paint paint, double centerY, double barWidth) {
    for (int i = 0; i < data.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final amplitude = data[i].abs() * centerY;
      
      // Apply animation effect
      final animatedAmplitude = amplitude * animationValue;
      
      if (showGradient) {
        final opacity = (amplitude / centerY).clamp(0.3, 1.0);
        paint.color = color.withOpacity(opacity);
      }
      
      canvas.drawLine(
        Offset(x, centerY - animatedAmplitude),
        Offset(x, centerY + animatedAmplitude),
        paint,
      );
    }
  }

  void _drawLine(Canvas canvas, Size size, Paint paint, double centerY, double barWidth) {
    paint.style = PaintingStyle.stroke;
    
    final path = Path();
    bool first = true;
    
    for (int i = 0; i < data.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final y = centerY - (data[i] * centerY * animationValue);
      
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    
    if (showGradient) {
      paint.shader = LinearGradient(
        colors: [
          color.withOpacity(0.5),
          color,
          color.withOpacity(0.5),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    
    canvas.drawPath(path, paint);
  }

  void _drawFilled(Canvas canvas, Size size, Paint paint, double centerY, double barWidth) {
    paint.style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(0, centerY);
    
    for (int i = 0; i < data.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final y = centerY - (data[i] * centerY * animationValue);
      path.lineTo(x, y);
    }
    
    path.lineTo(size.width, centerY);
    path.close();
    
    if (showGradient) {
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.8),
          color.withOpacity(0.2),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    
    canvas.drawPath(path, paint);
  }

  void _drawDots(Canvas canvas, Size size, Paint paint, double centerY, double barWidth) {
    paint.style = PaintingStyle.fill;
    
    for (int i = 0; i < data.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final amplitude = data[i].abs() * centerY * animationValue;
      
      if (amplitude > 0.01) {
        final radius = math.min(barWidth / 4, amplitude / 10);
        
        if (showGradient) {
          final opacity = (amplitude / centerY).clamp(0.3, 1.0);
          paint.color = color.withOpacity(opacity);
        }
        
        canvas.drawCircle(
          Offset(x, centerY - amplitude),
          radius,
          paint,
        );
        
        if (data[i] < 0) {
          canvas.drawCircle(
            Offset(x, centerY + amplitude),
            radius,
            paint,
          );
        }
      }
    }
  }

  void _drawMirror(Canvas canvas, Size size, Paint paint, double centerY, double barWidth) {
    for (int i = 0; i < data.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final amplitude = data[i].abs() * centerY * animationValue;
      
      if (showGradient) {
        final gradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color,
            color.withOpacity(0.3),
            color.withOpacity(0.3),
            color,
          ],
          stops: const [0.0, 0.4, 0.6, 1.0],
        );
        
        paint.shader = gradient.createShader(
          Rect.fromLTWH(x - barWidth / 4, centerY - amplitude, 
                       barWidth / 2, amplitude * 2),
        );
      }
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, centerY),
            width: barWidth * 0.8,
            height: amplitude * 2,
          ),
          Radius.circular(barWidth / 4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _WaveformPainter &&
        (oldDelegate.data != data ||
         oldDelegate.animationValue != animationValue ||
         oldDelegate.color != color);
  }
}

/// Compact waveform widget for smaller spaces
class CompactWaveformWidget extends StatefulWidget {
  final List<double> audioData;
  final double height;
  final Color? color;
  final int maxBars;
  final bool animate;
  
  const CompactWaveformWidget({
    super.key,
    required this.audioData,
    this.height = 40.0,
    this.color,
    this.maxBars = 20,
    this.animate = true,
  });

  @override
  State<CompactWaveformWidget> createState() => _CompactWaveformWidgetState();
}

class _CompactWaveformWidgetState extends State<CompactWaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? AppTheme.customColors.waveformSecondary;
    
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.maxBars, (index) {
              final dataIndex = widget.audioData.isEmpty ? 0 : 
                  (index * widget.audioData.length / widget.maxBars).floor()
                      .clamp(0, widget.audioData.length - 1);
              
              final amplitude = widget.audioData.isEmpty ? 0.1 : 
                  widget.audioData[dataIndex].abs().clamp(0.1, 1.0);
              
              final animatedHeight = widget.animate ? 
                  amplitude * widget.height * (0.3 + 0.7 * _animation.value) :
                  amplitude * widget.height;
              
              return Container(
                width: 3,
                height: animatedHeight,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3 + 0.7 * amplitude),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}