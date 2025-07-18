import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import '../../domain/entities/vocal_analysis.dart';
import '../../domain/entities/visual_guide.dart';
import 'model_loader.dart';

class GuideAnimator extends ChangeNotifier {
  final ModelLoader _modelLoader = ModelLoader();
  
  String? _currentModel;
  String? _currentAnimation;
  bool _isAnimating = false;
  double _animationProgress = 0.0;
  Timer? _animationTimer;
  
  // Rive 애니메이션 컨트롤러
  RiveAnimationController? _riveController;
  
  // 현재 상태
  String? get currentModel => _currentModel;
  String? get currentAnimation => _currentAnimation;
  bool get isAnimating => _isAnimating;
  double get animationProgress => _animationProgress;
  
  Future<void> startBreathingAnimation(BreathingType type) async {
    await _loadModel('human_torso');
    
    switch (type) {
      case BreathingType.diaphragmatic:
        await _playAnimation('breathe_deep', duration: const Duration(seconds: 4));
        break;
      case BreathingType.chest:
        await _playAnimation('breathe_shallow', duration: const Duration(seconds: 3));
        break;
      case BreathingType.mixed:
        await _playAnimation('breathe_deep', duration: const Duration(seconds: 4));
        break;
    }
  }
  
  Future<void> highlightBodyPart(String bodyPart, Color color) async {
    await _loadModel('human_torso');
    
    // 특정 신체 부위에 대한 하이라이트 애니메이션
    final highlightData = _getHighlightData(bodyPart, color);
    
    await _playHighlightAnimation(highlightData);
  }
  
  Future<void> showMouthShape(MouthOpening opening, TonguePosition tongue) async {
    await _loadModel('vocal_tract');
    
    // 입 모양 애니메이션
    final mouthAnimation = _getMouthAnimation(opening);
    
    // 혀 위치 애니메이션
    final tongueAnimation = _getTongueAnimation(tongue);
    
    // 병렬 애니메이션 실행
    await Future.wait([
      _playAnimation(mouthAnimation, duration: const Duration(seconds: 2)),
      _playAnimation(tongueAnimation, duration: const Duration(seconds: 2)),
    ]);
  }
  
  Future<void> showPostureCorrection() async {
    await _loadModel('human_torso');
    await _playAnimation('posture_correct', duration: const Duration(seconds: 3));
  }
  
  Future<void> showResonanceGuide(ResonancePosition position) async {
    await _loadModel('vocal_tract');
    
    final animation = _getResonanceAnimation(position);
    await _playAnimation(animation, duration: const Duration(seconds: 3));
  }
  
  Future<void> playCustomAnimation(GuideAnimation guideAnimation) async {
    final modelKey = _getModelKeyForTarget(guideAnimation.target);
    await _loadModel(modelKey);
    
    final animationName = _getAnimationName(guideAnimation);
    final duration = _parseAnimationTiming(guideAnimation.timing);
    
    await _playAnimation(animationName, duration: duration);
  }
  
  Future<void> _loadModel(String modelKey) async {
    if (_currentModel != modelKey) {
      _currentModel = modelKey;
      await _modelLoader.loadModel(modelKey);
      notifyListeners();
    }
  }
  
