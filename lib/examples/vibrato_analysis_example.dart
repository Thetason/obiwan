import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/vibrato_analyzer.dart';
import '../services/advanced_pitch_processor.dart';
import '../widgets/vibrato_visualizer_widget.dart';
import '../utils/pitch_color_system.dart';

/// 🎵 비브라토 분석 사용 예제
/// 
/// 오비완 v3.3 비브라토 분석기의 실제 사용법을 보여주는 예제입니다.
/// - 실시간 비브라토 분석
/// - 시각화 구현
/// - 피드백 시스템
/// - 품질 평가

class VibratoAnalysisExample extends StatefulWidget {
  const VibratoAnalysisExample({Key? key}) : super(key: key);

  @override
  State<VibratoAnalysisExample> createState() => _VibratoAnalysisExampleState();
}

class _VibratoAnalysisExampleState extends State<VibratoAnalysisExample> {
  
  // === 분석기 인스턴스 ===
  final VibratoAnalyzer _vibratoAnalyzer = VibratoAnalyzer();
  final AdvancedPitchProcessor _pitchProcessor = AdvancedPitchProcessor();
  
  // === 상태 관리 ===
  VibratoAnalysisResult? _currentResult;
  VibratoAnalysisStats? _analysisStats;
  Timer? _analysisTimer;
  bool _isAnalyzing = false;
  
  // === 시뮬레이션 데이터 (실제 사용 시에는 CREPE/SPICE 데이터 사용) ===
  int _simulationStep = 0;

  @override
  void initState() {
    super.initState();
    _startAnalysisDemo();
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _vibratoAnalyzer.clearHistory();
    _pitchProcessor.dispose();
    super.dispose();
  }

