import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../widgets/modern_card.dart';
import '../widgets/modern_button.dart';
import '../widgets/ripple_visualization.dart';
import '../widgets/advanced_pitch_display.dart';
import '../widgets/modern_audio_visualizer.dart';
import '../widgets/premium_button.dart';
import '../widgets/glassmorphism_card.dart';
import '../services/dual_engine_service.dart';
import '../models/analysis_result.dart';

class VocalTrainingScreen extends StatefulWidget {
  const VocalTrainingScreen({super.key});

  @override
  State<VocalTrainingScreen> createState() => _VocalTrainingScreenState();
}

class _VocalTrainingScreenState extends State<VocalTrainingScreen>
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F23),
              Color(0xFF1A1B23),
              Color(0xFF0F1419),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildPitchDisplay(),
                      const SizedBox(height: 24),
                      _buildTargetPitchSlider(),
                      const SizedBox(height: 24),
                      _buildFeedbackCard(),
                      const SizedBox(height: 24),
                      _buildAnalysisInfo(),
                      const SizedBox(height: 32),
                      _buildRecordingButton(),
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

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Text(
            '보컬 트레이닝',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isRecording ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isRecording ? 'REC' : 'READY',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPitchDisplay() {
    return ModernCard(
      child: Column(
        children: [
          const Text(
            '현재 피치',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isRecording ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isRecording 
                          ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                          : [const Color(0xFF374151), const Color(0xFF4B5563)],
                    ),
                    boxShadow: _isRecording ? [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ] : null,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_currentPitch.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'Hz',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (_lastResult != null) ...[
            Text(
              '신뢰도: ${(_lastResult!.confidence * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                color: _lastResult!.confidence > 0.7 
                    ? const Color(0xFF10B981) 
                    : const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '엔진: ${_lastResult!.recommendedEngine}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetPitchSlider() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '목표 피치',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF6366F1),
                    inactiveTrackColor: const Color(0xFF374151),
                    thumbColor: const Color(0xFF6366F1),
                    overlayColor: const Color(0xFF6366F1).withOpacity(0.2),
                  ),
                  child: Slider(
                    value: _targetPitch,
                    min: 80.0,
                    max: 800.0,
                    divisions: 100,
                    onChanged: (value) {
                      setState(() {
                        _targetPitch = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_targetPitch.toStringAsFixed(1)} Hz',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard() {
    return StatusCard(
      status: _currentPitch > 0 ? CardStatus.info : CardStatus.warning,
      child: Column(
        children: [
          Icon(
            _lastResult?.isChord == true ? Icons.queue_music : Icons.music_note,
            size: 40,
            color: const Color(0xFF6366F1),
          ),
          const SizedBox(height: 12),
          Text(
            _feedback,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisInfo() {
    if (_lastResult == null) return const SizedBox.shrink();

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '분석 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (_lastResult!.hasCrepe) ...[
            _buildInfoRow('CREPE 피치', '${_lastResult!.crepeResult!.frequency.toStringAsFixed(1)} Hz'),
            _buildInfoRow('안정성', '${_lastResult!.crepeResult!.stability.toStringAsFixed(1)}%'),
          ],
          if (_lastResult!.hasSpice) ...[
            _buildInfoRow('SPICE 피치', '${_lastResult!.spiceResult!.frequency.toStringAsFixed(1)} Hz'),
            _buildInfoRow('감지된 음성', '${_lastResult!.spiceResult!.detectedPitchCount}개'),
          ],
          _buildInfoRow('분석 품질', '${(_lastResult!.analysisQuality * 100).toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingButton() {
    return FloatingModernButton(
      icon: _isRecording ? Icons.stop : Icons.mic,
      onPressed: _isInitialized ? (_isRecording ? _stopRecording : _startRecording) : null,
      backgroundColor: _isRecording ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
      size: 80,
    );
  }
}