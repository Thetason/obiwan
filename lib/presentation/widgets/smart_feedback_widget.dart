import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/ai_coaching/smart_feedback_engine.dart';
import '../../core/theme/app_theme.dart';
import 'dart:math' as math;

class SmartFeedbackWidget extends ConsumerStatefulWidget {
  final SmartFeedback? feedback;
  final bool isActive;
  
  const SmartFeedbackWidget({
    super.key,
    this.feedback,
    this.isActive = false,
  });

  @override
  ConsumerState<SmartFeedbackWidget> createState() => _SmartFeedbackWidgetState();
}

class _SmartFeedbackWidgetState extends ConsumerState<SmartFeedbackWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
  }
  
  @override
  void didUpdateWidget(SmartFeedbackWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.feedback != null && oldWidget.feedback != widget.feedback) {
      _slideController.forward(from: 0);
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (widget.feedback == null) {
      return _buildEmptyState();
    }
    
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: _getDecorationForPriority(widget.feedback!.priority),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildMainContent(),
              if (widget.feedback!.specificTips.isNotEmpty)
                _buildTipsSection(),
              _buildMetricsBar(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassmorphismDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 48,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            '발성을 시작하면\nAI 피드백을 제공합니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    final feedback = widget.feedback!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getColorForPriority(feedback.priority).withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: _getColorForPriority(feedback.priority).withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: feedback.priority == FeedbackPriority.celebration 
                    ? _pulseAnimation.value 
                    : 1.0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getColorForPriority(feedback.priority),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: feedback.priority == FeedbackPriority.celebration
                        ? [
                            BoxShadow(
                              color: _getColorForPriority(feedback.priority).withOpacity(0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    _getIconForCategory(feedback.category),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getCategoryLabel(feedback.category),
                  style: TextStyle(
                    color: _getColorForPriority(feedback.priority),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getPriorityLabel(feedback.priority),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          _buildConfidenceIndicator(feedback.confidence),
        ],
      ),
    );
  }
  
  Widget _buildMainContent() {
    final feedback = widget.feedback!;
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feedback.mainMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.favorite,
                  color: Colors.pink.shade300,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feedback.encouragement,
                    style: TextStyle(
                      color: Colors.blue.shade200,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTipsSection() {
    final feedback = widget.feedback!;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.amber.shade300,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '맞춤 조언',
                style: TextStyle(
                  color: Colors.amber.shade300,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...feedback.specificTips.asMap().entries.map((entry) {
            final index = entry.key;
            final tip = entry.value;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
  
  Widget _buildMetricsBar() {
    final feedback = widget.feedback!;
    final metrics = feedback.metrics;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (metrics.containsKey('current_score'))
            _buildMetricItem(
              '종합점수',
              '${metrics['current_score'].toStringAsFixed(0)}점',
              Icons.star,
              _getScoreColor(metrics['current_score'].toDouble()),
            ),
          if (metrics.containsKey('stability'))
            _buildMetricItem(
              '안정성',
              '${(metrics['stability'] * 100).toStringAsFixed(0)}%',
              Icons.favorite,
              _getStabilityColor(metrics['stability'].toDouble()),
            ),
          if (metrics.containsKey('session_count'))
            _buildMetricItem(
              '세션',
              '${metrics['session_count']}회',
              Icons.schedule,
              Colors.blue.shade300,
            ),
        ],
      ),
    );
  }
  
  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 16,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
  
  Widget _buildConfidenceIndicator(double confidence) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.psychology,
            size: 12,
            color: _getConfidenceColor(confidence),
          ),
          const SizedBox(width: 4),
          Text(
            '${(confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: _getConfidenceColor(confidence),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper methods
  BoxDecoration _getDecorationForPriority(FeedbackPriority priority) {
    final color = _getColorForPriority(priority);
    
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.black.withOpacity(0.8),
          Colors.black.withOpacity(0.6),
        ],
      ),
      border: Border.all(
        color: color.withOpacity(0.5),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.3),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      ],
    );
  }
  
  Color _getColorForPriority(FeedbackPriority priority) {
    switch (priority) {
      case FeedbackPriority.critical:
        return Colors.red.shade400;
      case FeedbackPriority.high:
        return Colors.orange.shade400;
      case FeedbackPriority.medium:
        return Colors.blue.shade400;
      case FeedbackPriority.low:
        return Colors.grey.shade400;
      case FeedbackPriority.celebration:
        return Colors.green.shade400;
    }
  }
  
  IconData _getIconForCategory(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.pitch:
        return Icons.music_note;
      case FeedbackCategory.breathing:
        return Icons.air;
      case FeedbackCategory.resonance:
        return Icons.graphic_eq;
      case FeedbackCategory.posture:
        return Icons.accessibility_new;
      case FeedbackCategory.overall:
        return Icons.psychology;
    }
  }
  
  String _getCategoryLabel(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.pitch:
        return '음정 분석';
      case FeedbackCategory.breathing:
        return '호흡 분석';
      case FeedbackCategory.resonance:
        return '공명 분석';
      case FeedbackCategory.posture:
        return '자세 분석';
      case FeedbackCategory.overall:
        return '종합 분석';
    }
  }
  
  String _getPriorityLabel(FeedbackPriority priority) {
    switch (priority) {
      case FeedbackPriority.critical:
        return '즉시 개선 필요';
      case FeedbackPriority.high:
        return '우선 개선';
      case FeedbackPriority.medium:
        return '권장 사항';
      case FeedbackPriority.low:
        return '참고 사항';
      case FeedbackPriority.celebration:
        return '축하합니다!';
    }
  }
  
  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green.shade400;
    if (score >= 60) return Colors.blue.shade400;
    if (score >= 40) return Colors.orange.shade400;
    return Colors.red.shade400;
  }
  
  Color _getStabilityColor(double stability) {
    if (stability >= 0.8) return Colors.green.shade400;
    if (stability >= 0.6) return Colors.blue.shade400;
    if (stability >= 0.4) return Colors.orange.shade400;
    return Colors.red.shade400;
  }
  
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green.shade300;
    if (confidence >= 0.6) return Colors.blue.shade300;
    if (confidence >= 0.4) return Colors.orange.shade300;
    return Colors.red.shade300;
  }
}