import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fftea/fftea.dart';

/// 3D Frequency spectrum analyzer with advanced visualization
class FrequencyAnalyzer3D extends StatefulWidget {
  final Stream<List<double>>? audioStream;
  final int sampleRate;
  final int fftSize;
  final double minFrequency;
  final double maxFrequency;
  final bool showPeaks;
  final bool showAverage;
  final bool rotationEnabled;
  final FrequencyVisualizationMode mode;
  
  const FrequencyAnalyzer3D({
    Key? key,
    this.audioStream,
    this.sampleRate = 44100,
    this.fftSize = 2048,
    this.minFrequency = 20.0,
    this.maxFrequency = 20000.0,
    this.showPeaks = true,
    this.showAverage = false,
    this.rotationEnabled = true,
    this.mode = FrequencyVisualizationMode.bars3D,
  }) : super(key: key);
  
  @override
  State<FrequencyAnalyzer3D> createState() => _FrequencyAnalyzer3DState();
}

class _FrequencyAnalyzer3DState extends State<FrequencyAnalyzer3D>
    with TickerProviderStateMixin {
  late FFT fft;
  late AnimationController _rotationController;
  late AnimationController _barController;
  
  final List<List<double>> spectrumHistory = [];
  final List<double> currentSpectrum = [];
  final List<double> peakSpectrum = [];
  final List<double> averageSpectrum = [];
  final List<double> audioBuffer = [];
  
  static const int maxHistoryLength = 100;
  static const int displayBars = 64;
  late List<double> window;
  late List<double> frequencyBands;
  
  @override
  void initState() {
    super.initState();
    _initializeFFT();
    _initializeAnimations();
    _subscribeToAudio();
  }
  
  void _initializeFFT() {
    fft = FFT(widget.fftSize);
    
    // Create Hann window
    window = List.generate(widget.fftSize, (i) =>
        0.5 - 0.5 * math.cos(2 * math.pi * i / (widget.fftSize - 1)));
    
    // Create logarithmic frequency bands
    _createFrequencyBands();
    
    // Initialize spectrums
    currentSpectrum.addAll(List.filled(displayBars, 0.0));
    peakSpectrum.addAll(List.filled(displayBars, 0.0));
    averageSpectrum.addAll(List.filled(displayBars, 0.0));
  }
  
  void _initializeAnimations() {
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    
    _barController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    if (widget.rotationEnabled) {
      _rotationController.repeat();
    }
    
    _barController.repeat(reverse: true);
  }
  
  void _createFrequencyBands() {
    frequencyBands = [];
    final logMin = math.log(widget.minFrequency);
    final logMax = math.log(widget.maxFrequency);
    
    for (int i = 0; i < displayBars; i++) {
      final logFreq = logMin + (logMax - logMin) * i / (displayBars - 1);
      frequencyBands.add(math.exp(logFreq));
    }
  }
  
  void _subscribeToAudio() {
    widget.audioStream?.listen((audioChunk) {
      _processAudioChunk(audioChunk);
    });
  }
  
  void _processAudioChunk(List<double> audioChunk) {
    audioBuffer.addAll(audioChunk);
    
    if (audioBuffer.length >= widget.fftSize) {
      final frame = audioBuffer.take(widget.fftSize).toList();
      audioBuffer.removeRange(0, widget.fftSize ~/ 2);
      
      final spectrum = _computeSpectrum(frame);
      final bandedSpectrum = _createBandedSpectrum(spectrum);
      
      setState(() {
        for (int i = 0; i < displayBars; i++) {
          currentSpectrum[i] = bandedSpectrum[i];
          
          // Update peaks
          if (widget.showPeaks) {
            peakSpectrum[i] = math.max(peakSpectrum[i] * 0.95, bandedSpectrum[i]);
          }
          
          // Update average
          if (widget.showAverage) {
            averageSpectrum[i] = averageSpectrum[i] * 0.95 + bandedSpectrum[i] * 0.05;
          }
        }
        
        // Add to history
        spectrumHistory.add(List.from(currentSpectrum));
        if (spectrumHistory.length > maxHistoryLength) {
          spectrumHistory.removeAt(0);
        }
      });
    }
  }
  
  List<double> _computeSpectrum(List<double> frame) {
    // Apply window
    final windowedFrame = Float32List(widget.fftSize);
    for (int i = 0; i < widget.fftSize; i++) {
      windowedFrame[i] = frame[i] * window[i];
    }
    
    // Compute FFT
    final spectrum = fft.realFft(windowedFrame);
    
    // Convert to magnitudes and dB
    return spectrum.map((complex) {
      final magnitude = math.sqrt(complex.x * complex.x + complex.y * complex.y);
      return 20 * math.log(math.max(magnitude, 1e-10)) / math.ln10;
    }).toList();
  }
  
  List<double> _createBandedSpectrum(List<double> fullSpectrum) {
    final bandedSpectrum = List.filled(displayBars, 0.0);
    final frequencyResolution = widget.sampleRate / widget.fftSize;
    
    for (int i = 0; i < displayBars; i++) {
      final targetFreq = frequencyBands[i];
      final binIndex = (targetFreq / frequencyResolution).round();
      
      if (binIndex < fullSpectrum.length) {
        // Average nearby bins for smoother results
        double sum = 0.0;
        int count = 0;
        final range = math.max(1, (binIndex * 0.1).round());
        
        for (int j = math.max(0, binIndex - range); 
             j < math.min(fullSpectrum.length, binIndex + range); j++) {
          sum += fullSpectrum[j];
          count++;
        }
        
        bandedSpectrum[i] = count > 0 ? sum / count : 0.0;
      }
    }
    
    // Normalize to 0-1 range
    final maxVal = bandedSpectrum.reduce(math.max);
    if (maxVal > 0) {
      for (int i = 0; i < displayBars; i++) {
        bandedSpectrum[i] = ((bandedSpectrum[i] + 80) / 80).clamp(0.0, 1.0);
      }
    }
    
    return bandedSpectrum;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0A0A), Color(0xFF1A1A2E)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: FrequencyAnalyzer3DPainter(
                spectrum: currentSpectrum,
                peakSpectrum: widget.showPeaks ? peakSpectrum : null,
                averageSpectrum: widget.showAverage ? averageSpectrum : null,
                spectrumHistory: spectrumHistory,
                rotationAngle: _rotationController.value * 2 * math.pi,
                animationValue: _barController.value,
                mode: widget.mode,
                frequencyBands: frequencyBands,
              ),
            ),
            if (widget.mode == FrequencyVisualizationMode.waterfall)
              _buildFrequencyLabels(),
            _buildControlButtons(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFrequencyLabels() {
    return Positioned(
      left: 0,
      bottom: 0,
      right: 0,
      height: 30,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Row(
          children: [
            for (int i = 0; i < 5; i++)
              Expanded(
                child: Text(
                  _formatFrequency(frequencyBands[(i * displayBars / 4).round()]),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlButtons() {
    return Positioned(
      top: 8,
      right: 8,
      child: Column(
        children: [
          IconButton(
            icon: Icon(
              widget.rotationEnabled 
                  ? Icons.rotation_3d 
                  : Icons.rotation_3d_outlined,
              color: Colors.white70,
            ),
            onPressed: () {
              setState(() {
                if (_rotationController.isAnimating) {
                  _rotationController.stop();
                } else {
                  _rotationController.repeat();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white70),
            onPressed: () {
              setState(() {
                peakSpectrum.fillRange(0, displayBars, 0.0);
                averageSpectrum.fillRange(0, displayBars, 0.0);
                spectrumHistory.clear();
              });
            },
          ),
        ],
      ),
    );
  }
  
  String _formatFrequency(double frequency) {
    if (frequency >= 1000) {
      return '${(frequency / 1000).toStringAsFixed(1)}k';
    } else {
      return '${frequency.round()}';
    }
  }
  
  @override
  void dispose() {
    _rotationController.dispose();
    _barController.dispose();
    super.dispose();
  }
}

/// Custom painter for 3D frequency visualization
class FrequencyAnalyzer3DPainter extends CustomPainter {
  final List<double> spectrum;
  final List<double>? peakSpectrum;
  final List<double>? averageSpectrum;
  final List<List<double>> spectrumHistory;
  final double rotationAngle;
  final double animationValue;
  final FrequencyVisualizationMode mode;
  final List<double> frequencyBands;
  
  FrequencyAnalyzer3DPainter({
    required this.spectrum,
    this.peakSpectrum,
    this.averageSpectrum,
    required this.spectrumHistory,
    required this.rotationAngle,
    required this.animationValue,
    required this.mode,
    required this.frequencyBands,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    switch (mode) {
      case FrequencyVisualizationMode.bars3D:
        _drawBars3D(canvas, size);
        break;
      case FrequencyVisualizationMode.surface3D:
        _drawSurface3D(canvas, size);
        break;
      case FrequencyVisualizationMode.waterfall:
        _drawWaterfall(canvas, size);
        break;
      case FrequencyVisualizationMode.circular:
        _drawCircular(canvas, size);
        break;
    }
  }
  
  void _drawBars3D(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = math.min(size.width, size.height) * 0.3;
    
    for (int i = 0; i < spectrum.length; i++) {
      final angle = (i / spectrum.length) * 2 * math.pi + rotationAngle;
      final amplitude = spectrum[i];
      
      // 3D bar position
      final x = centerX + math.cos(angle) * radius;
      final y = centerY + math.sin(angle) * radius;
      final height = amplitude * size.height * 0.4;
      
      // Color based on frequency and amplitude
      final hue = (i / spectrum.length) * 360;
      final saturation = 0.8 + amplitude * 0.2;
      final lightness = 0.3 + amplitude * 0.4;
      paint.color = HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
      
      // Draw 3D bar with perspective
      _draw3DBar(canvas, paint, x, y, height, angle);
      
      // Draw peak if enabled
      if (peakSpectrum != null && peakSpectrum![i] > amplitude) {
        paint.color = Colors.red.withOpacity(0.8);
        _draw3DBar(canvas, paint, x, y, peakSpectrum![i] * size.height * 0.4, angle);
      }
    }
  }
  
  void _draw3DBar(Canvas canvas, Paint paint, double x, double y, double height, double angle) {
    const barWidth = 8.0;
    final topOffset = Offset(
      math.cos(angle + math.pi / 2) * barWidth / 2,
      math.sin(angle + math.pi / 2) * barWidth / 2,
    );
    
    // Main bar
    final rect = Rect.fromCenter(
      center: Offset(x, y - height / 2),
      width: barWidth,
      height: height,
    );
    canvas.drawRect(rect, paint);
    
    // 3D effect - top face
    if (height > 5) {
      final topPaint = Paint()
        ..color = paint.color.withOpacity(0.8)
        ..style = PaintingStyle.fill;
      
      final topPath = Path()
        ..moveTo(x - barWidth / 2, y - height)
        ..lineTo(x + topOffset.dx - barWidth / 2, y + topOffset.dy - height)
        ..lineTo(x + topOffset.dx + barWidth / 2, y + topOffset.dy - height)
        ..lineTo(x + barWidth / 2, y - height)
        ..close();
      
      canvas.drawPath(topPath, topPaint);
    }
  }
  
  void _drawSurface3D(Canvas canvas, Size size) {
    if (spectrumHistory.length < 2) return;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scaleX = size.width / spectrum.length;
    final scaleZ = 100.0;
    
    // Draw surface mesh
    for (int t = 0; t < spectrumHistory.length - 1; t++) {
      final spectrum1 = spectrumHistory[t];
      final spectrum2 = spectrumHistory[t + 1];
      
      for (int i = 0; i < spectrum1.length - 1; i++) {
        final points = [
          _transform3D(i * scaleX, spectrum1[i] * size.height * 0.3, t * scaleZ, centerX, centerY),
          _transform3D((i + 1) * scaleX, spectrum1[i + 1] * size.height * 0.3, t * scaleZ, centerX, centerY),
          _transform3D((i + 1) * scaleX, spectrum2[i + 1] * size.height * 0.3, (t + 1) * scaleZ, centerX, centerY),
          _transform3D(i * scaleX, spectrum2[i] * size.height * 0.3, (t + 1) * scaleZ, centerX, centerY),
        ];
        
        // Color based on amplitude
        final avgAmplitude = (spectrum1[i] + spectrum1[i + 1] + spectrum2[i] + spectrum2[i + 1]) / 4;
        paint.color = Color.lerp(Colors.blue, Colors.red, avgAmplitude)!.withOpacity(0.7);
        
        // Draw quad
        final path = Path()
          ..moveTo(points[0].dx, points[0].dy)
          ..lineTo(points[1].dx, points[1].dy)
          ..lineTo(points[2].dx, points[2].dy)
          ..lineTo(points[3].dx, points[3].dy)
          ..close();
        
        canvas.drawPath(path, paint..style = PaintingStyle.fill);
        canvas.drawPath(path, paint..style = PaintingStyle.stroke..color = Colors.white24);
      }
    }
  }
  
  void _drawWaterfall(Canvas canvas, Size size) {
    if (spectrumHistory.isEmpty) return;
    
    final paint = Paint();
    final lineHeight = size.height / spectrumHistory.length;
    
    for (int t = 0; t < spectrumHistory.length; t++) {
      final spectrum = spectrumHistory[t];
      final y = t * lineHeight;
      final alpha = 1.0 - (t / spectrumHistory.length) * 0.7;
      
      for (int i = 0; i < spectrum.length - 1; i++) {
        final x1 = (i / spectrum.length) * size.width;
        final x2 = ((i + 1) / spectrum.length) * size.width;
        
        final amplitude = spectrum[i];
        final hue = (i / spectrum.length) * 360;
        paint.color = HSLColor.fromAHSL(alpha, hue, 0.8, 0.3 + amplitude * 0.4).toColor();
        
        canvas.drawRect(
          Rect.fromLTWH(x1, y, x2 - x1, lineHeight),
          paint,
        );
      }
    }
  }
  
  void _drawCircular(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = math.min(size.width, size.height) * 0.4;
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Draw concentric circles for frequency bands
    for (int ring = 0; ring < 5; ring++) {
      final ringRadius = maxRadius * (ring + 1) / 5;
      
      for (int i = 0; i < spectrum.length; i++) {
        final angle = (i / spectrum.length) * 2 * math.pi + rotationAngle;
        final amplitude = spectrum[i];
        
        if (amplitude > ring * 0.2) {
          final x = centerX + math.cos(angle) * ringRadius;
          final y = centerY + math.sin(angle) * ringRadius;
          
          final hue = (i / spectrum.length) * 360;
          final intensity = math.min(1.0, amplitude * 2);
          paint.color = HSLColor.fromAHSL(intensity, hue, 0.8, 0.5).toColor();
          
          canvas.drawCircle(Offset(x, y), 3.0 + amplitude * 5, paint);
        }
      }
    }
    
    // Draw center circle
    paint.color = Colors.white.withOpacity(0.1);
    canvas.drawCircle(Offset(centerX, centerY), 20, paint);
  }
  
  Offset _transform3D(double x, double y, double z, double centerX, double centerY) {
    // Simple 3D to 2D projection
    final rotatedX = x * math.cos(rotationAngle) - z * math.sin(rotationAngle);
    final rotatedZ = x * math.sin(rotationAngle) + z * math.cos(rotationAngle);
    
    final perspective = 300.0 / (300.0 + rotatedZ);
    final projectedX = centerX + (rotatedX - centerX) * perspective;
    final projectedY = centerY + (y - centerY) * perspective;
    
    return Offset(projectedX, projectedY);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

enum FrequencyVisualizationMode {
  bars3D,
  surface3D,
  waterfall,
  circular,
}