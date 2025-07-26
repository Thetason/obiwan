import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../features/audio_analysis/timbre_analyzer.dart';

class TimbreAnalysisDisplay extends StatelessWidget {
  final TimbreAnalysis? analysis;
  final bool isAnalyzing;
  
  const TimbreAnalysisDisplay({
    Key? key,
    this.analysis,
    this.isAnalyzing = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (isAnalyzing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('음색 분석 중...'),
          ],
        ),
      );
    }
    
    if (analysis == null) {
      return const Center(
        child: Text(
          '녹음을 시작하여 음색을 분석해보세요',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVoiceTypeCard(context),
          const SizedBox(height: 16),
          _buildTimbreRadarChart(context),
          const SizedBox(height: 16),
          _buildDetailedMetrics(context),
          const SizedBox(height: 16),
          _buildFormantDisplay(context),
          const SizedBox(height: 16),
          _buildRecommendations(context),
        ],
      ),
    );
  }
  
  Widget _buildVoiceTypeCard(BuildContext context) {
    final voiceQuality = analysis!.voiceQuality;
    final color = _getQualityColor(voiceQuality.overallScore);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '음색 타입',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      voiceQuality.voiceType,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.2),
                    border: Border.all(color: color, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      '${(voiceQuality.overallScore * 100).round()}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildScoreIndicator(
                  label: '명료도',
                  score: voiceQuality.clarityScore,
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildScoreIndicator(
                  label: '톤',
                  score: voiceQuality.toneScore,
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildScoreIndicator({
    required String label,
    required double score,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: score,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
          const SizedBox(height: 4),
          Text(
            '${(score * 100).round()}%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTimbreRadarChart(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '음색 특성 분석',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: _buildSimpleRadarChart(context),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailedMetrics(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '상세 측정값',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              icon: Icons.wb_sunny,
              label: '밝기 (Brightness)',
              value: '${(analysis!.brightness * 100).round()}%',
              color: Colors.orange,
            ),
            _buildMetricRow(
              icon: Icons.local_fire_department,
              label: '따뜻함 (Warmth)',
              value: '${(analysis!.warmth * 100).round()}%',
              color: Colors.red,
            ),
            _buildMetricRow(
              icon: Icons.grain,
              label: '거칠기 (Roughness)',
              value: '${(analysis!.roughness * 100).round()}%',
              color: Colors.brown,
            ),
            _buildMetricRow(
              icon: Icons.air,
              label: '숨소리 (Breathiness)',
              value: '${(analysis!.breathiness * 100).round()}%',
              color: Colors.blue,
            ),
            _buildMetricRow(
              icon: Icons.graphic_eq,
              label: '하모닉 비율',
              value: '${(analysis!.harmonicRatio * 100).round()}%',
              color: Colors.purple,
            ),
            _buildMetricRow(
              icon: Icons.vibration,
              label: '진폭 변화 (Shimmer)',
              value: '${analysis!.shimmer.toStringAsFixed(2)}%',
              color: Colors.teal,
            ),
            _buildMetricRow(
              icon: Icons.timer,
              label: '주파수 변화 (Jitter)',
              value: '${analysis!.jitter.toStringAsFixed(2)}%',
              color: Colors.indigo,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFormantDisplay(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '포먼트 주파수',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '음성의 특징적인 공명 주파수',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (int i = 0; i < math.min(4, analysis!.formants.length); i++)
                  _buildFormantIndicator(
                    label: 'F${i + 1}',
                    frequency: analysis!.formants[i],
                    color: _getFormantColor(i),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFormantIndicator({
    required String label,
    required double frequency,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            color: color.withOpacity(0.1),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${frequency.round()} Hz',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildRecommendations(BuildContext context) {
    final recommendations = analysis!.voiceQuality.recommendations;
    
    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tips_and_updates,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  '개선 제안',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...recommendations.map((recommendation) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }
  
  Color _getQualityColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.blue;
    if (score >= 0.4) return Colors.orange;
    return Colors.red;
  }
  
  Widget _buildSimpleRadarChart(BuildContext context) {
    return CustomPaint(
      size: const Size.square(250),
      painter: RadarChartPainter(
        values: [
          analysis!.brightness,
          analysis!.warmth,
          1 - analysis!.roughness,
          1 - analysis!.breathiness,
          analysis!.harmonicRatio,
        ],
        labels: ['밝기', '따뜻함', '부드러움', '맑음', '하모닉'],
        color: Theme.of(context).primaryColor,
      ),
    );
  }
  
  Color _getFormantColor(int index) {
    const colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.purple,
    ];
    return colors[index % colors.length];
  }
}

class RadarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color color;
  
  RadarChartPainter({
    required this.values,
    required this.labels,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 40;
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Draw grid circles
    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center, radius * i / 5, paint);
    }
    
    // Draw axes
    final axisCount = values.length;
    for (int i = 0; i < axisCount; i++) {
      final angle = (i * 2 * math.pi / axisCount) - math.pi / 2;
      final endPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, endPoint, paint);
    }
    
    // Draw data
    final dataPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final angle = (i * 2 * math.pi / axisCount) - math.pi / 2;
      final distance = radius * values[i];
      final point = Offset(
        center.dx + distance * math.cos(angle),
        center.dy + distance * math.sin(angle),
      );
      
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, dataPaint);
    
    // Draw data border
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);
    
    // Draw labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    for (int i = 0; i < labels.length; i++) {
      final angle = (i * 2 * math.pi / axisCount) - math.pi / 2;
      final labelDistance = radius + 20;
      final labelPoint = Offset(
        center.dx + labelDistance * math.cos(angle),
        center.dy + labelDistance * math.sin(angle),
      );
      
      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          labelPoint.dx - textPainter.width / 2,
          labelPoint.dy - textPainter.height / 2,
        ),
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}