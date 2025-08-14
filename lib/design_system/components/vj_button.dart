import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';
import '../tokens/spacing.dart';
import '../tokens/animations.dart';

enum VJButtonType {
  primary,
  secondary,
  ghost,
  recording,
}

enum VJButtonSize {
  small,
  medium,
  large,
}

class VJButton extends StatefulWidget {
  final String? text;
  final IconData? icon;
  final VJButtonType type;
  final VJButtonSize size;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final Widget? child;

  const VJButton({
    Key? key,
    this.text,
    this.icon,
    this.type = VJButtonType.primary,
    this.size = VJButtonSize.medium,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.child,
  }) : super(key: key);

  @override
  State<VJButton> createState() => _VJButtonState();
}

class _VJButtonState extends State<VJButton> with SingleTickerProviderStateMixin {
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
      end: 0.95,
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

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isDisabled && !widget.isLoading) {
      HapticFeedback.lightImpact();
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.isDisabled || widget.isLoading;
    
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: isDisabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: _buildButton(),
          );
        },
      ),
    );
  }

  Widget _buildButton() {
    if (widget.type == VJButtonType.recording) {
      return _buildRecordingButton();
    }
    
    return AnimatedContainer(
      duration: VJAnimations.durationFast,
      width: widget.width,
      height: _getHeight(),
      decoration: BoxDecoration(
        gradient: _getGradient(),
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(VJSpacing.radiusRound),
        border: _getBorder(),
        boxShadow: _getBoxShadow(),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildRecordingButton() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            VJColors.primary,
            VJColors.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          VJColors.glowShadow(VJColors.primary),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.mic,
          size: 48,
          color: VJColors.white,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_getTextColor()),
          ),
        ),
      );
    }

    if (widget.child != null) {
      return Center(child: widget.child);
    }

    final List<Widget> children = [];
    
    if (widget.icon != null) {
      children.add(Icon(
        widget.icon,
        size: _getIconSize(),
        color: _getTextColor(),
      ));
    }
    
    if (widget.text != null) {
      if (children.isNotEmpty) {
        children.add(SizedBox(width: VJSpacing.xs));
      }
      children.add(Text(
        widget.text!,
        style: _getTextStyle(),
      ));
    }

    return Padding(
      padding: _getPadding(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }

  double _getHeight() {
    switch (widget.size) {
      case VJButtonSize.small:
        return VJSpacing.buttonHeightSm;
      case VJButtonSize.medium:
        return VJSpacing.buttonHeightMd;
      case VJButtonSize.large:
        return VJSpacing.buttonHeightLg;
    }
  }

  EdgeInsets _getPadding() {
    switch (widget.size) {
      case VJButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: VJSpacing.sm,
          vertical: VJSpacing.xs,
        );
      case VJButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: VJSpacing.md,
          vertical: VJSpacing.sm,
        );
      case VJButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: VJSpacing.lg,
          vertical: VJSpacing.md,
        );
    }
  }

  Color? _getBackgroundColor() {
    if (widget.type == VJButtonType.ghost) return Colors.transparent;
    if (widget.type != VJButtonType.primary) return null;
    return null;
  }

  LinearGradient? _getGradient() {
    if (widget.type == VJButtonType.primary) {
      return VJColors.primaryGradient;
    }
    if (widget.type == VJButtonType.secondary) {
      return LinearGradient(
        colors: [VJColors.secondary, VJColors.secondaryDark],
      );
    }
    return null;
  }

  Border? _getBorder() {
    if (widget.type == VJButtonType.ghost) {
      return Border.all(
        color: VJColors.gray300,
        width: 1.5,
      );
    }
    return null;
  }

  List<BoxShadow>? _getBoxShadow() {
    if (widget.isDisabled || widget.type == VJButtonType.ghost) return null;
    if (_isPressed) return null;
    return VJColors.softShadow;
  }

  Color _getTextColor() {
    if (widget.type == VJButtonType.ghost) {
      return VJColors.gray700;
    }
    return VJColors.white;
  }

  TextStyle _getTextStyle() {
    TextStyle style;
    switch (widget.size) {
      case VJButtonSize.small:
        style = VJTypography.labelMedium;
        break;
      case VJButtonSize.medium:
        style = VJTypography.button;
        break;
      case VJButtonSize.large:
        style = VJTypography.button.copyWith(fontSize: 18);
        break;
    }
    return style.copyWith(color: _getTextColor());
  }

  double _getIconSize() {
    switch (widget.size) {
      case VJButtonSize.small:
        return VJSpacing.iconSm;
      case VJButtonSize.medium:
        return VJSpacing.iconMd;
      case VJButtonSize.large:
        return VJSpacing.iconLg;
    }
  }
}