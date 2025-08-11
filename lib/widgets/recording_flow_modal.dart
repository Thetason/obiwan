import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import '../services/native_audio_service.dart';
import '../services/dual_engine_service.dart';
import '../services/sound_feedback_service.dart';
import '../services/timbre_analysis_service.dart';
import '../theme/pitch_colors.dart';
import 'playback_visualizer.dart';
import 'realtime_pitch_graph.dart';
import 'realtime_visual_feedback.dart';
import 'pitch_bar_visualizer.dart';
import 'success_animation_overlay.dart';
import 'force_glow_effect.dart';

enum FlowStep { recording, playback, analysis, results }

class RecordingFlowModal extends StatefulWidget {
  final VoidCallback onClose;
  
  const RecordingFlowModal({
    Key? key,
    required this.onClose,
  }) : super(key: key);
  
  @override
  State<RecordingFlowModal> createState() => _RecordingFlowModalState();
}

class _RecordingFlowModalState extends State<RecordingFlowModal>
    with TickerProviderStateMixin {
  
  FlowStep _currentStep = FlowStep.recording;
  bool _isRecording = false;
  bool _isPlaying = false;
  double _recordingTime = 0.0;
  List<double>? _recordedAudioData;
  List<double> _realtimeWaveform = [];
  List<PitchPoint> _pitchData = [];
  
  // 실시간 분석 상태 추가
  int _currentPitchIndex = 0;
  double _currentFrequency = 0.0;
  double _currentConfidence = 0.0;
  
  // 서비스
  final NativeAudioService _audioService = NativeAudioService.instance;
  final DualEngineService _engineService = DualEngineService();
  final SoundFeedbackService _soundService = SoundFeedbackService.instance;
  final TimbreAnalysisService _timbreService = TimbreAnalysisService.instance;
  
  // 애니메이션
  late AnimationController _recordingPulseController;
  late AnimationController _waveformController;
  late Animation<double> _recordingPulseAnimation;
  
  Timer? _recordingTimer;
  Timer? _waveformTimer;
  
  // 분석 결과
  double _averagePitch = 0.0;
  double _accuracy = 0.0;
  double _stability = 0.0;
  
  // 음색 분석 결과
  TimbreResult? _timbreResult;
  String _timbreFeedback = '';
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startRecording();
  }
  
  void _initializeAnimations() {
    _recordingPulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _recordingPulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _recordingPulseController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    // CRITICAL FIX: dispose 플래그 설정으로 추가 작업 방지
    if (!mounted) return;
    
    print('🔄 [RecordingFlow] dispose 시작');
    
    // 모든 타이머 즉시 취소
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _waveformTimer?.cancel();
    _waveformTimer = null;
    
    // 애니메이션 컨트롤러 정리
    _recordingPulseController.dispose();
    _waveformController.dispose();
    
    // CRITICAL FIX: 오디오 서비스 안전 정리 (비동기 처리)
    _cleanupAudioServices();
    
    // 대용량 데이터 메모리 해제
    _recordedAudioData = null;
    _pitchData.clear();
    _realtimeWaveform.clear();
    
    print('✅ [RecordingFlow] dispose 완료');
    super.dispose();
  }
  
  // CRITICAL FIX: 오디오 서비스 안전 정리 메소드
  void _cleanupAudioServices() {
    // 녹음 중지 (비동기, 에러 무시)
    if (_isRecording) {
      _audioService.stopRecording().catchError((e) {
        print('⚠️ [RecordingFlow] 녹음 중지 실패 (무시): $e');
      });
    }
    
    // 재생 중지 (비동기, 에러 무시)
    if (_isPlaying) {
      // stopPlayback과 stopAudio 둘 다 호출하여 확실하게 정리
      _audioService.stopPlayback().catchError((e) {
        // dispose에서는 에러 무시
      });
      _audioService.stopAudio().catchError((e) {
        // dispose에서는 에러 무시
      });
    }
    
    // 상태 초기화
    _isRecording = false;
    _isPlaying = false;
  }
  
  Future<void> _startRecording() async {
    try {
      await _audioService.startRecording();
      await _soundService.playRecordingStart(); // 녹음 시작 피드백
      
      setState(() {
        _isRecording = true;
        _recordingTime = 0.0;
        _realtimeWaveform.clear();
      });
      
      _recordingPulseController.repeat(reverse: true);
      
      // 녹음 시간 타이머
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordingTime += 0.1;
          
          // 실제 오디오 레벨 가져와서 웨이브폼 표시
          _audioService.getCurrentAudioLevel().then((level) {
            if (mounted) {
              _realtimeWaveform.add(level);
              if (_realtimeWaveform.length > 50) {
                _realtimeWaveform.removeAt(0);
              }
            }
          }).catchError((e) {
            // 오디오 레벨을 못 가져오면 최소값 사용
            if (mounted) {
              _realtimeWaveform.add(0.1);
              if (_realtimeWaveform.length > 50) {
                _realtimeWaveform.removeAt(0);
              }
            }
          });
        });
      });
      
    } catch (e) {
      print('녹음 시작 실패: $e');
    }
  }
  
  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      _recordingPulseController.stop();
      
      await _soundService.playRecordingStop(); // 녹음 종료 피드백
      await _audioService.stopRecording();
      
      // 실제 녹음된 오디오 데이터 가져오기
      final audioData = await _audioService.getRecordedAudioData();
      
      setState(() {
        _isRecording = false;
        _currentStep = FlowStep.playback;
        _recordedAudioData = audioData ?? [];
      });
      
      HapticFeedback.mediumImpact();
      
    } catch (e) {
      print('녹음 중지 실패: $e');
    }
  }
  
  Future<void> _startPlayback() async {
    if (!mounted) return;
    
    // CRITICAL FIX: 이전 상태 정리
    _waveformTimer?.cancel();
    _waveformTimer = null;
    
    if (mounted) {
      setState(() {
        _isPlaying = true;
        _currentStep = FlowStep.analysis;
      });
    }
    
    // CRITICAL FIX: 실제 오디오 재생을 안전하게 시작
    try {
      final success = await _audioService.playRecordedAudio();
      if (!mounted) return;  // 비동기 작업 후 재확인
      
      if (success) {
        print('✅ 오디오 재생 시작됨');
        // 실제 오디오 데이터를 가져와서 CREPE/SPICE로 분석
        await _analyzeRecordedAudio();
      } else {
        print('❌ 오디오 재생 실패');
        if (mounted) _showResults();
      }
    } catch (e) {
      print('❌ 재생 오류: $e');
      if (mounted) _showResults();
    }
  }
  
  Future<void> _analyzeRecordedAudio() async {
    if (!mounted) return;  // CRITICAL FIX: mounted 상태 확인
    
    try {
      // 녹음된 오디오 데이터 가져오기
      final audioData = await _audioService.getRecordedAudioData();
      if (!mounted) return;  // 비동기 작업 후 재확인
      
      if (audioData == null || audioData.isEmpty) {
        print('❌ 녹음된 오디오 데이터가 없습니다');
        if (mounted) _showResults();
        return;
      }
      
      print('🎵 오디오 분석 시작: ${audioData.length} 샘플');
      
      // List<double>을 Float32List로 변환
      final float32Data = Float32List.fromList(audioData);
      
      // CREPE/SPICE 듀얼 엔진으로 시간별 피치 분석
      final pitchResults = await _engineService.analyzeTimeBasedPitch(float32Data);
      
      // 음색 분석 일시적으로 비활성화 (디버깅)
      print('🎨 음색 분석 스킵 (디버깅 모드)');
      _timbreResult = null;
      _timbreFeedback = '';
      
      if (pitchResults.isEmpty) {
        print('❌ 피치 분석 결과가 없습니다');
        _showResults();
        return;
      }
      
      print('✅ 피치 분석 완료: ${pitchResults.length}개 포인트');
      
      // 분석 결과를 PitchPoint로 변환
      final convertedPitchData = pitchResults.map((result) {
        return PitchPoint(
          time: result.timeSeconds ?? 0.0,
          frequency: result.frequency,
          confidence: result.confidence,
        );
      }).toList();
      
      print('📊 변환된 피치 데이터: ${convertedPitchData.length}개');
      for (int i = 0; i < math.min(5, convertedPitchData.length); i++) {
        print('  - [${i}] ${convertedPitchData[i].time.toStringAsFixed(2)}s: ${convertedPitchData[i].frequency.toStringAsFixed(1)}Hz (${(convertedPitchData[i].confidence * 100).toStringAsFixed(0)}%)');
      }
      
      setState(() {
        _pitchData = convertedPitchData;
        
        // 첫 번째 피치 데이터로 초기화
        if (_pitchData.isNotEmpty) {
          _currentFrequency = _pitchData.first.frequency;
          _currentConfidence = _pitchData.first.confidence;
          print('🎤 초기 피치 설정: ${_currentFrequency.toStringAsFixed(1)}Hz');
          print('📈 UI 업데이트: _pitchData.length = ${_pitchData.length}');
        }
      });
      
      // CRITICAL FIX: 안전한 시각화 업데이트 타이머
      _currentPitchIndex = 0;
      _waveformTimer?.cancel();  // 기존 타이머 취소
      
      _waveformTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
        // CRITICAL FIX: mounted와 disposal 상태 체크
        if (!mounted || _isDisposed()) {
          timer.cancel();
          return;
        }
        
        final currentTime = timer.tick * 0.05;
        
        // 현재 시간에 해당하는 피치 데이터 찾기 (안전한 범위 체크)
        if (_pitchData.isNotEmpty && _currentPitchIndex >= 0 && _currentPitchIndex < _pitchData.length) {
          final currentPitch = _pitchData[_currentPitchIndex];
          
          // 시간이 맞으면 UI 업데이트
          if (currentPitch.time <= currentTime) {
            if (mounted && !_isDisposed()) {
              try {
                setState(() {
                  _currentFrequency = currentPitch.frequency;
                  _currentConfidence = currentPitch.confidence;
                });
                print('🎵 실시간 피치 업데이트: ${_currentFrequency.toStringAsFixed(1)}Hz');
              } catch (e) {
                print('⚠️ setState 실패: $e');
              }
            }
            
            // CRITICAL FIX: 사운드 피드백을 try-catch로 보호
            if (_currentConfidence > 0.7) {
              try {
                final accuracy = (_currentFrequency - 440).abs() < 50 ? 0.9 : 0.5;
                await _soundService.playPitchFeedback(accuracy);
              } catch (e) {
                print('⚠️ 사운드 피드백 실패 (무시): $e');
              }
            }
            
            _currentPitchIndex++;
          }
        }
        
        // CRITICAL FIX: 재생 완료 처리
        if (currentTime > _recordingTime) {
          timer.cancel();
          
          if (mounted && !_isDisposed()) {
            try {
              await _audioService.stopAudio();
            } catch (e) {
              print('⚠️ 오디오 정지 실패 (무시): $e');
            }
            
            if (mounted) {
              _showResults();
            }
          }
          return;
        }
      });
      
    } catch (e) {
      print('❌ 오디오 분석 오류: $e');
      if (mounted) _showResults();  // CRITICAL FIX: mounted 확인
    }
  }
  
  // CRITICAL FIX: disposal 상태 확인 메소드
  bool _isDisposed() {
    return !mounted || _recordingTimer == null && _waveformTimer == null;
  }
  
  void _showResults() {
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _currentStep = FlowStep.results;
      
      // 실제 분석 결과 계산
      if (_pitchData.isNotEmpty) {
        // 평균 음정 계산
        _averagePitch = _pitchData
            .map((p) => p.frequency)
            .reduce((a, b) => a + b) / _pitchData.length;
        
        // 목표 음정과의 정확도 계산 (A4 = 440Hz 기준)
        const targetPitch = 440.0;
        double totalDiff = 0;
        double totalConfidence = 0;
        
        for (final point in _pitchData) {
          final diff = (point.frequency - targetPitch).abs();
          final accuracy = math.max(0, 100 - (diff / targetPitch * 100));
          totalDiff += accuracy * point.confidence;
          totalConfidence += point.confidence;
        }
        
        _accuracy = totalConfidence > 0 ? totalDiff / totalConfidence : 0;
        
        // 안정성 계산 (주파수 변화의 표준편차) - 안전한 범위 체크
        if (_pitchData.length > 1) {
          double variance = 0;
          for (int i = 1; i < _pitchData.length; i++) {
            // 배열 인덱스 안전성 체크
            if (i < _pitchData.length && (i - 1) >= 0) {
              final diff = (_pitchData[i].frequency - _pitchData[i-1].frequency).abs();
              variance += diff * diff;
            }
          }
          // Division by zero 방지
          final divisor = math.max(1, _pitchData.length - 1);
          final stdDev = math.sqrt(variance / divisor);
          _stability = math.max(0, 100 - stdDev / 10); // 변화가 작을수록 안정적
        } else {
          _stability = 100;
        }
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.8),
      child: SafeArea(
        child: Column(
          children: [
            // 헤더
            _buildHeader(),
            
            // 메인 컨텐츠
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40),
          Text(
            _getStepTitle(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }
  
  String _getStepTitle() {
    switch (_currentStep) {
      case FlowStep.recording:
        return '녹음 중';
      case FlowStep.playback:
        return '녹음 확인';
      case FlowStep.analysis:
        return '실시간 분석';
      case FlowStep.results:
        return '분석 결과';
    }
  }
  
  Widget _buildContent() {
    switch (_currentStep) {
      case FlowStep.recording:
        return _buildRecordingStep();
      case FlowStep.playback:
        return _buildPlaybackStep();
      case FlowStep.analysis:
        return _buildAnalysisStep();
      case FlowStep.results:
        return _buildResultsStep();
    }
  }
  
  Widget _buildRecordingStep() {
    return Container(
      key: const ValueKey('recording'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 녹음 버튼
          AnimatedBuilder(
            animation: _recordingPulseAnimation,
            builder: (context, child) {
              return ForceGlowEffect(
                isLightSide: false,  // 녹음 중에는 다크사이드 (빨강)
                intensity: _isRecording ? 0.8 : 0.3,
                child: Transform.scale(
                  scale: _recordingPulseAnimation.value,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _isRecording 
                            ? [PitchColors.forceDark, PitchColors.forceDark.withOpacity(0.8)]
                            : [const Color(0xFFFF4757), const Color(0xFFFF6B7A)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? PitchColors.forceDark : const Color(0xFFFF4757))
                              .withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mic,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 40),
          
          // 녹음 시간
          Text(
            '${_recordingTime.toStringAsFixed(1)}초',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 실시간 웨이브폼
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(30, (index) {
                final height = index < _realtimeWaveform.length
                    ? _realtimeWaveform[index] * 60
                    : 4.0;
                return Container(
                  width: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          
          const SizedBox(height: 40),
          
          // 중지 버튼
          ElevatedButton(
            onPressed: _isRecording ? _stopRecording : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFFF4757),
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              '녹음 중지',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlaybackStep() {
    return Container(
      key: const ValueKey('playback'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 파형 시각화
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: PlaybackVisualizer(
              audioData: _recordedAudioData ?? [],
              isPlaying: false,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // 녹음 시간 정보
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  '녹음 시간: ${_recordingTime.toStringAsFixed(1)}초',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // 액션 버튼들
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 다시 녹음
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentStep = FlowStep.recording;
                    _pitchData.clear();
                  });
                  _startRecording();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('다시 녹음'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // 분석 시작
              ElevatedButton.icon(
                onPressed: _startPlayback,
                icon: const Icon(Icons.play_arrow),
                label: const Text('분석 시작'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnalysisStep() {
    // 정확도 계산
    final accuracy = _currentFrequency > 0 && _currentFrequency < 500 
        ? (_currentFrequency - 440).abs() < 50 ? 0.9 
        : (_currentFrequency - 440).abs() < 100 ? 0.7 
        : 0.5
        : 0.0;
    
    return Container(
      key: const ValueKey('analysis'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            PitchColors.backgroundDark,
            PitchColors.backgroundDark.withOpacity(0.95),
          ],
        ),
      ),
      child: Stack(
        children: [
          // 3차 레이어: 배경 웨이브폼
          Positioned.fill(
            child: Opacity(
              opacity: 0.2,
              child: CustomPaint(
                painter: _WaveformBackgroundPainter(
                  waveform: _realtimeWaveform,
                  color: PitchColors.neutral,
                ),
              ),
            ),
          ),
          
          // 2차 레이어: 피치 트래킹
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Vanido 스타일 피치 막대
                PitchBarVisualizer(
                  currentPitch: _currentFrequency,
                  targetPitch: 440.0, // A4 목표
                  confidence: _currentConfidence,
                  isActive: _isPlaying,
                ),
                
                const SizedBox(height: 20),
                
                // 메인 시각화 영역
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: PitchColors.fromAccuracy(accuracy).withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: RealtimeVisualFeedback(
                        currentFrequency: _currentFrequency,
                        targetFrequency: 440.0,
                        audioLevel: _currentConfidence,
                        isActive: _isPlaying,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 1차 레이어: 핵심 정보
          Positioned(
            top: 40,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: PitchColors.cardDark.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: PitchColors.fromAccuracy(accuracy).withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoItem(
                    '진행',
                    '${_currentPitchIndex}/${_pitchData.length}',
                    Colors.white70,
                  ),
                  _buildInfoItem(
                    '음정',
                    '${_currentFrequency.toStringAsFixed(1)}Hz',
                    PitchColors.fromAccuracy(accuracy),
                  ),
                  _buildInfoItem(
                    '정확도',
                    '${(accuracy * 100).toStringAsFixed(0)}%',
                    PitchColors.fromAccuracy(accuracy),
                  ),
                  if (_timbreResult != null)
                    _buildInfoItem(
                      '음색',
                      _getShortTimbreLabel(_timbreResult!),
                      _getTimbreColor(_timbreResult!),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 음색 분석 카드 (분석 중일 때만 표시)
          if (_timbreResult != null)
            Positioned(
              bottom: 180,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PitchColors.cardDark.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getTimbreColor(_timbreResult!).withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.graphic_eq,
                          color: _getTimbreColor(_timbreResult!),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '음색 분석',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 음색 특성 바
                    _buildTimbreBar('밝기', _timbreResult!.brightness),
                    _buildTimbreBar('따뜻함', _timbreResult!.warmth),
                    _buildTimbreBar('긴장도', _timbreResult!.tension),
                    if (_timbreResult!.breathiness > 0.3)
                      _buildTimbreBar('숨소리', _timbreResult!.breathiness),
                  ],
                ),
              ),
            ),
          
          // 하단 피치 그래프
          Positioned(
            bottom: 20,
            left: 24,
            right: 24,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _pitchData.isNotEmpty ? Colors.green : Colors.orange,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(12),
            child: _pitchData.isNotEmpty 
              ? Column(
                  children: [
                    Text(
                      '피치 그래프 (${_pitchData.length}개 데이터)',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Expanded(
                      child: RealtimePitchGraph(
                        pitchData: _pitchData,
                        isPlaying: _isPlaying,
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white54),
                      const SizedBox(height: 8),
                      Text(
                        '피치 데이터 분석 중... (현재: ${_pitchData.length}개)',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRealtimeInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
  
  Widget _buildResultsStep() {
    return Container(
      key: const ValueKey('results'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 점수 등급
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _accuracy > 80
                    ? [Color(0xFF00BFA6), Color(0xFF00E676)]
                    : [Color(0xFF7C4DFF), Color(0xFF9C88FF)],
              ),
            ),
            child: Center(
              child: Text(
                _getGrade(),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // 상세 결과
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _buildResultItem('평균 음정', '${_averagePitch.round()}Hz'),
                const SizedBox(height: 16),
                _buildResultItem('정확도', '${_accuracy.round()}%'),
                const SizedBox(height: 16),
                _buildResultItem('안정성', '${_stability.round()}%'),
                if (_timbreResult != null) ...[  
                  const SizedBox(height: 16),
                  _buildResultItem('음색', _timbreResult!.voiceType),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // 완료 버튼
          ElevatedButton(
            onPressed: widget.onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              '완료',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
  
  Widget _buildResultItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white70,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
  
  String _getGrade() {
    if (_accuracy >= 90) return 'A+';
    if (_accuracy >= 80) return 'A';
    if (_accuracy >= 70) return 'B';
    if (_accuracy >= 60) return 'C';
    return 'D';
  }
  
  Color _getPitchAccuracyColor(double frequency) {
    // 목표 주파수 범위 (A3 ~ A5)
    if (frequency >= 220 && frequency <= 880) {
      if (frequency >= 430 && frequency <= 450) {
        return const Color(0xFF4CAF50); // 정확함 (A4 근처)
      }
      return const Color(0xFFFFC107); // 범위 내
    }
    return const Color(0xFFFF5252); // 범위 밖
  }
  
  String _getPitchGuidance(double frequency) {
    if (frequency < 220) return '⬆️ 더 높게';
    if (frequency > 880) return '⬇️ 더 낮게';
    if (frequency >= 430 && frequency <= 450) return '✅ 완벽해요!';
    if (frequency < 430) return '↗️ 조금 더 높게';
    return '↘️ 조금 더 낮게';
  }
  
  Widget _buildTimbreBar(String label, double value) {
    final percentage = (value * 100).toInt();
    Color barColor;
    
    if (label == '긴장도') {
      barColor = value > 0.6 ? PitchColors.off : value > 0.3 ? PitchColors.close : PitchColors.perfect;
    } else if (label == '숨소리') {
      barColor = value > 0.6 ? PitchColors.warning : PitchColors.neutral;
    } else {
      barColor = PitchColors.fromAccuracy(value);
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$percentage%',
            style: TextStyle(
              color: barColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getShortTimbreLabel(TimbreResult result) {
    if (result.breathiness > 0.6) return '허스키';
    if (result.brightness > 0.7) return '맑음';
    if (result.warmth > 0.7) return '따뜻함';
    if (result.tension > 0.6) return '긴장';
    if (result.brightness < 0.3) return '깊음';
    return '균형';
  }
  
  Color _getTimbreColor(TimbreResult result) {
    if (result.tension > 0.6) return PitchColors.warning;
    if (result.breathiness > 0.6) return PitchColors.close;
    if (result.brightness > 0.7 || result.warmth > 0.7) return PitchColors.perfect;
    return PitchColors.neutral;
  }
  
  String _getNoteName(double frequency) {
    // 주파수를 음이름으로 변환
    final notes = [
      {'freq': 220, 'note': 'A3'},
      {'freq': 247, 'note': 'B3'},
      {'freq': 262, 'note': 'C4'},
      {'freq': 294, 'note': 'D4'},
      {'freq': 330, 'note': 'E4'},
      {'freq': 349, 'note': 'F4'},
      {'freq': 392, 'note': 'G4'},
      {'freq': 440, 'note': 'A4'},
      {'freq': 494, 'note': 'B4'},
      {'freq': 523, 'note': 'C5'},
      {'freq': 587, 'note': 'D5'},
      {'freq': 659, 'note': 'E5'},
      {'freq': 698, 'note': 'F5'},
      {'freq': 784, 'note': 'G5'},
      {'freq': 880, 'note': 'A5'},
    ];
    
    // 가장 가까운 음 찾기
    var closestNote = notes[0];
    var minDiff = (frequency - (notes[0]['freq'] as num)).abs();
    
    for (final note in notes) {
      final diff = (frequency - (note['freq'] as num)).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestNote = note;
      }
    }
    
    return closestNote['note'] as String;
  }
}

// 피치 데이터 포인트
class PitchPoint {
  final double time;
  final double frequency;
  final double confidence;
  
  PitchPoint({
    required this.time,
    required this.frequency,
    required this.confidence,
  });
}

// 배경 웨이브폼 페인터
class _WaveformBackgroundPainter extends CustomPainter {
  final List<double> waveform;
  final Color color;
  
  _WaveformBackgroundPainter({
    required this.waveform,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;
    
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;
    
    for (int i = 0; i < waveform.length; i++) {
      final x = (i / waveform.length) * width;
      final y = centerY + (waveform[i] * height * 0.4);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(_WaveformBackgroundPainter oldDelegate) {
    return waveform != oldDelegate.waveform;
  }
}