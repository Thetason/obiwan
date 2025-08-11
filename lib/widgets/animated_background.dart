import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';

class AnimatedBackground extends StatelessWidget {
  final AnimationController controller;
  
  const AnimatedBackground({
    Key? key,
    required this.controller,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC), // slate-50
              Color(0xFFFFFFFF), // white  
              Color(0xFFEBF8FF), // blue-50
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated Background Elements - 피그마 스타일
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                return Positioned(
                  top: 80 + (controller.value * 30),
                  left: 40 + (math.sin(controller.value * 2 * math.pi) * 30),
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF3B82F6).withOpacity(0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                      child: Container(),
                    ),
                  ),
                );
              },
            ),
            
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                return Positioned(
                  bottom: 160 - (controller.value * 25),
                  right: 40 + (math.cos(controller.value * 2 * math.pi + 1) * 20),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF8B5CF6).withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                      child: Container(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}