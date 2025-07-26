import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../session_management/recording_session_manager.dart';

/// Comprehensive progress tracking and analytics dashboard
class ProgressDashboard {
  final RecordingSessionManager _sessionManager;
  final StreamController<ProgressData> _progressController = 
      StreamController<ProgressData>.broadcast();
  
  Stream<ProgressData> get progressStream => _progressController.stream;
  
  ProgressData? _currentProgress;
  Timer? _updateTimer;
  
  ProgressDashboard(this._sessionManager) {
    _initializeTracking();
  }
  
  void _initializeTracking() {
    // Listen to session changes
    _sessionManager.sessionsStream.listen((sessions) {
      _updateProgress(sessions);
    });
    
    // Periodic progress updates
    _updateTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _updateProgress(_sessionManager.getAllSessions()),
    );
  }
  
  /// Update progress data based on current sessions
  void _updateProgress(List<VocalSession> sessions) {
    final progressData = _calculateProgress(sessions);
    _currentProgress = progressData;
    _progressController.add(progressData);
  }
  
  /// Calculate comprehensive progress data
  ProgressData _calculateProgress(List<VocalSession> sessions) {
    final now = DateTime.now();
    
    // Time ranges
    final today = DateTime(now.year, now.month, now.day);
    final thisWeek = now.subtract(const Duration(days: 7));
    final thisMonth = DateTime(now.year, now.month, 1);
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    
    // Filter sessions by time periods
    final todaySessions = sessions.where((s) => s.createdAt.isAfter(today)).toList();
    final thisWeekSessions = sessions.where((s) => s.createdAt.isAfter(thisWeek)).toList();
    final thisMonthSessions = sessions.where((s) => s.createdAt.isAfter(thisMonth)).toList();
    final lastMonthSessions = sessions.where((s) => 
        s.createdAt.isAfter(lastMonth) && s.createdAt.isBefore(thisMonth)).toList();
    
    // Calculate metrics
    final overallMetrics = _calculateOverallMetrics(sessions);
    final skillMetrics = _calculateSkillMetrics(sessions);
    final practiceMetrics = _calculatePracticeMetrics(sessions);
    final trendMetrics = _calculateTrendMetrics(sessions);
    final weeklyProgress = _calculateWeeklyProgress(sessions);
    final achievements = _calculateAchievements(sessions);
    final insights = _generateInsights(sessions, overallMetrics);
    
    return ProgressData(
      overallMetrics: overallMetrics,
      skillMetrics: skillMetrics,
      practiceMetrics: practiceMetrics,
      trendMetrics: trendMetrics,
      weeklyProgress: weeklyProgress,
      achievements: achievements,
      insights: insights,
      lastUpdated: now,
    );
  }
  
  /// Calculate overall performance metrics
  OverallMetrics _calculateOverallMetrics(List<VocalSession> sessions) {
    if (sessions.isEmpty) {
      return OverallMetrics(
        totalScore: 0.0,
        improvement: 0.0,
        consistency: 0.0,
        practiceStreak: 0,
        totalPracticeTime: Duration.zero,
        averageSessionDuration: Duration.zero,
      );
    }
    
    final allRecordings = sessions.expand((s) => s.recordings).toList();
    final validAnalyses = allRecordings
        .where((r) => r.analysis != null)
        .map((r) => r.analysis!)
        .toList();
    
    if (validAnalyses.isEmpty) {
      return OverallMetrics(
        totalScore: 0.0,
        improvement: 0.0,
        consistency: 0.0,
        practiceStreak: 0,
        totalPracticeTime: Duration.zero,
        averageSessionDuration: Duration.zero,
      );
    }
    
    // Calculate average scores
    final totalScore = validAnalyses
        .map((a) => a.overallScore)
        .reduce((a, b) => a + b) / validAnalyses.length;
    
    // Calculate improvement (last 5 vs first 5 sessions)
    final recentScores = validAnalyses.take(5).map((a) => a.overallScore);
    final earlierScores = validAnalyses.skip(math.max(0, validAnalyses.length - 5))
        .map((a) => a.overallScore);
    
    final recentAvg = recentScores.isNotEmpty 
        ? recentScores.reduce((a, b) => a + b) / recentScores.length
        : 0.0;
    final earlierAvg = earlierScores.isNotEmpty
        ? earlierScores.reduce((a, b) => a + b) / earlierScores.length
        : 0.0;
    
    final improvement = earlierAvg > 0 ? (recentAvg - earlierAvg) / earlierAvg : 0.0;
    
    // Calculate consistency (inverse of standard deviation)
    final mean = totalScore;
    final variance = validAnalyses
        .map((a) => math.pow(a.overallScore - mean, 2))
        .reduce((a, b) => a + b) / validAnalyses.length;
    final consistency = 1.0 / (1.0 + math.sqrt(variance));
    
    // Calculate practice streak
    final practiceStreak = _calculatePracticeStreak(sessions);
    
    // Calculate total practice time
    final totalPracticeTime = sessions.fold<Duration>(
      Duration.zero,
      (sum, session) => sum + session.totalDuration,
    );
    
    final averageSessionDuration = Duration(
      milliseconds: (totalPracticeTime.inMilliseconds / sessions.length).round(),
    );
    
    return OverallMetrics(
      totalScore: totalScore,
      improvement: improvement,
      consistency: consistency,
      practiceStreak: practiceStreak,
      totalPracticeTime: totalPracticeTime,
      averageSessionDuration: averageSessionDuration,
    );
  }
  
  /// Calculate skill-specific metrics
  Map<String, SkillMetric> _calculateSkillMetrics(List<VocalSession> sessions) {
    final skills = <String, List<double>>{
      'pitch_accuracy': [],
      'rhythm_accuracy': [],
      'tone_quality': [],
      'breathing': [],
      'resonance': [],
      'articulation': [],
    };
    
    for (final session in sessions) {
      for (final recording in session.recordings) {
        final analysis = recording.analysis;
        if (analysis != null) {
          skills['pitch_accuracy']!.add(analysis.pitchAccuracy);
          skills['rhythm_accuracy']!.add(analysis.rhythmAccuracy);
          skills['tone_quality']!.add(analysis.toneQuality);
          
          // Extract from detailed metrics
          skills['breathing']!.add(analysis.detailedMetrics['breathing'] ?? 0.0);
          skills['resonance']!.add(analysis.detailedMetrics['resonance'] ?? 0.0);
          skills['articulation']!.add(analysis.detailedMetrics['articulation'] ?? 0.0);
        }
      }
    }
    
    final skillMetrics = <String, SkillMetric>{};
    
    skills.forEach((skillName, scores) {
      if (scores.isNotEmpty) {
        final current = scores.take(10).reduce((a, b) => a + b) / 
                       math.min(10, scores.length);
        final previous = scores.length > 10 
            ? scores.skip(10).take(10).reduce((a, b) => a + b) / 
              math.min(10, scores.length - 10)
            : current;
        
        final trend = previous > 0 ? (current - previous) / previous : 0.0;
        final level = _getSkillLevel(current);
        
        skillMetrics[skillName] = SkillMetric(
          current: current,
          trend: trend,
          level: level,
          history: List.from(scores.reversed.take(30)),
        );
      }
    });
    
    return skillMetrics;
  }
  
  /// Calculate practice-related metrics
  PracticeMetrics _calculatePracticeMetrics(List<VocalSession> sessions) {
    final now = DateTime.now();
    final thisWeek = now.subtract(const Duration(days: 7));
    final thisMonth = now.subtract(const Duration(days: 30));
    
    final thisWeekSessions = sessions.where((s) => s.createdAt.isAfter(thisWeek));
    final thisMonthSessions = sessions.where((s) => s.createdAt.isAfter(thisMonth));
    
    final weeklyPracticeTime = thisWeekSessions.fold<Duration>(
      Duration.zero,
      (sum, session) => sum + session.totalDuration,
    );
    
    final monthlyPracticeTime = thisMonthSessions.fold<Duration>(
      Duration.zero,
      (sum, session) => sum + session.totalDuration,
    );
    
    // Calculate practice distribution by session type
    final sessionTypeDistribution = <SessionType, int>{};
    for (final session in thisMonthSessions) {
      sessionTypeDistribution[session.type] = 
          (sessionTypeDistribution[session.type] ?? 0) + 1;
    }
    
    // Calculate best practice times
    final hourDistribution = <int, int>{};
    for (final session in sessions) {
      final hour = session.createdAt.hour;
      hourDistribution[hour] = (hourDistribution[hour] ?? 0) + 1;
    }
    
    final bestPracticeHour = hourDistribution.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    
    return PracticeMetrics(
      weeklyPracticeTime: weeklyPracticeTime,
      monthlyPracticeTime: monthlyPracticeTime,
      weeklySessionCount: thisWeekSessions.length,
      monthlySessionCount: thisMonthSessions.length,
      sessionTypeDistribution: sessionTypeDistribution,
      bestPracticeHour: bestPracticeHour,
      practiceConsistency: _calculatePracticeConsistency(sessions),
    );
  }
  
  /// Calculate trend metrics
  TrendMetrics _calculateTrendMetrics(List<VocalSession> sessions) {
    if (sessions.length < 2) {
      return TrendMetrics(
        scoreProgression: [],
        skillTrends: {},
        performancePrediction: 0.0,
        nextMilestone: null,
      );
    }
    
    // Score progression over time
    final scoreProgression = <ProgressPoint>[];
    final now = DateTime.now();
    
    for (int i = 0; i < math.min(30, sessions.length); i++) {
      final session = sessions[i];
      final avgScore = session.averageScore;
      if (avgScore > 0) {
        scoreProgression.add(ProgressPoint(
          date: session.createdAt,
          value: avgScore,
          daysAgo: now.difference(session.createdAt).inDays,
        ));
      }
    }
    
    // Skill trends
    final skillTrends = <String, List<ProgressPoint>>{};
    final skillMetrics = _calculateSkillMetrics(sessions);
    
    skillMetrics.forEach((skill, metric) {
      skillTrends[skill] = metric.history
          .asMap()
          .entries
          .map((entry) => ProgressPoint(
                date: now.subtract(Duration(days: entry.key)),
                value: entry.value,
                daysAgo: entry.key,
              ))
          .toList();
    });
    
    // Performance prediction using linear regression
    final performancePrediction = _predictFuturePerformance(scoreProgression);
    
    // Next milestone
    final nextMilestone = _calculateNextMilestone(scoreProgression.isNotEmpty 
        ? scoreProgression.first.value : 0.0);
    
    return TrendMetrics(
      scoreProgression: scoreProgression,
      skillTrends: skillTrends,
      performancePrediction: performancePrediction,
      nextMilestone: nextMilestone,
    );
  }
  
  /// Calculate weekly progress
  List<WeeklyProgress> _calculateWeeklyProgress(List<VocalSession> sessions) {
    final now = DateTime.now();
    final weeklyProgress = <WeeklyProgress>[];
    
    for (int i = 0; i < 12; i++) { // Last 12 weeks
      final weekStart = now.subtract(Duration(days: (i + 1) * 7));
      final weekEnd = now.subtract(Duration(days: i * 7));
      
      final weekSessions = sessions.where((s) => 
          s.createdAt.isAfter(weekStart) && s.createdAt.isBefore(weekEnd)).toList();
      
      final totalDuration = weekSessions.fold<Duration>(
        Duration.zero,
        (sum, session) => sum + session.totalDuration,
      );
      
      final averageScore = weekSessions.isNotEmpty
          ? weekSessions.map((s) => s.averageScore).reduce((a, b) => a + b) / 
            weekSessions.length
          : 0.0;
      
      weeklyProgress.insert(0, WeeklyProgress(
        weekStart: weekStart,
        sessionCount: weekSessions.length,
        totalDuration: totalDuration,
        averageScore: averageScore,
        improvement: i < 11 && weeklyProgress.isNotEmpty 
            ? averageScore - weeklyProgress.last.averageScore
            : 0.0,
      ));
    }
    
    return weeklyProgress;
  }
  
  /// Calculate achievements
  List<Achievement> _calculateAchievements(List<VocalSession> sessions) {
    final achievements = <Achievement>[];
    final stats = _sessionManager.getSessionStatistics();
    
    // Practice milestones
    if (stats.totalSessions >= 1) {
      achievements.add(Achievement(
        id: 'first_session',
        title: '첫 연습 완료',
        description: '첫 번째 보컬 트레이닝 세션을 완료했습니다',
        icon: '🎤',
        unlockedAt: sessions.isNotEmpty ? sessions.last.createdAt : DateTime.now(),
        category: AchievementCategory.milestone,
      ));
    }
    
    if (stats.totalSessions >= 10) {
      achievements.add(Achievement(
        id: 'ten_sessions',
        title: '꾸준한 연습가',
        description: '10회 연습 세션을 완료했습니다',
        icon: '🏆',
        unlockedAt: sessions.length >= 10 ? sessions[sessions.length - 10].createdAt : DateTime.now(),
        category: AchievementCategory.milestone,
      ));
    }
    
    if (stats.totalSessions >= 50) {
      achievements.add(Achievement(
        id: 'fifty_sessions',
        title: '전문가의 길',
        description: '50회 연습 세션을 완료했습니다',
        icon: '⭐',
        unlockedAt: sessions.length >= 50 ? sessions[sessions.length - 50].createdAt : DateTime.now(),
        category: AchievementCategory.milestone,
      ));
    }
    
    // Streak achievements
    final streak = _calculatePracticeStreak(sessions);
    if (streak >= 7) {
      achievements.add(Achievement(
        id: 'week_streak',
        title: '일주일 연속 연습',
        description: '7일 연속으로 연습했습니다',
        icon: '🔥',
        unlockedAt: DateTime.now().subtract(Duration(days: streak - 7)),
        category: AchievementCategory.streak,
      ));
    }
    
    if (streak >= 30) {
      achievements.add(Achievement(
        id: 'month_streak',
        title: '한 달 연속 연습',
        description: '30일 연속으로 연습했습니다',
        icon: '🏅',
        unlockedAt: DateTime.now().subtract(Duration(days: streak - 30)),
        category: AchievementCategory.streak,
      ));
    }
    
    // Performance achievements
    final highScoreSessions = sessions.where((s) => s.averageScore >= 0.9).toList();
    if (highScoreSessions.isNotEmpty) {
      achievements.add(Achievement(
        id: 'perfect_score',
        title: '완벽한 연주',
        description: '90% 이상의 점수를 달성했습니다',
        icon: '🌟',
        unlockedAt: highScoreSessions.first.createdAt,
        category: AchievementCategory.performance,
      ));
    }
    
    // Time-based achievements
    if (stats.totalDuration.inHours >= 10) {
      achievements.add(Achievement(
        id: 'ten_hours',
        title: '10시간 연습가',
        description: '총 10시간의 연습을 완료했습니다',
        icon: '⏰',
        unlockedAt: DateTime.now(),
        category: AchievementCategory.time,
      ));
    }
    
    return achievements..sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
  }
  
  /// Generate insights based on data
  List<Insight> _generateInsights(List<VocalSession> sessions, OverallMetrics metrics) {
    final insights = <Insight>[];
    
    // Performance insights
    if (metrics.improvement > 0.1) {
      insights.add(Insight(
        type: InsightType.positive,
        title: '실력 향상 중!',
        description: '최근 ${(metrics.improvement * 100).round()}% 향상을 보이고 있습니다.',
        actionable: '현재 연습 방식을 계속 유지하세요.',
        priority: InsightPriority.high,
      ));
    } else if (metrics.improvement < -0.05) {
      insights.add(Insight(
        type: InsightType.warning,
        title: '연습 패턴 점검 필요',
        description: '최근 실력이 정체되고 있습니다.',
        actionable: '다른 연습 방법을 시도해보거나 휴식을 취해보세요.',
        priority: InsightPriority.medium,
      ));
    }
    
    // Practice frequency insights
    if (metrics.practiceStreak >= 7) {
      insights.add(Insight(
        type: InsightType.positive,
        title: '꾸준한 연습!',
        description: '${metrics.practiceStreak}일 연속 연습 중입니다.',
        actionable: '이 좋은 습관을 계속 유지하세요.',
        priority: InsightPriority.medium,
      ));
    }
    
    // Consistency insights
    if (metrics.consistency > 0.8) {
      insights.add(Insight(
        type: InsightType.positive,
        title: '안정된 실력',
        description: '연습 결과가 매우 일관성 있습니다.',
        actionable: '더 도전적인 목표를 설정해보세요.',
        priority: InsightPriority.low,
      ));
    } else if (metrics.consistency < 0.5) {
      insights.add(Insight(
        type: InsightType.suggestion,
        title: '연습 결과 편차가 큽니다',
        description: '매번 다른 결과를 보이고 있습니다.',
        actionable: '기본기 연습에 더 집중해보세요.',
        priority: InsightPriority.medium,
      ));
    }
    
    return insights;
  }
  
  int _calculatePracticeStreak(List<VocalSession> sessions) {
    if (sessions.isEmpty) return 0;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int streak = 0;
    DateTime checkDate = today;
    
    while (true) {
      final hasPractice = sessions.any((s) {
        final sessionDate = DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day);
        return sessionDate == checkDate;
      });
      
      if (hasPractice) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        // Allow one day gap for today
        if (checkDate == today) {
          checkDate = checkDate.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
    }
    
    return streak;
  }
  
  double _calculatePracticeConsistency(List<VocalSession> sessions) {
    if (sessions.length < 7) return 0.0;
    
    final last30Days = DateTime.now().subtract(const Duration(days: 30));
    final recentSessions = sessions.where((s) => s.createdAt.isAfter(last30Days)).toList();
    
    if (recentSessions.isEmpty) return 0.0;
    
    // Calculate days with practice
    final practiceDays = <DateTime>{};
    for (final session in recentSessions) {
      final day = DateTime(session.createdAt.year, session.createdAt.month, session.createdAt.day);
      practiceDays.add(day);
    }
    
    return practiceDays.length / 30.0;
  }
  
  SkillLevel _getSkillLevel(double score) {
    if (score >= 0.9) return SkillLevel.expert;
    if (score >= 0.8) return SkillLevel.advanced;
    if (score >= 0.6) return SkillLevel.intermediate;
    if (score >= 0.4) return SkillLevel.beginner;
    return SkillLevel.novice;
  }
  
  double _predictFuturePerformance(List<ProgressPoint> progression) {
    if (progression.length < 5) return 0.0;
    
    // Simple linear regression
    final n = progression.length;
    final sumX = progression.map((p) => p.daysAgo.toDouble()).reduce((a, b) => a + b);
    final sumY = progression.map((p) => p.value).reduce((a, b) => a + b);
    final sumXY = progression.map((p) => p.daysAgo * p.value).reduce((a, b) => a + b);
    final sumX2 = progression.map((p) => p.daysAgo * p.daysAgo).reduce((a, b) => a + b);
    
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;
    
    // Predict score in 30 days
    return (intercept + slope * -30).clamp(0.0, 1.0);
  }
  
  Milestone? _calculateNextMilestone(double currentScore) {
    final milestones = [
      Milestone(score: 0.5, title: '기초 완성', description: '기본기를 완전히 익혔습니다'),
      Milestone(score: 0.7, title: '중급자 도약', description: '중급 수준에 도달했습니다'),
      Milestone(score: 0.8, title: '고급자 진입', description: '고급 기술을 구사합니다'),
      Milestone(score: 0.9, title: '전문가 수준', description: '전문가 수준의 실력입니다'),
      Milestone(score: 0.95, title: '마스터급', description: '최고 수준의 보컬리스트입니다'),
    ];
    
    return milestones.firstWhere(
      (m) => m.score > currentScore,
      orElse: () => milestones.last,
    );
  }
  
  ProgressData? get currentProgress => _currentProgress;
  
  void dispose() {
    _updateTimer?.cancel();
    _progressController.close();
  }
}

