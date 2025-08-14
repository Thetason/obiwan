import 'package:flutter/material.dart';

/// Voice Journey 애니메이션 시스템
/// 부드럽고 자연스러운 마이크로 인터랙션
class VJAnimations {
  // Curves
  static const Curve curveEaseIn = Curves.easeIn;
  static const Curve curveEaseOut = Curves.easeOut;
  static const Curve curveEaseInOut = Curves.easeInOut;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveBounce = Curves.bounceOut;
  static const Curve curveDefault = Curves.easeInOutCubic;
  
  // Durations
  static const Duration durationInstant = Duration(milliseconds: 100);
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationVerySlow = Duration(milliseconds: 800);
  static const Duration durationPageTransition = Duration(milliseconds: 400);
  
  // Page Transitions
  static Route<T> slideUpRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: durationPageTransition,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        
        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );
        
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
  
  static Route<T> fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: durationNormal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }
  
  static Route<T> scaleRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: durationNormal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.95,
            end: 1.0,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: curveDefault,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }
  
  // Stagger Animation Helper
  static List<Animation<double>> createStaggeredAnimations(
    AnimationController controller,
    int itemCount, {
    Duration delay = const Duration(milliseconds: 50),
  }) {
    final List<Animation<double>> animations = [];
    for (int i = 0; i < itemCount; i++) {
      final startTime = i * delay.inMilliseconds / controller.duration!.inMilliseconds;
      final endTime = startTime + 0.5;
      
      animations.add(
        Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              startTime.clamp(0.0, 1.0),
              endTime.clamp(0.0, 1.0),
              curve: curveDefault,
            ),
          ),
        ),
      );
    }
    return animations;
  }
}