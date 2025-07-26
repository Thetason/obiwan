import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard/modern_dashboard_card.dart';
import '../widgets/common/progress_indicators.dart';
import '../widgets/common/audio_waveform_widget.dart';

/// Modern dashboard screen with analytics and quick actions
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  // Mock data for demonstration
  final List<double> _recentAudioData = [
    0.2, 0.4, 0.1, 0.6, 0.3, 0.8, 0.2, 0.5, 0.7, 0.3,
    0.9, 0.1, 0.4, 0.6, 0.2, 0.8, 0.5, 0.3, 0.7, 0.4,
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App bar
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
                      '안녕하세요! 👋',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '오늘도 멋진 목소리 연습을 시작해보세요',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    // Show notifications
                  },
                  icon: Stack(
                    children: [
                      const Icon(Icons.notifications_outlined),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppTheme.customColors.error,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                          child: Text(
                            '3',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontSize: 8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
            
            // Main content
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Today's progress overview
                  _buildTodayProgressSection(theme),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Statistics cards
                  _buildStatisticsSection(theme),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Recent activity
                  _buildRecentActivitySection(theme),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Quick actions
                  _buildQuickActionsSection(theme),
                  
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

  Widget _buildTodayProgressSection(ThemeData theme) {
    return ModernDashboardCard(
      title: '오늘의 진행 상황',
      subtitle: '목표 달성까지 ${100 - 78}% 남았어요',
      icon: Icons.today,
      accentColor: theme.colorScheme.primary,
      content: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ScoreProgressIndicator(
                  score: 0.78,
                  size: 80,
                  strokeWidth: 8,
                  label: '전체 점수',
                  showScore: true,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    AnimatedLinearProgress(
                      progress: 0.85,
                      label: '음정 정확도',
                      showPercentage: true,
                      progressColor: AppTheme.customColors.progressGood,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AnimatedLinearProgress(
                      progress: 0.72,
                      label: '호흡 안정성',
                      showPercentage: true,
                      progressColor: AppTheme.customColors.progressNeedsWork,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AnimatedLinearProgress(
                      progress: 0.91,
                      label: '발음 명확도',
                      showPercentage: true,
                      progressColor: AppTheme.customColors.progressExcellent,
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
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '오늘 연습 시간 목표를 달성했어요! 🎉',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이번 주 통계',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.2,
          children: [
            StatisticsCard(
              title: '연습 시간',
              value: '15.5',
              unit: '시간',
              icon: Icons.schedule,
              color: AppTheme.customColors.progressGood,
              trend: '+2.3시간',
            ),
            StatisticsCard(
              title: '완료된 연습',
              value: '42',
              unit: '개',
              icon: Icons.check_circle,
              color: AppTheme.customColors.progressExcellent,
              trend: '+8개',
            ),
            StatisticsCard(
              title: '평균 점수',
              value: '85',
              unit: '점',
              icon: Icons.star,
              color: AppTheme.customColors.warning,
              trend: '+5점',
            ),
            StatisticsCard(
              title: '연속 학습',
              value: '7',
              unit: '일',
              icon: Icons.local_fire_department,
              color: AppTheme.customColors.error,
              trend: '연속 기록!',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '최근 활동',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to full activity log
              },
              child: const Text('전체 보기'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        ModernDashboardCard(
          title: '최근 녹음 분석',
          subtitle: '10분 전',
          icon: Icons.graphic_eq,
          accentColor: AppTheme.customColors.waveformPrimary,
          content: Column(
            children: [
              // Compact waveform visualization
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: AudioWaveformWidget(
                  audioData: _recentAudioData,
                  height: 60,
                  isRealTime: false,
                  style: WaveformStyle.bars,
                  showGradient: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricChip('음정', '92%', AppTheme.customColors.progressExcellent),
                  _buildMetricChip('리듬', '88%', AppTheme.customColors.progressGood),
                  _buildMetricChip('음색', '76%', AppTheme.customColors.progressNeedsWork),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ModernDashboardCard(
          title: '호흡 연습 완료',
          subtitle: '1시간 전',
          icon: Icons.air,
          accentColor: AppTheme.customColors.breathingInhale,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '박스 호흡법 5사이클을 완료했습니다.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.customColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '완벽한 리듬 유지',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.customColors.success,
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

  Widget _buildQuickActionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '빠른 실행',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.3,
          children: [
            QuickActionCard(
              label: '음정 연습',
              icon: Icons.music_note,
              color: AppTheme.customColors.voiceSoprano,
              onTap: () {
                // Navigate to pitch training
              },
            ),
            QuickActionCard(
              label: '호흡 훈련',
              icon: Icons.air,
              color: AppTheme.customColors.breathingInhale,
              onTap: () {
                // Navigate to breathing training
              },
            ),
            QuickActionCard(
              label: '발성 연습',
              icon: Icons.record_voice_over,
              color: AppTheme.customColors.voiceAlto,
              onTap: () {
                // Navigate to vocal exercises
              },
            ),
            QuickActionCard(
              label: '진도 확인',
              icon: Icons.analytics,
              color: AppTheme.customColors.progressGood,
              onTap: () {
                // Navigate to progress
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecommendationsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '맞춤 추천',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ModernDashboardCard(
          title: 'AI 추천 연습',
          subtitle: '당신의 실력에 맞춘 개인화된 연습',
          icon: Icons.psychology,
          accentColor: theme.colorScheme.secondary,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.secondary.withOpacity(0.1),
                      theme.colorScheme.secondary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        color: theme.colorScheme.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '고음역 확장 연습',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '현재 음역대를 확장할 수 있는 단계적 연습',
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
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Show more recommendations
                      },
                      child: const Text('더 보기'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Start recommended exercise
                      },
                      child: const Text('시작하기'),
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

  Widget _buildMetricChip(String label, String value, Color color) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}