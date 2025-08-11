import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

enum TouchState {
  idle,      // 대기 상태
  pressed,   // 터치 중
  recording, // 녹음 중
  analyzing, // 분석 중
}

class WaveVisualizerWidget extends StatefulWidget {
  final bool isRecording;
  final double audioLevel;
  final VoidCallback? onTouchStart;
  final VoidCallback? onTouchEnd;
  final TouchState touchState;

  const WaveVisualizerWidget({
    Key? key,
    required this.isRecording,
    required this.audioLevel,
    this.onTouchStart,
    this.onTouchEnd,
    this.touchState = TouchState.idle,
  }) : super(key: key);

  @override
  State<WaveVisualizerWidget> createState() => _WaveVisualizerWidgetState();
}

class _WaveVisualizerWidgetState extends State<WaveVisualizerWidget>
    with TickerProviderStateMixin {
  
  // 애니메이션 컨트롤러들
  late List<AnimationController> _waveControllers;
  late AnimationController _pulseController;
  late AnimationController _touchController;
  late AnimationController _analysisController;
  late AnimationController _audioLevelController;
  
  // 애니메이션들
  late List<Animation<double>> _waveAnimations;
  late Animation<double> _pulseAnimation;
  late Animation<double> _touchAnimation;
  late Animation<double> _analysisAnimation;
  late Animation<double> _audioLevelAnimation;
  
  // 오디오 레벨 관련
  double _currentAudioLevel = 0.0;
  double _targetAudioLevel = 0.0;
  
  // 상태 관리
  TouchState _currentState = TouchState.idle;
  bool _isPressed = false;
  
  // 색상 테마
  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _accentColor = const Color(0xFF10B981);
  final Color _warningColor = const Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startIdleAnimation();
  }

  void _initializeAnimations() {
    // 6개 동심원용 웨이브 컨트롤러 - 더 부드러운 애니메이션을 위해 지속시간 조정
    _waveControllers = List.generate(6, (index) =>
        AnimationController(
          duration: Duration(milliseconds: 1500 + (index * 150)),
          vsync: this,
        )
    );

    // 웨이브 애니메이션들 - 더 부드러운 곡선 적용
    _waveAnimations = _waveControllers.map((controller) =>
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic),
        )
    ).toList();

    // 펄스 애니메이션 (기본 대기 상태)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    // 터치 반응 애니메이션
    _touchController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _touchAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _touchController, curve: Curves.elasticOut),
    );

    // 분석 중 회전 애니메이션
    _analysisController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _analysisAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _analysisController, curve: Curves.linear),
    );

    // 오디오 레벨 애니메이션 - 부드러운 실시간 반응
    _audioLevelController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _audioLevelAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _audioLevelController, curve: Curves.easeOutCubic),
    );

    // 오디오 레벨 변화 리스너
    _audioLevelAnimation.addListener(() {
      _currentAudioLevel = math.max(0.0, math.min(1.0, 
        _currentAudioLevel + (_targetAudioLevel - _currentAudioLevel) * _audioLevelAnimation.value));
    });
  }

  void _startIdleAnimation() {
    _pulseController.repeat(reverse: true);
  }

  void _handleTouchStart() {
    setState(() {
      _isPressed = true;
      _currentState = TouchState.pressed;
    });
    
    // 햅틱 피드백
    HapticFeedback.lightImpact();
    
    // 터치 확장 애니메이션
    _touchController.forward();
    
    // 웨이브 애니메이션 시작
    for (int i = 0; i < _waveControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted && _isPressed) {
          _waveControllers[i].repeat();
        }
      });
    }
    
    widget.onTouchStart?.call();
  }

  void _handleTouchEnd() {
    setState(() {
      _isPressed = false;
      _currentState = TouchState.analyzing;
    });
    
    // 햅틱 피드백
    HapticFeedback.mediumImpact();
    
    // 터치 애니메이션 되돌리기
    _touchController.reverse();
    
    // 웨이브 애니메이션 정지
    for (var controller in _waveControllers) {
      controller.stop();
      controller.reset();
    }
    
    // 분석 애니메이션 시작
    _analysisController.repeat();
    
    widget.onTouchEnd?.call();
    
    // 3초 후 대기 상태로 복귀 (임시)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _currentState = TouchState.idle;
        });
        _analysisController.stop();
        _analysisController.reset();
      }
    });
  }

  @override
  void didUpdateWidget(WaveVisualizerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 오디오 레벨이 변경되었을 때 부드러운 애니메이션 적용
    if (oldWidget.audioLevel != widget.audioLevel) {
      _targetAudioLevel = widget.audioLevel;
      _audioLevelController.reset();
      _audioLevelController.forward();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _touchController.dispose();
    _analysisController.dispose();
    _audioLevelController.dispose();
    for (var controller in _waveControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTapDown: (_) => _handleTouchStart(),
        onTapUp: (_) => _handleTouchEnd(),
        onTapCancel: () => _handleTouchEnd(),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _pulseController,
            _touchController,
            _analysisController,
            _audioLevelController,
            ..._waveControllers,
          ]),
          builder: (context, child) {
            return _buildWaveVisualizer();
          },
        ),
      ),
    );
  }

  Widget _buildWaveVisualizer() {
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 배경 그라데이션 효과
          _buildBackgroundGradient(),
          
          // 동심원 웨이브들
          ..._buildWaveCircles(),
          
          // 중앙 컨텐츠
          _buildCenterContent(),
        ],
      ),
    );
  }

  Widget _buildBackgroundGradient() {
    // 오디오 레벨에 따른 동적 배경 효과
    double audioIntensity = _currentAudioLevel * 0.15;
    Color dynamicColor = _getCircleColor();
    
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            dynamicColor.withOpacity(0.08 + audioIntensity),
            _primaryColor.withOpacity(0.04 + audioIntensity * 0.5),
            Colors.transparent,
          ],
          stops: const [0.15, 0.5, 1.0],
        ),
        // 오디오 레벨이 높을 때 미세한 글로우 효과
        boxShadow: _currentAudioLevel > 0.4 ? [
          BoxShadow(
            color: dynamicColor.withOpacity(0.1 * _currentAudioLevel),
            blurRadius: 20 + (_currentAudioLevel * 30),
            spreadRadius: 5 + (_currentAudioLevel * 10),
          ),
        ] : null,
      ),
    );
  }

  List<Widget> _buildWaveCircles() {
    return List.generate(6, (index) {
      double baseSize = 80 + (index * 30); // 사이즈 간격 늘림
      double animationValue = _waveAnimations[index].value;
      double pulseValue = _pulseAnimation.value;
      double touchScale = _touchAnimation.value;
      
      // 오디오 레벨에 따른 동적 크기 조절
      double audioLevelScale = 1.0 + (_currentAudioLevel * (0.4 - index * 0.05)); // 바깥 원일수록 더 크게 반응
      
      // 터치 상태에 따른 크기 조절
      double sizeMultiplier = 1.0;
      if (_currentState == TouchState.pressed || _currentState == TouchState.recording) {
        sizeMultiplier = touchScale * audioLevelScale;
      } else if (_currentState == TouchState.idle) {
        sizeMultiplier = (1.0 + (pulseValue * 0.08)) * (1.0 + _currentAudioLevel * 0.2);
      } else {
        sizeMultiplier = 1.0 + (_currentAudioLevel * 0.15);
      }
      
      // 오디오 레벨에 따른 애니메이션 강도 조절
      double waveIntensity = 15 + (_currentAudioLevel * 25); // 기본 15px에서 최대 40px까지
      
      double opacity = _getCircleOpacity(index);
      Color circleColor = _getCircleColor();
      double borderWidth = _getBorderWidth(index);
      
      return Positioned(
        left: 150 - (baseSize + (animationValue * waveIntensity) + (audioLevelScale - 1) * 30) / 2,
        top: 150 - (baseSize + (animationValue * waveIntensity) + (audioLevelScale - 1) * 30) / 2,
        child: Transform.scale(
          scale: sizeMultiplier,
          child: Container(
            width: baseSize + (animationValue * waveIntensity) + (audioLevelScale - 1) * 30,
            height: baseSize + (animationValue * waveIntensity) + (audioLevelScale - 1) * 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: circleColor.withOpacity(opacity * (0.8 + _currentAudioLevel * 0.5)),
                width: borderWidth,
              ),
              // 오디오 레벨에 따른 미세한 그라데이션 효과
              boxShadow: _currentAudioLevel > 0.3 ? [
                BoxShadow(
                  color: circleColor.withOpacity(0.3 * _currentAudioLevel),
                  blurRadius: 8 + (_currentAudioLevel * 12),
                  spreadRadius: 2 + (_currentAudioLevel * 4),
                ),
              ] : null,
            ),
          ),
        ),
      );
    });
  }

  double _getCircleOpacity(int index) {
    double baseOpacity;
    switch (_currentState) {
      case TouchState.idle:
        baseOpacity = 0.4 - (index * 0.04);
        break;
      case TouchState.pressed:
      case TouchState.recording:
        baseOpacity = 0.9 - (index * 0.08);
        break;
      case TouchState.analyzing:
        baseOpacity = 0.7 - (index * 0.06);
        break;
      default:
        baseOpacity = 0.3;
    }
    
    // 오디오 레벨에 따른 투명도 조절 (바깥 원일수록 더 반응적)
    double audioBoost = _currentAudioLevel * (0.4 - index * 0.05);
    return math.min(1.0, baseOpacity + audioBoost);
  }
  
  double _getBorderWidth(int index) {
    double baseBorderWidth = 1.5 + (index * 0.2); // 바깥 원일수록 두께
    
    if (_currentState == TouchState.pressed || _currentState == TouchState.recording) {
      return baseBorderWidth + (_currentAudioLevel * 1.5);
    }
    
    return baseBorderWidth + (_currentAudioLevel * 0.8);
  }

  Color _getCircleColor() {
    switch (_currentState) {
      case TouchState.idle:
        return _accentColor;
      case TouchState.pressed:
      case TouchState.recording:
        return _warningColor;
      case TouchState.analyzing:
        return _primaryColor;
      default:
        return _accentColor;
    }
  }

  Widget _buildCenterContent() {
    return AnimatedBuilder(
      animation: _analysisController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _currentState == TouchState.analyzing 
            ? _analysisAnimation.value * 2 * math.pi 
            : 0,
          child: Transform.scale(
            scale: 1.0 + (_currentAudioLevel * 0.05), // 오디오 레벨에 따른 중앙 컨텐츠 미세 스케일링
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 오비완 로고/텍스트
                _buildLogo(),
                
                const SizedBox(height: 16),
                
                // 상태 텍스트
                _buildStateText(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    Color logoColor = _getCircleColor();
    double audioPulse = _currentAudioLevel > 0.2 ? (1.0 + _currentAudioLevel * 0.15) : 1.0;
    
    return Transform.scale(
      scale: audioPulse,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withOpacity(0.12 + _currentAudioLevel * 0.08),
              Colors.white.withOpacity(0.05 + _currentAudioLevel * 0.03),
            ],
            stops: const [0.5, 1.0],
          ),
          border: Border.all(
            color: logoColor.withOpacity(0.4 + _currentAudioLevel * 0.3),
            width: 1.5 + (_currentAudioLevel * 1.0),
          ),
          boxShadow: _currentAudioLevel > 0.3 ? [
            BoxShadow(
              color: logoColor.withOpacity(0.2 * _currentAudioLevel),
              blurRadius: 8 + (_currentAudioLevel * 8),
              spreadRadius: 2 + (_currentAudioLevel * 3),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Obi-wan',
              style: TextStyle(
                color: Colors.white.withOpacity(0.95 + _currentAudioLevel * 0.05),
                fontSize: 20 + (_currentAudioLevel * 2),
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'AI 보컬 트레이너',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7 + _currentAudioLevel * 0.1),
                fontSize: 10,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateText() {
    String stateText;
    switch (_currentState) {
      case TouchState.idle:
        stateText = '터치하고 홀드하세요';
        break;
      case TouchState.pressed:
      case TouchState.recording:
        stateText = '녹음 중...';
        break;
      case TouchState.analyzing:
        stateText = '분석 중...';
        break;
      default:
        stateText = '';
    }
    
    return AnimatedOpacity(
      opacity: stateText.isEmpty ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Text(
        stateText,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}