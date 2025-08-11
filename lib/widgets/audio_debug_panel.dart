import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/debug_logger.dart';

class AudioDebugPanel extends StatefulWidget {
  final bool enabled;
  final Stream<List<double>>? audioDataStream;
  
  const AudioDebugPanel({
    Key? key,
    this.enabled = false,
    this.audioDataStream,
  }) : super(key: key);

  @override
  State<AudioDebugPanel> createState() => _AudioDebugPanelState();
}

class _AudioDebugPanelState extends State<AudioDebugPanel>
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  StreamSubscription? _audioSubscription;
  
  // Audio data
  List<double> _currentWaveform = [];
  List<double> _frequencySpectrum = [];
  double _currentLevel = 0.0;
  double _maxLevel = 0.0;
  double _averageLevel = 0.0;
  
  // Audio configuration
  int _sampleRate = 44100;
  int _bufferSize = 4096;
  int _channelCount = 1;
  String _audioFormat = 'PCM 16-bit';
  
  // Permission status
  PermissionStatus _microphonePermission = PermissionStatus.denied;
  
  // Buffer monitoring
  int _bufferUnderruns = 0;
  int _bufferOverruns = 0;
  double _bufferHealthScore = 1.0;
  
  // Frequency analysis
  double _fundamentalFreq = 0.0;
  List<double> _harmonics = [];
  
  // Performance metrics
  double _processingLatency = 0.0;
  int _samplesProcessed = 0;
  DateTime _lastProcessTime = DateTime.now();
  
  // Animation controllers
  late AnimationController _waveformAnimationController;
  late AnimationController _spectrumAnimationController;
  
  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(length: 4, vsync: this);
    
    _waveformAnimationController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    );
    
    _spectrumAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    if (widget.enabled) {
      _initializeAudioDebug();
    }
  }
  
  @override
  void didUpdateWidget(AudioDebugPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _initializeAudioDebug();
      } else {
        _cleanup();
      }
    }
    
    if (widget.audioDataStream != oldWidget.audioDataStream) {
      _audioSubscription?.cancel();
      if (widget.audioDataStream != null) {
        _subscribeToAudioStream();
      }
    }
  }
  
  Future<void> _initializeAudioDebug() async {
    await _checkMicrophonePermission();
    if (widget.audioDataStream != null) {
      _subscribeToAudioStream();
    }
  }
  
  Future<void> _checkMicrophonePermission() async {
    try {
      _microphonePermission = await Permission.microphone.status;
      if (mounted) setState(() {});
    } catch (e) {
      logger.error('마이크 권한 확인 실패: $e');
    }
  }
  
  void _subscribeToAudioStream() {
    _audioSubscription = widget.audioDataStream?.listen(
      (audioData) => _processAudioData(audioData),
      onError: (error) => logger.error('오디오 스트림 오류: $error'),
    );
  }
  
  void _processAudioData(List<double> audioData) {
    if (!mounted || audioData.isEmpty) return;
    
    final startTime = DateTime.now();
    
    // Update waveform
    _currentWaveform = List.from(audioData.take(200)); // Show first 200 samples
    
    // Calculate audio level
    _currentLevel = _calculateRMSLevel(audioData);
    _maxLevel = max(_maxLevel, _currentLevel);
    
    // Update running average
    _averageLevel = (_averageLevel * 0.9) + (_currentLevel * 0.1);
    
    // Perform FFT analysis
    _performFrequencyAnalysis(audioData);
    
    // Update performance metrics
    _samplesProcessed += audioData.length;
    final processingTime = DateTime.now().difference(startTime);
    _processingLatency = processingTime.inMicroseconds / 1000.0; // Convert to ms
    
    // Simulate buffer health monitoring
    _updateBufferHealth();
    
    if (mounted) {
      setState(() {});
      _waveformAnimationController.forward().then((_) {
        _waveformAnimationController.reset();
      });
    }
  }
  
  double _calculateRMSLevel(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    
    return sqrt(sum / samples.length);
  }
  
  void _performFrequencyAnalysis(List<double> audioData) {
    if (audioData.length < 4096) return;
    
    try {
      // Simplified frequency analysis without FFT library
      _frequencySpectrum = _computeSimpleSpectrum(audioData.take(4096).toList());
      
      // Find fundamental frequency
      _findFundamentalFrequency();
      
      // Extract harmonics
      _extractHarmonics();
      
      _spectrumAnimationController.forward().then((_) {
        _spectrumAnimationController.reset();
      });
      
    } catch (e) {
      logger.error('주파수 분석 실패: $e');
    }
  }
  
  List<double> _computeSimpleSpectrum(List<double> samples) {
    // Simplified spectrum computation using autocorrelation
    final spectrum = <double>[];
    final sampleCount = samples.length;
    
    for (int freq = 0; freq < sampleCount ~/ 2; freq++) {
      double real = 0.0;
      double imag = 0.0;
      
      for (int i = 0; i < sampleCount; i++) {
        final angle = -2 * pi * freq * i / sampleCount;
        real += samples[i] * cos(angle);
        imag += samples[i] * sin(angle);
      }
      
      final magnitude = sqrt(real * real + imag * imag);
      spectrum.add(magnitude);
    }
    
    return spectrum;
  }
  
  void _findFundamentalFrequency() {
    if (_frequencySpectrum.isEmpty) return;
    
    // Find peak frequency (simplified approach)
    double maxMagnitude = 0.0;
    int maxIndex = 0;
    
    // Look in vocal range (80-1000 Hz)
    final startBin = (80.0 * 4096 / _sampleRate).round();
    final endBin = (1000.0 * 4096 / _sampleRate).round();
    
    for (int i = startBin; i < min(endBin, _frequencySpectrum.length); i++) {
      if (_frequencySpectrum[i] > maxMagnitude) {
        maxMagnitude = _frequencySpectrum[i];
        maxIndex = i;
      }
    }
    
    _fundamentalFreq = maxIndex * _sampleRate / 4096.0;
  }
  
  void _extractHarmonics() {
    if (_fundamentalFreq <= 0) return;
    
    _harmonics.clear();
    
    // Look for harmonics (multiples of fundamental frequency)
    for (int harmonic = 2; harmonic <= 6; harmonic++) {
      final targetFreq = _fundamentalFreq * harmonic;
      final binIndex = (targetFreq * 4096 / _sampleRate).round();
      
      if (binIndex < _frequencySpectrum.length) {
        _harmonics.add(_frequencySpectrum[binIndex]);
      }
    }
  }
  
  void _updateBufferHealth() {
    // Simulate buffer health monitoring
    if (_currentLevel > 0.9) {
      _bufferOverruns++;
    } else if (_currentLevel < 0.01) {
      _bufferUnderruns++;
    }
    
    // Calculate health score
    final totalIssues = _bufferUnderruns + _bufferOverruns;
    final totalSamples = _samplesProcessed / _bufferSize;
    
    if (totalSamples > 0) {
      _bufferHealthScore = 1.0 - (totalIssues / totalSamples).clamp(0.0, 1.0);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }
    
    return Container(
      height: 350,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildTabBar(),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWaveformTab(),
                _buildSpectrumTab(),
                _buildStatusTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.audiotrack,
          color: Colors.purple,
          size: 20,
        ),
        const SizedBox(width: 8),
        const Text(
          'Audio Debug Panel',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        _buildAudioLevelIndicator(),
        const SizedBox(width: 16),
        _buildPermissionStatus(),
      ],
    );
  }
  
  Widget _buildAudioLevelIndicator() {
    return Container(
      width: 100,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _currentLevel.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: _currentLevel > 0.8 ? Colors.red : _currentLevel > 0.5 ? Colors.orange : Colors.green,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPermissionStatus() {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (_microphonePermission) {
      case PermissionStatus.granted:
        statusColor = Colors.green;
        statusIcon = Icons.mic;
        statusText = 'MIC';
        break;
      case PermissionStatus.denied:
        statusColor = Colors.red;
        statusIcon = Icons.mic_off;
        statusText = 'DENIED';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.mic_none;
        statusText = 'UNKNOWN';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 10),
          const SizedBox(width: 2),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabs: const [
        Tab(text: 'Waveform'),
        Tab(text: 'Spectrum'),
        Tab(text: 'Status'),
        Tab(text: 'Config'),
      ],
      labelColor: Colors.purple,
      unselectedLabelColor: Colors.white54,
      indicatorColor: Colors.purple,
    );
  }
  
  Widget _buildWaveformTab() {
    return Column(
      children: [
        Text(
          'Real-time Waveform (${_currentWaveform.length} samples)',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: CustomPaint(
              painter: WaveformPainter(
                waveform: _currentWaveform,
                color: Colors.purple,
                animate: _waveformAnimationController.value,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMetricChip('Level', '${(_currentLevel * 100).toStringAsFixed(1)}%'),
            _buildMetricChip('Peak', '${(_maxLevel * 100).toStringAsFixed(1)}%'),
            _buildMetricChip('Avg', '${(_averageLevel * 100).toStringAsFixed(1)}%'),
          ],
        ),
      ],
    );
  }
  
  Widget _buildSpectrumTab() {
    return Column(
      children: [
        Text(
          'Frequency Spectrum (${_frequencySpectrum.length} bins)',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: CustomPaint(
              painter: SpectrumPainter(
                spectrum: _frequencySpectrum,
                sampleRate: _sampleRate,
                fundamentalFreq: _fundamentalFreq,
                color: Colors.purple,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMetricChip('Fundamental', '${_fundamentalFreq.toStringAsFixed(1)} Hz'),
            _buildMetricChip('Harmonics', '${_harmonics.length}'),
            _buildMetricChip('Resolution', '${(_sampleRate / 4096).toStringAsFixed(1)} Hz/bin'),
          ],
        ),
      ],
    );
  }
  
  Widget _buildStatusTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStatusCard('Buffer Health', '${(_bufferHealthScore * 100).toStringAsFixed(1)}%', 
              _bufferHealthScore > 0.8 ? Colors.green : Colors.orange, Icons.memory),
          _buildStatusCard('Processing Latency', '${_processingLatency.toStringAsFixed(2)} ms', 
              _processingLatency < 10 ? Colors.green : Colors.orange, Icons.timer),
          _buildStatusCard('Samples Processed', _samplesProcessed.toString(), 
              Colors.blue, Icons.analytics),
          _buildStatusCard('Buffer Underruns', _bufferUnderruns.toString(), 
              _bufferUnderruns > 0 ? Colors.red : Colors.green, Icons.warning),
          _buildStatusCard('Buffer Overruns', _bufferOverruns.toString(), 
              _bufferOverruns > 0 ? Colors.red : Colors.green, Icons.error),
        ],
      ),
    );
  }
  
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildConfigCard('Sample Rate', '$_sampleRate Hz', Icons.speed),
          _buildConfigCard('Buffer Size', '$_bufferSize samples', Icons.memory),
          _buildConfigCard('Channels', '$_channelCount', Icons.surround_sound),
          _buildConfigCard('Format', _audioFormat, Icons.settings_voice),
          _buildConfigCard('Bit Depth', '16-bit', Icons.high_quality),
          
          const SizedBox(height: 16),
          
          ElevatedButton(
            onPressed: _requestMicrophonePermission,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Request Mic Permission'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.purple.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 8,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusCard(String title, String value, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConfigCard(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.purple, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      setState(() {
        _microphonePermission = status;
      });
    } catch (e) {
      logger.error('마이크 권한 요청 실패: $e');
    }
  }
  
  void _cleanup() {
    _audioSubscription?.cancel();
  }
  
  @override
  void dispose() {
    _cleanup();
    _tabController.dispose();
    _waveformAnimationController.dispose();
    _spectrumAnimationController.dispose();
    super.dispose();
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final Color color;
  final double animate;
  
  WaveformPainter({
    required this.waveform,
    required this.color,
    this.animate = 1.0,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;
    
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    final centerY = size.height / 2;
    final stepX = size.width / waveform.length;
    
    for (int i = 0; i < waveform.length; i++) {
      final x = i * stepX;
      final y = centerY + (waveform[i] * centerY * 0.8 * animate);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // Draw center line
    final centerPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 0.5;
    
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      centerPaint,
    );
  }
  
  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.waveform != waveform || oldDelegate.animate != animate;
  }
}

