import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../session_management/recording_session_manager.dart';
import '../progress_tracking/progress_dashboard.dart';

/// AI-powered vocal exercise generator with adaptive learning
class AIExerciseGenerator {
  final ProgressDashboard _progressDashboard;
  final StreamController<List<VocalExercise>> _exerciseController = 
      StreamController<List<VocalExercise>>.broadcast();
  
  Stream<List<VocalExercise>> get exerciseStream => _exerciseController.stream;
  
  final List<VocalExercise> _currentExercises = [];
  final List<ExerciseTemplate> _exerciseTemplates = [];
  final Map<String, UserSkillProfile> _skillProfiles = {};
  
  AIExerciseGenerator(this._progressDashboard) {
    _initializeExerciseTemplates();
    _subscribeToProgress();
  }
  
  void _initializeExerciseTemplates() {
    _exerciseTemplates.addAll([
      // Breathing exercises
      ExerciseTemplate(
        id: 'breathing_basic',
        name: '기본 호흡 연습',
        category: ExerciseCategory.breathing,
        difficulty: 1,
        duration: const Duration(minutes: 5),
        description: '올바른 복식호흡을 익히는 기본 연습입니다.',
        instructions: [
          '편안한 자세로 서거나 앉으세요',
          '한 손은 가슴에, 다른 손은 배에 올려주세요',
          '코로 천천히 숨을 들이마시며 배가 부풀어 오르는지 확인하세요',
          '입으로 천천히 숨을 내쉬며 배가 들어가는지 확인하세요',
        ],
        targetSkills: ['breathing', 'breath_control'],
        prerequisites: [],
        adaptationRules: {
          'low_breathing_score': 'increase_duration',
          'high_breathing_score': 'add_complexity',
        },
      ),
      
      ExerciseTemplate(
        id: 'breathing_control',
        name: '호흡 조절 연습',
        category: ExerciseCategory.breathing,
        difficulty: 2,
        duration: const Duration(minutes: 8),
        description: '호흡의 길이와 강도를 조절하는 연습입니다.',
        instructions: [
          '4박자로 숨을 들이마시세요',
          '4박자 동안 숨을 참으세요',
          '8박자로 천천히 숨을 내쉬세요',
          '점진적으로 내쉬는 시간을 늘려가세요',
        ],
        targetSkills: ['breath_control', 'rhythm'],
        prerequisites: ['breathing_basic'],
        adaptationRules: {
          'master_level': 'increase_hold_time',
          'difficulty_struggle': 'reduce_hold_time',
        },
      ),
      
      // Vocal warm-up exercises
      ExerciseTemplate(
        id: 'lip_trill',
        name: '입술 트릴',
        category: ExerciseCategory.warmup,
        difficulty: 1,
        duration: const Duration(minutes: 3),
        description: '성대를 부드럽게 워밍업하는 기본 연습입니다.',
        instructions: [
          '입술을 편안하게 다물어주세요',
          '숨을 내쉬며 입술을 떨어주세요',
          '편안한 음높이에서 "브르르" 소리를 내주세요',
          '점차 음높이를 올리고 내리며 연습하세요',
        ],
        targetSkills: ['vocal_flexibility', 'relaxation'],
        prerequisites: [],
        adaptationRules: {
          'tension_detected': 'emphasize_relaxation',
          'good_flexibility': 'expand_range',
        },
      ),
      
      // Pitch exercises
      ExerciseTemplate(
        id: 'scale_practice',
        name: '스케일 연습',
        category: ExerciseCategory.pitch,
        difficulty: 2,
        duration: const Duration(minutes: 10),
        description: '정확한 음정으로 스케일을 부르는 연습입니다.',
        instructions: [
          '편안한 음높이에서 시작하세요',
          'Do-Re-Mi-Fa-Sol-Fa-Mi-Re-Do를 부르세요',
          '각 음을 정확하게 맞춰주세요',
          '점차 다른 조로도 연습해보세요',
        ],
        targetSkills: ['pitch_accuracy', 'interval_recognition'],
        prerequisites: ['lip_trill'],
        adaptationRules: {
          'poor_pitch_accuracy': 'slow_down_tempo',
          'perfect_pitch': 'add_complex_intervals',
        },
      ),
      
      // Articulation exercises
      ExerciseTemplate(
        id: 'consonant_drill',
        name: '자음 연습',
        category: ExerciseCategory.articulation,
        difficulty: 2,
        duration: const Duration(minutes: 6),
        description: '명확한 자음 발음을 위한 연습입니다.',
        instructions: [
          'P-B-T-D-K-G 자음을 명확하게 발음하세요',
          '각 자음을 과장되게 연습하세요',
          '빠른 속도로 반복해보세요',
          '모음과 결합하여 연습하세요',
        ],
        targetSkills: ['articulation', 'clarity'],
        prerequisites: [],
        adaptationRules: {
          'unclear_articulation': 'slow_down_speed',
          'excellent_clarity': 'add_tongue_twisters',
        },
      ),
      
      // Advanced exercises
      ExerciseTemplate(
        id: 'melisma_practice',
        name: '멜리스마 연습',
        category: ExerciseCategory.advanced,
        difficulty: 4,
        duration: const Duration(minutes: 12),
        description: '한 음절에 여러 음을 부르는 고급 기법입니다.',
        instructions: [
          '편안한 모음(아, 에)으로 시작하세요',
          '한 음절에 3-5개의 음을 연결하세요',
          '부드럽게 음정이 연결되도록 주의하세요',
          '점차 복잡한 패턴으로 발전시키세요',
        ],
        targetSkills: ['vocal_agility', 'breath_control', 'pitch_accuracy'],
        prerequisites: ['scale_practice', 'breathing_control'],
        adaptationRules: {
          'insufficient_breath': 'add_breathing_breaks',
          'poor_connection': 'simplify_patterns',
        },
      ),
    ]);
  }
  
