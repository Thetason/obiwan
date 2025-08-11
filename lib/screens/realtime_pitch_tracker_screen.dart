import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import '../services/native_audio_service.dart';
import '../services/dual_engine_service.dart';
import '../widgets/professional_piano_keyboard.dart';
import '../widgets/realtime_pitch_visualizer.dart';
import '../widgets/spectrum_analyzer.dart';

class RealtimePitchTrackerScreen extends StatefulWidget {
  const RealtimePitchTrackerScreen({super.key});

  @override
  State<RealtimePitchTrackerScreen> createState() => _RealtimePitchTrackerScreenState();
}

class _RealtimePitchTrackerScreenState extends State<RealtimePitchTrackerScreen>
    with TickerProviderStateMixin {
  
  // Services
  final NativeAudioService _audioService = NativeAudioService.instance;
  final DualEngineService _dualEngine = DualEngineService();
  
  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _glowController;
  
  // Audio State
  bool _isListening = false;
  StreamSubscription? _audioSubscription;
  Timer? _analysisTimer;
  
  // Pitch Data
  double _currentFrequency = 0.0;
  double _targetFrequency = 440.0; // A4
  String _currentNote = "—";
  int _cents = 0;
  double _confidence = 0.0;
  List<double> _pitchHistory = [];
  List<double> _audioLevels = [];
  
  // UI State
  String _activeKey = "";
  double _smoothedFrequency = 0.0;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupAudioProcessing();
    HapticFeedback.mediumImpact();
  }
  
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }
  
  void _setupAudioProcessing() async {
    await _audioService.initialize();
    
    // 성능 개선: 300ms마다 CREPE 분석 (3배 적은 호출)
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (_isListening) {
        _analyzeCurrentAudio();
      }
    });
  }
  
  void _analyzeCurrentAudio() async {
    // 실시간 오디오 청크 가져오기 (최근 0.3초 데이터 - 더 안정적인 분석)
    final audioData = await _audioService.getRecordedAudio();
    if (audioData == null || audioData.isEmpty) return;
    
    // 최근 14400 샘플 (0.3초) 추출 - 더 큰 윈도우로 정확도 향상
    final chunkSize = 14400;
    final startIdx = audioData.length > chunkSize ? audioData.length - chunkSize : 0;
    final audioChunk = audioData.sublist(startIdx);
    
    // 너무 작은 청크는 건너뛰기
    if (audioChunk.length < 4800) return;
    
    try {
      // CREPE로 실시간 분석 (timeout 설정)
      final frequency = await _dualEngine.analyzeSingleWithCREPE(
        Float32List.fromList(audioChunk),
        sampleRate: 48000.0,
      ).timeout(
        const Duration(milliseconds: 500), // 500ms 타임아웃
        onTimeout: () {
          print('CREPE 분석 타임아웃');
          return 0.0;
        },
      );
      
      if (frequency > 0 && mounted) {
        setState(() {
          _currentFrequency = frequency;
          _smoothedFrequency = _smoothFrequency(frequency);
          _currentNote = _frequencyToNote(frequency);
          _cents = _calculateCents(frequency);
          _confidence = 0.95; // CREPE는 높은 신뢰도
          
          // 피치 히스토리 업데이트
          _pitchHistory.add(frequency);
          if (_pitchHistory.length > 50) {
            _pitchHistory.removeAt(0);
          }
          
          // 피아노 건반 활성화
          _activeKey = _currentNote;
          
          // 정확도에 따른 햅틱 피드백
          if (_cents.abs() < 5) {
            HapticFeedback.lightImpact();
            _glowController.forward();
          }
        });
      }
    } catch (e) {
      print('분석 오류: $e');
      // 에러 발생시 로컬 피치 추정으로 폴백
      _performLocalPitchEstimation(audioChunk);
    }
  }
  
  void _performLocalPitchEstimation(List<double> audioChunk) {
    // 간단한 로컬 피치 추정 (CREPE 실패시 폴백)
    try {
      final sampleRate = 48000.0;
      double maxCorr = 0.0;
      int bestLag = 0;
      
      // Autocorrelation 기반 피치 추정
      for (int lag = 50; lag < audioChunk.length ~/ 3; lag++) {
        double corr = 0.0;
        for (int i = 0; i < audioChunk.length - lag; i++) {
          corr += audioChunk[i] * audioChunk[i + lag];
        }
        if (corr > maxCorr) {
          maxCorr = corr;
          bestLag = lag;
        }
      }
      
      if (bestLag > 0 && mounted) {
        final frequency = sampleRate / bestLag;
        if (frequency > 80 && frequency < 2000) { // 보컬 범위
          setState(() {
            _currentFrequency = frequency;
            _smoothedFrequency = _smoothFrequency(frequency);
            _currentNote = _frequencyToNote(frequency);
            _cents = _calculateCents(frequency);
            _confidence = 0.7; // 로컬 분석은 낮은 신뢰도
            
            _pitchHistory.add(frequency);
            if (_pitchHistory.length > 50) {
              _pitchHistory.removeAt(0);
            }
            
            _activeKey = _currentNote;
          });
        }
      }
    } catch (e) {
      print('로컬 피치 추정 실패: $e');
    }
  }

  double _smoothFrequency(double freq) {
    // 이동평균으로 부드럽게
    if (_pitchHistory.isEmpty) return freq;
    final recent = _pitchHistory.take(5).toList()..add(freq);
    return recent.reduce((a, b) => a + b) / recent.length;
  }
  
  String _frequencyToNote(double frequency) {
    if (frequency <= 0) return "—";
    
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const a4 = 440.0;
    
    final halfSteps = 12 * (math.log(frequency / a4) / math.log(2));
    final noteIndex = (halfSteps.round() + 9) % 12;
    final octave = ((halfSteps.round() + 9) ~/ 12) + 4;
    
    return '${notes[noteIndex]}$octave';
  }
  
  int _calculateCents(double frequency) {
    if (frequency <= 0) return 0;
    
    // 가장 가까운 노트 찾기
    const a4 = 440.0;
    final halfSteps = 12 * (math.log(frequency / a4) / math.log(2));
    final nearestHalfStep = halfSteps.round();
    final nearestFreq = a4 * math.pow(2, nearestHalfStep / 12);
    
    // 센트 계산
    return (1200 * math.log(frequency / nearestFreq) / math.log(2)).round();
  }
  
  void _toggleListening() async {
    setState(() {
      _isListening = !_isListening;
    });
    
    if (_isListening) {
      HapticFeedback.heavyImpact();
      await _audioService.startRecording();
      _pulseController.repeat(reverse: true);
    } else {
      HapticFeedback.mediumImpact();
      await _audioService.stopRecording();
      _pulseController.stop();
      setState(() {
        _currentFrequency = 0;
        _currentNote = "—";
        _cents = 0;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0A0E27),
              const Color(0xFF151935),
              const Color(0xFF1E2341).withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Main Pitch Display
              Expanded(
                child: Stack(
                  children: [
                    // Background Wave Animation
                    _buildBackgroundWaves(),
                    
                    // Center: Pitch Visualizer
                    Center(
                      child: RealtimePitchVisualizer(
                        frequency: _smoothedFrequency,
                        targetFrequency: _targetFrequency,
                        confidence: _confidence,
                        cents: _cents,
                        note: _currentNote,
                        isActive: _isListening,
                        pulseAnimation: _pulseController,
                        glowAnimation: _glowController,
                      ),
                    ),
                    
                    // Spectrum Analyzer Overlay
                    if (_isListening)
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 280,
                        height: 80,
                        child: SpectrumAnalyzer(
                          audioLevels: _audioLevels,
                          frequency: _currentFrequency,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Piano Keyboard
              Container(
                height: 120,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: ProfessionalPianoKeyboard(
                  activeNote: _activeKey,
                  onKeyPressed: (note) {
                    setState(() {
                      _targetFrequency = _noteToFrequency(note);
                    });
                  },
                ),
              ),
              
              // Control Button
              _buildControlButton(),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Back button
              IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OBIWAN',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pitch Tracker',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _confidence > 0.8 
                ? Colors.greenAccent.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _confidence > 0.8 
                  ? Colors.greenAccent.withOpacity(0.5)
                  : Colors.white.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.greenAccent : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isListening ? 'LIVE' : 'READY',
                  style: TextStyle(
                    color: _isListening ? Colors.greenAccent : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBackgroundWaves() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: WaveBackgroundPainter(
            progress: _waveController.value,
            frequency: _smoothedFrequency,
            isActive: _isListening,
          ),
        );
      },
    );
  }
  
  Widget _buildControlButton() {
    return GestureDetector(
      onTap: _toggleListening,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = _isListening 
            ? 1.0 + (_pulseController.value * 0.1)
            : 1.0;
          
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isListening
                    ? [
                        Colors.redAccent,
                        Colors.red.shade700,
                      ]
                    : [
                        Colors.blueAccent,
                        Colors.blue.shade700,
                      ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? Colors.red : Colors.blue)
                        .withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }
  
  double _noteToFrequency(String note) {
    final frequencies = {
      'C4': 261.63, 'C#4': 277.18, 'D4': 293.66, 'D#4': 311.13,
      'E4': 329.63, 'F4': 349.23, 'F#4': 369.99, 'G4': 392.00,
      'G#4': 415.30, 'A4': 440.00, 'A#4': 466.16, 'B4': 493.88,
      'C5': 523.25,
    };
    return frequencies[note] ?? 440.0;
  }
  
  @override
  void dispose() {
    _analysisTimer?.cancel();
    _audioSubscription?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _glowController.dispose();
    _audioService.dispose();
    super.dispose();
  }
}

// Wave Background Painter
class WaveBackgroundPainter extends CustomPainter {
  final double progress;
  final double frequency;
  final bool isActive;
  
  WaveBackgroundPainter({
    required this.progress,
    required this.frequency,
    required this.isActive,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    // 주파수에 따른 파형 그리기
    for (int i = 0; i < 3; i++) {
      final opacity = (1.0 - (i * 0.3));
      paint.color = Colors.blueAccent.withOpacity(opacity * 0.2);
      
      final path = Path();
      for (double x = 0; x <= size.width; x += 5) {
        final normalizedX = x / size.width;
        final phase = normalizedX * math.pi * 4 + (progress * math.pi * 2);
        final amplitude = math.sin(phase) * (frequency / 20) * (i + 1);
        final y = size.height / 2 + amplitude;
        
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      
      canvas.drawPath(path, paint);
    }
  }
  
  @override
  bool shouldRepaint(WaveBackgroundPainter oldDelegate) =>
      progress != oldDelegate.progress || 
      frequency != oldDelegate.frequency ||
      isActive != oldDelegate.isActive;
}