import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/enhanced_audio_visualization_widget.dart';
import '../widgets/enhanced_visual_guide_widget.dart';
import '../widgets/enhanced_coaching_panel.dart';
import '../widgets/enhanced_control_panel_widget.dart';
import '../widgets/vocal_practice_mode_widget.dart';
import '../providers/audio_analysis_provider.dart';
import '../providers/real_time_analysis_provider.dart';
import '../providers/visual_guide_provider.dart';
import '../../domain/entities/vocal_analysis.dart';
import '../../features/training_modules/structured_vocal_training.dart';
import '../../core/theme/enhanced_app_theme.dart';

/// 향상된 메인 분석 페이지 - 현대적이고 세련된 UI
class EnhancedMainAnalysisPage extends ConsumerStatefulWidget {
  const EnhancedMainAnalysisPage({super.key});

  @override
  ConsumerState<EnhancedMainAnalysisPage> createState() => _EnhancedMainAnalysisPageState();
}

class _EnhancedMainAnalysisPageState extends ConsumerState<EnhancedMainAnalysisPage> 
    with TickerProviderStateMixin, CustomWidgetStyles {
  bool _isRecording = false;
  bool _showPracticeMode = false;
  TrainingMode _selectedMode = TrainingMode.breathing;
  TrainingDifficulty _selectedDifficulty = TrainingDifficulty.beginner;
  
  // 애니메이션 컨트롤러들
  late AnimationController _pulseController;
  late AnimationController _backgroundController;
  late AnimationController _cardController;
  
  // 애니메이션들
  late Animation<double> _pulseAnimation;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _cardSlideAnimation;
  late Animation<double> _cardFadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // 펄스 애니메이션 (마이크 버튼용)
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // 배경 애니메이션 (미묘한 컬러 변화)
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    
    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    );
    
    // 카드 슬라이드 애니메이션
    _cardController = AnimationController(
      duration: EnhancedAppTheme.slowDuration,
      vsync: this,
    );
    
    _cardSlideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );
    
    _cardFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: const Interval(0.3, 1.0)),
    );
    
    // 초기 카드 애니메이션 시작
    _cardController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _backgroundController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioAnalysisProvider);
    final visualGuideState = ref.watch(visualGuideProvider);
    final realTimeState = ref.watch(realTimeAnalysisProvider);
    
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
                  // 향상된 앱바
                  _buildEnhancedAppBar(context),
                  
                  // 메인 컨텐츠
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: EnhancedAppTheme.getSpacing(context, 16),
                      ),
                      child: Row(
                        children: [
                          // 왼쪽 패널 - 오디오 분석
                          Expanded(
                            flex: 1,
                            child: _buildLeftPanel(),
                          ),
                          
                          SizedBox(width: EnhancedAppTheme.getSpacing(context, 16)),
                          
                          // 오른쪽 패널 - 가이드 & 코칭
                          Expanded(
                            flex: 1,
                            child: _buildRightPanel(visualGuideState),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // 하단 여백
                  SizedBox(height: EnhancedAppTheme.getSpacing(context, 16)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 동적 배경 생성
  Gradient _buildDynamicBackground() {
    final baseGradient = EnhancedAppTheme.backgroundGradient;
    final animationValue = _backgroundAnimation.value;
    
    if (_isRecording) {
      // 녹음 중일 때는 더 생동감 있는 배경
      return RadialGradient(
        center: Alignment.topCenter,
        radius: 1.2 + (animationValue * 0.3),
        colors: [
          Color.lerp(const Color(0xFF1a1a2e), EnhancedAppTheme.neonBlue.withOpacity(0.3), animationValue * 0.5)!,
          Color.lerp(const Color(0xFF16213e), EnhancedAppTheme.neonGreen.withOpacity(0.2), animationValue * 0.3)!,
          const Color(0xFF0f0f23),
        ],
      );
    }
    
    return baseGradient;
  }

  /// 향상된 앱바
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
            // 애니메이션 마이크 아이콘
            _buildAnimatedMicrophoneIcon(),
            
            const SizedBox(width: 16),
            
            // 앱 정보
            Expanded(child: _buildAppInfo()),
            
            // 상태 인디케이터들
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
                  color: EnhancedAppTheme.neonGreen.withOpacity(0.5),
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
        Consumer(
          builder: (context, ref, child) {
            final emotion = ref.watch(emotionProvider);
            final style = ref.watch(styleProvider);
            final currentNote = ref.watch(currentNoteProvider);
            
            String statusText = _isRecording 
                ? '🎵 실시간 AI 분석 중...' 
                : '프로페셔널 보컬 코칭 시스템';
            
            if (_isRecording && currentNote.isNotEmpty) {
              statusText = '🎵 $currentNote | $emotion | $style';
            }
            
            return Text(
              statusText,
              style: EnhancedAppTheme.bodyMedium.copyWith(
                color: _isRecording ? EnhancedAppTheme.neonGreen : EnhancedAppTheme.accentLight,
                fontSize: EnhancedAppTheme.getFontSize(context, 14),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusIndicators() {
    return Row(
      children: [
        // AI 점수 표시
        _buildAIScoreCard(),
        const SizedBox(width: 12),
        // 라이브 상태 표시
        _buildLiveStatusIndicator(),
        const SizedBox(width: 12),
        // 설정 버튼
        _buildSettingsButton(),
      ],
    );
  }

  Widget _buildAIScoreCard() {
    return Consumer(
      builder: (context, ref, child) {
        final voiceQuality = ref.watch(voiceQualityProvider);
        final pitchAccuracy = ref.watch(pitchAccuracyProvider);
        final score = ((voiceQuality + pitchAccuracy / 100) / 2 * 100).round();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getScoreColor(score).withOpacity(0.5),
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
                      colors: [_getScoreColor(score), _getScoreColor(score).withOpacity(0.7)],
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
                  color: EnhancedAppTheme.accentLight.withOpacity(0.8),
                ),
              ),
            ],
          ),
        );
      },
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
                  EnhancedAppTheme.accentLight.withOpacity(0.3),
                  EnhancedAppTheme.accentLight.withOpacity(0.1),
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
                  color: Colors.white.withOpacity(0.8),
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
        onPressed: () {
          // 설정 페이지로 이동
        },
      ),
    );
  }

  /// 왼쪽 패널 - 오디오 분석
  Widget _buildLeftPanel() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-0.3, 0),
        end: Offset.zero,
      ).animate(_cardSlideAnimation),
      child: FadeTransition(
        opacity: _cardFadeAnimation,
        child: Column(
          children: [
            // 향상된 오디오 시각화
            Expanded(
              flex: 3,
              child: buildHoverCard(
                child: const EnhancedAudioVisualizationWidget(),
              ),
            ),
            
            SizedBox(height: EnhancedAppTheme.getSpacing(context, 16)),
            
            // 향상된 컨트롤 패널
            Expanded(
              flex: 1,
              child: buildHoverCard(
                child: EnhancedControlPanelWidget(
                  isRecording: _isRecording,
                  onRecordingToggle: _toggleRecording,
                  onSettingsChanged: (settings) {
                    // 설정 변경 처리
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 오른쪽 패널 - 가이드 & 코칭
  Widget _buildRightPanel(visualGuideState) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.3, 0),
        end: Offset.zero,
      ).animate(_cardSlideAnimation),
      child: FadeTransition(
        opacity: _cardFadeAnimation,
        child: Column(
          children: [
            // 모드 토글
            _buildEnhancedModeToggle(),
            
            SizedBox(height: EnhancedAppTheme.getSpacing(context, 16)),
            
            // 메인 콘텐츠
            Expanded(
              child: AnimatedSwitcher(
                duration: EnhancedAppTheme.defaultDuration,
                transitionBuilder: (child, animation) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.3, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: _showPracticeMode 
                    ? _buildPracticeModePanel()
                    : _buildAnalysisModePanel(visualGuideState),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedModeToggle() {
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
                onTap: () => _setMode(false),
              ),
              _buildModeToggleButton(
                label: '연습 모드',
                icon: ThemeIcons.music,
                isSelected: _showPracticeMode,
                onTap: () => _setMode(true),
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
                color: EnhancedAppTheme.accentBlue.withOpacity(0.3),
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

  Widget _buildAnalysisModePanel(visualGuideState) {
    return Column(
      key: const ValueKey('analysis_mode'),
      children: [
        // 향상된 시각 가이드
        Expanded(
          flex: 2,
          child: buildHoverCard(
            child: EnhancedVisualGuideWidget(
              visualGuideState: visualGuideState,
              isRecording: _isRecording,
            ),
          ),
        ),
        
        SizedBox(height: EnhancedAppTheme.getSpacing(context, 16)),
        
        // 향상된 코칭 패널
        Expanded(
          flex: 2,
          child: buildHoverCard(
            child: const EnhancedCoachingPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeModePanel() {
    return Consumer(
      key: const ValueKey('practice_mode'),
      builder: (context, ref, child) {
        final realTimeState = ref.watch(realTimeAnalysisProvider);
        final currentAnalysis = realTimeState.currentAnalysis;
        
        return VocalPracticeModeWidget(
          isActive: _isRecording,
          currentAnalysis: currentAnalysis,
          onModeChanged: (mode) {
            setState(() {
              _selectedMode = mode;
            });
          },
          onDifficultyChanged: (difficulty) {
            setState(() {
              _selectedDifficulty = difficulty;
            });
          },
        );
      },
    );
  }

  // 헬퍼 메서드들
  void _toggleRecording(bool recording) {
    setState(() {
      _isRecording = recording;
    });
    
    if (recording) {
      ref.read(realTimeAnalysisProvider.notifier).startAnalysis();
      _pulseController.repeat(reverse: true);
    } else {
      ref.read(realTimeAnalysisProvider.notifier).stopAnalysis();
      _pulseController.stop();
    }
  }

  void _setMode(bool practiceMode) {
    setState(() {
      _showPracticeMode = practiceMode;
    });
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return EnhancedAppTheme.neonGreen;
    if (score >= 80) return EnhancedAppTheme.neonBlue;
    if (score >= 70) return EnhancedAppTheme.neonOrange;
    if (score >= 60) return EnhancedAppTheme.neonPink;
    return EnhancedAppTheme.neonRed;
  }
}

// Provider 정의들 (예시)
final emotionProvider = StateProvider<String>((ref) => 'Calm');
final styleProvider = StateProvider<String>((ref) => 'Classical');
final currentNoteProvider = StateProvider<String>((ref) => 'A4');
final voiceQualityProvider = StateProvider<double>((ref) => 0.85);
final pitchAccuracyProvider = StateProvider<double>((ref) => 92.0);