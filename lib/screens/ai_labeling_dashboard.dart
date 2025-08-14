import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/vocal_label.dart';
import '../services/ai_labeling_service.dart';

/// AI-Human Hybrid Labeling Dashboard
/// AI 초벌 + 인간 시어링 하이브리드 시스템 UI
class AILabelingDashboard extends StatefulWidget {
  const AILabelingDashboard({Key? key}) : super(key: key);

  @override
  State<AILabelingDashboard> createState() => _AILabelingDashboardState();
}

class _AILabelingDashboardState extends State<AILabelingDashboard>
    with TickerProviderStateMixin {
  // Services
  final AILabelingService _aiService = AILabelingService();
  
  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  
  // State
  bool _isProcessing = false;
  int _currentBatch = 0;
  int _totalBatches = 0;
  int _processedCount = 0;
  int _totalCount = 0;
  
  // Statistics
  int _highConfidence = 0;
  int _mediumConfidence = 0;
  int _lowConfidence = 0;
  
  // Labels
  List<VocalLabel> _pendingLabels = [];
  List<VocalLabel> _reviewQueue = [];
  List<VocalLabel> _completedLabels = [];
  
  // Current Review Item
  VocalLabel? _currentReviewItem;
  int _currentReviewIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadPendingYouTubeList();
  }
  
  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
  }
  
  void _loadPendingYouTubeList() {
    // 테스트용 YouTube 리스트
    setState(() {
      _totalCount = 100;
      _totalBatches = 10;
    });
  }
  
  void _startAILabeling() async {
    setState(() {
      _isProcessing = true;
      _processedCount = 0;
      _highConfidence = 0;
      _mediumConfidence = 0;
      _lowConfidence = 0;
    });
    
    // AI 초벌 라벨링 시뮬레이션
    for (int batch = 1; batch <= _totalBatches; batch++) {
      setState(() {
        _currentBatch = batch;
      });
      
      // 배치 처리 시뮬레이션
      await Future.delayed(const Duration(seconds: 2));
      
      // 통계 업데이트
      setState(() {
        _processedCount = batch * 10;
        _highConfidence = (_processedCount * 0.15).round();
        _mediumConfidence = (_processedCount * 0.60).round();
        _lowConfidence = (_processedCount * 0.25).round();
        
        // 진행률 애니메이션
        _progressAnimation = Tween<double>(
          begin: _progressAnimation.value,
          end: _processedCount / _totalCount,
        ).animate(_progressController);
        _progressController.forward(from: 0);
      });
    }
    
    // 완료 후 검토 큐 생성
    _generateReviewQueue();
    
    setState(() {
      _isProcessing = false;
    });
  }
  
  void _generateReviewQueue() {
    // 낮은 신뢰도 라벨들을 검토 큐에 추가
    List<VocalLabel> tempQueue = [];
    
    // 테스트용 데이터 생성
    for (int i = 0; i < _lowConfidence; i++) {
      tempQueue.add(VocalLabel(
        id: 'review_$i',
        youtubeUrl: 'https://youtu.be/example_$i',
        artistName: 'Artist ${i + 1}',
        songTitle: 'Song ${i + 1}',
        startTime: 30,
        endTime: 45,
        overallQuality: 3,
        technique: 'mix',
        tone: 'neutral',
        pitchAccuracy: 75.0 + (i % 20),
        breathSupport: 70.0 + (i % 25),
        createdAt: DateTime.now(),
        createdBy: 'ai_bot',
      ));
    }
    
    setState(() {
      _reviewQueue = tempQueue;
      if (_reviewQueue.isNotEmpty) {
        _currentReviewItem = _reviewQueue.first;
        _currentReviewIndex = 0;
      }
    });
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0A0E27),
              const Color(0xFF1A1F3A),
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Left Panel - Statistics & Controls
              _buildLeftPanel(),
              
              // Center Panel - Main View
              Expanded(
                flex: 2,
                child: _buildCenterPanel(),
              ),
              
              // Right Panel - Review Queue
              _buildRightPanel(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLeftPanel() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF151A30).withOpacity(0.8),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Title
          _buildLogo(),
          const SizedBox(height: 32),
          
          // Start Button
          _buildStartButton(),
          const SizedBox(height: 32),
          
          // Progress Stats
          if (_processedCount > 0) _buildProgressStats(),
          const SizedBox(height: 24),
          
          // Confidence Distribution
          if (_processedCount > 0) _buildConfidenceChart(),
          
          const Spacer(),
          
          // Bottom Info
          _buildBottomInfo(),
        ],
      ),
    );
  }
  
  Widget _buildLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7C4DFF),
                    const Color(0xFF448AFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Labeling System',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Hybrid Intelligence',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildStartButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isProcessing ? _pulseAnimation.value : 1.0,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isProcessing
                    ? [
                        const Color(0xFFFF6B6B),
                        const Color(0xFFFF8E53),
                      ]
                    : [
                        const Color(0xFF7C4DFF),
                        const Color(0xFF448AFF),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (_isProcessing
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFF7C4DFF))
                      .withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isProcessing ? null : _startAILabeling,
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isProcessing
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isProcessing ? 'Processing...' : 'Start AI Labeling',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
  
  Widget _buildProgressStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$_processedCount / $_totalCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _totalCount > 0 ? _processedCount / _totalCount : 0,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF7C4DFF),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Batch', '$_currentBatch/$_totalBatches'),
              _buildStatItem('Speed', '${(_processedCount / 10).toStringAsFixed(1)}/s'),
              _buildStatItem('ETA', '${((_totalCount - _processedCount) / 10).toStringAsFixed(0)}s'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildConfidenceChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confidence Distribution',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _buildConfidenceBar('High', _highConfidence, const Color(0xFF4CAF50)),
          const SizedBox(height: 12),
          _buildConfidenceBar('Medium', _mediumConfidence, const Color(0xFFFFA726)),
          const SizedBox(height: 12),
          _buildConfidenceBar('Low', _lowConfidence, const Color(0xFFEF5350)),
        ],
      ),
    );
  }
  
  Widget _buildConfidenceBar(String label, int count, Color color) {
    final percentage = _processedCount > 0 ? (count / _processedCount) * 100 : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Text(
              '$count (${percentage.toStringAsFixed(0)}%)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
  
  Widget _buildBottomInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.white.withOpacity(0.5),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI processes initial labels\nHuman reviews & refines',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCenterPanel() {
    if (_currentReviewItem != null && !_isProcessing) {
      return _buildReviewInterface();
    } else if (_isProcessing) {
      return _buildProcessingView();
    } else {
      return _buildWelcomeView();
    }
  }
  
  Widget _buildWelcomeView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7C4DFF).withOpacity(0.2),
                  const Color(0xFF448AFF).withOpacity(0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 60,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'AI-Human Hybrid Labeling',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Click "Start AI Labeling" to begin processing YouTube vocals',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFeatureCard(
                Icons.speed,
                '100x Faster',
                'Than manual labeling',
              ),
              const SizedBox(width: 24),
              _buildFeatureCard(
                Icons.psychology,
                'AI + Human',
                'Best of both worlds',
              ),
              const SizedBox(width: 24),
              _buildFeatureCard(
                Icons.insights,
                'Continuous Learning',
                'Improves over time',
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeatureCard(IconData icon, String title, String subtitle) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF7C4DFF),
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildProcessingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Processing Ring
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return CustomPaint(
                      size: const Size(200, 200),
                      painter: ProcessingRingPainter(
                        progress: value,
                        color: const Color(0xFF7C4DFF),
                      ),
                    );
                  },
                ),
                // Center icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF7C4DFF),
                        const Color(0xFF448AFF),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Text(
            'Processing Batch $_currentBatch of $_totalBatches',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$_processedCount labels generated',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 32),
          // Live stats
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLiveStat('High', _highConfidence, const Color(0xFF4CAF50)),
              const SizedBox(width: 32),
              _buildLiveStat('Medium', _mediumConfidence, const Color(0xFFFFA726)),
              const SizedBox(width: 32),
              _buildLiveStat('Low', _lowConfidence, const Color(0xFFEF5350)),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildLiveStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$label Confidence',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
  
  Widget _buildReviewInterface() {
    if (_currentReviewItem == null) return const SizedBox();
    
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Human Review Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reviewing item ${_currentReviewIndex + 1} of ${_reviewQueue.length}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildActionButton(
                    Icons.skip_previous,
                    'Previous',
                    () => _navigateReview(-1),
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    Icons.skip_next,
                    'Next',
                    () => _navigateReview(1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Main Review Content
          Expanded(
            child: Row(
              children: [
                // Left - Video Info
                Expanded(
                  child: _buildVideoInfoCard(),
                ),
                const SizedBox(width: 24),
                // Right - Label Editor
                Expanded(
                  child: _buildLabelEditor(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDecisionButton(
                'Reject',
                const Color(0xFFEF5350),
                Icons.close,
              ),
              const SizedBox(width: 16),
              _buildDecisionButton(
                'Need More Review',
                const Color(0xFFFFA726),
                Icons.help_outline,
              ),
              const SizedBox(width: 16),
              _buildDecisionButton(
                'Approve',
                const Color(0xFF4CAF50),
                Icons.check,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildVideoInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // YouTube Thumbnail Placeholder
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.withOpacity(0.3),
                  Colors.red.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_currentReviewItem!.startTime}s - ${_currentReviewItem!.endTime}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Song Info
          Text(
            _currentReviewItem!.artistName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentReviewItem!.songTitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          
          // URL
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  color: Colors.white.withOpacity(0.5),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentReviewItem!.youtubeUrl,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // AI Confidence Indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFEF5350).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  color: const Color(0xFFEF5350),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Low AI Confidence',
                      style: TextStyle(
                        color: Color(0xFFEF5350),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manual review recommended',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLabelEditor() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Generated Labels',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Overall Quality
            _buildQualityEditor(),
            const SizedBox(height: 24),
            
            // Technique
            _buildTechniqueEditor(),
            const SizedBox(height: 24),
            
            // Tone
            _buildToneEditor(),
            const SizedBox(height: 24),
            
            // Pitch Accuracy
            _buildSliderEditor(
              'Pitch Accuracy',
              _currentReviewItem!.pitchAccuracy,
              const Color(0xFF7C4DFF),
            ),
            const SizedBox(height: 24),
            
            // Breath Support
            _buildSliderEditor(
              'Breath Support',
              _currentReviewItem!.breathSupport,
              const Color(0xFF448AFF),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQualityEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overall Quality',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(5, (index) {
            final filled = index < _currentReviewItem!.overallQuality;
            return GestureDetector(
              onTap: () {
                setState(() {
                  // Update quality
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                child: Icon(
                  filled ? Icons.star : Icons.star_border,
                  color: const Color(0xFFFFD700),
                  size: 36,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
  
  Widget _buildTechniqueEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vocal Technique',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: VocalTechnique.all.map((technique) {
            final isSelected = _currentReviewItem!.technique == technique;
            return ChoiceChip(
              label: Text(technique.toUpperCase()),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  // Update technique
                });
              },
              selectedColor: const Color(0xFF7C4DFF),
              backgroundColor: Colors.white.withOpacity(0.1),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildToneEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vocal Tone',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: VocalTone.all.map((tone) {
            final isSelected = _currentReviewItem!.tone == tone;
            return ChoiceChip(
              label: Text(tone.toUpperCase()),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  // Update tone
                });
              },
              selectedColor: const Color(0xFF448AFF),
              backgroundColor: Colors.white.withOpacity(0.1),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildSliderEditor(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${value.toInt()}%',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (newValue) {
              setState(() {
                // Update value
              });
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDecisionButton(String label, Color color, IconData icon) {
    return Material(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          // Handle decision
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRightPanel() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF151A30).withOpacity(0.8),
        border: Border(
          left: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Queue',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_reviewQueue.length} items pending',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Queue List
          Expanded(
            child: ListView.builder(
              itemCount: _reviewQueue.length,
              itemBuilder: (context, index) {
                final item = _reviewQueue[index];
                final isActive = index == _currentReviewIndex;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF7C4DFF).withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF7C4DFF).withOpacity(0.5)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _currentReviewIndex = index;
                          _currentReviewItem = item;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.artistName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.songTitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF5350).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Low Confidence',
                                    style: TextStyle(
                                      color: const Color(0xFFEF5350),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  void _navigateReview(int direction) {
    setState(() {
      _currentReviewIndex = (_currentReviewIndex + direction)
          .clamp(0, _reviewQueue.length - 1);
      _currentReviewItem = _reviewQueue[_currentReviewIndex];
    });
  }
}

// Custom Painter for Processing Ring
class ProcessingRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  
  ProcessingRingPainter({
    required this.progress,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Background ring
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    
    canvas.drawCircle(center, radius - 4, bgPaint);
    
    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }
  
  @override
  bool shouldRepaint(ProcessingRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}