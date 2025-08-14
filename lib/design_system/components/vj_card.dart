import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/animations.dart';

enum VJCardType {
  elevated,
  outlined,
  filled,
  gradient,
}

class VJCard extends StatefulWidget {
  final Widget child;
  final VJCardType type;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final LinearGradient? gradient;
  final Color? backgroundColor;
  final double? width;
  final double? height;
  final bool isSelected;
  final bool isDisabled;

  const VJCard({
    Key? key,
    required this.child,
    this.type = VJCardType.elevated,
    this.padding,
    this.margin,
    this.onTap,
    this.gradient,
    this.backgroundColor,
    this.width,
    this.height,
    this.isSelected = false,
    this.isDisabled = false,
  }) : super(key: key);

  @override
  State<VJCard> createState() => _VJCardState();
}

class _VJCardState extends State<VJCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: VJAnimations.durationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: VJAnimations.curveDefault,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget card = AnimatedContainer(
      duration: VJAnimations.durationNormal,
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        gradient: _getGradient(),
        borderRadius: BorderRadius.circular(VJSpacing.radiusMd),
        border: _getBorder(),
        boxShadow: _getBoxShadow(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VJSpacing.radiusMd),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isDisabled ? null : widget.onTap,
            onTapDown: widget.onTap != null ? (_) {
              setState(() => _isPressed = true);
              _controller.forward();
            } : null,
            onTapUp: widget.onTap != null ? (_) {
              setState(() => _isPressed = false);
              _controller.reverse();
            } : null,
            onTapCancel: widget.onTap != null ? () {
              setState(() => _isPressed = false);
              _controller.reverse();
            } : null,
            borderRadius: BorderRadius.circular(VJSpacing.radiusMd),
            child: Padding(
              padding: widget.padding ?? EdgeInsets.all(VJSpacing.cardPadding),
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    if (widget.onTap != null && !widget.isDisabled) {
      return AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: card,
          );
        },
      );
    }

    return card;
  }

  Color? _getBackgroundColor() {
    if (widget.type == VJCardType.gradient) return null;
    if (widget.backgroundColor != null) return widget.backgroundColor;
    
    switch (widget.type) {
      case VJCardType.elevated:
        return VJColors.surface;
      case VJCardType.outlined:
        return VJColors.surface;
      case VJCardType.filled:
        return VJColors.surfaceLight;
      case VJCardType.gradient:
        return null;
    }
  }

  LinearGradient? _getGradient() {
    if (widget.type == VJCardType.gradient) {
      return widget.gradient ?? VJColors.primaryGradient;
    }
    return null;
  }

  Border? _getBorder() {
    if (widget.isSelected) {
      return Border.all(
        color: VJColors.primary,
        width: 2,
      );
    }
    
    if (widget.type == VJCardType.outlined) {
      return Border.all(
        color: VJColors.gray300,
        width: 1,
      );
    }
    
    return null;
  }

  List<BoxShadow>? _getBoxShadow() {
    if (widget.isDisabled) return null;
    if (_isPressed) return null;
    
    switch (widget.type) {
      case VJCardType.elevated:
        return VJColors.softShadow;
      case VJCardType.outlined:
      case VJCardType.filled:
        return null;
      case VJCardType.gradient:
        return VJColors.mediumShadow;
    }
  }
}