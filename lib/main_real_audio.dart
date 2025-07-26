import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/enhanced_app_theme.dart';
import 'features/audio/audio_capture_service.dart';
import 'features/audio/audio_analysis_service_simple.dart';

void main() {
  runApp(const ProviderScope(child: VocalTrainerRealAudioApp()));
}

class VocalTrainerRealAudioApp extends StatelessWidget {
  const VocalTrainerRealAudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 보컬 트레이너 - 실제 오디오',
      theme: ThemeData.dark(),
      home: const RealAudioMainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RealAudioMainPage extends ConsumerStatefulWidget {
  const RealAudioMainPage({super.key});

  @override
  ConsumerState<RealAudioMainPage> createState() => _RealAudioMainPageState();
}

class _RealAudioMainPageState extends ConsumerState<RealAudioMainPage>
    with TickerProviderStateMixin, CustomWidgetStyles {
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
    final isRecording = ref.watch(isRecordingProvider);
    
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: _buildDynamicBackground(isRecording),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildEnhancedAppBar(context, isRecording),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: EnhancedAppTheme.getSpacing(context, 16),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 1, child: _buildLeftPanel(isRecording)),
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

  Gradient _buildDynamicBackground(bool isRecording) {
    final animationValue = _backgroundAnimation.value;
    
    if (isRecording) {
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

  Widget _buildEnhancedAppBar(BuildContext context, bool isRecording) {
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
            _buildAnimatedMicrophoneIcon(isRecording),
            const SizedBox(width: 16),
            Expanded(child: _buildAppInfo(isRecording)),
            _buildStatusIndicators(isRecording),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedMicrophoneIcon(bool isRecording) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isRecording ? _pulseAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isRecording 
                  ? EnhancedAppTheme.successGradient 
                  : EnhancedAppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isRecording ? [
                BoxShadow(
                  color: EnhancedAppTheme.neonGreen.withValues(alpha: 0.5),
                  blurRadius: 25,
                  spreadRadius: 3,
                ),
              ] : [],
            ),
            child: Icon(
              isRecording ? ThemeIcons.microphone : ThemeIcons.microphoneOff,
              color: Colors.white,
              size: 32,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppInfo(bool isRecording) {
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
          isRecording ? '🎵 실시간 AI 분석 중...' : '프로페셔널 보컬 코칭 시스템',
          style: EnhancedAppTheme.bodyMedium.copyWith(
            color: isRecording ? EnhancedAppTheme.neonGreen : EnhancedAppTheme.accentLight,
            fontSize: EnhancedAppTheme.getFontSize(context, 14),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicators(bool isRecording) {
    return Row(
      children: [
        _buildRealTimeAIScoreCard(),
        const SizedBox(width: 12),
        _buildLiveStatusIndicator(isRecording),
        const SizedBox(width: 12),
        _buildSettingsButton(),
      ],
    );
  }

  Widget _buildRealTimeAIScoreCard() {
    return Consumer(
      builder: (context, ref, child) {
        final analysisStream = ref.watch(simpleAudioAnalysisStreamProvider);
        
        return analysisStream.when(
          data: (analysis) {
            final score = analysis != null ? _calculateScore(analysis) : 0;
            return _buildScoreCard(score, analysis?.confidence ?? 0.0);
          },
          loading: () => _buildScoreCard(0, 0.0),
          error: (_, __) => _buildScoreCard(0, 0.0),
        );
      },
    );
  }

  Widget _buildScoreCard(int score, double confidence) {
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

  Widget _buildLiveStatusIndicator(bool isRecording) {
    return AnimatedContainer(
      duration: EnhancedAppTheme.defaultDuration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: isRecording 
            ? EnhancedAppTheme.successGradient 
            : LinearGradient(
                colors: [
                  EnhancedAppTheme.accentLight.withValues(alpha: 0.3),
                  EnhancedAppTheme.accentLight.withValues(alpha: 0.1),
                ],
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRecording ? EnhancedAppTheme.neonGreen : EnhancedAppTheme.accentLight,
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
              color: isRecording ? Colors.white : EnhancedAppTheme.accentLight,
              shape: BoxShape.circle,
              boxShadow: isRecording ? [
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
            isRecording ? 'LIVE' : 'READY',
            style: TextStyle(
              color: isRecording ? Colors.white : EnhancedAppTheme.accentLight,
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

  Widget _buildLeftPanel(bool isRecording) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _buildRealTimeAudioVisualization(isRecording),
        ),
        SizedBox(height: EnhancedAppTheme.getSpacing(context, 16)),
        Expanded(
          flex: 1,
          child: _buildRealControlPanel(),
        ),
      ],
    );
  }

  Widget _buildRealTimeAudioVisualization(bool isRecording) {
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
                  gradient: isRecording ? EnhancedAppTheme.successGradient : null,
                  color: !isRecording ? Colors.white.withValues(alpha: 0.1) : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isRecording ? '음성 감지' : '대기 중',
                  style: TextStyle(
                    color: isRecording ? Colors.white : EnhancedAppTheme.accentLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final analysisStream = ref.watch(simpleAudioAnalysisStreamProvider);
                
                return analysisStream.when(
                  data: (analysis) => _buildFrequencyDisplay(analysis, isRecording),
                  loading: () => _buildFrequencyDisplay(null, isRecording),
                  error: (_, __) => _buildFrequencyDisplay(null, isRecording),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyDisplay(AudioAnalysisResult? analysis, bool isRecording) {
    final frequency = analysis?.frequency ?? 0.0;
    final note = analysis?.note ?? 'N/A';
    final amplitude = analysis?.amplitude ?? 0.0;
    
    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              isRecording && frequency > 0
                  ? EnhancedAppTheme.neonGreen.withValues(alpha: 0.6 + amplitude * 0.4)
                  : EnhancedAppTheme.neonBlue.withValues(alpha: 0.4),
              isRecording && frequency > 0
                  ? EnhancedAppTheme.neonBlue.withValues(alpha: 0.3 + amplitude * 0.3)
                  : EnhancedAppTheme.accentBlue.withValues(alpha: 0.2),
              Colors.transparent,
            ],
          ),
          boxShadow: isRecording && frequency > 0 ? [
            BoxShadow(
              color: EnhancedAppTheme.neonGreen.withValues(alpha: 0.4 + amplitude * 0.4),
              blurRadius: 40 + amplitude * 20,
              spreadRadius: 10 + amplitude * 10,
            ),
          ] : [],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                frequency > 0 ? '${frequency.toStringAsFixed(1)} Hz' : '-- Hz',
                style: EnhancedAppTheme.headingMedium.copyWith(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                note,
                style: EnhancedAppTheme.bodyLarge.copyWith(
                  color: EnhancedAppTheme.accentLight,
                  fontSize: 16,
                ),
              ),
              if (analysis?.confidence != null && analysis!.confidence > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '신뢰도: ${(analysis.confidence * 100).toStringAsFixed(0)}%',
                    style: EnhancedAppTheme.caption.copyWith(
                      color: EnhancedAppTheme.accentLight.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealControlPanel() {
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
              child: Consumer(
                builder: (context, ref, child) {
                  final isRecording = ref.watch(isRecordingProvider);
                  final recordingNotifier = ref.read(isRecordingProvider.notifier);
                  
                  return GestureDetector(
                    onTap: () async {
                      try {
                        await recordingNotifier.toggleRecording();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('녹음 오류: $e'),
                              backgroundColor: EnhancedAppTheme.neonRed,
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: isRecording 
                            ? EnhancedAppTheme.errorGradient
                            : EnhancedAppTheme.successGradient,
                        shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius: isRecording ? BorderRadius.circular(16) : null,
                        boxShadow: [
                          BoxShadow(
                            color: (isRecording 
                                ? EnhancedAppTheme.neonRed 
                                : EnhancedAppTheme.neonGreen).withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
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
                      '2D 해부학적 시각화\\n(호흡, 성대, 공명)',
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
                      '스마트 피드백 &\\n개인화된 가이드',
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

  int _calculateScore(AudioAnalysisResult analysis) {
    // Simple scoring based on pitch stability and amplitude
    final pitchScore = analysis.confidence * 100;
    final amplitudeScore = (analysis.amplitude * 100).clamp(0, 100);
    
    return ((pitchScore * 0.7 + amplitudeScore * 0.3)).round();
  }
}