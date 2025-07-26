import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fftea/fftea.dart';

/// Real-time spectrogram visualization with advanced features
class SpectrogramVisualizer extends StatefulWidget {
  final Stream<List<double>>? audioStream;
  final int sampleRate;
  final int fftSize;
  final int hopSize;
  final double minFrequency;
  final double maxFrequency;
  final SpectrogramColorScheme colorScheme;
  final bool showFrequencyLabels;
  final bool showTimeLabels;
  final bool logScale;
  final double dynamicRange;
  
  const SpectrogramVisualizer({
    Key? key,
    this.audioStream,
    this.sampleRate = 44100,
    this.fftSize = 2048,
    this.hopSize = 512,
    this.minFrequency = 80.0,
    this.maxFrequency = 8000.0,
    this.colorScheme = SpectrogramColorScheme.jet,
    this.showFrequencyLabels = true,
    this.showTimeLabels = true,
    this.logScale = true,
    this.dynamicRange = 80.0,
  }) : super(key: key);
  
  @override
  State<SpectrogramVisualizer> createState() => _SpectrogramVisualizerState();
}

class _SpectrogramVisualizerState extends State<SpectrogramVisualizer> {
  late FFT fft;
  final List<List<double>> spectrogramData = [];
  final List<double> audioBuffer = [];
  late List<double> window;
  
  // Display parameters
  static const int maxTimeSlices = 200;
  static const int displayHeight = 300;
  late int frequencyBins;
  late double frequencyResolution;
  
  @override
  void initState() {
    super.initState();
    _initializeFFT();
    _subscribeToAudio();
  }
  
  void _initializeFFT() {
    fft = FFT(widget.fftSize);
    frequencyBins = widget.fftSize ~/ 2 + 1;
    frequencyResolution = widget.sampleRate / widget.fftSize;
    
    // Create Hann window
    window = List.generate(widget.fftSize, (i) =>
        0.5 - 0.5 * math.cos(2 * math.pi * i / (widget.fftSize - 1)));
  }
  
  void _subscribeToAudio() {
    widget.audioStream?.listen((audioChunk) {
      _processAudioChunk(audioChunk);
    });
  }
  
  void _processAudioChunk(List<double> audioChunk) {
    audioBuffer.addAll(audioChunk);
    
    // Process when we have enough samples
    while (audioBuffer.length >= widget.fftSize) {
      final frame = audioBuffer.take(widget.fftSize).toList();
      audioBuffer.removeRange(0, widget.hopSize);
      
      final spectrum = _computeSpectrum(frame);
      final magnitudes = _convertToMagnitudes(spectrum);
      final dbMagnitudes = _convertToDecibels(magnitudes);
      
      setState(() {
        spectrogramData.add(dbMagnitudes);
        
        // Keep only recent data
        if (spectrogramData.length > maxTimeSlices) {
          spectrogramData.removeAt(0);
        }
      });
    }
  }
  
  List<double> _computeSpectrum(List<double> frame) {
    // Apply window function
    final windowedFrame = Float32List(widget.fftSize);
    for (int i = 0; i < widget.fftSize; i++) {
      windowedFrame[i] = frame[i] * window[i];
    }
    
    // Compute FFT
    final spectrum = fft.realFft(windowedFrame);
    
    // Return magnitudes
    return spectrum.map((complex) => 
        math.sqrt(complex.x * complex.x + complex.y * complex.y)).toList();
  }
  
  List<double> _convertToMagnitudes(List<double> spectrum) {
    return spectrum;
  }
  
