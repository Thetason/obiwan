import 'dart:math' as math;
import 'timbre_analysis_service.dart';
import 'rhythm_analysis_service.dart';

/// 사용자 보컬 프로필
class VocalProfile {
  final String userId;
  final double pitchRange;          // 음역대 (옥타브)
  final double averagePitchAccuracy; // 평균 음정 정확도
  final double rhythmAccuracy;       // 리듬 정확도
  final String voiceType;            // 음색 타입
  final List<String> strengths;      // 강점
  final List<String> weaknesses;     // 개선점
  final int practiceLevel;           // 연습 레벨 (1-10)
  final Map<String, double> skillScores; // 세부 기술 점수
  
  VocalProfile({
    required this.userId,
    required this.pitchRange,
    required this.averagePitchAccuracy,
    required this.rhythmAccuracy,
    required this.voiceType,
    required this.strengths,
    required this.weaknesses,
    required this.practiceLevel,
    required this.skillScores,
  });
}

/// 연습 추천 항목
class PracticeRecommendation {
  final String id;
  final String title;
  final String description;
  final String category;           // 음정, 리듬, 호흡, 발성 등
  final int difficulty;            // 난이도 (1-5)
  final int estimatedMinutes;      // 예상 소요 시간
  final List<String> focusAreas;   // 집중 영역
  final String technique;          // 연습 기법
  final Map<String, dynamic> parameters; // 연습 파라미터
  final double priority;           // 우선순위 (0.0-1.0)
  
  PracticeRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.focusAreas,
    required this.technique,
    required this.parameters,
    required this.priority,
  });
}

/// 개인 맞춤형 연습 추천 AI
class PracticeRecommendationAI {
  static final PracticeRecommendationAI _instance = PracticeRecommendationAI._internal();
  factory PracticeRecommendationAI() => _instance;
  PracticeRecommendationAI._internal();
  
  static PracticeRecommendationAI get instance => _instance;
  
  // 연습 데이터베이스
  final List<PracticeRecommendation> _practiceDatabase = [];
  
  // 사용자 진행 상황 추적
  final Map<String, List<Map<String, dynamic>>> _userProgress = {};
  
