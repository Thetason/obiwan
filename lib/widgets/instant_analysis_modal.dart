import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import '../services/native_audio_service.dart';

enum AnalysisPhase { ready, listening, analyzing, results }

class InstantAnalysisModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;

  const InstantAnalysisModal({
    Key? key,
    required this.isOpen,
    required this.onClose,
  }) : super(key: key);

  @override
  State<InstantAnalysisModal> createState() => _InstantAnalysisModalState();
}

class _InstantAnalysisModalState extends State<InstantAnalysisModal>
    with TickerProviderStateMixin {
  
  AnalysisPhase _currentPhase = AnalysisPhase.ready;
  bool _isRecording = false;
  
  // Analysis data
  double _accuracy = 0.0;
  double _pitch = 0.0;
  double _volume = 0.0;
  double _sessionTime = 0.0;
  List<double> _analysisData = [];
  
  // Animation controllers
  late AnimationController _rippleController;
  late AnimationController _rotationController;
  late AnimationController _waveController;
  
  // Animations
  late Animation<double> _rippleAnimation;
  late Animation<double> _rotationAnimation;
  
  // Timers
  Timer? _analysisTimer;
  Timer? _sessionTimer;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _rippleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _rotationController.dispose();
    _waveController.dispose();
    _analysisTimer?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    try {
      HapticFeedback.mediumImpact();
      
      setState(() {
        _currentPhase = AnalysisPhase.listening;
        _isRecording = true;
        _sessionTime = 0.0;
        _analysisData.clear();
      });
      
      // Start recording with native audio service
      await NativeAudioService.instance.startRecording();
      
      // Start ripple animation
      _rippleController.repeat();
      
      // Start mock analysis simulation
      _startAnalysisSimulation();
      
      // Start session timer
      _sessionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        setState(() {
          _sessionTime += 0.1;
        });
      });
      
    } catch (e) {
      print('Error starting analysis: $e');
      _resetAnalysis();
    }
  }

  void _startAnalysisSimulation() {
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_isRecording) return;
      
      setState(() {
        // Mock real-time analysis data
        _pitch = 440 + (math.Random().nextDouble() - 0.5) * 200;
        _volume = math.Random().nextDouble() * 100;
        _accuracy = 60 + math.Random().nextDouble() * 35;
        
        // Add to analysis history
        _analysisData.add(_accuracy);
        if (_analysisData.length > 20) {
          _analysisData = _analysisData.sublist(_analysisData.length - 20);
        }
      });
    });
  }

  Future<void> _stopAnalysis() async {
    try {
      HapticFeedback.lightImpact();
      
      setState(() {
        _isRecording = false;
        _currentPhase = AnalysisPhase.analyzing;
      });
      
      // Stop recording
      await NativeAudioService.instance.stopRecording();
      
      // Stop timers
      _analysisTimer?.cancel();
      _sessionTimer?.cancel();
      
      // Stop ripple and start rotation
      _rippleController.stop();
      _rotationController.repeat();
      
      // Simulate analysis processing
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        setState(() {
          _currentPhase = AnalysisPhase.results;
        });
        _rotationController.stop();
      }
      
    } catch (e) {
      print('Error stopping analysis: $e');
      _resetAnalysis();
    }
  }

  void _resetAnalysis() {
    setState(() {
      _currentPhase = AnalysisPhase.ready;
      _isRecording = false;
      _sessionTime = 0.0;
      _analysisData.clear();
    });
    
    _analysisTimer?.cancel();
    _sessionTimer?.cancel();
    _rippleController.stop();
    _rotationController.stop();
  }

  String _getScoreGrade(double score) {
    if (score >= 90) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    return 'C';
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return const Color(0xFF10B981);
    if (score >= 80) return const Color(0xFF3B82F6);
    if (score >= 70) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();
    
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Icon(
                  Icons.bolt,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  '즉시 보컬 분석',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'AI가 실시간으로 분석합니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(
              Icons.close,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildPhaseContent(),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_currentPhase) {
      case AnalysisPhase.ready:
        return _buildReadyPhase();
      case AnalysisPhase.listening:
        return _buildListeningPhase();
      case AnalysisPhase.analyzing:
        return _buildAnalyzingPhase();
      case AnalysisPhase.results:
        return _buildResultsPhase();
    }
  }

  Widget _buildReadyPhase() {
    return Column(
      key: const ValueKey('ready'),
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF3B82F6).withOpacity(0.1),
                const Color(0xFF8B5CF6).withOpacity(0.1),
              ],
            ),
          ),
          child: const Icon(
            Icons.mic,
            size: 48,
            color: Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '준비됐어요!',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '아래 버튼을 눌러서 보컬 분석을 시작하세요',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _startAnalysis,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ).copyWith(
              backgroundColor: MaterialStateProperty.all(Colors.transparent),
            ),
            child: Ink(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: Container(
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '분석 시작',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListeningPhase() {
    return Column(
      key: const ValueKey('listening'),
      children: [
        // Live visualizer
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple effect
              AnimatedBuilder(
                animation: _rippleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _rippleAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFEF4444).withOpacity(
                            1.0 - (_rippleAnimation.value - 1.0) / 0.3
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              // Center recording indicator
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                ),
                child: const Icon(
                  Icons.mic,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Live stats
        Text(
          '${_accuracy.round()}%',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFFEF4444),
          ),
        ),
        Text(
          '${_sessionTime.toStringAsFixed(1)}초 • ${_pitch.round()}Hz',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Real-time wave visualization
        _buildWaveVisualization(),
        
        const SizedBox(height: 24),
        
        // Live feedback
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '실시간 정확도',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    '${_accuracy.round()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _accuracy / 100,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Stop button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _stopAnalysis,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic_off, size: 20),
                SizedBox(width: 8),
                Text(
                  '분석 완료',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaveVisualization() {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(12, (index) {
          return AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return Container(
                width: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 8 + (math.Random().nextDouble() * 20) * (_volume / 100),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildAnalyzingPhase() {
    return Column(
      key: const ValueKey('analyzing'),
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 4,
                    ),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.transparent,
                          Color(0xFF3B82F6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'AI 분석 중...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '잠시만 기다려주세요. 정확한 분석을 위해\n데이터를 처리하고 있어요.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildResultsPhase() {
    final grade = _getScoreGrade(_accuracy);
    final scoreColor = _getScoreColor(_accuracy);
    
    return Column(
      key: const ValueKey('results'),
      children: [
        // Score display
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scoreColor.withOpacity(0.1),
          ),
          child: Center(
            child: Text(
              grade,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: scoreColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '분석 완료!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_sessionTime.toStringAsFixed(1)}초간 분석했어요',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Detailed results
        Column(
          children: [
            _buildResultItem(
              Icons.track_changes,
              '평균 정확도',
              '${_accuracy.round()}%',
              const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 12),
            _buildResultItem(
              Icons.trending_up,
              '안정성',
              '${(70 + math.Random().nextDouble() * 20).round()}%',
              const Color(0xFF10B981),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _resetAnalysis,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, size: 16),
                    SizedBox(width: 6),
                    Text('다시 분석'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: widget.onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ).copyWith(
                  backgroundColor: MaterialStateProperty.all(Colors.transparent),
                ),
                child: Ink(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: const Text(
                      '완료',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultItem(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}