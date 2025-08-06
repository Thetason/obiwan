import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../widgets/ripple_visualization.dart';
import '../widgets/advanced_pitch_display.dart';
import '../widgets/modern_audio_visualizer.dart';
import '../widgets/premium_button.dart';
import '../widgets/glassmorphism_card.dart';
import '../widgets/smart_feedback_system.dart';
import '../widgets/particle_system.dart';
import '../services/dual_engine_service.dart';
import '../models/analysis_result.dart';

class FixedVocalTrainingScreen extends StatefulWidget {
  const FixedVocalTrainingScreen({super.key});

  @override
  State<FixedVocalTrainingScreen> createState() => _FixedVocalTrainingScreenState();
}

class _FixedVocalTrainingScreenState extends State<FixedVocalTrainingScreen>
    with TickerProviderStateMixin {
  FlutterSoundRecorder? _recorder;
  RealtimeAnalysisStream? _analysisStream;
  StreamController<Uint8List>? _recordingController;
  
  bool _isInitialized = false;
  bool _isRecording = false;
  
  // 분석 결과
  DualResult? _lastResult;
  double _currentPitch = 0.0;
  double _targetPitch = 440.0; // A4
  String _feedback = "초기화 중...";
  String _noteName = "---";
  double _cents = 0.0;
  double _audioLevel = 0.0;
  
  // 애니메이션
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  
  // 피치 히스토리 (시각화용)
  final List<double> _pitchHistory = [];
  static const int _maxHistoryLength = 100;
  
  // 오디오 데이터 (시각화용)
  Float32List? _currentAudioData;
  
  // 색상 테마
  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _secondaryColor = const Color(0xFF8B5CF6);
  final Color _accentColor = const Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeServices();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _waveAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.linear),
    );

    _pulseController.repeat(reverse: true);
    _waveController.repeat();
  }

  Future<void> _initializeServices() async {
    try {
      // 마이크 권한 요청
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('마이크 권한이 필요합니다');
      }

      // Flutter Sound 초기화
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();

      // 분석 스트림 초기화
      _analysisStream = RealtimeAnalysisStream();
      _analysisStream!.stream.listen(_onAnalysisResult);

      setState(() {
        _isInitialized = true;
        _feedback = "준비 완료! 🎤 버튼을 눌러 시작하세요";
      });

    } catch (e) {
      setState(() {
        _feedback = "초기화 실패: $e";
      });
    }
  }

  void _onAnalysisResult(DualResult result) {
    setState(() {
      _lastResult = result;
      _currentPitch = result.frequency;
      
      // 피치 히스토리 업데이트
      _pitchHistory.add(_currentPitch);
      if (_pitchHistory.length > _maxHistoryLength) {
        _pitchHistory.removeAt(0);
      }
      
      // 노트 이름과 센트 계산
      if (_currentPitch > 0) {
        _noteName = _getNoteName(_currentPitch);
        _cents = _getCentsFromFrequency(_currentPitch, _targetPitch);
      } else {
        _noteName = "---";
        _cents = 0.0;
      }
      
      // 피드백 생성
      _feedback = _generateFeedback(result);
    });
  }

  String _generateFeedback(DualResult result) {
    if (result.frequency <= 0) {
      return "목소리가 감지되지 않았어요 🎤";
    }

    if (result.isChord) {
      final pitchCount = result.detectedPitches.length;
      return "화음 감지! 🎵\n${pitchCount}개 음성이 감지되었습니다";
    }

    // 단일음 피드백
    final cents = 1200 * math.log(result.frequency / _targetPitch) / math.log(2);
    final absCents = cents.abs();
    
    if (absCents < 5) {
      return "완벽합니다! 🎯\n${cents.toStringAsFixed(1)} cents 오차";
    } else if (absCents < 20) {
      return cents > 0 
          ? "조금 높아요 ⬇️\n+${cents.toStringAsFixed(1)} cents"
          : "조금 낮아요 ⬆️\n${cents.toStringAsFixed(1)} cents";
    } else {
      return cents > 0 
          ? "많이 높아요 🔻\n+${cents.toStringAsFixed(1)} cents"
          : "많이 낮아요 🔺\n${cents.toStringAsFixed(1)} cents";
    }
  }

  Future<void> _startRecording() async {
    if (!_isInitialized || _isRecording) return;

    try {
      _recordingController = StreamController<Uint8List>();
      
      // 분석 스트림 시작
      _analysisStream!.startStream();

      // 녹음 시작
      await _recorder!.startRecorder(
        toStream: _recordingController!.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
      );

      // 오디오 데이터 처리
      _recordingController!.stream.listen((buffer) {
        final audioData = _processAudioBuffer(buffer);
        if (audioData != null) {
          // 시각화를 위해 현재 오디오 데이터 저장
          setState(() {
            _currentAudioData = audioData;
            _audioLevel = _calculateAudioLevel(audioData);
          });
          _analysisStream!.addAudioChunk(audioData);
        }
      });

      setState(() {
        _isRecording = true;
        _feedback = "녹음 중... 소리를 내보세요! 🎵";
      });

    } catch (e) {
      setState(() {
        _feedback = "녹음 시작 실패: $e";
      });
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder!.stopRecorder();
      _analysisStream!.stopStream();
      await _recordingController?.close();
      _recordingController = null;

      setState(() {
        _isRecording = false;
        _feedback = "녹음 중지됨. 다시 시작하려면 🎤를 누르세요";
        _audioLevel = 0.0;
        _currentAudioData = null;
      });

    } catch (e) {
      setState(() {
        _feedback = "녹음 중지 실패: $e";
      });
    }
  }

  Float32List? _processAudioBuffer(Uint8List buffer) {
    try {
      final int16Data = Int16List.view(buffer.buffer);
      final float32Data = Float32List(int16Data.length);
      
      for (int i = 0; i < int16Data.length; i++) {
        float32Data[i] = int16Data[i] / 32768.0;
      }
      
      return float32Data;
    } catch (e) {
      debugPrint('Audio buffer processing failed: $e');
      return null;
    }
  }
  
  double _calculateAudioLevel(Float32List audioData) {
    double sum = 0.0;
    for (int i = 0; i < audioData.length; i++) {
      sum += audioData[i].abs();
    }
    return (sum / audioData.length).clamp(0.0, 1.0);
  }
  
  String _getNoteName(double frequency) {
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const a4 = 440.0;
    
    final semitones = 12 * (math.log(frequency / a4) / math.log(2));
    final noteIndex = (semitones.round() + 9) % 12;
    final octave = ((semitones + 9) / 12).floor() + 4;
    
    return '${noteNames[noteIndex]}$octave';
  }
  
  double _getCentsFromFrequency(double frequency, double targetFreq) {
    return 1200 * math.log(frequency / targetFreq) / math.log(2);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _recorder?.closeRecorder();
    _analysisStream?.dispose();
    _recordingController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F0F23),
              const Color(0xFF1A1B23),
              const Color(0xFF0F1419),
              _primaryColor.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // 도플러 웨이브 시각화
                      RippleVisualization(
                        audioLevel: _audioLevel,
                        isRecording: _isRecording,
                        primaryColor: _primaryColor,
                        secondaryColor: _secondaryColor,
                      ),
                      const SizedBox(height: 32),
                      // 고급 피치 디스플레이
                      AdvancedPitchDisplay(
                        frequency: _currentPitch,
                        confidence: _lastResult?.confidence ?? 0.0,
                        noteName: _noteName,
                        cents: _cents,
                        isActive: _isRecording && _currentPitch > 0,
                      ),
                      const SizedBox(height: 24),
                      // 스마트 피드백 시스템
                      SmartFeedbackSystem(
                        analysisResult: _lastResult,
                        targetPitch: _targetPitch,
                        isActive: _isRecording,
                        primaryColor: _primaryColor,
                        secondaryColor: _secondaryColor,
                      ),
                      const SizedBox(height: 24),
                      _buildPremiumRecordingButton(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return GlassmorphismCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
              ),
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오비완 v2 보컬 트레이너',
                  style: TextStyle(
                    fontSize: 20,
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
                const SizedBox(height: 4),
                Text(
                  'CREPE + SPICE 듀얼 AI 엔진',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isRecording 
                  ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                  : [_accentColor, const Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (_isRecording ? const Color(0xFFEF4444) : _accentColor)
                      .withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isRecording ? Icons.fiber_manual_record : Icons.check_circle,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _isRecording ? 'RECORDING' : 'READY',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumRecordingButton() {
    return PremiumButton(
      text: _isRecording ? '녹음 중지' : '보컬 트레이닝 시작',
      icon: _isRecording ? Icons.stop : Icons.mic,
      onPressed: _isInitialized ? (_isRecording ? _stopRecording : _startRecording) : null,
      isEnabled: _isInitialized,
      isLoading: !_isInitialized,
      primaryColor: _isRecording ? const Color(0xFFEF4444) : _primaryColor,
      secondaryColor: _isRecording ? const Color(0xFFDC2626) : _secondaryColor,
      width: double.infinity,
      height: 64,
    );
  }
}