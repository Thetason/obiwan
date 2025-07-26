import '../../domain/entities/visual_guide.dart';
import '../../domain/entities/vocal_analysis.dart';

/// 보컬 트레이닝 가이드 콘텐츠 제공 클래스
class VocalGuideContent {
  
  /// 호흡법 가이드 생성
  static VisualGuide createBreathingGuide(BreathingType breathingType) {
    switch (breathingType) {
      case BreathingType.diaphragmatic:
        return _createDiaphragmaticBreathingGuide();
      case BreathingType.chest:
        return _createChestBreathingGuide();
      case BreathingType.mixed:
        return _createMixedBreathingGuide();
    }
  }
  
  static VisualGuide _createDiaphragmaticBreathingGuide() {
    return VisualGuide(
      id: 'diaphragmatic_breathing',
      title: '복식호흡 가이드',
      description: '횡격막을 이용한 깊고 안정적인 호흡법을 익혀보세요.',
      guideType: GuideType.breathing,
      
      highlights: [
        BodyHighlight(
          bodyPart: 'diaphragm',
          colorHex: 0xFF4CAF50,
          opacity: 0.8,
          pulse: true,
        ),
        BodyHighlight(
          bodyPart: 'abdomen',
          colorHex: 0xFF2196F3,
          opacity: 0.6,
          pulse: false,
        ),
      ],
      
      animations: [
        GuideAnimation(
          action: AnimationAction.expandContract,
          target: 'diaphragm',
          timing: 'inhale: 4s, hold: 2s, exhale: 6s',
          intensity: AnimationIntensity.deep,
        ),
        GuideAnimation(
          action: AnimationAction.pulse,
          target: 'abdomen',
          timing: 'continuous',
          intensity: AnimationIntensity.medium,
        ),
      ],
      
      stepByStep: [
        '1️⃣ 편안한 자세로 앉거나 누워주세요',
        '2️⃣ 한 손은 가슴에, 다른 손은 배에 올려주세요',
        '3️⃣ 가슴은 움직이지 않고 배만 부풀어 오르게 숨을 들이마세요',
        '4️⃣ 4초간 천천히 숨을 들이마시고 2초간 멈춰주세요',
        '5️⃣ 6초간 천천히 숨을 내쉬며 배가 들어가게 해주세요',
        '6️⃣ 이 과정을 10회 반복해주세요',
      ],
      
      instructions: [
        '💡 **팁**: 가슴이 아닌 배가 움직이는지 확인하세요',
        '⚠️ **주의**: 처음에는 어지러울 수 있으니 천천히 연습하세요',
        '🎯 **목표**: 자연스럽게 복식호흡이 되도록 연습하세요',
      ],
    );
  }
  
  static VisualGuide _createChestBreathingGuide() {
    return VisualGuide(
      id: 'chest_breathing',
      title: '흉식호흡 가이드',
      description: '가슴을 이용한 빠르고 얕은 호흡법입니다.',
      guideType: GuideType.breathing,
      
      highlights: [
        BodyHighlight(
          bodyPart: 'chest',
          colorHex: 0xFFFF9800,
          opacity: 0.8,
          pulse: true,
        ),
      ],
      
      animations: [
        GuideAnimation(
          action: AnimationAction.expandContract,
          target: 'chest',
          timing: 'inhale: 2s, exhale: 2s',
          intensity: AnimationIntensity.light,
        ),
      ],
      
      stepByStep: [
        '1️⃣ 어깨를 자연스럽게 내리고 서주세요',
        '2️⃣ 가슴에 손을 올려주세요',
        '3️⃣ 가슴이 위아래로 움직이며 숨을 쉬어주세요',
        '4️⃣ 2초간 들이마시고 2초간 내쉬어주세요',
        '5️⃣ 빠른 템포의 노래에 적합한 호흡법입니다',
      ],
      
      instructions: [
        '💡 **팁**: 어깨가 함께 올라가지 않도록 주의하세요',
        '⚠️ **주의**: 장시간 사용하면 피로할 수 있습니다',
        '🎯 **용도**: 빠른 템포나 짧은 프레이즈에 사용하세요',
      ],
    );
  }
  
