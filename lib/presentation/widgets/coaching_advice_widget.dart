import 'package:flutter/material.dart';
import '../../domain/entities/vocal_analysis.dart';

class CoachingAdviceWidget extends StatelessWidget {
  final List<VocalAnalysis> analysisResults;
  final bool isRealTime;
  
  const CoachingAdviceWidget({
    super.key,
    required this.analysisResults,
    required this.isRealTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                isRealTime ? Icons.mic : Icons.mic_off,
                size: 20,
                color: isRealTime ? Colors.red : Colors.white30,
              ),
              const SizedBox(width: 8),
              Text(
                isRealTime 
                  ? 'AI 실시간 코칭'
                  : '분석 결과',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Score Display
          if (analysisResults.isNotEmpty)
            _buildScoreSection(analysisResults.last),
          
          const SizedBox(height: 16),
          
          // Advice Section
          Expanded(
            child: _buildAdviceSection(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScoreSection(VocalAnalysis analysis) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getScoreColor(analysis.overallScore).withOpacity(0.2),
            _getScoreColor(analysis.overallScore).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '전체 점수',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          Text(
            '${analysis.overallScore}점',
            style: TextStyle(
              color: _getScoreColor(analysis.overallScore),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAdviceSection() {
    if (analysisResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology, size: 48, color: Colors.white30),
            SizedBox(height: 16),
            Text(
              '녹음을 시작하면\nAI 코칭을 받을 수 있습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    final advice = _generateAdvice(analysisResults.last);
    
    return ListView.builder(
      itemCount: advice.length,
      itemBuilder: (context, index) {
        final item = advice[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                item['icon'] as IconData,
                color: item['color'] as Color,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item['text'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
  
  List<Map<String, dynamic>> _generateAdvice(VocalAnalysis analysis) {
    final advice = <Map<String, dynamic>>[];
    
    if (analysis.pitchStability < 0.7) {
      advice.add({
        'icon': Icons.tune,
        'color': Colors.orange,
        'text': '음정 안정성을 향상시키세요. 천천히 부르며 연습하세요.',
      });
    }
    
    if (analysis.breathingType != BreathingType.diaphragmatic) {
      advice.add({
        'icon': Icons.air,
        'color': Colors.blue,
        'text': '복식호흡을 연습하세요. 배를 부풀리며 숨을 들이마시세요.',
      });
    }
    
    if (analysis.overallScore >= 80) {
      advice.add({
        'icon': Icons.star,
        'color': Colors.yellow,
        'text': '훌륭합니다! 계속 이 수준을 유지하세요.',
      });
    }
    
    if (advice.isEmpty) {
      advice.add({
        'icon': Icons.mic,
        'color': Colors.grey,
        'text': '계속 연습하며 기술을 향상시키세요.',
      });
    }
    
    return advice;
  }
}