// Data models for progress tracking
class ProgressData {
  final OverallMetrics overallMetrics;
  final Map<String, SkillMetric> skillMetrics;
  final PracticeMetrics practiceMetrics;
  final TrendMetrics trendMetrics;
  final List<WeeklyProgress> weeklyProgress;
  final List<Achievement> achievements;
  final List<Insight> insights;
  final DateTime lastUpdated;
  
  ProgressData({
    required this.overallMetrics,
    required this.skillMetrics,
    required this.practiceMetrics,
    required this.trendMetrics,
    required this.weeklyProgress,
    required this.achievements,
    required this.insights,
    required this.lastUpdated,
  });
}

class OverallMetrics {
  final double totalScore;
  final double improvement;
  final double consistency;
  final int practiceStreak;
  final Duration totalPracticeTime;
  final Duration averageSessionDuration;
  
  OverallMetrics({
    required this.totalScore,
    required this.improvement,
    required this.consistency,
    required this.practiceStreak,
    required this.totalPracticeTime,
    required this.averageSessionDuration,
  });
}

class SkillMetric {
  final double current;
  final double trend;
  final SkillLevel level;
  final List<double> history;
  
  SkillMetric({
    required this.current,
    required this.trend,
    required this.level,
    required this.history,
  });
}

class PracticeMetrics {
  final Duration weeklyPracticeTime;
  final Duration monthlyPracticeTime;
  final int weeklySessionCount;
  final int monthlySessionCount;
  final Map<SessionType, int> sessionTypeDistribution;
  final int bestPracticeHour;
  final double practiceConsistency;
  
