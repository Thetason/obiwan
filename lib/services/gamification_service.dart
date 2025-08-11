import 'dart:math' as math;

/// 사용자 게임 프로필
class UserGameProfile {
  final String userId;
  final int level;                   // 현재 레벨 (1-100)
  final int experiencePoints;        // 현재 경험치
  final int totalXP;                 // 총 누적 경험치
  final int streakDays;              // 연속 연습 일수
  final int longestStreak;           // 최장 연속 기록
  final List<Badge> badges;          // 획득한 배지
  final List<Achievement> achievements; // 달성한 업적
  final Map<String, int> stats;      // 통계 (총 연습 시간, 녹음 횟수 등)
  final String title;                // 칭호 (초보자, 실력자, 마스터 등)
  final int coins;                   // 게임 재화
  
  UserGameProfile({
    required this.userId,
    required this.level,
    required this.experiencePoints,
    required this.totalXP,
    required this.streakDays,
    required this.longestStreak,
    required this.badges,
    required this.achievements,
    required this.stats,
    required this.title,
    required this.coins,
  });
  
  /// 다음 레벨까지 필요한 경험치
  int get xpToNextLevel {
    return _calculateXPRequired(level + 1) - totalXP;
  }
  
  /// 현재 레벨 진행률 (0.0 ~ 1.0)
  double get levelProgress {
    final currentLevelXP = _calculateXPRequired(level);
    final nextLevelXP = _calculateXPRequired(level + 1);
    final progress = (totalXP - currentLevelXP) / (nextLevelXP - currentLevelXP);
    return progress.clamp(0.0, 1.0);
  }
  
  static int _calculateXPRequired(int level) {
    // 레벨업에 필요한 경험치 공식 (점진적 증가)
    return (level * level * 50) + (level * 100);
  }
}

/// 배지 정보
class Badge {
  final String id;
  final String name;
  final String description;
  final String iconEmoji;
  final BadgeRarity rarity;
  final DateTime earnedAt;
  final Map<String, dynamic>? metadata;
  
  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconEmoji,
    required this.rarity,
    required this.earnedAt,
    this.metadata,
  });
}

/// 배지 희귀도
enum BadgeRarity {
  common,    // 일반 (회색)
  rare,      // 희귀 (파랑)
  epic,      // 에픽 (보라)
  legendary, // 전설 (금색)
}

/// 업적 정보
class Achievement {
  final String id;
  final String title;
  final String description;
  final int tier;           // 티어 (1-3: 동, 은, 금)
  final double progress;    // 진행률 (0.0 ~ 1.0)
  final int targetValue;    // 목표값
  final int currentValue;   // 현재값
  final int xpReward;       // 달성 시 경험치 보상
  final int coinReward;     // 달성 시 코인 보상
  final bool isCompleted;   // 완료 여부
  
  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.tier,
    required this.progress,
    required this.targetValue,
    required this.currentValue,
    required this.xpReward,
    required this.coinReward,
    required this.isCompleted,
  });
}

/// 리더보드 엔트리
class LeaderboardEntry {
  final String userId;
  final String username;
  final String avatarUrl;
  final int rank;
  final int score;
  final String title;
  final int level;
  final List<String> topBadges; // 대표 배지 3개
  
  LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.rank,
    required this.score,
    required this.title,
    required this.level,
    required this.topBadges,
  });
}

/// 챌린지 정보
class Challenge {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final DateTime startTime;
  final DateTime endTime;
  final Map<String, dynamic> requirements;
  final Map<String, int> rewards;
  final double progress;
  final bool isActive;
  
  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.requirements,
    required this.rewards,
    required this.progress,
    required this.isActive,
  });
  
  /// 남은 시간
  Duration get timeRemaining {
    return endTime.difference(DateTime.now());
  }
}

/// 챌린지 타입
enum ChallengeType {
  daily,    // 일일 챌린지
  weekly,   // 주간 챌린지
  monthly,  // 월간 챌린지
  seasonal, // 시즌 챌린지
  special,  // 특별 이벤트
}

/// 게이미피케이션 서비스
class GamificationService {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal() {
    _initializeBadgeDefinitions();
    _initializeAchievementDefinitions();
  }
  
  static GamificationService get instance => _instance;
  
  // 배지 정의
  final Map<String, Map<String, dynamic>> _badgeDefinitions = {};
  
  // 업적 정의
  final Map<String, Map<String, dynamic>> _achievementDefinitions = {};
  
  // 사용자 프로필 캐시
  final Map<String, UserGameProfile> _profileCache = {};
  
