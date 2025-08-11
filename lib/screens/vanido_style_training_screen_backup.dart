import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import '../models/analysis_result.dart';
import '../models/pitch_point.dart';
import '../widgets/pitch_graph_widget.dart';
import '../widgets/professional_harmonics_analyzer.dart';
import '../widgets/professional_spectrogram_overlay.dart';
import '../widgets/holographic_3d_pitch_visualizer.dart';
// import '../widgets/logic_pro_waveform_widget.dart'; // 임시 비활성화
// import '../widgets/realtime_data_dashboard.dart'; // 임시 비활성화
import '../services/native_audio_service.dart';
import '../core/resource_manager.dart';
import 'package:audioplayers/audioplayers.dart';

class VanidoStyleTrainingScreen extends StatefulWidget {
  final DualResult? analysisResult;
  final List<DualResult>? timeBasedResults;
  final List<double> audioData;
  
  const VanidoStyleTrainingScreen({
    super.key,
    this.analysisResult,
    this.timeBasedResults,
    required this.audioData,
  });

  @override
  State<VanidoStyleTrainingScreen> createState() => _VanidoStyleTrainingScreenState();
}

class _VanidoStyleTrainingScreenState extends State<VanidoStyleTrainingScreen>
    with TickerProviderStateMixin, ResourceManagerMixin {
  
  // Services
  final NativeAudioService _audioService = NativeAudioService.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // 애니메이션
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _scoreController;
  late AnimationController _holographicController;
  late Animation<double> _scoreAnimation;
  late Animation<double> _holographicAnimation;
  
  // 분석 데이터
  double _overallScore = 0;
  double _pitchAccuracy = 0;
  double _consistency = 0;
  double _vibrato = 0;
  String _grade = "A";
  
  // 프로페셔널 분석 데이터
  List<double> _audioSpectrum = [];
  double _currentAmplitude = 0.0;
  double _pitchStability = 0.0;
  bool _isRecording = false;
  int _currentViewMode = 0; // 0: 기본, 1: 하모닉스, 2: 스펙트로그램, 3: 3D, 4: 웨이브폼, 5: 대시보드
  List<String> _viewModeNames = ['Analysis', 'Harmonics', 'Spectrogram', '3D View', 'Waveform', 'Dashboard'];
  
  // 피치 데이터 - RealtimePitchTrackerV2 스타일
  List<PitchPoint> _pitchHistory = [];
  String _currentNote = "";
  double _currentFrequency = 0;
  double _scrollPosition = 0;
  bool _isPlaying = false;
  Timer? _playbackTimer;
  
  // 음계별 색상 (RealtimePitchTrackerV2와 동일)
  final Map<String, Color> noteColors = {
    'C': const Color(0xFFFF6B6B),  // Red
    'C#': const Color(0xFFFF8E53), // Orange-red
    'D': const Color(0xFFFECA57),  // Yellow
    'D#': const Color(0xFFFFE66D), // Light yellow
    'E': const Color(0xFF48F99D),  // Green
    'F': const Color(0xFF5DD3F3),  // Light blue
    'F#': const Color(0xFF6C5CE7), // Purple
    'G': const Color(0xFFA29BFE),  // Light purple
    'G#': const Color(0xFFFF6B9D), // Pink
    'A': const Color(0xFFFF6B6B),  // Red (octave repeat)
    'A#': const Color(0xFFFF8E53), // Orange-red
    'B': const Color(0xFFFECA57),  // Yellow
  };
  
  // 옥타브 범위
  final List<String> octaveNotes = [
    'C2', 'C#2', 'D2', 'D#2', 'E2', 'F2', 'F#2', 'G2', 'G#2', 'A2', 'A#2', 'B2',
    'C3', 'C#3', 'D3', 'D#3', 'E3', 'F3', 'F#3', 'G3', 'G#3', 'A3', 'A#3', 'B3',
    'C4', 'C#4', 'D4', 'D#4', 'E4', 'F4', 'F#4', 'G4', 'G#4', 'A4', 'A#4', 'B4',
    'C5', 'C#5', 'D5', 'D#5', 'E5', 'F5', 'F#5', 'G5', 'G#5', 'A5', 'A#5', 'B5',
    'C6',
  ];
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _analyzePerformance();
  }
  
  void _initializeAnimations() {
    _waveController = registerAnimationController(
      duration: const Duration(seconds: 2),
      debugName: 'VanidoWaveController',
    )..repeat();
    
    _pulseController = registerAnimationController(
      duration: const Duration(milliseconds: 1500),
      debugName: 'VanidoPulseController',
    )..repeat(reverse: true);
    
    _scoreController = registerAnimationController(
      duration: const Duration(milliseconds: 2000),
      debugName: 'VanidoScoreController',
    );
    
    _holographicController = registerAnimationController(
      duration: const Duration(milliseconds: 3000),
      debugName: 'VanidoHolographicController',
    )..repeat();
    
    _scoreAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _scoreController,
      curve: Curves.elasticOut,
    ));
    
    _holographicAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _holographicController,
      curve: Curves.linear,
    ));
    
    _scoreController.forward();
  }
  
  void _analyzePerformance() {
    // 안전한 null 체크 및 에러 처리
    if (!mounted || 
        widget.timeBasedResults == null || 
        widget.timeBasedResults!.isEmpty || 
        widget.audioData.isEmpty) {
      return;
    }
    
    try {
      // CREPE 분석 결과를 기반으로 점수 계산
      double totalAccuracy = 0;
      double totalConfidence = 0;
      int validPoints = 0;
      
      // 피치 히스토리 생성 (RealtimePitchTrackerV2 스타일)
      for (int i = 0; i < widget.timeBasedResults!.length; i++) {
        final result = widget.timeBasedResults![i];
        
        if (result.frequency > 0 && result.confidence > 0.3) {
          final note = _frequencyToNote(result.frequency);
          _pitchHistory.add(PitchPoint(
            time: DateTime.now().add(Duration(milliseconds: i * 100)),
            frequency: result.frequency,
            note: note,
            confidence: result.confidence,
          ));
          
          // 현재 값 업데이트
          _currentFrequency = result.frequency;
          _currentNote = note;
          _currentAmplitude = result.confidence; // 임시로 confidence를 amplitude로 사용
          
          // 정확도 계산
          final cents = 1200 * math.log(result.frequency / 440.0) / math.log(2);
          final accuracy = math.max(0, 100 - cents.abs());
          totalAccuracy += accuracy;
          totalConfidence += result.confidence;
          validPoints++;
        }
      }
      
      if (validPoints > 0) {
        _pitchAccuracy = totalAccuracy / validPoints;
        _consistency = (totalConfidence / validPoints) * 100;
        _vibrato = _detectVibrato();
        _pitchStability = _consistency / 100.0; // 0-1 범위로 정규화
        _overallScore = (_pitchAccuracy * 0.5 + _consistency * 0.3 + _vibrato * 0.2);
        
        // 스펙트럼 데이터 생성 (시뮬레이션)
        _generateMockSpectrum();
        
        // 등급 결정
        if (_overallScore >= 90) _grade = "S";
        else if (_overallScore >= 80) _grade = "A";
        else if (_overallScore >= 70) _grade = "B";
        else if (_overallScore >= 60) _grade = "C";
        else _grade = "D";
      }
    } catch (e) {
      debugPrint('Error in _analyzePerformance: $e');
      _pitchAccuracy = 0;
      _consistency = 0;
      _vibrato = 0;
      _overallScore = 0;
      _grade = "N/A";
    }
  }
  }
  
  String _frequencyToNote(double frequency) {
    if (frequency <= 0) return "";
    
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const a4 = 440.0;
    
    final halfSteps = 12 * (math.log(frequency / a4) / math.log(2));
    final noteIndex = (halfSteps.round() + 9) % 12;
    final octave = ((halfSteps.round() + 9) ~/ 12) + 4;
    
    if (noteIndex < 0 || noteIndex >= notes.length) return "";
    return '${notes[noteIndex]}$octave';
  }
  
  double _detectVibrato() {
    // 간단한 비브라토 감지 (실제로는 더 복잡한 알고리즘 필요)
    if (_pitchHistory.length < 10) return 0;
    
    double variation = 0;
    for (int i = 1; i < _pitchHistory.length; i++) {
      variation += (_pitchHistory[i].frequency - _pitchHistory[i-1].frequency).abs();
    }
    
    // 적절한 변화량이 있으면 비브라토로 간주
    final avgVariation = variation / _pitchHistory.length;
    if (avgVariation > 2 && avgVariation < 10) {
      return 80; // 좋은 비브라토
    } else if (avgVariation <= 2) {
      return 60; // 너무 평평함
    } else {
      return 40; // 너무 불안정
    }
  }
  
  void _generateMockSpectrum() {
    if (!mounted) return;
    
    try {
      // 실제 오디오 스펙트럼 대신 모의 데이터 생성 (간소화)
      _audioSpectrum = List.generate(256, (index) { // 크기 줄임
      final freq = (index / 512.0) * 22050; // 0 ~ 22.05kHz
      double amplitude = 0.0;
      
      // 기본 주파수와 배음 추가
      if (_currentFrequency > 0) {
        for (int harmonic = 1; harmonic <= 5; harmonic++) {
          final harmonicFreq = _currentFrequency * harmonic;
          if ((freq - harmonicFreq).abs() < 50) {
            amplitude += 1.0 / harmonic; // 배음은 점점 약해짐
          }
        }
      }
      
      // 노이즈 추가
      amplitude += math.Random().nextDouble() * 0.1;
      
        return amplitude.clamp(0.0, 1.0);
      });
    } catch (e) {
      debugPrint('Error in _generateMockSpectrum: $e');
      _audioSpectrum = List.filled(256, 0.0);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더
            _buildHeader(),
            
            // 뷰 모드 선택기
            _buildViewModeSelector(),
            
            // 메인 비주얼라이저 영역
            Expanded(
              child: _buildCurrentView(),
            ),
            
            // 점수 카드
            _buildScoreCard(),
            
            // 상세 분석
            _buildDetailedAnalysis(),
            
            // 하단 액션 버튼
            _buildActionButtons(),
          ],
        ),
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
          // 정확도 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.green,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'ANALYZED',
                  style: TextStyle(
                    color: Colors.green,
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
  
  Widget _buildPianoRoll() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 왼쪽 음계 레이블 (무지개색)
          Container(
            width: 60,
            child: Column(
              children: octaveNotes.reversed.map((note) {
                final noteOnly = note.replaceAll(RegExp(r'\d'), '');
                final color = noteColors[noteOnly] ?? Colors.grey;
                
                return Expanded(
                  child: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.1),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Text(
                      note,
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // 오른쪽 그리드
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: CustomPaint(
                painter: GridPainter(),
                child: Container(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPitchCurve() {
    if (_pitchHistory.isEmpty) return Container();
    
    return Container(
      margin: const EdgeInsets.only(left: 76, right: 16),
      child: CustomPaint(
        painter: PitchCurvePainter(
          pitchHistory: _pitchHistory,
          scrollPosition: _scrollPosition,
          noteColors: noteColors,
        ),
        child: Container(),
      ),
    );
  }
  
  Widget _buildCurrentNoteIndicator() {
    if (_currentNote.isEmpty) return Container();
    
    final noteOnly = _currentNote.replaceAll(RegExp(r'\d'), '');
    final color = noteColors[noteOnly] ?? Colors.grey;
    
    return Positioned(
      right: 30,
      top: 100,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_pulseController.value * 0.1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Text(
                _currentNote,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildPitchGraph() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
      child: Stack(
        children: [
          // 배경 그리드
          CustomPaint(
            painter: GridPainter(),
            child: Container(),
          ),
          
          // 피치 곡선
          AnimatedBuilder(
            animation: _scoreAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: VanidoPitchPainter(
                  userPitchPoints: _pitchHistory,
                  targetPitchPoints: _pitchHistory,
                  animationValue: _scoreAnimation.value,
                ),
                child: Container(),
              );
            },
          ),
          
          // 레이블
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Your Pitch',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: Colors.white54, width: 1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Target',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
        animation: _scoreAnimation,
        builder: (context, child) {
          return Row(
            children: [
              // 등급 표시
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
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'GRADE',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 20),
              
              // 점수 상세
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${(_overallScore * _scoreAnimation.value).toInt()}',
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
              
              // 펄스 애니메이션
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.1),
                    child: Icon(
                      Icons.star,
                      color: Colors.yellowAccent.withOpacity(
                        0.5 + 0.5 * _pulseController.value,
                      ),
                      size: 30,
                    ),
                  );
                },
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
      animation: _scoreAnimation,
      builder: (context, child) {
        final animatedValue = value * _scoreAnimation.value;
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
                      color: Colors.white.withOpacity(0.1),
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
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.05),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  void _startPlayback() async {
    if (_pitchHistory.isEmpty) return;
    
    setState(() {
      _isPlaying = true;
      _scrollPosition = 0;
    });
    
    // 녹음된 오디오 재생
    await _audioService.playAudio();
    
    // 피치 히스토리를 순차적으로 보여주는 애니메이션
    int currentIndex = 0;
    _playbackTimer = registerTimer(
      const Duration(milliseconds: 100), 
      () {
        if (currentIndex >= _pitchHistory.length) {
          _playbackTimer?.cancel();
          setState(() {
            _isPlaying = false;
          });
          return;
        }
        
        setState(() {
          _currentNote = _pitchHistory[currentIndex].note;
          _currentFrequency = _pitchHistory[currentIndex].frequency;
          _scrollPosition = currentIndex.toDouble();
        });
        
        currentIndex++;
      },
      debugName: 'VanidoPlaybackTimer',
    );
  }
  
  String _getMotivationalMessage() {
    if (_overallScore >= 90) return "Outstanding performance! 🌟";
    if (_overallScore >= 80) return "Great job! Keep it up! 🎵";
    if (_overallScore >= 70) return "Good progress! 👍";
    if (_overallScore >= 60) return "Nice try! Practice makes perfect!";
    return "Keep practicing, you'll get there!";
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
    // 안전한 null 체크
    if (widget.audioData.isEmpty || !mounted) {
      return Container(
        child: const Center(
          child: Text('Loading analysis data...'),
        ),
      );
    }

    try {
      switch (_currentViewMode) {
        case 0: // 기본 분석 뷰 - 최적화된 렌더링
          return RepaintBoundary(
            child: Stack(
              children: [
                // 피아노 롤 배경 - 캐시된 렌더링
                RepaintBoundary(
                  key: const ValueKey('piano_roll'),
                  child: _buildPianoRoll(),
                ),
                
                // 실시간 피치 곡선 - 조건부 렌더링
                if (_pitchHistory.isNotEmpty)
                  RepaintBoundary(
                    key: ValueKey('pitch_curve_${_pitchHistory.length}'),
                    child: _buildPitchCurve(),
                  ),
                
                // 현재 음 표시 - 변경시만 렌더링
                if (_currentNote.isNotEmpty)
                  RepaintBoundary(
                    key: ValueKey('note_indicator_$_currentNote'),
                    child: _buildCurrentNoteIndicator(),
                  ),
              ],
            ),
          );
          
        case 1: // 하모닉스 분석 - 캐시된 렌더링 (에러 방지)
          return RepaintBoundary(
            key: ValueKey('harmonics_${_currentFrequency.toStringAsFixed(1)}'),
            child: Container(
              margin: const EdgeInsets.all(16),
              child: _currentFrequency > 0 
                ? ProfessionalHarmonicsAnalyzer(
                    audioData: widget.audioData,
                    fundamentalFrequency: _currentFrequency,
                    maxHarmonics: 4, // 부하 감소를 위해 4개로 제한
                    showFormants: false, // 초기 로드시 비활성화
                    displayMode: HarmonicsDisplayMode.circular,
                    primaryColor: const Color(0xFF00ff88),
                    harmonicColor: const Color(0xFFffaa00),
                  )
                : Container(
                    child: const Center(
                      child: Text('Analyzing frequency...'),
                    ),
                  ),
            ),
          );
          
        case 2: // 스펙트로그램 (간소화)
          return Container(
            margin: const EdgeInsets.all(16),
            child: ProfessionalSpectrogramOverlay(
              audioData: widget.audioData,
              sampleRate: 44100,
              timeRange: 5.0, // 시간 범위 줄임
              frequencyRange: 1000.0, // 주파수 범위 줄임
              showHarmonics: false, // 초기에는 비활성화
              opacity: 0.6,
              colorScheme: SpectrogramColorScheme.medical,
            ),
          );
          
        case 3: // 3D 뷰 (파티클 효과 비활성화)
          return Container(
            margin: const EdgeInsets.all(16),
            child: Holographic3DPitchVisualizer(
              pitchData: _pitchHistory,
              width: MediaQuery.of(context).size.width - 32,
              height: 400,
              enableParticleEffects: false, // 부하 감소를 위해 비활성화
              primaryColor: const Color(0xFF00ffff),
              accentColor: const Color(0xFFff00ff),
              rotationSpeed: 0.3, // 회전 속도 감소
            ),
          );
          
        case 4: // Logic Pro 스타일 웨이브폼 (간소화)
          return Container(
            margin: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  'Waveform View\n(Temporarily Disabled)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
          
        case 5: // 실시간 데이터 대시보드
          return Container(
            margin: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Real-time Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Current Note: $_currentNote',
                      style: TextStyle(color: Colors.green, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Frequency: ${_currentFrequency.toStringAsFixed(1)} Hz',
                      style: TextStyle(color: Colors.blue, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pitch Stability: ${(_pitchStability * 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: Colors.orange, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          );
          
        default:
          return Container(
            child: const Center(
              child: Text('Select a view mode'),
            ),
          );
      }
    } catch (e) {
      // 에러 발생시 안전한 fallback
      debugPrint('Error in _buildCurrentView: $e');
      return Container(
        child: Center(
          child: Text('Error loading view: ${e.toString()}'),
        ),
      );
    }
  }
  
  // 누락된 메소드들 추가
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green, width: 1),
            ),
            child: const Text(
              'ANALYZED',
              style: TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
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
              if (mounted) {
                setState(() {
                  _currentViewMode = index;
                });
                HapticFeedback.selectionClick();
              }
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

  Widget _buildPianoRoll() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: const Center(
        child: Text('Piano Roll View', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _buildPitchCurve() {
    return Container(
      margin: const EdgeInsets.only(left: 76, right: 16),
      child: const Center(
        child: Text('Pitch Curve', style: TextStyle(color: Colors.blue)),
      ),
    );
  }

  Widget _buildCurrentNoteIndicator() {
    if (_currentNote.isEmpty) return Container();
    
    return Positioned(
      right: 30,
      top: 100,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _currentNote,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _grade,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_overallScore.toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  ' / 100',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              ],
            ),
          ),
        ],
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
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
        ),
        Expanded(
          flex: 5,
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              widthFactor: value / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            '${value.toInt()}%',
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
              child: const Text('Try Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
              ),
              child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // AudioPlayer 정리
    _audioPlayer.dispose();
    
    // ResourceManagerMixin이 모든 AnimationController와 Timer를 자동으로 정리함
    super.dispose();
  }
}


// 피치 곡선 페인터 (RealtimePitchTrackerV2 스타일)
class PitchCurvePainter extends CustomPainter {
  final List<PitchPoint> pitchHistory;
  final double scrollPosition;
  final Map<String, Color> noteColors;
  
  PitchCurvePainter({
    required this.pitchHistory,
    required this.scrollPosition,
    required this.noteColors,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (pitchHistory.isEmpty) return;
    
    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final path = Path();
    
    for (int i = 0; i < pitchHistory.length; i++) {
      final point = pitchHistory[i];
      final x = (i / pitchHistory.length) * size.width;
      
      // 주파수를 Y 좌표로 변환 (C2-C6 범위)
      final noteIndex = _getNoteIndex(point.note);
      final y = size.height - (noteIndex / 49.0 * size.height);
      
      // 색상 설정 (신뢰도에 따라 투명도 조절)
      final noteOnly = point.note.replaceAll(RegExp(r'\d'), '');
      final baseColor = noteColors[noteOnly] ?? Colors.grey;
      paint.color = baseColor.withOpacity(0.3 + point.confidence * 0.7);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // 부드러운 곡선
        final prevPoint = pitchHistory[i - 1];
        final prevX = ((i - 1) / pitchHistory.length) * size.width;
        final prevNoteIndex = _getNoteIndex(prevPoint.note);
        final prevY = size.height - (prevNoteIndex / 49.0 * size.height);
        
        final cpX = (prevX + x) / 2;
        path.quadraticBezierTo(cpX, prevY, x, y);
      }
      
      // 포인트 그리기 (높은 신뢰도일 때만)
      if (point.confidence > 0.7) {
        canvas.drawCircle(Offset(x, y), 4, Paint()..color = paint.color);
      }
    }
    
    canvas.drawPath(path, paint);
  }
  
  int _getNoteIndex(String note) {
    const notes = [
      'C2', 'C#2', 'D2', 'D#2', 'E2', 'F2', 'F#2', 'G2', 'G#2', 'A2', 'A#2', 'B2',
      'C3', 'C#3', 'D3', 'D#3', 'E3', 'F3', 'F#3', 'G3', 'G#3', 'A3', 'A#3', 'B3',
      'C4', 'C#4', 'D4', 'D#4', 'E4', 'F4', 'F#4', 'G4', 'G#4', 'A4', 'A#4', 'B4',
      'C5', 'C#5', 'D5', 'D#5', 'E5', 'F5', 'F#5', 'G5', 'G#5', 'A5', 'A#5', 'B5',
      'C6',
    ];
    
    final index = notes.indexOf(note);
    return index >= 0 ? index : 24; // Default to C4
  }
  
  @override
  bool shouldRepaint(PitchCurvePainter oldDelegate) => true;
}

// Vanido 스타일 피치 그래프 페인터
class VanidoPitchPainter extends CustomPainter {
  final List<PitchPoint> userPitchPoints;
  final List<PitchPoint> targetPitchPoints;
  final double animationValue;
  
  VanidoPitchPainter({
    required this.userPitchPoints,
    required this.targetPitchPoints,
    required this.animationValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (userPitchPoints.isEmpty) return;
    
    // 목표 피치 라인 (점선)
    if (targetPitchPoints.isNotEmpty) {
      final targetPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      
      final targetPath = Path();
      for (int i = 0; i < targetPitchPoints.length; i++) {
        final x = (i / targetPitchPoints.length) * size.width;
        final y = size.height / 2; // 중앙 고정 (실제로는 주파수에 따라 계산)
        
        if (i == 0) {
          targetPath.moveTo(x, y);
        } else if (i % 2 == 0) {
          targetPath.lineTo(x, y);
        } else {
          targetPath.moveTo(x, y);
        }
      }
      canvas.drawPath(targetPath, targetPaint);
    }
    
    // 사용자 피치 곡선
    final userPaint = Paint()
      ..color = const Color(0xFF4ECDC4)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // 그라데이션 효과
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF4ECDC4).withOpacity(0.0),
          const Color(0xFF4ECDC4).withOpacity(0.3),
          const Color(0xFF4ECDC4).withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final userPath = Path();
    final fillPath = Path();
    
    for (int i = 0; i < (userPitchPoints.length * animationValue).floor(); i++) {
      final point = userPitchPoints[i];
      final x = (i / userPitchPoints.length) * size.width;
      
      // 주파수를 Y 좌표로 변환 (200-600Hz 범위)
      final normalizedFreq = (point.frequency - 200) / 400;
      final y = size.height * (1 - normalizedFreq.clamp(0, 1));
      
      if (i == 0) {
        userPath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        // 부드러운 곡선
        final prevPoint = userPitchPoints[i - 1];
        final prevX = ((i - 1) / userPitchPoints.length) * size.width;
        final prevY = size.height * (1 - ((prevPoint.frequency - 200) / 400).clamp(0, 1));
        
        final cpX = (prevX + x) / 2;
        userPath.quadraticBezierTo(cpX, prevY, x, y);
        fillPath.quadraticBezierTo(cpX, prevY, x, y);
      }
      
      // 정확도에 따른 포인트 표시
      if (point.confidence > 0.8) {
        final pointPaint = Paint()
          ..color = const Color(0xFF4ECDC4)
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(Offset(x, y), 3, pointPaint);
        
        // 광원 효과
        final glowPaint = Paint()
          ..color = const Color(0xFF4ECDC4).withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        
        canvas.drawCircle(Offset(x, y), 6, glowPaint);
      }
    }
    
    // 채우기 영역
    if (userPitchPoints.isNotEmpty) {
      fillPath.lineTo(
        ((userPitchPoints.length - 1) / userPitchPoints.length) * size.width,
        size.height,
      );
      fillPath.close();
      canvas.drawPath(fillPath, gradientPaint);
    }
    
    // 메인 라인
    canvas.drawPath(userPath, userPaint);
  }
  
  @override
  bool shouldRepaint(VanidoPitchPainter oldDelegate) => true;
}

// 배경 그리드 페인터
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