  static VisualGuide _createMixedBreathingGuide() {
    return VisualGuide(
      id: 'mixed_breathing',
      title: '혼합호흡 가이드',
      description: '복식호흡과 흉식호흡을 적절히 조합한 고급 호흡법입니다.',
      guideType: GuideType.breathing,
      
      highlights: [
        BodyHighlight(
          bodyPart: 'diaphragm',
          colorHex: 0xFF4CAF50,
          opacity: 0.7,
          pulse: true,
        ),
        BodyHighlight(
          bodyPart: 'chest',
          colorHex: 0xFFFF9800,
          opacity: 0.7,
          pulse: true,
        ),
      ],
      
      animations: [
        GuideAnimation(
          action: AnimationAction.expandContract,
          target: 'diaphragm',
          timing: 'inhale: 3s, hold: 1s, exhale: 4s',
          intensity: AnimationIntensity.medium,
        ),
        GuideAnimation(
          action: AnimationAction.expandContract,
          target: 'chest',
          timing: 'inhale: 3s, hold: 1s, exhale: 4s',
          intensity: AnimationIntensity.light,
        ),
      ],
      
      stepByStep: [
        '1️⃣ 복식호흡을 시작하여 배를 부풀려주세요',
        '2️⃣ 배가 충분히 나온 후 가슴도 확장해주세요',
        '3️⃣ 3초간 아래부터 위로 차례로 공기를 채워주세요',
        '4️⃣ 1초간 호흡을 유지해주세요',
        '5️⃣ 4초간 천천히 위부터 아래로 공기를 빼주세요',
        '6️⃣ 이 순서를 기억하며 자연스럽게 연습하세요',
      ],
      
      instructions: [
        '💡 **핵심**: 아래부터 위로 채우고, 위부터 아래로 비우기',
        '⚠️ **주의**: 충분한 복식호흡 연습 후 시도하세요',
        '🎯 **목표**: 긴 프레이즈와 강한 성량을 위한 호흡법',
      ],
    );
  }
  
  /// 공명 가이드 생성
  static VisualGuide createResonanceGuide(ResonancePosition position) {
    switch (position) {
      case ResonancePosition.head:
        return _createHeadResonanceGuide();
      case ResonancePosition.mouth:
        return _createMouthResonanceGuide();
      case ResonancePosition.throat:
        return _createThroatResonanceGuide();
      case ResonancePosition.mixed:
        return _createMixedResonanceGuide();
    }
  }
  
  static VisualGuide _createHeadResonanceGuide() {
    return VisualGuide(
      id: 'head_resonance',
      title: '두성 공명 가이드',
      description: '머리 부분의 공명을 활용한 맑고 밝은 음색을 만들어보세요.',
      guideType: GuideType.resonance,
      
      highlights: [
        BodyHighlight(
          bodyPart: 'head',
          colorHex: 0xFFE91E63,
          opacity: 0.8,
          pulse: true,
        ),
        BodyHighlight(
          bodyPart: 'sinuses',
          colorHex: 0xFF9C27B0,
          opacity: 0.6,
          pulse: false,
        ),
      ],
      
      animations: [
        GuideAnimation(
          action: AnimationAction.pulse,
          target: 'head',
          timing: 'continuous vibration',
          intensity: AnimationIntensity.medium,
        ),
      ],
      
      stepByStep: [
        '1️⃣ "흠~" 소리를 내며 입을 다물고 허밍해보세요',
        '2️⃣ 코 주변과 이마에서 진동을 느껴보세요',
        '3️⃣ "미-" 소리로 높은 음을 내보세요',
        '4️⃣ 머리 위쪽에서 울리는 느낌을 찾아보세요',
        '5️⃣ 점차 입을 열어가며 "마-메-미-모-무" 연습하세요',
      ],
      
      instructions: [
        '💡 **느낌**: 머리 위쪽에서 울리는 진동',
        '🎵 **음색**: 맑고 밝은 음색',
        '🎯 **적용**: 고음, 발라드, 클래식 장르에 효과적',
      ],
    );
  }
  
