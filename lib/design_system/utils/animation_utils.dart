import 'package:flutter/material.dart';

/// Shadcn 스타일 애니메이션 유틸리티
/// 
/// 미니멀하고 성능 최적화된 애니메이션을 제공
/// 과도한 애니메이션을 제거하고 필요한 곳에만 서브틀한 효과 적용
class ShadcnAnimations {
  // 애니메이션 지속시간 (shadcn 표준)
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  
  // 이징 곡선 (shadcn 표준)
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  
  /// 페이드 인 애니메이션
  static Widget fadeIn({
    required Widget child,
    Duration duration = normal,
    Curve curve = easeOut,
    double begin = 0.0,
    double end = 1.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: child,
    );
  }
  
  /// 슬라이드 업 애니메이션
  static Widget slideUp({
    required Widget child,
    Duration duration = normal,
    Curve curve = easeOut,
    double begin = 20.0,
    double end = 0.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, value),
          child: child,
        );
      },
      child: child,
    );
  }
  
  /// 스케일 애니메이션 (매우 서브틀)
  static Widget subtleScale({
    required Widget child,
    Duration duration = fast,
    Curve curve = easeOut,
    double begin = 0.95,
    double end = 1.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }
  
  /// 스태거드 애니메이션 (리스트 항목용)
  static Widget staggeredFadeIn({
    required Widget child,
    required int index,
    Duration baseDelay = const Duration(milliseconds: 50),
    Duration duration = normal,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// 성능 최적화된 애니메이션 위젯
/// 
/// 메모리 누수를 방지하고 리소스를 효율적으로 관리
class OptimizedAnimationWidget extends StatefulWidget {
  final Widget child;
  final AnimationController? controller;
  final Animation<double>? animation;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onComplete;
  
  const OptimizedAnimationWidget({
    super.key,
    required this.child,
    this.controller,
    this.animation,
    this.duration = ShadcnAnimations.normal,
    this.curve = ShadcnAnimations.easeOut,
    this.onComplete,
  });
  
  @override
  State<OptimizedAnimationWidget> createState() => _OptimizedAnimationWidgetState();
}

class _OptimizedAnimationWidgetState extends State<OptimizedAnimationWidget>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = widget.controller ?? AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _animation = widget.animation ?? Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
    
    _controller.addStatusListener(_handleAnimationStatus);
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.removeStatusListener(_handleAnimationStatus);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }
  
  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete?.call();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Transform.scale(
            scale: 0.95 + (0.05 * _animation.value),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// 컨디셔널 애니메이션 래퍼
/// 
/// 접근성 설정이나 성능 요구사항에 따라 애니메이션을 조건부로 적용
class ConditionalAnimation extends StatelessWidget {
  final Widget child;
  final bool enableAnimation;
  final Widget Function(Widget child) animationBuilder;
  
  const ConditionalAnimation({
    super.key,
    required this.child,
    this.enableAnimation = true,
    required this.animationBuilder,
  });
  
  @override
  Widget build(BuildContext context) {
    // 접근성: reduce motion 설정 확인
    final isMotionReduced = MediaQuery.of(context).disableAnimations;
    
    if (!enableAnimation || isMotionReduced) {
      return child;
    }
    
    return animationBuilder(child);
  }
}

/// 피치 시각화 전용 애니메이션
/// 
/// 보컬 트레이닝 앱에 특화된 애니메이션 효과들
class VocalAnimations {
  /// 피치 정확도에 따른 색상 전환 애니메이션
  static Widget accuracyColorTransition({
    required Widget child,
    required double accuracy,
    Duration duration = const Duration(milliseconds: 200),
  }) {
    return TweenAnimationBuilder<Color>(
      tween: ColorTween(
        begin: Colors.grey,
        end: _getAccuracyColor(accuracy),
      ),
      duration: duration,
      curve: ShadcnAnimations.easeOut,
      builder: (context, color, child) {
        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            color ?? Colors.grey,
            BlendMode.modulate,
          ),
          child: child,
        );
      },
      child: child,
    );
  }
  
  /// 녹음 버튼 펄스 애니메이션 (매우 서브틀)
  static Widget recordingPulse({
    required Widget child,
    required bool isRecording,
  }) {
    if (!isRecording) return child;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.02),
      duration: const Duration(milliseconds: 800),
      curve: ShadcnAnimations.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      onEnd: () {
        // 애니메이션 반복을 위한 트리거
      },
      child: child,
    );
  }
  
  /// 피치 데이터 포인트 애니메이션
  static Widget pitchDataPoint({
    required Widget child,
    required double confidence,
    Duration duration = const Duration(milliseconds: 150),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: confidence),
      duration: duration,
      curve: ShadcnAnimations.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: 0.3 + (value * 0.7),
          child: Transform.scale(
            scale: 0.5 + (value * 0.5),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
  
  static Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.9) return const Color(0xFF10B981); // success
    if (accuracy >= 0.7) return const Color(0xFF3B82F6); // info
    if (accuracy >= 0.5) return const Color(0xFFF59E0B); // warning
    return const Color(0xFFEF4444); // error
  }
}

/// 성능 모니터링을 위한 애니메이션 디버거
class AnimationPerformanceMonitor {
  static bool _isEnabled = false;
  static final List<String> _logs = [];
  
  static void enable() {
    _isEnabled = true;
  }
  
  static void disable() {
    _isEnabled = false;
    _logs.clear();
  }
  
  static void log(String message) {
    if (_isEnabled) {
      _logs.add('${DateTime.now()}: $message');
      print('[Animation] $message');
    }
  }
  
  static List<String> getLogs() => List.unmodifiable(_logs);
}

/// 애니메이션 프리셋
/// 
/// 자주 사용되는 애니메이션 조합을 미리 정의
class AnimationPresets {
  /// 카드 엔트리 애니메이션
  static Widget cardEntry(Widget child) {
    return ShadcnAnimations.fadeIn(
      duration: ShadcnAnimations.fast,
      child: ShadcnAnimations.slideUp(
        begin: 10,
        duration: ShadcnAnimations.fast,
        child: child,
      ),
    );
  }
  
  /// 모달 엔트리 애니메이션
  static Widget modalEntry(Widget child) {
    return ShadcnAnimations.fadeIn(
      duration: ShadcnAnimations.normal,
      child: ShadcnAnimations.slideUp(
        begin: 30,
        duration: ShadcnAnimations.normal,
        child: ShadcnAnimations.subtleScale(
          begin: 0.98,
          duration: ShadcnAnimations.normal,
          child: child,
        ),
      ),
    );
  }
  
  /// 버튼 피드백 애니메이션
  static Widget buttonFeedback(Widget child) {
    return ShadcnAnimations.subtleScale(
      begin: 1.0,
      end: 0.98,
      duration: const Duration(milliseconds: 100),
      child: child,
    );
  }
}