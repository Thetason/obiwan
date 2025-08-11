import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'debug_overlay.dart';
import 'performance_monitor.dart';
import 'network_debug_panel.dart';
import 'audio_debug_panel.dart';

class DebugDashboard extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final Stream<List<double>>? audioDataStream;
  
  const DebugDashboard({
    Key? key,
    required this.child,
    this.enabled = false,
    this.audioDataStream,
  }) : super(key: key);

  @override
  State<DebugDashboard> createState() => _DebugDashboardState();
  
  static _DebugDashboardState? of(BuildContext context) {
    return context.findAncestorStateOfType<_DebugDashboardState>();
  }
}

class _DebugDashboardState extends State<DebugDashboard>
    with TickerProviderStateMixin {
  
  bool _isDebugEnabled = false;
  bool _showFullDashboard = false;
  int _tapCount = 0;
  DateTime _lastTapTime = DateTime.now();
  
  // Panel visibility
  bool _showPerformanceMonitor = false;
  bool _showNetworkPanel = false;
  bool _showAudioPanel = false;
  
  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _isDebugEnabled = widget.enabled;
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
  }
  
  void toggleDebugMode() {
    setState(() {
      _isDebugEnabled = !_isDebugEnabled;
    });
    
    if (_isDebugEnabled) {
      _fadeController.forward();
      HapticFeedback.lightImpact();
    } else {
      _fadeController.reverse();
      _showFullDashboard = false;
      _slideController.reverse();
    }
  }
  
  void _handleGesture() {
    final now = DateTime.now();
    
    // Reset tap count if too much time has passed
    if (now.difference(_lastTapTime).inSeconds > 2) {
      _tapCount = 0;
    }
    
    _tapCount++;
    _lastTapTime = now;
    
    // Enable debug mode with 3 finger tap (simulated with rapid taps)
    if (_tapCount >= 3) {
      toggleDebugMode();
      _tapCount = 0;
      
      // Show confirmation
      if (_isDebugEnabled) {
        _showDebugEnabledSnackbar();
      }
    }
  }
  
  void _showDebugEnabledSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('🐛 Debug Mode Enabled'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  void _toggleFullDashboard() {
    setState(() {
      _showFullDashboard = !_showFullDashboard;
    });
    
    if (_showFullDashboard) {
      _slideController.forward();
    } else {
      _slideController.reverse();
    }
    
    HapticFeedback.selectionClick();
  }
  
  @override
  Widget build(BuildContext context) {
    // In production builds, completely exclude debug functionality
    if (kReleaseMode && !_isDebugEnabled) {
      return widget.child;
    }
    
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // Main app content with gesture detector
          GestureDetector(
            onTap: _handleGesture,
            child: DebugOverlay(
              enabled: _isDebugEnabled,
              child: widget.child,
            ),
          ),
        
        // Debug panels
        if (_isDebugEnabled) ...[
          // Full debug dashboard
          if (_showFullDashboard)
            _buildFullDashboard(),
          
          // Quick access floating button
          _buildFloatingDebugButton(),
        ],
      ],
    ),
    );
  }
  
  Widget _buildFullDashboard() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.4,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.95),
          border: Border(
            left: BorderSide(color: Colors.grey[700]!, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildDashboardHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    // Performance monitor toggle
                    _buildPanelToggle(
                      'Performance Monitor',
                      Icons.analytics,
                      _showPerformanceMonitor,
                      (value) => setState(() => _showPerformanceMonitor = value),
                    ),
                    
                    if (_showPerformanceMonitor)
                      PerformanceMonitor(enabled: true),
                    
                    const SizedBox(height: 16),
                    
                    // Network panel toggle
                    _buildPanelToggle(
                      'Network Debug',
                      Icons.network_check,
                      _showNetworkPanel,
                      (value) => setState(() => _showNetworkPanel = value),
                    ),
                    
                    if (_showNetworkPanel)
                      NetworkDebugPanel(enabled: true),
                    
                    const SizedBox(height: 16),
                    
                    // Audio panel toggle
                    _buildPanelToggle(
                      'Audio Debug',
                      Icons.audiotrack,
                      _showAudioPanel,
                      (value) => setState(() => _showAudioPanel = value),
                    ),
                    
                    if (_showAudioPanel)
                      AudioDebugPanel(
                        enabled: true,
                        audioDataStream: widget.audioDataStream,
                      ),
                    
                    const SizedBox(height: 20),
                    
                    // Quick actions
                    _buildQuickActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDashboardHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          bottom: BorderSide(color: Colors.grey[700]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bug_report,
            color: Colors.green,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'Debug Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _toggleFullDashboard,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red, width: 1),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.red,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPanelToggle(
    String title,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: value ? Colors.blue.withOpacity(0.2) : Colors.grey[800]?.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? Colors.blue : Colors.grey[600]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: value ? Colors.blue : Colors.grey[400],
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: value ? Colors.white : Colors.grey[400],
                  fontSize: 14,
                  fontWeight: value ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.blue,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Clear Logs',
                Icons.clear_all,
                Colors.orange,
                () {
                  // Clear debug logs
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debug logs cleared')),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                'Export Data',
                Icons.download,
                Colors.green,
                _exportDebugData,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        SizedBox(
          width: double.infinity,
          child: _buildActionButton(
            'Trigger Test Error',
            Icons.error,
            Colors.red,
            _triggerTestError,
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: color, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
  
  Widget _buildFloatingDebugButton() {
    return Positioned(
      right: 20,
      top: MediaQuery.of(context).padding.top + 60,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: _toggleFullDashboard,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.9),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.green, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.bug_report,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
  
  void _exportDebugData() {
    // Implementation for exporting debug data
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Debug data export functionality would be implemented here'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _triggerTestError() {
    try {
      throw Exception('Test error for debugging purposes');
    } catch (e, stackTrace) {
      // This would be caught by the error handler
      debugPrint('Test error triggered: $e');
      debugPrint('Stack trace: $stackTrace');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test error triggered - check console/logs'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}