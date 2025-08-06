import 'package:flutter/material.dart';
import 'dart:math' as math;

class AdvancedPitchDisplay extends StatefulWidget {
  final double frequency;
  final double confidence;
  final String noteName;
  final double cents;
  final bool isActive;

  const AdvancedPitchDisplay({
    super.key,
    required this.frequency,
    required this.confidence,
    required this.noteName,
    required this.cents,
    required this.isActive,
  });

  @override
  State<AdvancedPitchDisplay> createState() => _AdvancedPitchDisplayState();
}

class _AdvancedPitchDisplayState extends State<AdvancedPitchDisplay>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _tuningController;
  late Animation<double> _tuningAnimation;

  @override
  void initState() {
    super.initState();
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _tuningController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _tuningAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tuningController, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(AdvancedPitchDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive && !oldWidget.isActive) {
      _tuningController.forward();
    } else if (!widget.isActive && oldWidget.isActive) {
      _tuningController.reverse();
    }
  }

  Color _getTuningColor() {
    final absCents = widget.cents.abs();
    if (absCents < 5) return const Color(0xFF10B981); // Perfect - Green
    if (absCents < 15) return const Color(0xFFF59E0B); // Close - Amber  
    return const Color(0xFFEF4444); // Off - Red
  }

  String _getTuningStatus() {
    final absCents = widget.cents.abs();
    if (absCents < 5) return "완벽!";
    if (absCents < 15) return "거의 맞음";
    return widget.cents > 0 ? "높음" : "낮음";
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _tuningAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_tuningAnimation.value * 0.2),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1F1F23).withOpacity(0.9),
                  const Color(0xFF2D2D32).withOpacity(0.9),
                ],
              ),
              border: Border.all(
                color: _getTuningColor().withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getTuningColor().withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 메인 음표 표시
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            _getTuningColor().withOpacity(0.2),
                            _getTuningColor().withOpacity(0.1),
                          ],
                        ),
                        border: Border.all(
                          color: _getTuningColor().withOpacity(_glowAnimation.value),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        widget.noteName.isEmpty ? "---" : widget.noteName,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: _getTuningColor().withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // 주파수 표시
                Text(
                  "${widget.frequency.toStringAsFixed(1)} Hz",
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 16),

                // 튜닝 상태 표시
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _getTuningColor().withOpacity(0.2),
                  ),
                  child: Text(
                    _getTuningStatus(),
                    style: TextStyle(
                      fontSize: 16,
                      color: _getTuningColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 센트 표시기 (튜닝 정확도)
                TuningMeter(
                  cents: widget.cents,
                  confidence: widget.confidence,
                  color: _getTuningColor(),
                ),

                const SizedBox(height: 16),

                // 신뢰도 표시
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "정확도",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "${(widget.confidence * 100).toStringAsFixed(0)}%",
                      style: TextStyle(
                        color: widget.confidence > 0.8 
                          ? const Color(0xFF10B981)
                          : widget.confidence > 0.5
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFEF4444),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _tuningController.dispose();
    super.dispose();
  }
}

class TuningMeter extends StatelessWidget {
  final double cents;
  final double confidence;
  final Color color;

  const TuningMeter({
    super.key,
    required this.cents,
    required this.confidence,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 배경 메터
          Container(
            width: 240,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withOpacity(0.1),
            ),
          ),

          // 중앙 라인
          Container(
            width: 2,
            height: 30,
            color: Colors.white.withOpacity(0.5),
          ),

          // 센트 표시기
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            left: 120 + (cents.clamp(-50, 50) * 2.4) - 6,
            child: Container(
              width: 12,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

          // 센트 값 표시
          Positioned(
            bottom: 0,
            child: Text(
              "${cents.toStringAsFixed(0)}¢",
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}