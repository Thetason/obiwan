import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../core/theme/app_theme.dart';
import '../providers/audio_analysis_provider.dart';

/// Enhanced Pitch Visualization Widget with AI Features
class EnhancedPitchVisualizationWidget extends ConsumerStatefulWidget {
  const EnhancedPitchVisualizationWidget({super.key});

  @override
  ConsumerState<EnhancedPitchVisualizationWidget> createState() =>
      _EnhancedPitchVisualizationWidgetState();
}

class _EnhancedPitchVisualizationWidgetState
    extends ConsumerState<EnhancedPitchVisualizationWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _emotionController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _emotionAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _emotionController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.linear),
    );

    _emotionAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _emotionController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _emotionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = ref.watch(isRecordingProvider);
    final currentNote = ref.watch(currentNoteProvider);
    final pitchAccuracy = ref.watch(pitchAccuracyProvider);
    final cents = ref.watch(centsProvider);
    final emotion = ref.watch(emotionProvider);
    final style = ref.watch(styleProvider);
    final voiceQuality = ref.watch(voiceQualityProvider);
    final realtimeCoaching = ref.watch(realtimeCoachingProvider);
    final pitchData = ref.watch(audioAnalysisProvider).pitchData;

    return Container(
      decoration: AppTheme.glassmorphismDecoration,
      child: Column(
        children: [
          // Enhanced Header with AI Status
          _buildEnhancedHeader(isRecording, emotion, style),

          // Main Visualization Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Enhanced Circular Pitch Meter with AI
                  Expanded(
                    flex: 3,
                    child: _buildEnhancedCircularMeter(
                      currentNote,
                      pitchAccuracy,
                      cents,
                      voiceQuality,
                      emotion,
                      isRecording,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Real-time Coaching Tips
                  if (realtimeCoaching.isNotEmpty) ...[
                    _buildRealtimeCoachingPanel(realtimeCoaching),
                    const SizedBox(height: 16),
                  ],

                  // Enhanced Note Display with AI Metrics
                  _buildEnhancedNoteDisplay(
                    currentNote,
                    pitchAccuracy,
                    cents,
                    voiceQuality,
                    emotion,
                    style,
                  ),

                  const SizedBox(height: 16),

                  // Pitch History with AI Analysis
                  Expanded(
                    flex: 1,
                    child: _buildEnhancedPitchHistory(pitchData),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedHeader(bool isRecording, String emotion, String style) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Recording Status with Emotion
          _buildRecordingStatusIcon(isRecording, emotion),
          const SizedBox(width: 12),
          
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 음정 분석',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (style != 'Unknown')
                  Text(
                    '스타일: $style',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          
          // AI Status Indicator
          _buildAIStatusIndicator(isRecording),
        ],
      ),
    );
  }

  Widget _buildRecordingStatusIcon(bool isRecording, String emotion) {
    final emotionColor = _getEmotionColor(emotion);
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRecording 
                ? emotionColor.withOpacity(0.2)
                : AppTheme.surfaceColor.withOpacity(0.3),
            border: Border.all(
              color: isRecording ? emotionColor : AppTheme.textMuted,
              width: 2,
            ),
          ),
          child: Transform.scale(
            scale: isRecording ? _pulseAnimation.value : 1.0,
            child: Icon(
              isRecording ? Icons.mic : Icons.mic_off,
              color: isRecording ? emotionColor : AppTheme.textMuted,
              size: 20,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAIStatusIndicator(bool isRecording) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isRecording 
            ? AppTheme.accentColor.withOpacity(0.2)
            : AppTheme.surfaceColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRecording ? AppTheme.accentColor : AppTheme.textMuted,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.psychology,
            size: 16,
            color: isRecording ? AppTheme.accentColor : AppTheme.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            isRecording ? 'AI 분석중' : 'AI 대기',
            style: TextStyle(
              color: isRecording ? AppTheme.accentColor : AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedCircularMeter(
    String currentNote,
    double pitchAccuracy,
    double cents,
    double voiceQuality,
    String emotion,
    bool isRecording,
  ) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseAnimation,
        _waveAnimation,
        _emotionAnimation,
      ]),
      builder: (context, child) {
        return CustomPaint(
          size: const Size(300, 300),
          painter: EnhancedCircularPitchPainter(
            currentNote: currentNote,
            pitchAccuracy: pitchAccuracy,
            cents: cents,
            voiceQuality: voiceQuality,
            emotion: emotion,
            pulseValue: _pulseAnimation.value,
            waveValue: _waveAnimation.value,
            emotionValue: _emotionAnimation.value,
            isRecording: isRecording,
          ),
        );
      },
    );
  }

  Widget _buildRealtimeCoachingPanel(List<String> coachingTips) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentColor.withOpacity(0.1),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: AppTheme.accentColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '실시간 코칭',
                style: TextStyle(
                  color: AppTheme.accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...coachingTips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $tip',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildEnhancedNoteDisplay(
    String currentNote,
    double pitchAccuracy,
    double cents,
    double voiceQuality,
    String emotion,
    String style,
  ) {
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
      child: Column(
        children: [
          // Top row: Note and Accuracy
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetricDisplay('현재 음정', currentNote.isEmpty ? '--' : currentNote, 
                  _getAccuracyColor(pitchAccuracy)),
              _buildVerticalDivider(),
              _buildMetricDisplay('정확도', '${pitchAccuracy.toStringAsFixed(1)}%', 
                  _getAccuracyColor(pitchAccuracy)),
              _buildVerticalDivider(),
              _buildMetricDisplay('편차', '${cents > 0 ? '+' : ''}${cents.toStringAsFixed(0)}¢', 
                  _getCentsColor(cents)),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Bottom row: AI Metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetricDisplay('음성 품질', '${(voiceQuality * 100).toStringAsFixed(0)}%', 
                  _getQualityColor(voiceQuality)),
              _buildVerticalDivider(),
              _buildMetricDisplay('감정', emotion, _getEmotionColor(emotion)),
              _buildVerticalDivider(),
              _buildMetricDisplay('스타일', style, AppTheme.textPrimary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDisplay(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 30,
      color: AppTheme.textMuted.withOpacity(0.3),
    );
  }

  Widget _buildEnhancedPitchHistory(List<double> pitchData) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        size: const Size(double.infinity, 80),
        painter: EnhancedPitchHistoryPainter(
          pitchHistory: pitchData,
          waveAnimation: _waveAnimation.value,
        ),
      ),
    );
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

  Color _getQualityColor(double quality) {
    if (quality >= 0.8) return AppTheme.successColor;
    if (quality >= 0.6) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy': return Colors.amber;
      case 'sad': return Colors.blue;
      case 'angry': return Colors.red;
      case 'calm': return Colors.green;
      case 'excited': return Colors.orange;
      default: return AppTheme.textPrimary;
    }
  }
}

/// Enhanced Circular Pitch Painter with AI Features
class EnhancedCircularPitchPainter extends CustomPainter {
  final String currentNote;
  final double pitchAccuracy;
  final double cents;
  final double voiceQuality;
  final String emotion;
  final double pulseValue;
  final double waveValue;
  final double emotionValue;
  final bool isRecording;

  EnhancedCircularPitchPainter({
    required this.currentNote,
    required this.pitchAccuracy,
    required this.cents,
    required this.voiceQuality,
    required this.emotion,
    required this.pulseValue,
    required this.waveValue,
    required this.emotionValue,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 30;

    _drawBackgroundCircles(canvas, center, radius);
    _drawAccuracyArc(canvas, center, radius);
    _drawVoiceQualityRing(canvas, center, radius);
    _drawEmotionIndicators(canvas, center, radius);
    _drawCenterDisplay(canvas, center);
    _drawCentsIndicator(canvas, center, radius);
    
    if (isRecording) {
      _drawPulseEffect(canvas, center, radius);
    }
  }

  void _drawBackgroundCircles(Canvas canvas, Offset center, double radius) {
    // Outer background
    final bgPaint = Paint()
      ..color = AppTheme.surfaceColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius + 10, bgPaint);

    // Inner background
    final innerBgPaint = Paint()
      ..color = AppTheme.surfaceColor.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 20, innerBgPaint);
  }

  void _drawAccuracyArc(Canvas canvas, Offset center, double radius) {
    final accuracyPaint = Paint()
      ..color = _getAccuracyColor(pitchAccuracy)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (pitchAccuracy / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      accuracyPaint,
    );
  }

  void _drawVoiceQualityRing(Canvas canvas, Offset center, double radius) {
    final qualityPaint = Paint()
      ..color = _getQualityColor(voiceQuality).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final qualitySweep = (voiceQuality) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 15),
      -math.pi / 2,
      qualitySweep,
      false,
      qualityPaint,
    );
  }

  void _drawEmotionIndicators(Canvas canvas, Offset center, double radius) {
    final emotionColor = _getEmotionColor(emotion);
    final emotionPaint = Paint()
      ..color = emotionColor.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    // Draw emotion dots around the circle
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      final dotRadius = 4 + 2 * math.sin(emotionValue * 2 * math.pi + i);
      final dotCenter = center + Offset(
        (radius + 20) * math.cos(angle),
        (radius + 20) * math.sin(angle),
      );
      
      canvas.drawCircle(dotCenter, dotRadius, emotionPaint);
    }
  }

  void _drawCenterDisplay(Canvas canvas, Offset center) {
    // Note display
    final noteTextPainter = TextPainter(
      text: TextSpan(
        text: currentNote.isEmpty ? '--' : currentNote,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    noteTextPainter.layout();
    noteTextPainter.paint(
      canvas,
      center - Offset(noteTextPainter.width / 2, noteTextPainter.height / 2 + 10),
    );

    // Accuracy percentage below note
    final accuracyTextPainter = TextPainter(
      text: TextSpan(
        text: '${pitchAccuracy.toStringAsFixed(1)}%',
        style: TextStyle(
          color: _getAccuracyColor(pitchAccuracy),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    accuracyTextPainter.layout();
    accuracyTextPainter.paint(
      canvas,
      center - Offset(accuracyTextPainter.width / 2, -15),
    );
  }

  void _drawCentsIndicator(Canvas canvas, Offset center, double radius) {
    if (cents.abs() > 5) {
      final centsAngle = (cents / 50).clamp(-1.0, 1.0) * math.pi / 4;
      final indicatorEnd = center + Offset(
        radius * 0.7 * math.cos(-math.pi / 2 + centsAngle),
        radius * 0.7 * math.sin(-math.pi / 2 + centsAngle),
      );

      final centsIndicatorPaint = Paint()
        ..color = _getCentsColor(cents)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(center, indicatorEnd, centsIndicatorPaint);
    }
  }

  void _drawPulseEffect(Canvas canvas, Offset center, double radius) {
    final pulsePaint = Paint()
      ..color = AppTheme.accentColor.withOpacity(0.3 * (2 - pulseValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    
    canvas.drawCircle(center, radius * pulseValue, pulsePaint);
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

  Color _getQualityColor(double quality) {
    if (quality >= 0.8) return AppTheme.successColor;
    if (quality >= 0.6) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy': return Colors.amber;
      case 'sad': return Colors.blue;
      case 'angry': return Colors.red;
      case 'calm': return Colors.green;
      case 'excited': return Colors.orange;
      default: return AppTheme.textPrimary;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

/// Enhanced Pitch History Painter
class EnhancedPitchHistoryPainter extends CustomPainter {
  final List<double> pitchHistory;
  final double waveAnimation;

  EnhancedPitchHistoryPainter({
    required this.pitchHistory,
    required this.waveAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pitchHistory.isEmpty || pitchHistory.length < 2) return;

    _drawGridLines(canvas, size);
    _drawPitchCurve(canvas, size);
    _drawGradientFill(canvas, size);
  }

  void _drawGridLines(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppTheme.textMuted.withOpacity(0.1)
      ..strokeWidth = 1;

    // Horizontal grid lines
    for (int i = 1; i < 4; i++) {
      final y = (i / 4) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Vertical grid lines
    for (int i = 1; i < 5; i++) {
      final x = (i / 5) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  void _drawPitchCurve(Canvas canvas, Size size) {
    final maxPitch = pitchHistory.reduce(math.max);
    final minPitch = pitchHistory.reduce(math.min);
    final range = maxPitch - minPitch;
    
    if (range == 0) return;

    final path = Path();
    final paint = Paint()
      ..color = AppTheme.accentColor.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < pitchHistory.length; i++) {
      final x = (i / (pitchHistory.length - 1)) * size.width;
      final normalizedPitch = (pitchHistory[i] - minPitch) / range;
      final y = size.height - (normalizedPitch * size.height);
      
      // Add wave effect
      final waveOffset = math.sin(waveAnimation + i * 0.1) * 2;
      
      if (i == 0) {
        path.moveTo(x, y + waveOffset);
      } else {
        path.lineTo(x, y + waveOffset);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawGradientFill(Canvas canvas, Size size) {
    final maxPitch = pitchHistory.reduce(math.max);
    final minPitch = pitchHistory.reduce(math.min);
    final range = maxPitch - minPitch;
    
    if (range == 0) return;

    final path = Path();
    
    // Create filled area path
    for (int i = 0; i < pitchHistory.length; i++) {
      final x = (i / (pitchHistory.length - 1)) * size.width;
      final normalizedPitch = (pitchHistory[i] - minPitch) / range;
      final y = size.height - (normalizedPitch * size.height);
      
      if (i == 0) {
        path.moveTo(x, size.height);
        path.lineTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    path.lineTo(size.width, size.height);
    path.close();

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.accentColor.withOpacity(0.3),
          AppTheme.accentColor.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, gradientPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}