  /// 🎯 분석 데모 시작
  void _startAnalysisDemo() {
    setState(() {
      _isAnalyzing = true;
    });

    // 실제 사용법: CREPE/SPICE에서 받은 피치 데이터를 주기적으로 분석
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _performAnalysis();
    });
  }

  /// 🔬 실제 분석 수행
  void _performAnalysis() {
    // ❗ 실제 구현에서는 여기에 CREPE/SPICE 데이터를 사용
    // 지금은 시뮬레이션 데이터로 테스트
    final pitchData = _generateSimulatedPitchData();
    
    // 비브라토 분석 수행
    final result = _vibratoAnalyzer.analyzeVibrato(pitchData);
    
    // 분석 통계 업데이트
    final stats = _vibratoAnalyzer.getAnalysisStats();
    
    setState(() {
      _currentResult = result;
      _analysisStats = stats;
    });

    // 로그 출력 (실제 개발에서 디버깅용)
    print('🎵 [VibratoExample] ${result.toString()}');
  }

  /// 📊 시뮬레이션 피치 데이터 생성
  /// 
  /// ❗ 실제 사용 시에는 이 부분을 CREPE/SPICE 데이터로 교체하세요
  PitchData _generateSimulatedPitchData() {
    _simulationStep++;
    
    // 기본 주파수 (C5 = 523.25Hz)
    const double baseFrequency = 523.25;
    
    // 시간에 따른 비브라토 시뮬레이션
    final time = _simulationStep * 0.1; // 0.1초 간격
    
    // 비브라토 효과 (6Hz 속도, ±30 cents 깊이)
    final vibratoRate = 6.0; // Hz
    final vibratoDepth = 30.0; // cents
    final vibratoPhase = 2 * math.pi * vibratoRate * time;
    final vibratoOffset = vibratoDepth * math.sin(vibratoPhase);
    
    // cents를 주파수 변화로 변환
    final frequencyRatio = math.pow(2, vibratoOffset / 1200);
    final currentFrequency = baseFrequency * frequencyRatio;
    
    // 신뢰도 (품질 시뮬레이션)
    final confidence = 0.8 + 0.2 * math.sin(time * 2) * math.sin(time * 0.5);
    
    // 음량 (진폭)
    final amplitude = 0.5 + 0.3 * math.sin(time * 1.5);
    
    return PitchData(
      frequency: currentFrequency,
      confidence: confidence.clamp(0.0, 1.0),
      cents: vibratoOffset,
      timestamp: DateTime.now(),
      amplitude: amplitude.clamp(0.0, 1.0),
    );
  }

  /// 🧹 분석 초기화
  void _resetAnalysis() {
    _vibratoAnalyzer.clearHistory();
    _simulationStep = 0;
    setState(() {
      _currentResult = null;
      _analysisStats = null;
    });
  }

  /// ⏯️ 분석 토글
  void _toggleAnalysis() {
    if (_isAnalyzing) {
      _analysisTimer?.cancel();
      setState(() {
        _isAnalyzing = false;
      });
    } else {
      _startAnalysisDemo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('🎵 비브라토 분석 예제'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _resetAnalysis,
            icon: const Icon(Icons.refresh),
            tooltip: '분석 초기화',
          ),
          IconButton(
            onPressed: _toggleAnalysis,
            icon: Icon(_isAnalyzing ? Icons.pause : Icons.play_arrow),
            tooltip: _isAnalyzing ? '분석 일시정지' : '분석 시작',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === 실시간 비브라토 시각화 ===
            _buildVisualizationSection(),
            
            const SizedBox(height: 24),
            
            // === 분석 결과 상세 정보 ===
            _buildAnalysisResultSection(),
            
            const SizedBox(height: 24),
            
            // === 분석 통계 및 성능 정보 ===
            _buildAnalysisStatsSection(),
            
            const SizedBox(height: 24),
            
            // === 사용법 가이드 ===
            _buildUsageGuideSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualizationSection() {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🌊 실시간 비브라토 시각화',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // 메인 비브라토 시각화 위젯
            VibratoVisualizerWidget(
              vibratoResult: _currentResult,
              width: double.infinity,
              height: 200,
              showDetails: true,
              primaryColor: const Color(0xFF6366F1),
              backgroundColor: const Color(0xFF0F172A),
            ),
            
            const SizedBox(height: 16),
            
            // 컴팩트 인디케이터들
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    CompactVibratoIndicator(
                      vibratoResult: _currentResult,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '비브라토',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getStatusColor().withOpacity(0.2),
                        border: Border.all(
                          color: _getStatusColor(),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _isAnalyzing ? Icons.mic : Icons.mic_off,
                        color: _getStatusColor(),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '분석 상태',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResultSection() {
    final result = _currentResult;
    
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊 분석 결과',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (result == null || !result.isPresent) ...[
              _buildNoResultView(),
            ] else ...[
              _buildResultDetails(result),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.music_off,
            size: 48,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '비브라토가 감지되지 않았습니다',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '목소리에 일정한 떨림을 주어 비브라토를 만들어보세요',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResultDetails(VibratoAnalysisResult result) {
    return Column(
      children: [
        // 피드백 메시지
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getQualityColor(result.quality).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getQualityColor(result.quality).withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getQualityIcon(result.quality),
                    color: _getQualityColor(result.quality),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    result.feedback,
                    style: TextStyle(
                      color: _getQualityColor(result.quality),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                result.statusDescription,
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 상세 메트릭
        _buildMetricGrid(result),
      ],
    );
  }

  Widget _buildMetricGrid(VibratoAnalysisResult result) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2,
      children: [
        _buildMetricCard(
          '속도',
          '${result.rate.toStringAsFixed(1)} Hz',
          '4-8 Hz 권장',
          result.rate / 8.0,
          Colors.blue,
        ),
        _buildMetricCard(
          '깊이',
          '${result.depth.toStringAsFixed(0)} cents',
          '10-100 cents',
          result.depth / 100.0,
          Colors.green,
        ),
        _buildMetricCard(
          '규칙성',
          '${(result.regularity * 100).toStringAsFixed(0)}%',
          '60% 이상 권장',
          result.regularity,
          Colors.orange,
        ),
        _buildMetricCard(
          '강도',
          '${(result.intensity * 100).toStringAsFixed(0)}%',
          '전체 강도',
          result.intensity,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle, 
                         double progress, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisStatsSection() {
    final stats = _analysisStats;
    
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📈 분석 통계',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (stats != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem('총 분석 횟수', '${stats.totalAnalysisCount}'),
                  _buildStatItem('현재 데이터', '${stats.currentDataPoints}'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem('평균 신뢰도', '${(stats.avgConfidence * 100).toStringAsFixed(1)}%'),
                  _buildStatItem('분석 시간', '${stats.timeSpan.toStringAsFixed(1)}초'),
                ],
              ),
            ] else ...[
              Text(
                '분석 통계를 수집 중입니다...',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
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
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildUsageGuideSection() {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💡 사용법 가이드',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildGuideStep(
              '1',
              '실제 구현에서는 CREPE/SPICE 데이터 사용',
              'PitchData 객체를 생성하여 analyzeVibrato() 메서드에 전달',
            ),
            
            _buildGuideStep(
              '2',
              '실시간 분석을 위한 주기적 호출',
              '100ms 간격으로 분석하여 부드러운 실시간 피드백 제공',
            ),
            
            _buildGuideStep(
              '3',
              '비브라토 시각화 위젯 사용',
              'VibratoVisualizerWidget을 사용하여 결과를 시각화',
            ),
            
            _buildGuideStep(
              '4',
              '품질 기반 피드백 제공',
              'VibratoQuality에 따른 맞춤형 피드백 메시지 활용',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (!_isAnalyzing) return Colors.grey;
    return _currentResult?.isPresent == true 
        ? const Color(0xFF10B981) 
        : const Color(0xFF6366F1);
  }

  Color _getQualityColor(VibratoQuality quality) {
    switch (quality) {
      case VibratoQuality.excellent:
        return const Color(0xFF10B981);
      case VibratoQuality.good:
        return const Color(0xFF3B82F6);
      case VibratoQuality.fair:
        return const Color(0xFFF59E0B);
      case VibratoQuality.poor:
        return const Color(0xFFEF4444);
      case VibratoQuality.none:
        return Colors.grey;
    }
  }

  IconData _getQualityIcon(VibratoQuality quality) {
    switch (quality) {
      case VibratoQuality.excellent:
        return Icons.star;
      case VibratoQuality.good:
        return Icons.thumb_up;
      case VibratoQuality.fair:
        return Icons.trending_up;
      case VibratoQuality.poor:
        return Icons.trending_down;
      case VibratoQuality.none:
        return Icons.help_outline;
    }
  }
}