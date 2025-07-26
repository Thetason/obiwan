import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import '../../domain/entities/audio_data.dart';
import '../../domain/entities/vocal_analysis.dart';
import '../../domain/usecases/analyze_vocal_quality.dart';
import '../../data/repositories/audio_analysis_repository_impl.dart';
import '../../features/audio_analysis/audio_capture_service_simple.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../features/audio_analysis/web_audio_capture_service.dart';
import '../../features/audio_analysis/audio_capture_service_interface.dart';
import '../../features/ai_analysis/transformer_audio_analyzer.dart';
import '../../features/ai_coaching/generative_coaching_engine.dart';
import '../../features/emotion_style/emotion_style_recognizer.dart';
import '../../features/audio_enhancement/real_time_audio_enhancer.dart';
import '../../features/acoustic_analysis/high_precision_analyzer.dart';
import '../../features/audio_analysis/pitch_correction_engine.dart';

// Enhanced Audio Analysis State with AI Features
class AudioAnalysisState {
  final AudioData? audioData;
  final VocalAnalysis? analysis;
  final List<VocalAnalysis> analysisResults;
  final List<double> pitchData;
  final List<double> waveformData;
  final bool isAnalyzing;
  final bool isRecording;
  final String? error;
  final double recordingLevel;
  
  // AI Analysis Results
  final MultiTaskAnalysisResult? aiAnalysis;
  final EmotionStyleResult? emotionStyleResult;
  final CoachingResponse? coachingAdvice;
  final AcousticAnalysisResult? acousticAnalysis;
  final List<double>? enhancedAudio;
  
  // Real-time AI metrics
  final String currentNote;
  final double pitchAccuracy;
  final double cents;
  final String emotion;
  final String style;
  final double voiceQuality;
  final List<String> realtimeCoaching;
  
  // Pitch correction
  final bool isPitchCorrectionEnabled;
  final PitchCorrectionConfig pitchCorrectionConfig;
  final Float32List? correctedAudio;
  
  const AudioAnalysisState({
    this.audioData,
    this.analysis,
    this.analysisResults = const [],
    this.pitchData = const [],
    this.waveformData = const [],
    this.isAnalyzing = false,
    this.isRecording = false,
    this.error,
    this.recordingLevel = 0.0,
    
    // AI Features
    this.aiAnalysis,
    this.emotionStyleResult,
    this.coachingAdvice,
    this.acousticAnalysis,
    this.enhancedAudio,
    
    // Real-time metrics
    this.currentNote = '',
    this.pitchAccuracy = 0.0,
    this.cents = 0.0,
    this.emotion = 'Neutral',
    this.style = 'Unknown',
    this.voiceQuality = 0.0,
    this.realtimeCoaching = const [],
    
    // Pitch correction
    this.isPitchCorrectionEnabled = false,
    this.pitchCorrectionConfig = const PitchCorrectionConfig(),
    this.correctedAudio,
  });
  
