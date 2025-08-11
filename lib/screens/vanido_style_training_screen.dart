import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../models/analysis_result.dart';
import '../models/pitch_point.dart';

class VanidoStyleTrainingScreen extends StatefulWidget {
  final DualResult? analysisResult;
  final List<DualResult>? timeBasedResults;
  final List<double> audioData;
  
  const VanidoStyleTrainingScreen({
    super.key,
    this.analysisResult,
    this.timeBasedResults,
    required this.audioData,
  });

  @override
  State<VanidoStyleTrainingScreen> createState() => _VanidoStyleTrainingScreenState();
}

class _VanidoStyleTrainingScreenState extends State<VanidoStyleTrainingScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _animation;
  
  // 분석 데이터
  double _overallScore = 85;
  double _pitchAccuracy = 78;
  double _consistency = 82;
  double _vibrato = 65;
  String _grade = "B+";
  
  String _currentNote = "A4";
  double _currentFrequency = 440.0;
  int _currentViewMode = 0;
  List<String> _viewModeNames = ['Analysis', 'Harmonics', 'Spectrogram', '3D View', 'Dashboard'];
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _analyzePerformance();
  }
  
  void _initializeAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    
    _controller.forward();
  }
  
  void _analyzePerformance() {
    if (widget.timeBasedResults != null && widget.timeBasedResults!.isNotEmpty) {
      // 간단한 분석 로직
      double totalAccuracy = 0;
      int validPoints = 0;
      
      for (final result in widget.timeBasedResults!) {
        if (result.frequency > 0 && result.confidence > 0.3) {
          totalAccuracy += result.confidence * 100;
          validPoints++;
        }
      }
      
      if (validPoints > 0) {
        _pitchAccuracy = totalAccuracy / validPoints;
        _consistency = _pitchAccuracy * 0.9; // 임시 계산
        _vibrato = math.Random().nextDouble() * 30 + 50; // 임시 값
        _overallScore = (_pitchAccuracy * 0.5 + _consistency * 0.3 + _vibrato * 0.2);
        
        // 등급 결정
        if (_overallScore >= 90) _grade = "A+";
        else if (_overallScore >= 85) _grade = "A";
        else if (_overallScore >= 80) _grade = "B+";
        else if (_overallScore >= 75) _grade = "B";
        else if (_overallScore >= 70) _grade = "C+";
        else _grade = "C";
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildViewModeSelector(),
            Expanded(child: _buildCurrentView()),
            _buildScoreCard(),
            _buildDetailedAnalysis(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios),
          ),
          const Expanded(
            child: Text(
              'Performance Analysis',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green, width: 1),
            ),
            child: const Text(
              'ANALYZED',
              style: TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildViewModeSelector() {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _viewModeNames.length,
        itemBuilder: (context, index) {
          final isSelected = _currentViewMode == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _currentViewMode = index;
              });
              HapticFeedback.selectionClick();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected ? LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                ) : null,
                color: isSelected ? null : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ] : null,
              ),
              child: Center(
                child: Text(
                  _viewModeNames[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildCurrentView() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F23),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 배경 그리드
          CustomPaint(
            painter: GridPainter(),
            child: Container(),
          ),
          
          // 피치 곡선
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                painter: SimplePitchPainter(
                  animationValue: _animation.value,
                  currentNote: _currentNote,
                  frequency: _currentFrequency,
                ),
                child: Container(),
              );
            },
          ),
          
          // 현재 음 표시
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Note',
                    style: TextStyle(
                      color: Colors.blue.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _currentNote,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_currentFrequency.toStringAsFixed(1)} Hz',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 뷰 모드별 정보
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getViewModeDescription(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getViewModeDescription() {
    switch (_currentViewMode) {
      case 0: return 'Real-time pitch analysis';
      case 1: return 'Harmonic frequency analysis';
      case 2: return 'Audio spectrum visualization';
      case 3: return '3D pitch space rendering';
      case 4: return 'Performance dashboard';
      default: return 'Analysis view';
    }
  }
  
  Widget _buildScoreCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade400,
            Colors.blue.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _grade,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'GRADE',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 8,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 20),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${(_overallScore * _animation.value).toInt()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          ' / 100',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getMotivationalMessage(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              Icon(
                Icons.star,
                color: Colors.yellowAccent.withOpacity(0.8),
                size: 30,
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildDetailedAnalysis() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildMetricRow('Pitch Accuracy', _pitchAccuracy, Colors.green),
          const SizedBox(height: 12),
          _buildMetricRow('Consistency', _consistency, Colors.orange),
          const SizedBox(height: 12),
          _buildMetricRow('Vibrato Quality', _vibrato, Colors.purple),
        ],
      ),
    );
  }
  
  Widget _buildMetricRow(String label, double value, Color color) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final animatedValue = value * _animation.value;
        return Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: animatedValue / 100,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.8),
                            color,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 40,
              child: Text(
                '${animatedValue.toInt()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
                shadowColor: Colors.blue.withOpacity(0.5),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getMotivationalMessage() {
    if (_overallScore >= 90) return "Outstanding performance! 🌟";
    if (_overallScore >= 80) return "Great job! Keep it up! 🎵";
    if (_overallScore >= 70) return "Good progress! 👍";
    if (_overallScore >= 60) return "Nice try! Practice makes perfect!";
    return "Keep practicing, you'll get there!";
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// 간단한 그리드 페인터
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    
    // 가로선
    for (int i = 0; i <= 5; i++) {
      final y = (size.height / 5) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
    
    // 세로선
    for (int i = 0; i <= 10; i++) {
      final x = (size.width / 10) * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}

// 간단한 피치 곡선 페인터
class SimplePitchPainter extends CustomPainter {
  final double animationValue;
  final String currentNote;
  final double frequency;
  
  SimplePitchPainter({
    required this.animationValue,
    required this.currentNote,
    required this.frequency,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4ECDC4)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    final points = 50;
    
    for (int i = 0; i < (points * animationValue).floor(); i++) {
      final x = (i / points) * size.width;
      final normalizedFreq = (frequency - 200) / 400;
      final baseY = size.height * (1 - normalizedFreq.clamp(0, 1)) * 0.5 + size.height * 0.25;
      final variation = math.sin(i * 0.3) * 20 * animationValue;
      final y = baseY + variation;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // 글로우 효과
    final glowPaint = Paint()
      ..color = const Color(0xFF4ECDC4).withOpacity(0.5)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawPath(path, glowPaint);
  }
  
  @override
  bool shouldRepaint(SimplePitchPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}