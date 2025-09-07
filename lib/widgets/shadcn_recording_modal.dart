import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import '../design_system/tokens.dart';
import '../design_system/components/ui_button.dart';
import '../design_system/components/ui_card.dart';
import '../design_system/components/waveform_widget.dart';
import '../design_system/components/pitch_visualizer.dart';
import '../services/native_audio_service.dart';
import '../services/dual_engine_service.dart';
import '../services/realtime_pitch_stream.dart';
import '../widgets/session_report.dart';
import '../theme/pitch_colors.dart';

enum RecordingStep { 
  ready,      // 준비
  recording,  // 녹음 중
  analyzing,  // 분석 중 
  results,    // 결과
}

/// Shadcn UI 스타일의 새로운 녹음 플로우 모달
/// 
/// 4단계 플로우를 더 직관적이고 접근성 높은 디자인으로 개선
/// - 미니멀한 인터페이스
/// - 명확한 상태 표시
/// - 부드러운 전환 애니메이션
class ShadcnRecordingModal extends StatefulWidget {
  final VoidCallback onClose;
  
  const ShadcnRecordingModal({
    super.key,
    required this.onClose,
  });
  
  @override
  State<ShadcnRecordingModal> createState() => _ShadcnRecordingModalState();
}

class _ShadcnRecordingModalState extends State<ShadcnRecordingModal>
    with TickerProviderStateMixin {
  
  // 상태 관리
  RecordingStep _currentStep = RecordingStep.ready;
  bool _isRecording = false;
  double _recordingTime = 0.0;
  List<double> _audioData = [];
  List<double> _realtimeWaveform = [];
  
  // 피치 분석 결과
  double _currentPitch = 0.0;
  double _targetPitch = 440.0; // A4
  double _confidence = 0.0;
  double _averageAccuracy = 0.0;
  
  // 서비스
  final NativeAudioService _audioService = NativeAudioService.instance;
  final DualEngineService _engineService = DualEngineService();
  
  // 애니메이션
  late AnimationController _stepController;
  late AnimationController _recordingController;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  // 타이머
  Timer? _recordingTimer;
  Timer? _waveformTimer;
  RealtimePitchStream? _rtStream;
  StreamSubscription<RealtimePitchEvent>? _rtSub;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAudio();
  }
  
  void _initializeAnimations() {
    // 단계 전환 애니메이션
    _stepController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _stepController,
      curve: Curves.easeInOut,
    ));
    
    // 녹음 버튼 애니메이션
    _recordingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _recordingController,
      curve: Curves.easeInOut,
    ));
  }
  
  void _initializeAudio() async {
    await _audioService.initialize();
    
    _audioService.onAudioLevelChanged = (level) {
      if (mounted && _isRecording) {
        setState(() {
          _realtimeWaveform.add(level);
          if (_realtimeWaveform.length > 100) {
            _realtimeWaveform.removeAt(0);
          }
        });
      }
    };
  }
  
  @override
  void dispose() {
    _rtSub?.cancel();
    _rtStream?.stop();
    _recordingTimer?.cancel();
    _waveformTimer?.cancel();
    _stepController.dispose();
    _recordingController.dispose();
    
    // 안전한 오디오 정리
    if (_isRecording) {
      _audioService.stopRecording().catchError((_) {});
    }
    
    super.dispose();
  }
  
  // 녹음 시작
  void _startRecording() async {
    HapticFeedback.mediumImpact();
    
    try {
      await _audioService.startRecording();
      
      setState(() {
        _currentStep = RecordingStep.recording;
        _isRecording = true;
        _recordingTime = 0.0;
        _realtimeWaveform.clear();
      });
      
      _recordingController.repeat(reverse: true);
      _stepController.forward();
      
      // 실시간 피치 스트림 시작 (가능 시)
      try {
        final recorded = await _audioService.getRecordedAudio();
        if (recorded != null && recorded.isNotEmpty) {
          _rtStream = RealtimePitchStream();
          _rtSub = _rtStream!.stream.listen((ev) {
            if (!mounted || !_isRecording) return;
            setState(() {
              _currentPitch = ev.frequency;
              _confidence = ev.confidence;
              _recordingTime = ev.timeSec;
              _averageAccuracy = _calculateAccuracy(ev.frequency);
            });
          });
          unawaited(_rtStream!.start(Float32List.fromList(recorded), sampleRate: 48000.0));
        }
      } catch (_) {}
      
    } catch (e) {
      print('녹음 시작 실패: $e');
    }
  }
  
  // 녹음 중지
  void _stopRecording() async {
    _recordingTimer?.cancel();
    _recordingController.stop();
    _rtSub?.cancel();
    _rtStream?.stop();
    
    try {
      await _audioService.stopRecording();
      
      final audioData = await _audioService.getRecordedAudioData();
      
      setState(() {
        _isRecording = false;
        _currentStep = RecordingStep.analyzing;
        _audioData = audioData ?? [];
      });
      
      // 분석 시작
      _analyzeAudio();
      
    } catch (e) {
      print('녹음 중지 실패: $e');
    }
  }
  
  // 오디오 분석
  void _analyzeAudio() async {
    if (_audioData.isEmpty) {
      _showResults();
      return;
    }
    
    try {
      // CREPE/SPICE 분석
      final results = await _engineService.analyzeTimeBasedPitch(
        _audioData,
        useHMM: true,
      );
      
      if (results.isNotEmpty) {
        // 분석 결과 처리
        final validResults = results.where((r) => r.confidence > 0.5).toList();
        
        if (validResults.isNotEmpty) {
          final avgPitch = validResults
              .map((r) => r.frequency)
              .reduce((a, b) => a + b) / validResults.length;
          
          final avgConfidence = validResults
              .map((r) => r.confidence)
              .reduce((a, b) => a + b) / validResults.length;
          
          setState(() {
            _currentPitch = avgPitch;
            _confidence = avgConfidence;
            _averageAccuracy = _calculateAccuracy(avgPitch);
          });
        }
      }
      
      // 2초 후 결과 표시
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _showResults();
        }
      });
      
    } catch (e) {
      print('분석 실패: $e');
      _showResults();
    }
  }
  
  // 결과 표시
  void _showResults() {
    setState(() {
      _currentStep = RecordingStep.results;
    });
  }
  
  // 정확도 계산
  double _calculateAccuracy(double pitch) {
    if (pitch <= 0) return 0.0;
    
    final diff = (pitch - _targetPitch).abs();
    const maxDiff = 50.0;
    
    return (1.0 - (diff / maxDiff)).clamp(0.0, 1.0);
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: DesignTokens.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radius2xl),
        ),
      ),
      child: Column(
        children: [
          // 핸들
          _buildHandle(),
          
          // 헤더
          _buildHeader(),
          
          // 단계 인디케이터
          _buildStepIndicator(),
          
          // 메인 컨텐츠
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentStepContent(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: DesignTokens.space3),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: DesignTokens.muted,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.space6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _getStepTitle(),
            style: DesignTokens.h3.copyWith(
              color: DesignTokens.foreground,
            ),
          ),
          UIButton(
            icon: const Icon(Icons.close, size: 20),
            variant: ButtonVariant.ghost,
            size: ButtonSize.icon,
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DesignTokens.space6),
      child: Row(
        children: [
          for (int i = 0; i < RecordingStep.values.length; i++) ...[
            Expanded(
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: i <= _currentStep.index
                      ? DesignTokens.primary
                      : DesignTokens.muted,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            if (i < RecordingStep.values.length - 1)
              const SizedBox(width: DesignTokens.space2),
          ],
        ],
      ),
    );
  }
  
  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case RecordingStep.ready:
        return _buildReadyStep();
      case RecordingStep.recording:
        return _buildRecordingStep();
      case RecordingStep.analyzing:
        return _buildAnalyzingStep();
      case RecordingStep.results:
        return _buildResultsStep();
    }
  }
  
  Widget _buildReadyStep() {
    return Container(
      key: const ValueKey('ready'),
      padding: const EdgeInsets.all(DesignTokens.space6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_outlined,
            size: 80,
            color: DesignTokens.mutedForeground,
          ),
          
          const SizedBox(height: DesignTokens.space6),
          
          Text(
            'Ready to Record',
            style: DesignTokens.h2.copyWith(
              color: DesignTokens.foreground,
            ),
          ),
          
          const SizedBox(height: DesignTokens.space2),
          
          Text(
            'Sing or hum a note for pitch analysis',
            style: DesignTokens.body.copyWith(
              color: DesignTokens.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: DesignTokens.space8),
          
          UIButton(
            text: 'Start Recording',
            variant: ButtonVariant.recording,
            size: ButtonSize.lg,
            fullWidth: true,
            onPressed: _startRecording,
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecordingStep() {
    return Container(
      key: const ValueKey('recording'),
      padding: const EdgeInsets.all(DesignTokens.space6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 녹음 버튼
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: VocalTrainingTheme.recording,
                    boxShadow: [
                      BoxShadow(
                        color: VocalTrainingTheme.recording.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: DesignTokens.space6),
          
          // 녹음 시간
          Text(
            '${_recordingTime.toStringAsFixed(1)}s',
            style: DesignTokens.h1.copyWith(
              color: DesignTokens.foreground,
            ),
          ),
          
          const SizedBox(height: DesignTokens.space4),
          
          // 실시간 웨이브폼
          if (_realtimeWaveform.isNotEmpty)
            SizedBox(
              height: 60,
              child: WaveformWidget(
                audioData: _realtimeWaveform,
                style: WaveformStyle.bars,
                primaryColor: VocalTrainingTheme.recording,
                isRecording: true,
              ),
            ),
          
          const SizedBox(height: DesignTokens.space8),
          
          UIButton(
            text: 'Stop Recording',
            variant: ButtonVariant.outline,
            size: ButtonSize.lg,
            fullWidth: true,
            onPressed: _stopRecording,
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnalyzingStep() {
    return Container(
      key: const ValueKey('analyzing'),
      padding: const EdgeInsets.all(DesignTokens.space6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 분석 아이콘
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VocalTrainingTheme.analyzing.withOpacity(0.1),
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 40,
              color: VocalTrainingTheme.analyzing,
            ),
          ),
          
          const SizedBox(height: DesignTokens.space6),
          
          Text(
            'Analyzing...',
            style: DesignTokens.h2.copyWith(
              color: DesignTokens.foreground,
            ),
          ),
          
          const SizedBox(height: DesignTokens.space2),
          
          Text(
            'AI engines are processing your voice',
            style: DesignTokens.body.copyWith(
              color: DesignTokens.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: DesignTokens.space8),
          
          // 진행률 표시
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: DesignTokens.muted,
              borderRadius: BorderRadius.circular(2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  VocalTrainingTheme.analyzing,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultsStep() {
    return Container(
      key: const ValueKey('results'),
      padding: const EdgeInsets.all(DesignTokens.space6),
      child: Column(
        children: [
          // 피치 시각화
          if (_currentPitch > 0) ...[
            PitchVisualizer(
              currentPitch: _currentPitch,
              targetPitch: _targetPitch,
              confidence: _confidence,
              isActive: true,
            ),
            
            const SizedBox(height: DesignTokens.space6),
          ],
          
          // 결과 카드들
          Row(
            children: [
              Expanded(
                child: UICard.analysis(
                  title: 'FREQUENCY',
                  value: '${_currentPitch.toStringAsFixed(1)} Hz',
                  subtitle: _getNoteName(_currentPitch),
                  color: DesignTokens.info,
                ),
              ),
              const SizedBox(width: DesignTokens.space4),
              Expanded(
                child: UICard.analysis(
                  title: 'ACCURACY',
                  value: '${(_averageAccuracy * 100).toStringAsFixed(0)}%',
                  subtitle: _getAccuracyLabel(_averageAccuracy),
                  color: DesignTokens.pitchAccuracyColor(_averageAccuracy),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: DesignTokens.space6),

          // 세션 요약 리포트
          if (_pitchData.isNotEmpty) ...[
            SessionReport(frames: _pitchData),
            const SizedBox(height: DesignTokens.space6),
          ],
          
          // 액션 버튼들
          UIButton(
            text: 'Record Again',
            variant: ButtonVariant.outline,
            size: ButtonSize.lg,
            fullWidth: true,
            onPressed: () {
              setState(() {
                _currentStep = RecordingStep.ready;
                _recordingTime = 0.0;
                _audioData.clear();
                _realtimeWaveform.clear();
                _currentPitch = 0.0;
                _confidence = 0.0;
                _averageAccuracy = 0.0;
              });
            },
          ),
          
          const SizedBox(height: DesignTokens.space4),
          
          UIButton(
            text: 'Done',
            variant: ButtonVariant.primary,
            size: ButtonSize.lg,
            fullWidth: true,
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }
  
  String _getStepTitle() {
    switch (_currentStep) {
      case RecordingStep.ready:
        return 'Voice Analysis';
      case RecordingStep.recording:
        return 'Recording...';
      case RecordingStep.analyzing:
        return 'Processing';
      case RecordingStep.results:
        return 'Results';
    }
  }
  
  String _getNoteName(double frequency) {
    if (frequency <= 0) return 'Unknown';
    
    const double a4 = 440.0;
    final double semitones = 12 * math.log(frequency / a4) / math.ln2;
    final int noteIndex = (semitones.round() + 9) % 12;
    final int octave = 4 + ((semitones.round() + 9) ~/ 12);
    
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    return '${notes[noteIndex]}$octave';
  }
  
  String _getAccuracyLabel(double accuracy) {
    if (accuracy >= 0.95) return 'Perfect';
    if (accuracy >= 0.85) return 'Excellent';
    if (accuracy >= 0.70) return 'Good';
    if (accuracy >= 0.50) return 'Fair';
    return 'Needs work';
  }
}
