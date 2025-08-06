import 'package:flutter/material.dart';
import '../widgets/wave_visualizer_widget.dart';
import '../services/dual_engine_service.dart';
import '../widgets/audio_player_widget.dart';
import '../services/native_audio_service.dart';
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
  final NativeAudioService _audioService = NativeAudioService.instance;
  bool _isRecording = false;
  double _audioLevel = 0.0;
  TouchState _touchState = TouchState.idle;
  List<double>? _recordedAudioData;
  
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

  void _initializeAudioService() async {
    // 네이티브 오디오 서비스 초기화
    await _audioService.initialize();
    
    // 오디오 레벨 콜백 설정
    _audioService.onAudioLevelChanged = (level) {
      if (mounted) {
        setState(() {
          _audioLevel = level * 10.0; // 시각화를 위해 증폭
        });
      }
    };
    print('🎵 오디오 서비스 초기화 완료');
  }

  void _handleTouchStart() async {
    print('🎤 녹음 시작');
    setState(() {
      _isRecording = true;
      _touchState = TouchState.recording;
    });
    
    try {
      // 실제 녹음 시작
      final success = await _audioService.startRecording();
      if (success) {
        print('🎤 네이티브 녹음 시작됨');
      } else {
        print('❌ 녹음 시작 실패');
        setState(() {
          _isRecording = false;
          _touchState = TouchState.idle;
        });
      }
    } catch (e) {
      print('녹음 시작 오류: $e');
      setState(() {
        _isRecording = false;
        _touchState = TouchState.idle;
      });
    }
  }

  void _handleTouchEnd() async {
    print('🎤 녹음 종료 및 분석 시작');
    setState(() {
      _isRecording = false;
      _touchState = TouchState.analyzing;
    });
    
    try {
      // 실제 녹음 종료
      await _audioService.stopRecording();
      print('🎤 네이티브 녹음 종료');
      
      // 녹음된 오디오 데이터 가져오기
      final audioData = await _audioService.getRecordedAudio();
      if (audioData != null && audioData.isNotEmpty) {
        print('🎵 녹음된 오디오 데이터: ${audioData.length} 샘플');
        _recordedAudioData = audioData;
        
        // 1초 후 결과 화면으로 이동
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _navigateToResults();
          }
        });
      } else {
        print('❌ 오디오 데이터가 없습니다');
        setState(() {
          _touchState = TouchState.idle;
        });
      }
      
    } catch (e) {
      print('분석 오류: $e');
      setState(() {
        _touchState = TouchState.idle;
      });
    }
  }

  void _navigateToResults() {
    // 실제 녹음된 오디오 데이터 사용
    final audioData = _recordedAudioData ?? [];
    
    // 녹음 시간 계산 (44.1kHz 기준)
    final duration = Duration(
      milliseconds: ((audioData.length / 44100) * 1000).round(),
    );
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
          backgroundColor: const Color(0xFF0F0F23),
          body: SafeArea(
            child: AudioPlayerWidget(
              audioData: audioData,
              duration: duration,
              onAnalyze: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const FixedVocalTrainingScreen(),
                  ),
                );
              },
              onReRecord: () {
                Navigator.of(context).pop();
                setState(() {
                  _recordedAudioData = null;
                  _touchState = TouchState.idle;
                });
              },
            ),
          ),
        ),
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