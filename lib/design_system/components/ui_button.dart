import 'package:flutter/material.dart';
import '../tokens.dart';

enum ButtonVariant { 
  primary, 
  secondary, 
  destructive, 
  outline, 
  ghost, 
  link,
  // Vocal Training 전용
  recording,  // 녹음 버튼
  playback,   // 재생 버튼
  success,    // 성공/완료 버튼
}

enum ButtonSize { 
  sm, 
  md, 
  lg, 
  icon,
}

/// Shadcn UI Button 컴포넌트 - Flutter 구현
/// 
/// 복사-붙여넣기 방식의 재사용 가능한 버튼 컴포넌트
/// Radix UI의 접근성과 Tailwind CSS의 스타일링 철학을 Flutter에 적용
class UIButton extends StatelessWidget {
  final String? text;
  final Widget? child;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool loading;
  final Widget? icon;
  final bool fullWidth;
  final bool disabled;

  const UIButton({
    super.key,
    this.text,
    this.child,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
    this.loading = false,
    this.icon,
    this.fullWidth = false,
    this.disabled = false,
  }) : assert(text != null || child != null, 'Either text or child must be provided');

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = disabled || loading ? null : onPressed;
    
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: _getHeight(),
      child: ElevatedButton(
        onPressed: effectiveOnPressed,
        style: _getButtonStyle(),
        child: loading 
          ? _buildLoadingContent()
          : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (icon != null && text != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon!,
          SizedBox(width: DesignTokens.space2),
          Text(text!),
        ],
      );
    }
    
    if (child != null) return child!;
    if (text != null) return Text(text!);
    if (icon != null) return icon!;
    
    return const SizedBox.shrink();
  }

  Widget _buildLoadingContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _getIconSize(),
          height: _getIconSize(),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_getForegroundColor()),
          ),
        ),
        if (text != null) ...[
          SizedBox(width: DesignTokens.space2),
          Text(text!),
        ],
      ],
    );
  }

  ButtonStyle _getButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _getBackgroundColor(),
      foregroundColor: _getForegroundColor(),
      elevation: variant == ButtonVariant.outline || variant == ButtonVariant.ghost ? 0 : 1,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        side: _getBorderSide(),
      ),
      padding: _getPadding(),
      textStyle: _getTextStyle(),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Color _getBackgroundColor() {
    if (disabled) return DesignTokens.muted;
    
    switch (variant) {
      case ButtonVariant.primary:
        return DesignTokens.primary;
      case ButtonVariant.secondary:
        return DesignTokens.secondary;
      case ButtonVariant.destructive:
        return DesignTokens.destructive;
      case ButtonVariant.outline:
      case ButtonVariant.ghost:
      case ButtonVariant.link:
        return Colors.transparent;
      case ButtonVariant.recording:
        return const Color(0xFFDC2626); // 녹음 전용 빨강
      case ButtonVariant.playback:
        return const Color(0xFF2563EB); // 재생 전용 파랑
      case ButtonVariant.success:
        return DesignTokens.success;
    }
  }

  Color _getForegroundColor() {
    if (disabled) return DesignTokens.mutedForeground;
    
    switch (variant) {
      case ButtonVariant.primary:
        return DesignTokens.primaryForeground;
      case ButtonVariant.secondary:
        return DesignTokens.secondaryForeground;
      case ButtonVariant.destructive:
        return DesignTokens.destructiveForeground;
      case ButtonVariant.outline:
        return DesignTokens.foreground;
      case ButtonVariant.ghost:
      case ButtonVariant.link:
        return DesignTokens.primary;
      case ButtonVariant.recording:
      case ButtonVariant.playback:
      case ButtonVariant.success:
        return Colors.white;
    }
  }

  BorderSide _getBorderSide() {
    switch (variant) {
      case ButtonVariant.outline:
        return BorderSide(
          color: disabled ? DesignTokens.muted : DesignTokens.border,
          width: 1,
        );
      default:
        return BorderSide.none;
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case ButtonSize.sm:
        return const EdgeInsets.symmetric(
          horizontal: DesignTokens.space3,
          vertical: DesignTokens.space1,
        );
      case ButtonSize.md:
        return const EdgeInsets.symmetric(
          horizontal: DesignTokens.space4,
          vertical: DesignTokens.space2,
        );
      case ButtonSize.lg:
        return const EdgeInsets.symmetric(
          horizontal: DesignTokens.space8,
          vertical: DesignTokens.space3,
        );
      case ButtonSize.icon:
        return const EdgeInsets.all(DesignTokens.space2);
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case ButtonSize.sm:
        return DesignTokens.bodySmall.copyWith(fontWeight: FontWeight.w500);
      case ButtonSize.md:
        return DesignTokens.body.copyWith(fontWeight: FontWeight.w500);
      case ButtonSize.lg:
        return DesignTokens.body.copyWith(fontWeight: FontWeight.w600);
      case ButtonSize.icon:
        return const TextStyle(fontSize: 0); // 아이콘 전용
    }
  }

  double _getHeight() {
    switch (size) {
      case ButtonSize.sm:
        return 36;
      case ButtonSize.md:
        return 40;
      case ButtonSize.lg:
        return 44;
      case ButtonSize.icon:
        return 40;
    }
  }

  double _getIconSize() {
    switch (size) {
      case ButtonSize.sm:
        return 16;
      case ButtonSize.md:
        return 18;
      case ButtonSize.lg:
        return 20;
      case ButtonSize.icon:
        return 18;
    }
  }
}

/// 사용 예시:
/// 
/// ```dart
/// // 기본 사용
/// UIButton(
///   text: '녹음 시작',
///   variant: ButtonVariant.recording,
///   onPressed: () => startRecording(),
/// )
/// 
/// // 아이콘과 함께
/// UIButton(
///   text: '재생',
///   icon: Icon(Icons.play_arrow),
///   variant: ButtonVariant.playback,
///   onPressed: () => playAudio(),
/// )
/// 
/// // 로딩 상태
/// UIButton(
///   text: '분석 중...',
///   loading: true,
///   variant: ButtonVariant.primary,
/// )
/// ```