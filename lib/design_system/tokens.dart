import 'package:flutter/material.dart';

/// Shadcn UI 디자인 토큰 - Flutter 변환
/// 
/// Shadcn의 CSS 변수를 Flutter의 상수로 변환
/// 보컬 트레이닝 앱에 최적화된 색상과 타이포그래피 포함
class DesignTokens {
  // ===========================================
  // SHADCN CORE COLORS (라이트/다크 모드 지원)
  // ===========================================
  
  // Background colors
  static const Color background = Color(0xFFFFFFFF);     // hsl(0 0% 100%) | dark: hsl(240 10% 3.9%)
  static const Color foreground = Color(0xFF0A0A0B);     // hsl(240 10% 3.9%) | dark: hsl(0 0% 98%)
  
  // Card colors  
  static const Color card = Color(0xFFFFFFFF);           // hsl(0 0% 100%) | dark: hsl(240 10% 3.9%)
  static const Color cardForeground = Color(0xFF0A0A0B); // hsl(240 10% 3.9%) | dark: hsl(0 0% 98%)
  
  // Popover colors
  static const Color popover = Color(0xFFFFFFFF);        // hsl(0 0% 100%) | dark: hsl(240 10% 3.9%)
  static const Color popoverForeground = Color(0xFF0A0A0B); // hsl(240 10% 3.9%) | dark: hsl(0 0% 98%)
  
  // Primary colors
  static const Color primary = Color(0xFF0F172A);        // hsl(222.2 84% 4.9%) | dark: hsl(210 40% 98%)
  static const Color primaryForeground = Color(0xFFF8FAFC); // hsl(210 40% 98%) | dark: hsl(222.2 47.4% 11.2%)
  
  // Secondary colors
  static const Color secondary = Color(0xFFF1F5F9);      // hsl(210 40% 96%) | dark: hsl(217.2 32.6% 17.5%)
  static const Color secondaryForeground = Color(0xFF0F172A); // hsl(222.2 84% 4.9%) | dark: hsl(210 40% 98%)
  
  // Muted colors
  static const Color muted = Color(0xFFF1F5F9);          // hsl(210 40% 96%) | dark: hsl(217.2 32.6% 17.5%)
  static const Color mutedForeground = Color(0xFF64748B); // hsl(215.4 16.3% 46.9%) | dark: hsl(215 20.2% 65.1%)
  
  // Accent colors
  static const Color accent = Color(0xFFF1F5F9);         // hsl(210 40% 96%) | dark: hsl(217.2 32.6% 17.5%)
  static const Color accentForeground = Color(0xFF0F172A); // hsl(222.2 84% 4.9%) | dark: hsl(210 40% 98%)
  
  // Destructive colors
  static const Color destructive = Color(0xFFEF4444);    // hsl(0 84.2% 60.2%) | dark: hsl(0 62.8% 30.6%)
  static const Color destructiveForeground = Color(0xFFF8FAFC); // hsl(210 40% 98%) | dark: hsl(210 40% 98%)
  
  // Border and input
  static const Color border = Color(0xFFE2E8F0);         // hsl(214.3 31.8% 91.4%) | dark: hsl(217.2 32.6% 17.5%)
  static const Color input = Color(0xFFE2E8F0);          // hsl(214.3 31.8% 91.4%) | dark: hsl(217.2 32.6% 17.5%)
  static const Color ring = Color(0xFF0F172A);           // hsl(222.2 84% 4.9%) | dark: hsl(212.7 26.8% 83.9%)
  
  // ===========================================
  // VOCAL TRAINING 특화 색상
  // ===========================================
  
  // 피치 정확도 색상 (shadcn 팔레트 기반)
  static const Color success = Color(0xFF10B981);        // 완벽한 피치 (emerald-500)
  static const Color warning = Color(0xFFF59E0B);        // 근사한 피치 (amber-500)  
  static const Color error = Color(0xFFEF4444);          // 부정확한 피치 (red-500)
  static const Color info = Color(0xFF3B82F6);           // 정보성 피치 (blue-500)
  
  // 피치 시각화 전용 색상
  static const Color pitchTarget = Color(0xFF0F172A);    // 목표 피치 라인
  static const Color pitchCurrent = Color(0xFF3B82F6);   // 현재 피치 라인
  static const Color pitchBackground = Color(0xFFF8FAFC); // 피치 그래프 배경
  
  // ===========================================
  // SHADCN 타이포그래피 시스템
  // ===========================================
  
  static const TextStyle h1 = TextStyle(
    fontSize: 36,                    // text-4xl
    fontWeight: FontWeight.w800,     // font-extrabold
    letterSpacing: -0.02,            // tracking-tight
    height: 1.1,                     // leading-none
  );
  
  static const TextStyle h2 = TextStyle(
    fontSize: 30,                    // text-3xl
    fontWeight: FontWeight.w700,     // font-bold
    letterSpacing: -0.025,           // tracking-tight
    height: 1.2,                     // leading-tight
  );
  
