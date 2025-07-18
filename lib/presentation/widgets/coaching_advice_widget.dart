import 'package:flutter/material.dart';
import '../../domain/entities/vocal_analysis.dart';

class CoachingAdviceWidget extends StatelessWidget {
  final VocalAnalysis? analysis;
  final bool isRecording;
  final Function(String) onAdviceAction;
  
  const CoachingAdviceWidget({
    super.key,
    this.analysis,
    required this.isRecording,
    required this.onAdviceAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 점수 표시
          _buildScoreSection(),
          
          const SizedBox(height: 16),
          
          // 조언 섹션
          Expanded(
            child: analysis != null
                ? _buildAdviceSection()
                : _buildPlaceholderSection(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScoreSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '발성 점수',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        if (analysis != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getScoreColor(analysis!.overallScore),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${analysis!.overallScore}점',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildAdviceSection() {
    final advice = _generateAdvice(analysis!);
    final actions = _getRecommendedActions(analysis!);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 주요 조언
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            advice,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 액션 버튼들
        if (actions.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actions.map((action) => _buildActionButton(action)).toList(),
          ),
      ],
    );
  }
  
  Widget _buildPlaceholderSection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isRecording ? Icons.mic : Icons.mic_off,
            size: 48,
            color: isRecording ? Colors.red : Colors.white30,
          ),
          const SizedBox(height: 16),
          Text(
            isRecording 
                ? '분석 중...' 
                : '녹음을 시작하여 AI 코치의 조언을 받아보세요',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton(ActionInfo action) {
    return ElevatedButton.icon(
      onPressed: () => onAdviceAction(action.id),
      icon: Icon(
        action.icon,
        size: 18,
      ),
      label: Text(action.label),
      style: ElevatedButton.styleFrom(
        backgroundColor: action.color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
  
  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
  
  String _generateAdvice(VocalAnalysis analysis) {
    // 우선순위 기반 조언 생성
    final issues = <String>[];
    
    // 호흡 관련 조언
    if (analysis.breathingType == BreathingType.chest) {
      issues.add('복식호흡을 연습하세요. 배를 의식하며 깊게 숨을 들이마세요.');
    }
    
    // 피치 안정성 조언
    if (analysis.pitchStability < 70) {
      issues.add('음정이 불안정합니다. 천천히 정확한 음정을 유지하며 연습하세요.');
    }
    
    // 공명 위치 조언
    if (analysis.resonancePosition == ResonancePosition.throat) {
      issues.add('목 공명보다는 앞쪽(마스크 영역)으로 소리를 보내보세요.');
    }
    
    // 비브라토 조언
    if (analysis.vibratoQuality == VibratoQuality.heavy) {
      issues.add('비브라토가 너무 강합니다. 더 자연스럽게 조절해보세요.');
    }
    
    // 조언이 없으면 긍정적인 피드백
    if (issues.isEmpty) {
      return '훌륭한 발성입니다! 이 상태를 유지하며 계속 연습하세요.';
    }
    
    // 가장 중요한 조언 1-2개만 반환
    return issues.take(2).join(' ');
  }
  
  List<ActionInfo> _getRecommendedActions(VocalAnalysis analysis) {
    final actions = <ActionInfo>[];
    
    // 호흡 가이드
    if (analysis.breathingType == BreathingType.chest) {
      actions.add(ActionInfo(
        id: 'breathing_guide',
        label: '호흡 가이드',
        icon: Icons.air,
        color: Colors.blue,
      ));
    }
    
    // 자세 가이드
    if (analysis.pitchStability < 70) {
      actions.add(ActionInfo(
        id: 'posture_guide',
        label: '자세 교정',
        icon: Icons.person_pin,
        color: Colors.orange,
      ));
    }
    
    // 공명 가이드
    if (analysis.resonancePosition == ResonancePosition.throat) {
      actions.add(ActionInfo(
        id: 'resonance_guide',
        label: '공명 가이드',
        icon: Icons.graphic_eq,
        color: Colors.purple,
      ));
    }
    
    // 입 모양 가이드
    actions.add(ActionInfo(
      id: 'mouth_shape_guide',
      label: '입 모양',
      icon: Icons.record_voice_over,
      color: Colors.green,
    ));
    
    // 단계별 가이드
    actions.add(ActionInfo(
      id: 'step_by_step',
      label: '단계별 학습',
      icon: Icons.school,
      color: Colors.indigo,
    ));
    
    return actions;
  }
}

class ActionInfo {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  
  ActionInfo({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}