  Future<void> _playAnimation(String animationName, {required Duration duration}) async {
    if (_isAnimating) {
      await stopAnimation();
    }
    
    _currentAnimation = animationName;
    _isAnimating = true;
    _animationProgress = 0.0;
    
    notifyListeners();
    
    // 애니메이션 진행 시뮬레이션
    final totalSteps = (duration.inMilliseconds / 16).round(); // 60fps
    var currentStep = 0;
    
    _animationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      currentStep++;
      _animationProgress = currentStep / totalSteps;
      
      if (_animationProgress >= 1.0) {
        _animationProgress = 1.0;
        timer.cancel();
        _isAnimating = false;
        _currentAnimation = null;
      }
      
      notifyListeners();
    });
  }
  
  Future<void> _playHighlightAnimation(HighlightData data) async {
    await _playAnimation('highlight_${data.bodyPart}', 
                        duration: Duration(milliseconds: data.duration));
  }
  
  String _getMouthAnimation(MouthOpening opening) {
    switch (opening) {
      case MouthOpening.narrow:
        return 'mouth_narrow';
      case MouthOpening.medium:
        return 'mouth_medium';
      case MouthOpening.wide:
        return 'mouth_wide';
    }
  }
  
  String _getTongueAnimation(TonguePosition position) {
    switch (position) {
      case TonguePosition.highFront:
        return 'tongue_high_front';
      case TonguePosition.highBack:
        return 'tongue_high_back';
      case TonguePosition.lowFront:
        return 'tongue_low_front';
      case TonguePosition.lowBack:
        return 'tongue_low_back';
    }
  }
  
  String _getResonanceAnimation(ResonancePosition position) {
    switch (position) {
      case ResonancePosition.throat:
        return 'resonance_throat';
      case ResonancePosition.mouth:
        return 'resonance_mouth';
      case ResonancePosition.head:
        return 'resonance_head';
      case ResonancePosition.mixed:
        return 'resonance_mixed';
    }
  }
  
  String _getModelKeyForTarget(String target) {
    switch (target) {
      case 'abdomen':
      case 'chest':
      case 'diaphragm':
      case 'spine':
      case 'shoulders':
      case 'neck':
        return 'human_torso';
      case 'mouth':
      case 'tongue':
      case 'vocal_tract':
      case 'larynx':
        return 'vocal_tract';
      case 'breathing_guide':
        return 'breathing_guide';
      default:
        return 'human_torso';
    }
  }
  
  String _getAnimationName(GuideAnimation guideAnimation) {
    final action = guideAnimation.action;
    final target = guideAnimation.target;
    
    switch (action) {
      case AnimationAction.expandContract:
        return '${target}_expand_contract';
      case AnimationAction.highlight:
        return '${target}_highlight';
      case AnimationAction.rotate:
        return '${target}_rotate';
      case AnimationAction.pulse:
        return '${target}_pulse';
    }
  }
  
  Duration _parseAnimationTiming(String timing) {
    // "inhale: 4s, hold: 2s, exhale: 4s" 형태의 타이밍 파싱
    final parts = timing.split(', ');
    var totalSeconds = 0;
    
    for (final part in parts) {
      final match = RegExp(r'(\d+)s').firstMatch(part);
      if (match != null) {
        totalSeconds += int.parse(match.group(1)!);
      }
    }
    
    return Duration(seconds: totalSeconds > 0 ? totalSeconds : 3);
  }
  
  HighlightData _getHighlightData(String bodyPart, Color color) {
    return HighlightData(
      bodyPart: bodyPart,
      color: color,
      duration: 2000, // 2 seconds
      pulseRate: 1.0,
    );
  }
  
  Future<void> stopAnimation() async {
    _animationTimer?.cancel();
    _isAnimating = false;
    _currentAnimation = null;
    _animationProgress = 0.0;
    _riveController?.dispose();
    _riveController = null;
    
    notifyListeners();
  }
  
  Future<void> pauseAnimation() async {
    if (_animationTimer != null && _animationTimer!.isActive) {
      _animationTimer!.cancel();
    }
    notifyListeners();
  }
  
  Future<void> resumeAnimation() async {
    if (_isAnimating && _currentAnimation != null) {
      final remainingDuration = Duration(
        milliseconds: ((1.0 - _animationProgress) * 3000).round()
      );
      
      await _playAnimation(_currentAnimation!, duration: remainingDuration);
    }
  }
  
  // 애니메이션 강도 조절
  void setAnimationIntensity(AnimationIntensity intensity) {
    // 애니메이션 강도에 따른 파라미터 조절
    switch (intensity) {
      case AnimationIntensity.light:
        _setAnimationSpeed(0.5);
        break;
      case AnimationIntensity.medium:
        _setAnimationSpeed(1.0);
        break;
      case AnimationIntensity.deep:
        _setAnimationSpeed(1.5);
        break;
    }
  }
  
  void _setAnimationSpeed(double speed) {
    // 애니메이션 속도 조절 로직
    // 실제로는 Rive 컨트롤러나 3D 모델 애니메이션 속도 조절
  }
  
  // 복합 애니메이션 (여러 부위 동시 애니메이션)
  Future<void> playComplexAnimation(List<GuideAnimation> animations) async {
    final futures = animations.map((animation) => playCustomAnimation(animation));
    await Future.wait(futures);
  }
  
  // 애니메이션 체인 (순차적 애니메이션)
  Future<void> playAnimationChain(List<GuideAnimation> animations) async {
    for (final animation in animations) {
      await playCustomAnimation(animation);
    }
  }
  
  @override
  void dispose() {
    _animationTimer?.cancel();
    _riveController?.dispose();
    super.dispose();
  }
}

class HighlightData {
  final String bodyPart;
  final Color color;
  final int duration;
  final double pulseRate;
  
  HighlightData({
    required this.bodyPart,
    required this.color,
    required this.duration,
    required this.pulseRate,
  });
}