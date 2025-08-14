import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';
import '../tokens/spacing.dart';
import '../tokens/animations.dart';
import 'vj_card.dart';

enum StatTrend {
  up,
  down,
  neutral,
}

class VJStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final StatTrend? trend;
  final double? trendValue;
  final VoidCallback? onTap;
  final Widget? customValue;

  const VJStatCard({
    Key? key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trend,
    this.trendValue,
    this.onTap,
    this.customValue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return VJCard(
      type: VJCardType.elevated,
      onTap: onTap,
      padding: EdgeInsets.all(VJSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: VJTypography.labelMedium.copyWith(
                    color: VJColors.gray500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) ...[
                SizedBox(width: VJSpacing.xs),
                Container(
                  padding: EdgeInsets.all(VJSpacing.xs),
                  decoration: BoxDecoration(
                    color: (iconColor ?? VJColors.primary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(VJSpacing.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    size: VJSpacing.iconSm,
                    color: iconColor ?? VJColors.primary,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: VJSpacing.sm),
          if (customValue != null)
            customValue!
          else
            Text(
              value,
              style: VJTypography.headlineMedium.copyWith(
                color: VJColors.gray900,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (subtitle != null || trend != null) ...[
            SizedBox(height: VJSpacing.xs),
            Row(
              children: [
                if (trend != null && trendValue != null) ...[
                  _buildTrendIndicator(),
                  SizedBox(width: VJSpacing.xs),
                ],
                if (subtitle != null)
                  Expanded(
                    child: Text(
                      subtitle!,
                      style: VJTypography.bodySmall.copyWith(
                        color: VJColors.gray500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendIndicator() {
    Color trendColor;
    IconData trendIcon;
    
    switch (trend!) {
      case StatTrend.up:
        trendColor = VJColors.success;
        trendIcon = Icons.trending_up;
        break;
      case StatTrend.down:
        trendColor = VJColors.error;
        trendIcon = Icons.trending_down;
        break;
      case StatTrend.neutral:
        trendColor = VJColors.gray500;
        trendIcon = Icons.trending_flat;
        break;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: VJSpacing.xs,
        vertical: VJSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: trendColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(VJSpacing.radiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trendIcon,
            size: 12,
            color: trendColor,
          ),
          SizedBox(width: 2),
          Text(
            '${trendValue!.abs().toStringAsFixed(1)}%',
            style: VJTypography.labelSmall.copyWith(
              color: trendColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Grid layout for multiple stat cards
class VJStatGrid extends StatelessWidget {
  final List<VJStatCard> cards;
  final int crossAxisCount;
  final double spacing;
  final double aspectRatio;

  const VJStatGrid({
    Key? key,
    required this.cards,
    this.crossAxisCount = 2,
    this.spacing = VJSpacing.md,
    this.aspectRatio = 1.5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) => cards[index],
    );
  }
}