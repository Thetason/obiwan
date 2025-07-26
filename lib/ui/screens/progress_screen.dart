import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard/modern_dashboard_card.dart';
import '../widgets/common/progress_indicators.dart';

/// Progress tracking screen with detailed analytics
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  int _selectedTimeRange = 0; // 0: 일주일, 1: 한달, 2: 3개월
  
  final List<String> _timeRanges = ['일주일', '한달', '3개월'];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App bar with time range selector
            SliverAppBar(
              expandedHeight: 120,
              floating: true,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  bottom: AppSpacing.md,
                ),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '진행률 분석 📊',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '성장하는 모습을 확인해보세요',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                PopupMenuButton<int>(
                  initialValue: _selectedTimeRange,
                  onSelected: (value) {
                    setState(() => _selectedTimeRange = value);
                  },
                  itemBuilder: (context) => _timeRanges
                      .asMap()
                      .entries
                      .map((entry) => PopupMenuItem<int>(
                            value: entry.key,
                            child: Text(entry.value),
                          ))
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    margin: const EdgeInsets.only(right: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _timeRanges[_selectedTimeRange],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Main content
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Overall progress summary
                  _buildOverallProgressSection(theme),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Skill breakdown
                  _buildSkillBreakdownSection(theme),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Achievement and milestones
                  _buildAchievementsSection(theme),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Practice history
                  _buildPracticeHistorySection(theme),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Recommendations
                  _buildRecommendationsSection(theme),
                  
                  // Bottom padding for FAB
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallProgressSection(ThemeData theme) {
    return ModernDashboardCard(
      title: '전체 진행 상황',
      subtitle: '현재까지의 학습 성과를 한눈에 확인하세요',
      icon: Icons.trending_up,
      accentColor: theme.colorScheme.primary,
      content: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ScoreProgressIndicator(
                  score: 0.73,
                  size: 120,
                  strokeWidth: 12,
                  showScore: true,
                  label: '종합 점수',
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildProgressStat(
                      '연습 시간',
                      '47.5시간',
                      Icons.schedule,
                      AppTheme.customColors.progressGood,
                      '+5.2시간',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildProgressStat(
                      '완료 레슨',
                      '23개',
                      Icons.check_circle,
                      AppTheme.customColors.progressExcellent,
                      '+3개',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildProgressStat(
                      '연속 학습',
                      '12일',
                      Icons.local_fire_department,
                      AppTheme.customColors.error,
                      '신기록!',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.colorScheme.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.insights,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '이번 주 성과',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '지난주 대비 15% 향상된 결과를 보여주고 있어요!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillBreakdownSection(ThemeData theme) {
    final skills = [
      SkillProgress(
        name: '호흡',
        current: 0.85,
        previous: 0.78,
        color: AppTheme.customColors.breathingInhale,
        icon: Icons.air,
      ),
      SkillProgress(
        name: '음정',
        current: 0.72,
        previous: 0.65,
        color: AppTheme.customColors.voiceSoprano,
        icon: Icons.music_note,
      ),
      SkillProgress(
        name: '발음',
        current: 0.68,
        previous: 0.70,
        color: AppTheme.customColors.voiceAlto,
        icon: Icons.record_voice_over,
      ),
      SkillProgress(
        name: '음색',
        current: 0.45,
        previous: 0.38,
        color: AppTheme.customColors.voiceTenor,
        icon: Icons.graphic_eq,
      ),
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '영역별 실력 분석',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...skills.map((skill) => _buildSkillCard(theme, skill)),
      ],
    );
  }

  Widget _buildSkillCard(ThemeData theme, SkillProgress skill) {
    final improvement = skill.current - skill.previous;
    final isImproved = improvement > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ModernDashboardCard(
        title: skill.name,
        subtitle: '현재 레벨: ${_getSkillLevel(skill.current)}',
        icon: skill.icon,
        accentColor: skill.color,
        content: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: AnimatedLinearProgress(
                    progress: skill.current,
                    label: '실력 수준',
                    showPercentage: true,
                    progressColor: skill.color,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isImproved ? Icons.trending_up : Icons.trending_down,
                          color: isImproved 
                              ? AppTheme.customColors.success
                              : AppTheme.customColors.error,
                          size: 16,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${isImproved ? '+' : ''}${(improvement * 100).toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isImproved 
                                ? AppTheme.customColors.success
                                : AppTheme.customColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '변화량',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: skill.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: skill.color,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _getSkillRecommendation(skill.name, skill.current),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: skill.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsSection(ThemeData theme) {
    final achievements = [
      Achievement(
        title: '첫 완주',
        description: '첫 번째 레슨을 완료했습니다',
        icon: Icons.flag,
        color: AppTheme.customColors.success,
        isEarned: true,
        earnedDate: '2024.01.15',
      ),
      Achievement(
        title: '연습 마니아',
        description: '7일 연속으로 연습했습니다',
        icon: Icons.local_fire_department,
        color: AppTheme.customColors.error,
        isEarned: true,
        earnedDate: '2024.01.22',
      ),
      Achievement(
        title: '음정 마스터',
        description: '음정 정확도 90% 달성',
        icon: Icons.music_note,
        color: AppTheme.customColors.voiceSoprano,
        isEarned: false,
        progress: 0.85,
      ),
      Achievement(
        title: '호흡 전문가',
        description: '호흡 레벨 5 달성',
        icon: Icons.air,
        color: AppTheme.customColors.breathingInhale,
        isEarned: false,
        progress: 0.6,
      ),
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '업적 및 마일스톤',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // Show all achievements
              },
              child: const Text('전체 보기'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.1,
          children: achievements.map((achievement) => 
            _buildAchievementCard(theme, achievement)).toList(),
        ),
      ],
    );
  }

  Widget _buildAchievementCard(ThemeData theme, Achievement achievement) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: achievement.isEarned 
              ? achievement.color.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.2),
          width: achievement.isEarned ? 2 : 1,
        ),
        boxShadow: achievement.isEarned
            ? [
                BoxShadow(
                  color: achievement.color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // Achievement icon
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: achievement.isEarned
                    ? achievement.color.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                achievement.icon,
                size: 32,
                color: achievement.isEarned
                    ? achievement.color
                    : Colors.grey,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            
            // Achievement info
            Text(
              achievement.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: achievement.isEarned
                    ? theme.colorScheme.onSurface
                    : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              achievement.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: achievement.isEarned
                    ? theme.colorScheme.onSurface.withOpacity(0.7)
                    : Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            
            // Status
            if (achievement.isEarned)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: achievement.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  achievement.earnedDate!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: achievement.color,
                    fontSize: 10,
                  ),
                ),
              )
            else if (achievement.progress != null)
              AnimatedLinearProgress(
                progress: achievement.progress!,
                height: 4,
                progressColor: achievement.color,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPracticeHistorySection(ThemeData theme) {
    return ModernDashboardCard(
      title: '연습 기록',
      subtitle: '최근 활동 내역을 확인하세요',
      icon: Icons.history,
      accentColor: theme.colorScheme.secondary,
      content: Column(
        children: [
          // Chart placeholder
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: const Center(
              child: Text('연습 시간 차트 영역'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Recent sessions
          Column(
            children: [
              _buildSessionHistoryItem(
                theme,
                '호흡 훈련',
                '오늘',
                '25분',
                0.92,
                AppTheme.customColors.breathingInhale,
              ),
              _buildSessionHistoryItem(
                theme,
                '음정 연습',
                '어제',
                '18분',
                0.88,
                AppTheme.customColors.voiceSoprano,
              ),
              _buildSessionHistoryItem(
                theme,
                '발음 교정',
                '2일 전',
                '22분',
                0.75,
                AppTheme.customColors.voiceAlto,
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () {
              // Show full history
            },
            child: const Text('전체 기록 보기'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionHistoryItem(
    ThemeData theme,
    String title,
    String date,
    String duration,
    double score,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$date • $duration',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(score * 100).round()}점',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: score,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection(ThemeData theme) {
    return ModernDashboardCard(
      title: '개선 제안',
      subtitle: 'AI가 분석한 맞춤형 학습 가이드',
      icon: Icons.psychology,
      accentColor: theme.colorScheme.tertiary,
      content: Column(
        children: [
          _buildRecommendationItem(
            theme,
            '호흡 안정성 향상',
            '장시간 호흡 유지 연습을 통해 안정성을 높여보세요',
            Icons.air,
            AppTheme.customColors.breathingInhale,
            '고우선순위',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildRecommendationItem(
            theme,
            '음정 정확도 개선',
            '스케일 연습을 늘려 음정 감각을 기르는 것이 좋겠어요',
            Icons.music_note,
            AppTheme.customColors.voiceSoprano,
            '중간우선순위',
          ),
          const SizedBox(height: AppSpacing.md),
          _buildRecommendationItem(
            theme,
            '일정한 연습 패턴',
            '매일 같은 시간에 연습하면 더 좋은 결과를 얻을 수 있어요',
            Icons.schedule,
            AppTheme.customColors.progressGood,
            '낮은우선순위',
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(
    ThemeData theme,
    String title,
    String description,
    IconData icon,
    Color color,
    String priority,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        priority,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(
    String label,
    String value,
    IconData icon,
    Color color,
    String change,
  ) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Container(
          padding: const EdgeIsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Row(
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    change,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getSkillLevel(double progress) {
    if (progress >= 0.8) return '고급';
    if (progress >= 0.6) return '중급';
    if (progress >= 0.3) return '초급';
    return '입문';
  }

  String _getSkillRecommendation(String skill, double progress) {
    switch (skill) {
      case '호흡':
        return progress < 0.5 
            ? '기본 복식호흡 연습을 늘려보세요'
            : '장시간 호흡 유지 훈련을 추천합니다';
      case '음정':
        return progress < 0.5
            ? '스케일 연습으로 기초를 다져보세요'
            : '복잡한 멜로디 연습에 도전해보세요';
      case '발음':
        return progress < 0.5
            ? '자음 발음 연습에 집중해보세요'
            : '빠른 아티큘레이션 연습을 해보세요';
      case '음색':
        return progress < 0.5
            ? '공명 연습으로 기초를 다져보세요'
            : '다양한 음색 실험을 해보세요';
      default:
        return '꾸준한 연습을 계속해보세요';
    }
  }
}

/// Skill progress data class
class SkillProgress {
  final String name;
  final double current;
  final double previous;
  final Color color;
  final IconData icon;

  SkillProgress({
    required this.name,
    required this.current,
    required this.previous,
    required this.color,
    required this.icon,
  });
}

/// Achievement data class
class Achievement {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isEarned;
  final String? earnedDate;
  final double? progress;

  Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isEarned,
    this.earnedDate,
    this.progress,
  });
}