class SpectrumPainter extends CustomPainter {
  final List<double> spectrum;
  final int sampleRate;
  final double fundamentalFreq;
  final Color color;
  
  SpectrumPainter({
    required this.spectrum,
    required this.sampleRate,
    required this.fundamentalFreq,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (spectrum.isEmpty) return;
    
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    final stepX = size.width / spectrum.length;
    final maxMagnitude = spectrum.isNotEmpty ? spectrum.reduce(max) : 1.0;
    
    for (int i = 0; i < spectrum.length; i++) {
      final x = i * stepX;
      final normalizedMagnitude = spectrum[i] / maxMagnitude;
      final height = normalizedMagnitude * size.height;
      
      final rect = Rect.fromLTWH(x, size.height - height, stepX - 1, height);
      canvas.drawRect(rect, paint);
    }
    
    // Mark fundamental frequency
    if (fundamentalFreq > 0) {
      final fundamentalBin = (fundamentalFreq * spectrum.length * 2 / sampleRate).round();
      if (fundamentalBin < spectrum.length) {
        final x = fundamentalBin * stepX;
        final linePaint = Paint()
          ..color = Colors.red
          ..strokeWidth = 2.0;
        
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          linePaint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(SpectrumPainter oldDelegate) {
    return oldDelegate.spectrum != spectrum || oldDelegate.fundamentalFreq != fundamentalFreq;
  }
}

