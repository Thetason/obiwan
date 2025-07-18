import 'package:flutter/foundation.dart';

enum BreathingType { chest, diaphragmatic, mixed }
enum ResonancePosition { throat, mouth, head, mixed }
enum MouthOpening { narrow, medium, wide }
enum TonguePosition { highFront, highBack, lowFront, lowBack }
enum VibratoQuality { none, light, medium, heavy }

@immutable
class VocalAnalysis {
  final double pitchStability;
  final BreathingType breathingType;
  final ResonancePosition resonancePosition;
  final MouthOpening mouthOpening;
  final TonguePosition tonguePosition;
  final VibratoQuality vibratoQuality;
  final int overallScore;
  final DateTime timestamp;
  final List<double> fundamentalFreq;
  final List<double> formants;
  final double spectralTilt;

  const VocalAnalysis({
    required this.pitchStability,
    required this.breathingType,
    required this.resonancePosition,
    required this.mouthOpening,
    required this.tonguePosition,
    required this.vibratoQuality,
    required this.overallScore,
    required this.timestamp,
    required this.fundamentalFreq,
    required this.formants,
    required this.spectralTilt,
  });

  VocalAnalysis copyWith({
    double? pitchStability,
    BreathingType? breathingType,
    ResonancePosition? resonancePosition,
    MouthOpening? mouthOpening,
    TonguePosition? tonguePosition,
    VibratoQuality? vibratoQuality,
    int? overallScore,
    DateTime? timestamp,
    List<double>? fundamentalFreq,
    List<double>? formants,
    double? spectralTilt,
  }) {
    return VocalAnalysis(
      pitchStability: pitchStability ?? this.pitchStability,
      breathingType: breathingType ?? this.breathingType,
      resonancePosition: resonancePosition ?? this.resonancePosition,
      mouthOpening: mouthOpening ?? this.mouthOpening,
      tonguePosition: tonguePosition ?? this.tonguePosition,
      vibratoQuality: vibratoQuality ?? this.vibratoQuality,
      overallScore: overallScore ?? this.overallScore,
      timestamp: timestamp ?? this.timestamp,
      fundamentalFreq: fundamentalFreq ?? this.fundamentalFreq,
      formants: formants ?? this.formants,
      spectralTilt: spectralTilt ?? this.spectralTilt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pitchStability': pitchStability,
      'breathingType': breathingType.toString().split('.').last,
      'resonancePosition': resonancePosition.toString().split('.').last,
      'mouthOpening': mouthOpening.toString().split('.').last,
      'tonguePosition': tonguePosition.toString().split('.').last,
      'vibratoQuality': vibratoQuality.toString().split('.').last,
      'overallScore': overallScore,
      'timestamp': timestamp.toIso8601String(),
      'fundamentalFreq': fundamentalFreq,
      'formants': formants,
      'spectralTilt': spectralTilt,
    };
  }

  factory VocalAnalysis.fromJson(Map<String, dynamic> json) {
    return VocalAnalysis(
      pitchStability: json['pitchStability'] as double,
      breathingType: BreathingType.values.firstWhere(
        (e) => e.toString().split('.').last == json['breathingType'],
      ),
      resonancePosition: ResonancePosition.values.firstWhere(
        (e) => e.toString().split('.').last == json['resonancePosition'],
      ),
      mouthOpening: MouthOpening.values.firstWhere(
        (e) => e.toString().split('.').last == json['mouthOpening'],
      ),
      tonguePosition: TonguePosition.values.firstWhere(
        (e) => e.toString().split('.').last == json['tonguePosition'],
      ),
      vibratoQuality: VibratoQuality.values.firstWhere(
        (e) => e.toString().split('.').last == json['vibratoQuality'],
      ),
      overallScore: json['overallScore'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      fundamentalFreq: List<double>.from(json['fundamentalFreq']),
      formants: List<double>.from(json['formants']),
      spectralTilt: json['spectralTilt'] as double,
    );
  }

  @override
  String toString() {
    return 'VocalAnalysis(pitchStability: $pitchStability, breathingType: $breathingType, '
        'resonancePosition: $resonancePosition, mouthOpening: $mouthOpening, '
        'tonguePosition: $tonguePosition, vibratoQuality: $vibratoQuality, '
        'overallScore: $overallScore, timestamp: $timestamp, '
        'fundamentalFreq: ${fundamentalFreq.length} samples, '
        'formants: $formants, spectralTilt: $spectralTilt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VocalAnalysis &&
        other.pitchStability == pitchStability &&
        other.breathingType == breathingType &&
        other.resonancePosition == resonancePosition &&
        other.mouthOpening == mouthOpening &&
        other.tonguePosition == tonguePosition &&
        other.vibratoQuality == vibratoQuality &&
        other.overallScore == overallScore &&
        other.timestamp == timestamp &&
        listEquals(other.fundamentalFreq, fundamentalFreq) &&
        listEquals(other.formants, formants) &&
        other.spectralTilt == spectralTilt;
  }

  @override
  int get hashCode {
    return Object.hash(
      pitchStability,
      breathingType,
      resonancePosition,
      mouthOpening,
      tonguePosition,
      vibratoQuality,
      overallScore,
      timestamp,
      Object.hashAll(fundamentalFreq),
      Object.hashAll(formants),
      spectralTilt,
    );
  }
}