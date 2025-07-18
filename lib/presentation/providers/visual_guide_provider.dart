import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/visual_guide/visual_guide_controller.dart';
import '../../domain/usecases/generate_visual_guide.dart';
import '../../features/visual_guide/guide_animator.dart';

// Visual Guide Provider
final visualGuideProvider = 
    StateNotifierProvider<VisualGuideController, VisualGuideState>((ref) {
  final generateVisualGuide = GenerateVisualGuide();
  final guideAnimator = GuideAnimator();
  
  return VisualGuideController(generateVisualGuide, guideAnimator);
});

// 추가 Provider들
final isAnimatingProvider = Provider<bool>((ref) {
  return ref.watch(visualGuideProvider).isAnimating;
});

final currentStepProvider = Provider<String?>((ref) {
  final controller = ref.watch(visualGuideProvider.notifier);
  return controller.getCurrentStepText();
});

final guideProgressProvider = Provider<double>((ref) {
  final controller = ref.watch(visualGuideProvider.notifier);
  return controller.getProgress();
});