  /// 경험치 추가 및 레벨업 처리
  Future<Map<String, dynamic>> addExperience({
    required String userId,
    required int xpAmount,
    required String source,
  }) async {
    final profile = await getUserProfile(userId);
    
    final oldLevel = profile.level;
    final newTotalXP = profile.totalXP + xpAmount;
    final newLevel = _calculateLevelFromXP(newTotalXP);
    
    final leveledUp = newLevel > oldLevel;
    final rewards = <String, dynamic>{};
    
    if (leveledUp) {
      // 레벨업 보상
      rewards['coins'] = (newLevel - oldLevel) * 100;
      rewards['newBadges'] = _checkLevelBadges(newLevel);
      rewards['newTitle'] = _getTitleForLevel(newLevel);
    }
    
    // 프로필 업데이트
    final updatedProfile = UserGameProfile(
      userId: userId,
      level: newLevel,
      experiencePoints: newTotalXP - UserGameProfile._calculateXPRequired(newLevel),
      totalXP: newTotalXP,
      streakDays: profile.streakDays,
      longestStreak: profile.longestStreak,
      badges: [...profile.badges, ...?rewards['newBadges']],
      achievements: profile.achievements,
      stats: profile.stats,
      title: rewards['newTitle'] ?? profile.title,
      coins: profile.coins + (rewards['coins'] ?? 0),
    );
    
    _profileCache[userId] = updatedProfile;
    
    return {
      'leveledUp': leveledUp,
      'oldLevel': oldLevel,
      'newLevel': newLevel,
      'xpGained': xpAmount,
      'totalXP': newTotalXP,
      'rewards': rewards,
    };
  }
  
  /// 연습 세션 완료 처리
  Future<Map<String, dynamic>> completeSession({
    required String userId,
    required int duration,           // 분
    required double pitchAccuracy,
    required double rhythmAccuracy,
    required String songId,
  }) async {
    final rewards = <String, dynamic>{
      'xp': 0,
      'coins': 0,
      'badges': <Badge>[],
      'achievements': <Achievement>[],
    };
    
    // 기본 경험치 계산
    int baseXP = duration * 10; // 분당 10 XP
    
    // 정확도 보너스
    final accuracyBonus = ((pitchAccuracy + rhythmAccuracy) / 2 * 50).round();
    baseXP += accuracyBonus;
    
    // 경험치 추가
    final xpResult = await addExperience(
      userId: userId,
      xpAmount: baseXP,
      source: 'session_complete',
    );
    rewards['xp'] = baseXP;
    
    // 코인 보상
    final coins = (duration * 5 * (pitchAccuracy + rhythmAccuracy) / 2).round();
    rewards['coins'] = coins;
    
    // 연속 연습 체크
    await updateStreak(userId);
    
    // 배지 체크
    final newBadges = await checkBadges(
      userId: userId,
      context: {
        'sessionDuration': duration,
        'pitchAccuracy': pitchAccuracy,
        'rhythmAccuracy': rhythmAccuracy,
        'songId': songId,
      },
    );
    rewards['badges'] = newBadges;
    
    // 업적 업데이트
    final achievementProgress = await updateAchievements(
      userId: userId,
      updates: {
        'total_sessions': 1,
        'total_minutes': duration,
        'perfect_pitch_count': pitchAccuracy > 0.9 ? 1 : 0,
        'perfect_rhythm_count': rhythmAccuracy > 0.9 ? 1 : 0,
      },
    );
    rewards['achievements'] = achievementProgress['completed'];
    
    return {
      'rewards': rewards,
      'levelUp': xpResult['leveledUp'],
      'newLevel': xpResult['newLevel'],
    };
  }
  