  AudioAnalysisState copyWith({
    AudioData? audioData,
    VocalAnalysis? analysis,
    List<VocalAnalysis>? analysisResults,
    List<double>? pitchData,
    List<double>? waveformData,
    bool? isAnalyzing,
    bool? isRecording,
    String? error,
    double? recordingLevel,
    
    // AI Features
    MultiTaskAnalysisResult? aiAnalysis,
    EmotionStyleResult? emotionStyleResult,
    CoachingResponse? coachingAdvice,
    AcousticAnalysisResult? acousticAnalysis,
    List<double>? enhancedAudio,
    
    // Real-time metrics
    String? currentNote,
    double? pitchAccuracy,
    double? cents,
    String? emotion,
    String? style,
    double? voiceQuality,
    List<String>? realtimeCoaching,
    
    // Pitch correction
    bool? isPitchCorrectionEnabled,
    PitchCorrectionConfig? pitchCorrectionConfig,
    Float32List? correctedAudio,
  }) {
    return AudioAnalysisState(
      audioData: audioData ?? this.audioData,
      analysis: analysis ?? this.analysis,
      analysisResults: analysisResults ?? this.analysisResults,
      pitchData: pitchData ?? this.pitchData,
      waveformData: waveformData ?? this.waveformData,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isRecording: isRecording ?? this.isRecording,
      error: error ?? this.error,
      recordingLevel: recordingLevel ?? this.recordingLevel,
      
      // AI Features
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      emotionStyleResult: emotionStyleResult ?? this.emotionStyleResult,
      coachingAdvice: coachingAdvice ?? this.coachingAdvice,
      acousticAnalysis: acousticAnalysis ?? this.acousticAnalysis,
      enhancedAudio: enhancedAudio ?? this.enhancedAudio,
      
      // Real-time metrics
      currentNote: currentNote ?? this.currentNote,
      pitchAccuracy: pitchAccuracy ?? this.pitchAccuracy,
      cents: cents ?? this.cents,
      emotion: emotion ?? this.emotion,
      style: style ?? this.style,
      voiceQuality: voiceQuality ?? this.voiceQuality,
      realtimeCoaching: realtimeCoaching ?? this.realtimeCoaching,
      
      // Pitch correction
      isPitchCorrectionEnabled: isPitchCorrectionEnabled ?? this.isPitchCorrectionEnabled,
      pitchCorrectionConfig: pitchCorrectionConfig ?? this.pitchCorrectionConfig,
      correctedAudio: correctedAudio ?? this.correctedAudio,
    );
  }
}

// Enhanced Audio Analysis Controller with AI Features
class AudioAnalysisController extends StateNotifier<AudioAnalysisState> {
  final AnalyzeVocalQuality _analyzeVocalQuality;
  final AudioCaptureServiceInterface _audioCaptureService;
  
  // AI Analysis Engines
  final TransformerAudioAnalyzer _transformerAnalyzer;
  final GenerativeCoachingEngine _coachingEngine;
  final EmotionStyleRecognizer _emotionStyleRecognizer;
  final RealTimeAudioEnhancer _audioEnhancer;
  final HighPrecisionAcousticAnalyzer _acousticAnalyzer;
  final PitchCorrectionEngine _pitchCorrectionEngine;
  
  StreamSubscription? _audioStreamSubscription;
  Timer? _analysisTimer;
  Timer? _realtimeTimer;
  final List<double> _audioBuffer = [];
  static const int _bufferSize = 48000; // 3초 * 16kHz
  
  // User profile for personalized coaching
  final UserProfile _userProfile = UserProfile(
    name: 'User',
    experience: 'Intermediate',
    goal: 'Improve vocal technique',
    preferredGenre: 'Pop',
    sessionCount: 1,
  );
  
  final List<String> _conversationHistory = [];
  
  AudioAnalysisController(
    this._analyzeVocalQuality, 
    this._audioCaptureService,
    this._transformerAnalyzer,
    this._coachingEngine,
    this._emotionStyleRecognizer,
    this._audioEnhancer,
    this._acousticAnalyzer,
    this._pitchCorrectionEngine,
  ) : super(const AudioAnalysisState());
  
  // 새로운 메서드들 추가
  Future<void> startAnalysis() async {
    await startRecording();
  }
  
  Future<void> stopAnalysis() async {
    await stopRecording();
  }
  
