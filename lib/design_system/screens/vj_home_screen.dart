import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../tokens/colors.dart';
import '../tokens/typography.dart';
import '../tokens/spacing.dart';
import '../tokens/animations.dart';
import '../components/vj_button.dart';
import '../components/vj_card.dart';
import '../components/vj_progress_ring.dart';
import '../components/vj_stat_card.dart';
import 'vj_recording_flow.dart';
import '../../screens/admin_mode_screen.dart';
import '../../screens/ai_labeling_dashboard.dart';
import '../../screens/url_input_screen.dart';

class VJHomeScreen extends StatefulWidget {
  const VJHomeScreen({Key? key}) : super(key: key);

  @override
  State<VJHomeScreen> createState() => _VJHomeScreenState();
}

class _VJHomeScreenState extends State<VJHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _floatingController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _floatingAnimation;
  
  final DateTime _now = DateTime.now();
  double _todayProgress = 0.75; // Example progress
  
  // Admin Mode entry variables
  int _tapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _breathingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    
    _breathingAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));
    
    _floatingAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));
    
    _breathingController.repeat(reverse: true);
    _floatingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = _now.hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getMotivationalQuote() {
    final quotes = [
      'Your voice matters',
      'Every note is progress',
      'Sing your story',
      'Find your harmony',
      'Let your voice shine',
    ];
    return quotes[_now.day % quotes.length];
  }

  void _startRecording() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      VJAnimations.scaleRoute(const VJRecordingFlow()),
    );
  }
  
  void _onGreetingTap() {
    final now = DateTime.now();
    
    // Reset tap count if more than 2 seconds passed
    if (_lastTapTime == null || now.difference(_lastTapTime!).inSeconds > 2) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    
    _lastTapTime = now;
    
    // Enter Admin Mode on 5th tap
    if (_tapCount >= 5) {
      _tapCount = 0;
      _lastTapTime = null;
      
      HapticFeedback.lightImpact();
      
      // Show options dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Admin Features'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.label),
                title: const Text('Manual Labeling'),
                subtitle: const Text('Label YouTube vocals manually'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminModeScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('AI Labeling System'),
                subtitle: const Text('AI-Human hybrid labeling'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const URLInputScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VJColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(VJSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                SizedBox(height: VJSpacing.xl),
                _buildMainRecordButton(),
                SizedBox(height: VJSpacing.xl),
                _buildTodayProgress(),
                SizedBox(height: VJSpacing.lg),
                _buildQuickStats(),
                SizedBox(height: VJSpacing.lg),
                _buildRecentSessions(),
                SizedBox(height: VJSpacing.xxxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _onGreetingTap,
                  child: Text(
                    _getGreeting(),
                    style: VJTypography.displaySmall.copyWith(
                      color: VJColors.gray900,
                    ),
                  ),
                ),
                SizedBox(height: VJSpacing.xs),
                Text(
                  _getMotivationalQuote(),
                  style: VJTypography.bodyLarge.copyWith(
                    color: VJColors.gray500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: VJColors.primaryGradient,
              ),
              child: Center(
                child: Text(
                  'VJ',
                  style: VJTypography.labelLarge.copyWith(
                    color: VJColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainRecordButton() {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_breathingAnimation, _floatingAnimation]),
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -_floatingAnimation.value),
            child: Transform.scale(
              scale: _breathingAnimation.value,
              child: GestureDetector(
                onTap: _startRecording,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: VJColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: VJColors.primary.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 10,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer ring
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: VJColors.white.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                      ),
                      // Inner content
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mic,
                            size: 48,
                            color: VJColors.white,
                          ),
                          SizedBox(height: VJSpacing.xs),
                          Text(
                            'START',
                            style: VJTypography.labelLarge.copyWith(
                              color: VJColors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodayProgress() {
    return VJCard(
      type: VJCardType.filled,
      child: Row(
        children: [
          VJProgressRing(
            progress: _todayProgress,
            size: 80,
            strokeWidth: 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(_todayProgress * 100).toInt()}%',
                  style: VJTypography.titleLarge.copyWith(
                    color: VJColors.gray900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: VJSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Goal',
                  style: VJTypography.titleMedium.copyWith(
                    color: VJColors.gray900,
                  ),
                ),
                SizedBox(height: VJSpacing.xs),
                Text(
                  '15 minutes completed',
                  style: VJTypography.bodyMedium.copyWith(
                    color: VJColors.gray500,
                  ),
                ),
                SizedBox(height: VJSpacing.sm),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: VJSpacing.xs,
                        vertical: VJSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: VJColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(VJSpacing.radiusXs),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            size: 14,
                            color: VJColors.success,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '5 day streak',
                            style: VJTypography.labelSmall.copyWith(
                              color: VJColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Progress',
          style: VJTypography.titleLarge.copyWith(
            color: VJColors.gray900,
          ),
        ),
        SizedBox(height: VJSpacing.md),
        Row(
          children: [
            Expanded(
              child: VJStatCard(
                title: 'Pitch Accuracy',
                value: '92%',
                subtitle: 'Last session',
                icon: Icons.music_note,
                iconColor: VJColors.primary,
                trend: StatTrend.up,
                trendValue: 5.2,
              ),
            ),
            SizedBox(width: VJSpacing.md),
            Expanded(
              child: VJStatCard(
                title: 'Total Practice',
                value: '3.5h',
                subtitle: 'This week',
                icon: Icons.timer,
                iconColor: VJColors.secondary,
                trend: StatTrend.up,
                trendValue: 12.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentSessions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Sessions',
              style: VJTypography.titleLarge.copyWith(
                color: VJColors.gray900,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'See all',
                style: VJTypography.labelMedium.copyWith(
                  color: VJColors.primary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: VJSpacing.md),
        ..._buildSessionCards(),
      ],
    );
  }

  List<Widget> _buildSessionCards() {
    final sessions = [
      {'title': 'Morning Warm-up', 'accuracy': 95, 'duration': '5:23', 'time': '2 hours ago'},
      {'title': 'Scale Practice', 'accuracy': 88, 'duration': '8:45', 'time': 'Yesterday'},
      {'title': 'Free Session', 'accuracy': 92, 'duration': '12:30', 'time': '2 days ago'},
    ];

    return sessions.map((session) {
      return Padding(
        padding: EdgeInsets.only(bottom: VJSpacing.sm),
        child: VJCard(
          type: VJCardType.outlined,
          onTap: () {},
          padding: EdgeInsets.all(VJSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: VJColors.primaryLight,
                  borderRadius: BorderRadius.circular(VJSpacing.radiusSm),
                ),
                child: Center(
                  child: Text(
                    '${session['accuracy']}%',
                    style: VJTypography.labelMedium.copyWith(
                      color: VJColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: VJSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session['title'] as String,
                      style: VJTypography.titleSmall.copyWith(
                        color: VJColors.gray900,
                      ),
                    ),
                    SizedBox(height: VJSpacing.xxs),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: VJColors.gray500,
                        ),
                        SizedBox(width: 4),
                        Text(
                          session['duration'] as String,
                          style: VJTypography.bodySmall.copyWith(
                            color: VJColors.gray500,
                          ),
                        ),
                        SizedBox(width: VJSpacing.sm),
                        Text(
                          '•',
                          style: VJTypography.bodySmall.copyWith(
                            color: VJColors.gray500,
                          ),
                        ),
                        SizedBox(width: VJSpacing.sm),
                        Text(
                          session['time'] as String,
                          style: VJTypography.bodySmall.copyWith(
                            color: VJColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: VJColors.gray400,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}