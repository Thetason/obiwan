import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../domain/entities/vocal_analysis.dart';
import '../../features/ai_coaching/smart_feedback_engine.dart';
import '../../core/theme/enhanced_app_theme.dart';

/// 향상된 AI 코칭 패널
/// 스마트 피드백과 개인화된 가이드를 제공
class EnhancedCoachingPanel extends ConsumerStatefulWidget {
  const EnhancedCoachingPanel({super.key});

  @override
  ConsumerState<EnhancedCoachingPanel> createState() => _EnhancedCoachingPanelState();
}

class _EnhancedCoachingPanelState extends ConsumerState<EnhancedCoachingPanel>
    with TickerProviderStateMixin, CustomWidgetStyles {
  late AnimationController _feedbackController;
  late AnimationController _avatarController;
  late AnimationController _cardController;
  
  late Animation<double> _feedbackSlide;
  late Animation<double> _avatarPulse;
  late Animation<double> _cardFloat;
  
  final SmartFeedbackEngine _feedbackEngine = SmartFeedbackEngine();
  SmartFeedback? _currentFeedback;
  List<String> _recentTips = [];
  double _userProgress = 0.75;
  String _coachMood = 'encouraging';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateSampleFeedback();
  }

  void _initializeAnimations() {
    // 피드백 슬라이드 애니메이션
    _feedbackController = AnimationController(
      duration: EnhancedAppTheme.slowDuration,
      vsync: this,
    );
    
    _feedbackSlide = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _feedbackController, curve: Curves.easeOutCubic),
    );
    
    // 아바타 펄스 애니메이션
    _avatarController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _avatarPulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _avatarController, curve: Curves.easeInOut),
    );
    
    // 카드 플로팅 애니메이션
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    
    _cardFloat = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeInOut),
    );
  }

  void _generateSampleFeedback() {
    // 샘플 분석 데이터
    final sampleAnalysis = VocalAnalysis(
      timestamp: DateTime.now(),
      fundamentalFreq: [440.0],
      pitchStability: 0.85,
      breathingType: BreathingType.mixed,
      resonancePosition: ResonancePosition.mixed,
      vibratoQuality: VibratoQuality.light,
      mouthOpening: MouthOpening.medium,
      spectralTilt: 0.05,
      overallScore: 78,
    );

    setState(() {
      _currentFeedback = _feedbackEngine.generateSmartFeedback(sampleAnalysis);
      _recentTips = [
        '복식호흡을 조금 더 의식해보세요',
        '음정 안정성이 향상되고 있어요!',
        '목에 힘을 빼고 편안하게 발성하세요',
      ];
    });

    _feedbackController.forward();
    
    // 주기적으로 새 피드백 생성
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        _generateSampleFeedback();
      }
    });
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _avatarController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            EnhancedAppTheme.secondaryDark,
            EnhancedAppTheme.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: EnhancedAppTheme.accentBlue.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // 배경 파티클 효과
            _buildBackgroundParticles(),
            
            // 메인 콘텐츠
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  Expanded(child: _buildCoachingContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundParticles() {
    return AnimatedBuilder(
      animation: _cardFloat,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticleEffectPainter(
            animationValue: _cardFloat.value,
            feedbackPriority: _currentFeedback?.priority ?? FeedbackPriority.medium,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _buildAIAvatar(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildGradientText(
                text: 'AI 보컬 코치',
                gradient: EnhancedAppTheme.primaryGradient,
                style: EnhancedAppTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getCoachStatusText(),
                style: EnhancedAppTheme.bodyMedium.copyWith(
                  color: EnhancedAppTheme.accentLight,
                ),
              ),
            ],
          ),
        ),
        _buildProgressIndicator(),
      ],
    );
  }

  Widget _buildAIAvatar() {
    return AnimatedBuilder(
      animation: _avatarPulse,
      builder: (context, child) {
        return Transform.scale(
          scale: _avatarPulse.value,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: _getCoachGradient(),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getCoachColor().withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.psychology,
              color: Colors.white,
              size: 28,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 배경 원
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 3,
              ),
            ),
          ),
          // 진행도 원
          TweenAnimationBuilder(
            duration: EnhancedAppTheme.slowDuration,
            tween: Tween<double>(begin: 0, end: _userProgress),
            builder: (context, value, child) {
              return CustomPaint(
                size: const Size(60, 60),
                painter: ProgressCirclePainter(
                  progress: value,
                  color: EnhancedAppTheme.neonGreen,
                ),
              );
            },
          ),
          // 중앙 텍스트
          Text(
            '${(_userProgress * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachingContent() {
    return Column(
      children: [
        // 메인 피드백 카드
        Expanded(
          flex: 2,
          child: _buildMainFeedbackCard(),
        ),
        
        const SizedBox(height: 16),
        
        // 팁 카드들
        Expanded(
          flex: 1,
          child: _buildTipsSection(),
        ),
      ],
    );
  }

  Widget _buildMainFeedbackCard() {
    if (_currentFeedback == null) {
      return _buildLoadingCard();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_feedbackSlide, _cardFloat]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _cardFloat.value),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(_feedbackSlide),
            child: FadeTransition(
              opacity: _feedbackSlide,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: _getFeedbackGradient(_currentFeedback!.priority),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getPriorityColor(_currentFeedback!.priority).withOpacity(0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getPriorityColor(_currentFeedback!.priority).withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFeedbackHeader(),
                      const SizedBox(height: 12),
                      _buildFeedbackMessage(),
                      const SizedBox(height: 16),
                      _buildFeedbackTips(),
                      const Spacer(),
                      _buildFeedbackFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedbackHeader() {
    return Row(
      children: [
        Icon(
          _getPriorityIcon(_currentFeedback!.priority),
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          _getPriorityLabel(_currentFeedback!.priority),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${(_currentFeedback!.confidence * 100).toInt()}% 신뢰도',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackMessage() {
    return Text(
      _currentFeedback!.mainMessage,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    );
  }

  Widget _buildFeedbackTips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _currentFeedback!.specificTips.take(2).map((tip) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tip,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeedbackFooter() {
    return Row(
      children: [
        Icon(
          Icons.psychology,
          color: Colors.white.withOpacity(0.7),
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _currentFeedback!.encouragement,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.tips_and_updates,
              color: EnhancedAppTheme.neonOrange,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              '빠른 팁',
              style: EnhancedAppTheme.bodyMedium.copyWith(
                color: EnhancedAppTheme.highlight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: _recentTips.length,
            itemBuilder: (context, index) => _buildTipCard(index),
          ),
        ),
      ],
    );
  }

  Widget _buildTipCard(int index) {
    return AnimatedBuilder(
      animation: _cardFloat,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _cardFloat.value * (index + 1) * 0.5),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: EnhancedAppTheme.neonOrange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _recentTips[index],
                    style: EnhancedAppTheme.bodyMedium.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return buildHoverCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(EnhancedAppTheme.neonBlue),
          ),
          const SizedBox(height: 16),
          Text(
            'AI가 분석 중입니다...',
            style: EnhancedAppTheme.bodyMedium.copyWith(
              color: EnhancedAppTheme.accentLight,
            ),
          ),
        ],
      ),
    );
  }

  // 헬퍼 메서드들
  String _getCoachStatusText() {
    switch (_coachMood) {
      case 'encouraging':
        return '격려하는 중 💪';
      case 'analytical':
        return '분석하는 중 🔍';
      case 'celebrating':
        return '축하하는 중 🎉';
      default:
        return '도움을 주는 중 ✨';
    }
  }

  Color _getCoachColor() {
    switch (_coachMood) {
      case 'encouraging':
        return EnhancedAppTheme.neonGreen;
      case 'analytical':
        return EnhancedAppTheme.neonBlue;
      case 'celebrating':
        return EnhancedAppTheme.neonPink;
      default:
        return EnhancedAppTheme.neonOrange;
    }
  }

  Gradient _getCoachGradient() {
    switch (_coachMood) {
      case 'encouraging':
        return EnhancedAppTheme.successGradient;
      case 'analytical':
        return EnhancedAppTheme.primaryGradient;
      case 'celebrating':
        return const LinearGradient(
          colors: [EnhancedAppTheme.neonPink, EnhancedAppTheme.neonOrange],
        );
      default:
        return EnhancedAppTheme.accentGradient;
    }
  }

  Color _getPriorityColor(FeedbackPriority priority) {
    switch (priority) {
      case FeedbackPriority.critical:
        return EnhancedAppTheme.neonRed;
      case FeedbackPriority.high:
        return EnhancedAppTheme.neonOrange;
      case FeedbackPriority.medium:
        return EnhancedAppTheme.neonBlue;
      case FeedbackPriority.low:
        return EnhancedAppTheme.accentLight;
      case FeedbackPriority.celebration:
        return EnhancedAppTheme.neonGreen;
    }
  }

  Gradient _getFeedbackGradient(FeedbackPriority priority) {
    switch (priority) {
      case FeedbackPriority.critical:
        return EnhancedAppTheme.errorGradient;
      case FeedbackPriority.high:
        return EnhancedAppTheme.warningGradient;
      case FeedbackPriority.medium:
        return EnhancedAppTheme.primaryGradient;
      case FeedbackPriority.low:
        return LinearGradient(
          colors: [
            EnhancedAppTheme.accentLight.withOpacity(0.3),
            EnhancedAppTheme.accentLight.withOpacity(0.1),
          ],
        );
      case FeedbackPriority.celebration:
        return EnhancedAppTheme.successGradient;
    }
  }

  IconData _getPriorityIcon(FeedbackPriority priority) {
    switch (priority) {
      case FeedbackPriority.critical:
        return Icons.warning;
      case FeedbackPriority.high:
        return Icons.priority_high;
      case FeedbackPriority.medium:
        return Icons.info;
      case FeedbackPriority.low:
        return Icons.lightbulb_outline;
      case FeedbackPriority.celebration:
        return Icons.celebration;
    }
  }

  String _getPriorityLabel(FeedbackPriority priority) {
    switch (priority) {
      case FeedbackPriority.critical:
        return '중요 알림';
      case FeedbackPriority.high:
        return '개선 제안';
      case FeedbackPriority.medium:
        return 'AI 분석';
      case FeedbackPriority.low:
        return '참고 사항';
      case FeedbackPriority.celebration:
        return '축하합니다!';
    }
  }
}

/// 진행도 원 페인터
class ProgressCirclePainter extends CustomPainter {
  final double progress;
  final Color color;

  ProgressCirclePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 3) / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 파티클 효과 페인터
class ParticleEffectPainter extends CustomPainter {
  final double animationValue;
  final FeedbackPriority feedbackPriority;

  ParticleEffectPainter({
    required this.animationValue,
    required this.feedbackPriority,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    Color baseColor;
    switch (feedbackPriority) {
      case FeedbackPriority.celebration:
        baseColor = EnhancedAppTheme.neonGreen;
        break;
      case FeedbackPriority.critical:
        baseColor = EnhancedAppTheme.neonRed;
        break;
      default:
        baseColor = EnhancedAppTheme.neonBlue;
    }

    const particleCount = 15;
    
    for (int i = 0; i < particleCount; i++) {
      final x = (size.width * (i / particleCount + animationValue * 0.05)) % size.width;
      final y = size.height * (0.2 + 0.6 * math.sin(i + animationValue));
      final opacity = (math.sin(i + animationValue * 2) + 1) / 2;
      
      paint.color = baseColor.withOpacity(opacity * 0.2);
      
      canvas.drawCircle(
        Offset(x, y),
        1 + opacity * 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}