  Future<void> startRecording() async {
    if (state.isRecording) return;
    
    try {
      await _audioCaptureService.initialize();
      
      state = state.copyWith(isRecording: true, error: null);
      
      // 오디오 스트림 구독
      _audioStreamSubscription = _audioCaptureService.audioStream.listen(
        _onAudioData,
        onError: (error) {
          state = state.copyWith(
            isRecording: false,
            error: error.toString(),
          );
        },
      );
      
      await _audioCaptureService.startCapture();
      
      // 주기적 분석 시작 (1초마다)
      _analysisTimer = Timer.periodic(
        const Duration(seconds: 1), 
        (_) => _performAnalysis(),
      );
      
      // 실시간 AI 분석 (500ms마다)
      _realtimeTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _performRealtimeAIAnalysis(),
      );
      
    } catch (e) {
      String errorMessage = e.toString();
      
      // Provide user-friendly error messages
      if (errorMessage.contains('permission') || 
          errorMessage.contains('Permission') ||
          errorMessage.contains('denied')) {
        errorMessage = '마이크 권한이 필요합니다. 브라우저에서 마이크 접근을 허용해주세요.';
      } else if (errorMessage.contains('not found') || 
                 errorMessage.contains('webAudioCapture')) {
        errorMessage = '오디오 시스템을 초기화할 수 없습니다. 페이지를 새로고침해주세요.';
      } else if (errorMessage.contains('initialize')) {
        errorMessage = '오디오 시스템 초기화에 실패했습니다. 브라우저가 Web Audio API를 지원하는지 확인해주세요.';
      }
      
      state = state.copyWith(
        isRecording: false,
        error: errorMessage,
      );
    }
  }
  
  Future<void> stopRecording() async {
    if (!state.isRecording) return;
    
    await _audioCaptureService.stopCapture();
    await _audioStreamSubscription?.cancel();
    _analysisTimer?.cancel();
    _realtimeTimer?.cancel();
    
    state = state.copyWith(isRecording: false);
    
    // 최종 분석 수행
    if (_audioBuffer.isNotEmpty) {
      await _performFinalAnalysis();
    }
  }
  
  void _onAudioData(List<double> audioChunk) async {
    print('[DEBUG] _onAudioData called with chunk size: ${audioChunk.length}');
    
    // Real-time audio enhancement
    final enhancedChunk = await _audioEnhancer.processAudioRealTime(audioChunk);
    
    // Apply pitch correction if enabled
    Float32List? correctedChunk;
    if (state.isPitchCorrectionEnabled && enhancedChunk.isNotEmpty) {
      // Quick pitch detection for real-time correction
      final pitch = _quickPitchDetection(enhancedChunk);
      if (pitch > 0) {
        final float32Chunk = Float32List.fromList(enhancedChunk);
        correctedChunk = await _pitchCorrectionEngine.processPitchCorrection(
          float32Chunk,
          [pitch], // Single pitch value for real-time
        );
        
        // Add corrected audio to buffer
        _audioBuffer.addAll(correctedChunk);
      } else {
        _audioBuffer.addAll(enhancedChunk);
      }
    } else {
      // 오디오 버퍼에 추가 (enhanced audio)
      _audioBuffer.addAll(enhancedChunk);
    }
    
    // 버퍼 크기 제한
    if (_audioBuffer.length > _bufferSize) {
      _audioBuffer.removeRange(0, _audioBuffer.length - _bufferSize);
    }
    
    // 실시간 파형 데이터 업데이트
    _updateWaveformData(correctedChunk != null ? correctedChunk.toList() : enhancedChunk);
    
    // 음성 레벨 계산
    final level = _calculateAudioLevel(correctedChunk != null ? correctedChunk.toList() : enhancedChunk);
    
    state = state.copyWith(
      waveformData: List.from(_audioBuffer.take(1024)), // 시각화용
      recordingLevel: level,
      enhancedAudio: enhancedChunk,
      correctedAudio: correctedChunk,
    );
  }
  
  void _updateWaveformData(List<double> audioChunk) {
    // 파형 데이터 다운샘플링 (시각화용)
    const downsampleRate = 16; // 16:1 다운샘플링
    final downsampled = <double>[];
    
    for (int i = 0; i < audioChunk.length; i += downsampleRate) {
      double sum = 0;
      int count = 0;
      
      for (int j = i; j < i + downsampleRate && j < audioChunk.length; j++) {
        sum += audioChunk[j].abs();
        count++;
      }
      
      downsampled.add(count > 0 ? sum / count : 0);
    }
    
    final currentWaveform = List<double>.from(state.waveformData);
    currentWaveform.addAll(downsampled);
    
    // 파형 데이터 크기 제한 (1024 포인트)
    if (currentWaveform.length > 1024) {
      currentWaveform.removeRange(0, currentWaveform.length - 1024);
    }
    
    state = state.copyWith(waveformData: currentWaveform);
  }
  
  double _calculateAudioLevel(List<double> audioChunk) {
    if (audioChunk.isEmpty) return 0.0;
    
    double sum = 0;
    for (final sample in audioChunk) {
      sum += sample * sample;
    }
    
    final rms = math.sqrt(sum / audioChunk.length);
    return (rms * 100).clamp(0.0, 100.0);
  }
  
  Future<void> _performAnalysis() async {
    print('[DEBUG] _performAnalysis called, buffer size: ${_audioBuffer.length}');
    if (_audioBuffer.length < 16000) {
      print('[DEBUG] Buffer too small for analysis, skipping');
      return; // 최소 1초 오디오 필요
    }
    
    state = state.copyWith(isAnalyzing: true);
    
    try {
      // 최근 3초 오디오 데이터 사용
      final analysisBuffer = _audioBuffer.length > 48000 
          ? _audioBuffer.sublist(_audioBuffer.length - 48000).cast<double>()
          : _audioBuffer.cast<double>();
      
      final audioData = AudioData(
        samples: analysisBuffer.cast<double>(),
        sampleRate: 16000,
        channels: 1,
        duration: Duration(
          milliseconds: (analysisBuffer.length / 16000 * 1000).round(),
        ),
      );
      
      // Original analysis
      final analysis = await _analyzeVocalQuality(audioData);
      
      // AI Transformer Analysis
      print('[DEBUG] Starting AI analysis...');
      final aiAnalysis = await _transformerAnalyzer.analyzeAudio(analysisBuffer);
      print('[DEBUG] AI analysis complete');
      
      // Emotion/Style Recognition
      print('[DEBUG] Starting emotion/style recognition...');
      final emotionStyleResult = await _emotionStyleRecognizer.recognizeRealTime(analysisBuffer);
      print('[DEBUG] Emotion detected: ${emotionStyleResult.emotion.emotion}');
      
      // High-precision acoustic analysis
      print('[DEBUG] Starting acoustic analysis...');
      final acousticAnalysis = await _acousticAnalyzer.analyzeAudio(analysisBuffer);
      print('[DEBUG] Acoustic analysis complete');
      
      // Generate coaching advice
      print('[DEBUG] Generating coaching advice...');
      final coachingContext = CoachingContext(
        type: CoachingType.detailed,
        intensity: 0.7,
        focus: ['pitch', 'tone', 'emotion'],
      );
      
      final coachingAdvice = await _coachingEngine.generateCoaching(
        analysisResult: aiAnalysis,
        userProfile: _userProfile,
        conversationHistory: _conversationHistory,
        context: coachingContext,
      );
      print('[DEBUG] Coaching advice generated: ${coachingAdvice.mainAdvice}');
      
      // 피치 데이터 업데이트
      final pitchData = List<double>.from(state.pitchData);
      pitchData.addAll(analysis.fundamentalFreq);
      
      // 피치 데이터 크기 제한
      if (pitchData.length > 500) {
        pitchData.removeRange(0, pitchData.length - 500);
      }
      
      state = state.copyWith(
        audioData: audioData,
        analysis: analysis,
        pitchData: pitchData,
        isAnalyzing: false,
        
        // AI Results
        aiAnalysis: aiAnalysis,
        emotionStyleResult: emotionStyleResult,
        coachingAdvice: coachingAdvice,
        acousticAnalysis: acousticAnalysis,
      );
      
    } catch (e) {
      state = state.copyWith(
        isAnalyzing: false,
        error: e.toString(),
      );
    }
  }
  
  Future<void> _performFinalAnalysis() async {
    state = state.copyWith(isAnalyzing: true);
    
    try {
      final audioData = AudioData(
        samples: List.from(_audioBuffer),
        sampleRate: 16000,
        channels: 1,
        duration: Duration(
          milliseconds: (_audioBuffer.length / 16000 * 1000).round(),
        ),
      );
      
      final analysis = await _analyzeVocalQuality(audioData);
      
      state = state.copyWith(
        audioData: audioData,
        analysis: analysis,
        pitchData: analysis.fundamentalFreq.cast<double>(),
        isAnalyzing: false,
      );
      
    } catch (e) {
      state = state.copyWith(
        isAnalyzing: false,
        error: e.toString(),
      );
    }
  }
  
  // Real-time AI analysis for immediate feedback
  Future<void> _performRealtimeAIAnalysis() async {
    print('[DEBUG] _performRealtimeAIAnalysis called, buffer size: ${_audioBuffer.length}');
    if (_audioBuffer.length < 8000) {
      print('[DEBUG] Buffer too small for realtime analysis');
      return; // Minimum 0.5s audio
    }
    
    try {
      // Use recent 1-second audio for real-time analysis
      final realtimeBuffer = _audioBuffer.length > 16000
          ? _audioBuffer.sublist(_audioBuffer.length - 16000).cast<double>()
          : _audioBuffer.cast<double>();
      
      if (realtimeBuffer.isEmpty) return;
      
      // Quick pitch detection
      final fundamentalFreq = _quickPitchDetection(realtimeBuffer);
      final noteInfo = _frequencyToNoteInfo(fundamentalFreq);
      
      // Quick emotion/style recognition
      final quickEmotion = await _emotionStyleRecognizer.recognizeRealTime(realtimeBuffer);
      
      // Calculate voice quality metrics
      final voiceQuality = _calculateQuickVoiceQuality(realtimeBuffer);
      
      // Generate real-time coaching tips
      final realtimeCoaching = _generateQuickCoachingTips(
        fundamentalFreq, 
        noteInfo['accuracy'] as double,
        quickEmotion,
        voiceQuality,
      );
      
      state = state.copyWith(
        currentNote: noteInfo['note'] as String,
        pitchAccuracy: noteInfo['accuracy'] as double,
        cents: noteInfo['cents'] as double,
        emotion: quickEmotion.emotion.emotion,
        style: quickEmotion.style.style,
        voiceQuality: voiceQuality,
        realtimeCoaching: realtimeCoaching,
      );
      
    } catch (e) {
      // Silently handle realtime analysis errors
      print('Realtime analysis error: $e');
    }
  }
  
  double _quickPitchDetection(List<double> audio) {
    if (audio.length < 2) return 0.0;
    
    // Simplified autocorrelation for quick pitch detection
    double maxCorrelation = 0;
    int bestLag = 0;
    
    for (int lag = 50; lag < math.min(400, audio.length ~/ 2); lag++) {
      double correlation = 0;
      for (int i = 0; i < audio.length - lag; i++) {
        correlation += audio[i] * audio[i + lag];
      }
      
      if (correlation > maxCorrelation) {
        maxCorrelation = correlation;
        bestLag = lag;
      }
    }
    
    return bestLag > 0 ? 16000.0 / bestLag : 0.0;
  }
  
  Map<String, dynamic> _frequencyToNoteInfo(double frequency) {
    if (frequency <= 0) {
      return {'note': '', 'accuracy': 0.0, 'cents': 0.0};
    }
    
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const a4 = 440.0;
    
    // Calculate semitones from A4
    final semitonesFromA4 = 12 * math.log(frequency / a4) / math.ln2;
    final noteNumber = (semitonesFromA4 + 9).round(); // +9 to make A=0
    final octave = (noteNumber / 12).floor() + 4;
    final noteIndex = noteNumber % 12;
    
    // Calculate cents deviation
    final exactSemitones = 12 * math.log(frequency / a4) / math.ln2 + 9;
    final cents = ((exactSemitones - noteNumber) * 100).round();
    
    // Calculate accuracy (0-1, where 1 is perfect pitch)
    final accuracy = math.max(0, 1 - (cents.abs() / 50.0)).clamp(0.0, 1.0);
    
    final noteName = noteIndex >= 0 && noteIndex < noteNames.length 
        ? '${noteNames[noteIndex]}$octave' 
        : '';
    
    return {
      'note': noteName,
      'accuracy': accuracy,
      'cents': cents.toDouble(),
    };
  }
  
  double _calculateQuickVoiceQuality(List<double> audio) {
    if (audio.isEmpty) return 0.0;
    
    // Calculate RMS energy
    double energy = 0;
    for (final sample in audio) {
      energy += sample * sample;
    }
    final rms = math.sqrt(energy / audio.length);
    
    // Calculate zero crossing rate (voice stability indicator)
    int zeroCrossings = 0;
    for (int i = 1; i < audio.length; i++) {
      if ((audio[i] >= 0) != (audio[i-1] >= 0)) {
        zeroCrossings++;
      }
    }
    final zcr = zeroCrossings / audio.length.toDouble();
    
    // Combine metrics (higher energy + moderate ZCR = better quality)
    final energyScore = (rms * 10).clamp(0.0, 1.0);
    final zcrScore = 1.0 - (zcr - 0.1).abs().clamp(0.0, 0.9); // Optimal ZCR around 0.1
    
    return (energyScore * 0.7 + zcrScore * 0.3).clamp(0.0, 1.0);
  }
  
  List<String> _generateQuickCoachingTips(
    double frequency,
    double pitchAccuracy,
    EmotionStyleResult emotionStyle,
    double voiceQuality,
  ) {
    final tips = <String>[];
    
    // Pitch coaching
    if (pitchAccuracy < 0.7) {
      if (frequency > 0) {
        tips.add('음정을 조금 더 정확하게 맞춰보세요');
      } else {
        tips.add('좀 더 명확하게 발성해주세요');
      }
    } else if (pitchAccuracy > 0.9) {
      tips.add('완벽한 음정입니다! 👏');
    }
    
    // Voice quality coaching
    if (voiceQuality < 0.5) {
      tips.add('호흡을 더 안정적으로 유지해보세요');
    }
    
    // Emotion coaching
    if (emotionStyle.emotion.confidence > 0.7) {
      if (emotionStyle.emotion.emotion == 'Sad') {
        tips.add('더 밝은 감정을 표현해보세요');
      } else if (emotionStyle.emotion.emotion == 'Happy') {
        tips.add('좋은 감정 표현이에요!');
      }
    }
    
    return tips.take(2).toList(); // Limit to 2 tips for real-time display
  }
  
  void clearError() {
    state = state.copyWith(error: null);
  }
  
  void reset() {
    _audioBuffer.clear();
    _conversationHistory.clear();
    state = const AudioAnalysisState();
  }
  
  // Pitch correction control methods
  void togglePitchCorrection() {
    state = state.copyWith(
      isPitchCorrectionEnabled: !state.isPitchCorrectionEnabled,
    );
  }
  
  void updatePitchCorrectionConfig(PitchCorrectionConfig config) {
    state = state.copyWith(pitchCorrectionConfig: config);
    
    // Update engine settings
    _pitchCorrectionEngine.correctionStrength = config.correctionStrength;
    _pitchCorrectionEngine.setScale(config.scaleType);
    _pitchCorrectionEngine.attackTime = config.attackTime;
    _pitchCorrectionEngine.releaseTime = config.releaseTime;
    _pitchCorrectionEngine.referencePitch = config.referencePitch;
  }
  
  @override
  void dispose() {
    _audioStreamSubscription?.cancel();
    _analysisTimer?.cancel();
    _realtimeTimer?.cancel();
    _audioCaptureService.dispose();
    super.dispose();
  }
}

