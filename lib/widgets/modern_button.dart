import 'package:flutter/material.dart';

/// Shadcn/Flowbite 스타일의 모던 버튼
class ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  
  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.width,
  });

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getVariantColors(widget.variant);
    final sizes = _getSizeDimensions(widget.size);
    final isDisabled = widget.onPressed == null || widget.isLoading;
    
    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => _controller.forward(),
      onTapUp: isDisabled ? null : (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: sizes['height'],
              padding: EdgeInsets.symmetric(
                horizontal: sizes['paddingX']!,
                vertical: sizes['paddingY']!,
              ),
              decoration: BoxDecoration(
                color: isDisabled ? colors['bg']!.withOpacity(0.5) : colors['bg'],
                borderRadius: BorderRadius.circular(8),
                border: widget.variant == ButtonVariant.outline
                    ? Border.all(color: colors['border']!, width: 1)
                    : null,
                boxShadow: widget.variant == ButtonVariant.primary && !isDisabled
                    ? [
                        BoxShadow(
                          color: colors['bg']!.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isLoading) ...[
                    SizedBox(
                      width: sizes['iconSize'],
                      height: sizes['iconSize'],
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(colors['text']),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: sizes['iconSize'],
                      color: colors['text'],
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.text,
                    style: TextStyle(
                      color: isDisabled ? colors['text']!.withOpacity(0.5) : colors['text'],
                      fontSize: sizes['fontSize'],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Map<String, Color> _getVariantColors(ButtonVariant variant) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    switch (variant) {
      case ButtonVariant.primary:
        return {
          'bg': const Color(0xFF6366F1), // Indigo-500
          'text': Colors.white,
          'border': const Color(0xFF6366F1),
        };
      case ButtonVariant.secondary:
        return {
          'bg': isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
          'text': isDark ? Colors.white : const Color(0xFF374151),
          'border': isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
        };
      case ButtonVariant.outline:
        return {
          'bg': Colors.transparent,
          'text': isDark ? Colors.white : const Color(0xFF374151),
          'border': isDark ? Colors.white.withOpacity(0.2) : const Color(0xFFD1D5DB),
        };
      case ButtonVariant.ghost:
        return {
          'bg': Colors.transparent,
          'text': isDark ? Colors.white : const Color(0xFF374151),
          'border': Colors.transparent,
        };
      case ButtonVariant.destructive:
        return {
          'bg': const Color(0xFFEF4444), // Red-500
          'text': Colors.white,
          'border': const Color(0xFFEF4444),
        };
    }
  }
  
  Map<String, double> _getSizeDimensions(ButtonSize size) {
    switch (size) {
      case ButtonSize.small:
        return {
          'height': 32.0,
          'paddingX': 12.0,
          'paddingY': 6.0,
          'fontSize': 14.0,
          'iconSize': 16.0,
        };
      case ButtonSize.medium:
        return {
          'height': 40.0,
          'paddingX': 16.0,
          'paddingY': 8.0,
          'fontSize': 16.0,
          'iconSize': 18.0,
        };
      case ButtonSize.large:
        return {
          'height': 48.0,
          'paddingX': 24.0,
          'paddingY': 12.0,
          'fontSize': 18.0,
          'iconSize': 20.0,
        };
    }
  }
}

enum ButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  destructive,
}

enum ButtonSize {
  small,
  medium,
  large,
}

/// 플로팅 액션 스타일 버튼
class FloatingModernButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double size;
  
  const FloatingModernButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.size = 56.0,
  });

  @override
  State<FloatingModernButton> createState() => _FloatingModernButtonState();
}

class _FloatingModernButtonState extends State<FloatingModernButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _shadowAnimation = Tween<double>(begin: 8.0, end: 4.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? const Color(0xFF6366F1);
    final fgColor = widget.foregroundColor ?? Colors.white;
    
    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onPressed != null ? (_) {
        _controller.reverse();
        widget.onPressed?.call();
      } : null,
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(widget.size / 2),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withOpacity(0.3),
                    blurRadius: _shadowAnimation.value,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: fgColor,
                size: widget.size * 0.4,
              ),
            ),
          );
        },
      ),
    );
  }
}