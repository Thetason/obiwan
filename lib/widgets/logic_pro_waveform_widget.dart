import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Logic Pro 스타일 프로덕션 레벨 웨이브폼 위젯
/// 전문가급 오디오 편집 소프트웨어 수준의 웨이브폼 표시
class LogicProWaveformWidget extends StatefulWidget {
  final List<double> audioData;
  final double sampleRate;
  final double timeRange;
  final double currentTime;
  final bool enableZoom;
  final bool showSpectralView;
  final WaveformColorScheme colorScheme;
  final double amplitude;
  final bool showMarkers;
  final List<TimeMarker> markers;
  
  const LogicProWaveformWidget({
    super.key,
    required this.audioData,
    this.sampleRate = 44100.0,
    this.timeRange = 10.0,
    this.currentTime = 0.0,
    this.enableZoom = true,
    this.showSpectralView = false,
    this.colorScheme = WaveformColorScheme.professional,
    this.amplitude = 1.0,
    this.showMarkers = true,
    this.markers = const [],
  });

  @override
  State<LogicProWaveformWidget> createState() => _LogicProWaveformWidgetState();
}

class _LogicProWaveformWidgetState extends State<LogicProWaveformWidget>
    with TickerProviderStateMixin {
  
  late AnimationController _playheadController;
  late AnimationController _analyzerController;
  late AnimationController _spectralController;
  late Animation<double> _playheadAnimation;
  late Animation<double> _analyzerAnimation;
  late Animation<double> _spectralAnimation;
  
  double _zoomLevel = 1.0;
  double _scrollPosition = 0.0;
  List<List<double>> _spectralData = [];
  List<double> _peakData = [];
  List<double> _rmsData = [];
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _processAudioData();
  }
  
  void _initializeAnimations() {
    _playheadController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
    
    _analyzerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _spectralController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
    
    _playheadAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _playheadController,
      curve: Curves.easeInOut,
    ));
    
    _analyzerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _analyzerController,
      curve: Curves.easeOutCubic,
    ));
    
    _spectralAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_spectralController);
    
    _analyzerController.forward();
  }
  
  void _processAudioData() async {
    if (widget.audioData.isEmpty) return;
    
    // Peak 데이터 생성
    _peakData = _calculatePeakData(widget.audioData);
    
    // RMS 데이터 생성
    _rmsData = _calculateRMSData(widget.audioData);
    
    // 스펙트럼 데이터 생성 (스펙트럼 뷰 사용시)
    if (widget.showSpectralView) {
      _spectralData = _generateSpectralData(widget.audioData);
    }
    
    if (mounted) {
      setState(() {});
    }
  }
  
  List<double> _calculatePeakData(List<double> audioData) {
    final int windowSize = (audioData.length / 1000).round().clamp(1, audioData.length);
    final peaks = <double>[];
    
    for (int i = 0; i < audioData.length; i += windowSize) {
      final end = math.min(i + windowSize, audioData.length);
      double maxPeak = 0.0;
      
      for (int j = i; j < end; j++) {
        maxPeak = math.max(maxPeak, audioData[j].abs());
      }
      
      peaks.add(maxPeak);
    }
    
    return peaks;
  }
  
  List<double> _calculateRMSData(List<double> audioData) {
    final int windowSize = (audioData.length / 1000).round().clamp(1, audioData.length);
    final rms = <double>[];
    
    for (int i = 0; i < audioData.length; i += windowSize) {
      final end = math.min(i + windowSize, audioData.length);
      double sum = 0.0;
      
      for (int j = i; j < end; j++) {
        sum += audioData[j] * audioData[j];
      }
      
      rms.add(math.sqrt(sum / (end - i)));
    }
    
    return rms;
  }
  
  List<List<double>> _generateSpectralData(List<double> audioData) {
    final spectralData = <List<double>>[];
    final windowSize = 2048;
    final hopSize = windowSize ~/ 4;
    
    for (int i = 0; i < audioData.length - windowSize; i += hopSize) {
      final chunk = audioData.sublist(i, i + windowSize);
      final spectrum = _performFFT(chunk);
      spectralData.add(spectrum);
    }
    
    return spectralData;
  }
  
  List<double> _performFFT(List<double> audioChunk) {
    final N = audioChunk.length;
    final magnitudes = List<double>.filled(N ~/ 2, 0.0);
    
    for (int k = 0; k < N ~/ 2; k++) {
      double real = 0, imag = 0;
      for (int n = 0; n < N; n++) {
        final angle = -2 * math.pi * k * n / N;
        real += audioChunk[n] * math.cos(angle);
        imag += audioChunk[n] * math.sin(angle);
      }
      magnitudes[k] = math.sqrt(real * real + imag * imag);
    }
    
    // 로그 스케일링
    for (int i = 0; i < magnitudes.length; i++) {
      magnitudes[i] = math.log(magnitudes[i] + 1.0) / math.log(1000.0);
      magnitudes[i] = magnitudes[i].clamp(0.0, 1.0);
    }
    
    return magnitudes;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1a1a),
            Color(0xFF0d0d0d),
            Color(0xFF000000),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _getSchemeColor().withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onScaleUpdate: widget.enableZoom ? _handleZoomUpdate : null,
          onPanUpdate: _handlePanUpdate,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _playheadAnimation,
              _analyzerAnimation,
              _spectralAnimation,
            ]),
            builder: (context, child) {
              return Stack(
                children: [
                  // 배경 그리드
                  _buildTimeGrid(),
                  
                  // 메인 웨이브폼
                  if (!widget.showSpectralView) 
                    CustomPaint(
                      painter: LogicProWaveformPainter(
                        peakData: _peakData,
                        rmsData: _rmsData,
                        colorScheme: widget.colorScheme,
                        zoomLevel: _zoomLevel,
                        scrollPosition: _scrollPosition,
                        amplitude: widget.amplitude,
                        animationProgress: _analyzerAnimation.value,
                      ),
                      child: Container(),
                    ),
                  
                  // 스펙트럼 뷰
                  if (widget.showSpectralView && _spectralData.isNotEmpty)
                    CustomPaint(
                      painter: SpectralWaveformPainter(
                        spectralData: _spectralData,
                        colorScheme: widget.colorScheme,
                        zoomLevel: _zoomLevel,
                        scrollPosition: _scrollPosition,
                        animationProgress: _spectralAnimation.value,
                      ),
                      child: Container(),
                    ),
                  
                  // 재생 헤드
                  _buildPlayhead(),
                  
                  // 타임 마커
                  if (widget.showMarkers) _buildTimeMarkers(),
                  
                  // 레벨 미터
                  _buildLevelMeter(),
                  
                  // 컨트롤 오버레이
                  _buildControlOverlay(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  void _handleZoomUpdate(ScaleUpdateDetails details) {
    setState(() {
      _zoomLevel = (_zoomLevel * details.scale).clamp(0.1, 10.0);
    });
  }
  
  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _scrollPosition += details.delta.dx / _zoomLevel;
      _scrollPosition = _scrollPosition.clamp(0.0, widget.audioData.length.toDouble());
    });
  }
  
  Widget _buildTimeGrid() {
    return CustomPaint(
      painter: TimeGridPainter(
        timeRange: widget.timeRange,
        zoomLevel: _zoomLevel,
        scrollPosition: _scrollPosition,
        gridColor: _getSchemeColor().withOpacity(0.3),
      ),
      child: Container(),
    );
  }
  
  Widget _buildPlayhead() {
    return Positioned.fill(
      child: CustomPaint(
        painter: PlayheadPainter(
          currentTime: widget.currentTime,
          timeRange: widget.timeRange,
          zoomLevel: _zoomLevel,
          scrollPosition: _scrollPosition,
          playheadColor: _getSchemeColor(),
          pulseScale: _playheadAnimation.value,
        ),
        child: Container(),
      ),
    );
  }
  
  Widget _buildTimeMarkers() {
    return Positioned.fill(
      child: CustomPaint(
        painter: TimeMarkerPainter(
          markers: widget.markers,
          timeRange: widget.timeRange,
          zoomLevel: _zoomLevel,
          scrollPosition: _scrollPosition,
          markerColor: _getSchemeColor().withOpacity(0.8),
        ),
        child: Container(),
      ),
    );
  }
  
  Widget _buildLevelMeter() {
    if (_peakData.isEmpty) return Container();
    
    final currentLevel = _peakData.isNotEmpty ? _peakData.last : 0.0;
    
    return Positioned(
      right: 20,
      top: 20,
      child: Container(
        width: 80,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getSchemeColor().withOpacity(0.5),
            width: 1,
          ),
        ),
        child: CustomPaint(
          painter: LevelMeterPainter(
            level: currentLevel,
            colorScheme: widget.colorScheme,
            animationProgress: _analyzerAnimation.value,
          ),
          child: Container(),
        ),
      ),
    );
  }
  
  Widget _buildControlOverlay() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getSchemeColor().withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _getSchemeColor().withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 시간 정보
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TIME',
                  style: TextStyle(
                    color: _getSchemeColor().withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_formatTime(widget.currentTime)}',
                  style: TextStyle(
                    color: _getSchemeColor(),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            
            // 줌 레벨
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'ZOOM',
                  style: TextStyle(
                    color: _getSchemeColor().withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(_zoomLevel * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: _getSchemeColor(),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            
            // 샘플레이트 정보
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'SAMPLE RATE',
                  style: TextStyle(
                    color: _getSchemeColor().withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(widget.sampleRate / 1000).toStringAsFixed(1)}kHz',
                  style: TextStyle(
                    color: _getSchemeColor(),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getSchemeColor() {
    switch (widget.colorScheme) {
      case WaveformColorScheme.professional:
        return const Color(0xFF00ff88);
      case WaveformColorScheme.classic:
        return const Color(0xFF0088ff);
      case WaveformColorScheme.warm:
        return const Color(0xFFff8800);
      case WaveformColorScheme.cool:
        return const Color(0xFF00ffff);
      case WaveformColorScheme.neon:
        return const Color(0xFFff00ff);
    }
  }
  
  String _formatTime(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60);
    return '${minutes.toString().padLeft(2, '0')}:${secs.toStringAsFixed(1).padLeft(4, '0')}';
  }
  
  @override
  void dispose() {
    _playheadController.dispose();
    _analyzerController.dispose();
    _spectralController.dispose();
    super.dispose();
  }
}

/// Logic Pro 웨이브폼 페인터
class LogicProWaveformPainter extends CustomPainter {
  final List<double> peakData;
  final List<double> rmsData;
  final WaveformColorScheme colorScheme;
  final double zoomLevel;
  final double scrollPosition;
  final double amplitude;
  final double animationProgress;
  
  LogicProWaveformPainter({
    required this.peakData,
    required this.rmsData,
    required this.colorScheme,
    required this.zoomLevel,
    required this.scrollPosition,
    required this.amplitude,
    required this.animationProgress,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (peakData.isEmpty) return;
    
    final center = size.height / 2;
    final pixelsPerSample = size.width / peakData.length * zoomLevel;
    
    // RMS 배경 그리기
    _drawRMSWaveform(canvas, size, center, pixelsPerSample);
    
    // Peak 웨이브폼 그리기
    _drawPeakWaveform(canvas, size, center, pixelsPerSample);
    
    // 하이라이트 효과
    _drawHighlights(canvas, size, center, pixelsPerSample);
  }
  
  void _drawRMSWaveform(Canvas canvas, Size size, double center, double pixelsPerSample) {
    if (rmsData.isEmpty) return;
    
    final rmsPaint = Paint()
      ..color = _getColorForScheme().withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    final bottomPath = Path();
    
    for (int i = 0; i < rmsData.length; i++) {
      final x = i * pixelsPerSample - scrollPosition;
      if (x < -pixelsPerSample || x > size.width + pixelsPerSample) continue;
      
      final rmsValue = rmsData[i] * amplitude * animationProgress;
      final topY = center - rmsValue * center;
      final bottomY = center + rmsValue * center;
      
      if (i == 0) {
        path.moveTo(x, topY);
        bottomPath.moveTo(x, bottomY);
      } else {
        path.lineTo(x, topY);
        bottomPath.lineTo(x, bottomY);
      }
    }
    
    // 채우기를 위한 패스 연결
    final fullPath = Path.from(path);
    for (int i = bottomPath.fillType == PathFillType.nonZero ? rmsData.length - 1 : 0; 
         i >= 0; i--) {
      final x = i * pixelsPerSample - scrollPosition;
      final rmsValue = rmsData[i] * amplitude * animationProgress;
      final bottomY = center + rmsValue * center;
      fullPath.lineTo(x, bottomY);
    }
    fullPath.close();
    
    canvas.drawPath(fullPath, rmsPaint);
  }
  
  void _drawPeakWaveform(Canvas canvas, Size size, double center, double pixelsPerSample) {
    final peakPaint = Paint()
      ..color = _getColorForScheme()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final topPath = Path();
    final bottomPath = Path();
    
    for (int i = 0; i < peakData.length; i++) {
      final x = i * pixelsPerSample - scrollPosition;
      if (x < -pixelsPerSample || x > size.width + pixelsPerSample) continue;
      
      final peakValue = peakData[i] * amplitude * animationProgress;
      final topY = center - peakValue * center;
      final bottomY = center + peakValue * center;
      
      if (i == 0) {
        topPath.moveTo(x, topY);
        bottomPath.moveTo(x, bottomY);
      } else {
        topPath.lineTo(x, topY);
        bottomPath.lineTo(x, bottomY);
      }
    }
    
    canvas.drawPath(topPath, peakPaint);
    canvas.drawPath(bottomPath, peakPaint);
    
    // 글로우 효과
    final glowPaint = Paint()
      ..color = _getColorForScheme().withOpacity(0.5)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    
    canvas.drawPath(topPath, glowPaint);
    canvas.drawPath(bottomPath, glowPaint);
  }
  
  void _drawHighlights(Canvas canvas, Size size, double center, double pixelsPerSample) {
    final highlightPaint = Paint()
      ..color = _getColorForScheme().withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    // 높은 피크값에 하이라이트 추가
    for (int i = 0; i < peakData.length; i++) {
      if (peakData[i] > 0.8) {  // 80% 이상의 피크에만 하이라이트
        final x = i * pixelsPerSample - scrollPosition;
        if (x < 0 || x > size.width) continue;
        
        final peakValue = peakData[i] * amplitude * animationProgress;
        final topY = center - peakValue * center;
        final bottomY = center + peakValue * center;
        
        // 작은 점으로 하이라이트 표시
        canvas.drawCircle(Offset(x, topY), 2, highlightPaint);
        canvas.drawCircle(Offset(x, bottomY), 2, highlightPaint);
      }
    }
  }
  
  Color _getColorForScheme() {
    switch (colorScheme) {
      case WaveformColorScheme.professional:
        return const Color(0xFF00ff88);
      case WaveformColorScheme.classic:
        return const Color(0xFF0088ff);
      case WaveformColorScheme.warm:
        return const Color(0xFFff8800);
      case WaveformColorScheme.cool:
        return const Color(0xFF00ffff);
      case WaveformColorScheme.neon:
        return const Color(0xFFff00ff);
    }
  }
  
  @override
  bool shouldRepaint(LogicProWaveformPainter oldDelegate) {
    return oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.scrollPosition != scrollPosition ||
           oldDelegate.animationProgress != animationProgress ||
           oldDelegate.amplitude != amplitude;
  }
}

/// 스펙트럼 웨이브폼 페인터
class SpectralWaveformPainter extends CustomPainter {
  final List<List<double>> spectralData;
  final WaveformColorScheme colorScheme;
  final double zoomLevel;
  final double scrollPosition;
  final double animationProgress;
  
  SpectralWaveformPainter({
    required this.spectralData,
    required this.colorScheme,
    required this.zoomLevel,
    required this.scrollPosition,
    required this.animationProgress,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (spectralData.isEmpty) return;
    
    final pixelWidth = size.width / spectralData.length * zoomLevel;
    final pixelHeight = size.height / (spectralData[0].length);
    
    for (int col = 0; col < spectralData.length; col++) {
      final x = col * pixelWidth - scrollPosition;
      if (x < -pixelWidth || x > size.width + pixelWidth) continue;
      
      for (int row = 0; row < spectralData[col].length; row++) {
        final intensity = spectralData[col][row] * animationProgress;
        if (intensity < 0.1) continue;
        
        final y = size.height - (row + 1) * pixelHeight;
        
        final paint = Paint()
          ..color = _getSpectralColor(intensity)
          ..style = PaintingStyle.fill;
        
        final rect = Rect.fromLTWH(x, y, pixelWidth, pixelHeight);
        canvas.drawRect(rect, paint);
        
        // 고강도 영역에 글로우 추가
        if (intensity > 0.7) {
          paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
          canvas.drawRect(rect, paint);
          paint.maskFilter = null;
        }
      }
    }
  }
  
  Color _getSpectralColor(double intensity) {
    switch (colorScheme) {
      case WaveformColorScheme.professional:
        return Color.lerp(
          const Color(0xFF001a0d),
          const Color(0xFF00ff88),
          intensity,
        )!;
      case WaveformColorScheme.classic:
        return Color.lerp(
          const Color(0xFF000d1a),
          const Color(0xFF0088ff),
          intensity,
        )!;
      case WaveformColorScheme.warm:
        return Color.lerp(
          const Color(0xFF1a0d00),
          const Color(0xFFff8800),
          intensity,
        )!;
      case WaveformColorScheme.cool:
        return Color.lerp(
          const Color(0xFF001a1a),
          const Color(0xFF00ffff),
          intensity,
        )!;
      case WaveformColorScheme.neon:
        return Color.lerp(
          const Color(0xFF1a001a),
          const Color(0xFFff00ff),
          intensity,
        )!;
    }
  }
  
  @override
  bool shouldRepaint(SpectralWaveformPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.scrollPosition != scrollPosition;
  }
}

/// 시간 격자 페인터
class TimeGridPainter extends CustomPainter {
  final double timeRange;
  final double zoomLevel;
  final double scrollPosition;
  final Color gridColor;
  
  TimeGridPainter({
    required this.timeRange,
    required this.zoomLevel,
    required this.scrollPosition,
    required this.gridColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    final secondWidth = size.width / timeRange * zoomLevel;
    
    // 세로 격자선 (1초 간격)
    for (double time = 0; time <= timeRange; time += 1.0) {
      final x = time * secondWidth - scrollPosition;
      if (x >= 0 && x <= size.width) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          paint,
        );
      }
    }
    
    // 가로 격자선
    final paint2 = Paint()
      ..color = gridColor.withOpacity(0.3)
      ..strokeWidth = 0.3;
    
    final intervals = [0.25, 0.5, 0.75];
    for (final interval in intervals) {
      final y = size.height * interval;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint2,
      );
    }
    
    // 중앙선 (0 레벨)
    final centerPaint = Paint()
      ..color = gridColor.withOpacity(0.6)
      ..strokeWidth = 1.0;
    
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      centerPaint,
    );
  }
  
  @override
  bool shouldRepaint(TimeGridPainter oldDelegate) {
    return oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.scrollPosition != scrollPosition;
  }
}

/// 재생 헤드 페인터
class PlayheadPainter extends CustomPainter {
  final double currentTime;
  final double timeRange;
  final double zoomLevel;
  final double scrollPosition;
  final Color playheadColor;
  final double pulseScale;
  
  PlayheadPainter({
    required this.currentTime,
    required this.timeRange,
    required this.zoomLevel,
    required this.scrollPosition,
    required this.playheadColor,
    required this.pulseScale,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final x = (currentTime / timeRange * size.width) * zoomLevel - scrollPosition;
    
    if (x < 0 || x > size.width) return;
    
    final paint = Paint()
      ..color = playheadColor
      ..strokeWidth = 2.0 * pulseScale
      ..style = PaintingStyle.stroke;
    
    // 재생 헤드 라인
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      paint,
    );
    
    // 헤드 표시
    final headPaint = Paint()
      ..color = playheadColor
      ..style = PaintingStyle.fill;
    
    final headPath = Path();
    headPath.moveTo(x - 8 * pulseScale, 0);
    headPath.lineTo(x + 8 * pulseScale, 0);
    headPath.lineTo(x, 15 * pulseScale);
    headPath.close();
    
    canvas.drawPath(headPath, headPaint);
    
    // 글로우 효과
    final glowPaint = Paint()
      ..color = playheadColor.withOpacity(0.6)
      ..strokeWidth = 4.0 * pulseScale
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      glowPaint,
    );
  }
  
  @override
  bool shouldRepaint(PlayheadPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
           oldDelegate.pulseScale != pulseScale ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.scrollPosition != scrollPosition;
  }
}

