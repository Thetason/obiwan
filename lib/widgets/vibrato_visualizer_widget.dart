import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../services/vibrato_analyzer.dart';

/// 🎵 비브라토 시각화 위젯
/// 
/// 비브라토 분석 결과를 실시간으로 시각화합니다.
/// - 비브라토 파형 그래프
/// - 속도, 깊이, 규칙성 게이지
/// - 품질 등급 표시
/// - 실시간 피드백
class VibratoVisualizerWidget extends StatefulWidget {
  final VibratoAnalysisResult? vibratoResult;
  final double width;
  final double height;
  final bool showDetails;
  final Color primaryColor;
  final Color backgroundColor;
  
  const VibratoVisualizerWidget({
    Key? key,
    this.vibratoResult,
    this.width = 300,
    this.height = 200,
    this.showDetails = true,
    this.primaryColor = const Color(0xFF6366F1),
    this.backgroundColor = const Color(0xFF1F2937),
  }) : super(key: key);

  @override
  State<VibratoVisualizerWidget> createState() => _VibratoVisualizerWidgetState();
}

class _VibratoVisualizerWidgetState extends State<VibratoVisualizerWidget>
    with TickerProviderStateMixin {
  
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late Animation<double> _waveAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // 파형 애니메이션 (비브라토 속도에 따라 조절)
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.linear),
    );
    
    // 펄스 애니메이션 (비브라토 감지 시 활성화)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startAnimations();
  }

  void _startAnimations() {
    _waveController.repeat();
    _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(VibratoVisualizerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 비브라토 결과가 변경되면 애니메이션 속도 조절
    if (widget.vibratoResult != oldWidget.vibratoResult) {
      _updateAnimationSpeed();
    }
  }

  void _updateAnimationSpeed() {
    final result = widget.vibratoResult;
    if (result != null && result.isPresent && result.rate > 0) {
      // 비브라토 속도에 따라 애니메이션 속도 조절
      final animationSpeed = (1000 / result.rate).clamp(500, 3000);
      _waveController.duration = Duration(milliseconds: animationSpeed.round());
      _waveController.repeat();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            Expanded(
              child: _buildVisualization(),
            ),
            if (widget.showDetails) ...[
              const SizedBox(height: 12),
              _buildDetails(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final result = widget.vibratoResult;
    final isActive = result?.isPresent ?? false;
    
    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isActive ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive 
                      ? _getQualityColor(result?.quality ?? VibratoQuality.none)
                      : Colors.grey,
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: _getQualityColor(result?.quality ?? VibratoQuality.none)
                          .withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ] : null,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        Text(
          '비브라토 분석',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (result?.isPresent == true)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getQualityColor(result!.quality).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getQualityColor(result.quality).withOpacity(0.4),
              ),
            ),
            child: Text(
              result.quality.description,
              style: TextStyle(
                color: _getQualityColor(result.quality),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVisualization() {
    final result = widget.vibratoResult;
    
    if (result == null || !result.isPresent) {
      return _buildNoVibratoView();
    }
    
    return CustomPaint(
      size: Size.infinite,
      painter: VibratoWaveformPainter(
        vibratoResult: result,
        animation: _waveAnimation,
        primaryColor: widget.primaryColor,
      ),
    );
  }

  Widget _buildNoVibratoView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_outlined,
            size: 48,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            '비브라토 감지 대기 중...',
            style: TextStyle(
              color: Colors.grey.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    final result = widget.vibratoResult;
    
    if (result == null || !result.isPresent) {
      return const SizedBox.shrink();
    }
    
    return Column(
      children: [
        _buildMetricRow('속도', '${result.rate.toStringAsFixed(1)} Hz', result.rate / 8.0),
        const SizedBox(height: 6),
        _buildMetricRow('깊이', '${result.depth.toStringAsFixed(0)} cents', result.depth / 100.0),
        const SizedBox(height: 6),
        _buildMetricRow('규칙성', '${(result.regularity * 100).toStringAsFixed(0)}%', result.regularity),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value, double normalizedValue) {
    final progress = normalizedValue.clamp(0.0, 1.0);
    
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.primaryColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Color _getQualityColor(VibratoQuality quality) {
    switch (quality) {
      case VibratoQuality.excellent:
        return const Color(0xFF10B981);
      case VibratoQuality.good:
        return const Color(0xFF3B82F6);
      case VibratoQuality.fair:
        return const Color(0xFFF59E0B);
      case VibratoQuality.poor:
        return const Color(0xFFEF4444);
      case VibratoQuality.none:
        return Colors.grey;
    }
  }
}

/// 🌊 비브라토 파형 페인터
class VibratoWaveformPainter extends CustomPainter {
  final VibratoAnalysisResult vibratoResult;
  final Animation<double> animation;
  final Color primaryColor;

  VibratoWaveformPainter({
    required this.vibratoResult,
    required this.animation,
    required this.primaryColor,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (!vibratoResult.isPresent) return;

    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final shadowPaint = Paint()
      ..color = primaryColor.withOpacity(0.3)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withOpacity(0.3),
          primaryColor.withOpacity(0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final centerY = size.height / 2;
    final amplitude = vibratoResult.intensity * (size.height * 0.3);
    final frequency = vibratoResult.rate;
    final phase = animation.value;

    // 배경 파형 (그림자 효과)
    _drawWaveform(canvas, size, shadowPaint, centerY, amplitude * 0.8, frequency, phase);
    
    // 메인 파형
    _drawWaveform(canvas, size, paint, centerY, amplitude, frequency, phase);
    
    // 채우기 영역
    _drawWaveformFill(canvas, size, fillPaint, centerY, amplitude, frequency, phase);

    // 중심선
    final centerLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      centerLinePaint,
    );
  }

  void _drawWaveform(Canvas canvas, Size size, Paint paint, double centerY, 
                    double amplitude, double frequency, double phase) {
    final path = Path();
    final points = <Offset>[];
    
    const resolution = 100;
    for (int i = 0; i <= resolution; i++) {
      final x = (i / resolution) * size.width;
      final normalizedX = x / size.width;
      
      // 비브라토 파형 생성 (사인파 기반)
      final waveValue = math.sin((normalizedX * frequency * 2 * math.pi) + phase);
      final y = centerY + (waveValue * amplitude);
      
      points.add(Offset(x, y));
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
  }

  void _drawWaveformFill(Canvas canvas, Size size, Paint paint, double centerY, 
                        double amplitude, double frequency, double phase) {
    final path = Path();
    
    path.moveTo(0, centerY);
    
    const resolution = 100;
    for (int i = 0; i <= resolution; i++) {
      final x = (i / resolution) * size.width;
      final normalizedX = x / size.width;
      
      final waveValue = math.sin((normalizedX * frequency * 2 * math.pi) + phase);
      final y = centerY + (waveValue * amplitude);
      
      path.lineTo(x, y);
    }
    
    path.lineTo(size.width, centerY);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(VibratoWaveformPainter oldDelegate) {
    return oldDelegate.vibratoResult != vibratoResult ||
           oldDelegate.animation.value != animation.value;
  }
}

/// 🎯 컴팩트 비브라토 인디케이터
class CompactVibratoIndicator extends StatelessWidget {
  final VibratoAnalysisResult? vibratoResult;
  final double size;
  
  const CompactVibratoIndicator({
    Key? key,
    this.vibratoResult,
    this.size = 32,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final result = vibratoResult;
    final isActive = result?.isPresent ?? false;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive 
            ? _getQualityColor(result!.quality).withOpacity(0.2)
            : Colors.grey.withOpacity(0.1),
        border: Border.all(
          color: isActive 
              ? _getQualityColor(result!.quality)
              : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Icon(
        isActive ? Icons.graphic_eq : Icons.graphic_eq_outlined,
        color: isActive 
            ? _getQualityColor(result!.quality)
            : Colors.grey.withOpacity(0.5),
        size: size * 0.6,
      ),
    );
  }

  Color _getQualityColor(VibratoQuality quality) {
    switch (quality) {
      case VibratoQuality.excellent:
        return const Color(0xFF10B981);
      case VibratoQuality.good:
        return const Color(0xFF3B82F6);
      case VibratoQuality.fair:
        return const Color(0xFFF59E0B);
      case VibratoQuality.poor:
        return const Color(0xFFEF4444);
      case VibratoQuality.none:
        return Colors.grey;
    }
  }
}