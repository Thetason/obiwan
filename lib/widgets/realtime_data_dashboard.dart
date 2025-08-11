import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import '../models/pitch_point.dart';

/// 실시간 데이터 대시보드 - 프로 레벨 음성 분석 모니터링
/// 스튜디오급 실시간 분석 정보를 종합적으로 표시
class RealtimeDataDashboard extends StatefulWidget {
  final List<PitchPoint> pitchData;
  final List<double> audioSpectrum;
  final double currentFrequency;
  final double currentAmplitude;
  final double pitchStability;
  final double vibrato;
  final String detectedNote;
  final double confidence;
  final bool isRecording;
  final DashboardTheme theme;
  
  const RealtimeDataDashboard({
    super.key,
    required this.pitchData,
    required this.audioSpectrum,
    this.currentFrequency = 0.0,
    this.currentAmplitude = 0.0,
    this.pitchStability = 0.0,
    this.vibrato = 0.0,
    this.detectedNote = '--',
    this.confidence = 0.0,
    this.isRecording = false,
    this.theme = DashboardTheme.professional,
  });

  @override
  State<RealtimeDataDashboard> createState() => _RealtimeDataDashboardState();
}

class _RealtimeDataDashboardState extends State<RealtimeDataDashboard>
    with TickerProviderStateMixin {
  
  late AnimationController _recordingController;
  late AnimationController _dataUpdateController;
  late AnimationController _stabilityController;
  late Animation<double> _recordingAnimation;
  late Animation<double> _dataUpdateAnimation;
  late Animation<double> _stabilityAnimation;
  
  Timer? _updateTimer;
  List<DataPoint> _frequencyHistory = [];
  List<DataPoint> _amplitudeHistory = [];
  List<DataPoint> _stabilityHistory = [];
  double _peakFrequency = 0.0;
  double _avgFrequency = 0.0;
  double _frequencyRange = 0.0;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startDataCollection();
  }
  
  void _initializeAnimations() {
    _recordingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _dataUpdateController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _stabilityController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _recordingAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _recordingController,
      curve: Curves.easeInOut,
    ));
    
    _dataUpdateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dataUpdateController,
      curve: Curves.easeOutBack,
    ));
    
    _stabilityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _stabilityController,
      curve: Curves.elasticOut,
    ));
    
    if (widget.isRecording) {
      _recordingController.repeat(reverse: true);
    }
    
    _dataUpdateController.forward();
    _stabilityController.forward();
  }
  
  void _startDataCollection() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _updateDataHistory();
      _calculateStatistics();
      if (mounted) {
        setState(() {});
      }
    });
  }
  
  void _updateDataHistory() {
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    const maxHistoryLength = 200;  // 20초 히스토리 (100ms 간격)
    
    // 주파수 히스토리 업데이트
    _frequencyHistory.add(DataPoint(now, widget.currentFrequency));
    if (_frequencyHistory.length > maxHistoryLength) {
      _frequencyHistory.removeAt(0);
    }
    
    // 진폭 히스토리 업데이트
    _amplitudeHistory.add(DataPoint(now, widget.currentAmplitude));
    if (_amplitudeHistory.length > maxHistoryLength) {
      _amplitudeHistory.removeAt(0);
    }
    
    // 안정성 히스토리 업데이트
    _stabilityHistory.add(DataPoint(now, widget.pitchStability));
    if (_stabilityHistory.length > maxHistoryLength) {
      _stabilityHistory.removeAt(0);
    }
  }
  
  void _calculateStatistics() {
    if (_frequencyHistory.isEmpty) return;
    
    final frequencies = _frequencyHistory.map((p) => p.value).where((f) => f > 0);
    if (frequencies.isEmpty) return;
    
    _peakFrequency = frequencies.reduce(math.max);
    _avgFrequency = frequencies.reduce((a, b) => a + b) / frequencies.length;
    _frequencyRange = frequencies.reduce(math.max) - frequencies.reduce(math.min);
  }
  
  @override
  void didUpdateWidget(RealtimeDataDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _recordingController.repeat(reverse: true);
      } else {
        _recordingController.stop();
      }
    }
    
    if (widget.currentFrequency != oldWidget.currentFrequency ||
        widget.currentAmplitude != oldWidget.currentAmplitude) {
      _dataUpdateController.reset();
      _dataUpdateController.forward();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getThemeGradientColors(),
        ),
        boxShadow: [
          BoxShadow(
            color: _getThemeAccentColor().withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // 배경 패턴
            _buildBackgroundPattern(),
            
            // 메인 콘텐츠
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더
                  _buildHeader(),
                  
                  const SizedBox(height: 20),
                  
                  // 주 데이터 디스플레이
                  Row(
                    children: [
                      // 주파수 및 음표 표시
                      Expanded(
                        flex: 2,
                        child: _buildMainFrequencyDisplay(),
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // 실시간 차트
                      Expanded(
                        flex: 3,
                        child: _buildRealtimeCharts(),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 통계 및 분석 정보
                  _buildAnalyticsSection(),
                  
                  const SizedBox(height: 20),
                  
                  // 하단 메트릭스
                  _buildBottomMetrics(),
                ],
              ),
            ),
            
            // 스캔 라인 효과
            if (widget.isRecording) _buildScanLineEffect(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBackgroundPattern() {
    return CustomPaint(
      painter: BackgroundPatternPainter(
        theme: widget.theme,
        animation: _dataUpdateAnimation.value,
      ),
      child: Container(),
    );
  }
  
  Widget _buildHeader() {
    return Row(
      children: [
        // 녹음 상태 표시
        AnimatedBuilder(
          animation: _recordingAnimation,
          builder: (context, child) {
            return Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: widget.isRecording 
                    ? Color.lerp(Colors.red, Colors.red.withOpacity(0.3), _recordingAnimation.value)
                    : Colors.grey,
                shape: BoxShape.circle,
                boxShadow: widget.isRecording ? [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.6 * _recordingAnimation.value),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ] : null,
              ),
            );
          },
        ),
        
        const SizedBox(width: 12),
        
        Text(
          'VOCAL ANALYSIS MONITOR',
          style: TextStyle(
            color: _getThemePrimaryColor(),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        
        const Spacer(),
        
        // 신뢰도 표시
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getThemeAccentColor().withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Text(
            'CONF: ${(widget.confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: _getThemeAccentColor(),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildMainFrequencyDisplay() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getThemePrimaryColor().withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 주파수 표시
          Text(
            'FREQUENCY',
            style: TextStyle(
              color: _getThemePrimaryColor().withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          
          const SizedBox(height: 8),
          
          AnimatedBuilder(
            animation: _dataUpdateAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.9 + (_dataUpdateAnimation.value * 0.1),
                child: Text(
                  '${widget.currentFrequency.toStringAsFixed(1)} Hz',
                  style: TextStyle(
                    color: _getThemePrimaryColor(),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    shadows: [
                      Shadow(
                        color: _getThemePrimaryColor().withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // 음표 표시
          Text(
            'NOTE',
            style: TextStyle(
              color: _getThemeAccentColor().withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            widget.detectedNote,
            style: TextStyle(
              color: _getThemeAccentColor(),
              fontSize: 28,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: _getThemeAccentColor().withOpacity(0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 진폭 표시
          Row(
            children: [
              Text(
                'AMPLITUDE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: widget.currentAmplitude,
                  backgroundColor: Colors.grey.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation(_getThemeAccentColor()),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(widget.currentAmplitude * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildRealtimeCharts() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getThemePrimaryColor().withOpacity(0.3),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: RealtimeChartPainter(
            frequencyHistory: _frequencyHistory,
            amplitudeHistory: _amplitudeHistory,
            stabilityHistory: _stabilityHistory,
            theme: widget.theme,
            animationProgress: _dataUpdateAnimation.value,
          ),
          child: Container(),
        ),
      ),
    );
  }
  
  Widget _buildAnalyticsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getThemeAccentColor().withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VOICE ANALYTICS',
            style: TextStyle(
              color: _getThemeAccentColor().withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              // 피치 안정성
              _buildAnalyticItem(
                'STABILITY',
                '${(widget.pitchStability * 100).toStringAsFixed(1)}%',
                widget.pitchStability,
                _getThemePrimaryColor(),
              ),
              
              const SizedBox(width: 20),
              
              // 비브라토
              _buildAnalyticItem(
                'VIBRATO',
                '${widget.vibrato.toStringAsFixed(2)} Hz',
                widget.vibrato / 10,  // 정규화
                _getThemeAccentColor(),
              ),
              
              const SizedBox(width: 20),
              
              // 주파수 범위
              _buildAnalyticItem(
                'RANGE',
                '${_frequencyRange.toStringAsFixed(0)} Hz',
                math.min(_frequencyRange / 1000, 1.0),  // 1kHz까지 정규화
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnalyticItem(String label, String value, double progress, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 4),
          
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          
          const SizedBox(height: 8),
          
          AnimatedBuilder(
            animation: _stabilityAnimation,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: progress * _stabilityAnimation.value,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation(color.withOpacity(0.8)),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildBottomMetrics() {
    return Row(
      children: [
        // 평균 주파수
        _buildMetricCard(
          'AVG FREQ',
          '${_avgFrequency.toStringAsFixed(1)} Hz',
          Icons.show_chart,
        ),
        
        const SizedBox(width: 16),
        
        // 피크 주파수
        _buildMetricCard(
          'PEAK FREQ',
          '${_peakFrequency.toStringAsFixed(1)} Hz',
          Icons.trending_up,
        ),
        
        const SizedBox(width: 16),
        
        // 데이터 포인트 수
        _buildMetricCard(
          'SAMPLES',
          '${_frequencyHistory.length}',
          Icons.data_usage,
        ),
      ],
    );
  }
  
  Widget _buildMetricCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: _getThemePrimaryColor(),
              size: 16,
            ),
            
            const SizedBox(width: 8),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: _getThemePrimaryColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildScanLineEffect() {
    return AnimatedBuilder(
      animation: _recordingAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                _getThemePrimaryColor().withOpacity(0.1 * _recordingAnimation.value),
                Colors.transparent,
              ],
              stops: [0.0, _recordingAnimation.value, 1.0],
            ),
          ),
        );
      },
    );
  }
  
  List<Color> _getThemeGradientColors() {
    switch (widget.theme) {
      case DashboardTheme.professional:
        return [
          const Color(0xFF0a1a0a),
          const Color(0xFF1a1a1a),
          const Color(0xFF0a0a0a),
        ];
      case DashboardTheme.cyberpunk:
        return [
          const Color(0xFF1a001a),
          const Color(0xFF0d001a),
          const Color(0xFF000d1a),
        ];
      case DashboardTheme.medical:
        return [
          const Color(0xFF001a1a),
          const Color(0xFF0d1a1a),
          const Color(0xFF000d0d),
        ];
      case DashboardTheme.warm:
        return [
          const Color(0xFF1a0d00),
          const Color(0xFF1a1a0d),
          const Color(0xFF0d0d00),
        ];
    }
  }
  
  Color _getThemePrimaryColor() {
    switch (widget.theme) {
      case DashboardTheme.professional:
        return const Color(0xFF00ff88);
      case DashboardTheme.cyberpunk:
        return const Color(0xFFff00ff);
      case DashboardTheme.medical:
        return const Color(0xFF00ffff);
      case DashboardTheme.warm:
        return const Color(0xFFff8800);
    }
  }
  
  Color _getThemeAccentColor() {
    switch (widget.theme) {
      case DashboardTheme.professional:
        return const Color(0xFFffaa00);
      case DashboardTheme.cyberpunk:
        return const Color(0xFF00ffff);
      case DashboardTheme.medical:
        return const Color(0xFFffff00);
      case DashboardTheme.warm:
        return const Color(0xFF00ff88);
    }
  }
  
  @override
  void dispose() {
    _recordingController.dispose();
    _dataUpdateController.dispose();
    _stabilityController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }
}

/// 실시간 차트 페인터
class RealtimeChartPainter extends CustomPainter {
  final List<DataPoint> frequencyHistory;
  final List<DataPoint> amplitudeHistory;
  final List<DataPoint> stabilityHistory;
  final DashboardTheme theme;
  final double animationProgress;
  
  RealtimeChartPainter({
    required this.frequencyHistory,
    required this.amplitudeHistory,
    required this.stabilityHistory,
    required this.theme,
    required this.animationProgress,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (frequencyHistory.isEmpty) return;
    
    // 주파수 차트 그리기
    _drawFrequencyChart(canvas, size);
    
    // 진폭 차트 그리기 (오버레이)
    _drawAmplitudeChart(canvas, size);
    
    // 안정성 차트 그리기 (배경)
    _drawStabilityChart(canvas, size);
    
    // 격자선 그리기
    _drawGrid(canvas, size);
  }
  
  void _drawFrequencyChart(Canvas canvas, Size size) {
    if (frequencyHistory.length < 2) return;
    
    final paint = Paint()
      ..color = _getPrimaryColor()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final glowPaint = Paint()
      ..color = _getPrimaryColor().withOpacity(0.5)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    
    final path = Path();
    final maxFreq = frequencyHistory.map((p) => p.value).reduce(math.max);
    final minFreq = frequencyHistory.map((p) => p.value).reduce(math.min);
    final freqRange = maxFreq - minFreq;
    
    if (freqRange == 0) return;
    
    for (int i = 0; i < frequencyHistory.length; i++) {
      final x = (i / (frequencyHistory.length - 1)) * size.width;
      final normalizedY = (frequencyHistory[i].value - minFreq) / freqRange;
      final y = size.height - (normalizedY * size.height * 0.8) - size.height * 0.1;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    // 애니메이션 적용된 경로 그리기
    final animatedPath = _createAnimatedPath(path, animationProgress);
    canvas.drawPath(animatedPath, glowPaint);
    canvas.drawPath(animatedPath, paint);
  }
  
  void _drawAmplitudeChart(Canvas canvas, Size size) {
    if (amplitudeHistory.length < 2) return;
    
    final paint = Paint()
      ..color = _getAccentColor().withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    
    for (int i = 0; i < amplitudeHistory.length; i++) {
      final x = (i / (amplitudeHistory.length - 1)) * size.width;
      final y = size.height - (amplitudeHistory[i].value * size.height * 0.3);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
  }
  
  void _drawStabilityChart(Canvas canvas, Size size) {
    if (stabilityHistory.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(0, size.height);
    
    for (int i = 0; i < stabilityHistory.length; i++) {
      final x = (i / (stabilityHistory.length - 1)) * size.width;
      final y = size.height - (stabilityHistory[i].value * size.height * 0.2);
      
      if (i == 0) {
        path.lineTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5;
    
    // 수평선
    for (int i = 1; i < 4; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
    
    // 수직선
    for (int i = 1; i < 4; i++) {
      final x = (size.width / 4) * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }
  }
  
  Path _createAnimatedPath(Path originalPath, double progress) {
    final pathMetrics = originalPath.computeMetrics();
    final animatedPath = Path();
    
    for (final pathMetric in pathMetrics) {
      final length = pathMetric.length * progress;
      final extractedPath = pathMetric.extractPath(0.0, length);
      animatedPath.addPath(extractedPath, Offset.zero);
    }
    
    return animatedPath;
  }
  
  Color _getPrimaryColor() {
    switch (theme) {
      case DashboardTheme.professional:
        return const Color(0xFF00ff88);
      case DashboardTheme.cyberpunk:
        return const Color(0xFFff00ff);
      case DashboardTheme.medical:
        return const Color(0xFF00ffff);
      case DashboardTheme.warm:
        return const Color(0xFFff8800);
    }
  }
  
  Color _getAccentColor() {
    switch (theme) {
      case DashboardTheme.professional:
        return const Color(0xFFffaa00);
      case DashboardTheme.cyberpunk:
        return const Color(0xFF00ffff);
      case DashboardTheme.medical:
        return const Color(0xFFffff00);
      case DashboardTheme.warm:
        return const Color(0xFF00ff88);
    }
  }
  
  @override
  bool shouldRepaint(RealtimeChartPainter oldDelegate) {
    return oldDelegate.frequencyHistory.length != frequencyHistory.length ||
           oldDelegate.animationProgress != animationProgress;
  }
}

/// 배경 패턴 페인터
class BackgroundPatternPainter extends CustomPainter {
  final DashboardTheme theme;
  final double animation;
  
  BackgroundPatternPainter({
    required this.theme,
    required this.animation,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _getPatternColor().withOpacity(0.05)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    // 원형 패턴
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = math.min(size.width, size.height) / 2;
    
    for (int i = 1; i <= 5; i++) {
      final radius = (maxRadius / 5) * i * (0.5 + animation * 0.5);
      canvas.drawCircle(Offset(centerX, centerY), radius, paint);
    }
    
    // 격자 패턴
    final gridSpacing = 50.0;
    for (double x = 0; x <= size.width; x += gridSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    for (double y = 0; y <= size.height; y += gridSpacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }
  
  Color _getPatternColor() {
    switch (theme) {
      case DashboardTheme.professional:
        return const Color(0xFF00ff88);
      case DashboardTheme.cyberpunk:
        return const Color(0xFFff00ff);
      case DashboardTheme.medical:
        return const Color(0xFF00ffff);
      case DashboardTheme.warm:
        return const Color(0xFFff8800);
    }
  }
  
  @override
  bool shouldRepaint(BackgroundPatternPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

/// 대시보드 테마
enum DashboardTheme {
  professional,  // 전문가용 그린
  cyberpunk,     // 사이버펑크 핑크
  medical,       // 의료용 시안
  warm,          // 따뜻한 오렌지
}

/// 데이터 포인트 클래스
class DataPoint {
  final double time;
  final double value;
  
  DataPoint(this.time, this.value);
}