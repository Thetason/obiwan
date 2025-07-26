import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard/modern_dashboard_card.dart';
import '../widgets/training/breathing_coaching_widget.dart';
import '../widgets/common/progress_indicators.dart';

/// Training screen with exercise categories and coaching
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  
  @override
  bool get wantKeepAlive => true;
  
  late TabController _tabController;
  int _selectedCategory = 0;
  
  final List<TrainingCategory> _categories = [
    TrainingCategory(
      name: '호흡',
      icon: Icons.air,
      color: AppTheme.customColors.breathingInhale,
      description: '올바른 호흡법으로 발성의 기초를 다져보세요',
    ),
    TrainingCategory(
      name: '음정',
      icon: Icons.music_note,
      color: AppTheme.customColors.voiceSoprano,
      description: '정확한 음정으로 아름다운 선율을 만들어보세요',
    ),
    TrainingCategory(
      name: '발음',
      icon: Icons.record_voice_over,
      color: AppTheme.customColors.voiceAlto,
      description: '명확한 발음으로 전달력을 높여보세요',
    ),
    TrainingCategory(
      name: '음색',
      icon: Icons.graphic_eq,
      color: AppTheme.customColors.voiceTenor,
      description: '개성 있는 음색을 개발해보세요',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _categories.length,
      vsync: this,
    );
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedCategory = _tabController.index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // App bar with categories
              SliverAppBar(
                expandedHeight: 160,
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
                        '훈련 센터 🎯',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '체계적인 연습으로 실력을 향상시켜보세요',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Category tabs
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      color: theme.colorScheme.primary.withOpacity(0.1),
                    ),
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
                    labelStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: theme.textTheme.titleSmall,
                    tabs: _categories.map((category) {
                      return Tab(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                category.icon,
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(category.name),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildBreathingTraining(),
              _buildPitchTraining(),
              _buildArticulationTraining(),
              _buildToneTraining(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreathingTraining() {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current level and progress
          _buildLevelCard(
            theme,
            '호흡 훈련',
            'Level 3',
            0.65,
            '기본 호흡법을 마스터하셨네요! 심화 과정을 시작해보세요.',
            AppTheme.customColors.breathingInhale,
          ),
          
          const SizedBox(height: AppSpacing.xl),
          
          // Interactive breathing coach
          ModernDashboardCard(
            title: '실시간 호흡 코칭',
            subtitle: 'AI 코치와 함께하는 개인화된 호흡 훈련',
            icon: Icons.psychology,
            accentColor: AppTheme.customColors.breathingInhale,
            content: const BreathingCoachingWidget(
              exerciseType: BreathingExerciseType.box,
              cycles: 3,
              showInstructions: true,
            ),
          ),
          
          const SizedBox(height: AppSpacing.xl),
          
          // Exercise list
          _buildExerciseList(
            theme,
            '호흡 연습 프로그램',
            [
              ExerciseItem(
                title: '기본 복식호흡',
                description: '횡격막을 사용한 올바른 호흡법',
                duration: '5분',
                difficulty: '초급',
                progress: 1.0,
                isCompleted: true,
                color: AppTheme.customColors.success,
              ),
              ExerciseItem(
                title: '박스 호흡법',
                description: '4-4-4-4 리듬의 안정화 호흡',
                duration: '8분',
                difficulty: '초급',
                progress: 0.8,
                isCompleted: false,
                color: AppTheme.customColors.breathingInhale,
              ),
              ExerciseItem(
                title: '립 트릴 호흡',
                description: '입술 진동과 함께하는 호흡 연습',
                duration: '10분',
                difficulty: '중급',
                progress: 0.3,
                isCompleted: false,
                color: AppTheme.customColors.breathingExhale,
              ),
              ExerciseItem(
                title: '장시간 호흡법',
                description: '지속적인 호흡 유지 훈련',
                duration: '12분',
                difficulty: '고급',
                progress: 0.0,
                isCompleted: false,
                color: AppTheme.customColors.breathingHold,
              ),
            ],
          ),
          
          const SizedBox(height: 80), // FAB padding
        ],
      ),
    );
  }

  Widget _buildPitchTraining() {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLevelCard(
            theme,
            '음정 훈련',
            'Level 2',
            0.45,
            '기본 스케일 연습을 통해 음정 감각을 기르고 있어요.',
            AppTheme.customColors.voiceSoprano,
          ),
          
          const SizedBox(height: AppSpacing.xl),
          
          // Pitch accuracy stats
          ModernDashboardCard(
            title: '음정 정확도 분석',
            subtitle: '최근 7일간의 음정 정확도 변화',
            icon: Icons.show_chart,
            accentColor: AppTheme.customColors.voiceSoprano,
            content: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPitchStat('평균 정확도', '87%', AppTheme.customColors.progressGood),
                    _buildPitchStat('최고 정확도', '95%', AppTheme.customColors.progressExcellent),
                    _buildPitchStat('개선도', '+8%', AppTheme.customColors.success),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: const Center(
                    child: Text('음정 변화 그래프 영역'),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.xl),
          
          _buildExerciseList(
            theme,
            '음정 연습 프로그램',
            [
              ExerciseItem(
                title: '도레미파솔 스케일',
                description: '기본 5음 스케일 연습',
                duration: '8분',
                difficulty: '초급',
                progress: 1.0,
                isCompleted: true,
                color: AppTheme.customColors.success,
              ),
              ExerciseItem(
                title: '옥타브 도약',
                description: '큰 음정 간격 연습',
                duration: '12분',
                difficulty: '중급',
                progress: 0.6,
                isCompleted: false,
                color: AppTheme.customColors.voiceSoprano,
              ),
              ExerciseItem(
                title: '반음계 연습',
                description: '정확한 반음 구별 훈련',
                duration: '15분',
                difficulty: '중급',
                progress: 0.2,
                isCompleted: false,
                color: AppTheme.customColors.voiceAlto,
              ),
              ExerciseItem(
                title: '복잡한 멜로디',
                description: '실전 곡 멜로디 연습',
                duration: '20분',
                difficulty: '고급',
                progress: 0.0,
                isCompleted: false,
                color: AppTheme.customColors.voiceTenor,
              ),
            ],
          ),
          
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildArticulationTraining() {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLevelCard(
            theme,
            '발음 훈련',
            'Level 1',
            0.25,
            '발음의 기초를 배우고 있어요. 꾸준히 연습해보세요!',
            AppTheme.customColors.voiceAlto,
          ),
          
          const SizedBox(height: AppSpacing.xl),
          
          _buildExerciseList(
            theme,
            '발음 연습 프로그램',
            [
              ExerciseItem(
                title: '자음 명확화',
                description: 'ㄱ,ㄴ,ㄷ,ㄹ,ㅁ 자음 연습',
                duration: '10분',
                difficulty: '초급',
                progress: 0.8,
                isCompleted: false,
                color: AppTheme.customColors.voiceAlto,
              ),
              ExerciseItem(
                title: '모음 순수화',
                description: 'ㅏ,ㅓ,ㅗ,ㅜ,ㅡ,ㅣ 모음 연습',
                duration: '12분',
                difficulty: '초급',
                progress: 0.4,
                isCompleted: false,
                color: AppTheme.customColors.voiceTenor,
              ),
              ExerciseItem(
                title: '받침 발음',
                description: '정확한 받침 발음 연습',
                duration: '15분',
                difficulty: '중급',
                progress: 0.0,
                isCompleted: false,
                color: AppTheme.customColors.voiceBass,
              ),
            ],
          ),
          
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildToneTraining() {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLevelCard(
            theme,
            '음색 훈련',
            'Level 1',
            0.15,
            '자신만의 독특한 음색을 찾아가는 여정을 시작했어요.',
            AppTheme.customColors.voiceTenor,
          ),
          
          const SizedBox(height: AppSpacing.xl),
          
          _buildExerciseList(
            theme,
            '음색 개발 프로그램',
            [
              ExerciseItem(
                title: '공명 연습',
                description: '가슴/머리 공명 개발',
                duration: '15분',
                difficulty: '중급',
                progress: 0.3,
                isCompleted: false,
                color: AppTheme.customColors.voiceTenor,
              ),
              ExerciseItem(
                title: '비브라토 연습',
                description: '자연스러운 비브라토 개발',
                duration: '18분',
                difficulty: '고급',
                progress: 0.0,
                isCompleted: false,
                color: AppTheme.customColors.voiceBass,
              ),
            ],
          ),
          
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildLevelCard(
    ThemeData theme, 
    String category, 
    String level, 
    double progress, 
    String description,
    Color color,
  ) {
    return ModernDashboardCard(
      title: '$category $level',
      subtitle: description,
      icon: Icons.star,
      accentColor: color,
      content: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedLinearProgress(
                  progress: progress,
                  label: '레벨 진행률',
                  showPercentage: true,
                  progressColor: color,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Column(
                children: [
                  Text(
                    '${(progress * 100).round()}%',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    '완료',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '다음 레벨까지 ${((1 - progress) * 100).round()}% 남았어요!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
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

  Widget _buildExerciseList(
    ThemeData theme,
    String title,
    List<ExerciseItem> exercises,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...exercises.map((exercise) => _buildExerciseCard(theme, exercise)),
      ],
    );
  }

  Widget _buildExerciseCard(ThemeData theme, ExerciseItem exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ModernDashboardCard(
        title: exercise.title,
        subtitle: exercise.description,
        accentColor: exercise.color,
        trailing: exercise.isCompleted
            ? Icon(
                Icons.check_circle,
                color: AppTheme.customColors.success,
              )
            : null,
        content: Column(
          children: [
            Row(
              children: [
                _buildExerciseInfo('시간', exercise.duration, Icons.schedule),
                const SizedBox(width: AppSpacing.lg),
                _buildExerciseInfo('난이도', exercise.difficulty, Icons.signal_cellular_alt),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AnimatedLinearProgress(
              progress: exercise.progress,
              label: '진행률',
              showPercentage: true,
              progressColor: exercise.color,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (!exercise.isCompleted) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Preview exercise
                      },
                      child: const Text('미리보기'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Start or continue exercise
                    },
                    style: exercise.isCompleted
                        ? ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.customColors.success,
                          )
                        : null,
                    child: Text(
                      exercise.isCompleted 
                          ? '완료됨' 
                          : exercise.progress > 0 
                              ? '계속하기' 
                              : '시작하기',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseInfo(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label: $value',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildPitchStat(String label, String value, Color color) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

/// Training category data class
class TrainingCategory {
  final String name;
  final IconData icon;
  final Color color;
  final String description;

  TrainingCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
  });
}

/// Exercise item data class
class ExerciseItem {
  final String title;
  final String description;
  final String duration;
  final String difficulty;
  final double progress;
  final bool isCompleted;
  final Color color;

  ExerciseItem({
    required this.title,
    required this.description,
    required this.duration,
    required this.difficulty,
    required this.progress,
    required this.isCompleted,
    required this.color,
  });
}

/// Custom sliver delegate for tab bar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}