  /// 사용자 프로필 생성/업데이트
  VocalProfile analyzeUserProfile({
    required String userId,
    required List<Map<String, dynamic>> recentSessions,
  }) {
    // 최근 세션에서 데이터 추출
    double totalPitchAccuracy = 0.0;
    double totalRhythmAccuracy = 0.0;
    double minPitch = double.infinity;
    double maxPitch = 0.0;
    Map<String, int> voiceTypes = {};
    
    for (final session in recentSessions) {
      totalPitchAccuracy += (session['pitchAccuracy'] ?? 0.0) as double;
      totalRhythmAccuracy += (session['rhythmAccuracy'] ?? 0.0) as double;
      
      final pitchData = session['pitchData'] as List<double>?;
      if (pitchData != null && pitchData.isNotEmpty) {
        minPitch = math.min(minPitch, pitchData.reduce(math.min));
        maxPitch = math.max(maxPitch, pitchData.reduce(math.max));
      }
      
      final voiceType = session['voiceType'] as String?;
      if (voiceType != null) {
        voiceTypes[voiceType] = (voiceTypes[voiceType] ?? 0) + 1;
      }
    }
    
    // 평균 계산
    final avgPitchAccuracy = recentSessions.isNotEmpty 
        ? totalPitchAccuracy / recentSessions.length 
        : 0.5;
    final avgRhythmAccuracy = recentSessions.isNotEmpty 
        ? totalRhythmAccuracy / recentSessions.length 
        : 0.5;
    
    // 음역대 계산 (옥타브)
    final pitchRange = minPitch > 0 && maxPitch > minPitch 
        ? math.log(maxPitch / minPitch) / math.log(2) 
        : 1.5;
    
    // 가장 빈번한 음색 타입
    String dominantVoiceType = '균형잡힌 음색';
    int maxCount = 0;
    voiceTypes.forEach((type, count) {
      if (count > maxCount) {
        maxCount = count;
        dominantVoiceType = type;
      }
    });
    
    // 강점과 약점 분석
    final strengths = <String>[];
    final weaknesses = <String>[];
    
    if (avgPitchAccuracy > 0.8) {
      strengths.add('음정 정확도');
    } else if (avgPitchAccuracy < 0.6) {
      weaknesses.add('음정 정확도');
    }
    
    if (avgRhythmAccuracy > 0.8) {
      strengths.add('리듬감');
    } else if (avgRhythmAccuracy < 0.6) {
      weaknesses.add('리듬감');
    }
    
    if (pitchRange > 2.0) {
      strengths.add('넓은 음역대');
    } else if (pitchRange < 1.0) {
      weaknesses.add('음역대 확장');
    }
    
    // 연습 레벨 계산 (1-10)
    final practiceLevel = _calculatePracticeLevel(
      pitchAccuracy: avgPitchAccuracy,
      rhythmAccuracy: avgRhythmAccuracy,
      pitchRange: pitchRange,
    );
    
    // 세부 기술 점수
    final skillScores = {
      'pitch': avgPitchAccuracy,
      'rhythm': avgRhythmAccuracy,
      'range': pitchRange / 3.0, // 3옥타브를 기준으로 정규화
      'stability': _calculateStability(recentSessions),
      'expression': _calculateExpression(recentSessions),
    };
    
    return VocalProfile(
      userId: userId,
      pitchRange: pitchRange,
      averagePitchAccuracy: avgPitchAccuracy,
      rhythmAccuracy: avgRhythmAccuracy,
      voiceType: dominantVoiceType,
      strengths: strengths,
      weaknesses: weaknesses,
      practiceLevel: practiceLevel,
      skillScores: skillScores,
    );
  }
  
  /// 개인 맞춤 연습 추천
  List<PracticeRecommendation> recommendPractices({
    required VocalProfile profile,
    int maxRecommendations = 5,
    String? focusArea,
  }) {
    _initializePracticeDatabase();
    
    final recommendations = <PracticeRecommendation>[];
    
    // 1. 약점 개선 연습 (높은 우선순위)
    for (final weakness in profile.weaknesses) {
      final practices = _findPracticesForWeakness(weakness, profile.practiceLevel);
      recommendations.addAll(practices);
    }
    
    // 2. 강점 강화 연습 (중간 우선순위)
    for (final strength in profile.strengths) {
      final practices = _findPracticesForStrength(strength, profile.practiceLevel);
      recommendations.addAll(practices);
    }
    
    // 3. 종합적인 실력 향상 연습
    final generalPractices = _findGeneralPractices(profile);
    recommendations.addAll(generalPractices);
    
    // 4. 특정 영역 집중 (요청된 경우)
    if (focusArea != null) {
      final focusedPractices = _findFocusedPractices(focusArea, profile.practiceLevel);
      recommendations.insertAll(0, focusedPractices);
    }
    
    // 우선순위로 정렬하고 상위 N개 반환
    recommendations.sort((a, b) => b.priority.compareTo(a.priority));
    return recommendations.take(maxRecommendations).toList();
  }
  
