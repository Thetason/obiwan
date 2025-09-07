class CoachTemplates {
  static List<String> fromMetrics({
    required double medianCents,
    required double stability,
    required double vibratoRateHz,
    required double vibratoExtentCents,
  }) {
    final tips = <String>[];
    if (medianCents < -20) {
      tips.add('시작 음이 낮게 잡혀요. 첫 소절을 허밍→입 열기로 전환해 보세요.');
    } else if (medianCents > 20) {
      tips.add('음이 높게 치우쳐요. 들숨 후 첫 음에서 호흡 압을 조금 낮춰보세요.');
    }
    if (stability > 200) {
      tips.add('피치 흔들림이 커요. 길게 한 음 유지 후 천천히 다음 음으로 넘어가 보세요.');
    }
    if (vibratoRateHz > 8.0) {
      tips.add('비브라토가 빠릅니다(>8Hz). 6–7Hz 목표로 천천히 흔들어보세요.');
    } else if (vibratoExtentCents > 100) {
      tips.add('비브라토 폭이 커요(>100¢). 중심선 주변에서 작게 시작해보세요.');
    }
    if (tips.isEmpty) {
      tips.add('좋아요! 현재 정확도를 유지하며 프레이즈 전체를 연결해보세요.');
    }
    return tips.take(2).toList();
  }
}

