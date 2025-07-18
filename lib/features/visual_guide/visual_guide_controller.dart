import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/vocal_analysis.dart';
import '../../domain/entities/visual_guide.dart';
import '../../domain/usecases/generate_visual_guide.dart';
import 'guide_animator.dart';

// 상태 클래스 정의
class VisualGuideState {
  final VisualGuide? currentGuide;
  final bool isLoading;
  final String? error;
  final bool isAnimating;
  final int currentStep;
  final bool isStepByStepMode;
  
  const VisualGuideState({
    this.currentGuide,
    this.isLoading = false,
    this.error,
    this.isAnimating = false,
    this.currentStep = 0,
    this.isStepByStepMode = false,
  });
  
  VisualGuideState copyWith({
    VisualGuide? currentGuide,
    bool? isLoading,
    String? error,
    bool? isAnimating,
    int? currentStep,
    bool? isStepByStepMode,
  }) {
    return VisualGuideState(
      currentGuide: currentGuide ?? this.currentGuide,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isAnimating: isAnimating ?? this.isAnimating,
      currentStep: currentStep ?? this.currentStep,
      isStepByStepMode: isStepByStepMode ?? this.isStepByStepMode,
    );
  }
}

class VisualGuideController extends StateNotifier<VisualGuideState> {
  final GenerateVisualGuide _generateVisualGuide;
  final GuideAnimator _guideAnimator;
  
  VisualGuideController(this._generateVisualGuide, this._guideAnimator) 
      : super(const VisualGuideState());
  
  Future<void> updateGuide(VocalAnalysis analysis) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // 1. 분석 결과 기반 가이드 생성
      final guide = await _generateVisualGuide(analysis);
      
      // 2. 상태 업데이트
      state = state.copyWith(
        currentGuide: guide,
        isLoading: false,
        currentStep: 0,
      );
      