  /// 연습 효과 예측
  Map<String, double> predictImprovements({
    required VocalProfile profile,
    required List<PracticeRecommendation> practices,
    int daysOfPractice = 30,
  }) {
    final improvements = <String, double>{};
    
    for (final practice in practices) {
      // 각 연습의 예상 개선 효과 계산
      double improvementRate = 0.0;
      
      switch (practice.category) {
        case '음정':
          improvementRate = _calculatePitchImprovement(
            currentAccuracy: profile.averagePitchAccuracy,
            practiceIntensity: practice.difficulty / 5.0,
            days: daysOfPractice,
          );
          improvements['pitchAccuracy'] = 
              (improvements['pitchAccuracy'] ?? 0) + improvementRate;
          break;
          
        case '리듬':
          improvementRate = _calculateRhythmImprovement(
            currentAccuracy: profile.rhythmAccuracy,
            practiceIntensity: practice.difficulty / 5.0,
            days: daysOfPractice,
          );
          improvements['rhythmAccuracy'] = 
              (improvements['rhythmAccuracy'] ?? 0) + improvementRate;
          break;
          
        case '음역대':
          improvementRate = _calculateRangeImprovement(
            currentRange: profile.pitchRange,
            practiceIntensity: practice.difficulty / 5.0,
            days: daysOfPractice,
          );
          improvements['pitchRange'] = 
              (improvements['pitchRange'] ?? 0) + improvementRate;
          break;
      }
    }
    
    // 예상 레벨 상승
    final currentTotal = profile.skillScores.values.reduce((a, b) => a + b);
    final improvementTotal = improvements.values.reduce((a, b) => a + b);
    improvements['overallLevel'] = improvementTotal / currentTotal;
    
    return improvements;
  }
  
  /// 적응형 난이도 조정
  PracticeRecommendation adjustDifficulty({
    required PracticeRecommendation practice,
    required double performanceScore,
    required VocalProfile profile,
  }) {
    int newDifficulty = practice.difficulty;
    
    // 성과에 따른 난이도 조정
    if (performanceScore > 0.85 && practice.difficulty < 5) {
      newDifficulty = math.min(5, practice.difficulty + 1);
    } else if (performanceScore < 0.60 && practice.difficulty > 1) {
      newDifficulty = math.max(1, practice.difficulty - 1);
    }
    
    // 파라미터 조정
    final adjustedParams = Map<String, dynamic>.from(practice.parameters);
    
    if (practice.category == '음정') {
      // 음정 범위 조정
      final currentRange = adjustedParams['pitchRange'] ?? 1.0;
      adjustedParams['pitchRange'] = currentRange * (newDifficulty / practice.difficulty);
    } else if (practice.category == '리듬') {
      // BPM 조정
      final currentBPM = adjustedParams['bpm'] ?? 120;
      adjustedParams['bpm'] = (currentBPM * (newDifficulty / practice.difficulty)).round();
    }
    
    return PracticeRecommendation(
      id: practice.id,
      title: practice.title,
      description: '${practice.description} (난이도 조정됨)',
      category: practice.category,
      difficulty: newDifficulty,
      estimatedMinutes: practice.estimatedMinutes,
      focusAreas: practice.focusAreas,
      technique: practice.technique,
      parameters: adjustedParams,
      priority: practice.priority,
    );
  }
  
  /// 진행 상황 추적 및 분석
  Map<String, dynamic> analyzeProgress({
    required String userId,
    required List<Map<String, dynamic>> sessionHistory,
    int timeWindowDays = 30,
  }) {
    // 시간 창 내의 세션 필터링
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(days: timeWindowDays));
    
    final recentSessions = sessionHistory.where((session) {
      final sessionDate = DateTime.parse(session['date'] as String);
      return sessionDate.isAfter(windowStart);
    }).toList();
    
    if (recentSessions.isEmpty) {
      return {'status': 'no_data', 'message': '최근 연습 데이터가 없습니다.'};
    }
    
    // 진행 상황 메트릭 계산
    final metrics = {
      'totalSessions': recentSessions.length,
      'totalMinutes': _calculateTotalMinutes(recentSessions),
      'averageSessionLength': _calculateAverageSessionLength(recentSessions),
      'consistencyScore': _calculateConsistency(recentSessions),
      'improvementTrend': _calculateImprovementTrend(recentSessions),
      'strongestSkill': _identifyStrongestSkill(recentSessions),
      'weakestSkill': _identifyWeakestSkill(recentSessions),
      'recommendedFocus': _recommendFocusArea(recentSessions),
    };
    
