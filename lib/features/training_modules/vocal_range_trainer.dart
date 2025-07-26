import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Vocal range expansion training module with AI-powered personalized exercises
class VocalRangeTrainer {
  static const double _semitoneCents = 100.0;
  static const double _a4Frequency = 440.0;
  static const int _a4MidiNote = 69; // MIDI note number for A4
  
  final StreamController<RangeTrainingProgress> _progressController = 
      StreamController<RangeTrainingProgress>.broadcast();
  
  Stream<RangeTrainingProgress> get progressStream => _progressController.stream;
  
  // Current training session state
  VocalRange? _currentRange;
  RangeTrainingSession? _currentSession;
  final List<RangeExercise> _exerciseHistory = [];
  
  /// Analyze current vocal range from pitch data
  Future<VocalRange> analyzeVocalRange(List<double> pitchData) async {
    if (pitchData.isEmpty) {
      return const VocalRange(
        lowestNote: 'C3',
        highestNote: 'C5',
        totalSemitones: 24,
        comfortableRange: ComfortableRange(low: 'E3', high: 'G4'),
      );
    }
    
    // Filter out noise and silence
    final validPitches = pitchData.where((pitch) => 
      pitch > 80 && pitch < 2000).toList();
    
    if (validPitches.isEmpty) {
      return const VocalRange(
        lowestNote: 'C3',
        highestNote: 'C5',
        totalSemitones: 24,
        comfortableRange: ComfortableRange(low: 'E3', high: 'G4'),
      );
    }
    
    // Find extremes
    final lowestFreq = validPitches.reduce(math.min);
    final highestFreq = validPitches.reduce(math.max);
    
    // Convert to MIDI notes
    final lowestMidi = _frequencyToMidi(lowestFreq);
    final highestMidi = _frequencyToMidi(highestFreq);
    
    // Find comfortable range (remove extremes 10%)
    final sortedPitches = List<double>.from(validPitches)..sort();
    final tenPercent = (sortedPitches.length * 0.1).floor();
    final comfortablePitches = sortedPitches.sublist(
      tenPercent, 
      sortedPitches.length - tenPercent
    );
    
    final comfortableLow = comfortablePitches.first;
    final comfortableHigh = comfortablePitches.last;
    
    return VocalRange(
      lowestNote: _midiToNoteName(lowestMidi),
      highestNote: _midiToNoteName(highestMidi),
      totalSemitones: highestMidi - lowestMidi,
      comfortableRange: ComfortableRange(
        low: _midiToNoteName(_frequencyToMidi(comfortableLow)),
        high: _midiToNoteName(_frequencyToMidi(comfortableHigh)),
      ),
      lowestFrequency: lowestFreq,
      highestFrequency: highestFreq,
      comfortableLowFreq: comfortableLow,
      comfortableHighFreq: comfortableHigh,
    );
  }
  
  /// Generate personalized range expansion exercises
  List<RangeExercise> generateRangeExercises(
    VocalRange currentRange, {
    RangeTrainingGoal goal = RangeTrainingGoal.extend,
    int difficulty = 1,
  }) {
    final exercises = <RangeExercise>[];
    
    switch (goal) {
      case RangeTrainingGoal.extend:
        exercises.addAll(_generateRangeExtensionExercises(currentRange, difficulty));
        break;
      case RangeTrainingGoal.strengthen:
        exercises.addAll(_generateRangeStrengtheningExercises(currentRange, difficulty));
        break;
      case RangeTrainingGoal.smooth:
        exercises.addAll(_generateRangeSmoothingExercises(currentRange, difficulty));
        break;
      case RangeTrainingGoal.balance:
        exercises.addAll(_generateRangeBalancingExercises(currentRange, difficulty));
        break;
    }
    
    return exercises;
  }
  
  /// Start a new training session
  Future<void> startTrainingSession({
    required VocalRange currentRange,
    required RangeTrainingGoal goal,
    int difficulty = 1,
    Duration sessionDuration = const Duration(minutes: 15),
  }) async {
    _currentRange = currentRange;
    final exercises = generateRangeExercises(
      currentRange, 
      goal: goal, 
      difficulty: difficulty
    );
    
    _currentSession = RangeTrainingSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      goal: goal,
      difficulty: difficulty,
      exercises: exercises,
      duration: sessionDuration,
    );
    
