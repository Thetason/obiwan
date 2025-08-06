import 'package:flutter/material.dart';
import 'dart:ui';

class GlassmorphismCard extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final double blur;
  final double opacity;
  final List<BoxShadow>? boxShadow;
  final Border? border;

  const GlassmorphismCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.backgroundColor,
    this.blur = 10.0,
    this.opacity = 0.2,
    this.boxShadow,
    this.border,
  });

  @override
  State<GlassmorphismCard> createState() => _GlassmorphismCardState();
}

class _GlassmorphismCardState extends State<GlassmorphismCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_animation.value * 0.2),
          child: Opacity(
            opacity: _animation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              child: ClipRRect(
                borderRadius: widget.borderRadius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.blur,
                    sigmaY: widget.blur,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: (widget.backgroundColor ?? Colors.white)
                          .withOpacity(widget.opacity),
                      borderRadius: widget.borderRadius,
                      border: widget.border ??
                          Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                      boxShadow: widget.boxShadow ??
                          [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 0,
                              offset: const Offset(0, 10),
                            ),
                          ],
                    ),
                    padding: widget.padding,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class AnimatedGlassCard extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool isSelected;
  final Color primaryColor;
  final Color secondaryColor;

  const AnimatedGlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.isSelected = false,
    this.primaryColor = const Color(0xFF6366F1),
    this.secondaryColor = const Color(0xFF8B5CF6),
  });

  @override
  State<AnimatedGlassCard> createState() => _AnimatedGlassCardState();
}

class _AnimatedGlassCardState extends State<AnimatedGlassCard>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _tapController;
  late Animation<double> _hoverAnimation;
  late Animation<double> _tapAnimation;
  late Animation<double> _glowAnimation;
  late AnimationController _glowController;

  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _hoverAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );

    _tapAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.isSelected) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedGlassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _glowController.repeat(reverse: true);
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _glowController.stop();
      _glowController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovering = false);
        _hoverController.reverse();
      },
      child: GestureDetector(
        onTapDown: (_) => _tapController.forward(),
        onTapUp: (_) => _tapController.reverse(),
        onTapCancel: () => _tapController.reverse(),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _hoverAnimation,
            _tapAnimation,
            _glowAnimation,
          ]),
          builder: (context, child) {
            return Transform.scale(
              scale: _tapAnimation.value,
              child: Container(
                width: widget.width,
                height: widget.height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    20 + (_hoverAnimation.value * 4),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 15 + (_hoverAnimation.value * 5),
                      sigmaY: 15 + (_hoverAnimation.value * 5),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(
                              0.1 + (_hoverAnimation.value * 0.1),
                            ),
                            Colors.white.withOpacity(
                              0.05 + (_hoverAnimation.value * 0.05),
                            ),
                          ],
                        ),
                        border: Border.all(
                          color: widget.isSelected
                              ? Color.lerp(
                                  widget.primaryColor,
                                  widget.secondaryColor,
                                  _glowAnimation.value,
                                )!.withOpacity(0.5)
                              : Colors.white.withOpacity(
                                  0.2 + (_hoverAnimation.value * 0.1),
                                ),
                          width: widget.isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(
                          20 + (_hoverAnimation.value * 4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.isSelected
                                ? widget.primaryColor.withOpacity(
                                    0.2 + (_glowAnimation.value * 0.2),
                                  )
                                : Colors.black.withOpacity(0.1),
                            blurRadius: widget.isSelected
                                ? 20 + (_glowAnimation.value * 10)
                                : 15 + (_hoverAnimation.value * 10),
                            spreadRadius: widget.isSelected
                                ? 2 + (_glowAnimation.value * 3)
                                : 0 + (_hoverAnimation.value * 2),
                            offset: Offset(
                              0,
                              8 + (_hoverAnimation.value * 4),
                            ),
                          ),
                        ],
                      ),
                      padding: widget.padding,
                      child: widget.child,
                    ),
                  ),
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
    _hoverController.dispose();
    _tapController.dispose();
    _glowController.dispose();
    super.dispose();
  }
}