    // 성취 배지 확인
    final achievements = _checkAchievements(metrics, sessionHistory);
    metrics['achievements'] = achievements;
    
    return metrics;
  }
  
  // === Private Helper Methods ===
  
  void _initializePracticeDatabase() {
    if (_practiceDatabase.isNotEmpty) return;
    
    // 음정 연습
    _practiceDatabase.addAll([
      PracticeRecommendation(
        id: 'pitch_scales',
        title: '음계 연습',
        description: '도레미파솔라시도 기본 음계를 정확하게 부르기',
        category: '음정',
        difficulty: 1,
        estimatedMinutes: 10,
        focusAreas: ['음정 정확도', '음감'],
        technique: 'ascending_descending',
        parameters: {'scale': 'major', 'startNote': 'C4', 'tempo': 60},
        priority: 0.8,
      ),
      PracticeRecommendation(
        id: 'pitch_intervals',
        title: '음정 간격 연습',
        description: '3도, 5도, 옥타브 등 음정 간격 정확하게 부르기',
        category: '음정',
        difficulty: 2,
        estimatedMinutes: 15,
        focusAreas: ['음정 정확도', '음정 간격'],
        technique: 'interval_training',
        parameters: {'intervals': [3, 5, 8], 'tempo': 80},
        priority: 0.7,
      ),
    ]);
    
    // 리듬 연습
    _practiceDatabase.addAll([
      PracticeRecommendation(
        id: 'rhythm_basic',
        title: '기본 리듬 패턴',
        description: '4/4 박자 기본 리듬 패턴 연습',
        category: '리듬',
        difficulty: 1,
        estimatedMinutes: 10,
        focusAreas: ['리듬감', '박자'],
        technique: 'metronome_sync',
        parameters: {'timeSignature': '4/4', 'bpm': 100},
        priority: 0.7,
      ),
      PracticeRecommendation(
        id: 'rhythm_syncopation',
        title: '싱코페이션 연습',
        description: '엇박자와 싱코페이션 리듬 마스터하기',
        category: '리듬',
        difficulty: 3,
        estimatedMinutes: 20,
        focusAreas: ['리듬감', '싱코페이션'],
        technique: 'off_beat',
        parameters: {'complexity': 'medium', 'bpm': 110},
        priority: 0.6,
      ),
    ]);
    
    // 호흡 연습
    _practiceDatabase.addAll([
      PracticeRecommendation(
        id: 'breath_support',
        title: '복식 호흡',
        description: '안정적인 발성을 위한 복식 호흡 연습',
        category: '호흡',
        difficulty: 1,
        estimatedMinutes: 10,
        focusAreas: ['호흡', '지지력'],
        technique: 'diaphragm_breathing',
        parameters: {'holdTime': 4, 'releaseTime': 8},
        priority: 0.9,
      ),
      PracticeRecommendation(
        id: 'breath_control',
        title: '호흡 조절',
        description: '긴 프레이즈를 위한 호흡 조절 연습',
        category: '호흡',
        difficulty: 2,
        estimatedMinutes: 15,
        focusAreas: ['호흡', '지구력'],
        technique: 'sustained_notes',
        parameters: {'sustainTime': 10, 'dynamicControl': true},
        priority: 0.8,
      ),
    ]);
    
    // 음역대 확장
    _practiceDatabase.addAll([
      PracticeRecommendation(
        id: 'range_extension_high',
        title: '고음 확장',
        description: '안전하게 고음역대 확장하기',
        category: '음역대',
        difficulty: 3,
        estimatedMinutes: 20,
        focusAreas: ['음역대', '고음'],
        technique: 'gradual_ascent',
        parameters: {'startNote': 'C4', 'targetNote': 'C5', 'steps': 8},
        priority: 0.6,
      ),
      PracticeRecommendation(
        id: 'range_extension_low',
        title: '저음 확장',
        description: '풍부한 저음 개발하기',
        category: '음역대',
        difficulty: 2,
        estimatedMinutes: 15,
        focusAreas: ['음역대', '저음'],
        technique: 'gradual_descent',
        parameters: {'startNote': 'C4', 'targetNote': 'C3', 'steps': 8},
        priority: 0.5,
      ),
    ]);
  }
  
  int _calculatePracticeLevel({
    required double pitchAccuracy,
    required double rhythmAccuracy,
    required double pitchRange,
  }) {
    final score = (pitchAccuracy * 0.4 + 
                  rhythmAccuracy * 0.3 + 
                  (pitchRange / 3.0) * 0.3) * 10;
    return score.round().clamp(1, 10);
  }
  
  double _calculateStability(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return 0.5;
    
    final accuracies = sessions
        .map((s) => (s['pitchAccuracy'] ?? 0.0) as double)
        .toList();
    
    if (accuracies.length < 2) return accuracies.first;
    
    // 변동계수 계산
    final mean = accuracies.reduce((a, b) => a + b) / accuracies.length;
    double variance = 0;
    for (final acc in accuracies) {
      variance += math.pow(acc - mean, 2);
    }
    final stdDev = math.sqrt(variance / accuracies.length);
    final cv = stdDev / mean;
    
    return math.max(0, 1 - cv).clamp(0.0, 1.0);
  }
  
  double _calculateExpression(List<Map<String, dynamic>> sessions) {
    // 다이나믹 레인지와 음색 변화를 기반으로 표현력 계산
    double totalExpression = 0.0;
    int count = 0;
    
    for (final session in sessions) {
      final dynamics = session['dynamicRange'] as double?;
      final timbreVariety = session['timbreVariety'] as double?;
      
      if (dynamics != null && timbreVariety != null) {
        totalExpression += (dynamics + timbreVariety) / 2;
        count++;
      }
    }
    
    return count > 0 ? totalExpression / count : 0.5;
  }
  
  List<PracticeRecommendation> _findPracticesForWeakness(
    String weakness,
    int level,
  ) {
    return _practiceDatabase.where((practice) {
      final matchesWeakness = practice.focusAreas.any((area) =>
          area.toLowerCase().contains(weakness.toLowerCase()));
      final appropriateLevel = (practice.difficulty - level).abs() <= 1;
      return matchesWeakness && appropriateLevel;
    }).map((practice) {
      // 약점 개선은 높은 우선순위
      return PracticeRecommendation(
        id: practice.id,
        title: practice.title,
        description: practice.description,
        category: practice.category,
        difficulty: practice.difficulty,
        estimatedMinutes: practice.estimatedMinutes,
        focusAreas: practice.focusAreas,
        technique: practice.technique,
        parameters: practice.parameters,
        priority: math.min(1.0, practice.priority * 1.3),
      );
    }).toList();
  }
  
  List<PracticeRecommendation> _findPracticesForStrength(
    String strength,
    int level,
  ) {
    return _practiceDatabase.where((practice) {
      final matchesStrength = practice.focusAreas.any((area) =>
          area.toLowerCase().contains(strength.toLowerCase()));
      // 강점은 약간 높은 난이도 추천
      final appropriateLevel = practice.difficulty >= level && 
                               practice.difficulty <= level + 2;
      return matchesStrength && appropriateLevel;
    }).toList();
  }
  
  List<PracticeRecommendation> _findGeneralPractices(VocalProfile profile) {
    return _practiceDatabase.where((practice) {
      final appropriateLevel = (practice.difficulty - profile.practiceLevel).abs() <= 1;
      return appropriateLevel;
    }).take(3).toList();
  }
  
  List<PracticeRecommendation> _findFocusedPractices(
    String focusArea,
    int level,
  ) {
    return _practiceDatabase.where((practice) {
      final matchesFocus = practice.category.toLowerCase() == focusArea.toLowerCase() ||
                          practice.focusAreas.any((area) =>
                              area.toLowerCase().contains(focusArea.toLowerCase()));
      final appropriateLevel = (practice.difficulty - level).abs() <= 2;
      return matchesFocus && appropriateLevel;
    }).map((practice) {
      // 집중 영역은 최고 우선순위
      return PracticeRecommendation(
        id: practice.id,
        title: practice.title,
        description: practice.description,
        category: practice.category,
        difficulty: practice.difficulty,
        estimatedMinutes: practice.estimatedMinutes,
        focusAreas: practice.focusAreas,
        technique: practice.technique,
        parameters: practice.parameters,
        priority: 1.0,
      );
    }).toList();
  }
  
  double _calculatePitchImprovement({
    required double currentAccuracy,
    required double practiceIntensity,
    required int days,
  }) {
    // 로그 곡선 기반 개선 모델
    final baseImprovement = math.log(days + 1) / 10;
    final intensityMultiplier = practiceIntensity;
    final diminishingReturns = 1 - currentAccuracy; // 이미 높으면 개선 폭 감소
    
    return baseImprovement * intensityMultiplier * diminishingReturns;
  }
  
  double _calculateRhythmImprovement({
    required double currentAccuracy,
    required double practiceIntensity,
    required int days,
  }) {
    // 리듬은 음정보다 빠르게 개선되는 경향
    final baseImprovement = math.log(days + 1) / 8;
    final intensityMultiplier = practiceIntensity * 1.2;
    final diminishingReturns = 1 - currentAccuracy;
    
    return baseImprovement * intensityMultiplier * diminishingReturns;
  }
  
  double _calculateRangeImprovement({
    required double currentRange,
    required double practiceIntensity,
    required int days,
  }) {
    // 음역대는 천천히 확장됨
    final baseImprovement = math.log(days + 1) / 20;
    final intensityMultiplier = practiceIntensity * 0.8;
    final maxRange = 3.0; // 최대 3옥타브
    final remainingPotential = (maxRange - currentRange) / maxRange;
    
    return baseImprovement * intensityMultiplier * remainingPotential;
  }
  
  int _calculateTotalMinutes(List<Map<String, dynamic>> sessions) {
    return sessions.fold(0, (total, session) {
      return total + ((session['duration'] ?? 0) as int);
    });
  }
  
  double _calculateAverageSessionLength(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return 0;
    final total = _calculateTotalMinutes(sessions);
    return total / sessions.length;
  }
  
  double _calculateConsistency(List<Map<String, dynamic>> sessions) {
    if (sessions.length < 2) return 0;
    
    // 세션 간 날짜 간격 계산
    final dates = sessions
        .map((s) => DateTime.parse(s['date'] as String))
        .toList()
      ..sort();
    
    final intervals = <int>[];
    for (int i = 1; i < dates.length; i++) {
      intervals.add(dates[i].difference(dates[i - 1]).inDays);
    }
    
    // 이상적인 간격은 1-2일
    final consistentIntervals = intervals.where((i) => i >= 1 && i <= 3).length;
    return consistentIntervals / intervals.length;
  }
  
  Map<String, double> _calculateImprovementTrend(List<Map<String, dynamic>> sessions) {
    if (sessions.length < 3) {
      return {'trend': 0, 'confidence': 0};
    }
    
    // 시간순 정렬
    final sorted = List<Map<String, dynamic>>.from(sessions)
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    
    // 전반부와 후반부 평균 비교
    final midPoint = sorted.length ~/ 2;
    final firstHalf = sorted.take(midPoint).toList();
    final secondHalf = sorted.skip(midPoint).toList();
    
    double firstAvg = 0, secondAvg = 0;
    
    for (final session in firstHalf) {
      firstAvg += (session['pitchAccuracy'] ?? 0.0) as double;
    }
    firstAvg /= firstHalf.length;
    
    for (final session in secondHalf) {
      secondAvg += (session['pitchAccuracy'] ?? 0.0) as double;
    }
    secondAvg /= secondHalf.length;
    
    final trend = secondAvg - firstAvg;
    final confidence = math.min(1.0, sessions.length / 10.0);
    
    return {'trend': trend, 'confidence': confidence};
  }
  
  String _identifyStrongestSkill(List<Map<String, dynamic>> sessions) {
    final skills = <String, double>{
      'pitch': 0,
      'rhythm': 0,
      'breath': 0,
      'expression': 0,
    };
    
    for (final session in sessions) {
      skills['pitch'] = skills['pitch']! + ((session['pitchAccuracy'] ?? 0) as double);
      skills['rhythm'] = skills['rhythm']! + ((session['rhythmAccuracy'] ?? 0) as double);
      skills['breath'] = skills['breath']! + ((session['breathControl'] ?? 0) as double);
      skills['expression'] = skills['expression']! + ((session['expression'] ?? 0) as double);
    }
    
    String strongest = 'pitch';
    double maxScore = 0;
    
    skills.forEach((skill, total) {
      final avg = total / sessions.length;
      if (avg > maxScore) {
        maxScore = avg;
        strongest = skill;
      }
    });
    
    return strongest;
  }
  
  String _identifyWeakestSkill(List<Map<String, dynamic>> sessions) {
    final skills = <String, double>{
      'pitch': 0,
      'rhythm': 0,
      'breath': 0,
      'expression': 0,
    };
    
    for (final session in sessions) {
      skills['pitch'] = skills['pitch']! + ((session['pitchAccuracy'] ?? 0) as double);
      skills['rhythm'] = skills['rhythm']! + ((session['rhythmAccuracy'] ?? 0) as double);
      skills['breath'] = skills['breath']! + ((session['breathControl'] ?? 0) as double);
      skills['expression'] = skills['expression']! + ((session['expression'] ?? 0) as double);
    }
    
    String weakest = 'pitch';
    double minScore = double.infinity;
    
    skills.forEach((skill, total) {
      final avg = total / sessions.length;
      if (avg < minScore) {
        minScore = avg;
        weakest = skill;
      }
    });
    
    return weakest;
  }
  
  String _recommendFocusArea(List<Map<String, dynamic>> sessions) {
    final weakest = _identifyWeakestSkill(sessions);
    final trend = _calculateImprovementTrend(sessions);
    
    // 개선이 정체된 약점에 집중
    if (trend['trend']! < 0.05) {
      return weakest;
    }
    
    // 빠르게 개선 중이면 다음 약점으로
    final skills = ['pitch', 'rhythm', 'breath', 'expression'];
    skills.remove(weakest);
    
    return skills.first; // 간단히 다음 스킬 추천
  }
  
  List<Map<String, dynamic>> _checkAchievements(
    Map<String, dynamic> metrics,
    List<Map<String, dynamic>> allSessions,
  ) {
    final achievements = <Map<String, dynamic>>[];
    
    // 연속 연습 배지
    if ((metrics['consistencyScore'] as double) > 0.8) {
      achievements.add({
        'id': 'consistent_practice',
        'title': '꾸준한 연습가',
        'description': '일정한 간격으로 연습을 지속했습니다',
        'icon': '🏃',
      });
    }
    
    // 총 연습 시간 배지
    final totalMinutes = metrics['totalMinutes'] as int;
    if (totalMinutes > 600) {
      achievements.add({
        'id': 'practice_hours',
        'title': '10시간 달성',
        'description': '총 10시간 이상 연습했습니다',
        'icon': '⏰',
      });
    }
    
    // 개선 배지
    final trend = metrics['improvementTrend'] as Map<String, double>;
    if (trend['trend']! > 0.1) {
      achievements.add({
        'id': 'improving',
        'title': '실력 향상 중',
        'description': '꾸준히 실력이 향상되고 있습니다',
        'icon': '📈',
      });
    }
    
    return achievements;
  }
}