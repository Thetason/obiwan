import 'package:flutter/material.dart';
import 'dart:math' as math;

class SpectrumAnalyzer extends StatefulWidget {
  final List<double> audioLevels;
  final double frequency;
  
  const SpectrumAnalyzer({
    super.key,
    required this.audioLevels,
    required this.frequency,
  });
  
  @override
  State<SpectrumAnalyzer> createState() => _SpectrumAnalyzerState();
}

class _SpectrumAnalyzerState extends State<SpectrumAnalyzer>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  final int barCount = 32;
  List<double> _barHeights = [];
  List<double> _targetHeights = [];
  
  @override
  void initState() {
    super.initState();
    _barHeights = List.filled(barCount, 0.0);
    _targetHeights = List.filled(barCount, 0.0);
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    )..addListener(() {
      setState(() {
        for (int i = 0; i < barCount; i++) {
          _barHeights[i] = _barHeights[i] + 
            (_targetHeights[i] - _barHeights[i]) * 0.3;
        }
      });
    })..repeat();
    
    _generateSpectrum();
  }
  
  void _generateSpectrum() {
    if (widget.frequency <= 0) {
      _targetHeights = List.filled(barCount, 0.0);
      return;
    }
    
    // Simulate spectrum based on frequency
    final centerBar = (widget.frequency / 1000 * barCount).clamp(0, barCount - 1).toInt();
    
    for (int i = 0; i < barCount; i++) {
      final distance = (i - centerBar).abs();
      final height = math.max(0.0, 1.0 - (distance / 10));
      _targetHeights[i] = height * (0.5 + math.Random().nextDouble() * 0.5);
    }
  }
  
  @override
  void didUpdateWidget(SpectrumAnalyzer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.frequency != oldWidget.frequency) {
      _generateSpectrum();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(barCount, (index) {
          return _buildBar(index);
        }),
      ),
    );
  }
  
  Widget _buildBar(int index) {
    final height = _barHeights[index] * 60;
    final hue = (index / barCount * 180) + 180; // Blue to purple gradient
    
    return Container(
      width: 6,
      height: height.clamp(2.0, 60.0),
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor(),
            HSLColor.fromAHSL(1.0, hue, 0.7, 0.7).toColor(),
          ],
        ),
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: HSLColor.fromAHSL(0.5, hue, 0.7, 0.5).toColor(),
            blurRadius: 4,
            spreadRadius: 1,
          ),
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