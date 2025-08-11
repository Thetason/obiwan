import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../widgets/instant_analysis_modal.dart';

class ShazamHomeScreen extends StatefulWidget {
  const ShazamHomeScreen({Key? key}) : super(key: key);

  @override
  State<ShazamHomeScreen> createState() => _ShazamHomeScreenState();
}

class _ShazamHomeScreenState extends State<ShazamHomeScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _rippleController;
  late AnimationController _ripple2Controller;
  late AnimationController _pulseController;
  late AnimationController _floatingController;
  
  late Animation<double> _rippleAnimation;
  late Animation<double> _ripple2Animation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _floatingAnimation;
  
  bool _showAnalysis = false;
  
  // Mock stats
  final Map<String, dynamic> todayStats = {
    'streak': 5,
    'accuracy': 85,
    'practiceTime': 12,
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Ripple animations for Shazam-style button
    _rippleController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _ripple2Controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    
    _rippleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
    
    _ripple2Animation = Tween<double>(
      begin: 1.0,
      end: 1.4,
    ).animate(CurvedAnimation(
      parent: _ripple2Controller,
      curve: Curves.easeOut,
    ));
    
    // Pulse animation for button
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Floating background elements
    _floatingController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    
    _floatingAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(30, -20),
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _rippleController.repeat();
    _ripple2Controller.repeat();
    _pulseController.repeat(reverse: true);
    _floatingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _ripple2Controller.dispose();
    _pulseController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  void _startInstantAnalysis() {
    HapticFeedback.mediumImpact();
    setState(() {
      _showAnalysis = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Animated background elements
          _buildAnimatedBackground(),
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top stats bar
                _buildTopStatsBar(),
                
                // Main Shazam button area
                Flexible(
                  flex: 3,
                  child: _buildMainAnalysisArea(),
                ),
                
                // Quick actions
                _buildQuickActions(),
              ],
            ),
          ),
          
          // Instant Analysis Modal
          if (_showAnalysis)
            InstantAnalysisModal(
              isOpen: _showAnalysis,
              onClose: () => setState(() => _showAnalysis = false),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF1F5F9),
                  Color(0xFFE2E8F0),
                  Color(0xFFF8FAFC),
                ],
              ),
            ),
          ),
          
          // Floating elements
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Positioned(
                top: 100 + _floatingAnimation.value.dy,
                left: 50 + _floatingAnimation.value.dx,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF3B82F6).withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Positioned(
                bottom: 200 - _floatingAnimation.value.dy,
                right: 30 + _floatingAnimation.value.dx,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF8B5CF6).withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatsBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(todayStats['streak'].toString(), '일 연속', const Color(0xFFF59E0B)),
          Column(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ).createShader(bounds),
                child: const Text(
                  'Obi-wan',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Text(
                'AI 보컬 분석',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          _buildStatItem('${todayStats['accuracy']}%', '평균 정확도', const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildMainAnalysisArea() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Shazam-style button with ripples
          SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ripple
                AnimatedBuilder(
                  animation: _rippleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _rippleAnimation.value,
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF3B82F6).withOpacity(
                              1.0 - (_rippleAnimation.value - 1.0) * 3.33
                            ),
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                // Second ripple
                AnimatedBuilder(
                  animation: _ripple2Animation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _ripple2Animation.value,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withOpacity(
                              1.0 - (_ripple2Animation.value - 1.0) * 2.5
                            ),
                            width: 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                // Main button
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: GestureDetector(
                        onTap: _startInstantAnalysis,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF3B82F6),
                                Color(0xFF8B5CF6),
                                Color(0xFF6366F1),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withOpacity(0.4),
                                blurRadius: 30,
                                spreadRadius: 5,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Stack(
                            alignment: Alignment.center,
                            children: [
                              // Inner glow
                              Positioned.fill(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Color(0x40FFFFFF),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Icon and text
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.bolt,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '즉시 분석',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Call to action text
          Column(
            children: [
              const Text(
                '즉시 AI 보컬 분석',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '샤잠처럼 빠른 실시간 분석',
                style: TextStyle(
                  fontSize: 13,
                  color: const Color(0xFF64748B).withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          const Text(
            '분석 모드 선택',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '즉시 분석 또는 상세 분석을 선택하세요',
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF64748B).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  '상세 분석',
                  '3단계 완전 분석',
                  Icons.analytics,
                  const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  () => Navigator.pushNamed(context, '/wave_start'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  '내 진도',
                  '실력 향상 확인',
                  Icons.trending_up,
                  const [Color(0xFF3B82F6), Color(0xFF6366F1)],
                  () => Navigator.pushNamed(context, '/training'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String description,
    IconData icon,
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
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
                  colors: gradientColors,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}