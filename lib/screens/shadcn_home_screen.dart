import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design_system/tokens.dart';
import '../design_system/components/ui_button.dart';
import '../design_system/components/ui_card.dart';
import '../design_system/components/waveform_widget.dart';
import '../widgets/shadcn_recording_modal.dart';
import '../services/native_audio_service.dart';
import 'realtime_pitch_tracker_v2.dart';

/// Shadcn UI 디자인 철학을 적용한 새로운 홈 화면
/// 
/// 샤잠처럼 즉시 분석 가능한 UX와 미니멀한 디자인 결합
/// - 중앙의 큰 녹음 버튼 (Shazam 스타일)
/// - 깔끔한 카드 레이아웃
/// - 서브틀한 애니메이션
class ShadcnHomeScreen extends StatefulWidget {
  const ShadcnHomeScreen({super.key});

  @override
  State<ShadcnHomeScreen> createState() => _ShadcnHomeScreenState();
}

class _ShadcnHomeScreenState extends State<ShadcnHomeScreen>
    with TickerProviderStateMixin {
  
  final NativeAudioService _audioService = NativeAudioService.instance;
  
  // 상태 관리
  bool _isListening = false;
  double _audioLevel = 0.0;
  List<double> _realtimeWaveform = [];
  
  // 애니메이션
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAudio();
  }
  
  void _initializeAnimations() {
    // 메인 버튼 펄스 애니메이션 (서브틀)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02, // shadcn 스타일: 매우 서브틀한 스케일
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // 웨이브폼 컨트롤러
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.elasticOut,
    ));
  }
  
  void _initializeAudio() async {
    await _audioService.initialize();
    
    _audioService.onAudioLevelChanged = (level) {
      if (mounted && _isListening) {
        setState(() {
          _audioLevel = level;
          _realtimeWaveform.add(level);
          if (_realtimeWaveform.length > 50) {
            _realtimeWaveform.removeAt(0);
          }
        });
      }
    };
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }
  
  // 메인 녹음 시작
  void _startRecording() async {
    // 햅틱 피드백
    HapticFeedback.mediumImpact();
    
    // 스케일 애니메이션
    _waveController.forward().then((_) {
      _waveController.reverse();
    });
    
    // 녹음 모달 표시
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShadcnRecordingModal(
        onClose: () {
          Navigator.pop(context);
        },
      ),
    );
  }
  
  // 실시간 피치 트래커로 이동
  void _navigateToRealtimeTracker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RealtimePitchTrackerV2(),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.background,
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            _buildHeader(),
            
            // 메인 컨텐츠
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space6,
                ),
                child: Column(
                  children: [
                    // 주요 기능 카드들
                    _buildQuickActions(),
                    
                    const SizedBox(height: DesignTokens.space8),
                    
                    // 메인 녹음 버튼 영역
                    Expanded(
                      child: _buildMainRecordingArea(),
                    ),
                    
                    const SizedBox(height: DesignTokens.space6),
                    
                    // 하단 가이드
                    _buildGuideText(),
                    
                    const SizedBox(height: DesignTokens.space6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 로고 영역
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Obi-wan',
                style: DesignTokens.h2.copyWith(
                  color: DesignTokens.foreground,
                ),
              ),
              Text(
                'AI Vocal Assistant',
                style: DesignTokens.bodySmall.copyWith(
                  color: DesignTokens.mutedForeground,
                ),
              ),
            ],
          ),
          
          // 설정 버튼
          UIButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            variant: ButtonVariant.ghost,
            size: ButtonSize.icon,
            onPressed: () {
              // 설정 화면으로 이동
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActions() {
    return Row(
      children: [
        // 실시간 트래커 카드
        Expanded(
          child: UICard(
            variant: CardVariant.outlined,
            onTap: _navigateToRealtimeTracker,
            child: Column(
              children: [
                Icon(
                  Icons.graphic_eq,
                  size: 24,
                  color: DesignTokens.info,
                ),
                const SizedBox(height: DesignTokens.space2),
                Text(
                  'Real-time',
                  style: DesignTokens.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.foreground,
                  ),
                ),
                Text(
                  'Tracker',
                  style: DesignTokens.caption.copyWith(
                    color: DesignTokens.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(width: DesignTokens.space4),
        
        // 연습 세션 카드
        Expanded(
          child: UICard(
            variant: CardVariant.outlined,
            onTap: () {
              // 연습 세션으로 이동
            },
            child: Column(
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 24,
                  color: DesignTokens.success,
                ),
                const SizedBox(height: DesignTokens.space2),
                Text(
                  'Practice',
                  style: DesignTokens.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.foreground,
                  ),
                ),
                Text(
                  'Session',
                  style: DesignTokens.caption.copyWith(
                    color: DesignTokens.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(width: DesignTokens.space4),
        
        // 진행률 카드
        Expanded(
          child: UICard(
            variant: CardVariant.outlined,
            onTap: () {
              // 진행률 화면으로 이동
            },
            child: Column(
              children: [
                Icon(
                  Icons.trending_up_outlined,
                  size: 24,
                  color: DesignTokens.warning,
                ),
                const SizedBox(height: DesignTokens.space2),
                Text(
                  'Progress',
                  style: DesignTokens.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.foreground,
                  ),
                ),
                Text(
                  'Report',
                  style: DesignTokens.caption.copyWith(
                    color: DesignTokens.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildMainRecordingArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 실시간 웨이브폼 (활성 상태일 때만)
        if (_isListening && _realtimeWaveform.isNotEmpty) ...[
          SizedBox(
            height: 60,
            child: WaveformWidget(
              audioData: _realtimeWaveform,
              style: WaveformStyle.bars,
              primaryColor: DesignTokens.info,
              isRecording: _isListening,
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
        ],
        
        // 메인 녹음 버튼 (Shazam 스타일)
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: GestureDetector(
                onTapDown: (_) {
                  _pulseController.forward();
                },
                onTapUp: (_) {
                  _pulseController.reverse();
                  _startRecording();
                },
                onTapCancel: () {
                  _pulseController.reverse();
                },
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        DesignTokens.primary,
                        DesignTokens.primary.withOpacity(0.8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: DesignTokens.primary.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: DesignTokens.space6),
        
        // 버튼 라벨
        Text(
          'Tap to Analyze Voice',
          style: DesignTokens.h4.copyWith(
            color: DesignTokens.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: DesignTokens.space2),
        
        Text(
          'Get instant feedback on your pitch',
          style: DesignTokens.body.copyWith(
            color: DesignTokens.mutedForeground,
          ),
        ),
      ],
    );
  }
  
  Widget _buildGuideText() {
    return UICard(
      variant: CardVariant.default_,
      padding: const EdgeInsets.all(DesignTokens.space4),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 20,
            color: DesignTokens.warning,
          ),
          const SizedBox(width: DesignTokens.space3),
          Expanded(
            child: Text(
              'Powered by CREPE + SPICE dual AI engines for precise pitch analysis',
              style: DesignTokens.bodySmall.copyWith(
                color: DesignTokens.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 홈 화면 특화 통계 위젯
class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return UICard(
      variant: CardVariant.outlined,
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: DesignTokens.space2),
          Text(
            value,
            style: DesignTokens.h4.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: DesignTokens.bodySmall.copyWith(
              color: DesignTokens.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            style: DesignTokens.caption.copyWith(
              color: DesignTokens.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}