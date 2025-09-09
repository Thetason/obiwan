import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../models/analysis_result.dart';
import '../services/melody_evaluator.dart';
import '../widgets/dtw_alignment_visualizer.dart';
import '../services/reference_melody_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';

// RealtimePitchGraph와 호환되는 PitchPoint 정의
// (recording_flow_modal.dart에서 정의된 것과 동일)
class AnalysisPitchPoint {
  final double time;
  final double frequency;
  final double confidence;
  
  AnalysisPitchPoint({
    required this.time,
    required this.frequency,
    required this.confidence,
  });
}


class VanidoStyleTrainingScreen extends StatefulWidget {
  final DualResult? analysisResult;
  final List<DualResult>? timeBasedResults;
  final List<double> audioData;
  final List<double>? referencePitch; // 옵션: 원곡 피치 시퀀스(Hz)
  
  const VanidoStyleTrainingScreen({
    super.key,
    this.analysisResult,
    this.timeBasedResults,
    required this.audioData,
    this.referencePitch,
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
  List<AnalysisPitchPoint> _analysisPitchPoints = [];
  MelodyEvaluationResult? _melodyEval; // DTW 평가 결과
  bool _showDTW = false;
  bool _loadingReference = false;
  List<double>? _referencePitchLocal;
  
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
      // timeBasedResults를 AnalysisPitchPoint로 변환
      _analysisPitchPoints = [];
      double totalAccuracy = 0;
      int validPoints = 0;
      
      for (int i = 0; i < widget.timeBasedResults!.length; i++) {
        final result = widget.timeBasedResults![i];
        if (result.frequency > 0 && result.confidence > 0.3) {
          // 시간은 인덱스 기반으로 계산 (초 단위)
          final time = (i / widget.timeBasedResults!.length) * 10.0; // 0-10초 범위
          
          _analysisPitchPoints.add(AnalysisPitchPoint(
            time: time,
            frequency: result.frequency,
            confidence: result.confidence,
          ));
          
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

    // DTW 멜로디 정렬 + 피드백 (참조 멜로디가 있을 때만)
    final ref = widget.referencePitch ?? _referencePitchLocal;
    if (ref != null && ref.isNotEmpty &&
        widget.timeBasedResults != null && widget.timeBasedResults!.isNotEmpty) {
      // 사용자 피치 시퀀스 구성
      final user = widget.timeBasedResults!
          .map((e) => e.frequency > 0 ? e.frequency : 0.0)
          .toList();
      final refPitch = ref;
      // 프레임레이트 추정: totalFrames / durationSeconds
      final durationSec = widget.audioData.isNotEmpty
          ? (widget.audioData.length / 44100.0)
          : math.max(1.0, user.length / 10.0); // fallback
      final frameRate = user.length / durationSec;

      final evaluator = MelodyEvaluator();
      _melodyEval = evaluator.evaluate(reference: refPitch, user: user, frameRate: frameRate);
      setState(() {});
    }
  }

  Future<void> _pickAndAnalyzeReference() async {
    try {
      setState(() { _loadingReference = true; });
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav'], // WAV 권장
        withData: true,
      );
      if (res == null || res.files.isEmpty || res.files.first.bytes == null) {
        setState(() { _loadingReference = false; });
        return;
      }
      final Uint8List bytes = res.files.first.bytes!;
      final service = ReferenceMelodyService();
      final refFreqs = await service.createFromAudioBytes(bytes);
      setState(() { _referencePitchLocal = refFreqs; _loadingReference = false; });
      // DTW 즉시 평가
      _analyzePerformance();
      if (_melodyEval != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('참조 멜로디 생성 완료: 프레임 ${refFreqs.length}개')),
        );
      }
    } on DioException catch (e) {
      setState(() { _loadingReference = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CREPE 서버 연결 실패: ${e.message}')),
      );
    } catch (e) {
      setState(() { _loadingReference = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('참조 멜로디 생성 실패: $e')),
      );
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
            if (_melodyEval != null) _buildDTWFeedbackCard(),
            _buildScoreCard(),
            _buildDetailedAnalysis(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDTWFeedbackCard() {
    final e = _melodyEval!;
    final pct = (e.overallScore * 100).toStringAsFixed(1);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: Colors.indigo),
              const SizedBox(width: 8),
              Text('DTW Alignment • $pct%', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _showDTW = !_showDTW),
                child: Text(_showDTW ? 'Hide' : 'Show'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(e.summary),
          if (e.strengths.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Strengths', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final s in e.strengths) Text('• $s'),
          ],
          if (e.improvements.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Improvements', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final s in e.improvements) Text('• $s'),
          ],
          if (_showDTW) ...[
            const SizedBox(height: 12),
            DTWAlignmentVisualizer(
              alignmentResult: e.alignment,
              referencePitch: widget.referencePitch!,
              userPitch: widget.timeBasedResults!.map((r) => r.frequency).toList(),
              width: MediaQuery.of(context).size.width - 32,
              height: 240,
            ),
          ],
        ],
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
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _loadingReference ? null : _pickAndAnalyzeReference,
            icon: const Icon(Icons.library_music, size: 18),
            label: Text(_loadingReference ? '분석 중...' : '참조 멜로디 불러오기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _loadingReference ? Colors.grey : Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      child: _currentViewMode == 0 ? _buildAnalysisView() : _buildOtherViews(),
    );
  }
  
  Widget _buildAnalysisView() {
    return Stack(
      children: [
        // 피치 그래프 직접 그리기 (RealtimePitchGraph의 PitchGraphPainter 사용)
        if (_analysisPitchPoints.isNotEmpty)
          CustomPaint(
            painter: AnalysisPitchGraphPainter(
              pitchData: _analysisPitchPoints,
              animationValue: _animation.value,
              isPlaying: false,
              currentTime: null,
            ),
            child: Container(),
          ),
        
        // 피치 데이터가 없는 경우 기본 그리드와 곡선
        if (_analysisPitchPoints.isEmpty) ...[
          CustomPaint(
            painter: GridPainter(),
            child: Container(),
          ),
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
        ],
        
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
    );
  }
  
  Widget _buildOtherViews() {
    return Stack(
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

// RealtimePitchGraph의 PitchGraphPainter를 기반으로 한 분석용 피치 그래프 페인터
class AnalysisPitchGraphPainter extends CustomPainter {
  final List<AnalysisPitchPoint> pitchData;
  final double animationValue;
  final bool isPlaying;
  final double? currentTime;
  
  AnalysisPitchGraphPainter({
    required this.pitchData,
    required this.animationValue,
    required this.isPlaying,
    this.currentTime,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // 배경 그리드 그리기
    _drawGrid(canvas, size);
    
    // 음정 노트 레이블
    _drawNoteLabels(canvas, size);
    
    // 피치 곡선 그리기
    if (pitchData.isNotEmpty) {
      _drawPitchCurve(canvas, size);
    }
    
    // 현재 피치 포인트 강조
    if (pitchData.isNotEmpty) {
      _drawCurrentPoint(canvas, size);
    }
  }
  
  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1;
    
    final majorGridPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 1.5;
    
    // 수평선 (음정 구분) - 더 많은 음계 표시
    const noteFrequencies = [
      {'freq': 196, 'note': 'G3'}, // 솔
      {'freq': 220, 'note': 'A3'}, // 라
      {'freq': 247, 'note': 'B3'}, // 시
      {'freq': 262, 'note': 'C4'}, // 도 (중앙 도)
      {'freq': 294, 'note': 'D4'}, // 레
      {'freq': 330, 'note': 'E4'}, // 미
      {'freq': 349, 'note': 'F4'}, // 파
      {'freq': 392, 'note': 'G4'}, // 솔
      {'freq': 440, 'note': 'A4'}, // 라 (기준음)
      {'freq': 494, 'note': 'B4'}, // 시
      {'freq': 523, 'note': 'C5'}, // 도
      {'freq': 587, 'note': 'D5'}, // 레
      {'freq': 659, 'note': 'E5'}, // 미
    ];
    
    for (final noteInfo in noteFrequencies) {
      final freq = (noteInfo['freq'] as num).toDouble();
      final y = _frequencyToY(freq, size);
      final paint = freq == 440.0 ? majorGridPaint : gridPaint; // A4는 주요 그리드
      
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
    
    // 수직선 (시간 구분)
    const timeLines = 8;
    for (int i = 0; i <= timeLines; i++) {
      final x = size.width * i / timeLines;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }
  }
  
  void _drawNoteLabels(Canvas canvas, Size size) {
    const notes = [
      {'freq': 220, 'note': 'A3'},
      {'freq': 262, 'note': 'C4'},
      {'freq': 330, 'note': 'E4'},
      {'freq': 440, 'note': 'A4'}, // 기준음
      {'freq': 523, 'note': 'C5'},
      {'freq': 659, 'note': 'E5'},
    ];
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    for (final note in notes) {
      final freq = (note['freq'] as int).toDouble();
      final y = _frequencyToY(freq, size);
      
      // A4는 기준음이므로 강조 표시
      final isReference = freq == 440.0;
      
      textPainter.text = TextSpan(
        text: note['note'] as String,
        style: TextStyle(
          color: isReference 
              ? const Color(0xFF7C4DFF).withOpacity(0.9)
              : Colors.white.withOpacity(0.6),
          fontSize: isReference ? 12 : 10,
          fontWeight: isReference ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      
      // 배경 박스 추가 (기준음의 경우)
      if (isReference) {
        final bgRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(2, y - 14, textPainter.width + 6, textPainter.height + 4),
          const Radius.circular(4),
        );
        final bgPaint = Paint()
          ..color = const Color(0xFF7C4DFF).withOpacity(0.2)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(bgRect, bgPaint);
      }
      
      textPainter.paint(canvas, Offset(5, y - 12));
    }
    
    // 우상단에 시간 레이블
    final timePainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= 4; i++) {
      final timeSeconds = i * 2.5; // 0, 2.5, 5, 7.5, 10초
      final x = size.width * (timeSeconds / 10.0);
      
      timePainter.text = TextSpan(
        text: '${timeSeconds.toStringAsFixed(1)}s',
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 9,
        ),
      );
      timePainter.layout();
      timePainter.paint(canvas, Offset(x - timePainter.width / 2, 5));
    }
  }
  
  void _drawPitchCurve(Canvas canvas, Size size) {
    if (pitchData.length < 2) return;
    
    final path = Path();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    // 첫 점으로 이동
    if (pitchData.isEmpty) return;
    final firstPoint = pitchData.first;
    final firstX = _timeToX(firstPoint.time, size);
    final firstY = _frequencyToY(firstPoint.frequency, size);
    path.moveTo(firstX, firstY);
    
    // 나머지 점들 연결
    for (int i = 1; i < pitchData.length; i++) {
      final point = pitchData[i];
      final x = _timeToX(point.time, size);
      final y = _frequencyToY(point.frequency, size);
      
      // 베지어 곡선으로 부드럽게 연결
      if (i > 0) {
        final prevPoint = pitchData[i - 1];
        final prevX = _timeToX(prevPoint.time, size);
        final prevY = _frequencyToY(prevPoint.frequency, size);
        
        final controlX1 = prevX + (x - prevX) / 3;
        final controlY1 = prevY;
        final controlX2 = x - (x - prevX) / 3;
        final controlY2 = y;
        
        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }
    
    // 그라데이션 적용
    paint.shader = LinearGradient(
      colors: [
        const Color(0xFF7C4DFF),
        const Color(0xFF9C88FF),
        const Color(0xFFFF6B6B),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawPath(path, paint);
    
    // 신뢰도에 따른 투명도로 그림자 효과
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    for (int i = 1; i < pitchData.length; i++) {
      final point = pitchData[i];
      glowPaint.color = const Color(0xFF7C4DFF).withOpacity(point.confidence * 0.3);
      
      final x = _timeToX(point.time, size);
      final y = _frequencyToY(point.frequency, size);
      
      if (i > 0) {
        final prevPoint = pitchData[i - 1];
        final prevX = _timeToX(prevPoint.time, size);
        final prevY = _frequencyToY(prevPoint.frequency, size);
        
        canvas.drawLine(Offset(prevX, prevY), Offset(x, y), glowPaint);
      }
    }
  }
  
  void _drawCurrentPoint(Canvas canvas, Size size) {
    if (pitchData.isEmpty) return;
    
    // 현재 시간에 해당하는 포인트 찾기
    AnalysisPitchPoint currentPoint;
    
    if (currentTime != null && isPlaying) {
      // 재생 중이면 현재 시간에 가장 가까운 포인트 찾기
      currentPoint = pitchData.last; // 기본값
      double minTimeDiff = double.infinity;
      
      for (final point in pitchData) {
        final timeDiff = (point.time - currentTime!).abs();
        if (timeDiff < minTimeDiff) {
          minTimeDiff = timeDiff;
          currentPoint = point;
        }
      }
    } else {
      // 재생 중이 아니면 마지막 포인트 사용
      currentPoint = pitchData.last;
    }
    
    final x = _timeToX(currentPoint.time, size);
    final y = _frequencyToY(currentPoint.frequency, size);
    
    // 신뢰도에 따른 색상 결정
    final confidence = currentPoint.confidence;
    final baseColor = confidence > 0.7 
        ? const Color(0xFF4CAF50) // 높은 신뢰도 - 초록
        : confidence > 0.4 
            ? const Color(0xFF7C4DFF) // 중간 신뢰도 - 보라
            : const Color(0xFFFF9800); // 낮은 신뢰도 - 주황
    
    if (isPlaying) {
      // 재생 중일 때만 펄스 애니메이션
      final pulseRadius = 12 + animationValue * 8;
      
      // 외부 원 (펄스)
      final pulsePaint = Paint()
        ..color = baseColor.withOpacity((1 - animationValue) * 0.4)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), pulseRadius, pulsePaint);
      
      // 중간 원 (글로우 효과)
      final glowPaint = Paint()
        ..color = baseColor.withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), 8, glowPaint);
    }
    
    // 내부 원
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(x, y), 6, centerPaint);
    
    final borderPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(Offset(x, y), 6, borderPaint);
    
    // 현재 주파수와 음정 표시
    final noteName = _frequencyToNote(currentPoint.frequency);
    final frequencyText = '${currentPoint.frequency.round()}Hz';
    
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: noteName,
            style: TextStyle(
              color: baseColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: '\n$frequencyText',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    
    // 텍스트 배경
    final textX = x - textPainter.width / 2;
    final textY = y - 45;
    final textBgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(textX - 4, textY - 2, textPainter.width + 8, textPainter.height + 4),
      const Radius.circular(6),
    );
    final textBgPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(textBgRect, textBgPaint);
    
    textPainter.paint(canvas, Offset(textX, textY));
  }
  
  double _frequencyToY(double frequency, Size size) {
    // 주파수 범위: 100Hz ~ 800Hz
    const minFreq = 100.0;
    const maxFreq = 800.0;
    
    final normalized = (frequency - minFreq) / (maxFreq - minFreq);
    return size.height - (normalized * size.height);
  }
  
  double _timeToX(double time, Size size) {
    // 시간 범위: 0 ~ 10초
    const maxTime = 10.0;
    return (time / maxTime) * size.width;
  }
  
  String _frequencyToNote(double frequency) {
    // A4 = 440Hz를 기준으로 계산
    const double a4 = 440.0;
    const List<String> noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    
    // 주파수가 너무 낮거나 높으면 빈 문자열 반환
    if (frequency < 80 || frequency > 2000) return '';
    
    // A4(440Hz)로부터 몇 개의 반음(semitone) 떨어져 있는지 계산
    final double semitonesFromA4 = 12 * (math.log(frequency / a4) / math.ln2);
    final int semitoneIndex = semitonesFromA4.round();
    
    // A4는 인덱스 9 (A)
    final int noteIndex = (9 + semitoneIndex) % 12;
    final int octave = 4 + ((9 + semitoneIndex) ~/ 12);
    
    // 음정 이름과 옥타브 조합
    final String noteName = noteNames[noteIndex < 0 ? noteIndex + 12 : noteIndex];
    return '$noteName$octave';
  }
  
  @override
  bool shouldRepaint(AnalysisPitchGraphPainter oldDelegate) {
    return oldDelegate.pitchData != pitchData ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.currentTime != currentTime ||
           oldDelegate.isPlaying != isPlaying;
  }
}
