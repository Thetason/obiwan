import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../widgets/wave_visualizer_widget.dart';
import '../widgets/advanced_pitch_visualizer.dart';
import '../services/dual_engine_service.dart';
import '../widgets/audio_player_widget.dart';
import '../services/native_audio_service.dart';
import '../models/analysis_result.dart';
import '../utils/pitch_color_system.dart';
import '../utils/vibrato_analyzer.dart';
import 'fixed_vocal_training_screen.dart';
import 'vanido_style_training_screen.dart';
import 'realtime_pitch_tracker_screen.dart';
import 'realtime_pitch_tracker_v2.dart';

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
  final VibratoAnalyzer _vibratoAnalyzer = VibratoAnalyzer();
  final BreathingAnalyzer _breathingAnalyzer = BreathingAnalyzer();
  
  bool _isRecording = false;
  double _audioLevel = 0.0;
  TouchState _touchState = TouchState.idle;
  List<double>? _recordedAudioData;
  
  // 고급 시각화를 위한 새로운 상태들
  final List<PitchData> _pitchHistory = [];
  PitchData? _currentPitch;
  VibratoResult _currentVibrato = const VibratoResult.none();
  BreathingResult _currentBreathing = const BreathingResult.insufficient();
  
  // 애니메이션 컨트롤러
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;
  
  // 색상 테마 - 밝고 친근한 톤
  final Color _primaryColor = const Color(0xFF5B8DEE);
  final Color _secondaryColor = const Color(0xFF9C88FF);
  final Color _accentColor = const Color(0xFF00BFA6);

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
        
        // 실시간 피치 분석 (시뮬레이션 - 실제로는 CREPE/SPICE 결과 사용)
        if (_isRecording && level > 0.01) {
          _simulateRealtimePitch(level);
        }
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
          backgroundColor: const Color(0xFFF5F5F7),
          body: SafeArea(
            child: AudioPlayerWidget(
              audioData: audioData,
              duration: duration,
              onAnalyze: (List<DualResult>? timeBasedResults) {
                // 시간별 분석 결과에서 대표값 추출 (첫 번째 또는 가장 신뢰도 높은 것)
                DualResult? representativeResult;
                if (timeBasedResults != null && timeBasedResults.isNotEmpty) {
                  // 신뢰도가 가장 높은 결과 선택
                  representativeResult = timeBasedResults.reduce((a, b) => 
                    a.confidence > b.confidence ? a : b);
                }
                
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => VanidoStyleTrainingScreen(
                      analysisResult: representativeResult,
                      timeBasedResults: timeBasedResults, // 시간별 결과도 전달
                      audioData: audioData,
                    ),
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

  /// 실시간 피치 시뮬레이션 (오디오 레벨 기반)
  void _simulateRealtimePitch(double level) {
    // 실제로는 CREPE/SPICE 서버에서 받은 데이터를 사용
    // 여기서는 오디오 레벨을 기반으로 시뮬레이션
    
    final now = DateTime.now();
    final baseFreq = 220.0 + (level * 200.0); // A3 ~ A4 범위
    final confidence = (level * 2.0).clamp(0.0, 1.0);
    
    // 약간의 랜덤 변화로 자연스러운 피치 변동 시뮬레이션
    final randomOffset = (DateTime.now().millisecondsSinceEpoch % 1000) / 1000.0;
    final frequency = baseFreq + (math.sin(randomOffset * math.pi * 2) * 20);
    
    final pitchData = PitchData(
      frequency: frequency,
      confidence: confidence,
      cents: (math.sin(randomOffset * math.pi * 4) * 15), // ±15 cents 변동
      timestamp: now,
      amplitude: level,
    );
    
    // 피치 히스토리 업데이트
    _pitchHistory.add(pitchData);
    if (_pitchHistory.length > 50) {
      _pitchHistory.removeAt(0); // 최대 50개 유지
    }
    
    // 현재 피치 업데이트
    _currentPitch = pitchData;
    
    // 비브라토 분석
    _currentVibrato = _vibratoAnalyzer.analyzeVibrato(pitchData);
    
    // 호흡법 분석 
    _currentBreathing = _breathingAnalyzer.analyzeBreathing(_pitchHistory);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _vibratoAnalyzer.clearHistory();
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
                  
                  // 실시간 피치 트래커 버튼
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RealtimePitchTrackerV2(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.graphic_eq),
                      label: const Text('실시간 피치 트래커'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  
                  // 메인 도플러 웨이브 비주얼라이저 영역
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
            const Color(0xFFF5F5F7),
            const Color(0xFFFFFFFF),
            animationValue,
          )!,
          Color.lerp(
            const Color(0xFFFFFFFF),
            const Color(0xFFF8F9FA),
            animationValue,
          )!,
          Color.lerp(
            const Color(0xFFF8F9FA),
            const Color(0xFFF5F5F7),
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
          // 상단 버튼들
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48), // 좌측 여백
              
              // 테스트 버튼
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/pitch_test');
                  },
                  icon: Icon(
                    Icons.tune,
                    color: _primaryColor,
                    size: 24,
                  ),
                  tooltip: '피치 테스트',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
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
              color: const Color(0xFF1D1D1F),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 서브타이틀
          Text(
            'AI Vocal Training Assistant',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF1D1D1F).withOpacity(0.7),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _accentColor.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
                    color: Color(0xFF1D1D1F).withOpacity(0.8),
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
              color: Color(0xFF1D1D1F).withOpacity(0.6),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}