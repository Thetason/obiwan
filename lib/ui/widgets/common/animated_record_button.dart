import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

/// Animated recording button with pulse effect and state management
class AnimatedRecordButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback? onPressed;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool enableHapticFeedback;
  final String? tooltip;
  
  const AnimatedRecordButton({
    super.key,
    required this.isRecording,
    this.onPressed,
    this.size = 80.0,
    this.activeColor,
    this.inactiveColor,
    this.enableHapticFeedback = true,
    this.tooltip,
  });

  @override
  State<AnimatedRecordButton> createState() => _AnimatedRecordButtonState();
}

class _AnimatedRecordButtonState extends State<AnimatedRecordButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for recording state
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Scale animation for press feedback
    _scaleController = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    
    // Rotation animation for recording state
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    
    _updateAnimations();
  }

  @override
  void didUpdateWidget(AnimatedRecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRecording != widget.isRecording) {
      _updateAnimations();
    }
  }

  void _updateAnimations() {
    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
      _rotationController.repeat();
    } else {
      _pulseController.stop();
      _rotationController.stop();
      _pulseController.reset();
      _rotationController.reset();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  void _handleTap() {
    if (widget.enableHapticFeedback) {
      HapticFeedback.mediumImpact();
    }
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.activeColor ?? AppTheme.customColors.error;
    final inactiveColor = widget.inactiveColor ?? theme.colorScheme.primary;
    
    return Tooltip(
      message: widget.tooltip ?? (widget.isRecording ? '녹음 중지' : '녹음 시작'),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _pulseAnimation,
            _scaleAnimation,
            _rotationAnimation,
          ]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    // Outer glow effect
                    BoxShadow(
                      color: (widget.isRecording ? activeColor : inactiveColor)
                          .withOpacity(0.3 * _pulseAnimation.value),
                      blurRadius: 20 * _pulseAnimation.value,
                      spreadRadius: 5 * _pulseAnimation.value,
                    ),
                    // Inner shadow for depth
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background circle
                    Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isRecording ? activeColor : inactiveColor,
                        gradient: widget.isRecording
                            ? RadialGradient(
                                colors: [
                                  activeColor.withOpacity(0.8),
                                  activeColor,
                                ],
                              )
                            : RadialGradient(
                                colors: [
                                  inactiveColor.withOpacity(0.8),
                                  inactiveColor,
                                ],
                              ),
                      ),
                    ),
                    
                    // Rotating ring when recording
                    if (widget.isRecording)
                      Transform.rotate(
                        angle: _rotationAnimation.value * 2 * 3.14159,
                        child: Container(
                          width: widget.size + 8,
                          height: widget.size + 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: CustomPaint(
                            painter: _DashedCirclePainter(
                              color: Colors.white.withOpacity(0.7),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                    
                    // Center icon
                    TweenAnimationBuilder<double>(
                      duration: AppAnimations.medium,
                      tween: Tween(
                        begin: widget.isRecording ? 24.0 : 28.0,
                        end: widget.isRecording ? 16.0 : 28.0,
                      ),
                      builder: (context, iconSize, _) {
                        return AnimatedSwitcher(
                          duration: AppAnimations.medium,
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: child,
                            );
                          },
                          child: Icon(
                            widget.isRecording 
                                ? Icons.stop_rounded 
                                : Icons.mic_rounded,
                            key: ValueKey(widget.isRecording),
                            size: iconSize,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                    
                    // Pulse ripple effect
                    if (widget.isRecording)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, _) {
                            return Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(
                                    0.5 * (2.0 - _pulseAnimation.value),
                                  ),
                                  width: 2,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    super.dispose();
  }
}

/// Custom painter for dashed circle ring
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  _DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    this.dashLength = 8.0,
    this.gapLength = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final circumference = 2 * 3.14159 * radius;
    
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    final adjustedDashLength = circumference / dashCount - gapLength;
    
    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i * (adjustedDashLength + gapLength) / radius);
      final endAngle = startAngle + (adjustedDashLength / radius);
      
      final path = Path();
      path.addArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
      );
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}