  List<double> _convertToDecibels(List<double> magnitudes) {
    return magnitudes.map((mag) => 
        20 * math.log(math.max(mag, 1e-10)) / math.ln10).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: displayHeight.toDouble(),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: SpectrogramPainter(
              spectrogramData: spectrogramData,
              sampleRate: widget.sampleRate,
              fftSize: widget.fftSize,
              minFrequency: widget.minFrequency,
              maxFrequency: widget.maxFrequency,
              colorScheme: widget.colorScheme,
              logScale: widget.logScale,
              dynamicRange: widget.dynamicRange,
            ),
          ),
          if (widget.showFrequencyLabels) _buildFrequencyLabels(),
          if (widget.showTimeLabels) _buildTimeLabels(),
        ],
      ),
    );
  }
  
  Widget _buildFrequencyLabels() {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 60,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: CustomPaint(
          painter: FrequencyLabelsPainter(
            minFrequency: widget.minFrequency,
            maxFrequency: widget.maxFrequency,
            logScale: widget.logScale,
            textStyle: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTimeLabels() {
    return Positioned(
      left: widget.showFrequencyLabels ? 60 : 0,
      right: 0,
      bottom: 0,
      height: 20,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: CustomPaint(
          painter: TimeLabelsPainter(
            hopSize: widget.hopSize,
            sampleRate: widget.sampleRate,
            timeSlices: spectrogramData.length,
            textStyle: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for spectrogram visualization
class SpectrogramPainter extends CustomPainter {
  final List<List<double>> spectrogramData;
  final int sampleRate;
  final int fftSize;
  final double minFrequency;
  final double maxFrequency;
  final SpectrogramColorScheme colorScheme;
  final bool logScale;
  final double dynamicRange;
  
  SpectrogramPainter({
    required this.spectrogramData,
    required this.sampleRate,
    required this.fftSize,
    required this.minFrequency,
    required this.maxFrequency,
    required this.colorScheme,
    required this.logScale,
    required this.dynamicRange,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (spectrogramData.isEmpty) return;
    
    final paint = Paint();
    final frequencyBins = fftSize ~/ 2 + 1;
    final frequencyResolution = sampleRate / fftSize;
    
    // Calculate frequency indices
    final minBin = (minFrequency / frequencyResolution).round();
    final maxBin = math.min(frequencyBins - 1, (maxFrequency / frequencyResolution).round());
    
    final timeSliceWidth = size.width / spectrogramData.length;
    final frequencyHeight = size.height / (maxBin - minBin);
    
    for (int timeIndex = 0; timeIndex < spectrogramData.length; timeIndex++) {
      final spectrum = spectrogramData[timeIndex];
      
      for (int freqIndex = minBin; freqIndex < maxBin; freqIndex++) {
        if (freqIndex >= spectrum.length) continue;
        
        final magnitude = spectrum[freqIndex];
        final normalizedMagnitude = _normalizeMagnitude(magnitude);
        final color = _getColor(normalizedMagnitude);
        
        paint.color = color;
        
        // Calculate position
        final x = timeIndex * timeSliceWidth;
        final y = logScale ? 
            _getLogScaleY(freqIndex, minBin, maxBin, size.height) :
            _getLinearScaleY(freqIndex, minBin, maxBin, size.height);
        
        canvas.drawRect(
          Rect.fromLTWH(x, y, timeSliceWidth, frequencyHeight),
          paint,
        );
      }
    }
  }
  
  double _normalizeMagnitude(double magnitude) {
    // Normalize to 0-1 range based on dynamic range
    final normalized = (magnitude + dynamicRange) / dynamicRange;
    return normalized.clamp(0.0, 1.0);
  }
  
  double _getLinearScaleY(int freqIndex, int minBin, int maxBin, double height) {
    final normalizedFreq = (freqIndex - minBin) / (maxBin - minBin);
    return height * (1.0 - normalizedFreq);
  }
  
  double _getLogScaleY(int freqIndex, int minBin, int maxBin, double height) {
    final frequency = freqIndex * (sampleRate / fftSize);
    final logMin = math.log(minFrequency);
    final logMax = math.log(maxFrequency);
    final logFreq = math.log(frequency);
    
    final normalizedFreq = (logFreq - logMin) / (logMax - logMin);
    return height * (1.0 - normalizedFreq.clamp(0.0, 1.0));
  }
  
  Color _getColor(double normalizedMagnitude) {
    switch (colorScheme) {
      case SpectrogramColorScheme.jet:
        return _getJetColor(normalizedMagnitude);
      case SpectrogramColorScheme.viridis:
        return _getViridisColor(normalizedMagnitude);
      case SpectrogramColorScheme.plasma:
        return _getPlasmaColor(normalizedMagnitude);
      case SpectrogramColorScheme.grayscale:
        return _getGrayscaleColor(normalizedMagnitude);
      case SpectrogramColorScheme.hot:
        return _getHotColor(normalizedMagnitude);
    }
  }
  
  Color _getJetColor(double value) {
    if (value <= 0.125) {
      return Color.lerp(Colors.blue[900]!, Colors.blue, value * 8)!;
    } else if (value <= 0.375) {
      return Color.lerp(Colors.blue, Colors.cyan, (value - 0.125) * 4)!;
    } else if (value <= 0.625) {
      return Color.lerp(Colors.cyan, Colors.yellow, (value - 0.375) * 4)!;
    } else if (value <= 0.875) {
      return Color.lerp(Colors.yellow, Colors.red, (value - 0.625) * 4)!;
    } else {
      return Color.lerp(Colors.red, Colors.red[900]!, (value - 0.875) * 8)!;
    }
  }
  
  Color _getViridisColor(double value) {
    // Simplified Viridis colormap
    final colors = [
      const Color(0xFF440154),
      const Color(0xFF31688E),
      const Color(0xFF35B779),
      const Color(0xFFFDE725),
    ];
    
    final scaledValue = value * (colors.length - 1);
    final index = scaledValue.floor();
    final fraction = scaledValue - index;
    
    if (index >= colors.length - 1) return colors.last;
    
    return Color.lerp(colors[index], colors[index + 1], fraction)!;
  }
  
  Color _getPlasmaColor(double value) {
    // Simplified Plasma colormap
    final colors = [
      const Color(0xFF0D0887),
      const Color(0xFF7E03A8),
      const Color(0xFFCC4778),
      const Color(0xFFF89540),
      const Color(0xFFF0F921),
    ];
    
    final scaledValue = value * (colors.length - 1);
    final index = scaledValue.floor();
    final fraction = scaledValue - index;
    
    if (index >= colors.length - 1) return colors.last;
    
    return Color.lerp(colors[index], colors[index + 1], fraction)!;
  }
  
  Color _getGrayscaleColor(double value) {
    final intensity = (value * 255).round();
    return Color.fromARGB(255, intensity, intensity, intensity);
  }
  
  Color _getHotColor(double value) {
    if (value <= 0.33) {
      final red = (value * 3 * 255).round();
      return Color.fromARGB(255, red, 0, 0);
    } else if (value <= 0.66) {
      final green = ((value - 0.33) * 3 * 255).round();
      return Color.fromARGB(255, 255, green, 0);
    } else {
      final blue = ((value - 0.66) * 3 * 255).round();
      return Color.fromARGB(255, 255, 255, blue);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Painter for frequency labels
class FrequencyLabelsPainter extends CustomPainter {
  final double minFrequency;
  final double maxFrequency;
  final bool logScale;
  final TextStyle textStyle;
  
  FrequencyLabelsPainter({
    required this.minFrequency,
    required this.maxFrequency,
    required this.logScale,
    required this.textStyle,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final frequencies = _getFrequencyTicks();
    
    for (final frequency in frequencies) {
      final y = logScale ? 
          _getLogScaleY(frequency, size.height) :
          _getLinearScaleY(frequency, size.height);
      
      final text = _formatFrequency(frequency);
      final textPainter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }
  }
  
  List<double> _getFrequencyTicks() {
    if (logScale) {
      return [100, 200, 500, 1000, 2000, 4000, 8000]
          .where((f) => f >= minFrequency && f <= maxFrequency)
          .toList();
    } else {
      final step = (maxFrequency - minFrequency) / 8;
      return List.generate(9, (i) => minFrequency + i * step);
    }
  }
  
  double _getLinearScaleY(double frequency, double height) {
    final normalizedFreq = (frequency - minFrequency) / (maxFrequency - minFrequency);
    return height * (1.0 - normalizedFreq);
  }
  
  double _getLogScaleY(double frequency, double height) {
    final logMin = math.log(minFrequency);
    final logMax = math.log(maxFrequency);
    final logFreq = math.log(frequency);
    
    final normalizedFreq = (logFreq - logMin) / (logMax - logMin);
    return height * (1.0 - normalizedFreq);
  }
  
  String _formatFrequency(double frequency) {
    if (frequency >= 1000) {
      return '${(frequency / 1000).toStringAsFixed(1)}k';
    } else {
      return '${frequency.round()}';
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter for time labels
class TimeLabelsPainter extends CustomPainter {
  final int hopSize;
  final int sampleRate;
  final int timeSlices;
  final TextStyle textStyle;
  
  TimeLabelsPainter({
    required this.hopSize,
    required this.sampleRate,
    required this.timeSlices,
    required this.textStyle,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final timePerSlice = hopSize / sampleRate;
    final totalTime = timeSlices * timePerSlice;
    final timeStep = totalTime / 5; // 5 labels
    
    for (int i = 0; i <= 5; i++) {
      final time = i * timeStep;
      final x = (i / 5) * size.width;
      
      final text = '${time.toStringAsFixed(1)}s';
      final textPainter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, 2));
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Color schemes for spectrogram visualization
enum SpectrogramColorScheme {
  jet,
  viridis,
  plasma,
  grayscale,
  hot,
}