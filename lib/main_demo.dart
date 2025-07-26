import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/enhanced_app_theme.dart';

void main() {
  runApp(const ProviderScope(child: VocalTrainerDemoApp()));
}

class VocalTrainerDemoApp extends StatelessWidget {
  const VocalTrainerDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 보컬 트레이너 - UI 데모',
      theme: ThemeData.dark(),
      home: const EnhancedMainDemoPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class EnhancedMainDemoPage extends StatefulWidget {
  const EnhancedMainDemoPage({super.key});

  @override
  State<EnhancedMainDemoPage> createState() => _EnhancedMainDemoPageState();
}

class _EnhancedMainDemoPageState extends State<EnhancedMainDemoPage>
    with TickerProviderStateMixin, CustomWidgetStyles {
  bool _isRecording = false;
  bool _showPracticeMode = false;
  
  late AnimationController _pulseController;
  late AnimationController _backgroundController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    
    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: _buildDynamicBackground(),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildEnhancedAppBar(context),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: EnhancedAppTheme.getSpacing(context, 16),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 1, child: _buildLeftPanel()),
                          SizedBox(width: EnhancedAppTheme.getSpacing(context, 16)),
                          Expanded(flex: 1, child: _buildRightPanel()),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: EnhancedAppTheme.getSpacing(context, 16)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Gradient _buildDynamicBackground() {
    final animationValue = _backgroundAnimation.value;
    
    if (_isRecording) {
      return RadialGradient(
        center: Alignment.topCenter,
        radius: 1.2 + (animationValue * 0.3),
        colors: [
          Color.lerp(const Color(0xFF1a1a2e), EnhancedAppTheme.neonBlue.withValues(alpha: 0.3), animationValue * 0.5)!,
          Color.lerp(const Color(0xFF16213e), EnhancedAppTheme.neonGreen.withValues(alpha: 0.2), animationValue * 0.3)!,
          const Color(0xFF0f0f23),
        ],
      );
    }
    
    return EnhancedAppTheme.backgroundGradient;
  }