    _progressController.add(RangeTrainingProgress(
      session: _currentSession!,
      currentExerciseIndex: 0,
      completedExercises: 0,
      accuracy: 0.0,
      status: TrainingStatus.started,
    ));
  }
  
  /// Process real-time pitch feedback during exercise
  void processPitchFeedback(double currentPitch, RangeExercise exercise) {
    if (_currentSession == null) return;
    
    final targetPitch = exercise.currentTargetPitch;
    final accuracy = _calculatePitchAccuracy(currentPitch, targetPitch);
    
    final feedback = ExerciseFeedback(
      timestamp: DateTime.now(),
      targetPitch: targetPitch,
      actualPitch: currentPitch,
      accuracy: accuracy,
      isOnTarget: accuracy > 0.8,
    );
    
    exercise.addFeedback(feedback);
    
    // Update progress
    final progress = RangeTrainingProgress(
      session: _currentSession!,
      currentExerciseIndex: _currentSession!.currentExerciseIndex,
      completedExercises: _currentSession!.completedExercises,
      accuracy: _calculateSessionAccuracy(),
      status: TrainingStatus.inProgress,
      currentFeedback: feedback,
    );
    
    _progressController.add(progress);
  }
  
  /// Complete current exercise and move to next
  void completeCurrentExercise() {
    if (_currentSession == null) return;
    
    final currentExercise = _currentSession!.currentExercise;
    if (currentExercise != null) {
      currentExercise.isCompleted = true;
      _exerciseHistory.add(currentExercise);
    }
    
    _currentSession!.completedExercises++;
    
    if (_currentSession!.hasMoreExercises) {
      _currentSession!.currentExerciseIndex++;
      _progressController.add(RangeTrainingProgress(
        session: _currentSession!,
        currentExerciseIndex: _currentSession!.currentExerciseIndex,
        completedExercises: _currentSession!.completedExercises,
        accuracy: _calculateSessionAccuracy(),
        status: TrainingStatus.inProgress,
      ));
    } else {
      _completeSession();
    }
  }
  
  /// Complete training session
  void _completeSession() {
    if (_currentSession == null) return;
    
    _currentSession!.endTime = DateTime.now();
    final sessionSummary = _generateSessionSummary(_currentSession!);
    
    _progressController.add(RangeTrainingProgress(
      session: _currentSession!,
      currentExerciseIndex: _currentSession!.currentExerciseIndex,
      completedExercises: _currentSession!.completedExercises,
      accuracy: _calculateSessionAccuracy(),
      status: TrainingStatus.completed,
      sessionSummary: sessionSummary,
    ));
    
    _currentSession = null;
  }
  
  /// Generate range extension exercises
  List<RangeExercise> _generateRangeExtensionExercises(
    VocalRange range, int difficulty
  ) {
    final exercises = <RangeExercise>[];
    
    // Low range extension
    final lowTargetMidi = _noteNameToMidi(range.lowestNote) - (1 + difficulty);
    exercises.add(RangeExercise(
      id: 'low_extend_${DateTime.now().millisecondsSinceEpoch}',
      name: '저음역 확장 연습',
      description: '편안한 중간음에서 시작하여 점진적으로 낮은 음으로 이동합니다.',
      type: RangeExerciseType.extension,
      targetDirection: RangeDirection.lower,
      startNote: range.comfortableRange.low,
      endNote: _midiToNoteName(lowTargetMidi),
      duration: const Duration(minutes: 3),
      pattern: ExercisePattern.chromatic,
      tempo: 60,
    ));
    
    // High range extension
    final highTargetMidi = _noteNameToMidi(range.highestNote) + (1 + difficulty);
    exercises.add(RangeExercise(
      id: 'high_extend_${DateTime.now().millisecondsSinceEpoch}',
      name: '고음역 확장 연습',
      description: '편안한 중간음에서 시작하여 점진적으로 높은 음으로 이동합니다.',
      type: RangeExerciseType.extension,
      targetDirection: RangeDirection.higher,
      startNote: range.comfortableRange.high,
      endNote: _midiToNoteName(highTargetMidi),
      duration: const Duration(minutes: 3),
      pattern: ExercisePattern.chromatic,
      tempo: 60,
    ));
    
    return exercises;
  }
  
  /// Generate range strengthening exercises
  List<RangeExercise> _generateRangeStrengtheningExercises(
    VocalRange range, int difficulty
  ) {
    final exercises = <RangeExercise>[];
    
    // Sustained note exercises at range extremes
    exercises.add(RangeExercise(
      id: 'sustain_low_${DateTime.now().millisecondsSinceEpoch}',
      name: '저음 지속 연습',
      description: '낮은 음역에서 안정적으로 음을 유지하는 연습입니다.',
      type: RangeExerciseType.sustain,
      targetDirection: RangeDirection.steady,
      startNote: range.lowestNote,
      endNote: range.lowestNote,
      duration: Duration(seconds: 30 + (difficulty * 15)),
      pattern: ExercisePattern.sustained,
      tempo: 0, // Sustained note
    ));
    
    exercises.add(RangeExercise(
      id: 'sustain_high_${DateTime.now().millisecondsSinceEpoch}',
      name: '고음 지속 연습',
      description: '높은 음역에서 안정적으로 음을 유지하는 연습입니다.',
      type: RangeExerciseType.sustain,
      targetDirection: RangeDirection.steady,
      startNote: range.highestNote,
      endNote: range.highestNote,
      duration: Duration(seconds: 30 + (difficulty * 15)),
      pattern: ExercisePattern.sustained,
      tempo: 0,
    ));
    
    return exercises;
  }
  
  /// Generate range smoothing exercises
  List<RangeExercise> _generateRangeSmoothingExercises(
    VocalRange range, int difficulty
  ) {
    final exercises = <RangeExercise>[];
    
    // Glissando exercises
    exercises.add(RangeExercise(
      id: 'glissando_${DateTime.now().millisecondsSinceEpoch}',
      name: '글리산도 연습',
      description: '음정 간의 부드러운 이동을 연습합니다.',
      type: RangeExerciseType.glissando,
      targetDirection: RangeDirection.both,
      startNote: range.comfortableRange.low,
      endNote: range.comfortableRange.high,
      duration: Duration(seconds: 20 + (difficulty * 10)),
      pattern: ExercisePattern.glissando,
      tempo: 0,
    ));
    
    // Scale exercises
    exercises.add(RangeExercise(
      id: 'scale_smooth_${DateTime.now().millisecondsSinceEpoch}',
      name: '스케일 스무딩',
      description: '스케일을 따라 부드럽게 이동하며 음정 연결을 개선합니다.',
      type: RangeExerciseType.scale,
      targetDirection: RangeDirection.both,
      startNote: range.comfortableRange.low,
      endNote: range.comfortableRange.high,
      duration: Duration(minutes: 2 + difficulty),
      pattern: ExercisePattern.majorScale,
      tempo: 80,
    ));
    
    return exercises;
  }
  
  /// Generate range balancing exercises
  List<RangeExercise> _generateRangeBalancingExercises(
    VocalRange range, int difficulty
  ) {
    final exercises = <RangeExercise>[];
    
    // Interval jumps
    exercises.add(RangeExercise(
      id: 'intervals_${DateTime.now().millisecondsSinceEpoch}',
      name: '음정 점프 연습',
      description: '다양한 음정 간격으로 점프하며 전체 음역의 균형을 맞춥니다.',
      type: RangeExerciseType.intervals,
      targetDirection: RangeDirection.both,
      startNote: range.comfortableRange.low,
      endNote: range.comfortableRange.high,
      duration: Duration(minutes: 3 + difficulty),
      pattern: ExercisePattern.intervals,
      tempo: 120,
    ));
    
    return exercises;
  }
  
  /// Calculate pitch accuracy
  double _calculatePitchAccuracy(double actualPitch, double targetPitch) {
    if (actualPitch <= 0 || targetPitch <= 0) return 0.0;
    
    final cents = (1200 * math.log(actualPitch / targetPitch) / math.ln2).abs();
    
    // Perfect accuracy within 10 cents, linear decrease to 0 at 100 cents
    if (cents <= 10) return 1.0;
    if (cents >= 100) return 0.0;
    return 1.0 - ((cents - 10) / 90);
  }
  
  /// Calculate overall session accuracy
  double _calculateSessionAccuracy() {
    if (_currentSession == null || _currentSession!.exercises.isEmpty) return 0.0;
    
    double totalAccuracy = 0;
    int feedbackCount = 0;
    
    for (final exercise in _currentSession!.exercises) {
      for (final feedback in exercise.feedbackHistory) {
        totalAccuracy += feedback.accuracy;
        feedbackCount++;
      }
    }
    
    return feedbackCount > 0 ? totalAccuracy / feedbackCount : 0.0;
  }
  
  /// Generate session summary
  SessionSummary _generateSessionSummary(RangeTrainingSession session) {
    final accuracy = _calculateSessionAccuracy();
    final totalExercises = session.exercises.length;
    final completedExercises = session.completedExercises;
    
    // Calculate improvements
    final rangeImprovement = _calculateRangeImprovement(session);
    final stabilityImprovement = _calculateStabilityImprovement(session);
    
    // Generate recommendations
    final recommendations = _generateRecommendations(session, accuracy);
    
    return SessionSummary(
      sessionId: session.id,
      duration: session.actualDuration,
      accuracy: accuracy,
      completedExercises: completedExercises,
      totalExercises: totalExercises,
      rangeImprovement: rangeImprovement,
      stabilityImprovement: stabilityImprovement,
      recommendations: recommendations,
      achievements: _calculateAchievements(session, accuracy),
    );
  }
  
  double _calculateRangeImprovement(RangeTrainingSession session) {
    // Simplified improvement calculation
    // In a real implementation, this would compare against historical data
    return session.completedExercises / session.exercises.length;
  }
  
  double _calculateStabilityImprovement(RangeTrainingSession session) {
    double totalStability = 0;
    int count = 0;
    
    for (final exercise in session.exercises) {
      for (final feedback in exercise.feedbackHistory) {
        totalStability += feedback.accuracy;
        count++;
      }
    }
    
    return count > 0 ? totalStability / count : 0.0;
  }
  
  List<String> _generateRecommendations(RangeTrainingSession session, double accuracy) {
    final recommendations = <String>[];
    
    if (accuracy < 0.6) {
      recommendations.add('더 천천히 연습하여 정확도를 높여보세요');
      recommendations.add('브레스 컨트롤에 더 집중해보세요');
    } else if (accuracy < 0.8) {
      recommendations.add('좋은 진전입니다! 일정한 연습을 계속하세요');
    } else {
      recommendations.add('훌륭합니다! 더 어려운 레벨에 도전해보세요');
    }
    
    // Goal-specific recommendations
    switch (session.goal) {
      case RangeTrainingGoal.extend:
        recommendations.add('음역 확장 시 무리하지 말고 점진적으로 진행하세요');
        break;
      case RangeTrainingGoal.strengthen:
        recommendations.add('지속 연습으로 성대 근력을 강화하세요');
        break;
      case RangeTrainingGoal.smooth:
        recommendations.add('레가토 연습으로 음정 연결을 더욱 부드럽게 만드세요');
        break;
      case RangeTrainingGoal.balance:
        recommendations.add('전체 음역에서 균등한 음량과 음색을 유지하세요');
        break;
    }
    
    return recommendations;
  }
  
  List<String> _calculateAchievements(RangeTrainingSession session, double accuracy) {
    final achievements = <String>[];
    
    if (session.completedExercises == session.exercises.length) {
      achievements.add('완주 달성! 🏆');
    }
    
    if (accuracy >= 0.9) {
      achievements.add('완벽한 정확도! ⭐');
    } else if (accuracy >= 0.8) {
      achievements.add('높은 정확도! 👏');
    }
    
    if (session.actualDuration >= session.duration) {
      achievements.add('목표 시간 달성! ⏰');
    }
    
    return achievements;
  }
  
  // Helper methods for note conversion
  int _frequencyToMidi(double frequency) {
    return (69 + 12 * math.log(frequency / _a4Frequency) / math.ln2).round();
  }
  
  double _midiToFrequency(int midi) {
    return _a4Frequency * math.pow(2, (midi - _a4MidiNote) / 12);
  }
  
  String _midiToNoteName(int midi) {
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final octave = (midi / 12).floor() - 1;
    final noteIndex = midi % 12;
    return '${noteNames[noteIndex]}$octave';
  }
  
  int _noteNameToMidi(String noteName) {
    const noteValues = {
      'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5,
      'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11
    };
    
    // Parse note name (e.g., "C4", "F#3")
    final match = RegExp(r'([A-G]#?)(\d+)').firstMatch(noteName);
    if (match == null) return 60; // Default to C4
    
    final notePart = match.group(1)!;
    final octave = int.parse(match.group(2)!);
    
    return (octave + 1) * 12 + (noteValues[notePart] ?? 0);
  }
  
  void dispose() {
    _progressController.close();
  }
}