  void _subscribeToProgress() {
    _progressDashboard.progressStream.listen((progressData) {
      _updateSkillProfile(progressData);
      _generatePersonalizedExercises(progressData);
    });
  }
  
  /// Generate personalized exercises based on user progress
  Future<List<VocalExercise>> generatePersonalizedExercises({
    int count = 5,
    ExerciseCategory? focusCategory,
    int? targetDifficulty,
    Duration? sessionDuration,
  }) async {
    final progressData = _progressDashboard.currentProgress;
    if (progressData == null) {
      return _generateDefaultExercises(count);
    }
    
    final skillProfile = _createSkillProfile(progressData);
    final exercises = <VocalExercise>[];
    
    // Analyze weak points
    final weakestSkills = _identifyWeakestSkills(skillProfile);
    final strengths = _identifyStrengths(skillProfile);
    
    // Generate warm-up exercise (always first)
    exercises.add(_generateWarmupExercise(skillProfile));
    
    // Generate targeted exercises for weak skills
    for (final weakSkill in weakestSkills.take(2)) {
      final exercise = _generateSkillTargetedExercise(weakSkill, skillProfile);
      if (exercise != null) exercises.add(exercise);
    }
    
    // Add progressive challenge exercises
    final challengeExercise = _generateChallengeExercise(skillProfile, strengths);
    if (challengeExercise != null) exercises.add(challengeExercise);
    
    // Fill remaining slots with balanced exercises
    while (exercises.length < count) {
      final balancedExercise = _generateBalancedExercise(skillProfile, exercises);
      if (balancedExercise != null) {
        exercises.add(balancedExercise);
      } else {
        break;
      }
    }
    
    // Apply AI adaptations
    for (final exercise in exercises) {
      _applyAIAdaptations(exercise, skillProfile, progressData);
    }
    
    _currentExercises.clear();
    _currentExercises.addAll(exercises);
    _exerciseController.add(exercises);
    
    return exercises;
  }
  
  /// Generate exercise for specific skill improvement
  VocalExercise? generateSkillFocusExercise(String skillName) {
    final template = _exerciseTemplates
        .where((t) => t.targetSkills.contains(skillName))
        .reduce((a, b) => a.difficulty < b.difficulty ? a : b);
    
    return _createExerciseFromTemplate(template, UserSkillProfile.defaultProfile());
  }
  