  Widget _buildEnhancedAppBar(BuildContext context) {
    return Container(
      height: 90,
      margin: EdgeInsets.all(EnhancedAppTheme.getSpacing(context, 16)),
      decoration: EnhancedAppTheme.glassmorphism.copyWith(
        borderRadius: BorderRadius.circular(25),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            _buildAnimatedMicrophoneIcon(),
            const SizedBox(width: 16),
            Expanded(child: _buildAppInfo()),
            _buildStatusIndicators(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedMicrophoneIcon() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isRecording ? _pulseAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: _isRecording 
                  ? EnhancedAppTheme.successGradient 
                  : EnhancedAppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: _isRecording ? [
                BoxShadow(
                  color: EnhancedAppTheme.neonGreen.withValues(alpha: 0.5),
                  blurRadius: 25,
                  spreadRadius: 3,
                ),
              ] : [],
            ),
            child: Icon(
              _isRecording ? ThemeIcons.microphone : ThemeIcons.microphoneOff,
              color: Colors.white,
              size: 32,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppInfo() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildGradientText(
          text: 'AI 보컬 트레이너',
          gradient: EnhancedAppTheme.primaryGradient,
          style: EnhancedAppTheme.headingMedium.copyWith(
            fontSize: EnhancedAppTheme.getFontSize(context, 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isRecording ? '🎵 실시간 AI 분석 중...' : '프로페셔널 보컬 코칭 시스템',
          style: EnhancedAppTheme.bodyMedium.copyWith(
            color: _isRecording ? EnhancedAppTheme.neonGreen : EnhancedAppTheme.accentLight,
            fontSize: EnhancedAppTheme.getFontSize(context, 14),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicators() {
    return Row(
      children: [
        _buildAIScoreCard(),
        const SizedBox(width: 12),
        _buildLiveStatusIndicator(),
        const SizedBox(width: 12),
        _buildSettingsButton(),
      ],
    );
  }

  Widget _buildAIScoreCard() {
    const score = 85;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getScoreColor(score).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ThemeIcons.brain,
                color: _getScoreColor(score),
                size: 20,
              ),
              const SizedBox(width: 6),
              buildGradientText(
                text: '$score',
                gradient: LinearGradient(
                  colors: [_getScoreColor(score), _getScoreColor(score).withValues(alpha: 0.7)],
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            'AI 점수',
            style: EnhancedAppTheme.caption.copyWith(
              color: EnhancedAppTheme.accentLight.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusIndicator() {
    return AnimatedContainer(
      duration: EnhancedAppTheme.defaultDuration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: _isRecording 
            ? EnhancedAppTheme.successGradient 
            : LinearGradient(
                colors: [
                  EnhancedAppTheme.accentLight.withValues(alpha: 0.3),
                  EnhancedAppTheme.accentLight.withValues(alpha: 0.1),
                ],
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isRecording ? EnhancedAppTheme.neonGreen : EnhancedAppTheme.accentLight,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: EnhancedAppTheme.fastDuration,
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isRecording ? Colors.white : EnhancedAppTheme.accentLight,
              shape: BoxShape.circle,
              boxShadow: _isRecording ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.8),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ] : [],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isRecording ? 'LIVE' : 'READY',
            style: TextStyle(
              color: _isRecording ? Colors.white : EnhancedAppTheme.accentLight,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsButton() {
    return Container(
      decoration: EnhancedAppTheme.glassmorphism.copyWith(
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(
          ThemeIcons.settings,
          color: EnhancedAppTheme.accentLight,
          size: 20,
        ),
        onPressed: () {},
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _buildAudioVisualizationDemo(),
        ),
        SizedBox(height: EnhancedAppTheme.getSpacing(context, 16)),
        Expanded(
          flex: 1,
          child: _buildControlPanelDemo(),
        ),
      ],
    );
  }

  Widget _buildRightPanel() {
    return Column(
      children: [
        _buildModeToggle(),
        SizedBox(height: EnhancedAppTheme.getSpacing(context, 16)),
        Expanded(
          child: _showPracticeMode 
              ? _buildPracticeModeDemo()
              : _buildAnalysisModeDemo(),
        ),
      ],
    );
  }

  Widget _buildAudioVisualizationDemo() {
    return buildHoverCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(ThemeIcons.waveform, color: EnhancedAppTheme.neonBlue, size: 24),
              const SizedBox(width: 12),
              Text(
                '실시간 음성 분석',
                style: EnhancedAppTheme.headingMedium.copyWith(
                  fontSize: 18,
                  color: EnhancedAppTheme.highlight,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: _isRecording ? EnhancedAppTheme.successGradient : null,
                  color: !_isRecording ? Colors.white.withValues(alpha: 0.1) : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isRecording ? '음성 감지' : '대기 중',
                  style: TextStyle(
                    color: _isRecording ? Colors.white : EnhancedAppTheme.accentLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _isRecording 
                          ? EnhancedAppTheme.neonGreen.withValues(alpha: 0.6)
                          : EnhancedAppTheme.neonBlue.withValues(alpha: 0.4),
                      _isRecording 
                          ? EnhancedAppTheme.neonBlue.withValues(alpha: 0.3)
                          : EnhancedAppTheme.accentBlue.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: _isRecording ? [
                    BoxShadow(
                      color: EnhancedAppTheme.neonGreen.withValues(alpha: 0.4),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ] : [],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '440.0 Hz',
                        style: EnhancedAppTheme.headingMedium.copyWith(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A4',
                        style: EnhancedAppTheme.bodyLarge.copyWith(
                          color: EnhancedAppTheme.accentLight,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanelDemo() {
    return buildHoverCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(ThemeIcons.settings, color: EnhancedAppTheme.neonBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                '컨트롤 패널',
                style: EnhancedAppTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: EnhancedAppTheme.highlight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isRecording = !_isRecording;
                  });
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: _isRecording 
                        ? EnhancedAppTheme.errorGradient
                        : EnhancedAppTheme.successGradient,
                    shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: _isRecording ? BorderRadius.circular(16) : null,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording 
                            ? EnhancedAppTheme.neonRed 
                            : EnhancedAppTheme.neonGreen).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: EnhancedAppTheme.glassmorphism,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              _buildModeToggleButton(
                label: '실시간 분석',
                icon: ThemeIcons.analytics,
                isSelected: !_showPracticeMode,
                onTap: () => setState(() => _showPracticeMode = false),
              ),
              _buildModeToggleButton(
                label: '연습 모드',
                icon: ThemeIcons.music,
                isSelected: _showPracticeMode,
                onTap: () => setState(() => _showPracticeMode = true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: EnhancedAppTheme.defaultDuration,
          curve: EnhancedAppTheme.defaultCurve,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isSelected ? EnhancedAppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected ? [
              BoxShadow(
                color: EnhancedAppTheme.accentBlue.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : EnhancedAppTheme.accentLight,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : EnhancedAppTheme.accentLight,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisModeDemo() {
    return Column(
      children: [
        Expanded(
          child: buildHoverCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility, color: EnhancedAppTheme.neonBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '시각 가이드',
                      style: EnhancedAppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: EnhancedAppTheme.highlight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: Text(
                      '2D 해부학적 시각화\n(호흡, 성대, 공명)',
                      textAlign: TextAlign.center,
                      style: EnhancedAppTheme.bodyMedium.copyWith(
                        color: EnhancedAppTheme.accentLight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: buildHoverCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, color: EnhancedAppTheme.neonGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'AI 코칭',
                      style: EnhancedAppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: EnhancedAppTheme.highlight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: Text(
                      '스마트 피드백 &\n개인화된 가이드',
                      textAlign: TextAlign.center,
                      style: EnhancedAppTheme.bodyMedium.copyWith(
                        color: EnhancedAppTheme.accentLight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeModeDemo() {
    return buildHoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: EnhancedAppTheme.neonOrange, size: 20),
              const SizedBox(width: 8),
              Text(
                '연습 모드',
                style: EnhancedAppTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: EnhancedAppTheme.highlight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_note,
                    color: EnhancedAppTheme.neonOrange,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '체계적 보컬 트레이닝',
                    textAlign: TextAlign.center,
                    style: EnhancedAppTheme.bodyLarge.copyWith(
                      color: EnhancedAppTheme.highlight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '호흡법 • 음정 • 공명 • 표현력',
                    textAlign: TextAlign.center,
                    style: EnhancedAppTheme.bodyMedium.copyWith(
                      color: EnhancedAppTheme.accentLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return EnhancedAppTheme.neonGreen;
    if (score >= 80) return EnhancedAppTheme.neonBlue;
    if (score >= 70) return EnhancedAppTheme.neonOrange;
    if (score >= 60) return EnhancedAppTheme.neonPink;
    return EnhancedAppTheme.neonRed;
  }
}