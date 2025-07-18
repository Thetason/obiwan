import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../domain/entities/audio_data.dart';
import '../../domain/entities/vocal_analysis.dart';
import '../../domain/usecases/analyze_vocal_quality.dart';
import '../../data/repositories/audio_analysis_repository_impl.dart';
import '../../features/audio_analysis/audio_capture_service_simple.dart';

// 오디오 분석 상태 클래스
class AudioAnalysisState {
  final AudioData? audioData;
  final VocalAnalysis? analysis;
  final List<double> pitchData;
  final List<double> waveformData;
  final bool isAnalyzing;
  final bool isRecording;
  final String? error;
  final double recordingLevel;
  
  const AudioAnalysisState({
    this.audioData,
    this.analysis,
    this.pitchData = const [],
    this.waveformData = const [],
    this.isAnalyzing = false,
    this.isRecording = false,
    this.error,
    this.recordingLevel = 0.0,
  });
  
  AudioAnalysisState copyWith({
    AudioData? audioData,
    VocalAnalysis? analysis,
    List<double>? pitchData,
    List<double>? waveformData,
    bool? isAnalyzing,
    bool? isRecording,
    String? error,
    double? recordingLevel,
  }) {
    return AudioAnalysisState(
      audioData: audioData ?? this.audioData,
      analysis: analysis ?? this.analysis,
      pitchData: pitchData ?? this.pitchData,
      waveformData: waveformData ?? this.waveformData,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isRecording: isRecording ?? this.isRecording,
      error: error ?? this.error,
      recordingLevel: recordingLevel ?? this.recordingLevel,
    );
  }
}

// 오디오 분석 컨트롤러
class AudioAnalysisController extends StateNotifier<AudioAnalysisState> {
  final AnalyzeVocalQuality _analyzeVocalQuality;
  final AudioCaptureService _audioCaptureService;
  
  StreamSubscription? _audioStreamSubscription;
  Timer? _analysisTimer;
  final List<double> _audioBuffer = [];
  static const int _bufferSize = 48000; // 3초 * 16kHz
  
  AudioAnalysisController(this._analyzeVocalQuality, this._audioCaptureService) 
      : super(const AudioAnalysisState());
  
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
      
    } catch (e) {
      state = state.copyWith(
        isRecording: false,
        error: e.toString(),
      );
    }
  }
  
  Future<void> stopRecording() async {
    if (!state.isRecording) return;
    
    await _audioCaptureService.stopCapture();
    await _audioStreamSubscription?.cancel();
    _analysisTimer?.cancel();
    
    state = state.copyWith(isRecording: false);
    
    // 최종 분석 수행
    if (_audioBuffer.isNotEmpty) {
      await _performFinalAnalysis();
    }
  }
  
  void _onAudioData(List<double> audioChunk) {
    // 오디오 버퍼에 추가
    _audioBuffer.addAll(audioChunk);
    
    // 버퍼 크기 제한
    if (_audioBuffer.length > _bufferSize) {
      _audioBuffer.removeRange(0, _audioBuffer.length - _bufferSize);
    }
    
    // 실시간 파형 데이터 업데이트
    _updateWaveformData(audioChunk);
    
    // 음성 레벨 계산
    final level = _calculateAudioLevel(audioChunk);
    
    state = state.copyWith(
      waveformData: List.from(_audioBuffer.take(1024)), // 시각화용
      recordingLevel: level,
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
    if (_audioBuffer.length < 16000) return; // 최소 1초 오디오 필요
    
    state = state.copyWith(isAnalyzing: true);
    
    try {
      // 최근 3초 오디오 데이터 사용
      final analysisBuffer = _audioBuffer.length > 48000 
          ? _audioBuffer.sublist(_audioBuffer.length - 48000)
          : List.from(_audioBuffer);
      
      final audioData = AudioData(
        samples: analysisBuffer.cast<double>(),
        sampleRate: 16000,
        channels: 1,
        duration: Duration(
          milliseconds: (analysisBuffer.length / 16000 * 1000).round(),
        ),
      );
      
      final analysis = await _analyzeVocalQuality(audioData);
      
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
  
  void clearError() {
    state = state.copyWith(error: null);
  }
  
  void reset() {
    _audioBuffer.clear();
    state = const AudioAnalysisState();
  }
  
  @override
  void dispose() {
    _audioStreamSubscription?.cancel();
    _analysisTimer?.cancel();
    _audioCaptureService.dispose();
    super.dispose();
  }
}

// Provider 정의
final audioAnalysisProvider = 
    StateNotifierProvider<AudioAnalysisController, AudioAnalysisState>((ref) {
  final repository = AudioAnalysisRepositoryImpl();
  final analyzeVocalQuality = AnalyzeVocalQuality(repository);
  final audioCaptureService = AudioCaptureService();
  
  return AudioAnalysisController(analyzeVocalQuality, audioCaptureService);
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