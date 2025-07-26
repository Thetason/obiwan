import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'spectrogram_visualizer.dart';
import 'advanced_waveform_painter.dart';
import 'frequency_analyzer_3d.dart';

/// Comprehensive audio visualizer combining multiple visualization modes
class ComprehensiveAudioVisualizer extends StatefulWidget {
  final Stream<List<double>>? audioStream;
  final int sampleRate;
  final VisualizationConfig config;
  final bool showControls;
  final Function(VisualizationMode)? onModeChanged;
  
  const ComprehensiveAudioVisualizer({
    Key? key,
    this.audioStream,
    this.sampleRate = 44100,
    this.config = const VisualizationConfig(),
    this.showControls = true,
    this.onModeChanged,
  }) : super(key: key);
  
  @override
  State<ComprehensiveAudioVisualizer> createState() => _ComprehensiveAudioVisualizerState();
}

class _ComprehensiveAudioVisualizerState extends State<ComprehensiveAudioVisualizer>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late StreamController<List<double>> _waveformController;
  late StreamController<List<double>> _spectrogramController;
  late StreamController<List<double>> _frequencyController;
  
  VisualizationMode _currentMode = VisualizationMode.waveform;
  WaveformDisplayMode _waveformMode = WaveformDisplayMode.oscilloscope;
  WaveformColorScheme _waveformColorScheme = WaveformColorScheme.classic;
  SpectrogramColorScheme _spectrogramColorScheme = SpectrogramColorScheme.jet;
  FrequencyVisualizationMode _frequencyMode = FrequencyVisualizationMode.bars3D;
  
  bool _isPaused = false;
  bool _showGrid = true;
  bool _showPeaks = true;
  bool _showRMS = false;
  double _amplitudeScale = 1.0;
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _subscribeToAudio();
  }
  
  void _initializeControllers() {
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    _waveformController = StreamController<List<double>>.broadcast();
    _spectrogramController = StreamController<List<double>>.broadcast();
    _frequencyController = StreamController<List<double>>.broadcast();
  }
  
  void _subscribeToAudio() {
    widget.audioStream?.listen((audioData) {
      if (!_isPaused) {
        _waveformController.add(audioData);
        _spectrogramController.add(audioData);
        _frequencyController.add(audioData);
      }
    });
  }
  
  void _onTabChanged() {
    final newMode = VisualizationMode.values[_tabController.index];
    setState(() {
      _currentMode = newMode;
    });
    widget.onModeChanged?.call(newMode);
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black87,
            Colors.indigo[900]!.withOpacity(0.8),
          ],
        ),
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
          if (widget.showControls) _buildHeader(),
          Expanded(child: _buildVisualizationContent()),
          if (widget.showControls) _buildControlPanel(),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getVisualizationIcon(_currentMode),
            color: Colors.white70,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            _getVisualizationTitle(_currentMode),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _isPaused ? Icons.play_arrow : Icons.pause,
              color: Colors.white70,
            ),
            onPressed: () {
              setState(() {
                _isPaused = !_isPaused;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
    );
  }
  
  Widget _buildVisualizationContent() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (widget.showControls) _buildTabBar(),
          Expanded(child: _buildCurrentVisualization()),
        ],
      ),
    );
  }
  
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            colors: [Colors.cyan.withOpacity(0.6), Colors.blue.withOpacity(0.6)],
          ),
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.show_chart),
            text: 'Waveform',
          ),
          Tab(
            icon: Icon(Icons.gradient),
            text: 'Spectrogram',
          ),
          Tab(
            icon: Icon(Icons.equalizer),
            text: 'Frequency',
          ),
          Tab(
            icon: Icon(Icons.view_in_ar),
            text: 'Combined',
          ),
        ],
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
    );
  }
  
  Widget _buildCurrentVisualization() {
    switch (_currentMode) {
      case VisualizationMode.waveform:
        return _buildWaveformVisualization();
      case VisualizationMode.spectrogram:
        return _buildSpectrogramVisualization();
      case VisualizationMode.frequency:
        return _buildFrequencyVisualization();
      case VisualizationMode.combined:
        return _buildCombinedVisualization();
    }
  }
  
  Widget _buildWaveformVisualization() {
    return StreamBuilder<List<double>>(
      stream: _waveformController.stream,
      builder: (context, snapshot) {
        final data = snapshot.data ?? List.filled(1024, 0.0);
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyan.withOpacity(0.3)),
          ),
          child: CustomPaint(
            size: Size.infinite,
            painter: AdvancedWaveformPainter(
              waveformData: data,
              displayMode: _waveformMode,
              colorScheme: _waveformColorScheme,
              showGrid: _showGrid,
              showRMS: _showRMS,
              showPeaks: _showPeaks,
              amplitudeScale: _amplitudeScale,
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildSpectrogramVisualization() {
    return SpectrogramVisualizer(
      audioStream: _spectrogramController.stream,
      sampleRate: widget.sampleRate,
      colorScheme: _spectrogramColorScheme,
      showFrequencyLabels: true,
      showTimeLabels: true,
    );
  }
  
  Widget _buildFrequencyVisualization() {
    return FrequencyAnalyzer3D(
      audioStream: _frequencyController.stream,
      sampleRate: widget.sampleRate,
      mode: _frequencyMode,
      showPeaks: _showPeaks,
      rotationEnabled: true,
    );
  }
  
  Widget _buildCombinedVisualization() {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Expanded(child: _buildWaveformVisualization()),
              const SizedBox(width: 8),
              Expanded(child: _buildSpectrogramVisualization()),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 3,
          child: _buildFrequencyVisualization(),
        ),
      ],
    );
  }
  
  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Amplitude:', style: TextStyle(color: Colors.white70)),
              Expanded(
                child: Slider(
                  value: _amplitudeScale,
                  min: 0.1,
                  max: 3.0,
                  divisions: 29,
                  activeColor: Colors.cyan,
                  onChanged: (value) {
                    setState(() {
                      _amplitudeScale = value;
                    });
                  },
                ),
              ),
              Text(
                '${_amplitudeScale.toStringAsFixed(1)}x',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildToggleButton('Grid', _showGrid, (value) {
                setState(() {
                  _showGrid = value;
                });
              }),
              _buildToggleButton('Peaks', _showPeaks, (value) {
                setState(() {
                  _showPeaks = value;
                });
              }),
              _buildToggleButton('RMS', _showRMS, (value) {
                setState(() {
                  _showRMS = value;
                });
              }),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildToggleButton(String label, bool value, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: value ? Colors.cyan.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value ? Colors.cyan : Colors.white30,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: value ? Colors.cyan : Colors.white70,
            fontWeight: value ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Visualization Settings', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSettingsDropdown<WaveformDisplayMode>(
                'Waveform Mode',
                _waveformMode,
                WaveformDisplayMode.values,
                (value) => setState(() => _waveformMode = value),
              ),
              const SizedBox(height: 16),
              _buildSettingsDropdown<WaveformColorScheme>(
                'Waveform Colors',
                _waveformColorScheme,
                WaveformColorScheme.values,
                (value) => setState(() => _waveformColorScheme = value),
              ),
              const SizedBox(height: 16),
              _buildSettingsDropdown<SpectrogramColorScheme>(
                'Spectrogram Colors',
                _spectrogramColorScheme,
                SpectrogramColorScheme.values,
                (value) => setState(() => _spectrogramColorScheme = value),
              ),
              const SizedBox(height: 16),
              _buildSettingsDropdown<FrequencyVisualizationMode>(
                'Frequency Mode',
                _frequencyMode,
                FrequencyVisualizationMode.values,
                (value) => setState(() => _frequencyMode = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSettingsDropdown<T>(
    String label,
    T currentValue,
    List<T> values,
    Function(T) onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        DropdownButton<T>(
          value: currentValue,
          dropdownColor: Colors.grey[800],
          style: const TextStyle(color: Colors.white),
          items: values.map((value) {
            return DropdownMenuItem<T>(
              value: value,
              child: Text(
                value.toString().split('.').last,
                style: const TextStyle(color: Colors.white),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
              Navigator.of(context).pop();
              _showSettingsDialog();
            }
          },
        ),
      ],
    );
  }
  
  IconData _getVisualizationIcon(VisualizationMode mode) {
    switch (mode) {
      case VisualizationMode.waveform:
        return Icons.show_chart;
      case VisualizationMode.spectrogram:
        return Icons.gradient;
      case VisualizationMode.frequency:
        return Icons.equalizer;
      case VisualizationMode.combined:
        return Icons.view_in_ar;
    }
  }
  
  String _getVisualizationTitle(VisualizationMode mode) {
    switch (mode) {
      case VisualizationMode.waveform:
        return 'Waveform Analysis';
      case VisualizationMode.spectrogram:
        return 'Spectrogram Analysis';
      case VisualizationMode.frequency:
        return '3D Frequency Analysis';
      case VisualizationMode.combined:
        return 'Combined View';
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _waveformController.close();
    _spectrogramController.close();
    _frequencyController.close();
    super.dispose();
  }
}

/// Visualization configuration
class VisualizationConfig {
  final int fftSize;
  final int hopSize;
  final double minFrequency;
  final double maxFrequency;
  final bool adaptiveColors;
  final bool smoothing;
  
  const VisualizationConfig({
    this.fftSize = 2048,
    this.hopSize = 512,
    this.minFrequency = 80.0,
    this.maxFrequency = 8000.0,
    this.adaptiveColors = true,
    this.smoothing = true,
  });
}

/// Visualization modes
enum VisualizationMode {
  waveform,
  spectrogram,
  frequency,
  combined,
}

/// Professional audio visualization widget with preset configurations
class AudioVisualizationSuite extends StatelessWidget {
  final Stream<List<double>>? audioStream;
  final int sampleRate;
  final AudioVisualizationPreset preset;
  
  const AudioVisualizationSuite({
    Key? key,
    this.audioStream,
    this.sampleRate = 44100,
    this.preset = AudioVisualizationPreset.professional,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final config = _getConfigForPreset(preset);
    
    return ComprehensiveAudioVisualizer(
      audioStream: audioStream,
      sampleRate: sampleRate,
      config: config,
      showControls: preset != AudioVisualizationPreset.minimal,
    );
  }
  
  VisualizationConfig _getConfigForPreset(AudioVisualizationPreset preset) {
    switch (preset) {
      case AudioVisualizationPreset.minimal:
        return const VisualizationConfig(
          fftSize: 1024,
          hopSize: 256,
          adaptiveColors: false,
          smoothing: false,
        );
      case AudioVisualizationPreset.standard:
        return const VisualizationConfig(
          fftSize: 2048,
          hopSize: 512,
        );
      case AudioVisualizationPreset.professional:
        return const VisualizationConfig(
          fftSize: 4096,
          hopSize: 1024,
          minFrequency: 20.0,
          maxFrequency: 20000.0,
          adaptiveColors: true,
          smoothing: true,
        );
      case AudioVisualizationPreset.highResolution:
        return const VisualizationConfig(
          fftSize: 8192,
          hopSize: 2048,
          minFrequency: 10.0,
          maxFrequency: 22050.0,
          adaptiveColors: true,
          smoothing: true,
        );
    }
  }
}

enum AudioVisualizationPreset {
  minimal,
  standard,
  professional,
  highResolution,
}