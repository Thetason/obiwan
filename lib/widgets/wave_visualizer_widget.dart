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
  
  // 애니메이션들
  late List<Animation<double>> _waveAnimations;
  late Animation<double> _pulseAnimation;
  late Animation<double> _touchAnimation;
  late Animation<double> _analysisAnimation;
  
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
    // 6개 동심원용 웨이브 컨트롤러
    _waveControllers = List.generate(6, (index) =>
        AnimationController(
          duration: Duration(milliseconds: 1000 + (index * 100)),
          vsync: this,
        )
    );

    // 웨이브 애니메이션들
    _waveAnimations = _waveControllers.map((controller) =>
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeInOut),
        )
    ).toList();

    // 펄스 애니메이션 (기본 대기 상태)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 터치 반응 애니메이션
    _touchController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _touchAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _touchController, curve: Curves.easeOut),
    );

    // 분석 중 회전 애니메이션
    _analysisController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _analysisAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _analysisController, curve: Curves.linear),
    );
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
  void dispose() {
    _pulseController.dispose();
    _touchController.dispose();
    _analysisController.dispose();
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
    return Container(
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
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _accentColor.withOpacity(0.1),
            _primaryColor.withOpacity(0.05),
            Colors.transparent,
          ],
          stops: const [0.2, 0.6, 1.0],
        ),
      ),
    );
  }

  List<Widget> _buildWaveCircles() {
    return List.generate(6, (index) {
      double baseSize = 80 + (index * 25);
      double animationValue = _waveAnimations[index].value;
      double pulseValue = _pulseAnimation.value;
      double touchScale = _touchAnimation.value;
      
      // 터치 상태에 따른 크기 조절
      double sizeMultiplier = 1.0;
      if (_currentState == TouchState.pressed || _currentState == TouchState.recording) {
        sizeMultiplier = touchScale;
      } else if (_currentState == TouchState.idle) {
        sizeMultiplier = 1.0 + (pulseValue * 0.1);
      }
      
      double opacity = _getCircleOpacity(index);
      Color circleColor = _getCircleColor();
      
      return Positioned.fill(
        child: Center(
          child: Transform.scale(
            scale: sizeMultiplier,
            child: Container(
              width: baseSize + (animationValue * 20),
              height: baseSize + (animationValue * 20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: circleColor.withOpacity(opacity),
                  width: 2.0,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  double _getCircleOpacity(int index) {
    switch (_currentState) {
      case TouchState.idle:
        return 0.4 - (index * 0.05);
      case TouchState.pressed:
      case TouchState.recording:
        return 0.8 - (index * 0.1);
      case TouchState.analyzing:
        return 0.6 - (index * 0.08);
      default:
        return 0.3;
    }
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
        );
      },
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.1),
        border: Border.all(
          color: _getCircleColor().withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Text(
        'Obi-wan',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w300,
          letterSpacing: 2.0,
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