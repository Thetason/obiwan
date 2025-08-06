import 'package:flutter/material.dart';

/// Shadcn/Flowbite 스타일의 모던 카드 컴포넌트
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? elevation;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final Border? border;
  final bool glassy;
  final VoidCallback? onTap;
  
  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.elevation,
    this.backgroundColor,
    this.borderRadius,
    this.border,
    this.glassy = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Widget card = Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor ?? (glassy 
            ? (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02))
            : (isDark ? const Color(0xFF1A1B23) : Colors.white)),
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: border ?? Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: glassy ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ] : [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
            blurRadius: elevation ?? 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
    
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          child: card,
        ),
      );
    }
    
    return card;
  }
}

/// 그라디언트 배경의 히어로 카드
class HeroCard extends StatelessWidget {
  final Widget child;
  final List<Color>? gradientColors;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  
  const HeroCard({
    super.key,
    required this.child,
    this.gradientColors,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final defaultGradient = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFA855F7), // Purple-500
    ];
    
    Widget card = Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors ?? defaultGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (gradientColors?.first ?? defaultGradient.first).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
    
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: card,
        ),
      );
    }
    
    return card;
  }
}

/// 상태에 따른 컬러 카드
class StatusCard extends StatelessWidget {
  final Widget child;
  final CardStatus status;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  
  const StatusCard({
    super.key,
    required this.child,
    required this.status,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getStatusColors(status);
    
    return ModernCard(
      padding: padding,
      backgroundColor: colors['bg'],
      border: Border.all(color: colors['border']!, width: 1),
      onTap: onTap,
      child: child,
    );
  }
  
  Map<String, Color> _getStatusColors(CardStatus status) {
    switch (status) {
      case CardStatus.success:
        return {
          'bg': const Color(0xFF10B981).withOpacity(0.1),
          'border': const Color(0xFF10B981).withOpacity(0.2),
        };
      case CardStatus.warning:
        return {
          'bg': const Color(0xFFF59E0B).withOpacity(0.1),
          'border': const Color(0xFFF59E0B).withOpacity(0.2),
        };
      case CardStatus.error:
        return {
          'bg': const Color(0xFFEF4444).withOpacity(0.1),
          'border': const Color(0xFFEF4444).withOpacity(0.2),
        };
      case CardStatus.info:
        return {
          'bg': const Color(0xFF3B82F6).withOpacity(0.1),
          'border': const Color(0xFF3B82F6).withOpacity(0.2),
        };
    }
  }
}

enum CardStatus { success, warning, error, info }

/// 애니메이션 카드 (Magic UI 스타일)
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  
  const AnimatedCard({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.padding,
    this.onTap,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
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
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: ModernCard(
              padding: widget.padding,
              elevation: _shadowAnimation.value,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}