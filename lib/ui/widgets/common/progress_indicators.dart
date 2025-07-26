import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';

/// Animated circular progress indicator with customizable styling
class AnimatedCircularProgress extends StatefulWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color? progressColor;
  final Color? backgroundColor;
  final Duration animationDuration;
  final String? centerText;
  final TextStyle? centerTextStyle;
  final Widget? centerWidget;
  final bool showPercentage;
  final VoidCallback? onComplete;
  
  const AnimatedCircularProgress({
    super.key,
    required this.progress,
    this.size = 120.0,
    this.strokeWidth = 8.0,
    this.progressColor,
    this.backgroundColor,
    this.animationDuration = const Duration(milliseconds: 800),
    this.centerText,
    this.centerTextStyle,
    this.centerWidget,
    this.showPercentage = true,
    this.onComplete,
  });

  @override
  State<AnimatedCircularProgress> createState() => _AnimatedCircularProgressState();
}

class _AnimatedCircularProgressState extends State<AnimatedCircularProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _controller.forward();
    
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed && 
          widget.progress >= 1.0 && 
          widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedCircularProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _previousProgress,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ));
      
      _previousProgress = widget.progress;
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor = widget.progressColor ?? theme.colorScheme.primary;
    final backgroundColor = widget.backgroundColor ?? 
        theme.colorScheme.primary.withOpacity(0.2);
    
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: widget.strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(backgroundColor),
              backgroundColor: Colors.transparent,
            ),
          ),
          
          // Progress circle
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  value: _animation.value.clamp(0.0, 1.0),
                  strokeWidth: widget.strokeWidth,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  backgroundColor: Colors.transparent,
                  strokeCap: StrokeCap.round,
                ),
              );
            },
          ),
          
          // Center content
          if (widget.centerWidget != null)
            widget.centerWidget!
          else if (widget.centerText != null)
            Text(
              widget.centerText!,
              style: widget.centerTextStyle ?? 
                  theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            )
          else if (widget.showPercentage)
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final percentage = (_animation.value * 100).round();
                return Text(
                  '$percentage%',
                  style: widget.centerTextStyle ?? 
                      theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Linear progress bar with gradient and animation
class AnimatedLinearProgress extends StatefulWidget {
  final double progress;
  final double height;
  final Color? progressColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final BorderRadius? borderRadius;
  final Duration animationDuration;
  final String? label;
  final TextStyle? labelStyle;
  final bool showPercentage;
  
  const AnimatedLinearProgress({
    super.key,
    required this.progress,
    this.height = 8.0,
    this.progressColor,
    this.backgroundColor,
    this.gradient,
    this.borderRadius,
    this.animationDuration = const Duration(milliseconds: 600),
    this.label,
    this.labelStyle,
    this.showPercentage = false,
  });

  @override
  State<AnimatedLinearProgress> createState() => _AnimatedLinearProgressState();
}

class _AnimatedLinearProgressState extends State<AnimatedLinearProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedLinearProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
      
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor = widget.progressColor ?? theme.colorScheme.primary;
    final backgroundColor = widget.backgroundColor ?? 
        theme.colorScheme.primary.withOpacity(0.2);
    final borderRadius = widget.borderRadius ?? 
        BorderRadius.circular(widget.height / 2);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null || widget.showPercentage)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.label != null)
                  Text(
                    widget.label!,
                    style: widget.labelStyle ?? theme.textTheme.bodySmall,
                  ),
                if (widget.showPercentage)
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      final percentage = (_animation.value * 100).round();
                      return Text(
                        '$percentage%',
                        style: widget.labelStyle ?? 
                            theme.textTheme.bodySmall?.copyWith(
                              color: progressColor,
                              fontWeight: FontWeight.w600,
                            ),
                      );
                    },
                  ),
              ],
            ),
          ),
        
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
          ),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _animation.value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.gradient == null ? progressColor : null,
                    gradient: widget.gradient,
                    borderRadius: borderRadius,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Score progress indicator with color-coded segments
class ScoreProgressIndicator extends StatefulWidget {
  final double score; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Duration animationDuration;
  final bool showScore;
  final String? label;
  
  const ScoreProgressIndicator({
    super.key,
    required this.score,
    this.size = 100.0,
    this.strokeWidth = 12.0,
    this.animationDuration = const Duration(milliseconds: 1000),
    this.showScore = true,
    this.label,
  });

  @override
  State<ScoreProgressIndicator> createState() => _ScoreProgressIndicatorState();
}

class _ScoreProgressIndicatorState extends State<ScoreProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.score,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    
    _controller.forward();
  }

  @override
  void didUpdateWidget(ScoreProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.score,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ));
      
      _controller.reset();
      _controller.forward();
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) return AppTheme.customColors.progressExcellent;
    if (score >= 0.6) return AppTheme.customColors.progressGood;
    if (score >= 0.4) return AppTheme.customColors.progressNeedsWork;
    return AppTheme.customColors.progressPoor;
  }

  String _getScoreLabel(double score) {
    if (score >= 0.8) return '우수';
    if (score >= 0.6) return '좋음';
    if (score >= 0.4) return '보통';
    return '노력 필요';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background segments
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _ScoreBackgroundPainter(
                  strokeWidth: widget.strokeWidth,
                ),
              ),
              
              // Progress arc
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final animatedScore = _animation.value;
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _ScoreProgressPainter(
                      progress: animatedScore,
                      strokeWidth: widget.strokeWidth,
                      color: _getScoreColor(animatedScore),
                    ),
                  );
                },
              ),
              
              // Center content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showScore)
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        final score = (_animation.value * 100).round();
                        return Text(
                          '$score',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(_animation.value),
                          ),
                        );
                      },
                    ),
                  
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Text(
                        _getScoreLabel(_animation.value),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getScoreColor(_animation.value),
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              widget.label!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Custom painter for score background segments
class _ScoreBackgroundPainter extends CustomPainter {
  final double strokeWidth;

  _ScoreBackgroundPainter({required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    // Draw background segments
    final segments = [
      {'start': -2.35, 'sweep': 0.78, 'color': AppTheme.customColors.progressPoor},
      {'start': -1.57, 'sweep': 0.78, 'color': AppTheme.customColors.progressNeedsWork},
      {'start': -0.78, 'sweep': 0.78, 'color': AppTheme.customColors.progressGood},
      {'start': 0.0, 'sweep': 0.78, 'color': AppTheme.customColors.progressExcellent},
    ];
    
    for (final segment in segments) {
      paint.color = (segment['color'] as Color).withOpacity(0.2);
      canvas.drawArc(
        rect,
        segment['start'] as double,
        segment['sweep'] as double,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for score progress arc
class _ScoreProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;

  _ScoreProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    // Draw progress arc
    const startAngle = -2.35; // Start from bottom left
    final sweepAngle = progress * (math.pi * 1.5); // 270 degrees total
    
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _ScoreProgressPainter &&
        (oldDelegate.progress != progress || 
         oldDelegate.color != color);
  }
}