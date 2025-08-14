import 'package:flutter/material.dart';

/// Voice Journey 색상 시스템
/// 나이키 러닝 클럽의 깔끔함 + 젤다의 희망적 톤
class VJColors {
  // Primary - 따뜻한 코랄/살몬 (열정, 시작)
  static const Color primary = Color(0xFFFF6B6B);
  static const Color primaryLight = Color(0xFFFFE5E5);
  static const Color primaryDark = Color(0xFFE55555);
  
  // Secondary - 민트/터콰이즈 (성장, 신선함)
  static const Color secondary = Color(0xFF4ECDC4);
  static const Color secondaryLight = Color(0xFFE0F9F7);
  static const Color secondaryDark = Color(0xFF38A39A);
  
  // Accent - 라벤더 (평온, 집중)
  static const Color accent = Color(0xFF9B84EC);
  static const Color accentLight = Color(0xFFF0EDFF);
  static const Color accentDark = Color(0xFF7B64CC);
  
  // Success/Error/Warning
  static const Color success = Color(0xFF52C41A);
  static const Color error = Color(0xFFFF4757);
  static const Color warning = Color(0xFFFFA502);
  static const Color info = Color(0xFF1890FF);
  
  // Neutral - 깔끔한 그레이스케일
  static const Color black = Color(0xFF1A1A1A);
  static const Color gray900 = Color(0xFF2D3436);
  static const Color gray700 = Color(0xFF636E72);
  static const Color gray600 = Color(0xFF7B8A8B);
  static const Color gray500 = Color(0xFF95A5A6);
  static const Color gray400 = Color(0xFFB2BEC3);
  static const Color gray300 = Color(0xFFDFE6E9);
  static const Color gray200 = Color(0xFFECF0F1);
  static const Color gray100 = Color(0xFFF5F6FA);
  static const Color white = Color(0xFFFFFFFF);
  
  // Background
  static const Color background = Color(0xFFFBFCFD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF8F9FA);
  
  // Gradients - 부드러운 그라데이션
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFFF6B9D), Color(0xFFFECA57)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient oceanGradient = LinearGradient(
    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Shadows - 부드러운 그림자
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: black.withOpacity(0.02),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> mediumShadow = [
    BoxShadow(
      color: black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: black.withOpacity(0.04),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];
  
  static List<BoxShadow> strongShadow = [
    BoxShadow(
      color: black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: black.withOpacity(0.05),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];
  
  // Special Effects
  static BoxShadow glowShadow(Color color) => BoxShadow(
    color: color.withOpacity(0.3),
    blurRadius: 20,
    spreadRadius: 2,
  );
}