import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../services/native_audio_service.dart';
import '../../services/dual_engine_service.dart';
import '../../services/bach_temperament_service.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';
import '../tokens/spacing.dart';
import '../tokens/animations.dart';
import '../components/vj_button.dart';
import '../components/vj_card.dart';
import '../components/vj_wave_visualizer.dart';
import '../components/vj_pitch_graph.dart';
import '../components/vj_progress_ring.dart';
import 'vj_analysis_result.dart';

enum RecordingStep {
  prepare,
  recording,
  analyzing,
  results,
}

class VJRecordingFlow extends StatefulWidget {
  const VJRecordingFlow({Key? key}) : super(key: key);

  @override
  State<VJRecordingFlow> createState() => _VJRecordingFlowState();
}

class _VJRecordingFlowState extends State<VJRecordingFlow>
    with TickerProviderStateMixin {
  RecordingStep _currentStep = RecordingStep.prepare;
  
  // Services
  final _audioService = NativeAudioService.instance;
  final _dualEngineService = DualEngineService();
  
  // Recording state
  bool _isRecording = false;
  double _recordingTime = 0.0;
  Timer? _recordingTimer;
  List<double> _audioLevels = [];
  List<double>? _recordedAudioData;
  bool _isTestMode = false; // MP3 테스트 모드
  
  // Analysis state
  List<PitchPoint> _pitchData = [];
  double _averageAccuracy = 0.0;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeAudio();
    // Start the flow automatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPreparation();
    });
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _initializeAudio() async {
    // Request microphone permissions if needed
    // Audio service is already initialized
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _startPreparation() {
    setState(() {
      _currentStep = RecordingStep.prepare;
    });
    
    // Don't auto-advance - wait for user to tap the record button
    // User should manually start recording
  }

  void _startRecording() async {
    HapticFeedback.lightImpact();
    
    setState(() {
      _currentStep = RecordingStep.recording;
      _isRecording = true;
      _recordingTime = 0.0;
      _audioLevels.clear();
    });
    
    _pulseController.repeat(reverse: true);
    
    // Start real recording using correct method name
    final success = await _audioService.startRecording();
    if (!success) {
      print('❌ Failed to start recording');
      return;
    }
    
    print('✅ Recording started successfully');
    
    // Start timer and get real audio levels
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      final level = await _audioService.getCurrentAudioLevel();
      
      setState(() {
        _recordingTime += 0.1;
        // Use real audio level
        _audioLevels.add(level.clamp(0.0, 1.0));
        if (_audioLevels.length > 50) {
          _audioLevels.removeAt(0);
        }
      });
    });
  }

  void _stopRecording() async {
    HapticFeedback.mediumImpact();
    
    _recordingTimer?.cancel();
    _pulseController.stop();
    
    setState(() {
      _isRecording = false;
      _currentStep = RecordingStep.analyzing;
    });
    
    // Stop real recording and get audio data using correct method names
    await _audioService.stopRecording();
    final audioData = await _audioService.getRecordedAudioData();
    
    if (audioData != null && audioData.isNotEmpty) {
      print('📊 Got audio data: ${audioData.length} samples');
      
      // 오디오 데이터 통계 확인
      final maxAmplitude = audioData.reduce((a, b) => a.abs() > b.abs() ? a : b);
      final avgAmplitude = audioData.map((x) => x.abs()).reduce((a, b) => a + b) / audioData.length;
      print('🎤 오디오 통계: 최대 진폭=${maxAmplitude.toStringAsFixed(4)}, 평균 진폭=${avgAmplitude.toStringAsFixed(4)}');
      print('🎤 첫 100개 샘플: ${audioData.take(100).map((x) => x.toStringAsFixed(3)).join(", ")}');
      
      setState(() {
        _recordedAudioData = audioData;
      });
      
      _progressController.forward();
      await _analyzeAudio(audioData);
    } else {
      print('❌ No audio data recorded');
      // Go back to prepare step
      setState(() {
        _currentStep = RecordingStep.prepare;
      });
    }
  }

  Future<void> _analyzeAudio(List<double> audioData) async {
    print('🎯 Starting audio analysis with ${audioData.length} samples');
    
    // Convert to Float32List for analysis
    final float32Data = Float32List.fromList(audioData);
    
    try {
      // Start progress animation
      _progressController.forward();
      
      // Analyze with CREPE/SPICE
      print('🎵 Calling CREPE/SPICE analysis...');
      final results = await _dualEngineService.analyzeTimeBasedPitch(
        float32Data,
        windowSize: 4096,   // Smaller window for faster processing
        hopSize: 2048,      // 50% overlap
        sampleRate: 48000.0,
        useHMM: true,
      );
      
      print('✅ Got ${results.length} pitch results from AI');
      
      if (results.isEmpty) {
        print('⚠️ No pitch data returned from analysis');
        // Fallback to prepare step with error message
        setState(() {
          _currentStep = RecordingStep.prepare;
        });
        return;
      }
      
      // Convert to PitchPoint format
      final pitchPoints = results.map((result) {
        // 디버깅: 각 결과 로그
        print('🎵 피치 포인트: ${result.frequency.toStringAsFixed(1)}Hz at ${result.timeSeconds?.toStringAsFixed(2)}s (신뢰도: ${(result.confidence * 100).toInt()}%)');
        return PitchPoint(
          time: result.timeSeconds ?? 0.0,
          frequency: result.frequency,
          confidence: result.confidence,
          note: _frequencyToNote(result.frequency),
        );
      }).toList();
      
      // Calculate average accuracy (simplified)
      final avgConfidence = pitchPoints.isEmpty 
          ? 0.0 
          : pitchPoints.map((p) => p.confidence).reduce((a, b) => a + b) / pitchPoints.length;
      
      print('📊 Analysis complete: ${pitchPoints.length} points, avg confidence: ${(avgConfidence * 100).toInt()}%');
      
      setState(() {
        _pitchData = pitchPoints;
        _averageAccuracy = avgConfidence;
        _currentStep = RecordingStep.results;
      });
      
    } catch (e) {
      print('❌ Analysis error: $e');
      // Fallback to prepare step on error
      setState(() {
        _currentStep = RecordingStep.prepare;
      });
    }
  }

  String _frequencyToNote(double frequency) {
    // Use Bach Temperament Service for accurate note conversion
    if (frequency < 50) return '';
    
    final note = BachTemperamentService.frequencyToTemperamentNote(frequency);
    return '${note.noteName}${note.octave}'; // Returns like "C4", "D#4", etc.
  }

  void _retry() {
    setState(() {
      _currentStep = RecordingStep.prepare;
      _recordingTime = 0.0;
      _audioLevels.clear();
      _recordedAudioData = null;
      _pitchData.clear();
      _averageAccuracy = 0.0;
    });
    
    _progressController.reset();
    _startPreparation();
  }

  void _viewDetails() {
    Navigator.push(
      context,
      VJAnimations.slideUpRoute(
        VJAnalysisResult(
          pitchData: _pitchData,
          audioData: _recordedAudioData ?? [],
          accuracy: _averageAccuracy,
          duration: _recordingTime,
        ),
      ),
    );
  }

  Future<void> _loadTestMP3() async {
    print('🎵 MP3 파일 로드 시작...');
    try {
      // 파일 선택
      print('📂 파일 선택 다이얼로그 오픈 시도...');
      FilePickerResult? pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,  // audio 대신 custom 사용
        allowedExtensions: ['mp3', 'wav', 'm4a'],
        allowMultiple: false,
      );
      
      print('📂 파일 선택 결과: ${pickerResult != null ? "선택됨" : "취소됨"}');

      if (pickerResult != null && pickerResult.files.single.path != null) {
        final filePath = pickerResult.files.single.path!;
        print('🎵 선택된 MP3 파일: $filePath');
        
        // 테스트 모드 활성화
        setState(() {
          _isTestMode = true;
          _currentStep = RecordingStep.analyzing;
        });
        
        // MP3 파일 로드 및 분석
        _progressController.forward();
        
        // Native에서 MP3 파일 로드
        final audioResult = await _audioService.loadAudioFile(filePath);
        
        if (audioResult != null && audioResult['samples'] != null) {
          final audioData = List<double>.from(audioResult['samples']);
          print('📊 MP3 데이터 로드 성공: ${audioData.length} 샘플');
          setState(() {
            _recordedAudioData = audioData;
            _recordingTime = audioData.length / 48000.0; // 48kHz 기준
          });
          
          // 바로 분석 시작
          await _analyzeAudio(audioData);
        } else {
          print('❌ MP3 데이터 로드 실패');
          setState(() {
            _currentStep = RecordingStep.prepare;
            _isTestMode = false;
          });
        }
      }
    } catch (e) {
      print('❌ MP3 로드 오류: $e');
      setState(() {
        _currentStep = RecordingStep.prepare;
        _isTestMode = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VJColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: VJColors.gray700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Voice Training',
          style: VJTypography.titleLarge.copyWith(
            color: VJColors.gray900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(VJSpacing.screenPadding),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentStep) {
      case RecordingStep.prepare:
        return _buildPrepareStep();
      case RecordingStep.recording:
        return _buildRecordingStep();
      case RecordingStep.analyzing:
        return _buildAnalyzingStep();
      case RecordingStep.results:
        return _buildResultsStep();
    }
  }

  Widget _buildPrepareStep() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          Icon(
            Icons.mic_none,
            size: 80,
            color: VJColors.gray400,
          ),
          SizedBox(height: VJSpacing.xl),
          Text(
            'Get Ready',
            style: VJTypography.headlineLarge.copyWith(
              color: VJColors.gray900,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: VJSpacing.md),
          Text(
            'Take a deep breath and prepare your voice',
            style: VJTypography.bodyLarge.copyWith(
              color: VJColors.gray500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: VJSpacing.xxxl),
          Container(
            padding: EdgeInsets.all(VJSpacing.lg),
            decoration: BoxDecoration(
              color: VJColors.primaryLight.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.headphones,
              size: 48,
              color: VJColors.primary,
            ),
          ),
          SizedBox(height: VJSpacing.lg),
          Text(
            'Use headphones for best results',
            style: VJTypography.labelMedium.copyWith(
              color: VJColors.gray500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: VJSpacing.xxxl),
          // Start Recording Button
          GestureDetector(
            onTap: _startRecording,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VJColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: VJColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.mic,
                  size: 48,
                  color: VJColors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: VJSpacing.lg),
          Text(
            'Tap to start recording',
            style: VJTypography.labelMedium.copyWith(
              color: VJColors.primary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: VJSpacing.xl),
          // Test Mode Button
          TextButton.icon(
            onPressed: _loadTestMP3,
            icon: Icon(Icons.music_note, color: VJColors.secondary),
            label: Text(
              'Use Test MP3 File',
              style: VJTypography.labelMedium.copyWith(
                color: VJColors.secondary,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildRecordingStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Timer
        Text(
          '${_recordingTime.toStringAsFixed(1)}s',
          style: VJTypography.number.copyWith(
            color: VJColors.gray900,
          ),
        ),
        SizedBox(height: VJSpacing.xl),
        
        // Waveform visualization
        if (_audioLevels.isNotEmpty)
          Container(
            height: 100,
            child: VJWaveVisualizer(
              audioData: _audioLevels,
              style: WaveStyle.bars,
              color: VJColors.primary,
              animate: true,
              isPlaying: _isRecording,
            ),
          ),
        
        SizedBox(height: VJSpacing.xxxl),
        
        // Recording button
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: GestureDetector(
                onTap: _isRecording ? _stopRecording : null,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: VJColors.error,
                    boxShadow: [
                      BoxShadow(
                        color: VJColors.error.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: VJColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        
        SizedBox(height: VJSpacing.lg),
        Text(
          'Tap to stop',
          style: VJTypography.labelMedium.copyWith(
            color: VJColors.gray500,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzingStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        VJProgressRing(
          progress: _progressAnimation.value,
          size: 120,
          animate: true,
          child: Icon(
            Icons.analytics_outlined,
            size: 48,
            color: VJColors.primary,
          ),
        ),
        SizedBox(height: VJSpacing.xl),
        Text(
          'Analyzing Your Voice',
          style: VJTypography.headlineMedium.copyWith(
            color: VJColors.gray900,
          ),
        ),
        SizedBox(height: VJSpacing.md),
        Text(
          'AI is processing your vocal patterns...',
          style: VJTypography.bodyLarge.copyWith(
            color: VJColors.gray500,
          ),
        ),
      ],
    );
  }

  Widget _buildResultsStep() {
    final grade = _getGrade(_averageAccuracy);
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // Grade circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _getGradeGradient(grade),
              boxShadow: [
                BoxShadow(
                  color: _getGradeColor(grade).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Text(
                grade,
                style: VJTypography.displayLarge.copyWith(
                  color: VJColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          
          SizedBox(height: VJSpacing.lg),
          
          Text(
            _getGradeMessage(grade),
            style: VJTypography.headlineMedium.copyWith(
              color: VJColors.gray900,
            ),
          ),
          
          SizedBox(height: VJSpacing.md),
          
          Text(
            'Accuracy: ${(_averageAccuracy * 100).toInt()}%',
            style: VJTypography.bodyLarge.copyWith(
              color: VJColors.gray500,
            ),
          ),
          
          SizedBox(height: VJSpacing.xl),
          
          // Pitch graph preview
          if (_pitchData.isNotEmpty)
            VJCard(
              type: VJCardType.elevated,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pitch Analysis',
                    style: VJTypography.titleMedium.copyWith(
                      color: VJColors.gray900,
                    ),
                  ),
                  SizedBox(height: VJSpacing.md),
                  VJPitchGraph(
                    pitchData: _pitchData,
                    height: 150,
                    showGuides: false,
                    animateEntry: true,
                  ),
                ],
              ),
            ),
          
          SizedBox(height: VJSpacing.xl),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: VJButton(
                  text: 'Try Again',
                  type: VJButtonType.ghost,
                  onPressed: _retry,
                ),
              ),
              SizedBox(width: VJSpacing.md),
              Expanded(
                child: VJButton(
                  text: 'View Details',
                  type: VJButtonType.primary,
                  onPressed: _viewDetails,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getGrade(double accuracy) {
    if (accuracy >= 0.95) return 'A+';
    if (accuracy >= 0.90) return 'A';
    if (accuracy >= 0.85) return 'B+';
    if (accuracy >= 0.80) return 'B';
    if (accuracy >= 0.75) return 'C+';
    if (accuracy >= 0.70) return 'C';
    return 'D';
  }

  String _getGradeMessage(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return 'Excellent!';
      case 'B+':
      case 'B':
        return 'Great Job!';
      case 'C+':
      case 'C':
        return 'Good Progress!';
      default:
        return 'Keep Practicing!';
    }
  }

  Color _getGradeColor(String grade) {
    if (grade.startsWith('A')) return VJColors.success;
    if (grade.startsWith('B')) return VJColors.secondary;
    if (grade.startsWith('C')) return VJColors.warning;
    return VJColors.error;
  }

  LinearGradient _getGradeGradient(String grade) {
    if (grade.startsWith('A')) {
      return LinearGradient(
        colors: [VJColors.success, VJColors.secondary],
      );
    }
    if (grade.startsWith('B')) {
      return LinearGradient(
        colors: [VJColors.secondary, VJColors.accent],
      );
    }
    return VJColors.primaryGradient;
  }
}
