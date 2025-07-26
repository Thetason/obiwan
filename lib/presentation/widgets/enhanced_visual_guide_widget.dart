import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../domain/entities/vocal_analysis.dart';
import '../../core/theme/enhanced_app_theme.dart';

/// 향상된 시각 가이드 위젯
/// 2D 해부학적 시각화와 실시간 피드백을 제공
class EnhancedVisualGuideWidget extends ConsumerStatefulWidget {
  final dynamic visualGuideState;
  final bool isRecording;

  const EnhancedVisualGuideWidget({
    super.key,
    required this.visualGuideState,
    required this.isRecording,
  });

  @override
  ConsumerState<EnhancedVisualGuideWidget> createState() => _EnhancedVisualGuideWidgetState();
}

class _EnhancedVisualGuideWidgetState extends ConsumerState<EnhancedVisualGuideWidget>
    with TickerProviderStateMixin, CustomWidgetStyles {
  late AnimationController _breathingController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  
  late Animation<double> _breathingAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  
  String _currentInstruction = '편안한 자세로 준비하세요';
  String _currentFocus = 'breathing';
  double _breathingIntensity = 0.0;
  bool _showDetailedView = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _updateInstructions();
  }

  void _initializeAnimations() {
    // 호흡 애니메이션
    _breathingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    
    _breathingAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
    
    // 펄스 애니메이션
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // 글로우 애니메이션
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_glowController);
  }

  void _updateInstructions() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          switch (_currentFocus) {
            case 'breathing':
              _currentInstruction = '깊게 숨을 들이마시고 천천히 내쉬세요';
              _currentFocus = 'posture';
              break;
            case 'posture':
              _currentInstruction = '어깨를 편안히 내리고 목을 곧게 세우세요';
              _currentFocus = 'vocal_cords';
              break;
            case 'vocal_cords':
              _currentInstruction = '성대를 부드럽게 진동시켜 보세요';
              _currentFocus = 'breathing';
              break;
          }
        });
        _updateInstructions();
      }
    });
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            EnhancedAppTheme.secondaryDark,
            EnhancedAppTheme.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: EnhancedAppTheme.accentBlue.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(child: _buildMainVisualization()),
              const SizedBox(height: 16),
              _buildInstructionPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.visibility,
          color: EnhancedAppTheme.neonBlue,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          '시각 가이드',
          style: EnhancedAppTheme.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: EnhancedAppTheme.highlight,
          ),
        ),
        const Spacer(),
        _buildViewToggle(),
      ],
    );
  }

  Widget _buildViewToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showDetailedView = !_showDetailedView;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: _showDetailedView 
              ? EnhancedAppTheme.primaryGradient 
              : null,
          color: !_showDetailedView 
              ? Colors.white.withOpacity(0.1) 
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: EnhancedAppTheme.accentLight.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showDetailedView ? Icons.zoom_out : Icons.zoom_in,
              color: _showDetailedView ? Colors.white : EnhancedAppTheme.accentLight,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              _showDetailedView ? '기본' : '상세',
              style: TextStyle(
                color: _showDetailedView ? Colors.white : EnhancedAppTheme.accentLight,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainVisualization() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            Colors.black.withOpacity(0.1),
            Colors.black.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // 메인 해부학적 시각화
            _buildAnatomicalVisualization(),
            
            // 인터랙티브 요소들
            _buildInteractiveElements(),
            
            // 실시간 피드백 오버레이
            if (widget.isRecording) _buildRealtimeFeedback(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnatomicalVisualization() {
    return AnimatedBuilder(
      animation: Listenable.merge([_breathingAnimation, _glowAnimation]),
      builder: (context, child) {
        return CustomPaint(
          painter: AnatomicalVisualizationPainter(
            breathingValue: _breathingAnimation.value,
            glowValue: _glowAnimation.value,
            currentFocus: _currentFocus,
            isRecording: widget.isRecording,
            isDetailedView: _showDetailedView,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildInteractiveElements() {
    return Stack(
      children: [
        // 호흡 영역 터치 포인트
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: _buildBreathingIndicator(),
        ),
        
        // 성대 영역 터치 포인트
        Positioned(
          top: 80,
          left: 0,
          right: 0,
          child: _buildVocalCordsIndicator(),
        ),
        
        // 공명 영역들
        if (_showDetailedView) ...[
          _buildResonancePoint('비강', 0.3, 0.2, ResonanceType.nasal),
          _buildResonancePoint('구강', 0.5, 0.35, ResonanceType.oral),
          _buildResonancePoint('흉강', 0.7, 0.8, ResonanceType.chest),
        ],
      ],
    );
  }

  Widget _buildBreathingIndicator() {
    return AnimatedBuilder(
      animation: _breathingAnimation,
      builder: (context, child) {
        return Center(
          child: GestureDetector(
            onTap: () => _focusOnBreathing(),
            child: Container(
              width: 60 * _breathingAnimation.value,
              height: 40 * _breathingAnimation.value,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    EnhancedAppTheme.neonGreen.withOpacity(0.6),
                    EnhancedAppTheme.neonGreen.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: EnhancedAppTheme.neonGreen.withOpacity(0.8),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.air,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVocalCordsIndicator() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Center(
          child: GestureDetector(
            onTap: () => _focusOnVocalCords(),
            child: Container(
              width: 40,
              height: 20 + (10 * _pulseAnimation.value),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    EnhancedAppTheme.neonBlue.withOpacity(0.8),
                    EnhancedAppTheme.neonPink.withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: EnhancedAppTheme.neonBlue,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: EnhancedAppTheme.neonBlue.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 2,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResonancePoint(String label, double topFactor, double leftFactor, ResonanceType type) {
    return Positioned(
      top: MediaQuery.of(context).size.height * topFactor,
      left: MediaQuery.of(context).size.width * leftFactor,
      child: GestureDetector(
        onTap: () => _focusOnResonance(type),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: 30 + (5 * _pulseAnimation.value),
              height: 30 + (5 * _pulseAnimation.value),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    _getResonanceColor(type).withOpacity(0.7),
                    _getResonanceColor(type).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getResonanceColor(type),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRealtimeFeedback() {
    return Positioned(
      top: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.black.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: EnhancedAppTheme.neonGreen.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: EnhancedAppTheme.neonGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'LIVE',
                  style: EnhancedAppTheme.caption.copyWith(
                    color: EnhancedAppTheme.neonGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '호흡: 좋음',
              style: EnhancedAppTheme.caption.copyWith(
                color: Colors.white,
              ),
            ),
            Text(
              '자세: 개선 필요',
              style: EnhancedAppTheme.caption.copyWith(
                color: EnhancedAppTheme.neonOrange,
              ),
            ),
            Text(
              '음정: 안정적',
              style: EnhancedAppTheme.caption.copyWith(
                color: EnhancedAppTheme.neonGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            EnhancedAppTheme.neonBlue.withOpacity(0.1),
            EnhancedAppTheme.neonBlue.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: EnhancedAppTheme.neonBlue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (0.1 * _pulseAnimation.value),
                child: Icon(
                  Icons.lightbulb_outline,
                  color: EnhancedAppTheme.neonBlue,
                  size: 20,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _currentInstruction,
              style: EnhancedAppTheme.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 인터랙션 메서드들
  void _focusOnBreathing() {
    setState(() {
      _currentFocus = 'breathing';
      _currentInstruction = '복식호흡에 집중하세요. 배가 움직이는 것을 느껴보세요.';
    });
  }

  void _focusOnVocalCords() {
    setState(() {
      _currentFocus = 'vocal_cords';
      _currentInstruction = '성대를 부드럽게 진동시키며 편안하게 발성하세요.';
    });
  }

  void _focusOnResonance(ResonanceType type) {
    setState(() {
      _currentFocus = 'resonance';
      switch (type) {
        case ResonanceType.nasal:
          _currentInstruction = '비강 공명을 느껴보세요. "망" 소리로 연습해보세요.';
          break;
        case ResonanceType.oral:
          _currentInstruction = '구강 공명에 집중하세요. 입 모양을 조절해보세요.';
          break;
        case ResonanceType.chest:
          _currentInstruction = '흉성 공명을 느껴보세요. 가슴에 울림을 만들어보세요.';
          break;
      }
    });
  }

  Color _getResonanceColor(ResonanceType type) {
    switch (type) {
      case ResonanceType.nasal:
        return EnhancedAppTheme.neonPink;
      case ResonanceType.oral:
        return EnhancedAppTheme.neonOrange;
      case ResonanceType.chest:
        return EnhancedAppTheme.neonBlue;
    }
  }
}

enum ResonanceType { nasal, oral, chest }

/// 해부학적 시각화 페인터
class AnatomicalVisualizationPainter extends CustomPainter {
  final double breathingValue;
  final double glowValue;
  final String currentFocus;
  final bool isRecording;
  final bool isDetailedView;

  AnatomicalVisualizationPainter({
    required this.breathingValue,
    required this.glowValue,
    required this.currentFocus,
    required this.isRecording,
    required this.isDetailedView,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    // 기본 인체 실루엣
    _drawBodyOutline(canvas, size, paint);
    
    // 호흡 시스템
    _drawBreathingSystem(canvas, size, paint);
    
    // 성대
    _drawVocalCords(canvas, size, paint);
    
    if (isDetailedView) {
      // 상세 해부학적 구조
      _drawDetailedAnatomy(canvas, size, paint);
    }
    
    // 포커스 하이라이트
    _drawFocusHighlight(canvas, size, paint);
  }

  void _drawBodyOutline(Canvas canvas, Size size, Paint paint) {
    paint.color = EnhancedAppTheme.accentLight.withOpacity(0.3);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;

    final bodyPath = Path();
    
    // 머리
    final headCenter = Offset(size.width * 0.5, size.height * 0.15);
    canvas.drawCircle(headCenter, 30, paint);
    
    // 목
    bodyPath.moveTo(size.width * 0.5, size.height * 0.24);
    bodyPath.lineTo(size.width * 0.5, size.height * 0.35);
    
    // 어깨와 몸통
    bodyPath.moveTo(size.width * 0.3, size.height * 0.35);
    bodyPath.lineTo(size.width * 0.7, size.height * 0.35);
    bodyPath.lineTo(size.width * 0.65, size.height * 0.85);
    bodyPath.lineTo(size.width * 0.35, size.height * 0.85);
    bodyPath.close();
    
    canvas.drawPath(bodyPath, paint);
  }

  void _drawBreathingSystem(Canvas canvas, Size size, Paint paint) {
    // 폐
    paint.color = EnhancedAppTheme.neonGreen.withOpacity(0.3 + (breathingValue - 0.8) * 0.5);
    paint.style = PaintingStyle.fill;
    
    final leftLung = Rect.fromCenter(
      center: Offset(size.width * 0.4, size.height * 0.55),
      width: 40 * breathingValue,
      height: 80 * breathingValue,
    );
    
    final rightLung = Rect.fromCenter(
      center: Offset(size.width * 0.6, size.height * 0.55),
      width: 40 * breathingValue,
      height: 80 * breathingValue,
    );
    
    canvas.drawOval(leftLung, paint);
    canvas.drawOval(rightLung, paint);
    
    // 횡격막
    paint.color = EnhancedAppTheme.neonBlue.withOpacity(0.4);
    final diaphragm = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.7 + (breathingValue - 1.0) * 10),
      width: size.width * 0.4,
      height: 8,
    );
    canvas.drawOval(diaphragm, paint);
  }

  void _drawVocalCords(Canvas canvas, Size size, Paint paint) {
    paint.color = EnhancedAppTheme.neonPink.withOpacity(0.6);
    paint.style = PaintingStyle.fill;
    
    final vocalCordsRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.32),
      width: 30,
      height: 8 + glowValue * 4,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(vocalCordsRect, const Radius.circular(4)),
      paint,
    );
    
    // 성대 진동 표시
    if (isRecording) {
      paint.color = EnhancedAppTheme.neonPink.withOpacity(glowValue * 0.8);
      for (int i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.32),
          10 + i * 5 + glowValue * 10,
          paint,
        );
      }
    }
  }

  void _drawDetailedAnatomy(Canvas canvas, Size size, Paint paint) {
    // 비강
    paint.color = EnhancedAppTheme.neonOrange.withOpacity(0.4);
    final nasalCavity = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.2),
      width: 20,
      height: 15,
    );
    canvas.drawOval(nasalCavity, paint);
    
    // 혀
    paint.color = EnhancedAppTheme.neonRed.withOpacity(0.5);
    final tongue = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.28),
      width: 25,
      height: 12,
    );
    canvas.drawOval(tongue, paint);
    
    // 기관
    paint.color = EnhancedAppTheme.accentLight.withOpacity(0.4);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.35),
      Offset(size.width * 0.5, size.height * 0.45),
      paint,
    );
  }

  void _drawFocusHighlight(Canvas canvas, Size size, Paint paint) {
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    
    switch (currentFocus) {
      case 'breathing':
        paint.color = EnhancedAppTheme.neonGreen.withOpacity(glowValue);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.6),
          60 + glowValue * 20,
          paint,
        );
        break;
      case 'vocal_cords':
        paint.color = EnhancedAppTheme.neonPink.withOpacity(glowValue);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.32),
          25 + glowValue * 10,
          paint,
        );
        break;
      case 'posture':
        paint.color = EnhancedAppTheme.neonBlue.withOpacity(glowValue);
        canvas.drawCircle(
          Offset(size.width * 0.5, size.height * 0.4),
          80 + glowValue * 30,
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}