      // 3. 자동 애니메이션 시작
      await _startAutoAnimation(guide);
      
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  Future<void> _startAutoAnimation(VisualGuide guide) async {
    if (guide.animations.isEmpty) return;
    
    state = state.copyWith(isAnimating: true);
    
    try {
      // 우선순위가 높은 애니메이션부터 실행
      final prioritizedAnimations = _prioritizeAnimations(guide.animations);
      
      // 주요 애니메이션 실행
      if (prioritizedAnimations.isNotEmpty) {
        await _guideAnimator.playCustomAnimation(prioritizedAnimations.first);
      }
      
      // 하이라이트 적용
      await _applyHighlights(guide.highlights);
      
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isAnimating: false);
    }
  }
  
  List<GuideAnimation> _prioritizeAnimations(List<GuideAnimation> animations) {
    // 애니메이션 우선순위 정렬
    final prioritized = List<GuideAnimation>.from(animations);
    
    prioritized.sort((a, b) {
      // 호흡 관련 애니메이션이 최우선
      if (a.target == 'abdomen' || a.target == 'diaphragm') return -1;
      if (b.target == 'abdomen' || b.target == 'diaphragm') return 1;
      
      // 자세 관련 애니메이션이 두 번째
      if (a.target == 'spine' || a.target == 'shoulders') return -1;
      if (b.target == 'spine' || b.target == 'shoulders') return 1;
      
      // 강도가 높은 애니메이션 우선
      final intensityOrder = {
        AnimationIntensity.deep: 0,
        AnimationIntensity.medium: 1,
        AnimationIntensity.light: 2,
      };
      
      return intensityOrder[a.intensity]!.compareTo(intensityOrder[b.intensity]!);
    });
    
    return prioritized;
  }
  
  Future<void> _applyHighlights(List<BodyHighlight> highlights) async {
    for (final highlight in highlights) {
      await _guideAnimator.highlightBodyPart(
        highlight.bodyPart,
        Color(highlight.colorHex),
      );
    }
  }
  
  Future<void> startStepByStepGuide(GuideType type) async {
    state = state.copyWith(isStepByStepMode: true, currentStep: 0);
    
    if (state.currentGuide == null) return;
    
    try {
      await _executeCurrentStep();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  Future<void> nextStep() async {
    if (!state.isStepByStepMode || state.currentGuide == null) return;
    
    final guide = state.currentGuide!;
    
    if (state.currentStep < guide.stepByStep.length - 1) {
      state = state.copyWith(currentStep: state.currentStep + 1);
      await _executeCurrentStep();
    } else {
      // 마지막 단계 완료
      state = state.copyWith(isStepByStepMode: false);
    }
  }
  
  Future<void> previousStep() async {
    if (!state.isStepByStepMode || state.currentGuide == null) return;
    
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
      await _executeCurrentStep();
    }
  }
  
  Future<void> _executeCurrentStep() async {
    if (state.currentGuide == null) return;
    
    final guide = state.currentGuide!;
    final currentStep = state.currentStep;
    
    // 현재 단계에 해당하는 애니메이션 실행
    if (currentStep < guide.animations.length) {
      await _guideAnimator.playCustomAnimation(guide.animations[currentStep]);
    }
    
    // 단계별 하이라이트 적용
    final stepHighlights = _getStepHighlights(guide, currentStep);
    await _applyHighlights(stepHighlights);
  }
  
  List<BodyHighlight> _getStepHighlights(VisualGuide guide, int step) {
    // 단계별로 관련된 하이라이트만 반환
    if (step >= guide.animations.length) return [];
    
    final animation = guide.animations[step];
    
    return guide.highlights.where((highlight) {
      return highlight.bodyPart == animation.target ||
             _isRelatedBodyPart(highlight.bodyPart, animation.target);
    }).toList();
  }
  
  bool _isRelatedBodyPart(String highlight, String target) {
    const relatedParts = {
      'abdomen': ['diaphragm', 'breathing_guide'],
      'chest': ['shoulders', 'spine'],
      'mouth': ['tongue', 'vocal_tract'],
      'diaphragm': ['abdomen'],
    };
    
    return relatedParts[target]?.contains(highlight) ?? false;
  }
  
  Future<void> playSpecificAnimation(GuideAnimation animation) async {
    state = state.copyWith(isAnimating: true);
    
    try {
      await _guideAnimator.playCustomAnimation(animation);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isAnimating: false);
    }
  }
  
  Future<void> stopCurrentAnimation() async {
    await _guideAnimator.stopAnimation();
    state = state.copyWith(isAnimating: false);
  }
  
  void clearError() {
    state = state.copyWith(error: null);
  }
  
  void reset() {
    state = const VisualGuideState();
  }
  
  // 특정 호흡 타입 가이드 시작
  Future<void> startBreathingGuide(BreathingType type) async {
    state = state.copyWith(isAnimating: true);
    
    try {
      await _guideAnimator.startBreathingAnimation(type);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isAnimating: false);
    }
  }
  
  // 특정 공명 가이드 시작
  Future<void> startResonanceGuide(ResonancePosition position) async {
    state = state.copyWith(isAnimating: true);
    
    try {
      await _guideAnimator.showResonanceGuide(position);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isAnimating: false);
    }
  }
  
  // 입 모양 가이드 시작
  Future<void> startMouthShapeGuide(MouthOpening opening, TonguePosition tongue) async {
    state = state.copyWith(isAnimating: true);
    
    try {
      await _guideAnimator.showMouthShape(opening, tongue);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isAnimating: false);
    }
  }
  
  // 자세 교정 가이드 시작
  Future<void> startPostureGuide() async {
    state = state.copyWith(isAnimating: true);
    
    try {
      await _guideAnimator.showPostureCorrection();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isAnimating: false);
    }
  }
  
  // 현재 단계 정보 반환
  String? getCurrentStepText() {
    if (state.currentGuide == null || !state.isStepByStepMode) return null;
    
    final guide = state.currentGuide!;
    if (state.currentStep < guide.stepByStep.length) {
      return guide.stepByStep[state.currentStep];
    }
    
    return null;
  }
  
  // 전체 단계 정보 반환
  List<String> getAllSteps() {
    return state.currentGuide?.stepByStep ?? [];
  }
  
  // 진행률 계산
  double getProgress() {
    if (state.currentGuide == null || !state.isStepByStepMode) return 0.0;
    
    final totalSteps = state.currentGuide!.stepByStep.length;
    if (totalSteps == 0) return 0.0;
    
    return (state.currentStep + 1) / totalSteps;
  }
}

// Provider 정의
final visualGuideControllerProvider = 
    StateNotifierProvider<VisualGuideController, VisualGuideState>((ref) {
  final generateVisualGuide = GenerateVisualGuide();
  final guideAnimator = GuideAnimator();
  
  return VisualGuideController(generateVisualGuide, guideAnimator);
});