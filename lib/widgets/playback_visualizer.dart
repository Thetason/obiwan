import 'package:flutter/material.dart';
import 'dart:math' as math;

class PlaybackVisualizer extends StatefulWidget {
  final List<double> audioData;
  final bool isPlaying;
  
  const PlaybackVisualizer({
    Key? key,
    required this.audioData,
    required this.isPlaying,
  }) : super(key: key);
  
  @override
  State<PlaybackVisualizer> createState() => _PlaybackVisualizerState();
}

class _PlaybackVisualizerState extends State<PlaybackVisualizer>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  double _playbackPosition = 0.0;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    
    if (widget.isPlaying) {
      _animationController.forward();
    }
  }
  
  @override
  void didUpdateWidget(PlaybackVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _animationController.forward();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _animationController.stop();
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        _playbackPosition = _animationController.value;
        
        return CustomPaint(
          painter: WaveformPainter(
            audioData: widget.audioData,
            playbackPosition: _playbackPosition,
            primaryColor: const Color(0xFF7C4DFF),
            secondaryColor: const Color(0xFF9C88FF),
          ),
        );
      },
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> audioData;
  final double playbackPosition;
  final Color primaryColor;
  final Color secondaryColor;
  
  WaveformPainter({
    required this.audioData,
    required this.playbackPosition,
    required this.primaryColor,
    required this.secondaryColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (audioData.isEmpty) return;
    
    final paint = Paint()
      ..style = PaintingStyle.fill;
    
    final barWidth = size.width / 100;
    final barSpacing = 2.0;
    final totalBars = (size.width / (barWidth + barSpacing)).floor();
    
    for (int i = 0; i < totalBars; i++) {
      final dataIndex = (i * audioData.length ~/ totalBars).clamp(0, audioData.length - 1);
      final amplitude = audioData[dataIndex].abs();
      final barHeight = amplitude * size.height * 0.8;
      
      final x = i * (barWidth + barSpacing);
      final progress = i / totalBars;
      
      // 색상 결정 (재생 위치에 따라)
      if (progress < playbackPosition) {
        // 재생된 부분 - 그라데이션
        paint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primaryColor, secondaryColor],
        ).createShader(Rect.fromLTWH(x, 0, barWidth, size.height));
      } else {
        // 아직 재생 안된 부분
        paint.shader = null;
        paint.color = Colors.white.withOpacity(0.3);
      }
      
      // 바 그리기
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          size.height / 2 - barHeight / 2,
          barWidth,
          barHeight,
        ),
        const Radius.circular(2),
      );
      
      canvas.drawRRect(rect, paint);
    }
    
    // 재생 위치 표시선
    if (playbackPosition > 0 && playbackPosition < 1) {
      final playbackPaint = Paint()
        ..color = primaryColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      
      final playbackX = size.width * playbackPosition;
      canvas.drawLine(
        Offset(playbackX, 0),
        Offset(playbackX, size.height),
        playbackPaint,
      );
    }
  }
  
  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.playbackPosition != playbackPosition ||
           oldDelegate.audioData != audioData;
  }
}