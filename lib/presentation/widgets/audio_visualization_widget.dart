import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../domain/entities/audio_data.dart';

class AudioVisualizationWidget extends StatefulWidget {
  final AudioData? audioData;
  final List<double> pitchData;
  final bool isRecording;
  
  const AudioVisualizationWidget({
    super.key,
    this.audioData,
    this.pitchData = const [],
    this.isRecording = false,
  });
  
  @override
  State<AudioVisualizationWidget> createState() => _AudioVisualizationWidgetState();
}

class _AudioVisualizationWidgetState extends State<AudioVisualizationWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
    }
  }
  
  @override
  void didUpdateWidget(AudioVisualizationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 상단 정보 표시
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isRecording ? '녹음 중...' : '음성 분석 준비',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.isRecording)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 파형 및 피치 시각화
          Expanded(
            child: widget.audioData != null || widget.pitchData.isNotEmpty
                ? Row(
                    children: [
                      // 파형 시각화 (왼쪽 50%)
                      Expanded(
                        flex: 1,
                        child: _buildWaveform(),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // 피치 곡선 (오른쪽 50%)
                      Expanded(
                        flex: 1,
                        child: _buildPitchCurve(),
                      ),
                    ],
                  )
                : _buildPlaceholder(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWaveform() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: WaveformPainter(
          waveformData: widget.audioData?.samples ?? [],
          isRecording: widget.isRecording,
        ),
        child: Container(),
      ),
    );
  }
  
  Widget _buildPitchCurve() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: PitchCurvePainter(
          pitchData: widget.pitchData,
          isRecording: widget.isRecording,
        ),
        child: Container(),
      ),
    );
  }
  
  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic,
              size: 48,
              color: Colors.white54,
            ),
            SizedBox(height: 8),
            Text(
              '녹음 버튼을 눌러 분석을 시작하세요',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final bool isRecording;
  
  WaveformPainter({
    required this.waveformData,
    required this.isRecording,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;
    
    final paint = Paint()
      ..color = isRecording ? Colors.green : Colors.blue
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    final centerY = size.height / 2;
    final stepX = size.width / (waveformData.length - 1);
    
    for (int i = 0; i < waveformData.length; i++) {
      final x = i * stepX;
      final y = centerY + (waveformData[i] * centerY * 0.8);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // 중심선 그리기
    final centerLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 0.5;
    
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      centerLinePaint,
    );
  }
  
  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
           oldDelegate.isRecording != isRecording;
  }
}

class PitchCurvePainter extends CustomPainter {
  final List<double> pitchData;
  final bool isRecording;
  
  PitchCurvePainter({
    required this.pitchData,
    required this.isRecording,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (pitchData.isEmpty) return;
    
    // 피치 범위 설정 (80Hz ~ 800Hz)
    const minPitch = 80.0;
    const maxPitch = 800.0;
    
    final paint = Paint()
      ..color = isRecording ? Colors.orange : Colors.purple
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    final stepX = size.width / (pitchData.length - 1);
    
    // 유성음 구간만 그리기
    bool pathStarted = false;
    
    for (int i = 0; i < pitchData.length; i++) {
      final pitch = pitchData[i];
      
      if (pitch > 0 && pitch >= minPitch && pitch <= maxPitch) {
        final x = i * stepX;
        final normalizedPitch = (pitch - minPitch) / (maxPitch - minPitch);
        final y = size.height * (1 - normalizedPitch);
        
        if (!pathStarted) {
          path.moveTo(x, y);
          pathStarted = true;
        } else {
          path.lineTo(x, y);
        }
      } else {
        pathStarted = false;
      }
    }
    
    canvas.drawPath(path, paint);
    
    // 음정 가이드라인 그리기
    _drawPitchGuideLines(canvas, size);
  }
  
  void _drawPitchGuideLines(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 0.5;
    
    final textPaint = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    // 주요 음정 표시 (C4=261.63Hz, C5=523.25Hz 등)
    final pitchMarkers = {
      261.63: 'C4',
      293.66: 'D4',
      329.63: 'E4',
      349.23: 'F4',
      392.00: 'G4',
      440.00: 'A4',
      493.88: 'B4',
      523.25: 'C5',
    };
    
    const minPitch = 80.0;
    const maxPitch = 800.0;
    
    for (final entry in pitchMarkers.entries) {
      final pitch = entry.key;
      final note = entry.value;
      
      if (pitch >= minPitch && pitch <= maxPitch) {
        final normalizedPitch = (pitch - minPitch) / (maxPitch - minPitch);
        final y = size.height * (1 - normalizedPitch);
        
        // 가이드라인 그리기
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          guidePaint,
        );
        
        // 음정 라벨 그리기
        textPaint.text = TextSpan(
          text: note,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
          ),
        );
        textPaint.layout();
        textPaint.paint(canvas, Offset(5, y - 6));
      }
    }
  }
  
  @override
  bool shouldRepaint(PitchCurvePainter oldDelegate) {
    return oldDelegate.pitchData != pitchData ||
           oldDelegate.isRecording != isRecording;
  }
}