  static VisualGuide _createMouthResonanceGuide() {
    return VisualGuide(
      id: 'mouth_resonance',
      title: '구강 공명 가이드',
      description: '입안 공간을 활용한 풍부하고 따뜻한 음색을 만들어보세요.',
      guideType: GuideType.resonance,
      
      highlights: [
        BodyHighlight(
          bodyPart: 'mouth',
          colorHex: 0xFF2196F3,
          opacity: 0.8,
          pulse: true,
        ),
      ],
      
      animations: [
        GuideAnimation(
          action: AnimationAction.expandContract,
          target: 'mouth',
          timing: 'shape changes with vowels',
          intensity: AnimationIntensity.medium,
        ),
      ],
      
      stepByStep: [
        '1️⃣ 입안에 달걀 하나가 들어있다고 상상하며 입을 열어주세요',
        '2️⃣ "아-" 소리를 내며 입안 공간을 넓혀주세요',
        '3️⃣ 혀는 아래쪽에 편안히 놓아주세요',
        '4️⃣ "아-에-이-오-우" 순서로 모음을 연습하세요',
        '5️⃣ 각 모음마다 입 모양의 변화를 느껴보세요',
      ],
      
      instructions: [
        '💡 **핵심**: 입안 공간을 넓게 유지',
        '🎵 **음색**: 풍부하고 따뜻한 음색',
        '🎯 **적용**: 중음역, 팝, R&B 장르에 효과적',
      ],
    );
  }
  
  static VisualGuide _createThroatResonanceGuide() {
    return VisualGuide(
      id: 'throat_resonance',
      title: '흉성 공명 가이드',
      description: '가슴과 목 부분의 공명을 활용한 깊고 진한 음색을 만들어보세요.',
      guideType: GuideType.resonance,
      
      highlights: [
        BodyHighlight(
          bodyPart: 'chest',
          colorHex: 0xFF795548,
          opacity: 0.8,
          pulse: true,
        ),
        BodyHighlight(
          bodyPart: 'throat',
          colorHex: 0xFF607D8B,
          opacity: 0.6,
          pulse: false,
        ),
      ],
      
      animations: [
        GuideAnimation(
          action: AnimationAction.pulse,
          target: 'chest',
          timing: 'low frequency vibration',
          intensity: AnimationIntensity.deep,
        ),
      ],
      
      stepByStep: [
        '1️⃣ 가슴에 손을 올리고 낮은 "어-" 소리를 내보세요',
        '2️⃣ 가슴에서 진동이 느껴지는지 확인하세요',
        '3️⃣ 목을 편안히 하고 자연스럽게 소리내세요',
        '4️⃣ "아-어-오-우" 순서로 낮은 음으로 연습하세요',
        '5️⃣ 점차 음역을 넓혀가며 흉성을 유지해보세요',
      ],
      
      instructions: [
        '💡 **느낌**: 가슴에서 느껴지는 진동',
        '🎵 **음색**: 깊고 진한 음색',
        '🎯 **적용**: 저음, 재즈, 블루스 장르에 효과적',
      ],
    );
  }
  
