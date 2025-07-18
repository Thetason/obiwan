import '../../domain/entities/vocal_analysis.dart';
import '../../domain/entities/visual_guide.dart';

class RuleBasedCoach {
  static const Map<String, List<String>> exerciseDatabase = {
    'breathing': [
      '복식호흡 연습: 배에 손을 대고 숨을 깊게 들이마시세요.',
      '4-7-8 호흡법: 4초 들이마시고, 7초 참고, 8초 내쉬세요.',
      '립트릴 연습: 입술을 떨며 "브르르" 소리를 내세요.',
      '스트로우 발성: 스트로우를 물고 "우" 소리로 스케일 연습하세요.',
    ],
    'posture': [
      '벽에 등을 대고 서서 올바른 자세를 익히세요.',
      '어깨를 뒤로 젖히고 가슴을 펴세요.',
      '턱을 살짝 당기고 목을 길게 늘이세요.',
      '발을 어깨 너비로 벌리고 무릎을 살짝 구부리세요.',
    ],
    'resonance': [
      '허밍으로 공명 위치를 찾아보세요.',
      '마스크 영역(얼굴 앞쪽)에 진동을 느끼며 발성하세요.',
      '"엥" 소리로 비강 공명을 연습하세요.',
      '입을 다문 채로 "음마음마" 발성 연습하세요.',
    ],
    'mouth_shape': [
      '모음 "아에이오우"를 정확한 입 모양으로 연습하세요.',
      '거울을 보며 입 모양을 확인하세요.',
      '혀의 위치를 의식하며 발성하세요.',
      '입술 모양을 과장되게 연습한 후 자연스럽게 줄여보세요.',
    ],
    'pitch': [
      '피아노와 함께 음정 맞추기 연습하세요.',
      '스케일을 천천히 올라가며 정확한 음정을 익히세요.',
      '좋아하는 노래의 멜로디를 따라 불러보세요.',
      '음정이 흔들리지 않도록 한 음을 길게 내보세요.',
    ],
    'vibrato': [
      '자연스러운 비브라토를 위해 목과 턱의 힘을 빼세요.',
      '복부 근육을 의식하며 지지하는 연습을 하세요.',
      '과도한 비브라토는 피하고 자연스럽게 나오도록 하세요.',
      '직음으로 충분히 연습한 후 비브라토를 추가하세요.',
    ],
  };
  
  String generateAdvice(VocalAnalysis analysis) {
    final priority = _determinePriority(analysis);
    
    switch (priority) {
      case CoachingPriority.breathing:
        return _generateBreathingAdvice(analysis);
      case CoachingPriority.posture:
        return _generatePostureAdvice(analysis);
      case CoachingPriority.resonance:
        return _generateResonanceAdvice(analysis);
      case CoachingPriority.pitch:
        return _generatePitchAdvice(analysis);
      case CoachingPriority.vibrato:
        return _generateVibratoAdvice(analysis);
      case CoachingPriority.mouthShape:
        return _generateMouthShapeAdvice(analysis);
    }
  }
  
  List<String> generateExercises(VocalAnalysis analysis) {
    final exercises = <String>[];
    
    // 호흡 문제
    if (analysis.breathingType == BreathingType.chest) {
      exercises.addAll(exerciseDatabase['breathing']!.take(2));
    }
    
    // 피치 안정성 문제
    if (analysis.pitchStability < 70) {
      exercises.addAll(exerciseDatabase['pitch']!.take(2));
    }
    
    // 공명 문제
    if (analysis.resonancePosition == ResonancePosition.throat) {
      exercises.addAll(exerciseDatabase['resonance']!.take(2));
    }
    
    // 비브라토 문제
    if (analysis.vibratoQuality == VibratoQuality.heavy) {
      exercises.addAll(exerciseDatabase['vibrato']!.take(1));
    }
    
    // 입 모양 문제
    if (_needsMouthShapeWork(analysis)) {
      exercises.addAll(exerciseDatabase['mouth_shape']!.take(1));
    }
    
    // 자세 문제
    if (analysis.pitchStability < 60) {
      exercises.addAll(exerciseDatabase['posture']!.take(1));
    }
    
    return exercises.take(5).toList(); // 최대 5개 연습
  }
  
