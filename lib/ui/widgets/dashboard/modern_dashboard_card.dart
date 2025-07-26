import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Modern dashboard card with gradient backgrounds and animations
class ModernDashboardCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget content;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? accentColor;
  final IconData? icon;
  final bool showShadow;
  final bool isExpanded;
  final Duration animationDuration;
  final EdgeInsets? padding;
  final Widget? header;
  
  const ModernDashboardCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.content,
    this.trailing,
    this.onTap,
    this.accentColor,
    this.icon,
    this.showShadow = true,
    this.isExpanded = false,
    this.animationDuration = const Duration(milliseconds: 300),
    this.padding,
    this.header,
  });

  @override
  State<ModernDashboardCard> createState() => _ModernDashboardCardState();
}

class _ModernDashboardCardState extends State<ModernDashboardCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _elevationAnimation = Tween<double>(
      begin: widget.showShadow ? 2.0 : 0.0,
      end: widget.showShadow ? 8.0 : 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  void _handleHover(bool isHovering) {
    setState(() => _isHovered = isHovering);
    if (isHovering && widget.onTap != null) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.accentColor ?? theme.colorScheme.primary;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _isPressed ? 0.98 : _scaleAnimation.value,
          child: MouseRegion(
            onEnter: (_) => _handleHover(true),
            onExit: (_) => _handleHover(false),
            child: GestureDetector(
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: AppAnimations.fast,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  gradient: _isHovered
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.surface,
                            accentColor.withOpacity(0.05),
                          ],
                        )
                      : null,
                  color: _isHovered ? null : theme.colorScheme.surface,
                  border: Border.all(
                    color: _isHovered
                        ? accentColor.withOpacity(0.3)
                        : theme.colorScheme.outline.withOpacity(0.1),
                    width: _isHovered ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.1),
                      blurRadius: _elevationAnimation.value * 2,
                      offset: Offset(0, _elevationAnimation.value),
                    ),
                    if (_isHovered)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header section
                      if (widget.header != null)
                        widget.header!
                      else
                        _buildDefaultHeader(theme, accentColor),
                      
                      // Content section
                      Padding(
                        padding: widget.padding ?? 
                            const EdgeInsets.fromLTRB(
                              AppSpacing.lg, 
                              AppSpacing.sm, 
                              AppSpacing.lg, 
                              AppSpacing.lg,
                            ),
                        child: widget.content,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultHeader(ThemeData theme, Color accentColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, 
        AppSpacing.lg, 
        AppSpacing.lg, 
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(0.1),
            accentColor.withOpacity(0.05),
          ],
        ),
      ),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                widget.icon,
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          if (widget.trailing != null)
            widget.trailing!,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

/// Statistics card with animated number counter
class StatisticsCard extends StatefulWidget {
  final String title;
  final String value;
  final String? unit;
  final IconData icon;
  final Color? color;
  final String? trend;
  final bool showTrend;
  final VoidCallback? onTap;
  
  const StatisticsCard({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    required this.icon,
    this.color,
    this.trend,
    this.showTrend = true,
    this.onTap,
  });

  @override
  State<StatisticsCard> createState() => _StatisticsCardState();
}

class _StatisticsCardState extends State<StatisticsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _countAnimation;
  
  double _targetValue = 0.0;
  double _currentValue = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _targetValue = double.tryParse(widget.value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    
    _countAnimation = Tween<double>(
      begin: 0.0,
      end: _targetValue,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void didUpdateWidget(StatisticsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _currentValue = _countAnimation.value;
      _targetValue = double.tryParse(widget.value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      
      _countAnimation = Tween<double>(
        begin: _currentValue,
        end: _targetValue,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));
      
      _animationController.reset();
      _animationController.forward();
    }
  }

  String _formatValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else if (value % 1 == 0) {
      return value.toInt().toString();
    } else {
      return value.toStringAsFixed(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.primary;
    
    return ModernDashboardCard(
      title: widget.title,
      accentColor: color,
      icon: widget.icon,
      onTap: widget.onTap,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _countAnimation,
                  builder: (context, child) {
                    return Text(
                      _formatValue(_countAnimation.value),
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    );
                  },
                ),
              ),
              if (widget.unit != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    widget.unit!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
            ],
          ),
          
          if (widget.showTrend && widget.trend != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                widget.trend!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

/// Quick action card with icon and label
class QuickActionCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool enabled;
  final String? badge;
  
  const QuickActionCard({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.enabled = true,
    this.badge,
  });

  @override
  State<QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<QuickActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
    if (widget.enabled) {
      widget.onTap();
    }
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.primary;
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: widget.enabled 
                    ? theme.colorScheme.surface 
                    : theme.colorScheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: widget.enabled
                      ? (_isPressed ? color : theme.colorScheme.outline.withOpacity(0.2))
                      : theme.colorScheme.outline.withOpacity(0.1),
                  width: _isPressed ? 2 : 1,
                ),
                boxShadow: widget.enabled && _isPressed
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: widget.enabled
                              ? color.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(
                          widget.icon,
                          size: 28,
                          color: widget.enabled ? color : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        widget.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: widget.enabled 
                              ? theme.colorScheme.onSurface
                              : Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  
                  if (widget.badge != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.customColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.badge!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
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