  static VisualGuide _createMixedResonanceGuide() {
    return VisualGuide(
      id: 'mixed_resonance',
      title: '믹스보이스 가이드',
      description: '두성과 흉성을 조화롭게 섞은 균형 잡힌 음색을 만들어보세요.',
      guideType: GuideType.resonance,
      
      highlights: [
        BodyHighlight(
          bodyPart: 'head',
          colorHex: 0xFFE91E63,
          opacity: 0.6,
          pulse: true,
        ),
        BodyHighlight(
          bodyPart: 'chest',
          colorHex: 0xFF795548,
          opacity: 0.6,
          pulse: true,
        ),
        BodyHighlight(
          bodyPart: 'mask',
          colorHex: 0xFF4CAF50,
          opacity: 0.8,
          pulse: false,
        ),
      ],
      
      animations: [
        GuideAnimation(
          action: AnimationAction.pulse,
          target: 'head',
          timing: 'synchronized with chest',
          intensity: AnimationIntensity.medium,
        ),
        GuideAnimation(
          action: AnimationAction.pulse,
          target: 'chest',
          timing: 'synchronized with head',
          intensity: AnimationIntensity.medium,
        ),
      ],
      
      stepByStep: [
        '1️⃣ 중간 음역에서 편안하게 "마-" 소리를 내보세요',
        '2️⃣ 가슴과 머리에서 동시에 진동을 느껴보세요',
        '3️⃣ 음을 올려가며 두성의 비율을 늘려보세요',
        '4️⃣ 음을 내려가며 흉성의 비율을 늘려보세요',
        '5️⃣ 전 음역에서 균형을 유지하며 연습하세요',
        '6️⃣ "나-네-니-노-누" 연습으로 안정화하세요',
      ],
      
      instructions: [
        '💡 **핵심**: 두성과 흉성의 균형 잡힌 조화',
        '🎵 **음색**: 자연스럽고 균형 잡힌 음색',
        '🎯 **목표**: 전 음역에서 일관된 음색 유지',
        '⚠️ **주의**: 충분한 두성/흉성 연습 후 시도',
      ],
    );
  }
  
  /// 자세 교정 가이드 생성
  static VisualGuide createPostureGuide() {
    return VisualGuide(
      id: 'vocal_posture',
      title: '발성 자세 가이드',
      description: '올바른 발성을 위한 기본 자세를 익혀보세요.',
      guideType: GuideType.posture,
      
      highlights: [
        BodyHighlight(
          bodyPart: 'spine',
          colorHex: 0xFF4CAF50,
          opacity: 0.8,
          pulse: false,
        ),
        BodyHighlight(
          bodyPart: 'shoulders',
          colorHex: 0xFF2196F3,
          opacity: 0.6,
          pulse: false,
        ),
        BodyHighlight(
          bodyPart: 'neck',
          colorHex: 0xFFFF9800,
          opacity: 0.6,
          pulse: false,
        ),
      ],
      
      animations: [
        GuideAnimation(
          action: AnimationAction.highlight,
          target: 'spine',
          timing: 'maintain straight',
          intensity: AnimationIntensity.medium,
        ),
      ],
      
      stepByStep: [
        '1️⃣ 어깨를 뒤로 젖히고 자연스럽게 내려주세요',
        '2️⃣ 등을 곧게 펴고 척추를 일직선으로 세워주세요',
        '3️⃣ 턱을 살짝 당겨 목을 곧게 세워주세요',
        '4️⃣ 발을 어깨 너비로 벌리고 무게중심을 잡아주세요',
        '5️⃣ 무릎을 살짝 굽혀 자연스러운 자세를 만들어주세요',
        '6️⃣ 전체적으로 편안하면서도 안정된 자세를 유지하세요',
      ],
      
      instructions: [
        '💡 **핵심**: 자연스럽고 안정된 정렬',
        '⚠️ **주의**: 과도하게 긴장하지 마세요',
        '🎯 **목표**: 호흡과 발성에 방해가 되지 않는 자세',
        '🔄 **유지**: 노래하는 동안 지속적으로 체크',
      ],
    );
  }
  
  /// 입 모양 가이드 생성 (모음별)
  static List<VisualGuide> createVowelGuides() {
    return [
      _createVowelGuide('a', '아', 0xFFE91E63),
      _createVowelGuide('e', '에', 0xFF2196F3),
      _createVowelGuide('i', '이', 0xFF4CAF50),
      _createVowelGuide('o', '오', 0xFFFF9800),
      _createVowelGuide('u', '우', 0xFF9C27B0),
    ];
  }
  
  static VisualGuide _createVowelGuide(String vowel, String korean, int colorHex) {
    return VisualGuide(
      id: 'vowel_$vowel',
      title: '모음 "$korean" 발성 가이드',
      description: '"$korean" 모음의 정확한 입 모양과 혀 위치를 익혀보세요.',
      guideType: GuideType.mouthShape,
      
      highlights: [
        BodyHighlight(
          bodyPart: 'mouth',
          colorHex: colorHex,
          opacity: 0.8,
          pulse: true,
        ),
        BodyHighlight(
          bodyPart: 'tongue',
          colorHex: colorHex,
          opacity: 0.6,
          pulse: false,
        ),
      ],
      
      animations: [
        GuideAnimation(
          action: AnimationAction.expandContract,
          target: 'mouth',
          timing: vowel == 'a' ? 'wide open' : vowel == 'i' ? 'narrow' : 'medium',
          intensity: AnimationIntensity.medium,
        ),
      ],
      
      stepByStep: _getVowelSteps(vowel, korean),
      
      instructions: _getVowelInstructions(vowel, korean),
    );
  }
  