  /// Adapt exercise difficulty based on performance
  void adaptExerciseDifficulty(String exerciseId, double performanceScore) {
    final exercise = _currentExercises.firstWhere(
      (e) => e.id == exerciseId,
      orElse: () => throw Exception('Exercise not found'),
    );
    
    if (performanceScore < 0.6) {
      // Make easier
      exercise.difficulty = math.max(1, exercise.difficulty - 1);
      exercise.tempo = (exercise.tempo * 0.9).round();
      if (exercise.parameters.containsKey('complexity')) {
        exercise.parameters['complexity'] = 
            (exercise.parameters['complexity'] as int) - 1;
      }
    } else if (performanceScore > 0.85) {
      // Make harder
      exercise.difficulty = math.min(5, exercise.difficulty + 1);
      exercise.tempo = (exercise.tempo * 1.1).round();
      if (exercise.parameters.containsKey('complexity')) {
        exercise.parameters['complexity'] = 
            (exercise.parameters['complexity'] as int) + 1;
      }
    }
    
    _exerciseController.add(List.from(_currentExercises));
  }
  
  void _updateSkillProfile(ProgressData progressData) {
    final profile = _createSkillProfile(progressData);
    _skillProfiles['current_user'] = profile;
  }
  
  void _generatePersonalizedExercises(ProgressData progressData) {
    // Auto-generate new exercises when significant progress is detected
    final profile = _skillProfiles['current_user'];
    if (profile != null && _shouldRegenerateExercises(profile, progressData)) {
      generatePersonalizedExercises();
    }
  }
  
  bool _shouldRegenerateExercises(UserSkillProfile profile, ProgressData progressData) {
    // Regenerate if user has improved significantly
    return progressData.overallMetrics.improvement > 0.1 ||
           progressData.achievements.any((a) => 
               DateTime.now().difference(a.unlockedAt).inHours < 24);
  }
  
  UserSkillProfile _createSkillProfile(ProgressData progressData) {
    final skillLevels = <String, double>{};
    final preferences = <String, double>{};
    
    progressData.skillMetrics.forEach((skill, metric) {
      skillLevels[skill] = metric.current;
    });
    
    // Infer preferences from practice patterns
    final practiceMetrics = progressData.practiceMetrics;
    preferences['session_length'] = practiceMetrics.averageSessionDuration.inMinutes.toDouble();
    preferences['challenge_level'] = progressData.overallMetrics.consistency > 0.7 ? 0.8 : 0.5;
    
    return UserSkillProfile(
      skillLevels: skillLevels,
      preferences: preferences,
      practiceHistory: progressData.weeklyProgress.length,
      currentStreak: progressData.overallMetrics.practiceStreak,
    );
  }
  
  List<String> _identifyWeakestSkills(UserSkillProfile profile) {
    final sortedSkills = profile.skillLevels.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    return sortedSkills.take(3).map((e) => e.key).toList();
  }
  
  List<String> _identifyStrengths(UserSkillProfile profile) {
    final sortedSkills = profile.skillLevels.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedSkills.take(2).map((e) => e.key).toList();
  }
  
  VocalExercise _generateWarmupExercise(UserSkillProfile profile) {
    final template = _exerciseTemplates
        .where((t) => t.category == ExerciseCategory.warmup)
        .reduce((a, b) => math.Random().nextBool() ? a : b);
    
    return _createExerciseFromTemplate(template, profile);
  }
  
  VocalExercise? _generateSkillTargetedExercise(String skillName, UserSkillProfile profile) {
    final targetTemplates = _exerciseTemplates
        .where((t) => t.targetSkills.contains(skillName))
        .toList();
    
    if (targetTemplates.isEmpty) return null;
    
    // Choose template based on current skill level
    final skillLevel = profile.skillLevels[skillName] ?? 0.5;
    final targetDifficulty = (skillLevel * 4 + 1).round().clamp(1, 5);
    
    final suitableTemplates = targetTemplates
        .where((t) => (t.difficulty - targetDifficulty).abs() <= 1)
        .toList();
    
    if (suitableTemplates.isEmpty) return null;
    
    final template = suitableTemplates[math.Random().nextInt(suitableTemplates.length)];
    return _createExerciseFromTemplate(template, profile);
  }
  
  VocalExercise? _generateChallengeExercise(UserSkillProfile profile, List<String> strengths) {
    final challengeTemplates = _exerciseTemplates
        .where((t) => t.difficulty >= 3 && 
                     strengths.any((s) => t.targetSkills.contains(s)))
        .toList();
    
    if (challengeTemplates.isEmpty) return null;
    
    final template = challengeTemplates[math.Random().nextInt(challengeTemplates.length)];
    return _createExerciseFromTemplate(template, profile);
  }
  
