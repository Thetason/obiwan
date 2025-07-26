import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../domain/entities/vocal_analysis.dart';
import '../../core/theme/enhanced_app_theme.dart';

/// 향상된 오디오 시각화 위젯
/// 실시간 음성 데이터를 아름다운 시각적 효과로 표현
class EnhancedAudioVisualizationWidget extends ConsumerStatefulWidget {
  const EnhancedAudioVisualizationWidget({super.key});

  @override
  ConsumerState<EnhancedAudioVisualizationWidget> createState() => _EnhancedAudioVisualizationWidgetState();
}

class _EnhancedAudioVisualizationWidgetState extends ConsumerState<EnhancedAudioVisualizationWidget>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  
  late Animation<double> _waveAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _particleAnimation;
  
  // 시뮬레이션 데이터
  List<double> _waveformData = [];
  double _currentPitch = 440.0;
  double _pitchStability = 0.8;
  double _amplitude = 0.5;
  bool _isVocalizing = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateSampleData();
  }

  void _initializeAnimations() {
    // 파형 애니메이션
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    )..repeat();
    
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_waveController);
    
    // 펄스 애니메이션
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // 파티클 애니메이션
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
    
    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_particleController);
  }

  void _generateSampleData() {
    // 실제 구현에서는 실시간 오디오 데이터를 사용
    _waveformData = List.generate(64, (index) {
      return (math.sin(index * 0.1 + DateTime.now().millisecondsSinceEpoch * 0.01) * 0.5 + 0.5) * _amplitude;
    });
    
    // 주기적으로 데이터 업데이트
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _generateSampleData();
          _isVocalizing = _amplitude > 0.1;
        });
      }
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            EnhancedAppTheme.primaryDark.withOpacity(0.8),
            EnhancedAppTheme.secondaryDark,
            Colors.black.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isVocalizing 
              ? EnhancedAppTheme.neonGreen.withOpacity(0.5)
              : EnhancedAppTheme.accentBlue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // 배경 파티클 효과
            _buildParticleBackground(),
            
            // 메인 시각화 영역
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  Expanded(child: _buildMainVisualization()),
                  const SizedBox(height: 20),
                  _buildMetricsPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticleBackground() {
    return AnimatedBuilder(
      animation: _particleAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticleBackgroundPainter(
            animationValue: _particleAnimation.value,
            isActive: _isVocalizing,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.graphic_eq,
          color: EnhancedAppTheme.neonBlue,
          size: 24,
        ),
        const SizedBox(width: 12),
        Text(
          '실시간 음성 분석',
          style: EnhancedAppTheme.headingMedium.copyWith(
            fontSize: 18,
            color: EnhancedAppTheme.highlight,
          ),
        ),
        const Spacer(),
        _buildStatusIndicator(),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: _isVocalizing 
            ? EnhancedAppTheme.successGradient 
            : LinearGradient(colors: [
                EnhancedAppTheme.accentLight.withOpacity(0.3),
                EnhancedAppTheme.accentLight.withOpacity(0.1),
              ]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isVocalizing ? Colors.white : EnhancedAppTheme.accentLight,
                  shape: BoxShape.circle,
                  boxShadow: _isVocalizing ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(_pulseAnimation.value),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ] : [],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            _isVocalizing ? '음성 감지' : '대기 중',
            style: TextStyle(
              color: _isVocalizing ? Colors.white : EnhancedAppTheme.accentLight,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainVisualization() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EnhancedAppTheme.accentBlue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // 중앙 원형 시각화
            _buildCentralVisualization(),
            
            // 주변 파형 시각화
            _buildSurroundingWaveform(),
            
            // 피치 인디케이터
            _buildPitchIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildCentralVisualization() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Center(
          child: Container(
            width: 200 * _pulseAnimation.value,
            height: 200 * _pulseAnimation.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _isVocalizing 
                      ? EnhancedAppTheme.neonGreen.withOpacity(0.6)
                      : EnhancedAppTheme.neonBlue.withOpacity(0.4),
                  _isVocalizing 
                      ? EnhancedAppTheme.neonBlue.withOpacity(0.3)
                      : EnhancedAppTheme.accentBlue.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
              boxShadow: _isVocalizing ? [
                BoxShadow(
                  color: EnhancedAppTheme.neonGreen.withOpacity(0.4),
                  blurRadius: 40 * _pulseAnimation.value,
                  spreadRadius: 10,
                ),
              ] : [],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_currentPitch.toStringAsFixed(1)} Hz',
                    style: EnhancedAppTheme.headingMedium.copyWith(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getPitchNote(_currentPitch),
                    style: EnhancedAppTheme.bodyLarge.copyWith(
                      color: EnhancedAppTheme.accentLight,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStabilityIndicator(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStabilityIndicator() {
    return Container(
      width: 100,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _pitchStability,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                EnhancedAppTheme.neonGreen,
                EnhancedAppTheme.neonBlue,
              ],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildSurroundingWaveform() {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: WaveformPainter(
            waveformData: _waveformData,
            animationValue: _waveAnimation.value,
            isVocalizing: _isVocalizing,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildPitchIndicator() {
    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.6),
              Colors.black.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.music_note,
              color: EnhancedAppTheme.neonBlue,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              '안정성',
              style: EnhancedAppTheme.caption.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            Text(
              '${(_pitchStability * 100).toInt()}%',
              style: EnhancedAppTheme.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildMetricItem(
            icon: Icons.volume_up,
            label: '음량',
            value: '${(_amplitude * 100).toInt()}%',
            color: EnhancedAppTheme.neonOrange,
          ),
          const SizedBox(width: 20),
          _buildMetricItem(
            icon: Icons.track_changes,
            label: '정확도',
            value: '${(_pitchStability * 100).toInt()}%',
            color: EnhancedAppTheme.neonGreen,
          ),
          const SizedBox(width: 20),
          _buildMetricItem(
            icon: Icons.timer,
            label: '지속시간',
            value: '2.3s',
            color: EnhancedAppTheme.neonBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: EnhancedAppTheme.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: EnhancedAppTheme.caption.copyWith(
              color: EnhancedAppTheme.accentLight,
            ),
          ),
        ],
      ),
    );
  }

  String _getPitchNote(double frequency) {
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const a4 = 440.0;
    
    if (frequency <= 0) return '--';
    
    final semitones = 12 * (math.log(frequency / a4) / math.ln2);
    final noteIndex = (semitones.round() + 9) % 12;
    final octave = 4 + ((semitones.round() + 9) ~/ 12);
    
    return '${notes[noteIndex]}$octave';
  }
}

/// 파형 시각화 페인터
class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double animationValue;
  final bool isVocalizing;

  WaveformPainter({
    required this.waveformData,
    required this.animationValue,
    required this.isVocalizing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.4;

    for (int i = 0; i < waveformData.length; i++) {
      final angle = (i / waveformData.length) * 2 * math.pi;
      final amplitude = waveformData[i] * 50 * (isVocalizing ? 1.5 : 0.5);
      
      final innerRadius = radius - amplitude;
      final outerRadius = radius + amplitude;
      
      final innerPoint = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );
      
      final outerPoint = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );

      // 색상 계산
      final progress = (i + animationValue * 10) % waveformData.length / waveformData.length;
      paint.color = Color.lerp(
        isVocalizing ? EnhancedAppTheme.neonGreen : EnhancedAppTheme.neonBlue,
        isVocalizing ? EnhancedAppTheme.neonBlue : EnhancedAppTheme.accentBlue,
        progress,
      )!.withOpacity(0.8);

      canvas.drawLine(innerPoint, outerPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 파티클 배경 페인터
class ParticleBackgroundPainter extends CustomPainter {
  final double animationValue;
  final bool isActive;

  ParticleBackgroundPainter({
    required this.animationValue,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    const particleCount = 20;
    
    for (int i = 0; i < particleCount; i++) {
      final x = (size.width * (i / particleCount + animationValue * 0.1)) % size.width;
      final y = size.height * (0.3 + 0.4 * math.sin(i + animationValue * 2));
      final opacity = (math.sin(i + animationValue * 3) + 1) / 2;
      
      paint.color = EnhancedAppTheme.neonGreen.withOpacity(opacity * 0.3);
      
      canvas.drawCircle(
        Offset(x, y),
        2 + opacity * 3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}