// Provider 정의
final audioAnalysisProvider = 
    StateNotifierProvider<AudioAnalysisController, AudioAnalysisState>((ref) {
  final repository = AudioAnalysisRepositoryImpl();
  final analyzeVocalQuality = AnalyzeVocalQuality(repository);
  final AudioCaptureServiceInterface audioCaptureService = kIsWeb 
      ? WebAudioCaptureService() as AudioCaptureServiceInterface
      : AudioCaptureService() as AudioCaptureServiceInterface;
  
  // Initialize AI engines
  final transformerAnalyzer = TransformerAudioAnalyzer();
  final coachingEngine = GenerativeCoachingEngine();
  final emotionStyleRecognizer = EmotionStyleRecognizer();
  final audioEnhancer = RealTimeAudioEnhancer();
  final acousticAnalyzer = HighPrecisionAcousticAnalyzer();
  final pitchCorrectionEngine = PitchCorrectionEngine();
  
  return AudioAnalysisController(
    analyzeVocalQuality,
    audioCaptureService,
    transformerAnalyzer,
    coachingEngine,
    emotionStyleRecognizer,
    audioEnhancer,
    acousticAnalyzer,
    pitchCorrectionEngine,
  );
});

// 추가 Provider들
final isRecordingProvider = Provider<bool>((ref) {
  return ref.watch(audioAnalysisProvider).isRecording;
});

