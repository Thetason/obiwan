import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/common/animated_record_button.dart';
import '../widgets/common/progress_indicators.dart';
import '../widgets/common/audio_waveform_widget.dart';
import '../widgets/dashboard/modern_dashboard_card.dart';
import 'dashboard_screen.dart';
import 'training_screen.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';

/// Main application screen with bottom navigation
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  
  final List<NavItem> _navItems = [
    NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: '대시보드',
    ),
    NavItem(
      icon: Icons.school_outlined,
      activeIcon: Icons.school,
      label: '훈련',
    ),
    NavItem(
      icon: Icons.trending_up_outlined,
      activeIcon: Icons.trending_up,
      label: '진행률',
    ),
    NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: '설정',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    _fabAnimationController = AnimationController(
      duration: AppAnimations.medium,
      vsync: this,
    );
    
    _fabScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _fabAnimationController.forward();
  }

  void _onNavItemTapped(int index) {
    if (index == _currentIndex) return;
    
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
    
    _pageController.animateToPage(
      index,
      duration: AppAnimations.medium,
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        children: const [
          DashboardScreen(),
          TrainingScreen(),
          ProgressScreen(),
          SettingsScreen(),
        ],
      ),
      
      bottomNavigationBar: _buildBottomNavBar(theme),
      
      floatingActionButton: _buildFloatingActionButton(theme),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBottomNavBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < _navItems.length; i++) ...[
                if (i == 2) const SizedBox(width: 80), // Space for FAB
                _buildNavItem(i, theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, ThemeData theme) {
    final item = _navItems[index];
    final isActive = index == _currentIndex;
    
    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive 
              ? theme.colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: AppAnimations.fast,
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                key: ValueKey('${item.label}_$isActive'),
                color: isActive 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.6),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: AppAnimations.fast,
              style: theme.textTheme.bodySmall!.copyWith(
                color: isActive 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.6),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(ThemeData theme) {
    return AnimatedBuilder(
      animation: _fabScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _fabScaleAnimation.value,
          child: AnimatedRecordButton(
            isRecording: false, // This would be connected to actual recording state
            size: 64,
            onPressed: () {
              // Handle recording action
              HapticFeedback.heavyImpact();
              _showRecordingBottomSheet(context);
            },
          ),
        );
      },
    );
  }

  void _showRecordingBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RecordingBottomSheet(),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }
}

/// Navigation item data class
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Recording bottom sheet with waveform visualization and controls
class RecordingBottomSheet extends StatefulWidget {
  const RecordingBottomSheet({super.key});

  @override
  State<RecordingBottomSheet> createState() => _RecordingBottomSheetState();
}

class _RecordingBottomSheetState extends State<RecordingBottomSheet>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  
  // Mock audio data for demonstration
  List<double> _audioData = [];
  
  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: AppAnimations.medium,
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    
    _slideController.forward();
    
    // Generate mock audio data
    _generateMockAudioData();
  }

  void _generateMockAudioData() {
    // Generate some mock waveform data
    final List<double> mockData = [];
    for (int i = 0; i < 100; i++) {
      mockData.add((i / 100) * 0.8 * (1 - i / 100));
    }
    setState(() => _audioData = mockData);
  }

  void _toggleRecording() {
    setState(() => _isRecording = !_isRecording);
    HapticFeedback.mediumImpact();
    
    if (_isRecording) {
      // Start recording logic
    } else {
      // Stop recording logic
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: mediaQuery.size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isRecording ? '녹음 중...' : '음성 녹음',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _isRecording ? '마이크에 대고 말씀해 주세요' : '아래 버튼을 눌러 녹음을 시작하세요',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            // Waveform visualization
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    // Main waveform
                    Expanded(
                      flex: 2,
                      child: AudioWaveformWidget(
                        audioData: _audioData,
                        height: 120,
                        isRealTime: _isRecording,
                        showGradient: true,
                        style: WaveformStyle.mirror,
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),
                    
                    // Recording stats
                    if (_isRecording)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildRecordingStat('시간', '00:45', Icons.timer),
                          _buildRecordingStat('음량', '72dB', Icons.volume_up),
                          _buildRecordingStat('품질', '좋음', Icons.high_quality),
                        ],
                      ),
                    
                    const SizedBox(height: AppSpacing.xl),
                    
                    // Recording button
                    AnimatedRecordButton(
                      isRecording: _isRecording,
                      onPressed: _toggleRecording,
                      size: 80,
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),
                    
                    // Action buttons
                    if (!_isRecording) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // Play last recording
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('재생'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Analyze recording
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.analytics),
                              label: const Text('분석'),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: _toggleRecording,
                        icon: const Icon(Icons.stop),
                        label: const Text('녹음 중지'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.customColors.error,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Bottom padding
            SizedBox(height: mediaQuery.padding.bottom + AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingStat(String label, String value, IconData icon) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }
}