  /// 연속 연습 업데이트
  Future<Map<String, dynamic>> updateStreak(String userId) async {
    final profile = await getUserProfile(userId);
    final lastPractice = DateTime.parse(profile.stats['lastPracticeDate'] ?? '2000-01-01');
    final now = DateTime.now();
    final daysSinceLastPractice = now.difference(lastPractice).inDays;
    
    int newStreakDays = profile.streakDays;
    int newLongestStreak = profile.longestStreak;
    final streakRewards = <String, dynamic>{};
    
    if (daysSinceLastPractice == 1) {
      // 연속 연습 지속
      newStreakDays++;
      newLongestStreak = math.max(newLongestStreak, newStreakDays);
      
      // 연속 보상
      if (newStreakDays % 7 == 0) {
        streakRewards['weeklyStreakBonus'] = 500; // 7일마다 500 코인
      }
      if (newStreakDays % 30 == 0) {
        streakRewards['monthlyStreakBonus'] = 2000; // 30일마다 2000 코인
      }
      
      // 연속 배지 체크
      final streakBadges = _checkStreakBadges(newStreakDays);
      if (streakBadges.isNotEmpty) {
        streakRewards['badges'] = streakBadges;
      }
    } else if (daysSinceLastPractice > 1) {
      // 연속 끊김
      newStreakDays = 1;
    }
    
    // 프로필 업데이트
    final updatedStats = Map<String, int>.from(profile.stats);
    updatedStats['lastPracticeDate'] = now.millisecondsSinceEpoch;
    
    final updatedProfile = UserGameProfile(
      userId: userId,
      level: profile.level,
      experiencePoints: profile.experiencePoints,
      totalXP: profile.totalXP,
      streakDays: newStreakDays,
      longestStreak: newLongestStreak,
      badges: profile.badges,
      achievements: profile.achievements,
      stats: updatedStats,
      title: profile.title,
      coins: profile.coins + (streakRewards['weeklyStreakBonus'] ?? 0) + (streakRewards['monthlyStreakBonus'] ?? 0),
    );
    
    _profileCache[userId] = updatedProfile;
    
    return {
      'streakDays': newStreakDays,
      'longestStreak': newLongestStreak,
      'rewards': streakRewards,
    };
  }
  
  /// 배지 체크
  Future<List<Badge>> checkBadges({
    required String userId,
    required Map<String, dynamic> context,
  }) async {
    final profile = await getUserProfile(userId);
    final newBadges = <Badge>[];
    
    _badgeDefinitions.forEach((badgeId, definition) {
      // 이미 획득한 배지는 스킵
      if (profile.badges.any((b) => b.id == badgeId)) {
        return;
      }
      
      // 조건 체크
      final condition = definition['condition'] as bool Function(UserGameProfile, Map<String, dynamic>);
      if (condition(profile, context)) {
        newBadges.add(Badge(
          id: badgeId,
          name: definition['name'],
          description: definition['description'],
          iconEmoji: definition['icon'],
          rarity: definition['rarity'],
          earnedAt: DateTime.now(),
          metadata: context,
        ));
      }
    });
    
    return newBadges;
  }
  
  /// 업적 업데이트
  Future<Map<String, dynamic>> updateAchievements({
    required String userId,
    required Map<String, int> updates,
  }) async {
    final profile = await getUserProfile(userId);
    final completedAchievements = <Achievement>[];
    final updatedAchievements = <Achievement>[];
    
    for (final achievement in profile.achievements) {
      if (achievement.isCompleted) {
        updatedAchievements.add(achievement);
        continue;
      }
      
      // 업적 정의 가져오기
      final definition = _achievementDefinitions[achievement.id];
      if (definition == null) continue;
      
      // 진행도 업데이트
      final updateKey = definition['updateKey'] as String;
      final increment = updates[updateKey] ?? 0;
      final newValue = achievement.currentValue + increment;
      final newProgress = (newValue / achievement.targetValue).clamp(0.0, 1.0);
      
      final updatedAchievement = Achievement(
        id: achievement.id,
        title: achievement.title,
        description: achievement.description,
        tier: achievement.tier,
        progress: newProgress,
        targetValue: achievement.targetValue,
        currentValue: newValue,
        xpReward: achievement.xpReward,
        coinReward: achievement.coinReward,
        isCompleted: newProgress >= 1.0,
      );
      
      updatedAchievements.add(updatedAchievement);
      
      if (updatedAchievement.isCompleted && !achievement.isCompleted) {
        completedAchievements.add(updatedAchievement);
      }
    }
    
    // 프로필 업데이트
    final updatedProfile = UserGameProfile(
      userId: userId,
      level: profile.level,
      experiencePoints: profile.experiencePoints,
      totalXP: profile.totalXP,
      streakDays: profile.streakDays,
      longestStreak: profile.longestStreak,
      badges: profile.badges,
      achievements: updatedAchievements,
      stats: profile.stats,
      title: profile.title,
      coins: profile.coins,
    );
    
    _profileCache[userId] = updatedProfile;
    
    // 완료된 업적에 대한 보상 처리
    for (final achievement in completedAchievements) {
      await addExperience(
        userId: userId,
        xpAmount: achievement.xpReward,
        source: 'achievement_${achievement.id}',
      );
    }
    
    return {
      'updated': updatedAchievements.length,
      'completed': completedAchievements,
    };
  }
  
