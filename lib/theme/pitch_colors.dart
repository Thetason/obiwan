import 'package:flutter/material.dart';

/// 오비완 v3 색상 코딩 시스템
/// 신호등 패턴을 적용한 피치 정확도 피드백 색상
class PitchColors {
  // 피치 정확도 색상 (신호등 패턴)
  static const Color perfect = Color(0xFF4CAF50);    // 초록: 정확 (90%+)
  static const Color close = Color(0xFFFFC107);      // 노랑: 근접 (70-90%)
  static const Color off = Color(0xFFF44336);        // 빨강: 벗어남 (<70%)
  static const Color neutral = Color(0xFF9E9E9E);    // 회색: 기본 상태
  static const Color warning = Color(0xFFFF9800);    // 주황: 경고 상태
  
  // Force 테마 색상 (스타워즈 컨셉)
  static const Color forceLight = Color(0xFF2196F3);  // 파란 포스 (라이트사이드)
  static const Color forceDark = Color(0xFFD32F2F);   // 빨간 포스 (다크사이드)
  static const Color forceBalance = Color(0xFF9C27B0); // 보라 (밸런스)
  
  // 배경 및 UI 색상
  static const Color backgroundDark = Color(0xFF1A1A2E);
  static const Color backgroundLight = Color(0xFFF8F9FE);
  static const Color cardDark = Color(0xFF16213E);
  static const Color cardLight = Color(0xFFFFFFFF);
  
  // 애니메이션 효과 색상
  static const Color glowSuccess = Color(0xFF00E676);
  static const Color glowWarning = Color(0xFFFFD600);
  static const Color glowError = Color(0xFFFF1744);
  
  // 투명도 변화를 위한 메서드
  static Color withConfidence(Color color, double confidence) {
    // confidence (0.0 ~ 1.0)에 따라 투명도 조절
    return color.withOpacity(0.3 + (confidence * 0.7));
  }
  
  // 정확도에 따른 색상 반환
  static Color fromAccuracy(double accuracy) {
    if (accuracy >= 0.9) return perfect;
    if (accuracy >= 0.7) return close;
    if (accuracy >= 0.5) return off;
    return neutral;
  }
  
  // 그라데이션 생성
  static LinearGradient pitchGradient(double accuracy) {
    final color = fromAccuracy(accuracy);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withOpacity(0.8),
        color.withOpacity(0.3),
      ],
    );
  }
  
  // Force 효과 그라데이션
  static RadialGradient forceGlow(bool isAccurate) {
    final color = isAccurate ? forceLight : forceDark;
    return RadialGradient(
      colors: [
        color.withOpacity(0.8),
        color.withOpacity(0.4),
        color.withOpacity(0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }
}