/// 타임 마커 페인터
class TimeMarkerPainter extends CustomPainter {
  final List<TimeMarker> markers;
  final double timeRange;
  final double zoomLevel;
  final double scrollPosition;
  final Color markerColor;
  
  TimeMarkerPainter({
    required this.markers,
    required this.timeRange,
    required this.zoomLevel,
    required this.scrollPosition,
    required this.markerColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    for (final marker in markers) {
      final x = (marker.time / timeRange * size.width) * zoomLevel - scrollPosition;
      
      if (x < 0 || x > size.width) continue;
      
      final paint = Paint()
        ..color = marker.color ?? markerColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      
      // 마커 라인
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
      
      // 마커 레이블
      final textPainter = TextPainter(
        text: TextSpan(
          text: marker.label,
          style: TextStyle(
            color: marker.color ?? markerColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      // 배경 박스
      final labelRect = Rect.fromLTWH(
        x + 5,
        5,
        textPainter.width + 6,
        textPainter.height + 4,
      );
      
      final backgroundPaint = Paint()
        ..color = Colors.black.withOpacity(0.8)
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
        backgroundPaint,
      );
      
      textPainter.paint(canvas, Offset(x + 8, 7));
    }
  }
  
  @override
  bool shouldRepaint(TimeMarkerPainter oldDelegate) {
    return oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.scrollPosition != scrollPosition;
  }
}

/// 레벨 미터 페인터
class LevelMeterPainter extends CustomPainter {
  final double level;
  final WaveformColorScheme colorScheme;
  final double animationProgress;
  
  LevelMeterPainter({
    required this.level,
    required this.colorScheme,
    required this.animationProgress,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final segments = 20;
    final segmentHeight = size.height / segments;
    final activeSegments = (level * segments * animationProgress).round();
    
    for (int i = 0; i < segments; i++) {
      final y = size.height - (i + 1) * segmentHeight;
      final rect = Rect.fromLTWH(10, y + 2, size.width - 20, segmentHeight - 4);
      
      final paint = Paint()..style = PaintingStyle.fill;
      
      if (i < activeSegments) {
        // 활성 세그먼트 색상
        if (i < segments * 0.7) {
          paint.color = _getSchemeColor().withOpacity(0.8);
        } else if (i < segments * 0.9) {
          paint.color = const Color(0xFFffaa00).withOpacity(0.8);
        } else {
          paint.color = const Color(0xFFff0000).withOpacity(0.8);
        }
        
        // 글로우 효과
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
      } else {
        // 비활성 세그먼트
        paint.color = Colors.grey.withOpacity(0.2);
      }
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
    
    // dB 레이블
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(level * 100).toStringAsFixed(0)}%',
        style: TextStyle(
          color: _getSchemeColor(),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas, 
      Offset(size.width / 2 - textPainter.width / 2, size.height + 5),
    );
  }
  
  Color _getSchemeColor() {
    switch (colorScheme) {
      case WaveformColorScheme.professional:
        return const Color(0xFF00ff88);
      case WaveformColorScheme.classic:
        return const Color(0xFF0088ff);
      case WaveformColorScheme.warm:
        return const Color(0xFFff8800);
      case WaveformColorScheme.cool:
        return const Color(0xFF00ffff);
      case WaveformColorScheme.neon:
        return const Color(0xFFff00ff);
    }
  }
  
  @override
  bool shouldRepaint(LevelMeterPainter oldDelegate) {
    return oldDelegate.level != level ||
           oldDelegate.animationProgress != animationProgress;
  }
}

/// 웨이브폼 색상 스킴
enum WaveformColorScheme {
  professional,  // 전문가용 그린
  classic,       // 클래식 블루
  warm,          // 따뜻한 오렌지
  cool,          // 시원한 시안
  neon,          // 네온 핑크
}

/// 타임 마커 클래스
class TimeMarker {
  final double time;
  final String label;
  final Color? color;
  
  const TimeMarker({
    required this.time,
    required this.label,
    this.color,
  });
}