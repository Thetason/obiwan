import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/debug_logger.dart';

class PerformanceMonitor extends StatefulWidget {
  final bool enabled;
  
  const PerformanceMonitor({
    Key? key,
    this.enabled = false,
  }) : super(key: key);

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor>
    with TickerProviderStateMixin {
  
  Timer? _updateTimer;
  
  // Performance data storage
  final List<FlSpot> _fpsData = [];
  final List<FlSpot> _memoryData = [];
  final List<FlSpot> _renderTimeData = [];
  final List<FlSpot> _networkData = [];
  
  // Current metrics
  double _currentFPS = 60.0;
  double _currentMemory = 0.0;
  double _currentRenderTime = 16.67; // 60fps = 16.67ms per frame
  double _currentNetworkThroughput = 0.0;
  
  // FPS measurement
  late Ticker _fpsTicker;
  final List<Duration> _frameTimes = [];
  DateTime _lastFrameTime = DateTime.now();
  
  // Render time measurement
  final List<double> _renderTimes = [];
  
  // Animation controllers
  late AnimationController _chartAnimationController;
  
  // Data point counter
  int _dataPointCounter = 0;
  static const int maxDataPoints = 60; // Show last 60 data points
  
  // Bottleneck detection
  final Map<String, double> _bottleneckScores = {
    'CPU': 0.0,
    'Memory': 0.0,
    'Render': 0.0,
    'Network': 0.0,
  };
  
  @override
  void initState() {
    super.initState();
    
    _chartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fpsTicker = createTicker(_onTick);
    
    if (widget.enabled) {
      _startMonitoring();
    }
  }
  
  @override
  void didUpdateWidget(PerformanceMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _startMonitoring();
      } else {
        _stopMonitoring();
      }
    }
  }
  
  void _onTick(Duration elapsed) {
    final now = DateTime.now();
    final frameDuration = now.difference(_lastFrameTime);
    _lastFrameTime = now;
    
    _frameTimes.add(frameDuration);
    _renderTimes.add(frameDuration.inMicroseconds / 1000.0); // Convert to ms
    
    // Keep only recent data
    if (_frameTimes.length > 60) {
      _frameTimes.removeAt(0);
    }
    if (_renderTimes.length > 60) {
      _renderTimes.removeAt(0);
    }
    
    // Calculate current FPS
    if (_frameTimes.isNotEmpty) {
      final totalFrameTime = _frameTimes.fold<Duration>(
        Duration.zero,
        (prev, time) => prev + time,
      );
      final averageFrameTimeMs = totalFrameTime.inMilliseconds / _frameTimes.length;
      
      _currentFPS = 1000.0 / averageFrameTimeMs;
    }
    
    // Calculate current render time
    if (_renderTimes.isNotEmpty) {
      _currentRenderTime = _renderTimes.fold<double>(
        0.0,
        (prev, time) => prev + time,
      ) / _renderTimes.length;
    }
  }
  
  void _startMonitoring() {
    _fpsTicker.start();
    _chartAnimationController.repeat();
    
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _updateMetrics();
    });
  }
  
  void _stopMonitoring() {
    _fpsTicker.stop();
    _chartAnimationController.stop();
    _updateTimer?.cancel();
  }
  
  void _updateMetrics() async {
    if (!mounted) return;
    
    try {
      // Update memory usage
      final memoryUsage = await _getMemoryUsage();
      _currentMemory = memoryUsage;
      
      // Simulate network throughput (in real app, this would come from network interceptor)
      _currentNetworkThroughput = _simulateNetworkThroughput();
      
      // Add data points
      _addDataPoint();
      
      // Update bottleneck scores
      _updateBottleneckScores();
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      logger.error('성능 메트릭 업데이트 실패: $e');
    }
  }
  
  Future<double> _getMemoryUsage() async {
    // Simplified memory usage calculation
    // In a real implementation, you'd use platform-specific methods
    return 45.0 + Random().nextDouble() * 10.0; // MB
  }
  
  double _simulateNetworkThroughput() {
    // Simulate network throughput in KB/s
    return Random().nextDouble() * 100.0;
  }
  
  void _addDataPoint() {
    final x = _dataPointCounter.toDouble();
    
    // Add new data points
    _fpsData.add(FlSpot(x, _currentFPS));
    _memoryData.add(FlSpot(x, _currentMemory));
    _renderTimeData.add(FlSpot(x, _currentRenderTime));
    _networkData.add(FlSpot(x, _currentNetworkThroughput));
    
    // Remove old data points
    if (_fpsData.length > maxDataPoints) {
      _fpsData.removeAt(0);
      _memoryData.removeAt(0);
      _renderTimeData.removeAt(0);
      _networkData.removeAt(0);
    }
    
    _dataPointCounter++;
  }
  
  void _updateBottleneckScores() {
    // Calculate bottleneck scores (0.0 = no bottleneck, 1.0 = severe bottleneck)
    _bottleneckScores['CPU'] = _currentFPS < 30 ? (60 - _currentFPS) / 30.0 : 0.0;
    _bottleneckScores['Memory'] = _currentMemory > 100 ? (_currentMemory - 100) / 100.0 : 0.0;
    _bottleneckScores['Render'] = _currentRenderTime > 20 ? (_currentRenderTime - 16.67) / 10.0 : 0.0;
    _bottleneckScores['Network'] = _currentNetworkThroughput < 10 ? (10 - _currentNetworkThroughput) / 10.0 : 0.0;
    
    // Clamp values
    _bottleneckScores.updateAll((key, value) => value.clamp(0.0, 1.0));
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.analytics,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Performance Monitor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _buildLegend(),
            ],
          ),
          const SizedBox(height: 16),
          
          // Charts
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildPerformanceCharts(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: _buildBottleneckHeatmap(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Current metrics
          _buildCurrentMetrics(),
        ],
      ),
    );
  }
  
  Widget _buildLegend() {
    return Row(
      children: [
        _buildLegendItem(Colors.green, 'FPS'),
        const SizedBox(width: 8),
        _buildLegendItem(Colors.orange, 'Memory'),
        const SizedBox(width: 8),
        _buildLegendItem(Colors.red, 'Render'),
        const SizedBox(width: 8),
        _buildLegendItem(Colors.cyan, 'Network'),
      ],
    );
  }
  
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPerformanceCharts() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: _fpsData.isNotEmpty ? _fpsData.first.x : 0,
        maxX: _fpsData.isNotEmpty ? _fpsData.last.x : 60,
        minY: 0,
        maxY: 120,
        lineBarsData: [
          // FPS line
          LineChartBarData(
            spots: _fpsData,
            color: Colors.green,
            barWidth: 2,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withOpacity(0.1),
            ),
          ),
          // Memory line (scaled)
          LineChartBarData(
            spots: _memoryData.map((spot) => FlSpot(spot.x, spot.y)).toList(),
            color: Colors.orange,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
          // Render time line (scaled)
          LineChartBarData(
            spots: _renderTimeData.map((spot) => FlSpot(spot.x, spot.y * 3)).toList(),
            color: Colors.red,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
          // Network line
          LineChartBarData(
            spots: _networkData,
            color: Colors.cyan,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBottleneckHeatmap() {
    return Column(
      children: [
        const Text(
          'Bottlenecks',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Column(
            children: _bottleneckScores.entries.map((entry) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getBottleneckColor(entry.value),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${(entry.value * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  Color _getBottleneckColor(double score) {
    if (score < 0.3) return Colors.green.withOpacity(0.3);
    if (score < 0.6) return Colors.orange.withOpacity(0.3);
    return Colors.red.withOpacity(0.3);
  }
  
  Widget _buildCurrentMetrics() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'FPS',
            _currentFPS.toStringAsFixed(1),
            Colors.green,
            Icons.speed,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            'Memory',
            '${_currentMemory.toStringAsFixed(1)} MB',
            Colors.orange,
            Icons.memory,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            'Render',
            '${_currentRenderTime.toStringAsFixed(1)} ms',
            Colors.red,
            Icons.timer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            'Network',
            '${_currentNetworkThroughput.toStringAsFixed(1)} KB/s',
            Colors.cyan,
            Icons.network_check,
          ),
        ),
      ],
    );
  }
  
  Widget _buildMetricCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _stopMonitoring();
    _chartAnimationController.dispose();
    super.dispose();
  }
}