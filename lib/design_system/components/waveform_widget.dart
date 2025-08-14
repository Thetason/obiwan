import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../tokens.dart';

enum WaveformStyle {
  minimal,     // 심플한 라인 웨이브
  bars,        // 수직 바 스타일
  dots,        // 도트 스타일
  smooth,      // 부드러운 곡선
}

/// Shadcn 스타일의 웨이브폼 위젯
/// 
/// 오디오 시각화를 위한 미니멀하고 접근성 높은 컴포넌트
/// 보컬 트레이닝 앱에서 실시간 오디오 레벨과 녹음 데이터 표시에 사용
class WaveformWidget extends StatefulWidget {
  final List<double> audioData;     // 오디오 데이터 (-1.0 ~ 1.0)
  final WaveformStyle style;        // 웨이브폼 스타일
  final Color? primaryColor;        // 메인 색상
  final Color? backgroundColor;     // 배경 색상
  final double height;              // 위젯 높이
  final bool isPlaying;            // 재생 중 여부
  final double? playbackProgress;   // 재생 진행률 (0.0-1.0)
  final bool isRecording;          // 녹음 중 여부
  final VoidCallback? onTap;       // 탭 이벤트
  final int maxBars;               // 최대 바 개수 (성능 최적화)

  const WaveformWidget({
    super.key,
    required this.audioData,
    this.style = WaveformStyle.minimal,
    this.primaryColor,
    this.backgroundColor,
    this.height = 60,
    this.isPlaying = false,
    this.playbackProgress,
    this.isRecording = false,
    this.onTap,
    this.maxBars = 100,
  });

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (widget.isRecording) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(WaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? DesignTokens.card,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          border: Border.all(
            color: DesignTokens.border,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: _WaveformPainter(
                  audioData: widget.audioData,
                  style: widget.style,
                  primaryColor: widget.primaryColor ?? DesignTokens.primary,
                  isPlaying: widget.isPlaying,
                  playbackProgress: widget.playbackProgress ?? 0.0,
                  isRecording: widget.isRecording,
                  pulseScale: _pulseAnimation.value,
                  maxBars: widget.maxBars,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> audioData;
  final WaveformStyle style;
  final Color primaryColor;
  final bool isPlaying;
  final double playbackProgress;
  final bool isRecording;
  final double pulseScale;
  final int maxBars;

  _WaveformPainter({
    required this.audioData,
    required this.style,
    required this.primaryColor,
    required this.isPlaying,
    required this.playbackProgress,
    required this.isRecording,
    required this.pulseScale,
    required this.maxBars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (audioData.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    switch (style) {
      case WaveformStyle.minimal:
        _drawMinimalWave(canvas, size);
        break;
      case WaveformStyle.bars:
        _drawBars(canvas, size);
        break;
      case WaveformStyle.dots:
        _drawDots(canvas, size);
        break;
      case WaveformStyle.smooth:
        _drawSmoothWave(canvas, size);
        break;
    }

    // 재생 진행률 표시
    if (isPlaying) {
      _drawPlaybackProgress(canvas, size);
    }
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DesignTokens.muted
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 가이드 라인 그리기
    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(DesignTokens.space4, centerY),
      Offset(size.width - DesignTokens.space4, centerY),
      paint,
    );

    // 안내 텍스트
    final textPainter = TextPainter(
      text: TextSpan(
        text: isRecording ? 'Recording...' : 'No audio data',
        style: DesignTokens.caption.copyWith(
          color: DesignTokens.mutedForeground,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        size.width / 2 - textPainter.width / 2,
        size.height / 2 - textPainter.height / 2,
      ),
    );
  }

  void _drawMinimalWave(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final centerY = size.height / 2;
    final stepX = size.width / math.max(1, audioData.length - 1);

    for (int i = 0; i < audioData.length; i++) {
      final x = i * stepX;
      final amplitude = audioData[i] * (size.height / 2 - DesignTokens.space2);
      final y = centerY - amplitude;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawBars(Canvas canvas, Size size) {
    final sampledData = _sampleData(audioData, maxBars);
    final barWidth = size.width / sampledData.length;
    final centerY = size.height / 2;

    for (int i = 0; i < sampledData.length; i++) {
      final amplitude = sampledData[i].abs();
      final barHeight = amplitude * (size.height / 2 - DesignTokens.space2);

      // 녹음 중일 때 펄스 효과 적용
      final effectiveHeight = isRecording ? barHeight * pulseScale : barHeight;

      final paint = Paint()
        ..color = _getBarColor(i, sampledData.length)
        ..style = PaintingStyle.fill;

      final rect = Rect.fromLTWH(
        i * barWidth + 1, // 바 사이 간격
        centerY - effectiveHeight / 2,
        barWidth - 2,
        effectiveHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(DesignTokens.radiusSm),
        ),
        paint,
      );
    }
  }

  void _drawDots(Canvas canvas, Size size) {
    final sampledData = _sampleData(audioData, maxBars);
    final stepX = size.width / sampledData.length;
    final centerY = size.height / 2;

    for (int i = 0; i < sampledData.length; i++) {
      final x = i * stepX + stepX / 2;
      final amplitude = sampledData[i].abs();
      final dotRadius = amplitude * 8 + 2;

      final paint = Paint()
        ..color = _getBarColor(i, sampledData.length)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x, centerY),
        isRecording ? dotRadius * pulseScale : dotRadius,
        paint,
      );
    }
  }

  void _drawSmoothWave(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final centerY = size.height / 2;

    if (audioData.length < 2) return;

    for (int i = 0; i < audioData.length; i++) {
      final x = (i / (audioData.length - 1)) * size.width;
      final amplitude = audioData[i] * (size.height / 2 - DesignTokens.space2);
      final y = centerY - amplitude;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // 부드러운 곡선을 위한 베지어 곡선
        final prevX = ((i - 1) / (audioData.length - 1)) * size.width;
        final prevY = centerY - audioData[i - 1] * (size.height / 2 - DesignTokens.space2);

        final controlPoint1X = prevX + (x - prevX) * 0.5;
        final controlPoint1Y = prevY;
        final controlPoint2X = prevX + (x - prevX) * 0.5;
        final controlPoint2Y = y;

        path.cubicTo(controlPoint1X, controlPoint1Y, controlPoint2X, controlPoint2Y, x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawPlaybackProgress(Canvas canvas, Size size) {
    final progressX = size.width * playbackProgress;

    // 진행률 라인
    final linePaint = Paint()
      ..color = DesignTokens.success
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(progressX, 0),
      Offset(progressX, size.height),
      linePaint,
    );

    // 진행률 인디케이터
    final indicatorPaint = Paint()
      ..color = DesignTokens.success
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(progressX, size.height / 2),
      4,
      indicatorPaint,
    );
  }

  Color _getBarColor(int index, int total) {
    if (isPlaying) {
      final progressIndex = (total * playbackProgress).floor();
      if (index <= progressIndex) {
        return DesignTokens.success;
      }
    }

    return primaryColor.withOpacity(0.7);
  }

  List<double> _sampleData(List<double> data, int maxSamples) {
    if (data.length <= maxSamples) return data;

    final sampledData = <double>[];
    final step = data.length / maxSamples;

    for (int i = 0; i < maxSamples; i++) {
      final startIndex = (i * step).floor();
      final endIndex = math.min(((i + 1) * step).floor(), data.length);

      // RMS 계산으로 더 정확한 샘플링
      double sum = 0;
      for (int j = startIndex; j < endIndex; j++) {
        sum += data[j] * data[j];
      }
      final rms = math.sqrt(sum / (endIndex - startIndex));
      sampledData.add(rms * (data[startIndex] >= 0 ? 1 : -1));
    }

    return sampledData;
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return audioData != oldDelegate.audioData ||
           isPlaying != oldDelegate.isPlaying ||
           playbackProgress != oldDelegate.playbackProgress ||
           isRecording != oldDelegate.isRecording ||
           pulseScale != oldDelegate.pulseScale;
  }
}

/// 실시간 오디오 레벨 표시 위젯
/// 
/// 녹음 중 실시간 오디오 입력 레벨을 표시하는 간단한 컴포넌트
class AudioLevelIndicator extends StatelessWidget {
  final double level;           // 오디오 레벨 (0.0-1.0)
  final bool isActive;         // 활성 상태
  final Color? color;          // 커스텀 색상
  final double height;         // 높이

  const AudioLevelIndicator({
    super.key,
    required this.level,
    this.isActive = true,
    this.color,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? DesignTokens.success;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: DesignTokens.muted,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: isActive ? level.clamp(0.0, 1.0) : 0.0,
        child: Container(
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}

/// 사용 예시:
/// 
/// ```dart
/// // 기본 웨이브폼
/// WaveformWidget(
///   audioData: recordedAudioData,
///   style: WaveformStyle.bars,
///   height: 80,
/// )
/// 
/// // 재생 중 웨이브폼
/// WaveformWidget(
///   audioData: audioData,
///   isPlaying: true,
///   playbackProgress: 0.3,
///   style: WaveformStyle.smooth,
/// )
/// 
/// // 실시간 레벨 표시
/// AudioLevelIndicator(
///   level: currentAudioLevel,
///   isActive: isRecording,
/// )
/// ```