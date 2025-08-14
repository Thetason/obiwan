import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/dtw_melody_aligner.dart';

/// DTW 정렬 결과 시각화 위젯
/// 원곡과 사용자 멜로디의 정렬을 시각적으로 표현
class DTWAlignmentVisualizer extends StatefulWidget {
  final DTWMelodyAligner.AlignmentResult alignmentResult;
  final List<double> referencePitch;
  final List<double> userPitch;
  final double width;
  final double height;
  
  const DTWAlignmentVisualizer({
    Key? key,
    required this.alignmentResult,
    required this.referencePitch,
    required this.userPitch,
    this.width = 400,
    this.height = 300,
  }) : super(key: key);
  
  @override
  State<DTWAlignmentVisualizer> createState() => _DTWAlignmentVisualizerState();
}

class _DTWAlignmentVisualizerState extends State<DTWAlignmentVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _selectedPointIndex = -1;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Stack(
                  children: [
                    _buildAlignmentGrid(),
                    _buildAlignmentPath(),
                    if (_selectedPointIndex >= 0) _buildTooltip(),
                  ],
                );
              },
            ),
          ),
          _buildMetrics(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    final quality = widget.alignmentResult.alignmentQuality;
    final qualityColor = _getQualityColor(quality);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            qualityColor.withOpacity(0.2),
            qualityColor.withOpacity(0.1),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timeline,
            color: qualityColor,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            'DTW 멜로디 정렬',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: qualityColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: qualityColor.withOpacity(0.5),
              ),
            ),
            child: Text(
              '${(quality * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: qualityColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAlignmentGrid() {
    return GestureDetector(
      onTapDown: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        _handleTap(localPosition);
      },
      child: CustomPaint(
        size: Size(widget.width, widget.height - 120),
        painter: AlignmentGridPainter(
          alignmentResult: widget.alignmentResult,
          referencePitch: widget.referencePitch,
          userPitch: widget.userPitch,
          animationValue: _animation.value,
          selectedPointIndex: _selectedPointIndex,
        ),
      ),
    );
  }
  
  Widget _buildAlignmentPath() {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(widget.width, widget.height - 120),
        painter: AlignmentPathPainter(
          alignmentPath: widget.alignmentResult.alignmentPath,
          referenceLength: widget.referencePitch.length,
          userLength: widget.userPitch.length,
          animationValue: _animation.value,
        ),
      ),
    );
  }
  
  Widget _buildTooltip() {
    if (_selectedPointIndex < 0 || 
        _selectedPointIndex >= widget.alignmentResult.noteMatchings.length) {
      return const SizedBox.shrink();
    }
    
    final matching = widget.alignmentResult.noteMatchings[_selectedPointIndex];
    
    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '음정 매칭 #$_selectedPointIndex',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildTooltipRow(
              '원곡',
              '${matching.referenceNote.toStringAsFixed(1)} Hz',
            ),
            _buildTooltipRow(
              '사용자',
              '${matching.userNote.toStringAsFixed(1)} Hz',
            ),
            _buildTooltipRow(
              '오차',
              '${matching.pitchError.toStringAsFixed(1)} cents',
              color: matching.isCorrect ? Colors.green : Colors.orange,
            ),
            _buildTooltipRow(
              '타이밍',
              '${(matching.timingError * 1000).toStringAsFixed(0)} ms',
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTooltipRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetrics() {
    final result = widget.alignmentResult;
    final correctCount = result.noteMatchings.where((m) => m.isCorrect).length;
    final totalCount = result.noteMatchings.length;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricItem(
            icon: Icons.music_note,
            label: '정확한 음',
            value: '$correctCount / $totalCount',
            color: Colors.green,
          ),
          _buildMetricItem(
            icon: Icons.speed,
            label: '타이밍',
            value: result.timingAccuracy,
            color: Colors.blue,
          ),
          _buildMetricItem(
            icon: Icons.trending_up,
            label: '거리',
            value: result.normalizedDistance.toStringAsFixed(1),
            color: Colors.orange,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  void _handleTap(Offset localPosition) {
    // 탭 위치에서 가장 가까운 정렬 포인트 찾기
    final alignmentPath = widget.alignmentResult.alignmentPath;
    if (alignmentPath.isEmpty) return;
    
    final gridHeight = widget.height - 120;
    final cellWidth = widget.width / widget.userPitch.length;
    final cellHeight = gridHeight / widget.referencePitch.length;
    
    double minDistance = double.infinity;
    int closestIndex = -1;
    
    for (int i = 0; i < alignmentPath.length; i++) {
      final point = alignmentPath[i];
      final x = point.userIndex * cellWidth;
      final y = point.referenceIndex * cellHeight;
      
      final distance = math.sqrt(
        math.pow(x - localPosition.dx, 2) +
        math.pow(y - localPosition.dy, 2),
      );
      
      if (distance < minDistance && distance < 20) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    
    setState(() {
      _selectedPointIndex = closestIndex;
    });
  }
  
  Color _getQualityColor(double quality) {
    if (quality > 0.8) return Colors.green;
    if (quality > 0.6) return Colors.blue;
    if (quality > 0.4) return Colors.orange;
    return Colors.red;
  }
}

/// DTW 정렬 그리드 페인터
class AlignmentGridPainter extends CustomPainter {
  final DTWMelodyAligner.AlignmentResult alignmentResult;
  final List<double> referencePitch;
  final List<double> userPitch;
  final double animationValue;
  final int selectedPointIndex;
  
  AlignmentGridPainter({
    required this.alignmentResult,
    required this.referencePitch,
    required this.userPitch,
    required this.animationValue,
    required this.selectedPointIndex,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // 배경 그리드
    _drawGrid(canvas, size);
    
    // 피치 곡선
    _drawPitchCurves(canvas, size);
    
    // 매칭 포인트
    _drawMatchingPoints(canvas, size);
  }
  
  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    // 수직선
    const verticalLines = 10;
    for (int i = 0; i <= verticalLines; i++) {
      final x = size.width * i / verticalLines;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    // 수평선
    const horizontalLines = 8;
    for (int i = 0; i <= horizontalLines; i++) {
      final y = size.height * i / horizontalLines;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }
  
  void _drawPitchCurves(Canvas canvas, Size size) {
    // 원곡 피치 (상단)
    _drawPitchCurve(
      canvas,
      size,
      referencePitch,
      Colors.blue.withOpacity(0.5),
      0,
      size.height * 0.4,
    );
    
    // 사용자 피치 (하단)
    _drawPitchCurve(
      canvas,
      size,
      userPitch,
      Colors.green.withOpacity(0.5),
      size.height * 0.6,
      size.height,
    );
  }
  
  void _drawPitchCurve(
    Canvas canvas,
    Size size,
    List<double> pitchData,
    Color color,
    double yStart,
    double yEnd,
  ) {
    if (pitchData.isEmpty) return;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    final stepX = size.width / pitchData.length;
    final yRange = yEnd - yStart;
    
    // 피치 범위 계산
    final minPitch = pitchData.where((p) => p > 0).fold<double>(
      double.infinity,
      (min, p) => p < min ? p : min,
    );
    final maxPitch = pitchData.where((p) => p > 0).fold<double>(
      0,
      (max, p) => p > max ? p : max,
    );
    final pitchRange = maxPitch - minPitch;
    
    bool started = false;
    for (int i = 0; i < pitchData.length * animationValue; i++) {
      if (pitchData[i] <= 0) {
        started = false;
        continue;
      }
      
      final x = i * stepX;
      final normalizedPitch = (pitchData[i] - minPitch) / pitchRange;
      final y = yStart + yRange * (1 - normalizedPitch);
      
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
  }
  
  void _drawMatchingPoints(Canvas canvas, Size size) {
    final noteMatchings = alignmentResult.noteMatchings;
    if (noteMatchings.isEmpty) return;
    
    for (int i = 0; i < noteMatchings.length * animationValue; i++) {
      final matching = noteMatchings[i];
      final isSelected = i == selectedPointIndex;
      
      // 색상 결정
      final color = matching.isCorrect
          ? Colors.green
          : (matching.pitchError.abs() < 50 ? Colors.orange : Colors.red);
      
      final paint = Paint()
        ..color = color.withOpacity(isSelected ? 1.0 : 0.6)
        ..style = PaintingStyle.fill;
      
      // 위치 계산
      final x = (matching.userTime * 100 / userPitch.length) * size.width;
      final y = size.height * 0.5;
      
      // 원 크기
      final radius = isSelected ? 6.0 : 4.0;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
      
      // 선택된 포인트 강조
      if (isSelected) {
        final glowPaint = Paint()
          ..color = color.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), radius + 4, glowPaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant AlignmentGridPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.selectedPointIndex != selectedPointIndex;
  }
}

/// DTW 경로 페인터
class AlignmentPathPainter extends CustomPainter {
  final List<DTWMelodyAligner.AlignmentPoint> alignmentPath;
  final int referenceLength;
  final int userLength;
  final double animationValue;
  
  AlignmentPathPainter({
    required this.alignmentPath,
    required this.referenceLength,
    required this.userLength,
    required this.animationValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (alignmentPath.isEmpty) return;
    
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.purple.withOpacity(0.6),
          Colors.blue.withOpacity(0.6),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    
    for (int i = 0; i < alignmentPath.length * animationValue; i++) {
      final point = alignmentPath[i];
      
      // 정규화된 좌표
      final x = (point.userIndex / userLength) * size.width;
      final y = (point.referenceIndex / referenceLength) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // 부드러운 곡선
        final prevPoint = alignmentPath[i - 1];
        final prevX = (prevPoint.userIndex / userLength) * size.width;
        final prevY = (prevPoint.referenceIndex / referenceLength) * size.height;
        
        final controlX = (prevX + x) / 2;
        final controlY = (prevY + y) / 2;
        
        path.quadraticBezierTo(controlX, controlY, x, y);
      }
    }
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant AlignmentPathPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}