import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Advanced waveform visualization with multiple display modes
class AdvancedWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final WaveformDisplayMode displayMode;
  final WaveformColorScheme colorScheme;
  final bool showGrid;
  final bool showRMS;
  final bool showPeaks;
  final bool showZeroCrossings;
  final double amplitudeScale;
  final double timeWindow;
  final List<double>? referenceWaveform;
  
  AdvancedWaveformPainter({
    required this.waveformData,
    this.displayMode = WaveformDisplayMode.oscilloscope,
    this.colorScheme = WaveformColorScheme.classic,
    this.showGrid = true,
    this.showRMS = false,
    this.showPeaks = false,
    this.showZeroCrossings = false,
    this.amplitudeScale = 1.0,
    this.timeWindow = 1.0,
    this.referenceWaveform,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;
    
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    // Draw background
    canvas.drawRect(rect, Paint()..color = _getBackgroundColor());
    
    // Draw grid if enabled
    if (showGrid) {
      _drawGrid(canvas, size);
    }
    
    // Draw waveform based on display mode
    switch (displayMode) {
      case WaveformDisplayMode.oscilloscope:
        _drawOscilloscope(canvas, size);
        break;
      case WaveformDisplayMode.filled:
        _drawFilledWaveform(canvas, size);
        break;
      case WaveformDisplayMode.bars:
        _drawBarWaveform(canvas, size);
        break;
      case WaveformDisplayMode.dots:
        _drawDotWaveform(canvas, size);
        break;
      case WaveformDisplayMode.envelope:
        _drawEnvelopeWaveform(canvas, size);
        break;
    }
    
    // Draw reference waveform if provided
    if (referenceWaveform != null) {
      _drawReferenceWaveform(canvas, size);
    }
    
    // Draw additional features
    if (showRMS) {
      _drawRMS(canvas, size);
    }
    
    if (showPeaks) {
      _drawPeaks(canvas, size);
    }
    
    if (showZeroCrossings) {
      _drawZeroCrossings(canvas, size);
    }
  }
  
  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 0.5;
    
    // Horizontal lines
    for (int i = 0; i <= 4; i++) {
      final y = (i / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    
    // Vertical lines
    for (int i = 0; i <= 8; i++) {
      final x = (i / 8) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    
    // Center line
    paint.color = Colors.grey.withOpacity(0.6);
    paint.strokeWidth = 1.0;
    final centerY = size.height / 2;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), paint);
  }
  
  void _drawOscilloscope(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _getPrimaryColor()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    final centerY = size.height / 2;
    final scaleY = (size.height / 2) * amplitudeScale;
    
    bool first = true;
    for (int i = 0; i < waveformData.length; i++) {
      final x = (i / waveformData.length) * size.width;
      final y = centerY - (waveformData[i] * scaleY);
      
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    
    // Apply glow effect if specified in color scheme
    if (colorScheme == WaveformColorScheme.neon) {
      _drawGlowEffect(canvas, path, paint);
    }
    
    canvas.drawPath(path, paint);
  }
  
  void _drawFilledWaveform(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _getPrimaryColor().withOpacity(0.7)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    final centerY = size.height / 2;
    final scaleY = (size.height / 2) * amplitudeScale;
    
    // Start from center line
    path.moveTo(0, centerY);
    
    // Draw upper envelope
    for (int i = 0; i < waveformData.length; i++) {
      final x = (i / waveformData.length) * size.width;
      final y = centerY - (waveformData[i].abs() * scaleY);
      path.lineTo(x, y);
    }
    
    // Draw lower envelope (reverse)
    for (int i = waveformData.length - 1; i >= 0; i--) {
      final x = (i / waveformData.length) * size.width;
      final y = centerY + (waveformData[i].abs() * scaleY);
      path.lineTo(x, y);
    }
    
    path.close();
    canvas.drawPath(path, paint);
    
    // Draw center line
    _drawOscilloscope(canvas, size);
  }
  
  void _drawBarWaveform(Canvas canvas, Size size) {
    final paint = Paint()..color = _getPrimaryColor();
    
    final barWidth = size.width / waveformData.length;
    final centerY = size.height / 2;
    final scaleY = (size.height / 2) * amplitudeScale;
    
    for (int i = 0; i < waveformData.length; i++) {
      final x = i * barWidth;
      final amplitude = waveformData[i].abs();
      final barHeight = amplitude * scaleY;
      
      // Draw bar from center
      final rect = Rect.fromLTWH(
        x,
        centerY - barHeight,
        barWidth * 0.8, // Slight gap between bars
        barHeight * 2,
      );
      
      // Color based on amplitude
      paint.color = _getAmplitudeColor(amplitude);
      canvas.drawRect(rect, paint);
    }
  }
  
  void _drawDotWaveform(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _getPrimaryColor()
      ..style = PaintingStyle.fill;
    
    final centerY = size.height / 2;
    final scaleY = (size.height / 2) * amplitudeScale;
    
    for (int i = 0; i < waveformData.length; i++) {
      final x = (i / waveformData.length) * size.width;
      final y = centerY - (waveformData[i] * scaleY);
      final amplitude = waveformData[i].abs();
      
      // Dot size based on amplitude
      final radius = math.max(1.0, amplitude * 4.0);
      paint.color = _getAmplitudeColor(amplitude);
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }
  
  void _drawEnvelopeWaveform(Canvas canvas, Size size) {
    if (waveformData.length < 10) return;
    
    final envelopeData = _calculateEnvelope(waveformData);
    final paint = Paint()
      ..color = _getPrimaryColor().withOpacity(0.6)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    final centerY = size.height / 2;
    final scaleY = (size.height / 2) * amplitudeScale;
    
    bool first = true;
    for (int i = 0; i < envelopeData.length; i++) {
      final x = (i / envelopeData.length) * size.width;
      final y = centerY - (envelopeData[i] * scaleY);
      
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // Draw negative envelope
    final negativePath = Path();
    first = true;
    for (int i = 0; i < envelopeData.length; i++) {
      final x = (i / envelopeData.length) * size.width;
      final y = centerY + (envelopeData[i] * scaleY);
      
      if (first) {
        negativePath.moveTo(x, y);
        first = false;
      } else {
        negativePath.lineTo(x, y);
      }
    }
    
    canvas.drawPath(negativePath, paint);
  }
  
  void _drawReferenceWaveform(Canvas canvas, Size size) {
    if (referenceWaveform == null || referenceWaveform!.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    final centerY = size.height / 2;
    final scaleY = (size.height / 2) * amplitudeScale;
    
    bool first = true;
    for (int i = 0; i < referenceWaveform!.length; i++) {
      final x = (i / referenceWaveform!.length) * size.width;
      final y = centerY - (referenceWaveform![i] * scaleY);
      
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
  }
  
  void _drawRMS(Canvas canvas, Size size) {
    final rms = _calculateRMS(waveformData);
    final paint = Paint()
      ..color = Colors.yellow.withOpacity(0.8)
      ..strokeWidth = 2.0;
    
    final centerY = size.height / 2;
    final scaleY = (size.height / 2) * amplitudeScale;
    final rmsY = rms * scaleY;
    
    // Draw RMS lines
    canvas.drawLine(
      Offset(0, centerY - rmsY),
      Offset(size.width, centerY - rmsY),
      paint,
    );
    canvas.drawLine(
      Offset(0, centerY + rmsY),
      Offset(size.width, centerY + rmsY),
      paint,
    );
  }
  
  void _drawPeaks(Canvas canvas, Size size) {
    final peaks = _findPeaks(waveformData);
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    
    final centerY = size.height / 2;
    final scaleY = (size.height / 2) * amplitudeScale;
    
    for (final peak in peaks) {
      final x = (peak['index'] as int / waveformData.length) * size.width;
      final y = centerY - ((peak['value'] as double) * scaleY);
      
      canvas.drawCircle(Offset(x, y), 4.0, paint);
    }
  }
  
  void _drawZeroCrossings(Canvas canvas, Size size) {
    final crossings = _findZeroCrossings(waveformData);
    final paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2.0;
    
    final centerY = size.height / 2;
    
    for (final crossing in crossings) {
      final x = (crossing / waveformData.length) * size.width;
      canvas.drawLine(
        Offset(x, centerY - 10),
        Offset(x, centerY + 10),
        paint,
      );
    }
  }
  
  void _drawGlowEffect(Canvas canvas, Path path, Paint paint) {
    final glowPaint = Paint()
      ..color = paint.color.withOpacity(0.3)
      ..strokeWidth = paint.strokeWidth * 3
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    
    canvas.drawPath(path, glowPaint);
  }
  
  List<double> _calculateEnvelope(List<double> data) {
    const windowSize = 10;
    final envelope = <double>[];
    
    for (int i = 0; i < data.length; i += windowSize) {
      double maxValue = 0.0;
      for (int j = i; j < math.min(i + windowSize, data.length); j++) {
        maxValue = math.max(maxValue, data[j].abs());
      }
      envelope.add(maxValue);
    }
    
    return envelope;
  }
  
  double _calculateRMS(List<double> data) {
    if (data.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (final value in data) {
      sum += value * value;
    }
    
    return math.sqrt(sum / data.length);
  }
  
  List<Map<String, dynamic>> _findPeaks(List<double> data) {
    final peaks = <Map<String, dynamic>>[];
    const minDistance = 10;
    const threshold = 0.3;
    
    for (int i = minDistance; i < data.length - minDistance; i++) {
      final value = data[i].abs();
      if (value < threshold) continue;
      
      bool isPeak = true;
      for (int j = i - minDistance; j <= i + minDistance; j++) {
        if (j != i && data[j].abs() >= value) {
          isPeak = false;
          break;
        }
      }
      
      if (isPeak) {
        peaks.add({'index': i, 'value': data[i]});
      }
    }
    
    return peaks;
  }
  
  List<int> _findZeroCrossings(List<double> data) {
    final crossings = <int>[];
    
    for (int i = 1; i < data.length; i++) {
      if ((data[i - 1] >= 0 && data[i] < 0) || 
          (data[i - 1] < 0 && data[i] >= 0)) {
        crossings.add(i);
      }
    }
    
    return crossings;
  }
  
  Color _getBackgroundColor() {
    switch (colorScheme) {
      case WaveformColorScheme.classic:
        return Colors.black;
      case WaveformColorScheme.neon:
        return const Color(0xFF0A0A0A);
      case WaveformColorScheme.retro:
        return const Color(0xFF1a1a2e);
      case WaveformColorScheme.modern:
        return const Color(0xFF1E1E1E);
    }
  }
  
  Color _getPrimaryColor() {
    switch (colorScheme) {
      case WaveformColorScheme.classic:
        return Colors.green;
      case WaveformColorScheme.neon:
        return const Color(0xFF00FFFF);
      case WaveformColorScheme.retro:
        return const Color(0xFFFF6B6B);
      case WaveformColorScheme.modern:
        return const Color(0xFF4FC3F7);
    }
  }
  
  Color _getAmplitudeColor(double amplitude) {
    final normalizedAmp = amplitude.clamp(0.0, 1.0);
    
    switch (colorScheme) {
      case WaveformColorScheme.classic:
        return Color.lerp(Colors.green[200]!, Colors.green, normalizedAmp)!;
      case WaveformColorScheme.neon:
        return Color.lerp(const Color(0xFF004444), const Color(0xFF00FFFF), normalizedAmp)!;
      case WaveformColorScheme.retro:
        return Color.lerp(const Color(0xFF660000), const Color(0xFFFF6B6B), normalizedAmp)!;
      case WaveformColorScheme.modern:
        return Color.lerp(const Color(0xFF1565C0), const Color(0xFF4FC3F7), normalizedAmp)!;
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 3D Waveform visualization painter
class Waveform3DPainter extends CustomPainter {
  final List<List<double>> waveformHistory;
  final double rotationX;
  final double rotationY;
  final Color waveColor;
  
  Waveform3DPainter({
    required this.waveformHistory,
    this.rotationX = 0.0,
    this.rotationY = 0.0,
    this.waveColor = Colors.blue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (waveformHistory.isEmpty) return;
    
    final paint = Paint()
      ..color = waveColor.withOpacity(0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scaleX = size.width / waveformHistory[0].length;
    final scaleY = size.height / 4;
    final scaleZ = 50.0;
    
    // Draw waveform lines in 3D space
    for (int z = 0; z < waveformHistory.length - 1; z++) {
      final waveform = waveformHistory[z];
      final path = Path();
      
      bool first = true;
      for (int x = 0; x < waveform.length; x++) {
        final point3D = _transform3D(
          x.toDouble() * scaleX - centerX,
          waveform[x] * scaleY,
          z.toDouble() * scaleZ - (waveformHistory.length * scaleZ / 2),
          rotationX,
          rotationY,
        );
        
        final screenX = point3D[0] + centerX;
        final screenY = point3D[1] + centerY;
        
        if (first) {
          path.moveTo(screenX, screenY);
          first = false;
        } else {
          path.lineTo(screenX, screenY);
        }
      }
      
      // Fade older waveforms
      final alpha = 1.0 - (z / waveformHistory.length);
      paint.color = waveColor.withOpacity(alpha * 0.8);
      
      canvas.drawPath(path, paint);
    }
  }
  
  List<double> _transform3D(double x, double y, double z, double rotX, double rotY) {
    // Simple 3D rotation transformation
    final cosX = math.cos(rotX);
    final sinX = math.sin(rotX);
    final cosY = math.cos(rotY);
    final sinY = math.sin(rotY);
    
    // Rotate around X-axis
    final y1 = y * cosX - z * sinX;
    final z1 = y * sinX + z * cosX;
    
    // Rotate around Y-axis
    final x2 = x * cosY + z1 * sinY;
    final z2 = -x * sinY + z1 * cosY;
    
    // Simple perspective projection
    final distance = 300.0;
    final projX = x2 * distance / (distance + z2);
    final projY = y1 * distance / (distance + z2);
    
    return [projX, projY];
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

enum WaveformDisplayMode {
  oscilloscope,
  filled,
  bars,
  dots,
  envelope,
}

enum WaveformColorScheme {
  classic,
  neon,
  retro,
  modern,
}