import 'package:flutter/material.dart';
import '../tokens.dart';

enum CardVariant {
  default_,
  elevated,
  outlined,
  // Vocal Training 전용
  pitch,      // 피치 정보 카드
  analysis,   // 분석 결과 카드  
  metric,     // 측정값 카드
}

/// Shadcn UI Card 컴포넌트 - Flutter 구현
/// 
/// 컨텐츠를 담는 유연한 컨테이너 컴포넌트
/// 보컬 트레이닝 앱에서 분석 결과, 피치 정보 등을 표시하는데 사용
class UICard extends StatelessWidget {
  final Widget child;
  final CardVariant variant;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final double? elevation;
  final Border? border;

  const UICard({
    super.key,
    required this.child,
    this.variant = CardVariant.default_,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.elevation,
    this.border,
  });

  /// 헤더와 컨텐츠가 있는 카드
  UICard.withHeader({
    super.key,
    required Widget header,
    required Widget content,
    this.variant = CardVariant.default_,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.elevation,
    this.border,
  }) : child = _CardWithHeader(header: header, content: content);

  /// 피치 정보를 표시하는 전용 카드
  UICard.pitch({
    super.key,
    required String frequency,
    required String note,
    required double accuracy,
    this.onTap,
  }) : variant = CardVariant.pitch,
       padding = null,
       backgroundColor = null,
       elevation = null,
       border = null,
       child = _PitchCard(
         frequency: frequency,
         note: note, 
         accuracy: accuracy,
       );

  /// 분석 결과를 표시하는 전용 카드
  UICard.analysis({
    super.key,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    this.onTap,
  }) : variant = CardVariant.analysis,
       padding = null,
       backgroundColor = null,
       elevation = null,
       border = null,
       child = _AnalysisCard(
         title: title,
         value: value,
         subtitle: subtitle,
         color: color,
       );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        child: Container(
          padding: padding ?? _getDefaultPadding(),
          decoration: _getDecoration(),
          child: child,
        ),
      ),
    );
  }

  EdgeInsets _getDefaultPadding() {
    switch (variant) {
      case CardVariant.default_:
      case CardVariant.elevated:
      case CardVariant.outlined:
        return const EdgeInsets.all(DesignTokens.space6);
      case CardVariant.pitch:
      case CardVariant.analysis:
      case CardVariant.metric:
        return const EdgeInsets.all(DesignTokens.space4);
    }
  }

  BoxDecoration _getDecoration() {
    return BoxDecoration(
      color: backgroundColor ?? _getBackgroundColor(),
      borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      border: border ?? _getBorder(),
      boxShadow: _getShadow(),
    );
  }

  Color _getBackgroundColor() {
    switch (variant) {
      case CardVariant.default_:
      case CardVariant.outlined:
        return DesignTokens.card;
      case CardVariant.elevated:
        return DesignTokens.card;
      case CardVariant.pitch:
        return DesignTokens.card.withOpacity(0.8);
      case CardVariant.analysis:
        return DesignTokens.secondary;
      case CardVariant.metric:
        return DesignTokens.accent;
    }
  }

  Border? _getBorder() {
    switch (variant) {
      case CardVariant.outlined:
        return Border.all(
          color: DesignTokens.border,
          width: 1,
        );
      default:
        return null;
    }
  }

  List<BoxShadow>? _getShadow() {
    double elevationValue = elevation ?? _getDefaultElevation();
    
    if (elevationValue <= 0) return null;
    
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: elevationValue * 2,
        offset: Offset(0, elevationValue),
      ),
    ];
  }

  double _getDefaultElevation() {
    switch (variant) {
      case CardVariant.default_:
      case CardVariant.outlined:
        return 0;
      case CardVariant.elevated:
        return 2;
      case CardVariant.pitch:
      case CardVariant.analysis:
      case CardVariant.metric:
        return 1;
    }
  }
}

class _CardWithHeader extends StatelessWidget {
  final Widget header;
  final Widget content;

  const _CardWithHeader({
    required this.header,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        SizedBox(height: DesignTokens.space4),
        content,
      ],
    );
  }
}

class _PitchCard extends StatelessWidget {
  final String frequency;
  final String note;
  final double accuracy;

  const _PitchCard({
    required this.frequency,
    required this.note,
    required this.accuracy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FREQUENCY',
                  style: DesignTokens.bodySmall.copyWith(
                    color: DesignTokens.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: DesignTokens.space1),
                Text(
                  frequency,
                  style: DesignTokens.h3.copyWith(
                    color: DesignTokens.foreground,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'NOTE',
                  style: DesignTokens.bodySmall.copyWith(
                    color: DesignTokens.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: DesignTokens.space1),
                Text(
                  note,
                  style: DesignTokens.h3.copyWith(
                    color: _getAccuracyColor(),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: DesignTokens.space4),
        _buildAccuracyBar(),
      ],
    );
  }

  Color _getAccuracyColor() {
    if (accuracy >= 0.9) return DesignTokens.success;
    if (accuracy >= 0.7) return DesignTokens.warning; 
    return DesignTokens.error;
  }

  Widget _buildAccuracyBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACCURACY',
              style: DesignTokens.bodySmall.copyWith(
                color: DesignTokens.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(accuracy * 100).round()}%',
              style: DesignTokens.bodySmall.copyWith(
                color: _getAccuracyColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: DesignTokens.space2),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: DesignTokens.muted,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: accuracy.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: _getAccuracyColor(),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _AnalysisCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: DesignTokens.bodySmall.copyWith(
            color: DesignTokens.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: DesignTokens.space2),
        Text(
          value,
          style: DesignTokens.h2.copyWith(
            color: color,
          ),
        ),
        SizedBox(height: DesignTokens.space1),
        Text(
          subtitle,
          style: DesignTokens.bodySmall.copyWith(
            color: DesignTokens.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// 사용 예시:
/// 
/// ```dart
/// // 기본 카드
/// UICard(
///   child: Text('카드 내용'),
/// )
/// 
/// // 피치 정보 카드
/// UICard.pitch(
///   frequency: '440.2 Hz',
///   note: 'A4',
///   accuracy: 0.92,
/// )
/// 
/// // 분석 결과 카드
/// UICard.analysis(
///   title: 'AVERAGE PITCH',
///   value: '445 Hz',
///   subtitle: 'Above target by 5 Hz',
///   color: DesignTokens.warning,
/// )
/// ```