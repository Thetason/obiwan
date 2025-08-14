import 'package:flutter/material.dart';
import '../design_system/tokens.dart';

/// Shadcn 기반 보컬 트레이닝 색상 시스템
/// 기존 Nike 스타일에서 shadcn의 미니멀하고 접근성 높은 색상으로 전환
/// 
/// @deprecated 이 클래스는 레거시 호환성을 위해 유지되며, 
/// 새로운 컴포넌트는 DesignTokens를 직접 사용하세요.
class PitchColors {
  // === SHADCN 기반 피치 정확도 색상 (레거시 호환) ===
  static const Color perfect = DesignTokens.success;     // 완벽한 정확도 (90%+) 
  static const Color close = DesignTokens.info;          // 근접한 정확도 (70-90%)
  static const Color off = DesignTokens.error;           // 부정확 (<70%)
  static const Color neutral = DesignTokens.muted;       // 중성 상태
  static const Color warning = DesignTokens.warning;     // 경고
  
  // === 레거시 호환성을 위한 색상 매핑 ===
  @deprecated
  static const Color electricBlue = DesignTokens.info;   // -> info로 매핑
  @deprecated
  static const Color neonGreen = DesignTokens.success;   // -> success로 매핑
  @deprecated
  static const Color hotPink = DesignTokens.error;       // -> error로 매핑
  @deprecated
  static const Color neonYellow = DesignTokens.warning;  // -> warning으로 매핑
  @deprecated
  static const Color purpleGlow = DesignTokens.accent;   // -> accent로 매핑
  
  // === Shadcn 기반 배경 색상 (레거시 호환) ===
  @deprecated
  static const Color backgroundStart = DesignTokens.background;
  @deprecated
  static const Color backgroundEnd = DesignTokens.card;
  @deprecated
  static const Color cardDark = DesignTokens.card;
  @deprecated
  static const Color cardAccent = DesignTokens.accent;
  
  // === 글로우 효과 (shadcn 스타일로 변경) ===
  @deprecated
  static const Color glowSuccess = DesignTokens.success;
  @deprecated
  static const Color glowWarning = DesignTokens.warning;
  @deprecated
  static const Color glowError = DesignTokens.error;
  
  // === 레거시 색상 (호환성 유지) ===
  @deprecated
  static const Color forceDark = DesignTokens.primary;
  @deprecated
  static const Color forceLight = DesignTokens.background;
  
  // === 신뢰도 기반 투명도 (shadcn 방식) ===
  static Color withConfidence(Color color, double confidence) {
    return DesignTokens.withConfidence(color, confidence);
  }
  
  // === 정확도 기반 색상 매핑 (shadcn 색상 사용) ===
  static Color fromAccuracy(double accuracy) {
    return DesignTokens.pitchAccuracyColor(accuracy);
  }
  
  // === Shadcn 스타일 그라데이션 (미니멀) ===
  static LinearGradient pitchGradient(double accuracy) {
    final color = fromAccuracy(accuracy);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color,
        color.withOpacity(0.8),
        color.withOpacity(0.5),
      ],
      stops: const [0.0, 0.6, 1.0],
    );
  }
  
  // === Shadcn 스타일 배경 (클린) ===
  static LinearGradient nikeBackground() {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        DesignTokens.background,
        DesignTokens.card,
      ],
    );
  }
  
  // === 서브틀한 글로우 효과 (shadcn 스타일) ===
  static RadialGradient athleticGlow(Color color, {double intensity = 0.3}) {
    // shadcn 스타일: 매우 서브틀한 글로우
    return RadialGradient(
      colors: [
        color.withOpacity(intensity * 0.3),
        color.withOpacity(intensity * 0.2), 
        color.withOpacity(intensity * 0.1),
        color.withOpacity(0.0),
      ],
      stops: const [0.0, 0.4, 0.7, 1.0],
    );
  }
  
  // === Shadcn 스타일 데이터 시각화 그라데이션 ===
  static LinearGradient dataVisualizationGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        DesignTokens.info,
        DesignTokens.success,
        DesignTokens.warning,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }
}

/// 새로운 Shadcn 기반 보컬 트레이닝 테마
/// 
/// 기존 PitchColors를 완전히 대체할 새로운 테마 시스템
/// 모든 새로운 컴포넌트는 이 테마를 사용하세요.
class VocalTrainingTheme {
  // === 피치 시각화 특화 색상 ===
  static const Color pitchPerfect = DesignTokens.success;     // 완벽한 피치
  static const Color pitchGood = DesignTokens.info;           // 좋은 피치
  static const Color pitchFair = DesignTokens.warning;        // 보통 피치
  static const Color pitchPoor = DesignTokens.error;          // 개선 필요 피치
  
  // === 상태별 색상 ===
  static const Color recording = Color(0xFFDC2626);          // 녹음 상태 (red-600)
  static const Color playing = Color(0xFF2563EB);            // 재생 상태 (blue-600)
  static const Color analyzing = Color(0xFF7C3AED);          // 분석 상태 (violet-600)
  static const Color completed = DesignTokens.success;       // 완료 상태
  
  // === 음성 특성별 색상 ===
  static const Color vibrato = Color(0xFF10B981);            // 비브라토 (emerald-500)
  static const Color timbre = Color(0xFF8B5CF6);             // 음색 (violet-500)
  static const Color pitch = Color(0xFF3B82F6);              // 피치 (blue-500)
  static const Color rhythm = Color(0xFFF59E0B);             // 리듬 (amber-500)
  
  // === 레벨별 색상 (게이미피케이션) ===
  static const Color levelBeginner = Color(0xFF84CC16);      // 초급 (lime-500)
  static const Color levelIntermediate = Color(0xFFF59E0B);  // 중급 (amber-500)  
  static const Color levelAdvanced = Color(0xFFEF4444);      // 고급 (red-500)
  static const Color levelExpert = Color(0xFF8B5CF6);        // 전문가 (violet-500)
  
  // === 그라데이션 ===
  static LinearGradient get recordingGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [recording, recording.withOpacity(0.7)],
  );
  
  static LinearGradient get playingGradient => LinearGradient(
    begin: Alignment.topLeft, 
    end: Alignment.bottomRight,
    colors: [playing, playing.withOpacity(0.7)],
  );
  
  static LinearGradient get analyzingGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight, 
    colors: [analyzing, analyzing.withOpacity(0.7)],
  );
}