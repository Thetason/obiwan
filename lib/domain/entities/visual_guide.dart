import 'package:flutter/foundation.dart';

enum GuideType { breathing, posture, resonance, mouthShape }
enum AnimationAction { expandContract, highlight, rotate, pulse }
enum AnimationIntensity { light, medium, deep }

@immutable
class VisualGuide {
  final GuideType guideType;
  final List<GuideAnimation> animations;
  final List<BodyHighlight> highlights;
  final List<String> stepByStep;
  final Duration estimatedDuration;

  const VisualGuide({
    required this.guideType,
    required this.animations,
    required this.highlights,
    required this.stepByStep,
    required this.estimatedDuration,
  });

  VisualGuide copyWith({
    GuideType? guideType,
    List<GuideAnimation>? animations,
    List<BodyHighlight>? highlights,
    List<String>? stepByStep,
    Duration? estimatedDuration,
  }) {
    return VisualGuide(
      guideType: guideType ?? this.guideType,
      animations: animations ?? this.animations,
      highlights: highlights ?? this.highlights,
      stepByStep: stepByStep ?? this.stepByStep,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'guideType': guideType.toString().split('.').last,
      'animations': animations.map((a) => a.toJson()).toList(),
      'highlights': highlights.map((h) => h.toJson()).toList(),
      'stepByStep': stepByStep,
      'estimatedDuration': estimatedDuration.inSeconds,
    };
  }

  factory VisualGuide.fromJson(Map<String, dynamic> json) {
    return VisualGuide(
      guideType: GuideType.values.firstWhere(
        (e) => e.toString().split('.').last == json['guideType'],
      ),
      animations: (json['animations'] as List)
          .map((a) => GuideAnimation.fromJson(a as Map<String, dynamic>))
          .toList(),
      highlights: (json['highlights'] as List)
          .map((h) => BodyHighlight.fromJson(h as Map<String, dynamic>))
          .toList(),
      stepByStep: List<String>.from(json['stepByStep']),
      estimatedDuration: Duration(seconds: json['estimatedDuration'] as int),
    );
  }

  @override
  String toString() {
    return 'VisualGuide(guideType: $guideType, animations: ${animations.length}, '
        'highlights: ${highlights.length}, steps: ${stepByStep.length}, '
        'estimatedDuration: $estimatedDuration)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VisualGuide &&
        other.guideType == guideType &&
        listEquals(other.animations, animations) &&
        listEquals(other.highlights, highlights) &&
        listEquals(other.stepByStep, stepByStep) &&
        other.estimatedDuration == estimatedDuration;
  }

  @override
  int get hashCode {
    return Object.hash(
      guideType,
      Object.hashAll(animations),
      Object.hashAll(highlights),
      Object.hashAll(stepByStep),
      estimatedDuration,
    );
  }
}

@immutable
class GuideAnimation {
  final String target;
  final AnimationAction action;
  final String timing;
  final AnimationIntensity intensity;

  const GuideAnimation({
    required this.target,
    required this.action,
    required this.timing,
    required this.intensity,
  });

  GuideAnimation copyWith({
    String? target,
    AnimationAction? action,
    String? timing,
    AnimationIntensity? intensity,
  }) {
    return GuideAnimation(
      target: target ?? this.target,
      action: action ?? this.action,
      timing: timing ?? this.timing,
      intensity: intensity ?? this.intensity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'target': target,
      'action': action.toString().split('.').last,
      'timing': timing,
      'intensity': intensity.toString().split('.').last,
    };
  }

  factory GuideAnimation.fromJson(Map<String, dynamic> json) {
    return GuideAnimation(
      target: json['target'] as String,
      action: AnimationAction.values.firstWhere(
        (e) => e.toString().split('.').last == json['action'],
      ),
      timing: json['timing'] as String,
      intensity: AnimationIntensity.values.firstWhere(
        (e) => e.toString().split('.').last == json['intensity'],
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GuideAnimation &&
        other.target == target &&
        other.action == action &&
        other.timing == timing &&
        other.intensity == intensity;
  }

  @override
  int get hashCode {
    return Object.hash(target, action, timing, intensity);
  }
}

@immutable
class BodyHighlight {
  final String bodyPart;
  final double opacity;
  final int colorHex;
  final bool pulse;

  const BodyHighlight({
    required this.bodyPart,
    required this.opacity,
    required this.colorHex,
    required this.pulse,
  });

  BodyHighlight copyWith({
    String? bodyPart,
    double? opacity,
    int? colorHex,
    bool? pulse,
  }) {
    return BodyHighlight(
      bodyPart: bodyPart ?? this.bodyPart,
      opacity: opacity ?? this.opacity,
      colorHex: colorHex ?? this.colorHex,
      pulse: pulse ?? this.pulse,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bodyPart': bodyPart,
      'opacity': opacity,
      'colorHex': colorHex,
      'pulse': pulse,
    };
  }

  factory BodyHighlight.fromJson(Map<String, dynamic> json) {
    return BodyHighlight(
      bodyPart: json['bodyPart'] as String,
      opacity: json['opacity'] as double,
      colorHex: json['colorHex'] as int,
      pulse: json['pulse'] as bool,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BodyHighlight &&
        other.bodyPart == bodyPart &&
        other.opacity == opacity &&
        other.colorHex == colorHex &&
        other.pulse == pulse;
  }

  @override
  int get hashCode {
    return Object.hash(bodyPart, opacity, colorHex, pulse);
  }
}