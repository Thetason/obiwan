import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../domain/entities/vocal_analysis.dart';
import '../../features/audio_analysis/real_time_vocal_analyzer.dart';
import '../../features/ai_coaching/smart_feedback_engine.dart';

/// 실시간 음성 분석 상태
class RealTimeAnalysisState {
  final bool isAnalyzing;
  final VocalAnalysis? currentAnalysis;
  final List<VocalAnalysis> analysisHistory;
  final String? error;
  final double currentPitch;
  final double currentAmplitude;
  final SmartFeedback? currentFeedback;
  
  const RealTimeAnalysisState({
    this.isAnalyzing = false,
    this.currentAnalysis,
    this.analysisHistory = const [],
    this.error,
    this.currentPitch = 0.0,
    this.currentAmplitude = 0.0,
    this.currentFeedback,
  });
  
  RealTimeAnalysisState copyWith({
    bool? isAnalyzing,
    VocalAnalysis? currentAnalysis,
    List<VocalAnalysis>? analysisHistory,
    String? error,
    double? currentPitch,
    double? currentAmplitude,
    SmartFeedback? currentFeedback,
  }) {
    return RealTimeAnalysisState(
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      currentAnalysis: currentAnalysis ?? this.currentAnalysis,
      analysisHistory: analysisHistory ?? this.analysisHistory,
      error: error,
      currentPitch: currentPitch ?? this.currentPitch,
      currentAmplitude: currentAmplitude ?? this.currentAmplitude,
      currentFeedback: currentFeedback ?? this.currentFeedback,
    );
  }
}

/// 실시간 음성 분석 컨트롤러
class RealTimeAnalysisController extends StateNotifier<RealTimeAnalysisState> {
  final RealTimeVocalAnalyzer _analyzer = RealTimeVocalAnalyzer();
  final SmartFeedbackEngine _feedbackEngine = SmartFeedbackEngine();
  StreamSubscription<VocalAnalysis>? _analysisSubscription;
  
  RealTimeAnalysisController() : super(const RealTimeAnalysisState());
  
  /// 분석 시작
  Future<void> startAnalysis() async {
    if (state.isAnalyzing) return;
    
    try {
      state = state.copyWith(isAnalyzing: true, error: null);
      
      // 분석 시작
      await _analyzer.startAnalysis();
      
      // 분석 결과 스트림 구독
      _analysisSubscription = _analyzer.analysisStream.listen(
        (analysis) {
          final newHistory = List<VocalAnalysis>.from(state.analysisHistory);
          newHistory.add(analysis);
          
          // 히스토리 크기 제한 (최근 100개)
          if (newHistory.length > 100) {
            newHistory.removeAt(0);
          }
          
          // 현재 피치와 진폭 추출
          final currentPitch = analysis.fundamentalFreq.isNotEmpty 
              ? analysis.fundamentalFreq.last 
              : 0.0;
          
          // AI 피드백 생성
          final smartFeedback = _feedbackEngine.generateSmartFeedback(analysis);
          
          state = state.copyWith(
            currentAnalysis: analysis,
            analysisHistory: newHistory,
            currentPitch: currentPitch,
            currentAmplitude: analysis.spectralTilt.abs(),
            currentFeedback: smartFeedback,
          );
        },
        onError: (error) {
          state = state.copyWith(
            isAnalyzing: false,
            error: error.toString(),
          );
        },
      );
      
    } catch (e) {
      state = state.copyWith(
        isAnalyzing: false,
        error: e.toString(),
      );
    }
  }
  
  /// 분석 중지
  Future<void> stopAnalysis() async {
    if (!state.isAnalyzing) return;
    
    await _analysisSubscription?.cancel();
    await _analyzer.stopAnalysis();
    
    state = state.copyWith(isAnalyzing: false);
  }
  
  /// 에러 클리어
  void clearError() {
    state = state.copyWith(error: null);
  }
  
  /// 히스토리 클리어
  void clearHistory() {
    _feedbackEngine.clearHistory();
    state = state.copyWith(
      analysisHistory: [],
      currentAnalysis: null,
      currentFeedback: null,
    );
  }
  
  @override
  void dispose() {
    _analysisSubscription?.cancel();
    _analyzer.dispose();
    super.dispose();
  }
}

// Provider 정의
final realTimeAnalysisProvider = 
    StateNotifierProvider<RealTimeAnalysisController, RealTimeAnalysisState>((ref) {
  return RealTimeAnalysisController();
});

// 편의 Provider들
final isAnalyzingProvider = Provider<bool>((ref) {
  return ref.watch(realTimeAnalysisProvider).isAnalyzing;
});

final currentAnalysisProvider = Provider<VocalAnalysis?>((ref) {
  return ref.watch(realTimeAnalysisProvider).currentAnalysis;
});

final currentPitchProvider = Provider<double>((ref) {
  return ref.watch(realTimeAnalysisProvider).currentPitch;
});

final currentAmplitudeProvider = Provider<double>((ref) {
  return ref.watch(realTimeAnalysisProvider).currentAmplitude;
});

final analysisHistoryProvider = Provider<List<VocalAnalysis>>((ref) {
  return ref.watch(realTimeAnalysisProvider).analysisHistory;
});

final analysisErrorProvider = Provider<String?>((ref) {
  return ref.watch(realTimeAnalysisProvider).error;
});

final currentFeedbackProvider = Provider<SmartFeedback?>((ref) {
  return ref.watch(realTimeAnalysisProvider).currentFeedback;
});