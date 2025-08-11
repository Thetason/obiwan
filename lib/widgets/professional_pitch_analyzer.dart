import 'package:flutter/material.dart';
import 'dart:math' as math;

class ProfessionalPitchData {
  final double frequency;
  final double confidence;
  final double startTime;
  final double duration;
  final String noteName;
  
  const ProfessionalPitchData({
    required this.frequency,
    required this.confidence, 
    required this.startTime,
    required this.duration,
    required this.noteName,
  });
}

class ProfessionalPitchAnalyzer extends StatefulWidget {
  final List<ProfessionalPitchData> pitchData;
  final double totalDuration;
  final double height;
  
  const ProfessionalPitchAnalyzer({
    super.key,
    required this.pitchData,
    required this.totalDuration, 
    this.height = 400,
  });

  @override
  State<ProfessionalPitchAnalyzer> createState() => _ProfessionalPitchAnalyzerState();
}

class _ProfessionalPitchAnalyzerState extends State<ProfessionalPitchAnalyzer>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 음표별 색상 정의 (F♯3 ~ C4 범위, 보라→파랑→초록→노랑→주황)
  Color _getNoteColor(double frequency) {
    // F♯3 = 185Hz, C4 = 261Hz
    const double minFreq = 180.0; // F♯3 근처
    const double maxFreq = 270.0; // C4 근처
    
    double normalizedFreq = ((frequency - minFreq) / (maxFreq - minFreq)).clamp(0.0, 1.0);
    
    // 5단계 색상 그라디언트 (보라→파랑→초록→노랑→주황)
    if (normalizedFreq < 0.2) {
      // 보라 → 파랑
      return Color.lerp(
        const Color(0xFF8B5CF6), // 보라
        const Color(0xFF3B82F6), // 파랑
        (normalizedFreq / 0.2),
      )!;
    } else if (normalizedFreq < 0.4) {
      // 파랑 → 초록  
      return Color.lerp(
        const Color(0xFF3B82F6), // 파랑
        const Color(0xFF10B981), // 초록
        ((normalizedFreq - 0.2) / 0.2),
      )!;
    } else if (normalizedFreq < 0.6) {
      // 초록 → 노랑
      return Color.lerp(
        const Color(0xFF10B981), // 초록
        const Color(0xFFF59E0B), // 노랑
        ((normalizedFreq - 0.4) / 0.2),
      )!;
    } else if (normalizedFreq < 0.8) {
      // 노랑 → 주황
      return Color.lerp(
        const Color(0xFFF59E0B), // 노랑
        const Color(0xFFEA580C), // 주황
        ((normalizedFreq - 0.6) / 0.2),
      )!;
    } else {
      // 주황 → 빨강
      return Color.lerp(
        const Color(0xFFEA580C), // 주황
        const Color(0xFFDC2626), // 빨강
        ((normalizedFreq - 0.8) / 0.2),
      )!;
    }
  }
  
  // 주파수를 Y 좌표로 변환
  double _frequencyToY(double frequency) {
    // F♯3 = 185Hz (하단), C4 = 261Hz (상단)
    const double minFreq = 180.0;
    const double maxFreq = 270.0;
    
    double normalizedFreq = ((frequency - minFreq) / (maxFreq - minFreq)).clamp(0.0, 1.0);
    return widget.height - (normalizedFreq * widget.height * 0.8) - widget.height * 0.1;
  }
  
  // 주파수를 음표로 변환
  String _frequencyToNote(double frequency) {
    const double a4 = 440.0;
    double semitones = 12 * (math.log(frequency / a4) / math.log(2));
    int noteIndex = (69 + semitones.round()) % 12;
    int octave = ((69 + semitones.round()) / 12).floor();
    
    const List<String> noteNames = ['A', 'A♯', 'B', 'C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯'];
    return '${noteNames[noteIndex]}$octave';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            // 왼쪽: 세로 음계 스케일
            _buildVerticalNoteScale(),
            
            // 오른쪽: 시간축 피치 트랙
            Expanded(
              child: _buildPitchTrack(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildVerticalNoteScale() {
    return Container(
      width: 80,
      height: widget.height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFDC2626), // 빨강 (높은 음)
            Color(0xFFEA580C), // 주황
            Color(0xFFF59E0B), // 노랑
            Color(0xFF10B981), // 초록
            Color(0xFF3B82F6), // 파랑
            Color(0xFF8B5CF6), // 보라 (낮은 음)
          ],
        ),
      ),
      child: Stack(
        children: [
          // 음표 라벨들
          ..._buildNoteLabels(),
        ],
      ),
    );
  }
  
  List<Widget> _buildNoteLabels() {
    // F♯3부터 C4까지의 주요 음표들
    final List<Map<String, dynamic>> notes = [
      {'name': 'C4', 'freq': 261.63, 'color': Colors.white},
      {'name': 'B3', 'freq': 246.94, 'color': Colors.white},  
      {'name': 'A♯3', 'freq': 233.08, 'color': Colors.white70},
      {'name': 'A3', 'freq': 220.00, 'color': Colors.white},
      {'name': 'G♯3', 'freq': 207.65, 'color': Colors.white70},
      {'name': 'G3', 'freq': 196.00, 'color': Colors.white},
      {'name': 'F♯3', 'freq': 185.00, 'color': Colors.white},
    ];
    
    return notes.map((note) {
      final y = _frequencyToY(note['freq']);
      
      return Positioned(
        left: 8,
        right: 8,
        top: y - 12,
        child: Container(
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            note['name'],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: note['color'],
            ),
          ),
        ),
      );
    }).toList();
  }
  
  Widget _buildPitchTrack() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
      ),
      child: CustomPaint(
        painter: ProfessionalPitchPainter(
          pitchData: widget.pitchData,
          totalDuration: widget.totalDuration,
          animation: _fadeAnimation,
          height: widget.height,
          getNoteColor: _getNoteColor,
          frequencyToY: _frequencyToY,
          frequencyToNote: _frequencyToNote,
        ),
        child: Stack(
          children: [
            // 시간 격자선
            ..._buildTimeGridLines(),
            
            // 피치 블록들
            ..._buildPitchBlocks(),
          ],
        ),
      ),
    );
  }
  
  List<Widget> _buildTimeGridLines() {
    if (widget.totalDuration <= 0) return [];
    
    List<Widget> lines = [];
    for (double time = 0; time <= widget.totalDuration; time += 1.0) {
      final x = (time / widget.totalDuration) * 400; // 대략적인 폭
      
      lines.add(
        Positioned(
          left: x,
          top: 0,
          bottom: 0,
          child: Container(
            width: 1,
            color: const Color(0xFFE5E7EB).withOpacity(0.5),
          ),
        ),
      );
    }
    
    return lines;
  }
  
  List<Widget> _buildPitchBlocks() {
    return widget.pitchData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      
      final x = (data.startTime / widget.totalDuration) * 400.0;
      final width = math.max(40.0, (data.duration / widget.totalDuration) * 400.0);
      final y = _frequencyToY(data.frequency);
      final color = _getNoteColor(data.frequency);
      
      return AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          final delay = (index / widget.pitchData.length) * 0.5;
          final opacity = ((1 - delay) * _fadeAnimation.value).clamp(0.0, 1.0);
          
          return Positioned(
            left: x,
            top: y - 15,
            child: Transform.scale(
              scale: _fadeAnimation.value,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: width,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      data.noteName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }
}

class ProfessionalPitchPainter extends CustomPainter {
  final List<ProfessionalPitchData> pitchData;
  final double totalDuration;
  final Animation<double> animation;
  final double height;
  final Color Function(double) getNoteColor;
  final double Function(double) frequencyToY;
  final String Function(double) frequencyToNote;
  
  ProfessionalPitchPainter({
    required this.pitchData,
    required this.totalDuration,
    required this.animation,
    required this.height,
    required this.getNoteColor,
    required this.frequencyToY,
    required this.frequencyToNote,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (pitchData.isEmpty) return;
    
    // 실시간 연결 곡선 그리기
    final path = Path();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = const Color(0xFFEA580C);
    
    for (int i = 0; i < pitchData.length; i++) {
      final data = pitchData[i];
      final x = (data.startTime / totalDuration) * size.width;
      final y = frequencyToY(data.frequency);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // 현재 위치 점
    if (pitchData.isNotEmpty) {
      final currentData = pitchData.last;
      final x = (currentData.startTime / totalDuration) * size.width;
      final y = frequencyToY(currentData.frequency);
      
      final pointPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.black;
      
      canvas.drawCircle(Offset(x, y), 6 * animation.value, pointPaint);
      
      final innerPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white;
      
      canvas.drawCircle(Offset(x, y), 3 * animation.value, innerPaint);
    }
  }

  @override
  bool shouldRepaint(ProfessionalPitchPainter oldDelegate) {
    return oldDelegate.pitchData != pitchData || 
           oldDelegate.animation != animation;
  }
}