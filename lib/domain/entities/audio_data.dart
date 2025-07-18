import 'package:flutter/foundation.dart';

@immutable
class AudioData {
  final List<double> samples;
  final int sampleRate;
  final int channels;
  final Duration duration;

  const AudioData({
    required this.samples,
    required this.sampleRate,
    required this.channels,
    required this.duration,
  });

  int get sampleCount => samples.length;
  
  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  AudioData copyWith({
    List<double>? samples,
    int? sampleRate,
    int? channels,
    Duration? duration,
  }) {
    return AudioData(
      samples: samples ?? this.samples,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      duration: duration ?? this.duration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'samples': samples,
      'sampleRate': sampleRate,
      'channels': channels,
      'duration': duration.inMilliseconds,
    };
  }

  factory AudioData.fromJson(Map<String, dynamic> json) {
    return AudioData(
      samples: List<double>.from(json['samples']),
      sampleRate: json['sampleRate'] as int,
      channels: json['channels'] as int,
      duration: Duration(milliseconds: json['duration'] as int),
    );
  }

  @override
  String toString() {
    return 'AudioData(sampleCount: $sampleCount, sampleRate: $sampleRate, '
        'channels: $channels, duration: $duration)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioData &&
        listEquals(other.samples, samples) &&
        other.sampleRate == sampleRate &&
        other.channels == channels &&
        other.duration == duration;
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(samples),
      sampleRate,
      channels,
      duration,
    );
  }
}