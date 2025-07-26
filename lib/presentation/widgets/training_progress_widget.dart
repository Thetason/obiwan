import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/vocal_analysis.dart';
import '../../features/training_modules/structured_vocal_training.dart';
import '../../features/ai_coaching/expert_knowledge_base.dart';
import '../../core/theme/app_theme.dart';

/// 트레이닝 진행도 및 통계 위젯
class TrainingProgressWidget extends ConsumerStatefulWidget {
  final StructuredVocalTraining trainingSystem;
  final List<VocalAnalysis> userHistory;
  final String currentUserLevel;

  const TrainingProgressWidget({
    super.key,
    required this.trainingSystem,
    required this.userHistory,
    required this.currentUserLevel,
  });

  @override
  ConsumerState<TrainingProgressWidget> createState() => _TrainingProgressWidgetState();
}

class _TrainingProgressWidgetState extends ConsumerState<TrainingProgressWidget> {
  int _selectedTabIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassmorphismDecoration,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildTabSelector(),
            const SizedBox(height: 16),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.analytics,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '트레이닝 진행도',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '현재 레벨: ${_getLevelDisplayName(widget.currentUserLevel)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.trending_up,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.userHistory.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    final tabs = ['개요', '모드별', '상세 통계'];
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == _selectedTabIndex;
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.primaryGradient : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildModeStatsTab();
      case 2:
        return _buildDetailedStatsTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    final stats = widget.trainingSystem.getTrainingStatistics();
    final recentAnalyses = widget.userHistory.take(10).toList();
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Progress Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.2),
                  AppTheme.accentColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard('총 세션', '${widget.userHistory.length}', Icons.play_circle),
                    _buildStatCard('현재 레벨', _getLevelDisplayName(widget.currentUserLevel), Icons.trending_up),
                    _buildStatCard('평균 점수', _calculateAverageScore().toStringAsFixed(0), Icons.score),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Recent Performance Trend
          Text(
            '📈 최근 성과 트렌드',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (recentAnalyses.isNotEmpty) _buildPerformanceTrend(recentAnalyses),
          const SizedBox(height: 20),
          
          // Achievements
          Text(
            '🏆 최근 성취',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildRecentAchievements(),
        ],
      ),
    );
  }

  Widget _buildModeStatsTab() {
    final stats = widget.trainingSystem.getTrainingStatistics();
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: TrainingMode.values.map((mode) {
          final modeStats = stats[mode.toString()] as Map<String, dynamic>?;
          return _buildModeStatCard(mode, modeStats);
        }).toList(),
      ),
    );
  }

  Widget _buildDetailedStatsTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkillRadarChart(),
          const SizedBox(height: 20),
          _buildProgressTimeline(),
          const SizedBox(height: 20),
          _buildPersonalBests(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceTrend(List<VocalAnalysis> recentAnalyses) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: recentAnalyses.asMap().entries.map((entry) {
          final index = entry.key;
          final analysis = entry.value;
          final score = ExpertEvaluationEngine.calculateExpertScore(analysis);
          final height = (score / 100.0) * 80;
          
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.accentColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentAchievements() {
    final achievements = [
      '🎵 음정 안정성 향상',
      '💨 복식호흡 달성',
      '🌟 7일 연속 연습',
    ];
    
    return Column(
      children: achievements.map((achievement) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Text(
              achievement,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildModeStatCard(TrainingMode mode, Map<String, dynamic>? stats) {
    final hasStats = stats != null;
    final sessions = hasStats ? stats['total_sessions'] as int : 0;
    final avgScore = hasStats ? (stats['average_score'] as double).toStringAsFixed(1) : '0.0';
    final bestScore = hasStats ? stats['best_score'] as int : 0;
    final totalTime = hasStats ? stats['total_time'] as int : 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getModeIcon(mode),
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _getModeDisplayName(mode),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!hasStats)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '연습 필요',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildModeStatItem('세션', '$sessions회'),
              ),
              Expanded(
                child: _buildModeStatItem('평균', avgScore),
              ),
              Expanded(
                child: _buildModeStatItem('최고', '$bestScore'),
              ),
              Expanded(
                child: _buildModeStatItem('시간', '${totalTime}분'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildSkillRadarChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎯 역량 분석',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildSkillBar('음정 정확도', _calculateSkillLevel('pitch')),
          _buildSkillBar('호흡 기법', _calculateSkillLevel('breathing')),
          _buildSkillBar('공명 조절', _calculateSkillLevel('resonance')),
          _buildSkillBar('표현력', _calculateSkillLevel('expression')),
          _buildSkillBar('전체 안정성', _calculateSkillLevel('stability')),
        ],
      ),
    );
  }

  Widget _buildSkillBar(String skill, double level) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                skill,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                ),
              ),
              Text(
                '${(level * 100).toInt()}%',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: level,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  level >= 0.8 ? AppTheme.successColor :
                  level >= 0.6 ? AppTheme.warningColor :
                  AppTheme.errorColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTimeline() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📅 진행 타임라인',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          // 주간별 진행도 표시
          Text(
            '최근 활동이 표시됩니다.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalBests() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🏅 개인 기록',
            style: TextStyle(
              color: AppTheme.successColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '최고 점수: ${_calculatePersonalBest()}점',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
            ),
          ),
          Text(
            '연속 연습: ${_calculateStreakDays()}일',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _getLevelDisplayName(String level) {
    switch (level) {
      case 'beginner': return '초급';
      case 'intermediate': return '중급';
      case 'advanced': return '고급';
      case 'expert': return '전문가';
      default: return '미정';
    }
  }

  double _calculateAverageScore() {
    if (widget.userHistory.isEmpty) return 0.0;
    final totalScore = widget.userHistory
        .map((analysis) => ExpertEvaluationEngine.calculateExpertScore(analysis))
        .reduce((a, b) => a + b);
    return totalScore / widget.userHistory.length;
  }

  double _calculateSkillLevel(String skill) {
    if (widget.userHistory.isEmpty) return 0.0;
    
    switch (skill) {
      case 'pitch':
        return widget.userHistory.map((a) => a.pitchStability).reduce((a, b) => a + b) / widget.userHistory.length;
      case 'breathing':
        final diaphragmaticCount = widget.userHistory.where((a) => a.breathingType == BreathingType.diaphragmatic).length;
        return diaphragmaticCount / widget.userHistory.length;
      case 'resonance':
        return 0.7; // Placeholder
      case 'expression':
        return 0.6; // Placeholder
      case 'stability':
        return widget.userHistory.map((a) => a.pitchStability).reduce((a, b) => a + b) / widget.userHistory.length;
      default:
        return 0.0;
    }
  }

  int _calculatePersonalBest() {
    if (widget.userHistory.isEmpty) return 0;
    return widget.userHistory
        .map((analysis) => ExpertEvaluationEngine.calculateExpertScore(analysis))
        .reduce((a, b) => a > b ? a : b);
  }

  int _calculateStreakDays() {
    // Placeholder for streak calculation
    return 3;
  }

  IconData _getModeIcon(TrainingMode mode) {
    switch (mode) {
      case TrainingMode.breathing: return Icons.air;
      case TrainingMode.pitch: return Icons.music_note;
      case TrainingMode.scales: return Icons.piano;
      case TrainingMode.resonance: return Icons.graphic_eq;
      case TrainingMode.expression: return Icons.emoji_emotions;
      case TrainingMode.freeStyle: return Icons.mic;
    }
  }

  String _getModeDisplayName(TrainingMode mode) {
    switch (mode) {
      case TrainingMode.breathing: return '호흡법';
      case TrainingMode.pitch: return '음정';
      case TrainingMode.scales: return '스케일';
      case TrainingMode.resonance: return '공명';
      case TrainingMode.expression: return '표현력';
      case TrainingMode.freeStyle: return '자유연습';
    }
  }
}