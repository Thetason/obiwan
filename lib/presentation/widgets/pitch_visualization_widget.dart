import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/app_theme.dart';

class PitchVisualizationWidget extends StatefulWidget {
  final double currentPitch;
  final double targetPitch;
  final List<double> pitchHistory;
  final bool isRecording;

  const PitchVisualizationWidget({
    super.key,
    required this.currentPitch,
    required this.targetPitch,
    required this.pitchHistory,
    required this.isRecording,
  });

  @override
  State<PitchVisualizationWidget> createState() => _PitchVisualizationWidgetState();
}

class _PitchVisualizationWidgetState extends State<PitchVisualizationWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _waveAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassmorphismDecoration,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.music_note,
                  color: widget.isRecording ? AppTheme.accentColor : AppTheme.textMuted,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  '음정 분석',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildPitchIndicator(),
              ],
            ),
          ),
          
          // Main Pitch Visualizer
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Circular Pitch Meter
                  Expanded(
                    flex: 2,
                    child: _buildCircularPitchMeter(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Linear Pitch History
                  Expanded(
                    flex: 1,
                    child: _buildPitchHistory(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Note and Frequency Display
                  _buildNoteDisplay(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPitchIndicator() {
    final accuracy = _calculatePitchAccuracy();
    final color = _getAccuracyColor(accuracy);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${accuracy.toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularPitchMeter() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _waveAnimation]),
      builder: (context, child) {
        return CustomPaint(
          size: const Size(300, 300),
          painter: CircularPitchPainter(
            currentPitch: widget.currentPitch,
            targetPitch: widget.targetPitch,
            accuracy: _calculatePitchAccuracy(),
            pulseValue: _pulseAnimation.value,
            waveValue: _waveAnimation.value,
            isRecording: widget.isRecording,
          ),
        );
      },
    );
  }

  Widget _buildPitchHistory() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        size: const Size(double.infinity, 60),
        painter: PitchHistoryPainter(
          pitchHistory: widget.pitchHistory,
          targetPitch: widget.targetPitch,
        ),
      ),
    );
  }

  Widget _buildNoteDisplay() {
    final note = _frequencyToNote(widget.currentPitch);
    final cents = _calculateCents(widget.currentPitch, widget.targetPitch);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.2),
            AppTheme.secondaryColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Text(
                '현재 음정',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                note,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            color: AppTheme.textMuted.withOpacity(0.3),
          ),
          Column(
            children: [
              Text(
                '주파수',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.currentPitch.toStringAsFixed(1)} Hz',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            color: AppTheme.textMuted.withOpacity(0.3),
          ),
          Column(
            children: [
              Text(
                '편차',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${cents > 0 ? '+' : ''}${cents.toStringAsFixed(0)} 센트',
                style: TextStyle(
                  color: _getCentsColor(cents),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _calculatePitchAccuracy() {
    if (widget.currentPitch == 0 || widget.targetPitch == 0) return 0;
    final cents = _calculateCents(widget.currentPitch, widget.targetPitch);
    return math.max(0, 100 - cents.abs());
  }

  double _calculateCents(double current, double target) {
    if (current == 0 || target == 0) return 0;
    return 1200 * math.log(current / target) / math.ln2;
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return AppTheme.successColor;
    if (accuracy >= 70) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  Color _getCentsColor(double cents) {
    final absCents = cents.abs();
    if (absCents <= 10) return AppTheme.successColor;
    if (absCents <= 25) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  String _frequencyToNote(double frequency) {
    if (frequency <= 0) return '--';
    
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const a4 = 440.0;
    final semitonesFromA4 = 12 * math.log(frequency / a4) / math.ln2;
    final noteIndex = (semitonesFromA4.round() + 9) % 12;
    final octave = 4 + ((semitonesFromA4.round() + 9) ~/ 12);
    
    return '${noteNames[noteIndex]}$octave';
  }
}

class CircularPitchPainter extends CustomPainter {
  final double currentPitch;
  final double targetPitch;
  final double accuracy;
  final double pulseValue;
  final double waveValue;
  final bool isRecording;

  CircularPitchPainter({
    required this.currentPitch,
    required this.targetPitch,
    required this.accuracy,
    required this.pulseValue,
    required this.waveValue,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    
    // Background circle
    final bgPaint = Paint()
      ..color = AppTheme.surfaceColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, bgPaint);
    
    // Accuracy arc
    final accuracyPaint = Paint()
      ..color = _getAccuracyColor(accuracy)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    
    final sweepAngle = (accuracy / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      accuracyPaint,
    );
    
    // Pulse effect when recording
    if (isRecording) {
      final pulsePaint = Paint()
        ..color = AppTheme.accentColor.withOpacity(0.3 * (2 - pulseValue))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;
      canvas.drawCircle(center, radius * pulseValue, pulsePaint);
    }
    
    // Center frequency display
    final textPainter = TextPainter(
      text: TextSpan(
        text: currentPitch > 0 ? '${currentPitch.toStringAsFixed(0)}' : '--',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
    
    // Target indicator
    if (targetPitch > 0) {
      final targetAngle = -math.pi / 2;
      final targetPos = center + Offset(
        radius * math.cos(targetAngle),
        radius * math.sin(targetAngle),
      );
      
      final targetPaint = Paint()
        ..color = AppTheme.primaryColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(targetPos, 8, targetPaint);
    }
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return AppTheme.successColor;
    if (accuracy >= 70) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class PitchHistoryPainter extends CustomPainter {
  final List<double> pitchHistory;
  final double targetPitch;

  PitchHistoryPainter({
    required this.pitchHistory,
    required this.targetPitch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pitchHistory.isEmpty) return;
    
    final paint = Paint()
      ..color = AppTheme.accentColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    final maxPitch = pitchHistory.reduce(math.max);
    final minPitch = pitchHistory.reduce(math.min);
    final range = maxPitch - minPitch;
    
    if (range == 0) return;
    
    for (int i = 0; i < pitchHistory.length; i++) {
      final x = (i / (pitchHistory.length - 1)) * size.width;
      final y = size.height - ((pitchHistory[i] - minPitch) / range) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // Target line
    if (targetPitch > 0 && targetPitch >= minPitch && targetPitch <= maxPitch) {
      final targetY = size.height - ((targetPitch - minPitch) / range) * size.height;
      final targetPaint = Paint()
        ..color = AppTheme.primaryColor.withOpacity(0.7)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(
        Offset(0, targetY),
        Offset(size.width, targetY),
        targetPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}