  VocalExercise? _generateBalancedExercise(UserSkillProfile profile, List<VocalExercise> existingExercises) {
    final usedCategories = existingExercises.map((e) => e.category).toSet();
    final availableTemplates = _exerciseTemplates
        .where((t) => !usedCategories.contains(t.category))
        .toList();
    
    if (availableTemplates.isEmpty) {
      // Fall back to any available template
      final template = _exerciseTemplates[math.Random().nextInt(_exerciseTemplates.length)];
      return _createExerciseFromTemplate(template, profile);
    }
    
    final template = availableTemplates[math.Random().nextInt(availableTemplates.length)];
    return _createExerciseFromTemplate(template, profile);
  }
  
  VocalExercise _createExerciseFromTemplate(ExerciseTemplate template, UserSkillProfile profile) {
    final exercise = VocalExercise(
      id: '${template.id}_${DateTime.now().millisecondsSinceEpoch}',
      templateId: template.id,
      name: template.name,
      category: template.category,
      difficulty: template.difficulty,
      duration: template.duration,
      description: template.description,
      instructions: List.from(template.instructions),
      targetSkills: List.from(template.targetSkills),
      tempo: 120, // Default tempo
      key: 'C', // Default key
      parameters: {},
    );
    
    // Customize based on user profile
    _customizeExercise(exercise, profile, template);
    
    return exercise;
  }
  
  void _customizeExercise(VocalExercise exercise, UserSkillProfile profile, ExerciseTemplate template) {
    // Adjust difficulty based on skill level
    final relevantSkills = exercise.targetSkills
        .where((s) => profile.skillLevels.containsKey(s))
        .toList();
    
    if (relevantSkills.isNotEmpty) {
      final avgSkillLevel = relevantSkills
          .map((s) => profile.skillLevels[s]!)
          .reduce((a, b) => a + b) / relevantSkills.length;
      
      if (avgSkillLevel < 0.4) {
        exercise.difficulty = math.max(1, exercise.difficulty - 1);
        exercise.tempo = (exercise.tempo * 0.8).round();
      } else if (avgSkillLevel > 0.8) {
        exercise.difficulty = math.min(5, exercise.difficulty + 1);
        exercise.tempo = (exercise.tempo * 1.2).round();
      }
    }
    
    // Adjust duration based on preferences
    final preferredLength = profile.preferences['session_length'] ?? 10.0;
    if (preferredLength < 8) {
      exercise.duration = Duration(
        milliseconds: (exercise.duration.inMilliseconds * 0.8).round(),
      );
    } else if (preferredLength > 15) {
      exercise.duration = Duration(
        milliseconds: (exercise.duration.inMilliseconds * 1.3).round(),
      );
    }
  }
  
  void _applyAIAdaptations(VocalExercise exercise, UserSkillProfile profile, ProgressData progressData) {
    final template = _exerciseTemplates.firstWhere((t) => t.id == exercise.templateId);
    
    template.adaptationRules.forEach((condition, adaptation) {
      if (_checkAdaptationCondition(condition, profile, progressData)) {
        _applyAdaptation(exercise, adaptation);
      }
    });
  }
  
  bool _checkAdaptationCondition(String condition, UserSkillProfile profile, ProgressData progressData) {
    switch (condition) {
      case 'low_breathing_score':
        return (profile.skillLevels['breathing'] ?? 1.0) < 0.5;
      case 'high_breathing_score':
        return (profile.skillLevels['breathing'] ?? 0.0) > 0.8;
      case 'master_level':
        return progressData.overallMetrics.totalScore > 0.9;
      case 'difficulty_struggle':
        return progressData.overallMetrics.improvement < -0.05;
      case 'tension_detected':
        return (profile.skillLevels['relaxation'] ?? 1.0) < 0.6;
      case 'good_flexibility':
        return (profile.skillLevels['vocal_flexibility'] ?? 0.0) > 0.7;
      case 'poor_pitch_accuracy':
        return (profile.skillLevels['pitch_accuracy'] ?? 1.0) < 0.6;
      case 'perfect_pitch':
        return (profile.skillLevels['pitch_accuracy'] ?? 0.0) > 0.95;
      default:
        return false;
    }
  }
  
