import '../entities/vocal_analysis.dart';
import '../entities/visual_guide.dart';

class GenerateVisualGuide {
  Future<VisualGuide> call(VocalAnalysis analysis) async {
    // 분석 결과 기반 우선순위 결정
    final priority = _determinePriority(analysis);
    
    // 우선순위에 따른 가이드 생성
    switch (priority) {
      case GuidePriority.breathing:
        return _generateBreathingGuide(analysis);
      case GuidePriority.posture:
        return _generatePostureGuide(analysis);
      case GuidePriority.resonance:
        return _generateResonanceGuide(analysis);
      case GuidePriority.mouthShape:
        return _generateMouthShapeGuide(analysis);
    }
  }

  GuidePriority _determinePriority(VocalAnalysis analysis) {
    // 호흡이 가장 중요 (흉식호흡인 경우)
    if (analysis.breathingType == BreathingType.chest) {
      return GuidePriority.breathing;
    }
    
    // 피치 안정성이 낮은 경우 자세 교정 필요
    if (analysis.pitchStability < 60) {
      return GuidePriority.posture;
    }
    
    // 공명 위치가 목구멍인 경우
    if (analysis.resonancePosition == ResonancePosition.throat) {
      return GuidePriority.resonance;
    }
    
    // 기본적으로 입 모양 가이드
    return GuidePriority.mouthShape;
  }

  Future<VisualGuide> _generateBreathingGuide(VocalAnalysis analysis) async {
    final animations = <GuideAnimation>[];
    final highlights = <BodyHighlight>[];
    final steps = <String>[];
    
    // 복식호흡 애니메이션
    animations.add(const GuideAnimation(
      target: 'abdomen',
      action: AnimationAction.expandContract,
      timing: 'inhale: 4s, hold: 2s, exhale: 4s',
      intensity: AnimationIntensity.deep,
    ));
    
    animations.add(const GuideAnimation(
      target: 'diaphragm',
      action: AnimationAction.highlight,
      timing: 'continuous',
      intensity: AnimationIntensity.medium,
    ));
    
    // 하이라이트
    highlights.add(const BodyHighlight(
      bodyPart: 'abdomen',
      opacity: 0.7,
      colorHex: 0xFF4CAF50,
      pulse: true,
    ));
    
    highlights.add(const BodyHighlight(
      bodyPart: 'lower_ribs',
      opacity: 0.5,
      colorHex: 0xFF2196F3,
      pulse: false,
    ));
    
    // 단계별 가이드
    steps.add('편안한 자세로 서거나 앉으세요');
    steps.add('한 손은 가슴에, 다른 손은 배에 올려놓으세요');
    steps.add('코로 천천히 숨을 들이마시며 배가 나오는 것을 느껴보세요');
    steps.add('가슴의 움직임은 최소화하세요');
    steps.add('입으로 천천히 숨을 내쉬며 배가 들어가는 것을 느껴보세요');
    
    return VisualGuide(
      guideType: GuideType.breathing,
      animations: animations,
      highlights: highlights,
      stepByStep: steps,
      estimatedDuration: const Duration(minutes: 5),
    );
  }

  Future<VisualGuide> _generatePostureGuide(VocalAnalysis analysis) async {
    final animations = <GuideAnimation>[];
    final highlights = <BodyHighlight>[];
    final steps = <String>[];
    
    // 자세 교정 애니메이션
    animations.add(const GuideAnimation(
      target: 'spine',
      action: AnimationAction.highlight,
      timing: 'continuous',
      intensity: AnimationIntensity.medium,
    ));
    
    animations.add(const GuideAnimation(
      target: 'shoulders',
      action: AnimationAction.rotate,
      timing: 'backward: 2s, pause: 1s, forward: 2s',
      intensity: AnimationIntensity.light,
    ));
    
    // 하이라이트
    highlights.add(const BodyHighlight(
      bodyPart: 'spine',
      opacity: 0.8,
      colorHex: 0xFFFF9800,
      pulse: false,
    ));
    
    highlights.add(const BodyHighlight(
      bodyPart: 'neck',
      opacity: 0.6,
      colorHex: 0xFFE91E63,
      pulse: true,
    ));
    
    // 단계별 가이드
    steps.add('발을 어깨 너비로 벌리고 서세요');
    steps.add('무릎을 살짝 구부려 긴장을 풀어주세요');
    steps.add('척추를 곧게 세우되 자연스러운 곡선을 유지하세요');
    steps.add('어깨를 뒤로 젖히고 아래로 내려 이완시키세요');
    steps.add('턱을 살짝 당겨 목이 길어지는 느낌을 받으세요');
    steps.add('시선은 정면을 향하고 머리 꼭대기가 위로 당겨지는 느낌을 상상하세요');
    
    return VisualGuide(
      guideType: GuideType.posture,
      animations: animations,
      highlights: highlights,
      stepByStep: steps,
      estimatedDuration: const Duration(minutes: 3),
    );
  }