// Data classes
class VocalRange {
  final String lowestNote;
  final String highestNote;
  final int totalSemitones;
  final ComfortableRange comfortableRange;
  final double? lowestFrequency;
  final double? highestFrequency;
  final double? comfortableLowFreq;
  final double? comfortableHighFreq;
  
  const VocalRange({
    required this.lowestNote,
    required this.highestNote,
    required this.totalSemitones,
    required this.comfortableRange,
    this.lowestFrequency,
    this.highestFrequency,
    this.comfortableLowFreq,
    this.comfortableHighFreq,
  });
}

class ComfortableRange {
  final String low;
  final String high;
  
  const ComfortableRange({required this.low, required this.high});
}

class RangeExercise {
  final String id;
  final String name;
  final String description;
  final RangeExerciseType type;
  final RangeDirection targetDirection;
  final String startNote;
  final String endNote;
  final Duration duration;
  final ExercisePattern pattern;
  final int tempo;
  
  bool isCompleted = false;
  final List<ExerciseFeedback> feedbackHistory = [];
  
  RangeExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.targetDirection,
    required this.startNote,
    required this.endNote,
    required this.duration,
    required this.pattern,
    required this.tempo,
  });
  
  double get currentTargetPitch {
    // Simplified - returns start note frequency
    final midi = _noteNameToMidi(startNote);
    return 440 * math.pow(2, (midi - 69) / 12);
  }
  
  void addFeedback(ExerciseFeedback feedback) {
    feedbackHistory.add(feedback);
  }
  
  int _noteNameToMidi(String noteName) {
    const noteValues = {
      'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5,
      'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11
    };
    
    final match = RegExp(r'([A-G]#?)(\d+)').firstMatch(noteName);
    if (match == null) return 60;
    
    final notePart = match.group(1)!;
    final octave = int.parse(match.group(2)!);
    
    return (octave + 1) * 12 + (noteValues[notePart] ?? 0);
  }
}

