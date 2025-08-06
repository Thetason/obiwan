import 'package:flutter/material.dart';
import '../widgets/wave_visualizer_widget.dart';
import '../services/dual_engine_service.dart';
import 'fixed_vocal_training_screen.dart';

class WaveStartScreen extends StatefulWidget {
  const WaveStartScreen({super.key});

  @override
  State<WaveStartScreen> createState() => _WaveStartScreenState();
}

class _WaveStartScreenState extends State<WaveStartScreen>
    with TickerProviderStateMixin {
  
  // 서비스 및 상태 관리
  final DualEngineService _engineService = DualEngineService();
  bool _isRecording = false;
  double _audioLevel = 0.0;
  TouchState _touchState = TouchState.idle;
  
  // 애니메이션 컨트롤러
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;
  
  // 색상 테마
  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _secondaryColor = const Color(0xFF8B5CF6);
  final Color _accentColor = const Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _initializeBackground();
    _initializeAudioService();
  }

  void _initializeBackground() {
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    
    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.linear),
    );
    
    _backgroundController.repeat();
  }

  void _initializeAudioService() {
    // 오디오 서비스 초기화 (현재는 더미)
    print('🎵 오디오 서비스 초기화 완료');
  }

  void _handleTouchStart() async {
    print('🎤 녹음 시작');
    setState(() {
      _isRecording = true;
      _touchState = TouchState.recording;
    });
    
    try {
      // 실제 녹음 시작 로직 (더미)
      await Future.delayed(const Duration(milliseconds: 100));
      print('🎤 녹음 시작됨');
    } catch (e) {
      print('녹음 시작 오류: $e');
    }
  }

  void _handleTouchEnd() async {
    print('🎤 녹음 종료 및 분석 시작');
    setState(() {
      _isRecording = false;
      _touchState = TouchState.analyzing;
    });
    
    try {
      // 실제 녹음 종료 및 분석 (더미)
      await Future.delayed(const Duration(milliseconds: 100));
      print('🎤 녹음 종료 및 분석 시작');
      
      // 3초 후 결과 화면으로 이동
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _navigateToResults();
        }
      });
      
    } catch (e) {
      print('분석 오류: $e');
      setState(() {
        _touchState = TouchState.idle;
      });
    }
  }

  void _navigateToResults() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const FixedVocalTrainingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: _buildBackgroundDecoration(),
            child: SafeArea(
              child: Column(
                children: [
                  // 상단 제목 영역
                  _buildHeader(),
                  
                  // 메인 웨이브 비주얼라이저 영역
                  Expanded(
                    child: Center(
                      child: WaveVisualizerWidget(
                        isRecording: _isRecording,
                        audioLevel: _audioLevel,
                        touchState: _touchState,
                        onTouchStart: _handleTouchStart,
                        onTouchEnd: _handleTouchEnd,
                      ),
                    ),
                  ),
                  
                  // 하단 설명 영역
                  _buildFooter(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  BoxDecoration _buildBackgroundDecoration() {
    double animationValue = _backgroundAnimation.value;
    
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(
            const Color(0xFF0F0F23),
            const Color(0xFF1A1B23),
            animationValue,
          )!,
          Color.lerp(
            const Color(0xFF1A1B23),
            const Color(0xFF0F1419),
            animationValue,
          )!,
          Color.lerp(
            const Color(0xFF0F1419),
            const Color(0xFF0F0F23),
            animationValue,
          )!,
        ],
        stops: [
          0.0 + (animationValue * 0.2),
          0.5 + (animationValue * 0.3),
          1.0 - (animationValue * 0.2),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // 앱 아이콘
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.multitrack_audio,
              color: Colors.white,
              size: 30,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 타이틀
          Text(
            'Obi-wan v2',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: _primaryColor.withOpacity(0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 서브타이틀
          Text(
            'AI Vocal Training Assistant',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w300,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // 인스트럭션
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _accentColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app,
                  color: _accentColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  '웨이브를 터치하고 홀드하여 음성을 녹음하세요',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 설명
          Text(
            'CREPE + SPICE 듀얼 AI 엔진이\n실시간으로 당신의 목소리를 분석합니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}