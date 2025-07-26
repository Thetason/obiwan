import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard/modern_dashboard_card.dart';

/// Settings screen with user preferences and app configuration
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  // Settings state
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  bool _hapticFeedbackEnabled = true;
  bool _autoRecordingEnabled = false;
  bool _cloudSyncEnabled = true;
  double _audioQuality = 1.0; // 0: Low, 0.5: Medium, 1.0: High
  String _selectedLanguage = 'ko'; // ko, en, ja
  String _voiceType = 'soprano'; // soprano, alto, tenor, bass

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
                      '설정 ⚙️',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '앱을 나에게 맞게 설정해보세요',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Main content
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // User profile section
                  _buildUserProfileSection(theme),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Audio settings
                  _buildAudioSettingsSection(theme),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // App preferences
                  _buildAppPreferencesSection(theme),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Training settings
                  _buildTrainingSettingsSection(theme),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Data and privacy
                  _buildDataPrivacySection(theme),
                  
                  const SizedBox(height: AppSpacing.xl),
                  
                  // Support and about
                  _buildSupportSection(theme),
                  
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

  Widget _buildUserProfileSection(ThemeData theme) {
    return ModernDashboardCard(
      title: '프로필',
      subtitle: '내 정보를 관리하세요',
      icon: Icons.person,
      accentColor: theme.colorScheme.primary,
      content: Column(
        children: [
          // Profile picture and basic info
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '사용자',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.customColors.voiceSoprano.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        _getVoiceTypeLabel(_voiceType),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.customColors.voiceSoprano,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '레벨 3 • 연습 시간 47.5시간',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Edit profile
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('프로필 수정'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Voice type test
                  },
                  icon: const Icon(Icons.mic),
                  label: const Text('음성 테스트'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioSettingsSection(ThemeData theme) {
    return ModernDashboardCard(
      title: '오디오 설정',
      subtitle: '녹음 및 재생 품질을 조정하세요',
      icon: Icons.audiotrack,
      accentColor: AppTheme.customColors.waveformPrimary,
      content: Column(
        children: [
          // Audio quality slider
          _buildSliderSetting(
            theme,
            '오디오 품질',
            _audioQuality,
            ['낮음', '보통', '높음'],
            (value) => setState(() => _audioQuality = value),
            AppTheme.customColors.waveformPrimary,
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Auto recording toggle
          _buildSwitchSetting(
            theme,
            '자동 녹음',
            '음성이 감지되면 자동으로 녹음을 시작합니다',
            Icons.auto_fix_high,
            _autoRecordingEnabled,
            (value) => setState(() => _autoRecordingEnabled = value),
            AppTheme.customColors.waveformSecondary,
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Microphone calibration
          OutlinedButton.icon(
            onPressed: () {
              _showMicrophoneCalibration(context);
            },
            icon: const Icon(Icons.mic),
            label: const Text('마이크 보정'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppPreferencesSection(ThemeData theme) {
    return ModernDashboardCard(
      title: '앱 설정',
      subtitle: '앱의 모양과 동작을 설정하세요',
      icon: Icons.tune,
      accentColor: theme.colorScheme.secondary,
      content: Column(
        children: [
          // Dark mode toggle
          _buildSwitchSetting(
            theme,
            '다크 모드',
            '어두운 테마를 사용합니다',
            Icons.dark_mode,
            _isDarkMode,
            (value) => setState(() => _isDarkMode = value),
            theme.colorScheme.secondary,
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Language selection
          _buildSelectionSetting(
            theme,
            '언어',
            _getLanguageLabel(_selectedLanguage),
            Icons.language,
            () => _showLanguageSelection(context),
            theme.colorScheme.secondary,
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Notifications toggle
          _buildSwitchSetting(
            theme,
            '알림',
            '연습 리마인더 및 성과 알림을 받습니다',
            Icons.notifications,
            _notificationsEnabled,
            (value) => setState(() => _notificationsEnabled = value),
            AppTheme.customColors.info,
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Haptic feedback toggle
          _buildSwitchSetting(
            theme,
            '햅틱 피드백',
            '터치할 때 진동 피드백을 제공합니다',
            Icons.vibration,
            _hapticFeedbackEnabled,
            (value) => setState(() => _hapticFeedbackEnabled = value),
            AppTheme.customColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingSettingsSection(ThemeData theme) {
    return ModernDashboardCard(
      title: '훈련 설정',
      subtitle: '개인화된 학습 경험을 설정하세요',
      icon: Icons.school,
      accentColor: AppTheme.customColors.progressGood,
      content: Column(
        children: [
          // Voice type selection
          _buildSelectionSetting(
            theme,
            '음성 유형',
            _getVoiceTypeLabel(_voiceType),
            Icons.record_voice_over,
            () => _showVoiceTypeSelection(context),
            AppTheme.customColors.voiceSoprano,
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Cloud sync toggle
          _buildSwitchSetting(
            theme,
            '클라우드 동기화',
            '진행 상황을 클라우드에 백업합니다',
            Icons.cloud_sync,
            _cloudSyncEnabled,
            (value) => setState(() => _cloudSyncEnabled = value),
            AppTheme.customColors.progressGood,
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Training reminders
          OutlinedButton.icon(
            onPressed: () {
              _showReminderSettings(context);
            },
            icon: const Icon(Icons.alarm),
            label: const Text('연습 알림 설정'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataPrivacySection(ThemeData theme) {
    return ModernDashboardCard(
      title: '데이터 및 개인정보',
      subtitle: '내 데이터를 안전하게 관리하세요',
      icon: Icons.security,
      accentColor: AppTheme.customColors.success,
      content: Column(
        children: [
          _buildActionSetting(
            theme,
            '데이터 내보내기',
            '내 연습 데이터를 파일로 다운로드합니다',
            Icons.download,
            () => _exportData(context),
            AppTheme.customColors.success,
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          _buildActionSetting(
            theme,
            '데이터 삭제',
            '모든 연습 기록을 영구적으로 삭제합니다',
            Icons.delete_forever,
            () => _showDeleteDataDialog(context),
            AppTheme.customColors.error,
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          _buildActionSetting(
            theme,
            '개인정보 처리방침',
            '개인정보 보호 정책을 확인합니다',
            Icons.privacy_tip,
            () => _showPrivacyPolicy(context),
            AppTheme.customColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection(ThemeData theme) {
    return ModernDashboardCard(
      title: '지원 및 정보',
      subtitle: '도움말과 앱 정보를 확인하세요',
      icon: Icons.help,
      accentColor: AppTheme.customColors.info,
      content: Column(
        children: [
          _buildActionSetting(
            theme,
            '도움말',
            '앱 사용법과 FAQ를 확인합니다',
            Icons.help_outline,
            () => _showHelp(context),
            AppTheme.customColors.info,
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          _buildActionSetting(
            theme,
            '피드백 보내기',
            '개선 의견이나 버그를 신고합니다',
            Icons.feedback,
            () => _sendFeedback(context),
            AppTheme.customColors.warning,
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          _buildActionSetting(
            theme,
            '앱 정보',
            '버전 정보 및 라이선스를 확인합니다',
            Icons.info,
            () => _showAppInfo(context),
            theme.colorScheme.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchSetting(
    ThemeData theme,
    String title,
    String description,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
    Color color,
  ) {
    return Row(
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
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: color,
        ),
      ],
    );
  }

  Widget _buildSelectionSetting(
    ThemeData theme,
    String title,
    String currentValue,
    IconData icon,
    VoidCallback onTap,
    Color color,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              currentValue,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSetting(
    ThemeData theme,
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
    Color color,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSetting(
    ThemeData theme,
    String title,
    double value,
    List<String> labels,
    ValueChanged<double> onChanged,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.3),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 2,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels.map((label) => Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          )).toList(),
        ),
      ],
    );
  }

  // Helper methods for labels
  String _getLanguageLabel(String code) {
    switch (code) {
      case 'ko': return '한국어';
      case 'en': return 'English';
      case 'ja': return '日本語';
      default: return '한국어';
    }
  }

  String _getVoiceTypeLabel(String type) {
    switch (type) {
      case 'soprano': return '소프라노';
      case 'alto': return '알토';
      case 'tenor': return '테너';
      case 'bass': return '베이스';
      default: return '소프라노';
    }
  }

  // Dialog and action methods
  void _showLanguageSelection(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('언어 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('한국어'),
              value: 'ko',
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() => _selectedLanguage = value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() => _selectedLanguage = value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<String>(
              title: const Text('日本語'),
              value: 'ja',
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() => _selectedLanguage = value!);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVoiceTypeSelection(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('음성 유형 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('소프라노'),
              subtitle: const Text('높은 여성 음역'),
              value: 'soprano',
              groupValue: _voiceType,
              onChanged: (value) {
                setState(() => _voiceType = value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<String>(
              title: const Text('알토'),
              subtitle: const Text('낮은 여성 음역'),
              value: 'alto',
              groupValue: _voiceType,
              onChanged: (value) {
                setState(() => _voiceType = value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<String>(
              title: const Text('테너'),
              subtitle: const Text('높은 남성 음역'),
              value: 'tenor',
              groupValue: _voiceType,
              onChanged: (value) {
                setState(() => _voiceType = value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<String>(
              title: const Text('베이스'),
              subtitle: const Text('낮은 남성 음역'),
              value: 'bass',
              groupValue: _voiceType,
              onChanged: (value) {
                setState(() => _voiceType = value!);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMicrophoneCalibration(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('마이크 보정'),
        content: const Text('마이크 보정을 시작하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Start calibration
            },
            child: const Text('시작'),
          ),
        ],
      ),
    );
  }

  void _showReminderSettings(BuildContext context) {
    // Implementation for reminder settings
  }

  void _exportData(BuildContext context) {
    // Implementation for data export
  }

  void _showDeleteDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데이터 삭제'),
        content: const Text('모든 연습 기록이 영구적으로 삭제됩니다. 계속하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.customColors.error,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              // Delete data
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    // Implementation for privacy policy
  }

  void _showHelp(BuildContext context) {
    // Implementation for help
  }

  void _sendFeedback(BuildContext context) {
    // Implementation for feedback
  }

  void _showAppInfo(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Vocal Trainer AI',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: const Icon(
          Icons.mic,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        const Text('AI 기반 개인화 성악 훈련 앱'),
        const SizedBox(height: 16),
        const Text('© 2024 Vocal Trainer AI Team'),
      ],
    );
  }
}