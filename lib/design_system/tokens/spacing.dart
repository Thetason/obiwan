/// Voice Journey 간격 시스템
/// 8px 기반의 일관된 스페이싱
class VJSpacing {
  // Base unit = 4px
  static const double unit = 4.0;
  
  // Spacing scale
  static const double xxs = unit * 1;   // 4px
  static const double xs = unit * 2;    // 8px
  static const double sm = unit * 3;    // 12px
  static const double md = unit * 4;    // 16px
  static const double lg = unit * 6;    // 24px
  static const double xl = unit * 8;    // 32px
  static const double xxl = unit * 12;  // 48px
  static const double xxxl = unit * 16; // 64px
  
  // Component specific
  static const double buttonPaddingX = md;
  static const double buttonPaddingY = sm;
  static const double cardPadding = lg;
  static const double screenPadding = md;
  static const double sectionGap = xl;
  
  // Border radius
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusRound = 999.0;
  
  // Icon sizes
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;
  
  // Component heights
  static const double buttonHeightSm = 32.0;
  static const double buttonHeightMd = 44.0;
  static const double buttonHeightLg = 56.0;
  
  // Animation durations (milliseconds)
  static const int animationFast = 150;
  static const int animationNormal = 300;
  static const int animationSlow = 500;
  static const int animationVerySlow = 800;
}