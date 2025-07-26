import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'advanced_breathing_detector.dart';

/// Interactive breathing training UI with real-time feedback
class BreathingTrainingUI extends StatefulWidget {
  final AdvancedBreathingDetector detector;
  final Function(BreathingAnalysis)? onAnalysisUpdate;
  
  const BreathingTrainingUI({
    Key? key,
    required this.detector,
    this.onAnalysisUpdate,
  }) : super(key: key);
  
  @override
  State<BreathingTrainingUI> createState() => _BreathingTrainingUIState();
}

class _BreathingTrainingUIState extends State<BreathingTrainingUI>
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _pulseController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _pulseAnimation;
  
  BreathingAnalysis? _currentAnalysis;
  BreathingStatistics? _currentStats;
  StreamSubscription<BreathingAnalysis>? _analysisSubscription;
  
  // Training modes
  BreathingTrainingMode _currentMode = BreathingTrainingMode.guided;
  int _targetBreathsPerMinute = 15;
  Duration _inhaleTarget = const Duration(seconds: 4);
  Duration _exhaleTarget = const Duration(seconds: 6);
  Duration _pauseTarget = const Duration(seconds: 2);
  
  // Training session
  bool _isTrainingActive = false;
  DateTime? _sessionStartTime;
  int _completedBreaths = 0;
  int _targetBreaths = 20;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _subscribeToAnalysis();
    _updateStatistics();
  }
  
  void _initializeAnimations() {
    _breathingController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _breathingAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
  }
  
  void _subscribeToAnalysis() {
    _analysisSubscription = widget.detector.analysisStream.listen((analysis) {
      setState(() {
        _currentAnalysis = analysis;
      });
      widget.onAnalysisUpdate?.call(analysis);
      
      if (_isTrainingActive) {
        _updateTrainingProgress(analysis);
      }
    });
  }
  
  void _updateStatistics() {
    Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() {
        _currentStats = widget.detector.getCurrentStatistics();
      });
    });
  }
  
  void _updateTrainingProgress(BreathingAnalysis analysis) {
    // Count completed breaths
    final inhaleEvents = analysis.recentEvents
        .where((e) => e.type == BreathType.inhale)
        .length;
    
    if (inhaleEvents > _completedBreaths) {
      setState(() {
        _completedBreaths = inhaleEvents;
      });
      
      if (_completedBreaths >= _targetBreaths) {
        _completeTrainingSession();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.indigo[900]!.withOpacity(0.8),
            Colors.purple[900]!.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildTrainingArea()),
          _buildControlPanel(),
          _buildStatisticsPanel(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            '호흡 트레이닝',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getTrainingModeDescription(_currentMode),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrainingArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(child: _buildBreathingVisualizer()),
          const SizedBox(height: 20),
          if (_isTrainingActive) _buildTrainingProgress(),
          const SizedBox(height: 20),
          _buildRealTimeFeedback(),
        ],
      ),
    );
  }
  
  Widget _buildBreathingVisualizer() {
    return Center(
      child: AnimatedBuilder(
        animation: _breathingAnimation,
        builder: (context, child) {
          return AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final scale = _breathingAnimation.value * _pulseAnimation.value;
              
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.cyan.withOpacity(0.8),
                        Colors.blue.withOpacity(0.6),
                        Colors.indigo.withOpacity(0.4),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getBreathingIcon(),
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getBreathingPhaseText(),
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
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _buildTrainingProgress() {
    final progress = _completedBreaths / _targetBreaths;
    
    return Column(
      children: [
        Text(
          '진행률: $_completedBreaths / $_targetBreaths',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white24,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
        ),
        const SizedBox(height: 8),
        Text(
          _sessionStartTime != null
              ? '경과 시간: ${DateTime.now().difference(_sessionStartTime!).inMinutes}분'
              : '',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
  
  Widget _buildRealTimeFeedback() {
    if (_currentAnalysis == null) {
      return const Text(
        '호흡 분석 중...',
        style: TextStyle(color: Colors.white70, fontSize: 16),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricCard(
                '호흡수',
                '${_currentAnalysis!.breathingRate.toStringAsFixed(1)}/분',
                _getBreathingRateColor(_currentAnalysis!.breathingRate),
              ),
              _buildMetricCard(
                '리듬',
                '${(_currentAnalysis!.rhythmRegularity * 100).toStringAsFixed(0)}%',
                _getRhythmColor(_currentAnalysis!.rhythmRegularity),
              ),
              _buildMetricCard(
                '효율성',
                '${(_currentAnalysis!.efficiency * 100).toStringAsFixed(0)}%',
                _getEfficiencyColor(_currentAnalysis!.efficiency),
              ),
            ],
          ),
          if (_currentAnalysis!.insights.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInsights(_currentAnalysis!.insights),
          ],
        ],
      ),
    );
  }
  
  Widget _buildMetricCard(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildInsights(List<BreathingInsight> insights) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '실시간 피드백:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...insights.take(2).map((insight) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(
                _getInsightIcon(insight.severity),
                size: 16,
                color: _getInsightColor(insight.severity),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.message,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
  
  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _isTrainingActive ? _stopTraining : _startTraining,
                icon: Icon(_isTrainingActive ? Icons.stop : Icons.play_arrow),
                label: Text(_isTrainingActive ? '중지' : '시작'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTrainingActive ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showSettingsDialog,
                icon: const Icon(Icons.settings),
                label: const Text('설정'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildModeSelector(),
        ],
      ),
    );
  }
  
  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: BreathingTrainingMode.values.map((mode) {
          final isSelected = mode == _currentMode;
          return GestureDetector(
            onTap: () => _setTrainingMode(mode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.cyan.withOpacity(0.3) : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getTrainingModeName(mode),
                style: TextStyle(
                  color: isSelected ? Colors.cyan : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildStatisticsPanel() {
    if (_currentStats == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('총 호흡', '${_currentStats!.totalBreaths}'),
          _buildStatItem('평균 호흡수', '${_currentStats!.averageRate.toStringAsFixed(1)}/분'),
          _buildStatItem('오늘 세션', '${_currentStats!.sessionsToday}'),
          _buildStatItem(
            '향상도',
            '${_currentStats!.improvementTrend > 0 ? '+' : ''}${_currentStats!.improvementTrend.toStringAsFixed(1)}',
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  void _startTraining() {
    setState(() {
      _isTrainingActive = true;
      _sessionStartTime = DateTime.now();
      _completedBreaths = 0;
    });
    
    if (_currentMode == BreathingTrainingMode.guided) {
      _startGuidedBreathing();
    }
  }
  
  void _stopTraining() {
    setState(() {
      _isTrainingActive = false;
      _sessionStartTime = null;
    });
    
    _breathingController.stop();
  }
  
  void _completeTrainingSession() {
    setState(() {
      _isTrainingActive = false;
    });
    
    _showCompletionDialog();
  }
  
  void _startGuidedBreathing() {
    final totalCycleDuration = _inhaleTarget + _pauseTarget + _exhaleTarget + _pauseTarget;
    
    _breathingController.duration = totalCycleDuration;
    _breathingController.repeat();
  }
  
  void _setTrainingMode(BreathingTrainingMode mode) {
    setState(() {
      _currentMode = mode;
    });
  }
  
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('호흡 트레이닝 설정', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSettingSlider(
                '목표 호흡수 (분당)',
                _targetBreathsPerMinute.toDouble(),
                10,
                25,
                (value) => setState(() => _targetBreathsPerMinute = value.round()),
              ),
              _buildSettingSlider(
                '들숨 시간 (초)',
                _inhaleTarget.inSeconds.toDouble(),
                2,
                8,
                (value) => setState(() => _inhaleTarget = Duration(seconds: value.round())),
              ),
              _buildSettingSlider(
                '날숨 시간 (초)',
                _exhaleTarget.inSeconds.toDouble(),
                3,
                12,
                (value) => setState(() => _exhaleTarget = Duration(seconds: value.round())),
              ),
              _buildSettingSlider(
                '목표 호흡 횟수',
                _targetBreaths.toDouble(),
                10,
                50,
                (value) => setState(() => _targetBreaths = value.round()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSettingSlider(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.round()}',
          style: const TextStyle(color: Colors.white),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          activeColor: Colors.cyan,
          onChanged: onChanged,
        ),
      ],
    );
  }
  
  void _showCompletionDialog() {
    final duration = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!)
        : Duration.zero;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('트레이닝 완료!', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              '훌륭합니다!\n$_targetBreaths번의 호흡을 완료했습니다.',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '소요 시간: ${duration.inMinutes}분 ${duration.inSeconds % 60}초',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
  }
  
  // Helper methods
  
  IconData _getBreathingIcon() {
    if (!_isTrainingActive || _currentAnalysis == null) {
      return Icons.air;
    }
    
    // Determine current phase based on animation progress
    final progress = _breathingController.value;
    
    if (progress < 0.4) {
      return Icons.keyboard_arrow_up; // Inhale
    } else if (progress < 0.6) {
      return Icons.pause; // Hold
    } else {
      return Icons.keyboard_arrow_down; // Exhale
    }
  }
  
  String _getBreathingPhaseText() {
    if (!_isTrainingActive) return '준비';
    
    final progress = _breathingController.value;
    
    if (progress < 0.4) {
      return '들숨';
    } else if (progress < 0.6) {
      return '잠시';
    } else {
      return '날숨';
    }
  }
  
  Color _getBreathingRateColor(double rate) {
    if (rate < 12 || rate > 20) return Colors.orange;
    return Colors.green;
  }
  
  Color _getRhythmColor(double regularity) {
    if (regularity > 0.8) return Colors.green;
    if (regularity > 0.6) return Colors.orange;
    return Colors.red;
  }
  
  Color _getEfficiencyColor(double efficiency) {
    if (efficiency > 0.8) return Colors.green;
    if (efficiency > 0.6) return Colors.orange;
    return Colors.red;
  }
  
  IconData _getInsightIcon(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.info:
        return Icons.info_outline;
      case InsightSeverity.warning:
        return Icons.warning_amber_outlined;
      case InsightSeverity.critical:
        return Icons.error_outline;
    }
  }
  
  Color _getInsightColor(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.info:
        return Colors.blue;
      case InsightSeverity.warning:
        return Colors.orange;
      case InsightSeverity.critical:
        return Colors.red;
    }
  }
  
  String _getTrainingModeDescription(BreathingTrainingMode mode) {
    switch (mode) {
      case BreathingTrainingMode.guided:
        return '가이드에 따라 천천히 호흡하세요';
      case BreathingTrainingMode.free:
        return '자유롭게 호흡하며 분석을 받아보세요';
      case BreathingTrainingMode.rhythm:
        return '일정한 리듬으로 호흡 연습을 하세요';
    }
  }
  
  String _getTrainingModeName(BreathingTrainingMode mode) {
    switch (mode) {
      case BreathingTrainingMode.guided:
        return '가이드';
      case BreathingTrainingMode.free:
        return '자유';
      case BreathingTrainingMode.rhythm:
        return '리듬';
    }
  }
  
  @override
  void dispose() {
    _analysisSubscription?.cancel();
    _breathingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}

enum BreathingTrainingMode {
  guided,
  free,
  rhythm,
}