  void _applyAdaptation(VocalExercise exercise, String adaptation) {
    switch (adaptation) {
      case 'increase_duration':
        exercise.duration = Duration(
          milliseconds: (exercise.duration.inMilliseconds * 1.5).round(),
        );
        break;
      case 'add_complexity':
        exercise.parameters['complexity'] = (exercise.parameters['complexity'] ?? 1) + 1;
        break;
      case 'increase_hold_time':
        exercise.parameters['hold_time'] = (exercise.parameters['hold_time'] ?? 4) + 2;
        break;
      case 'reduce_hold_time':
        exercise.parameters['hold_time'] = math.max(2, (exercise.parameters['hold_time'] ?? 4) - 1);
        break;
      case 'emphasize_relaxation':
        exercise.instructions.insert(0, '긴장을 완전히 풀고 편안한 상태에서 시작하세요');
        break;
      case 'expand_range':
        exercise.parameters['range_extension'] = true;
        break;
      case 'slow_down_tempo':
        exercise.tempo = (exercise.tempo * 0.7).round();
        break;
      case 'add_complex_intervals':
        exercise.parameters['interval_complexity'] = 'advanced';
        break;
    }
  }
  
  List<VocalExercise> _generateDefaultExercises(int count) {
    final defaultTemplates = _exerciseTemplates.take(count).toList();
    return defaultTemplates
        .map((t) => _createExerciseFromTemplate(t, UserSkillProfile.defaultProfile()))
        .toList();
  }
  
  List<VocalExercise> get currentExercises => List.from(_currentExercises);
  
  void dispose() {
    _exerciseController.close();
  }
}

/// Template for generating vocal exercises
class ExerciseTemplate {
  final String id;
  final String name;
  final ExerciseCategory category;
  final int difficulty;
  final Duration duration;
  final String description;
  final List<String> instructions;
  final List<String> targetSkills;
  final List<String> prerequisites;
  final Map<String, String> adaptationRules;
  
  ExerciseTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.duration,
    required this.description,
    required this.instructions,
    required this.targetSkills,
    required this.prerequisites,
    required this.adaptationRules,
  });
}

/// Generated vocal exercise instance
class VocalExercise {
  final String id;
  final String templateId;
  String name;
  final ExerciseCategory category;
  int difficulty;
  Duration duration;
  final String description;
  final List<String> instructions;
  final List<String> targetSkills;
  int tempo;
  String key;
  final Map<String, dynamic> parameters;
  
  // Progress tracking
  DateTime? startedAt;
  DateTime? completedAt;
  double? performanceScore;
  List<String> feedback = [];
  
  VocalExercise({
    required this.id,
    required this.templateId,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.duration,
    required this.description,
    required this.instructions,
    required this.targetSkills,
    required this.tempo,
    required this.key,
    required this.parameters,
  });
  
  bool get isCompleted => completedAt != null;
  bool get isInProgress => startedAt != null && completedAt == null;
  
  Duration? get actualDuration {
    if (startedAt == null) return null;
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(startedAt!);
  }
  
  void start() {
    startedAt = DateTime.now();
  }
  
  void complete({double? score, List<String>? feedbackItems}) {
    completedAt = DateTime.now();
    performanceScore = score;
    if (feedbackItems != null) {
      feedback.addAll(feedbackItems);
    }
  }
}

/// User's skill profile for exercise personalization
class UserSkillProfile {
  final Map<String, double> skillLevels;
  final Map<String, double> preferences;
  final int practiceHistory;
  final int currentStreak;
  
  UserSkillProfile({
    required this.skillLevels,
    required this.preferences,
    required this.practiceHistory,
    required this.currentStreak,
  });
  
  factory UserSkillProfile.defaultProfile() {
    return UserSkillProfile(
      skillLevels: {
        'breathing': 0.5,
        'pitch_accuracy': 0.5,
        'rhythm_accuracy': 0.5,
        'tone_quality': 0.5,
        'vocal_flexibility': 0.5,
        'articulation': 0.5,
      },
      preferences: {
        'session_length': 10.0,
        'challenge_level': 0.5,
      },
      practiceHistory: 0,
      currentStreak: 0,
    );
  }
}

enum ExerciseCategory {
  breathing,
  warmup,
  pitch,
  rhythm,
  articulation,
  resonance,
  range,
  style,
  advanced,
}