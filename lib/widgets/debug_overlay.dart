import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../core/debug_logger.dart';

class DebugOverlay extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const DebugOverlay({
    Key? key,
    required this.child,
    this.enabled = false,
  }) : super(key: key);

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay>
    with TickerProviderStateMixin {
  bool _isVisible = false;
  bool _isExpanded = false;
  bool _isDragging = false;
  
  // Position management
  Offset _position = const Offset(20, 100);
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  
  // Performance metrics
  Timer? _metricsTimer;
  double _fps = 60.0;
  double _memoryUsage = 0.0;
  double _audioLevel = 0.0;
  double _pitchLatency = 0.0;
  int _networkRequests = 0;
  int _frameCount = 0;
  DateTime _lastFrameTime = DateTime.now();
  
  // FPS calculation
  late Ticker _fpsTicker;
  final List<Duration> _frameTimes = [];
  
  // Device info
  String _deviceInfo = '';
  
  @override
  void initState() {
    super.initState();
    
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    
    _fpsTicker = createTicker(_onTick);
    
    if (widget.enabled) {
      _isVisible = true;
      _startMonitoring();
      _loadDeviceInfo();
    }
  }
  
  @override
  void didUpdateWidget(DebugOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.enabled != oldWidget.enabled) {
      setState(() {
        _isVisible = widget.enabled;
      });
      
      if (widget.enabled) {
        _startMonitoring();
        _loadDeviceInfo();
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
    
    // Keep only last 60 frame times
    if (_frameTimes.length > 60) {
      _frameTimes.removeAt(0);
    }
    
    // Calculate FPS
    if (_frameTimes.isNotEmpty) {
      final totalFrameTime = _frameTimes.fold<Duration>(
        Duration.zero,
        (prev, time) => prev + time,
      );
      final averageFrameTimeMs = totalFrameTime.inMilliseconds / _frameTimes.length;
      
      _fps = 1000.0 / averageFrameTimeMs;
    }
    
    _frameCount++;
  }
  
  void _startMonitoring() {
    _fpsTicker.start();
    
    _metricsTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _updateMetrics();
    });
  }
  
  void _stopMonitoring() {
    _fpsTicker.stop();
    _metricsTimer?.cancel();
  }
  
  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceInfo = '${androidInfo.brand} ${androidInfo.model}\\n'
            'Android ${androidInfo.version.release}\\n'
            'SDK ${androidInfo.version.sdkInt}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceInfo = '${iosInfo.model}\\n'
            'iOS ${iosInfo.systemVersion}\\n'
            '${iosInfo.name}';
      } else {
        _deviceInfo = 'Desktop Platform';
      }
      
      if (mounted) setState(() {});
    } catch (e) {
      logger.error('디바이스 정보 로드 실패: $e');
    }
  }
  
  void _updateMetrics() async {
    if (!mounted) return;
    
    try {
      // Memory usage calculation
      final info = await ProcessInfo.currentMemoryUsage;
      _memoryUsage = info.rss / (1024 * 1024); // MB
      
      // Mock audio level and pitch latency for now
      // These would be updated by actual audio services
      _audioLevel = (_audioLevel + (DateTime.now().microsecond % 100) / 100.0) % 1.0;
      _pitchLatency = 10.0 + (DateTime.now().microsecond % 20);
      
    } catch (e) {
      logger.error('메트릭 업데이트 실패: $e');
    }
    
    if (mounted) {
      setState(() {});
    }
  }
  
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    
    if (_isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }
  
  Widget _buildCompactView() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FPS indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _fps > 50 ? Colors.green : _fps > 30 ? Colors.orange : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${_fps.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          // Memory indicator
          Icon(
            Icons.memory,
            color: _memoryUsage < 100 ? Colors.green : Colors.orange,
            size: 12,
          ),
          const SizedBox(width: 2),
          Text(
            '${_memoryUsage.toStringAsFixed(0)}M',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExpandedView() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 1),
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
                Icons.bug_report,
                color: Colors.green,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Debug Panel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _toggleExpanded,
                child: const Icon(
                  Icons.minimize,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          
          // Performance metrics
          _buildMetricRow('FPS', '${_fps.toStringAsFixed(1)}', 
              _fps > 50 ? Colors.green : _fps > 30 ? Colors.orange : Colors.red),
          _buildMetricRow('Memory', '${_memoryUsage.toStringAsFixed(1)} MB', 
              _memoryUsage < 100 ? Colors.green : Colors.orange),
          _buildMetricRow('Frames', '$_frameCount', Colors.blue),
          
          const SizedBox(height: 8),
          
          // Audio metrics
          const Text(
            'Audio',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          _buildMetricRow('Level', '${(_audioLevel * 100).toStringAsFixed(0)}%', 
              _audioLevel > 0.5 ? Colors.green : Colors.orange),
          _buildMetricRow('Pitch Latency', '${_pitchLatency.toStringAsFixed(1)}ms', 
              _pitchLatency < 20 ? Colors.green : Colors.orange),
          
          const SizedBox(height: 8),
          
          // Network
          _buildMetricRow('Network', '$_networkRequests reqs', Colors.cyan),
          
          if (_deviceInfo.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Device',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              _deviceInfo,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildMetricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isVisible || !widget.enabled) {
      return widget.child;
    }
    
    return Stack(
      children: [
        widget.child,
        
        // Debug overlay
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onTap: _isExpanded ? null : _toggleExpanded,
            onPanStart: (details) {
              _isDragging = true;
            },
            onPanUpdate: (details) {
              if (_isDragging) {
                setState(() {
                  _position += details.delta;
                  
                  // Keep within screen bounds
                  final screenSize = MediaQuery.of(context).size;
                  _position = Offset(
                    _position.dx.clamp(0, screenSize.width - 100),
                    _position.dy.clamp(0, screenSize.height - 100),
                  );
                });
              }
            },
            onPanEnd: (details) {
              _isDragging = false;
            },
            child: AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                return _isExpanded
                    ? _buildExpandedView()
                    : _buildCompactView();
              },
            ),
          ),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _stopMonitoring();
    _expandController.dispose();
    super.dispose();
  }
}

// Extension to update network request count
extension DebugOverlayNetworkExtension on _DebugOverlayState {
  void updateNetworkRequests(int count) {
    if (mounted) {
      setState(() {
        _networkRequests = count;
      });
    }
  }
}

// ProcessInfo class for memory usage
class ProcessInfo {
  static Future<_MemoryUsage> get currentMemoryUsage async {
    // This is a simplified implementation
    // In a real app, you might use platform-specific methods
    return _MemoryUsage(
      rss: 50 * 1024 * 1024, // 50MB as placeholder
    );
  }
}

class _MemoryUsage {
  final int rss; // Resident Set Size
  
  const _MemoryUsage({required this.rss});
}