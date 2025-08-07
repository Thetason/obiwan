import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 🎨 고급 피치 색상 시스템
/// 
/// 음계별 고유 색상과 아름다운 그라디에이션을 제공합니다.
/// 각 음정마다 고유한 색상을 가지며, 피치 정확도에 따라 밝기와 채도가 조절됩니다.
class PitchColorSystem {
  
  /// 🎵 음계별 기본 색상 매핑
  /// 
  /// 색상 이론에 기반한 음계별 고유 색상:
  /// - C (도): 빨강 - 강렬하고 기본이 되는 색
  /// - D (레): 주황 - 따뜻하고 활력적인 색  
  /// - E (미): 노랑 - 밝고 경쾌한 색
  /// - F (파): 초록 - 자연스럽고 안정적인 색
  /// - G (솔): 파랑 - 깊이있고 차분한 색
  /// - A (라): 남색 - 우아하고 세련된 색
  /// - B (시): 보라 - 신비롭고 고급스러운 색
  static const Map<String, Color> _noteBaseColors = {
    'C': Color(0xFFFF4444),  // 빨강
    'C#': Color(0xFFFF6622), // 빨강-주황
    'D': Color(0xFFFF8800),  // 주황  
    'D#': Color(0xFFFFAA00), // 주황-노랑
    'E': Color(0xFFFFDD00),  // 노랑
    'F': Color(0xFF88DD00),  // 노랑-초록
    'F#': Color(0xFF44BB00), // 초록
    'G': Color(0xFF00BB44),  // 초록-파랑
    'G#': Color(0xFF00AAAA), // 청록
    'A': Color(0xFF0088FF),  // 파랑
    'A#': Color(0xFF4444FF), // 파랑-보라
    'B': Color(0xFF8844FF),  // 보라
  };

  /// 🎯 피치 정확도에 따른 색상 생성
  /// 
  /// [frequency]: 감지된 주파수 (Hz)
  /// [confidence]: AI 신뢰도 (0.0 ~ 1.0)
  /// [cents]: 음정 정확도 (-100 ~ +100 cents)
  static Color getPitchColor(double frequency, double confidence, double cents) {
    if (frequency <= 0 || confidence < 0.3) {
      return Colors.grey.withOpacity(0.3);
    }

    // 주파수를 음계로 변환
    final noteName = _frequencyToNoteName(frequency);
    final baseColor = _noteBaseColors[noteName] ?? Colors.grey;
    
    // 정확도에 따른 색상 조절
    final accuracy = _calculateAccuracy(cents);
    
    // 신뢰도에 따른 투명도 조절  
    final opacity = math.min(confidence, 1.0);
    
    // HSV 색상 공간에서 조절
    final hsvColor = HSVColor.fromColor(baseColor);
    final adjustedColor = hsvColor.withSaturation(
      math.min(hsvColor.saturation * (0.5 + accuracy * 0.5), 1.0)
    ).withValue(
      math.min(hsvColor.value * (0.6 + accuracy * 0.4), 1.0)
    );
    
    return adjustedColor.toColor().withOpacity(opacity);
  }

  /// 🌈 실시간 그라디에이션 생성
  /// 
  /// 피치 히스토리를 기반으로 아름다운 그라디에이션을 생성합니다.
  static LinearGradient createPitchGradient(List<PitchData> pitchHistory) {
    if (pitchHistory.isEmpty) {
      return LinearGradient(
        colors: [Colors.grey.withOpacity(0.1), Colors.grey.withOpacity(0.3)],
      );
    }
    
    // 최근 5개 피치 데이터 사용
    final recentPitches = pitchHistory.length > 5 
        ? pitchHistory.sublist(pitchHistory.length - 5)
        : pitchHistory;
    
    final colors = recentPitches.map((pitch) {
      return getPitchColor(pitch.frequency, pitch.confidence, pitch.cents);
    }).toList();
    
    // 색상이 너무 적으면 보간
    if (colors.length < 3) {
      colors.addAll([colors.last, colors.last.withOpacity(0.5)]);
    }
    
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    );
  }

  /// 🎪 비브라토 색상 효과
  /// 
  /// 비브라토(목소리 떨림)를 감지했을 때 특별한 색상 효과
  static Color getVibratoColor(double vibratoIntensity, Color baseColor) {
    final intensity = math.min(vibratoIntensity, 1.0);
    
    // 비브라토 강도에 따라 무지개 효과 추가
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final rainbow = HSVColor.fromAHSV(
      1.0,
      (time * 60 + intensity * 180) % 360, // 색상이 시간에 따라 변화
      0.7,
      1.0,
    );
    
    // 기본 색상과 무지개 효과 블렌딩
    return Color.lerp(baseColor, rainbow.toColor(), intensity * 0.3) ?? baseColor;
  }

  /// 🎨 호흡법 분석 색상
  /// 
  /// 호흡 패턴에 따른 색상 변화 (차분한 파란색 계열)
  static Color getBreathingColor(double breathingQuality) {
    final quality = math.min(breathingQuality, 1.0);
    
    // 좋은 호흡: 깊은 파란색, 나쁜 호흡: 회색
    return Color.lerp(
      Colors.grey,
      const Color(0xFF0066CC),
      quality,
    ) ?? Colors.grey;
  }

  /// 🎯 목소리 안정성 색상
  /// 
  /// 목소리의 안정성에 따른 색상 (안정: 금색, 불안정: 빨간색)
  static Color getStabilityColor(double stability) {
    final stableValue = math.min(stability, 1.0);
    
    return Color.lerp(
      const Color(0xFFFF4444), // 불안정: 빨간색
      const Color(0xFFFFD700), // 안정: 금색
      stableValue,
    ) ?? Colors.grey;
  }

  /// 내부 유틸리티: 주파수 → 음계 변환
  static String _frequencyToNoteName(double frequency) {
    if (frequency <= 0) return 'C';
    
    // A4 = 440Hz를 기준으로 계산
    final a4 = 440.0;
    final noteNumber = (12 * math.log(frequency / a4) / math.ln2).round() % 12;
    
    const noteNames = ['A', 'A#', 'B', 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#'];
    return noteNames[noteNumber];
  }

  /// 내부 유틸리티: cents를 정확도로 변환
  static double _calculateAccuracy(double cents) {
    final absCents = cents.abs();
    if (absCents <= 5) return 1.0;      // 완벽
    if (absCents <= 15) return 0.8;     // 매우 좋음
    if (absCents <= 30) return 0.6;     // 좋음
    if (absCents <= 50) return 0.4;     // 보통
    return 0.2;                         // 개선 필요
  }
}

/// 🎵 피치 데이터 모델
class PitchData {
  final double frequency;    // Hz
  final double confidence;   // 0.0 ~ 1.0
  final double cents;        // -100 ~ +100
  final DateTime timestamp;  // 시간
  final double amplitude;    // 볼륨

  const PitchData({
    required this.frequency,
    required this.confidence,
    required this.cents,
    required this.timestamp,
    this.amplitude = 0.0,
  });

  /// 음계 이름 가져오기
  String get noteName => PitchColorSystem._frequencyToNoteName(frequency);
  
  /// 옥타브 번호 계산
  int get octave {
    if (frequency <= 0) return 4;
    return (math.log(frequency / 440) / math.ln2 + 4.75).floor();
  }
  
  /// 피치 색상 가져오기
  Color get color => PitchColorSystem.getPitchColor(frequency, confidence, cents);
}