  CoachingPriority _determinePriority(VocalAnalysis analysis) {
    // 우선순위 결정 로직 (가장 중요한 문제부터)
    
    // 1. 호흡 문제가 가장 심각
    if (analysis.breathingType == BreathingType.chest) {
      return CoachingPriority.breathing;
    }
    
    // 2. 피치 안정성 문제
    if (analysis.pitchStability < 50) {
      return CoachingPriority.pitch;
    }
    
    // 3. 자세 문제 (피치 안정성과 연관)
    if (analysis.pitchStability < 70) {
      return CoachingPriority.posture;
    }
    
    // 4. 공명 위치 문제
    if (analysis.resonancePosition == ResonancePosition.throat) {
      return CoachingPriority.resonance;
    }
    
    // 5. 과도한 비브라토
    if (analysis.vibratoQuality == VibratoQuality.heavy) {
      return CoachingPriority.vibrato;
    }
    
    // 6. 입 모양 문제
    return CoachingPriority.mouthShape;
  }
  
  String _generateBreathingAdvice(VocalAnalysis analysis) {
    switch (analysis.breathingType) {
      case BreathingType.chest:
        return "흉식호흡을 사용하고 있습니다. 복식호흡을 연습해보세요. "
               "배에 손을 대고 숨을 들이마실 때 배가 나오도록 해보세요. "
               "가슴의 움직임은 최소화하고 횡격막을 의식하며 호흡하세요.";
      case BreathingType.mixed:
        return "혼합 호흡을 사용하고 있습니다. 조금 더 복식호흡에 집중해보세요. "
               "깊고 안정적인 호흡이 좋은 발성의 기초입니다.";
      case BreathingType.diaphragmatic:
        return "복식호흡을 잘하고 있습니다! 이 호흡법을 유지하면서 "
               "더 깊고 안정적인 호흡을 연습해보세요.";
    }
  }
  
  String _generatePostureAdvice(VocalAnalysis analysis) {
    return "자세가 발성에 영향을 주고 있을 수 있습니다. "
           "척추를 곧게 세우고 어깨를 뒤로 젖히세요. "
           "턱을 살짝 당기고 목을 길게 늘이는 느낌으로 서보세요. "
           "올바른 자세는 호흡과 발성 모두에 도움이 됩니다.";
  }
  
  String _generateResonanceAdvice(VocalAnalysis analysis) {
    switch (analysis.resonancePosition) {
      case ResonancePosition.throat:
        return "목 공명을 사용하고 있습니다. 소리를 앞쪽(마스크 영역)으로 보내보세요. "
               "얼굴 앞쪽에 진동을 느끼며 발성하고, 목에 힘을 빼세요. "
               "허밍으로 공명 위치를 찾는 연습을 해보세요.";
      case ResonancePosition.mouth:
        return "구강 공명을 사용하고 있습니다. 좋은 시작이지만 "
               "조금 더 앞쪽과 위쪽으로 소리를 보내보세요.";
      case ResonancePosition.head:
        return "두성을 사용하고 있습니다. 좋은 공명이지만 "
               "중저음에서도 안정적인 공명을 유지해보세요.";
      case ResonancePosition.mixed:
        return "혼합 공명을 사용하고 있습니다. 훌륭합니다! "
               "이 균형을 유지하며 더욱 안정적인 공명을 연습해보세요.";
    }
  }
  
  String _generatePitchAdvice(VocalAnalysis analysis) {
    if (analysis.pitchStability < 50) {
      return "음정이 매우 불안정합니다. 천천히 한 음을 길게 내며 "
             "정확한 음정을 유지하는 연습을 해보세요. "
             "피아노와 함께 연습하면 도움이 됩니다.";
    } else if (analysis.pitchStability < 70) {
      return "음정이 약간 불안정합니다. 호흡 지지를 강화하고 "
             "편안한 자세로 발성해보세요. "
             "목과 턱의 긴장을 풀어주세요.";
    } else {
      return "음정이 비교적 안정적입니다. 이 상태를 유지하며 "
             "더 다양한 음역대에서 연습해보세요.";
    }
  }
  
  String _generateVibratoAdvice(VocalAnalysis analysis) {
    switch (analysis.vibratoQuality) {
      case VibratoQuality.none:
        return "비브라토가 없습니다. 자연스러운 비브라토를 위해 "
               "목과 턱의 힘을 빼고 복부 지지를 강화해보세요.";
      case VibratoQuality.light:
        return "가벼운 비브라토를 사용하고 있습니다. 좋은 상태입니다. "
               "필요에 따라 조금 더 강화해보세요.";
      case VibratoQuality.medium:
        return "적절한 비브라토를 사용하고 있습니다. 완벽합니다! "
               "이 자연스러운 비브라토를 유지하세요.";
      case VibratoQuality.heavy:
        return "비브라토가 과도합니다. 목과 턱의 힘을 더 빼고 "
               "직음으로 충분히 연습한 후 자연스럽게 비브라토를 추가해보세요.";
    }
  }
  