  /// 리더보드 가져오기
  Future<List<LeaderboardEntry>> getLeaderboard({
    required String type, // 'weekly', 'monthly', 'alltime'
    int limit = 100,
  }) async {
    // 실제 구현에서는 서버에서 데이터를 가져옴
    // 여기서는 더미 데이터 반환
    return List.generate(limit, (index) {
      return LeaderboardEntry(
        userId: 'user_${index + 1}',
        username: 'Player ${index + 1}',
        avatarUrl: '',
        rank: index + 1,
        score: (10000 - index * 100),
        title: _getTitleForLevel(100 - index),
        level: 100 - index,
        topBadges: ['🏆', '⭐', '🎵'],
      );
    });
  }
  
  /// 활성 챌린지 가져오기
  Future<List<Challenge>> getActiveChallenges(String userId) async {
    final now = DateTime.now();
    
    return [
      Challenge(
        id: 'daily_practice',
        title: '일일 연습',
        description: '오늘 30분 이상 연습하기',
        type: ChallengeType.daily,
        startTime: DateTime(now.year, now.month, now.day),
        endTime: DateTime(now.year, now.month, now.day + 1),
        requirements: {'minutes': 30},
        rewards: {'xp': 100, 'coins': 50},
        progress: 0.5,
        isActive: true,
      ),
      Challenge(
        id: 'weekly_accuracy',
        title: '정확도 마스터',
        description: '이번 주 평균 정확도 80% 이상 달성',
        type: ChallengeType.weekly,
        startTime: now.subtract(Duration(days: now.weekday - 1)),
        endTime: now.add(Duration(days: 7 - now.weekday)),
        requirements: {'accuracy': 0.8},
        rewards: {'xp': 500, 'coins': 200},
        progress: 0.75,
        isActive: true,
      ),
    ];
  }
  
  /// 사용자 프로필 가져오기
  Future<UserGameProfile> getUserProfile(String userId) async {
    // 캐시 확인
    if (_profileCache.containsKey(userId)) {
      return _profileCache[userId]!;
    }
    
    // 새 프로필 생성 (실제로는 DB에서 로드)
    final newProfile = UserGameProfile(
      userId: userId,
      level: 1,
      experiencePoints: 0,
      totalXP: 0,
      streakDays: 0,
      longestStreak: 0,
      badges: [],
      achievements: _createInitialAchievements(),
      stats: {
        'totalSessions': 0,
        'totalMinutes': 0,
        'songsCompleted': 0,
        'perfectScores': 0,
      },
      title: '초보 보컬리스트',
      coins: 100, // 시작 보너스
    );
    
    _profileCache[userId] = newProfile;
    return newProfile;
  }
  
  // === Private Helper Methods ===
  
  void _initializeBadgeDefinitions() {
    // 연습 관련 배지
    _badgeDefinitions['first_session'] = {
      'name': '첫 발걸음',
      'description': '첫 연습 세션 완료',
      'icon': '🎤',
      'rarity': BadgeRarity.common,
      'condition': (UserGameProfile profile, Map<String, dynamic> context) {
        return profile.stats['totalSessions'] == 0;
      },
    };
    
    _badgeDefinitions['perfect_pitch'] = {
      'name': '완벽한 음정',
      'description': '음정 정확도 95% 이상 달성',
      'icon': '🎯',
      'rarity': BadgeRarity.rare,
      'condition': (UserGameProfile profile, Map<String, dynamic> context) {
        return (context['pitchAccuracy'] ?? 0) > 0.95;
      },
    };
    
    _badgeDefinitions['rhythm_master'] = {
      'name': '리듬 마스터',
      'description': '리듬 정확도 95% 이상 달성',
      'icon': '🥁',
      'rarity': BadgeRarity.rare,
      'condition': (UserGameProfile profile, Map<String, dynamic> context) {
        return (context['rhythmAccuracy'] ?? 0) > 0.95;
      },
    };
    
    _badgeDefinitions['marathon_singer'] = {
      'name': '마라톤 가수',
      'description': '한 세션 60분 이상 연습',
      'icon': '🏃',
      'rarity': BadgeRarity.epic,
      'condition': (UserGameProfile profile, Map<String, dynamic> context) {
        return (context['sessionDuration'] ?? 0) >= 60;
      },
    };
  }
  
