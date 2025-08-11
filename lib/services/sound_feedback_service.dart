import 'package:flutter/services.dart';

/// 멀티모달 피드백을 위한 사운드 및 햅틱 서비스
class SoundFeedbackService {
  static final SoundFeedbackService _instance = SoundFeedbackService._internal();
  factory SoundFeedbackService() => _instance;
  SoundFeedbackService._internal();
  
  static SoundFeedbackService get instance => _instance;
  
  // 시스템 사운드 ID (macOS/iOS)
  static const int _successSound = 1057;  // Tink
  static const int _warningSound = 1073;  // Tock
  static const int _errorSound = 1053;    // Sosumi
  
  /// 성공 사운드 재생
  Future<void> playSuccess() async {
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();
    } catch (e) {
      print('Success sound failed: $e');
    }
  }
  
  /// 경고 사운드 재생
  Future<void> playWarning() async {
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.mediumImpact();
    } catch (e) {
      print('Warning sound failed: $e');
    }
  }
  
  /// 에러 사운드 재생
  Future<void> playError() async {
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.heavyImpact();
    } catch (e) {
      print('Error sound failed: $e');
    }
  }
  
  /// 피치 정확도에 따른 피드백
  Future<void> playPitchFeedback(double accuracy) async {
    if (accuracy >= 0.9) {
      await playSuccess();
    } else if (accuracy >= 0.7) {
      // 근접했을 때는 가벼운 햅틱만
      HapticFeedback.selectionClick();
    } else if (accuracy < 0.5) {
      await playWarning();
    }
  }
  
  /// 녹음 시작/종료 피드백
  Future<void> playRecordingStart() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.lightImpact();
  }
  
  Future<void> playRecordingStop() async {
    HapticFeedback.heavyImpact();
  }
  
  /// 버튼 클릭 피드백
  Future<void> playButtonTap() async {
    HapticFeedback.selectionClick();
  }
  
  /// 레벨업/성취 피드백
  Future<void> playAchievement() async {
    // 연속 햅틱으로 축하 효과
    for (int i = 0; i < 3; i++) {
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 100));
    }
    SystemSound.play(SystemSoundType.click);
  }
}