class RangeTrainingSession {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  final RangeTrainingGoal goal;
  final int difficulty;
  final List<RangeExercise> exercises;
  final Duration duration;
  
  int currentExerciseIndex = 0;
  int completedExercises = 0;
  
  RangeTrainingSession({
    required this.id,
    required this.startTime,
    required this.goal,
    required this.difficulty,
    required this.exercises,
    required this.duration,
  });
  
  RangeExercise? get currentExercise {
    if (currentExerciseIndex < exercises.length) {
      return exercises[currentExerciseIndex];
    }
    return null;
  }
  
  bool get hasMoreExercises => currentExerciseIndex < exercises.length - 1;
  
  Duration get actualDuration {
    return endTime?.difference(startTime) ?? Duration.zero;
  }
}

class RangeTrainingProgress {
  final RangeTrainingSession session;
  final int currentExerciseIndex;
  final int completedExercises;
  final double accuracy;
  final TrainingStatus status;
  final ExerciseFeedback? currentFeedback;
  final SessionSummary? sessionSummary;
  
  RangeTrainingProgress({
    required this.session,
    required this.currentExerciseIndex,
    required this.completedExercises,
    required this.accuracy,
    required this.status,
    this.currentFeedback,
    this.sessionSummary,
  });
}

class ExerciseFeedback {
  final DateTime timestamp;
  final double targetPitch;
  final double actualPitch;
  final double accuracy;
  final bool isOnTarget;
  