  void _initializeAchievementDefinitions() {
    _achievementDefinitions['total_sessions_bronze'] = {
      'title': '연습의 시작',
      'description': '총 10회 연습 완료',
      'tier': 1,
      'targetValue': 10,
      'xpReward': 100,
      'coinReward': 50,
      'updateKey': 'total_sessions',
    };
    
    _achievementDefinitions['total_sessions_silver'] = {
      'title': '꾸준한 연습',
      'description': '총 50회 연습 완료',
      'tier': 2,
      'targetValue': 50,
      'xpReward': 500,
      'coinReward': 200,
      'updateKey': 'total_sessions',
    };
    
    _achievementDefinitions['total_sessions_gold'] = {
      'title': '연습의 달인',
      'description': '총 100회 연습 완료',
      'tier': 3,
      'targetValue': 100,
      'xpReward': 1000,
      'coinReward': 500,
      'updateKey': 'total_sessions',
    };
    
    _achievementDefinitions['total_minutes_bronze'] = {
      'title': '시간 투자',
      'description': '총 300분 연습',
      'tier': 1,
      'targetValue': 300,
      'xpReward': 150,
      'coinReward': 75,
      'updateKey': 'total_minutes',
    };
    
    _achievementDefinitions['perfect_pitch_bronze'] = {
      'title': '음정 마스터',
      'description': '완벽한 음정 10회 달성',
      'tier': 1,
      'targetValue': 10,
      'xpReward': 200,
      'coinReward': 100,
      'updateKey': 'perfect_pitch_count',
    };
  }
  
  List<Achievement> _createInitialAchievements() {
    final achievements = <Achievement>[];
    
    _achievementDefinitions.forEach((id, definition) {
      achievements.add(Achievement(
        id: id,
        title: definition['title'],
        description: definition['description'],
        tier: definition['tier'],
        progress: 0.0,
        targetValue: definition['targetValue'],
        currentValue: 0,
        xpReward: definition['xpReward'],
        coinReward: definition['coinReward'],
        isCompleted: false,
      ));
    });
    
    return achievements;
  }
  
  int _calculateLevelFromXP(int totalXP) {
    int level = 1;
    while (UserGameProfile._calculateXPRequired(level + 1) <= totalXP) {
      level++;
      if (level >= 100) break; // 최대 레벨 100
    }
    return level;
  }
  
  String _getTitleForLevel(int level) {
    if (level >= 80) return '보컬 마스터';
    if (level >= 60) return '프로 가수';
    if (level >= 40) return '실력파 보컬리스트';
    if (level >= 20) return '중급 보컬리스트';
    if (level >= 10) return '초급 보컬리스트';
    return '초보 보컬리스트';
  }
  
  List<Badge> _checkLevelBadges(int level) {
    final badges = <Badge>[];
    
    if (level == 10) {
      badges.add(Badge(
        id: 'level_10',
        name: '레벨 10 달성',
        description: '레벨 10에 도달했습니다',
        iconEmoji: '🎖️',
        rarity: BadgeRarity.common,
        earnedAt: DateTime.now(),
      ));
    } else if (level == 25) {
      badges.add(Badge(
        id: 'level_25',
        name: '레벨 25 달성',
        description: '레벨 25에 도달했습니다',
        iconEmoji: '🏅',
        rarity: BadgeRarity.rare,
        earnedAt: DateTime.now(),
      ));
    } else if (level == 50) {
      badges.add(Badge(
        id: 'level_50',
        name: '레벨 50 달성',
        description: '레벨 50에 도달했습니다',
        iconEmoji: '🥇',
        rarity: BadgeRarity.epic,
        earnedAt: DateTime.now(),
      ));
    } else if (level == 100) {
      badges.add(Badge(
        id: 'level_100',
        name: '최고 레벨',
        description: '최고 레벨에 도달했습니다',
        iconEmoji: '👑',
        rarity: BadgeRarity.legendary,
        earnedAt: DateTime.now(),
      ));
    }
    
    return badges;
  }
  
  List<Badge> _checkStreakBadges(int streakDays) {
    final badges = <Badge>[];
    
    if (streakDays == 7) {
      badges.add(Badge(
        id: 'streak_7',
        name: '일주일 연속',
        description: '7일 연속 연습',
        iconEmoji: '🔥',
        rarity: BadgeRarity.common,
        earnedAt: DateTime.now(),
      ));
    } else if (streakDays == 30) {
      badges.add(Badge(
        id: 'streak_30',
        name: '한 달 연속',
        description: '30일 연속 연습',
        iconEmoji: '🌟',
        rarity: BadgeRarity.rare,
        earnedAt: DateTime.now(),
      ));
    } else if (streakDays == 100) {
      badges.add(Badge(
        id: 'streak_100',
        name: '100일 연속',
        description: '100일 연속 연습',
        iconEmoji: '💎',
        rarity: BadgeRarity.epic,
        earnedAt: DateTime.now(),
      ));
    } else if (streakDays == 365) {
      badges.add(Badge(
        id: 'streak_365',
        name: '1년 연속',
        description: '365일 연속 연습',
        iconEmoji: '🏆',
        rarity: BadgeRarity.legendary,
        earnedAt: DateTime.now(),
      ));
    }
    
    return badges;
  }
}