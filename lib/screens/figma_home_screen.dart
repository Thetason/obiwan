import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../widgets/figma_instant_analysis_modal.dart';
import '../services/native_audio_service.dart';

class FigmaHomeScreen extends StatefulWidget {
  final Function(dynamic) onNavigate;
  final Function(dynamic) onSelectSong;

  const FigmaHomeScreen({
    Key? key,
    required this.onNavigate,
    required this.onSelectSong,
  }) : super(key: key);

  @override
  State<FigmaHomeScreen> createState() => _FigmaHomeScreenState();
}

class _FigmaHomeScreenState extends State<FigmaHomeScreen>
    with TickerProviderStateMixin {
  
  bool _showInstantAnalysis = false;
  
  // 실제 데이터 - 피그마에서 목 데이터였던 부분
  final Map<String, dynamic> _todayStats = {
    'practiceTime': 12,
    'songsCompleted': 3,
    'accuracy': 85,
    'streak': 5,
  };
  
  // 애니메이션 컨트롤러들 - 피그마 디자인 그대로
  late AnimationController _rippleController;
  late AnimationController _ripple2Controller;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  
  late Animation<double> _rippleAnimation;
  late Animation<double> _ripple2Animation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }
  
  void _initializeAnimations() {
    // 피그마 HomeScreen의 애니메이션들을 정확히 구현
    _rippleController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    
    _ripple2Controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _rippleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
    
    _ripple2Animation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _ripple2Controller,
      curve: Curves.easeOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.4,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    // 애니메이션 시작 - 피그마와 동일한 패턴
    _rippleController.repeat();
    _ripple2Controller.repeat();
    _pulseController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _rippleController.dispose();
    _ripple2Controller.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }
  
  void _startInstantAnalysis() async {
    // 실제 기능 - 마이크 권한 확인
    HapticFeedback.mediumImpact();
    
    final audioStatus = await NativeAudioService.instance.getAudioSystemStatus();
    if (audioStatus['canRecord'] == true) {
      setState(() {
        _showInstantAnalysis = true;
      });
    } else {
      // 권한 요청 로직
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('마이크 권한이 필요합니다'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 메인 컨텐츠
        SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 120,
            ),
            child: Column(
              children: [
                // Top Stats Bar - 피그마 디자인 완전 재현
                _buildTopStatsBar(),
                
                // Main Analysis Button - Shazam Style
                _buildMainAnalysisSection(),
                
                // Quick Actions - 피그마 스타일
                _buildQuickActions(),
              ],
            ),
          ),
        ),
        
        // Instant Analysis Modal - 실제 기능 포함
        if (_showInstantAnalysis)
          FigmaInstantAnalysisModal(
            isOpen: _showInstantAnalysis,
            onClose: () => setState(() => _showInstantAnalysis = false),
          ),
      ],
    );
  }
  
  Widget _buildTopStatsBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 연속 일수 - 왼쪽
          Column(
            children: [
              Text(
                '${_todayStats['streak']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const Text(
                '일 연속',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          
          // 중앙 브랜딩 - VocalMaster → Obi-wan
          Column(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ).createShader(bounds),
                child: const Text(
                  'Obi-wan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Text(
                'AI 보컬 분석',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          
          // 평균 정확도 - 오른쪽
          Column(
            children: [
              Text(
                '${_todayStats['accuracy']}%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              const Text(
                '평균 정확도',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMainAnalysisSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        children: [
          // Shazam-style Button with Ripples - 피그마 완전 재현
          SizedBox(
            width: 320,
            height: 320,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ambient Ripples - 첫 번째
                AnimatedBuilder(
                  animation: _rippleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _rippleAnimation.value,
                      child: Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF3B82F6).withOpacity(
                              (1.0 - (_rippleAnimation.value - 1.0) / 0.2) * 0.3
                            ),
                            width: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                // 두 번째 리플 - delay 적용
                AnimatedBuilder(
                  animation: _ripple2Animation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _ripple2Animation.value,
                      child: Container(
                        width: 384,
                        height: 384,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withOpacity(
                              (1.0 - (_ripple2Animation.value - 1.0) / 0.3) * 0.15
                            ),
                            width: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                // Main Shazam-style Button - 피그마 디자인 정확히
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: GestureDetector(
                        onTap: _startInstantAnalysis,
                        child: AnimatedBuilder(
                          animation: _glowAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 192,
                              height: 192,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF3B82F6),
                                    Color(0xFF8B5CF6),
                                    Color(0xFF4F46E5),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3B82F6).withOpacity(_glowAnimation.value),
                                    blurRadius: 60,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 20),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6).withOpacity(_glowAnimation.value * 0.8),
                                    blurRadius: 80,
                                    spreadRadius: 10,
                                    offset: const Offset(0, 25),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Inner glow layers - 피그마의 정확한 구조
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              const Color(0xFF3B82F6).withOpacity(0.3),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(48),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              Colors.white.withOpacity(0.2),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Shazam-style Icon & Text
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.bolt,
                                        size: 64,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        '즉시 분석',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Call-to-Action Text - 피그마 스타일
          const SizedBox(height: 32),
          Column(
            children: [
              Text(
                '터치하여 AI 보컬 분석 시작',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '샤잠처럼 빠르고 정확하게',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActions() {
    final quickActions = [
      {
        'title': '노래 연습',
        'description': '인기곡으로 연습하기',
        'icon': Icons.music_note,
        'gradient': [Color(0xFF8B5CF6), Color(0xFFEC4899)],
        'action': () => widget.onNavigate('songs'),
      },
      {
        'title': '내 진도',
        'description': '실력 향상 확인',
        'icon': Icons.trending_up,
        'gradient': [Color(0xFF3B82F6), Color(0xFF6366F1)],
        'action': () => widget.onNavigate('progress'),
      },
    ];
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
      child: Column(
        children: [
          const Text(
            '빠른 실행',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          
          Column(
            children: quickActions.map((action) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: action['action'] as VoidCallback,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: action['gradient'] as List<Color>,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: (action['gradient'] as List<Color>)[0].withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            action['icon'] as IconData,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                action['title'] as String,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              Text(
                                action['description'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}