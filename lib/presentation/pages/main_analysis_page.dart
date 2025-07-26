import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/audio_visualization_widget.dart';
import '../widgets/visual_guide_widget.dart';
import '../widgets/coaching_advice_widget.dart';
import '../widgets/control_panel_widget.dart';
import '../widgets/enhanced_pitch_visualization_widget.dart';
import '../widgets/ai_coaching_panel.dart';
import '../widgets/smart_feedback_widget.dart';
import '../widgets/vocal_practice_mode_widget.dart';
import '../providers/audio_analysis_provider.dart';
import '../providers/real_time_analysis_provider.dart';
import '../providers/visual_guide_provider.dart';
import '../../domain/entities/vocal_analysis.dart';
import '../../features/training_modules/structured_vocal_training.dart';
import '../../core/theme/app_theme.dart';

class MainAnalysisPage extends ConsumerStatefulWidget {
  const MainAnalysisPage({super.key});

  @override
  ConsumerState<MainAnalysisPage> createState() => _MainAnalysisPageState();
}

class _MainAnalysisPageState extends ConsumerState<MainAnalysisPage> 
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _showStepByStep = false;
  bool _showPracticeMode = false;
  TrainingMode _selectedMode = TrainingMode.breathing;
  TrainingDifficulty _selectedDifficulty = TrainingDifficulty.beginner;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(audioAnalysisProvider);
    final visualGuideState = ref.watch(visualGuideProvider);
    final realTimeState = ref.watch(realTimeAnalysisProvider);
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar with glassmorphism effect
              _buildCustomAppBar(context),
              
              // Main Content Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Left Column - Enhanced AI Audio Analysis
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            // Enhanced Pitch Visualization with AI
                            Expanded(
                              flex: 3,
                              child: _buildEnhancedPitchVisualization(),
                            ),
                            const SizedBox(height: 16),
                            // Control Panel
                            Expanded(
                              flex: 1,
                              child: _buildControlPanel(),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Right Column - 3D Guide & AI Coaching or Practice Mode
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            // Mode Toggle
                            _buildModeToggle(),
                            const SizedBox(height: 16),
                            // Main Right Panel Content
                            Expanded(
                              child: _showPracticeMode 
                                  ? _buildPracticeModePanel()
                                  : Column(
                                      children: [
                                        // 3D Visual Guide
                                        Expanded(
                                          flex: 2,
                                          child: _build3DGuidePanel(visualGuideState),
                                        ),
                                        const SizedBox(height: 16),
                                        // Smart AI Feedback Panel
                                        Expanded(
                                          flex: 2,
                                          child: _buildSmartFeedbackPanel(),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      height: 80,
      margin: const EdgeInsets.all(16),
      decoration: AppTheme.glassmorphismDecoration,
      child: Row(
        children: [
          const SizedBox(width: 20),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isRecording ? _pulseAnimation.value : 1.0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: _isRecording 
                        ? AppTheme.accentGradient 
                        : AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _isRecording ? [
                      BoxShadow(
                        color: AppTheme.accentColor.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ] : [],
                  ),
                  child: const Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 보컬 트레이너',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final emotion = ref.watch(emotionProvider);
                    final style = ref.watch(styleProvider);
                    final currentNote = ref.watch(currentNoteProvider);
                    
                    String statusText = _isRecording 
                        ? '🎵 분석 중...' 
                        : '실시간 AI 음성 분석 및 코칭';
                    
                    if (_isRecording && currentNote.isNotEmpty) {
                      statusText = '🎵 $currentNote | $emotion | $style';
                    }
                    
                    return Text(
                      statusText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _isRecording ? AppTheme.accentColor : AppTheme.textMuted,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          _buildStatusIndicator(),
          const SizedBox(width: 8),
          Consumer(
            builder: (context, ref, child) {
              final voiceQuality = ref.watch(voiceQualityProvider);
              final pitchAccuracy = ref.watch(pitchAccuracyProvider);
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'AI 점수',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.psychology,
                          color: _getQualityColor(voiceQuality),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${((voiceQuality + pitchAccuracy / 100) / 2 * 100).toStringAsFixed(0)}',
                          style: TextStyle(
                            color: _getQualityColor(voiceQuality),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.settings, color: AppTheme.textSecondary),
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isRecording 
            ? AppTheme.successColor.withOpacity(0.2)
            : AppTheme.textMuted.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isRecording ? AppTheme.successColor : AppTheme.textMuted,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isRecording ? AppTheme.successColor : AppTheme.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isRecording ? 'LIVE' : 'READY',
            style: TextStyle(
              color: _isRecording ? AppTheme.successColor : AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedPitchVisualization() {
    return const EnhancedPitchVisualizationWidget();
  }

  Widget _buildControlPanel() {
    return Container(
      decoration: AppTheme.glassmorphismDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ControlPanelWidget(
          isRecording: _isRecording,
          onRecordingToggle: (recording) {
            setState(() {
              _isRecording = recording;
            });
            if (recording) {
              ref.read(realTimeAnalysisProvider.notifier).startAnalysis();
            } else {
              ref.read(realTimeAnalysisProvider.notifier).stopAnalysis();
            }
          },
          onSettingsChanged: (settings) {
            // Handle settings changes
          },
        ),
      ),
    );
  }

  Widget _build3DGuidePanel(visualGuideState) {
    return Container(
      decoration: AppTheme.glassmorphismDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: VisualGuideWidget(
          visualGuideState: visualGuideState,
          showStepByStep: _showStepByStep,
          onStepByStepToggle: (enabled) {
            setState(() {
              _showStepByStep = enabled;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSmartFeedbackPanel() {
    return Consumer(
      builder: (context, ref, child) {
        final feedback = ref.watch(currentFeedbackProvider);
        final isAnalyzing = ref.watch(isAnalyzingProvider);
        
        return Container(
          decoration: AppTheme.glassmorphismDecoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SmartFeedbackWidget(
              feedback: feedback,
              isActive: isAnalyzing,
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildAICoachingPanel() {
    return const AICoachingPanel();
  }
  
  Widget _buildCoachingPanel(audioState) {
    return Container(
      decoration: AppTheme.glassmorphismDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CoachingAdviceWidget(
          analysisResults: audioState.analysisResults,
          isRealTime: _isRecording,
        ),
      ),
    );
  }
  
  Widget _buildModeToggle() {
    return Container(
      decoration: AppTheme.glassmorphismDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showPracticeMode = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: !_showPracticeMode ? AppTheme.primaryGradient : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '실시간 분석',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: !_showPracticeMode ? Colors.white : AppTheme.textSecondary,
                        fontWeight: !_showPracticeMode ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showPracticeMode = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: _showPracticeMode ? AppTheme.accentGradient : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '연습 모드',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _showPracticeMode ? Colors.white : AppTheme.textSecondary,
                        fontWeight: _showPracticeMode ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPracticeModePanel() {
    return Consumer(
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

  Color _getQualityColor(double quality) {
    if (quality >= 0.8) return AppTheme.successColor;
    if (quality >= 0.6) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}