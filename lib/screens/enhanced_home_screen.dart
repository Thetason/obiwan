import 'package:flutter/material.dart';  
import 'dart:math' as math;
import '../widgets/glassmorphism_card.dart';
import '../widgets/premium_button.dart';
import '../services/dual_engine_service.dart';
import 'fixed_vocal_training_screen.dart';

class EnhancedHomeScreen extends StatefulWidget {
  const EnhancedHomeScreen({super.key});

  @override
  State<EnhancedHomeScreen> createState() => _EnhancedHomeScreenState();
}

class _EnhancedHomeScreenState extends State<EnhancedHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _logoController;
  late AnimationController _backgroundController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _logoAnimation;
  late Animation<double> _backgroundAnimation;
  
  EngineStatus? _engineStatus;
  bool _isCheckingStatus = true;
  
  // 색상 테마
  final Color _primaryColor = const Color(0xFF6366F1);
  final Color _secondaryColor = const Color(0xFF8B5CF6);
  final Color _accentColor = const Color(0xFF10B981);
  final Color _errorColor = const Color(0xFFEF4444);
  final Color _warningColor = const Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));
    
    _logoAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.linear),
    );
    
    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    );
    
    _checkEngineStatus();
    _startAnimations();
  }

  void _startAnimations() {
    _fadeController.forward();
    _backgroundController.repeat(reverse: true);
    _logoController.repeat();
    
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
  }

  Future<void> _checkEngineStatus() async {
    final service = DualEngineService();
    final status = await service.checkStatus();
    
    setState(() {
      _engineStatus = status;
      _isCheckingStatus = false;
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _logoController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F0F23),
              const Color(0xFF1A1B23),
              const Color(0xFF0F1419),
              _primaryColor.withOpacity(0.1),
            ],
          ),
        ),
        child: Stack(
          children: [
            // 배경 애니메이션 효과
            AnimatedBuilder(
              animation: _backgroundAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: BackgroundEffectPainter(
                    animation: _backgroundAnimation.value,
                    primaryColor: _primaryColor,
                    secondaryColor: _secondaryColor,
                  ),
                );
              },
            ),
            
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEnhancedHeader(),
                        const SizedBox(height: 40),
                        _buildEngineStatusCard(),
                        const SizedBox(height: 32),
                        _buildFeaturesSection(),
                        const SizedBox(height: 32),
                        _buildPerformanceMetrics(),
                        const SizedBox(height: 40),
                        _buildActionSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedHeader() {
    return GlassmorphismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 로고 애니메이션
              AnimatedBuilder(
                animation: _logoAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _logoAnimation.value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryColor, _secondaryColor],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.multitrack_audio,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오비완 v2',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: _primaryColor.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dual AI Vocal Trainer',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withOpacity(0.1),
                  _secondaryColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _primaryColor.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: _accentColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '세계 최초 듀얼 AI 엔진',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'CREPE + SPICE 듀얼 엔진으로 0.6 cents 정확도의 피치 분석과 실시간 화음 감지를 동시에 경험하세요',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineStatusCard() {
    if (_isCheckingStatus) {
      return GlassmorphismCard(
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              '엔진 상태 확인 중...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final isHealthy = _engineStatus?.bothHealthy ?? false;
    final isPartial = _engineStatus?.anyHealthy ?? false;
    final statusColor = isHealthy 
      ? _accentColor 
      : isPartial 
        ? _warningColor 
        : _errorColor;

    return AnimatedGlassCard(
      isSelected: isHealthy,
      primaryColor: statusColor,
      secondaryColor: statusColor.withOpacity(0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [statusColor, statusColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isHealthy 
                    ? Icons.check_circle 
                    : isPartial 
                      ? Icons.warning 
                      : Icons.error,
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
                      _engineStatus?.statusText ?? '서버 연결 실패',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusDescription(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildEngineIndicator(
                  'CREPE',
                  '단일 피치 분석',
                  _engineStatus?.crepeHealthy ?? false,
                  Icons.analytics,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildEngineIndicator(
                  'SPICE',
                  '다중 피치 감지',
                  _engineStatus?.spiceHealthy ?? false,
                  Icons.queue_music,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStatusDescription() {
    if (_engineStatus == null) return '서버에 연결할 수 없습니다';
    if (_engineStatus!.bothHealthy) return '모든 엔진이 정상 작동 중입니다';
    if (_engineStatus!.anyHealthy) return '일부 엔진만 작동 중입니다';
    return '모든 엔진이 오프라인 상태입니다';
  }

  Widget _buildEngineIndicator(String name, String description, bool isHealthy, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHealthy 
            ? _accentColor.withOpacity(0.3)
            : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isHealthy ? _accentColor : Colors.white.withOpacity(0.5),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isHealthy ? Colors.white : Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isHealthy ? _accentColor : _errorColor,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: (isHealthy ? _accentColor : _errorColor).withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '핵심 기능',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.1,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildFeatureCard(
              icon: Icons.multitrack_audio,
              title: '듀얼 AI 엔진',
              subtitle: 'CREPE + SPICE',
              description: '두 개의 AI 엔진이 동시에 분석',
              colors: [_primaryColor, _secondaryColor],
            ),
            _buildFeatureCard(
              icon: Icons.precision_manufacturing,
              title: '초정밀 분석',
              subtitle: '0.6 cents 정확도',
              description: '세계 최고 수준의 피치 정확도',
              colors: [_accentColor, const Color(0xFF059669)],
            ),
            _buildFeatureCard(
              icon: Icons.speed,
              title: '실시간 처리',
              subtitle: '<100ms 지연',
              description: '즉시 반응하는 실시간 분석',
              colors: [_warningColor, const Color(0xFFD97706)],
            ),
            _buildFeatureCard(
              icon: Icons.auto_awesome,
              title: '스마트 선택',
              subtitle: '자동 엔진 전환',
              description: '상황에 맞는 최적 엔진 선택',
              colors: [const Color(0xFFEC4899), const Color(0xFFBE185D)],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required List<Color> colors,
  }) {
    return AnimatedGlassCard(
      primaryColor: colors[0],
      secondaryColor: colors[1],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: colors[0],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return GlassmorphismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: _accentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                '성능 지표',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  '피치 정확도',
                  '0.6',
                  'cents',
                  Icons.gps_fixed,
                  _accentColor,
                  0.95,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  '응답 속도',
                  '<100',
                  'ms',
                  Icons.flash_on,
                  _warningColor,
                  0.88,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  '안정성',
                  '99.2',
                  '%',
                  Icons.shield,
                  _primaryColor,
                  0.92,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, String unit, IconData icon, Color color, double progress) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.white.withOpacity(0.1),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionSection() {
    final canStart = _engineStatus?.anyHealthy ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumButton(
          text: '보컬 트레이닝 시작',
          icon: Icons.mic,
          height: 72,
          primaryColor: _primaryColor,
          secondaryColor: _secondaryColor,
          isEnabled: canStart,
          onPressed: canStart ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FixedVocalTrainingScreen(),
              ),
            );
          } : null,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: PremiumButton(
                text: '서버 새로고침',
                icon: Icons.refresh,
                height: 56,
                primaryColor: Colors.white.withOpacity(0.1),
                secondaryColor: Colors.white.withOpacity(0.05),
                onPressed: () {
                  setState(() {
                    _isCheckingStatus = true;
                  });
                  _checkEngineStatus();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PremiumButton(
                text: '고급 설정',
                icon: Icons.tune,
                height: 56,
                primaryColor: _secondaryColor,
                secondaryColor: _primaryColor,
                onPressed: () {
                  // TODO: 고급 설정 화면
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class BackgroundEffectPainter extends CustomPainter {
  final double animation;
  final Color primaryColor;
  final Color secondaryColor;

  BackgroundEffectPainter({
    required this.animation,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // 배경 그라데이션 원들
    for (int i = 0; i < 3; i++) {
      final radius = 150 + (i * 50) + (animation * 30);
      final opacity = 0.05 + (animation * 0.03);
      
      paint.shader = RadialGradient(
        colors: [
          primaryColor.withOpacity(opacity),
          secondaryColor.withOpacity(opacity * 0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(
          size.width * (0.2 + i * 0.3),
          size.height * (0.3 + animation * 0.4),
        ),
        radius: radius,
      ));

      canvas.drawCircle(
        Offset(
          size.width * (0.2 + i * 0.3),
          size.height * (0.3 + animation * 0.4),
        ),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}