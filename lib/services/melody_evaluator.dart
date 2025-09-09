import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'dtw_melody_aligner.dart';

/// 결과 요약 모델
class MelodyEvaluationResult {
  final DTWAlignmentResult alignment;
  final double overallScore; // 0..1
  final String summary;
  final List<String> strengths;
  final List<String> improvements;

  MelodyEvaluationResult({
    required this.alignment,
    required this.overallScore,
    required this.summary,
    required this.strengths,
    required this.improvements,
  });
}

/// 멜로디 정렬 + 피드백 생성기
class MelodyEvaluator {
  final DTWMelodyAligner _aligner = DTWMelodyAligner();

  /// reference/user 피치 시퀀스(Hz)로 DTW 정렬을 수행하고 텍스트 피드백 생성
  MelodyEvaluationResult evaluate({
    required List<double> reference,
    required List<double> user,
    double frameRate = 100.0, // frames per second
  }) {
    final alignment = _aligner.alignMelody(
      reference,
      user,
      sampleRate: frameRate,
      windowConstraint: 0.12,
    );

    final score = alignment.alignmentQuality.clamp(0.0, 1.0);
    final texts = _buildFeedback(alignment);

    return MelodyEvaluationResult(
      alignment: alignment,
      overallScore: score,
      summary: texts['summary'] as String,
      strengths: (texts['strengthsList'] as List<String>),
      improvements: (texts['improvementsList'] as List<String>),
    );
  }

  Map<String, dynamic> _buildFeedback(DTWAlignmentResult a) {
    final correct = a.noteMatchings.where((m) => m.isCorrect).length;
    final total = a.noteMatchings.length;
    final pct = total > 0 ? (correct / total * 100.0) : 0.0;

    // 평균 오차
    double avgCents = 0, avgTiming = 0;
    if (total > 0) {
      avgCents = a.noteMatchings
              .map((m) => m.pitchError.abs())
              .reduce((x, y) => x + y) /
          total;
      avgTiming = a.noteMatchings
              .map((m) => m.timingError)
              .reduce((x, y) => x + y) /
          total;
    }

    // 요약
    String summary = '전체 정확도 ${pct.toStringAsFixed(1)}%. ';
    if (a.alignmentQuality > 0.85) {
      summary += '멜로디와 타이밍이 매우 잘 맞습니다.';
    } else if (a.alignmentQuality > 0.7) {
      summary += '전반적으로 좋습니다. 몇몇 구간의 음정/타이밍을 다듬어보세요.';
    } else {
      summary += '음정과 박자 모두 개선 여지가 있습니다. 느린 템포로 반복 연습을 권장합니다.';
    }

    // 강점/개선 포인트 추출
    final strengths = <String>[];
    final improvements = <String>[];

    if (avgCents < 20) strengths.add('음정 정확도가 우수합니다');
    if (avgTiming < 0.15) strengths.add('타이밍 일관성이 좋습니다');
    if (strengths.isEmpty) strengths.add('멜로디 윤곽은 잘 따라가고 있습니다');

    if (avgCents >= 30) improvements.add('평균 음정 오차 ${avgCents.toStringAsFixed(0)} cents → 반음 단위 스케일 연습 추천');
    if (avgTiming >= 0.2) improvements.add('평균 타이밍 오차 ${(avgTiming * 1000).toStringAsFixed(0)}ms → 메트로놈과 느린 템포 연습');

    return {
      'summary': summary,
      'strengthsList': strengths,
      'improvementsList': improvements,
    };
  }
}