  Future<VisualGuide> _generateResonanceGuide(VocalAnalysis analysis) async {
    final animations = <GuideAnimation>[];
    final highlights = <BodyHighlight>[];
    final steps = <String>[];
    
    // 공명 위치 애니메이션
    animations.add(const GuideAnimation(
      target: 'vocal_tract',
      action: AnimationAction.pulse,
      timing: 'pulse: 1s, pause: 1s',
      intensity: AnimationIntensity.medium,
    ));
    
    // 현재 공명 위치에서 목표 위치로 이동
    final targetResonance = _getTargetResonance(analysis.resonancePosition);
    animations.add(GuideAnimation(
      target: targetResonance,
      action: AnimationAction.highlight,
      timing: 'fade_in: 2s, hold: 3s',
      intensity: AnimationIntensity.deep,
    ));
    
    // 하이라이트
    highlights.add(BodyHighlight(
      bodyPart: targetResonance,
      opacity: 0.9,
      colorHex: 0xFF9C27B0,
      pulse: true,
    ));
    
    // 단계별 가이드
    steps.add('편안한 자세로 "흠~" 소리를 내보세요');
    steps.add('입을 다문 채로 소리의 진동을 느껴보세요');
    steps.add('진동이 ${_getResonanceDescription(targetResonance)}에서 느껴지도록 조절하세요');
    steps.add('소리를 앞으로 보내는 느낌으로 발성하세요');
    steps.add('거울을 보며 얼굴 표정이 편안한지 확인하세요');
    
    return VisualGuide(
      guideType: GuideType.resonance,
      animations: animations,
      highlights: highlights,
      stepByStep: steps,
      estimatedDuration: const Duration(minutes: 4),
    );
  }

  Future<VisualGuide> _generateMouthShapeGuide(VocalAnalysis analysis) async {
    final animations = <GuideAnimation>[];
    final highlights = <BodyHighlight>[];
    final steps = <String>[];
    
    // 입 모양 애니메이션
    final targetOpening = _getTargetMouthOpening(analysis.mouthOpening, analysis.tonguePosition);
    
    animations.add(GuideAnimation(
      target: 'mouth',
      action: AnimationAction.expandContract,
      timing: 'open: 2s, hold: 2s, close: 2s',
      intensity: targetOpening == MouthOpening.wide 
          ? AnimationIntensity.deep 
          : AnimationIntensity.medium,
    ));
    
    animations.add(const GuideAnimation(
      target: 'tongue',
      action: AnimationAction.highlight,
      timing: 'continuous',
      intensity: AnimationIntensity.light,
    ));
    
    // 하이라이트
    highlights.add(const BodyHighlight(
      bodyPart: 'lips',
      opacity: 0.7,
      colorHex: 0xFFFF5722,
      pulse: false,
    ));
    
    highlights.add(const BodyHighlight(
      bodyPart: 'jaw',
      opacity: 0.5,
      colorHex: 0xFF607D8B,
      pulse: true,
    ));
    
    // 단계별 가이드
    steps.addAll(_getMouthShapeSteps(analysis.mouthOpening, analysis.tonguePosition));
    
    return VisualGuide(
      guideType: GuideType.mouthShape,
      animations: animations,
      highlights: highlights,
      stepByStep: steps,
      estimatedDuration: const Duration(minutes: 3),
    );
  }

  String _getTargetResonance(ResonancePosition current) {
    switch (current) {
      case ResonancePosition.throat:
        return 'mask_area';
      case ResonancePosition.mouth:
        return 'nasal_cavity';
      case ResonancePosition.head:
        return 'frontal_sinuses';
      case ResonancePosition.mixed:
        return 'mask_area';
    }
  }

  String _getResonanceDescription(String resonanceArea) {
    switch (resonanceArea) {
      case 'mask_area':
        return '얼굴 앞쪽 (마스크 영역)';
      case 'nasal_cavity':
        return '비강';
      case 'frontal_sinuses':
        return '이마 부근';
      default:
        return '얼굴 앞쪽';
    }
  }

  MouthOpening _getTargetMouthOpening(MouthOpening current, TonguePosition tongue) {
    // 혀 위치에 따른 최적 입 모양 결정
    switch (tongue) {
      case TonguePosition.highFront:
      case TonguePosition.highBack:
        return MouthOpening.narrow;
      case TonguePosition.lowFront:
      case TonguePosition.lowBack:
        return MouthOpening.wide;
    }
  }

  List<String> _getMouthShapeSteps(MouthOpening opening, TonguePosition tongue) {
    final steps = <String>[];
    
    steps.add('거울을 보며 연습하세요');
    
    // 입 모양 가이드
    switch (opening) {
      case MouthOpening.narrow:
        steps.add('입술을 살짝 벌리고 미소 짓듯이 옆으로 당기세요');
        steps.add('위아래 치아 사이에 연필 하나 정도의 공간을 만드세요');
        break;
      case MouthOpening.medium:
        steps.add('입을 자연스럽게 벌리세요');
        steps.add('위아래 치아 사이에 엄지손가락 정도의 공간을 만드세요');
        break;
      case MouthOpening.wide:
        steps.add('턱을 편안하게 내리고 입을 크게 벌리세요');
        steps.add('하품하듯이 목구멍 뒤쪽 공간을 넓히세요');
        break;
    }
    
    // 혀 위치 가이드
    switch (tongue) {
      case TonguePosition.highFront:
        steps.add('혀끝을 아래 앞니 뒤에 가볍게 대세요');
        steps.add('혀의 중간 부분을 입천장 가까이 올리세요');
        break;
      case TonguePosition.highBack:
        steps.add('혀를 뒤로 당기면서 올리세요');
        steps.add('목구멍이 막히지 않도록 주의하세요');
        break;
      case TonguePosition.lowFront:
        steps.add('혀를 평평하게 이완시키세요');
        steps.add('혀끝은 아래 앞니 뒤에 자연스럽게 놓으세요');
        break;
      case TonguePosition.lowBack:
        steps.add('혀 전체를 아래로 내리고 이완시키세요');
        steps.add('목구멍 공간이 넓어지는 것을 느껴보세요');
        break;
    }
    
    steps.add('이 자세를 유지하며 "아~" 소리를 내보세요');
    
    return steps;
  }
}

enum GuidePriority {
  breathing,
  posture,
  resonance,
  mouthShape,
}