  ExerciseFeedback({
    required this.timestamp,
    required this.targetPitch,
    required this.actualPitch,
    required this.accuracy,
    required this.isOnTarget,
  });
}

class SessionSummary {
  final String sessionId;
  final Duration duration;
  final double accuracy;
  final int completedExercises;
  final int totalExercises;
  final double rangeImprovement;
  final double stabilityImprovement;
  final List<String> recommendations;
  final List<String> achievements;
  
  SessionSummary({
    required this.sessionId,
    required this.duration,
    required this.accuracy,
    required this.completedExercises,
    required this.totalExercises,
    required this.rangeImprovement,
    required this.stabilityImprovement,
    required this.recommendations,
    required this.achievements,
  });
}

// Enums
enum RangeTrainingGoal {
  extend,    // Expand vocal range
  strengthen, // Strengthen existing range
  smooth,    // Improve transitions
  balance,   // Balance across range
}

enum RangeExerciseType {
  extension,
  sustain,
  glissando,
  scale,
  intervals,
}

enum RangeDirection {
  lower,
  higher,
  both,
  steady,
}

enum ExercisePattern {
  chromatic,
  majorScale,
  minorScale,
  pentatonic,
  intervals,
  sustained,
  glissando,
}

enum TrainingStatus {
  started,
  inProgress,
  paused,
  completed,
  cancelled,
}