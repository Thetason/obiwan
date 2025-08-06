import 'package:flutter/material.dart';
import '../widgets/modern_card.dart';
import '../widgets/modern_button.dart';
import '../services/dual_engine_service.dart';
import 'vocal_training_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  EngineStatus? _engineStatus;
  bool _isCheckingStatus = true;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    
    _checkEngineStatus();
    _startAnimations();
  }

  void _startAnimations() {
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F23), // Deep purple dark
              Color(0xFF1A1B23), // Darker
              Color(0xFF0F1419), // Almost black
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildEngineStatus(),
                    const SizedBox(height: 32),
                    _buildMainFeatures(),
                    const SizedBox(height: 24),
                    _buildQuickStats(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                  ],
                ),
              ),
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
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.multitrack_audio,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오비완 v2',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Dual AI Vocal Trainer',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          '세계 최초 CREPE + SPICE 듀얼 엔진으로\n정확한 피치 분석과 화음 감지를 경험하세요',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEngineStatus() {
    if (_isCheckingStatus) {
      return ModernCard(
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            const Text(
              '엔진 상태 확인 중...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      );
    }

    if (_engineStatus == null) {
      return StatusCard(
        status: CardStatus.error,
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
            const SizedBox(width: 12),
            const Text(
              '서버 연결 실패',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      );
    }

    return StatusCard(
      status: _engineStatus!.bothHealthy 
          ? CardStatus.success 
          : _engineStatus!.anyHealthy 
              ? CardStatus.warning 
              : CardStatus.error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _engineStatus!.bothHealthy 
                    ? Icons.check_circle 
                    : _engineStatus!.anyHealthy 
                        ? Icons.warning 
                        : Icons.error,
                color: _engineStatus!.bothHealthy 
                    ? const Color(0xFF10B981)
                    : _engineStatus!.anyHealthy 
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 12),
              Text(
                _engineStatus!.statusText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildEngineIndicator('CREPE', _engineStatus!.crepeHealthy),
              const SizedBox(width: 16),
              _buildEngineIndicator('SPICE', _engineStatus!.spiceHealthy),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEngineIndicator(String name, bool isHealthy) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isHealthy ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          name,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _buildMainFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '주요 기능',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildFeatureCard(
              icon: Icons.multitrack_audio,
              title: '듀얼 엔진',
              subtitle: 'CREPE + SPICE',
              gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            _buildFeatureCard(
              icon: Icons.graphic_eq,
              title: '실시간 분석',
              subtitle: '0.6 cents 정확도',
              gradient: const [Color(0xFF10B981), Color(0xFF059669)],
            ),
            _buildFeatureCard(
              icon: Icons.queue_music,
              title: '화음 감지',
              subtitle: '다중 피치 분석',
              gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
            ),
            _buildFeatureCard(
              icon: Icons.auto_awesome,
              title: '스마트 선택',
              subtitle: '자동 엔진 선택',
              gradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
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
    required List<Color> gradient,
  }) {
    return HeroCard(
      gradientColors: gradient,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 12),
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
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '성능 지표',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('정확도', '0.6 cents', Icons.precision_manufacturing),
              _buildStatItem('지연시간', '<100ms', Icons.speed),
              _buildStatItem('신뢰도', '92%', Icons.verified),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF6366F1), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final canStart = _engineStatus?.anyHealthy ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModernButton(
          text: '보컬 트레이닝 시작',
          icon: Icons.mic,
          size: ButtonSize.large,
          variant: ButtonVariant.primary,
          width: double.infinity,
          onPressed: canStart ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const VocalTrainingScreen(),
              ),
            );
          } : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ModernButton(
                text: '서버 새로고침',
                icon: Icons.refresh,
                variant: ButtonVariant.outline,
                onPressed: () {
                  setState(() {
                    _isCheckingStatus = true;
                  });
                  _checkEngineStatus();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ModernButton(
                text: '설정',
                icon: Icons.settings,
                variant: ButtonVariant.secondary,
                onPressed: () {
                  // TODO: 설정 화면
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}