  static const TextStyle h3 = TextStyle(
    fontSize: 24,                    // text-2xl
    fontWeight: FontWeight.w600,     // font-semibold
    letterSpacing: -0.02,            // tracking-tight
    height: 1.25,                    // leading-tight
  );
  
  static const TextStyle h4 = TextStyle(
    fontSize: 20,                    // text-xl
    fontWeight: FontWeight.w600,     // font-semibold
    letterSpacing: -0.01,            // tracking-tight
    height: 1.3,                     // leading-snug
  );
  
  static const TextStyle body = TextStyle(
    fontSize: 16,                    // text-base
    fontWeight: FontWeight.w400,     // font-normal
    letterSpacing: 0,                // tracking-normal
    height: 1.5,                     // leading-normal
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,                    // text-sm
    fontWeight: FontWeight.w400,     // font-normal
    letterSpacing: 0,                // tracking-normal
    height: 1.43,                    // leading-normal
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,                    // text-xs
    fontWeight: FontWeight.w400,     // font-normal
    letterSpacing: 0.02,             // tracking-wide
    height: 1.33,                    // leading-normal
  );
  
  static const TextStyle button = TextStyle(
    fontSize: 16,                    // text-base
    fontWeight: FontWeight.w500,     // font-medium
    letterSpacing: 0.01,             // tracking-wide
    height: 1.0,                     // leading-none
  );
  
  // ===========================================
  // SHADCN 스페이싱 시스템 (Tailwind 기반)
  // ===========================================
  
  static const double space0_5 = 2;   // space-0.5
  static const double space1 = 4;     // space-1
  static const double space1_5 = 6;   // space-1.5
  static const double space2 = 8;     // space-2
  static const double space2_5 = 10;  // space-2.5
  static const double space3 = 12;    // space-3
  static const double space3_5 = 14;  // space-3.5
  static const double space4 = 16;    // space-4
  static const double space5 = 20;    // space-5
  static const double space6 = 24;    // space-6
  static const double space7 = 28;    // space-7
  static const double space8 = 32;    // space-8
  static const double space9 = 36;    // space-9
  static const double space10 = 40;   // space-10
  static const double space11 = 44;   // space-11
  static const double space12 = 48;   // space-12
  static const double space14 = 56;   // space-14
  static const double space16 = 64;   // space-16
  static const double space20 = 80;   // space-20
  static const double space24 = 96;   // space-24
  static const double space28 = 112;  // space-28
  static const double space32 = 128;  // space-32
  
  // ===========================================
  // SHADCN 반지름 시스템 (Tailwind 기반)
  // ===========================================
  
  static const double radiusNone = 0;        // rounded-none
  static const double radiusSm = 2;         // rounded-sm
  static const double radiusDefault = 4;    // rounded (기본값)
  static const double radiusMd = 6;         // rounded-md  
  static const double radiusLg = 8;         // rounded-lg
  static const double radiusXl = 12;        // rounded-xl
  static const double radius2xl = 16;       // rounded-2xl
  static const double radius3xl = 24;       // rounded-3xl
  static const double radiusFull = 9999;    // rounded-full
  
  // ===========================================
  // 그림자 시스템 (Tailwind 기반)
  // ===========================================
  
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];
  
  static List<BoxShadow> get shadowDefault => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];
  
  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 15,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
  ];
  
  // ===========================================
  // 유틸리티 메서드
  // ===========================================
  
  /// 피치 정확도에 따른 색상 반환
  static Color pitchAccuracyColor(double accuracy) {
    if (accuracy >= 0.95) return success;      // 95% 이상: 완벽
    if (accuracy >= 0.85) return info;         // 85% 이상: 좋음
    if (accuracy >= 0.70) return warning;      // 70% 이상: 보통
    return error;                              // 70% 미만: 개선 필요
  }
  
  /// 신뢰도에 따른 투명도 적용
  static Color withConfidence(Color color, double confidence) {
    return color.withOpacity(0.3 + (confidence * 0.7));
  }
  
  /// 다크 모드 지원 색상
  static Color adaptiveColor(Color lightColor, Color darkColor, bool isDark) {
    return isDark ? darkColor : lightColor;
  }
}

/// 다크 모드 토큰 (향후 구현 예정)
class DarkDesignTokens {
  // Dark mode colors
  static const Color background = Color(0xFF0A0A0B);     // dark background
  static const Color foreground = Color(0xFFFAFAFA);     // dark foreground
  static const Color card = Color(0xFF09090B);           // dark card
  static const Color cardForeground = Color(0xFFFAFAFA); // dark card foreground
  
  // 다크 모드에서의 피치 시각화 색상
  static const Color pitchTarget = Color(0xFFFAFAFA);    // 목표 피치 라인 (밝게)
  static const Color pitchCurrent = Color(0xFF60A5FA);   // 현재 피치 라인 (blue-400)
  static const Color pitchBackground = Color(0xFF09090B); // 피치 그래프 배경 (어둡게)
}