  static List<String> _getVowelSteps(String vowel, String korean) {
    switch (vowel) {
      case 'a':
        return [
          '1️⃣ 입을 크게 벌리고 턱을 자연스럽게 내려주세요',
          '2️⃣ 혀를 아래쪽에 평평하게 놓아주세요',
          '3️⃣ 목 안쪽을 넓게 열어주세요',
          '4️⃣ "$korean~" 소리를 길게 내보세요',
          '5️⃣ 공명이 입안에서 울리는지 확인하세요',
        ];
      case 'e':
        return [
          '1️⃣ 입을 옆으로 살짝 벌려주세요',
          '2️⃣ 혀의 중간 부분을 약간 올려주세요',
          '3️⃣ 입꼬리를 살짝 올려 미소 짓듯이 해주세요',
          '4️⃣ "$korean~" 소리를 명확하게 내보세요',
          '5️⃣ 밝은 음색이 나는지 확인하세요',
        ];
      case 'i':
        return [
          '1️⃣ 입을 가로로 벌려 미소를 지어주세요',
          '2️⃣ 혀를 위쪽 앞부분에 가까이 대주세요',
          '3️⃣ 치아를 살짝 보이게 해주세요',
          '4️⃣ "$korean~" 소리를 날카롭게 내보세요',
          '5️⃣ 머리 위쪽에서 울리는지 확인하세요',
        ];
      case 'o':
        return [
          '1️⃣ 입술을 동그랗게 모아주세요',
          '2️⃣ 입안 공간을 동그랗게 만들어주세요',
          '3️⃣ 혀를 뒤쪽으로 살짝 당겨주세요',
          '4️⃣ "$korean~" 소리를 둥글게 내보세요',
          '5️⃣ 깊고 풍부한 음색이 나는지 확인하세요',
        ];
      case 'u':
        return [
          '1️⃣ 입술을 작게 모아 뾰족하게 만들어주세요',
          '2️⃣ 혀를 뒤쪽 위로 올려주세요',
          '3️⃣ 입안을 좁고 깊게 만들어주세요',
          '4️⃣ "$korean~" 소리를 집중해서 내보세요',
          '5️⃣ 집중된 음색이 나는지 확인하세요',
        ];
      default:
        return [];
    }
  }
  
  static List<String> _getVowelInstructions(String vowel, String korean) {
    switch (vowel) {
      case 'a':
        return [
          '💡 **핵심**: 가장 열린 모음, 자연스러운 발성',
          '🎵 **음색**: 따뜻하고 풍부한 음색',
          '🎯 **적용**: 모든 장르의 기본 모음',
        ];
      case 'e':
        return [
          '💡 **핵심**: 밝고 명확한 발성',
          '🎵 **음색**: 밝고 선명한 음색',
          '🎯 **적용**: 명확한 딕션이 필요한 구간',
        ];
      case 'i':
        return [
          '💡 **핵심**: 가장 밝은 모음, 두성과 연결',
          '🎵 **음색**: 날카롭고 집중된 음색',
          '🎯 **적용**: 고음, 힘 있는 구간',
        ];
      case 'o':
        return [
          '💡 **핵심**: 둥글고 안정된 발성',
          '🎵 **음색**: 깊고 안정된 음색',
          '🎯 **적용**: 중저음, 서정적인 구간',
        ];
      case 'u':
        return [
          '💡 **핵심**: 가장 집중된 모음',
          '🎵 **음색**: 집중되고 깊은 음색',
          '🎯 **적용**: 저음, 강조하고 싶은 구간',
        ];
      default:
        return [];
    }
  }
}