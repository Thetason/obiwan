import 'package:flutter/material.dart';
import 'dart:math' as math;

class PitchFeedbackOverlay extends StatefulWidget {
  final double currentFrequency;
  final double targetFrequency;
  final bool isActive;
  
  const PitchFeedbackOverlay({
    Key? key,
    required this.currentFrequency,
    this.targetFrequency = 440.0, // A4 기본값
    required this.isActive,
  }) : super(key: key);
  
  @override
  State<PitchFeedbackOverlay> createState() => _PitchFeedbackOverlayState();
}

class _PitchFeedbackOverlayState extends State<PitchFeedbackOverlay>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isActive) {
      _animationController.repeat(reverse: true);
    }
  }
  
  @override
  void didUpdateWidget(PitchFeedbackOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive && !oldWidget.isActive) {
      _animationController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _animationController.stop();
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  double _calculateAccuracy() {
    final diff = (widget.currentFrequency - widget.targetFrequency).abs();
    final percentage = math.max(0, 100 - (diff / widget.targetFrequency * 100));
    return percentage;
  }
  
  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 95) return const Color(0xFF4CAF50);
    if (accuracy >= 80) return const Color(0xFF8BC34A);
    if (accuracy >= 60) return const Color(0xFFFFC107);
    if (accuracy >= 40) return const Color(0xFFFF9800);
    return const Color(0xFFFF5252);
  }
  
  String _getMotivationalText(double accuracy) {
    if (accuracy >= 95) return '완벽해요! 🎯';
    if (accuracy >= 80) return '아주 좋아요! 👍';
    if (accuracy >= 60) return '잘하고 있어요! 💪';
    if (accuracy >= 40) return '조금만 더! 🎵';
    return '다시 해보세요! 🎤';
  }
  
  IconData _getDirectionIcon() {
    final diff = widget.currentFrequency - widget.targetFrequency;
    if (diff.abs() < 10) return Icons.check_circle;
    if (diff > 0) return Icons.arrow_downward;
    return Icons.arrow_upward;
  }
  
  String _getDirectionText() {
    final diff = widget.currentFrequency - widget.targetFrequency;
    if (diff.abs() < 10) return '정확해요!';
    if (diff > 0) return '조금 낮춰보세요';
    return '조금 높여보세요';
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();
    
    final accuracy = _calculateAccuracy();
    final color = _getAccuracyColor(accuracy);
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 상단 피드백 카드
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: accuracy >= 95 ? _pulseAnimation.value : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getDirectionIcon(),
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getMotivationalText(accuracy),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getDirectionText(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 20),
          
          // 정확도 미터
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Stack(
              children: [
                // 배경 그라데이션
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF5252),
                        const Color(0xFFFFC107),
                        const Color(0xFF4CAF50),
                      ],
                    ),
                  ),
                  child: Opacity(
                    opacity: 0.2,
                    child: Container(),
                  ),
                ),
                
                // 현재 위치 표시
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  left: MediaQuery.of(context).size.width * 
                        (widget.currentFrequency - 200) / 680 - 30,
                  top: 10,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${accuracy.round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // 목표 위치 표시
                Positioned(
                  left: MediaQuery.of(context).size.width * 
                        (widget.targetFrequency - 200) / 680 - 2,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 주파수 정보
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFrequencyInfo(
                '현재',
                '${widget.currentFrequency.round()}Hz',
                _frequencyToNote(widget.currentFrequency),
                color,
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white24,
              ),
              _buildFrequencyInfo(
                '목표',
                '${widget.targetFrequency.round()}Hz',
                _frequencyToNote(widget.targetFrequency),
                Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildFrequencyInfo(String label, String frequency, String note, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          frequency,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          note,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
  
  String _frequencyToNote(double frequency) {
    final notes = [
      {'freq': 261.63, 'note': 'C4'},
      {'freq': 293.66, 'note': 'D4'},
      {'freq': 329.63, 'note': 'E4'},
      {'freq': 349.23, 'note': 'F4'},
      {'freq': 392.00, 'note': 'G4'},
      {'freq': 440.00, 'note': 'A4'},
      {'freq': 493.88, 'note': 'B4'},
      {'freq': 523.25, 'note': 'C5'},
    ];
    
    var closestNote = notes[0];
    var minDiff = (frequency - notes[0]['freq'] as num).abs();
    
    for (final note in notes) {
      final diff = (frequency - note['freq'] as num).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestNote = note;
      }
    }
    
    return closestNote['note'] as String;
  }
}