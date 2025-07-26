import 'package:flutter/material.dart';

/// 향상된 앱 테마 - 현대적이고 세련된 디자인 시스템
class EnhancedAppTheme {
  // 프리미엄 다크 테마 컬러 팔레트
  static const Color primaryDark = Color(0xFF0D1B2A);
  static const Color secondaryDark = Color(0xFF1B263B);
  static const Color accentBlue = Color(0xFF415A77);
  static const Color accentLight = Color(0xFF778DA9);
  static const Color highlight = Color(0xFFE0E1DD);
  
  // 생동감 있는 액센트 컬러들
  static const Color neonGreen = Color(0xFF06FFA5);
  static const Color neonBlue = Color(0xFF4FACFE);
  static const Color neonPink = Color(0xFFFF6B9D);
  static const Color neonOrange = Color(0xFFFFB800);
  static const Color neonRed = Color(0xFFFF4757);
  
  // 그라데이션 정의
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient accentGradient = LinearGradient(
    colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient successGradient = LinearGradient(
    colors: [Color(0xFF06FFA5), Color(0xFF4FACFE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient warningGradient = LinearGradient(
    colors: [Color(0xFFFFB800), Color(0xFFFF8A00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient errorGradient = LinearGradient(
    colors: [Color(0xFFFF4757), Color(0xFFFF3742)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient backgroundGradient = RadialGradient(
    center: Alignment.topCenter,
    radius: 1.2,
    colors: [
      Color(0xFF1a1a2e),
      Color(0xFF16213e),
      Color(0xFF0f0f23),
    ],
  );
  
  // 글래스모피즘 효과
  static BoxDecoration get glassmorphism => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.1),
        Colors.white.withOpacity(0.05),
      ],
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: Colors.white.withOpacity(0.2),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );
  
  // 네온 글로우 효과
  static BoxDecoration neonGlow(Color color) => BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: color.withOpacity(0.3),
        blurRadius: 20,
        spreadRadius: 2,
      ),
      BoxShadow(
        color: color.withOpacity(0.6),
        blurRadius: 40,
        spreadRadius: 1,
      ),
    ],
  );
  
  // 카드 스타일
  static BoxDecoration get modernCard => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        secondaryDark,
        primaryDark,
      ],
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: accentBlue.withOpacity(0.3),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 15,
        offset: const Offset(0, 8),
      ),
    ],
  );
  
  // 버튼 스타일
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ).copyWith(
    backgroundColor: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.pressed)) {
        return accentBlue.withOpacity(0.8);
      }
      return null;
    }),
  );
  
  // 텍스트 스타일
  static const TextStyle headingLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: highlight,
    letterSpacing: -1,
  );
  
  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: highlight,
    letterSpacing: -0.5,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: accentLight,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: accentLight,
    height: 1.4,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w300,
    color: accentLight,
    letterSpacing: 0.5,
  );
  
  // 애니메이션 커브
  static const Curve defaultCurve = Curves.easeInOutCubic;
  static const Duration defaultDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 600);
  static const Duration fastDuration = Duration(milliseconds: 150);
  
  // 반응형 스페이싱
  static double getSpacing(BuildContext context, double baseSpacing) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return baseSpacing * 1.5;
    if (width > 800) return baseSpacing * 1.2;
    return baseSpacing;
  }
  
  // 반응형 폰트 크기
  static double getFontSize(BuildContext context, double baseFontSize) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return baseFontSize * 1.2;
    if (width > 800) return baseFontSize * 1.1;
    return baseFontSize;
  }
}

/// 커스텀 위젯 스타일 믹스인
mixin CustomWidgetStyles {
  // 호버 효과가 있는 카드
  Widget buildHoverCard({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets? padding,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: EnhancedAppTheme.defaultDuration,
        curve: EnhancedAppTheme.defaultCurve,
        decoration: EnhancedAppTheme.modernCard,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
  
  // 네온 버튼
  Widget buildNeonButton({
    required String text,
    required VoidCallback onPressed,
    required Color glowColor,
    IconData? icon,
  }) {
    return Container(
      decoration: EnhancedAppTheme.neonGlow(glowColor),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, color: Colors.white) : const SizedBox.shrink(),
        label: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: glowColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
  
  // 그라데이션 텍스트
  Widget buildGradientText({
    required String text,
    required Gradient gradient,
    required TextStyle style,
  }) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
  
  // 펄스 애니메이션 래퍼
  Widget buildPulseAnimation({
    required Widget child,
    required Animation<double> animation,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Transform.scale(
          scale: 1.0 + (animation.value * 0.1),
          child: child,
        );
      },
    );
  }
}

/// 테마별 아이콘 정의
class ThemeIcons {
  static const IconData microphone = Icons.mic;
  static const IconData microphoneOff = Icons.mic_off;
  static const IconData music = Icons.music_note;
  static const IconData headphones = Icons.headphones;
  static const IconData waveform = Icons.graphic_eq;
  static const IconData settings = Icons.tune;
  static const IconData analytics = Icons.analytics;
  static const IconData celebration = Icons.celebration;
  static const IconData trending = Icons.trending_up;
  static const IconData fire = Icons.local_fire_department;
  static const IconData star = Icons.star;
  static const IconData heart = Icons.favorite;
  static const IconData brain = Icons.psychology;
}

/// 커스텀 페인터들
class NeonPainter extends CustomPainter {
  final Color color;
  final double intensity;
  
  NeonPainter({required this.color, this.intensity = 1.0});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color primaryColor;
  final Color accentColor;
  final double animationValue;
  
  WaveformPainter({
    required this.waveformData,
    required this.primaryColor,
    required this.accentColor,
    this.animationValue = 1.0,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;
    
    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    
    final barWidth = size.width / waveformData.length;
    
    for (int i = 0; i < waveformData.length; i++) {
      final x = i * barWidth;
      final height = waveformData[i] * size.height * animationValue;
      final y = (size.height - height) / 2;
      
      // 그라데이션 효과
      final progress = i / waveformData.length;
      paint.color = Color.lerp(primaryColor, accentColor, progress)!;
      
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + height),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}