  String _generateMouthShapeAdvice(VocalAnalysis analysis) {
    final mouthAdvice = _getMouthOpeningAdvice(analysis.mouthOpening);
    final tongueAdvice = _getTonguePositionAdvice(analysis.tonguePosition);
    
    return "$mouthAdvice $tongueAdvice 거울을 보며 입 모양을 확인하고 연습하세요.";
  }
  
  String _getMouthOpeningAdvice(MouthOpening opening) {
    switch (opening) {
      case MouthOpening.narrow:
        return "입 벌림이 좁습니다. 조금 더 입을 벌리고 턱을 편안하게 내려보세요.";
      case MouthOpening.medium:
        return "적절한 입 벌림입니다.";
      case MouthOpening.wide:
        return "입 벌림이 넓습니다. 과도하지 않게 조절해보세요.";
    }
  }
  
  String _getTonguePositionAdvice(TonguePosition position) {
    switch (position) {
      case TonguePosition.highFront:
        return "혀가 높고 앞쪽에 있습니다. 모음에 따라 혀 위치를 조절해보세요.";
      case TonguePosition.highBack:
        return "혀가 높고 뒤쪽에 있습니다. 목구멍이 막히지 않도록 주의하세요.";
      case TonguePosition.lowFront:
        return "혀가 낮고 앞쪽에 있습니다. 좋은 위치입니다.";
      case TonguePosition.lowBack:
        return "혀가 낮고 뒤쪽에 있습니다. 공명 공간이 잘 확보되어 있습니다.";
    }
  }
  
  bool _needsMouthShapeWork(VocalAnalysis analysis) {
    // 입 모양이나 혀 위치가 문제가 있는지 판단
    return analysis.mouthOpening == MouthOpening.narrow ||
           analysis.tonguePosition == TonguePosition.highBack;
  }
  
  // 개선 제안 생성
  List<String> generateImprovementSuggestions(VocalAnalysis analysis) {
    final suggestions = <String>[];
    
    // 점수별 격려 메시지
    if (analysis.overallScore >= 80) {
      suggestions.add("훌륭한 발성입니다! 이 수준을 유지하며 더 도전적인 곡을 연습해보세요.");
    } else if (analysis.overallScore >= 60) {
      suggestions.add("좋은 발성입니다. 몇 가지 개선점을 보완하면 더욱 좋아질 것입니다.");
    } else {
      suggestions.add("발성에 개선이 필요합니다. 기본기부터 차근차근 연습해보세요.");
    }
    
    // 구체적인 개선 제안
    if (analysis.breathingType != BreathingType.diaphragmatic) {
      suggestions.add("호흡 연습을 매일 5-10분씩 해보세요.");
    }
    
    if (analysis.pitchStability < 70) {
      suggestions.add("음정 연습을 위해 피아노나 튜너 앱을 활용해보세요.");
    }
    
    if (analysis.resonancePosition == ResonancePosition.throat) {
      suggestions.add("목 공명에서 벗어나기 위해 허밍 연습을 해보세요.");
    }
    
    return suggestions;
  }
  
  // 연습 계획 생성
  Map<String, List<String>> generatePracticePlan(VocalAnalysis analysis) {
    final plan = <String, List<String>>{};
    
    // 우선순위에 따른 연습 계획
    final priority = _determinePriority(analysis);
    
    switch (priority) {
      case CoachingPriority.breathing:
        plan['1주차'] = ['복식호흡 기본 연습', '4-7-8 호흡법', '호흡 지지 연습'];
        plan['2주차'] = ['립트릴 연습', '스트로우 발성', '호흡과 발성 연결'];
        plan['3주차'] = ['긴 프레이즈 연습', '다양한 음역대 호흡', '노래 적용'];
        break;
      case CoachingPriority.pitch:
        plan['1주차'] = ['음정 인식 연습', '스케일 연습', '한 음 길게 내기'];
        plan['2주차'] = ['음정 변화 연습', '도약 연습', '멜로디 따라하기'];
        plan['3주차'] = ['복잡한 멜로디', '즉흥 연습', '노래 적용'];
        break;
      case CoachingPriority.resonance:
        plan['1주차'] = ['허밍 연습', '마스크 공명 찾기', '공명 위치 인식'];
        plan['2주차'] = ['다양한 모음 공명', '음역별 공명', '공명 안정화'];
        plan['3주차'] = ['표현적 공명', '감정과 공명', '노래 적용'];
        break;
      default:
        plan['1주차'] = ['기본 발성 연습', '자세 교정', '호흡 연습'];
        plan['2주차'] = ['음정 연습', '공명 연습', '표현 연습'];
        plan['3주차'] = ['종합 연습', '노래 적용', '개인별 보완'];
    }
    
    return plan;
  }
}

enum CoachingPriority {
  breathing,
  pitch,
  posture,
  resonance,
  vibrato,
  mouthShape,
}