  PracticeMetrics({
    required this.weeklyPracticeTime,
    required this.monthlyPracticeTime,
    required this.weeklySessionCount,
    required this.monthlySessionCount,
    required this.sessionTypeDistribution,
    required this.bestPracticeHour,
    required this.practiceConsistency,
  });
}

class TrendMetrics {
  final List<ProgressPoint> scoreProgression;
  final Map<String, List<ProgressPoint>> skillTrends;
  final double performancePrediction;
  final Milestone? nextMilestone;
  
  TrendMetrics({
    required this.scoreProgression,
    required this.skillTrends,
    required this.performancePrediction,
    this.nextMilestone,
  });
}

class WeeklyProgress {
  final DateTime weekStart;
  final int sessionCount;
  final Duration totalDuration;
  final double averageScore;
  final double improvement;
  
  WeeklyProgress({
    required this.weekStart,
    required this.sessionCount,
    required this.totalDuration,
    required this.averageScore,
    required this.improvement,
  });
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final DateTime unlockedAt;
  final AchievementCategory category;
  
  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlockedAt,
    required this.category,
  });
}

class Insight {
  final InsightType type;
  final String title;
  final String description;
  final String actionable;
  final InsightPriority priority;
  
  Insight({
    required this.type,
    required this.title,
    required this.description,
    required this.actionable,
    required this.priority,
  });
}

class ProgressPoint {
  final DateTime date;
  final double value;
  final int daysAgo;
  
  ProgressPoint({
    required this.date,
    required this.value,
    required this.daysAgo,
  });
}

class Milestone {
  final double score;
  final String title;
  final String description;
  
  Milestone({
    required this.score,
    required this.title,
    required this.description,
  });
}

enum SkillLevel {
  novice,
  beginner,
  intermediate,
  advanced,
  expert,
}

enum AchievementCategory {
  milestone,
  streak,
  performance,
  time,
  special,
}

enum InsightType {
  positive,
  warning,
  suggestion,
  tip,
}

enum InsightPriority {
  low,
  medium,
  high,
}