final currentAnalysisProvider = Provider<VocalAnalysis?>((ref) {
  return ref.watch(audioAnalysisProvider).analysis;
});

final audioLevelProvider = Provider<double>((ref) {
  return ref.watch(audioAnalysisProvider).recordingLevel;
});

// New AI-specific providers
final currentNoteProvider = Provider<String>((ref) {
  return ref.watch(audioAnalysisProvider).currentNote;
});

final pitchAccuracyProvider = Provider<double>((ref) {
  return ref.watch(audioAnalysisProvider).pitchAccuracy;
});

final centsProvider = Provider<double>((ref) {
  return ref.watch(audioAnalysisProvider).cents;
});

final emotionProvider = Provider<String>((ref) {
  return ref.watch(audioAnalysisProvider).emotion;
});

final styleProvider = Provider<String>((ref) {
  return ref.watch(audioAnalysisProvider).style;
});

final voiceQualityProvider = Provider<double>((ref) {
  return ref.watch(audioAnalysisProvider).voiceQuality;
});

final realtimeCoachingProvider = Provider<List<String>>((ref) {
  return ref.watch(audioAnalysisProvider).realtimeCoaching;
});

final aiAnalysisProvider = Provider<MultiTaskAnalysisResult?>((ref) {
  return ref.watch(audioAnalysisProvider).aiAnalysis;
});

final coachingAdviceProvider = Provider<CoachingResponse?>((ref) {
  return ref.watch(audioAnalysisProvider).coachingAdvice;
});

final acousticAnalysisProvider = Provider<AcousticAnalysisResult?>((ref) {
  return ref.watch(audioAnalysisProvider).acousticAnalysis;
});

// Pitch correction providers
final isPitchCorrectionEnabledProvider = Provider<bool>((ref) {
  return ref.watch(audioAnalysisProvider).isPitchCorrectionEnabled;
});

final pitchCorrectionConfigProvider = Provider<PitchCorrectionConfig>((ref) {
  return ref.watch(audioAnalysisProvider).pitchCorrectionConfig;
});

final correctedAudioProvider = Provider<Float32List?>((ref) {
  return ref.watch(audioAnalysisProvider).correctedAudio;
});