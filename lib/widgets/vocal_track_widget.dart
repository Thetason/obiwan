import 'package:flutter/material.dart';
import 'dart:math' as math;

class VocalTrackData {
  final double frequency;
  final double confidence;
  final DateTime timestamp;
  
  const VocalTrackData({
    required this.frequency,
    required this.confidence,
    required this.timestamp,
  });
}

class VocalTrackWidget extends StatefulWidget {
  final List<VocalTrackData> pitchData;
  final Duration animationDuration;
  final double height;
  
  const VocalTrackWidget({
    super.key,
    required this.pitchData,
    this.animationDuration = const Duration(milliseconds: 100),
    this.height = 300,
  });

  @override
  State<VocalTrackWidget> createState() => _VocalTrackWidgetState();
}

class _VocalTrackWidgetState extends State<VocalTrackWidget> 
    with TickerProviderStateMixin {
  
  late AnimationController _trackController;
  late Animation<double> _trackAnimation;
  
  @override
  void initState() {
    super.initState();
    _trackController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _trackAnimation = CurvedAnimation(
      parent: _trackController,
      curve: Curves.easeInOut,
    );
    _trackController.forward();
  }
  
  @override
  void dispose() {
    _trackController.dispose();
    super.dispose();
  }

  // 주파수를 Y 좌표로 변환 (C4=261Hz ~ C5=523Hz 범위)
  double _frequencyToY(double frequency, double height) {
    const double minFreq = 200.0; // 약 G3
    const double maxFreq = 600.0; // 약 D5
    
    if (frequency <= minFreq) return height - 20;
    if (frequency >= maxFreq) return 20;
    
    double normalizedFreq = (frequency - minFreq) / (maxFreq - minFreq);
    return height - (normalizedFreq * (height - 40)) - 20;
  }
  
  // 주파수를 가장 가까운 음표로 변환
  String _frequencyToNote(double frequency) {
    if (frequency <= 0) return '';
    
    const double a4 = 440.0;
    double semitones = 12 * (math.log(frequency / a4) / math.log(2));
    int noteIndex = (69 + semitones.round()) % 12;
    int octave = ((69 + semitones.round()) / 12).floor();
    
    const List<String> noteNames = ['A', 'A#', 'B', 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#'];
    return '${noteNames[noteIndex]}$octave';
  }
  
  // 음정 정확도에 따른 색상
  Color _getPitchColor(double confidence) {
    if (confidence >= 0.8) return const Color(0xFF00BFA6); // 정확 - 초록
    if (confidence >= 0.6) return const Color(0xFFFFB74D); // 근접 - 주황
    if (confidence >= 0.3) return const Color(0xFFFF8A65); // 부정확 - 연한빨강
    return const Color(0xFFE57373); // 매우 부정확 - 빨강
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8F9FA), Color(0xFFFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: VocalTrackPainter(
            pitchData: widget.pitchData,
            animation: _trackAnimation,
            height: widget.height,
          ),
          child: Stack(
            children: [
              // 음표 가이드라인들
              _buildNoteGuidelines(),
              
              // 현재 피치 표시
              if (widget.pitchData.isNotEmpty)
                _buildCurrentPitchIndicator(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNoteGuidelines() {
    // C4부터 C5까지의 주요 음표들
    final Map<String, double> noteFrequencies = {
      'C5': 523.25,
      'B4': 493.88,
      'A4': 440.00,
      'G4': 392.00,
      'F4': 349.23,
      'E4': 329.63,
      'D4': 293.66,
      'C4': 261.63,
    };
    
    return Stack(
      children: noteFrequencies.entries.map((entry) {
        final note = entry.key;
        final freq = entry.value;
        final y = _frequencyToY(freq, widget.height);
        
        return Positioned(
          left: 0,
          right: 0,
          top: y - 1,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF5B8DEE).withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B8DEE).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    note,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: const Color(0xFF5B8DEE).withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildCurrentPitchIndicator() {
    final currentData = widget.pitchData.last;
    final y = _frequencyToY(currentData.frequency, widget.height);
    final color = _getPitchColor(currentData.confidence);
    
    return Positioned(
      right: 20,
      top: y - 12,
      child: AnimatedContainer(
        duration: widget.animationDuration,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _frequencyToNote(currentData.frequency),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VocalTrackPainter extends CustomPainter {
  final List<VocalTrackData> pitchData;
  final Animation<double> animation;
  final double height;
  
  VocalTrackPainter({
    required this.pitchData,
    required this.animation,
    required this.height,
  }) : super(repaint: animation);

  double _frequencyToY(double frequency, double height) {
    const double minFreq = 200.0;
    const double maxFreq = 600.0;
    
    if (frequency <= minFreq) return height - 20;
    if (frequency >= maxFreq) return 20;
    
    double normalizedFreq = (frequency - minFreq) / (maxFreq - minFreq);
    return height - (normalizedFreq * (height - 40)) - 20;
  }
  
  Color _getPitchColor(double confidence) {
    if (confidence >= 0.8) return const Color(0xFF00BFA6);
    if (confidence >= 0.6) return const Color(0xFFFFB74D);
    if (confidence >= 0.3) return const Color(0xFFFF8A65);
    return const Color(0xFFE57373);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (pitchData.isEmpty) return;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    final path = Path();
    final gradientPaint = Paint()..style = PaintingStyle.fill;
    
    for (int i = 0; i < pitchData.length; i++) {
      final data = pitchData[i];
      final x = (i / (pitchData.length - 1).clamp(1, double.infinity)) * size.width;
      final y = _frequencyToY(data.frequency, height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      
      // 각 포인트에 원 그리기
      paint.color = _getPitchColor(data.confidence);
      canvas.drawCircle(
        Offset(x, y), 
        2.0 * animation.value, 
        paint..style = PaintingStyle.fill,
      );
    }
    
    // 피치 라인 그리기
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFF5B8DEE).withOpacity(0.8);
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(VocalTrackPainter oldDelegate) {
    return oldDelegate.pitchData != pitchData || 
           oldDelegate.animation != animation;
  }
}