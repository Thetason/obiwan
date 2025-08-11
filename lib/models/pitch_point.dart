// 피치 포인트 데이터 모델
class PitchPoint {
  final DateTime time;
  final double frequency;
  final String note;
  final double confidence;
  
  PitchPoint({
    required this.time,
    required this.frequency,
    required this.note,
    required this.confidence,
  });
}