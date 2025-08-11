import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/native_audio_service.dart';
import '../services/dual_engine_service.dart';
import '../services/ai_feedback_service.dart';
import '../models/analysis_result.dart';
import '../models/pitch_point.dart';
import '../core/resource_manager.dart';

class RealtimePitchTrackerV2 extends StatefulWidget {
  const RealtimePitchTrackerV2({super.key});

  @override
  State<RealtimePitchTrackerV2> createState() => _RealtimePitchTrackerV2State();
}

class _RealtimePitchTrackerV2State extends State<RealtimePitchTrackerV2>
    with TickerProviderStateMixin, ResourceManagerMixin {
  
  // Services
  final NativeAudioService _audioService = NativeAudioService.instance;
  final DualEngineService _dualEngine = DualEngineService();
  final AIFeedbackService _feedbackService = AIFeedbackService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Recording state
  bool _isRecording = false;
  bool _isTestMode = false;
  Timer? _analysisTimer;
  String? _testFilePath;
  List<double>? _testAudioData;
  int _testDataIndex = 0; // 테스트 데이터 현재 위치
  
  // Pitch data - 시간별 피치 트래킹
  List<PitchPoint> _pitchHistory = [];
  double _currentFrequency = 0;
  String _currentNote = "";
  double _scrollPosition = 0;
  
  // Animation
  late AnimationController _waveController;
  late AnimationController _pulseController;
  
  // 음계별 색상 (이미지처럼 무지개색)
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
    _setupAudioService();
  }
  
  void _initializeAnimations() {
    _waveController = registerAnimationController(
      duration: const Duration(seconds: 2),
      debugName: 'RealtimeWaveController',
    )..repeat();
    
    _pulseController = registerAnimationController(
      duration: const Duration(milliseconds: 1500),
      debugName: 'RealtimePulseController',
    )..repeat(reverse: true);
  }
  
  void _setupAudioService() async {
    await _audioService.initialize();
  }
  
  void _toggleRecording() async {
    if (_isRecording) {
      _stopRecording();
    } else {
      if (_isTestMode && _testFilePath != null) {
        _startTestMode();
      } else {
        _startRecording();
      }
    }
  }
  
  void _loadTestFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );
      
      if (result != null && result.files.single.path != null) {
        setState(() {
          _testFilePath = result.files.single.path;
          _isTestMode = true;
        });
        
        // MP3 파일을 오디오 데이터로 변환
        // 실제 구현에서는 ffmpeg나 다른 라이브러리를 사용해야 함
        // 여기서는 간단한 테스트를 위해 더미 데이터 사용
        _loadAudioData(_testFilePath!);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('MP3 loaded: ${result.files.single.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error loading file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load MP3 file'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _loadAudioData(String filePath) async {
    try {
      // 네이티브 코드를 통해 실제 오디오 파일 로드
      final audioData = await _audioService.loadAudioFile(filePath);
      
      if (audioData != null && audioData['samples'] != null) {
        setState(() {
          _testAudioData = audioData['samples'] as List<double>;
        });
        
        final sampleRate = audioData['sampleRate'] as double;
        final duration = audioData['duration'] as double;
        
        print('🎵 오디오 파일 로드 성공: ${_testAudioData!.length} 샘플, ${duration.toStringAsFixed(1)}초, ${sampleRate.toInt()}Hz');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio loaded: ${duration.toStringAsFixed(1)}s @ ${sampleRate.toInt()}Hz'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to load audio data');
      }
    } catch (e) {
      print('Error loading audio data: $e');
      
      // 로드 실패 시 테스트용 사인파 생성
      final sampleRate = 44100;
      final duration = 10; // 10초
      final samples = sampleRate * duration;
      
      _testAudioData = List.generate(samples, (i) {
        // 440Hz (A4) 사인파 생성
        return math.sin(2 * math.pi * 440 * i / sampleRate) * 0.5;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Using test sine wave (440Hz)'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  void _startTestMode() async {
    setState(() {
      _isRecording = true;
      _pitchHistory.clear();
      _testDataIndex = 0; // 인덱스 리셋
    });
    
    HapticFeedback.heavyImpact();
    
    // MP3 재생 시작
    if (_testFilePath != null) {
      await _audioPlayer.play(DeviceFileSource(_testFilePath!));
    }
    
    // 50ms마다 MP3 데이터 분석
    _analysisTimer = registerTimer(
      const Duration(milliseconds: 50), 
      _analyzeRealtimePitch,
      debugName: 'RealtimeTestAnalysisTimer',
    );
  }
  
  void _startRecording() async {
    setState(() {
      _isRecording = true;
      _pitchHistory.clear();
    });
    
    HapticFeedback.heavyImpact();
    await _audioService.startRecording();
    
    // 50ms마다 초고속 CREPE 분석 (실시간성 극대화)
    _analysisTimer = registerTimer(
      const Duration(milliseconds: 50), 
      _analyzeRealtimePitch,
      debugName: 'RealtimeRecordingAnalysisTimer',
    );
  }
  
  void _stopRecording() async {
    setState(() {
      _isRecording = false;
    });
    
    _analysisTimer?.cancel();
    HapticFeedback.mediumImpact();
    
    if (_isTestMode) {
      await _audioPlayer.stop();
    } else {
      await _audioService.stopRecording();
    }
    
    // 녹음 종료 후 AI 피드백 생성
    _generateAIFeedback();
  }
  
  void _analyzeRealtimePitch() async {
    List<double>? audioData;
    
    if (_isTestMode && _testAudioData != null) {
      // 테스트 모드: MP3 파일 데이터를 순차적으로 처리
      const chunkSize = 2048; // 50ms @ 44.1kHz ≈ 2205 샘플
      
      if (_testDataIndex >= _testAudioData!.length) {
        // 데이터 끝에 도달했으면 정지
        _stopRecording();
        return;
      }
      
      final endIndex = math.min(_testDataIndex + chunkSize, _testAudioData!.length);
      audioData = _testAudioData!.sublist(_testDataIndex, endIndex);
      _testDataIndex = endIndex; // 다음 위치로 이동
      
      print('📊 테스트 모드 진행: ${_testDataIndex}/${_testAudioData!.length} (${(_testDataIndex * 100 / _testAudioData!.length).toStringAsFixed(1)}%)');
    } else {
      // 실시간 모드: 마이크 입력 사용
      audioData = await _audioService.getRealtimeAudioBuffer();
    }
    
    if (audioData == null || audioData.isEmpty) return;
    
    try {
      // CREPE 서버로 실시간 분석 (빠른 모드)
      final Float32List audioFloat32 = Float32List.fromList(audioData);
      final result = await _dualEngine.analyzeSinglePitch(audioFloat32);
      
      double frequency = 0;
      double confidence = 0;
      
      if (result != null && result.frequency > 0) {
        frequency = result.frequency;
        confidence = result.confidence;
      } else {
        // 폴백: 간단한 자체 피치 감지
        frequency = _quickPitchDetection(audioFloat32);
        confidence = _calculateConfidence(audioFloat32, frequency);
      }
      
      // 필터링: 사람 목소리 범위 (80Hz ~ 1000Hz) & 충분한 신뢰도
      final isValidPitch = frequency > 80 && frequency < 1000 && confidence > 0.5;
      
      // 볼륨 체크: 너무 작은 소리는 무시
      final volume = _calculateVolume(audioFloat32);
      final isAudible = volume > 0.01; // 최소 볼륨 임계값
      
      if (frequency > 0 && isValidPitch && isAudible) {
        final note = _frequencyToNote(frequency);
        final timestamp = DateTime.now();
        
        setState(() {
          _currentFrequency = frequency;
          _currentNote = note;
          
          // 피치 히스토리에 추가
          _pitchHistory.add(PitchPoint(
            time: timestamp,
            frequency: frequency,
            note: note,
            confidence: confidence,
          ));
          
          // 최대 200개 포인트 유지 (10초 분량)
          if (_pitchHistory.length > 200) {
            _pitchHistory.removeAt(0);
          }
          
          // 자동 스크롤
          _scrollPosition += 2;
        });
      }
    } catch (e) {
      print('Pitch detection error: $e');
    }
  }
  
  // 개선된 자체 피치 감지 알고리즘 (YIN 알고리즘)
  double _quickPitchDetection(Float32List audioData) {
    if (audioData.length < 512) return 0;
    
    // YIN 알고리즘 구현 (더 정확한 피치 감지)
    const minPeriod = 40;  // ~1100Hz (44100/40)
    const maxPeriod = 400; // ~110Hz (44100/400)
    const threshold = 0.1;
    
    // Step 1: Difference function
    final yinBuffer = List<double>.filled(maxPeriod, 0);
    
    for (int tau = 1; tau < maxPeriod && tau < audioData.length / 2; tau++) {
      double sum = 0;
      for (int i = 0; i < audioData.length - tau; i++) {
        final delta = audioData[i] - audioData[i + tau];
        sum += delta * delta;
      }
      yinBuffer[tau] = sum;
    }
    
    // Step 2: Cumulative mean normalized difference
    yinBuffer[0] = 1;
    double runningSum = 0;
    
    for (int tau = 1; tau < maxPeriod; tau++) {
      runningSum += yinBuffer[tau];
      yinBuffer[tau] *= tau / runningSum;
    }
    
    // Step 3: Absolute threshold
    int bestPeriod = 0;
    for (int tau = minPeriod; tau < maxPeriod; tau++) {
      if (yinBuffer[tau] < threshold) {
        bestPeriod = tau;
        
        // Step 4: Parabolic interpolation
        if (tau > 0 && tau < maxPeriod - 1) {
          final x0 = tau - 1;
          final x2 = tau + 1;
          
          final y0 = yinBuffer[x0];
          final y1 = yinBuffer[tau];
          final y2 = yinBuffer[x2];
          
          final a = (y2 - 2 * y1 + y0) / 2;
          if (a != 0) {
            final xVertex = tau - (y2 - y0) / (2 * a);
            if (xVertex > 0) {
              return 44100.0 / xVertex;
            }
          }
        }
        
        return 44100.0 / bestPeriod;
      }
    }
    
    return 0;
  }
  
  // 볼륨 계산 (RMS - Root Mean Square)
  double _calculateVolume(Float32List audioData) {
    if (audioData.isEmpty) return 0;
    
    double sum = 0;
    for (final sample in audioData) {
      sum += sample * sample;
    }
    
    return math.sqrt(sum / audioData.length);
  }
  
  // 신뢰도 계산 (피치 감지의 신뢰성)
  double _calculateConfidence(Float32List audioData, double frequency) {
    if (frequency <= 0) return 0;
    
    // 볼륨 기반 신뢰도
    final volume = _calculateVolume(audioData);
    
    // 주파수 범위 기반 신뢰도 (사람 목소리 범위에 가까울수록 높음)
    double freqConfidence = 1.0;
    if (frequency < 80 || frequency > 1000) {
      freqConfidence = 0.3;
    } else if (frequency < 100 || frequency > 800) {
      freqConfidence = 0.7;
    }
    
    // 최종 신뢰도 = 볼륨 * 주파수 신뢰도
    return math.min(volume * 10 * freqConfidence, 1.0);
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
  
  void _generateAIFeedback() {
    if (_pitchHistory.isNotEmpty) {
      // AI 피드백 생성
      final feedback = _feedbackService.generateFeedback(
        pitchHistory: _pitchHistory,
      );
      
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _buildAIFeedbackSheet(feedback),
      );
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
            
            // 메인 피치 비주얼라이저
            Expanded(
              child: Stack(
                children: [
                  // 피아노 롤 배경
                  _buildPianoRoll(),
                  
                  // 실시간 피치 곡선
                  _buildPitchCurve(),
                  
                  // 현재 음 표시
                  if (_currentNote.isNotEmpty)
                    _buildCurrentNoteIndicator(),
                ],
              ),
            ),
            
            // 하단 컨트롤
            _buildControls(),
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
              'Real-time Pitch Tracker',
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
              color: _isRecording ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isRecording ? Colors.green : Colors.grey,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isRecording ? 'LIVE' : 'READY',
                  style: TextStyle(
                    color: _isRecording ? Colors.green : Colors.grey,
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
    if (!_isRecording || _currentNote.isEmpty) return Container();
    
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
  
  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 모드 전환 버튼들
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // MP3 테스트 버튼
              ElevatedButton.icon(
                onPressed: _loadTestFile,
                icon: const Icon(Icons.audio_file, size: 20),
                label: Text(_testFilePath != null ? 'MP3 Loaded' : 'Load MP3'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _testFilePath != null ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 모드 표시
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isTestMode ? Colors.orange.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isTestMode ? Colors.orange : Colors.blue,
                    width: 1,
                  ),
                ),
                child: Text(
                  _isTestMode ? 'TEST MODE' : 'LIVE MODE',
                  style: TextStyle(
                    color: _isTestMode ? Colors.orange : Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 녹음/재생 버튼
          GestureDetector(
            onTap: _toggleRecording,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isRecording
                        ? [Colors.red, Colors.red.shade700]
                        : _isTestMode 
                          ? [Colors.orange, Colors.orange.shade700]
                          : [Colors.blue, Colors.blue.shade700],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording ? Colors.red : _isTestMode ? Colors.orange : Colors.blue)
                            .withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: _isRecording ? 10 : 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : _isTestMode ? Icons.play_arrow : Icons.mic,
                    color: Colors.white,
                    size: 35,
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            _isRecording 
              ? 'Tap to stop' 
              : _isTestMode 
                ? 'Tap to test MP3' 
                : 'Tap to start',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAIFeedbackSheet(VocalFeedback feedback) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Center(
                    child: Text(
                      '🎤 AI Vocal Coach Analysis',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Overall Score
                  _buildScoreCard(feedback),
                  
                  const SizedBox(height: 20),
                  
                  // Detailed Metrics
                  _buildMetricsGrid(feedback),
                  
                  const SizedBox(height: 20),
                  
                  // Vocal Range
                  if (feedback.vocalRange != null)
                    _buildVocalRangeCard(feedback.vocalRange!),
                  
                  const SizedBox(height: 20),
                  
                  // Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📝 Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          feedback.summary,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  
                  // Strengths
                  if (feedback.strengths.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildListCard(
                      '💪 Strengths',
                      feedback.strengths,
                      Colors.green,
                    ),
                  ],
                  
                  // Areas for Improvement
                  if (feedback.improvements.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildListCard(
                      '🎯 Areas for Improvement',
                      feedback.improvements,
                      Colors.orange,
                    ),
                  ],
                  
                  // Suggestions
                  const SizedBox(height: 16),
                  _buildSuggestionsCard(feedback.suggestions),
                  
                  const SizedBox(height: 24),
                  
                  // Action Button
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue Practice',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScoreCard(VocalFeedback feedback) {
    final percentage = (feedback.overallScore * 100).round();
    Color scoreColor;
    if (percentage >= 80) {
      scoreColor = Colors.green;
    } else if (percentage >= 60) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scoreColor.withOpacity(0.1), scoreColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: feedback.overallScore,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
              Column(
                children: [
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  Text(
                    'Overall',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricsGrid(VocalFeedback feedback) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Pitch Accuracy',
            feedback.pitchAccuracy,
            Icons.music_note,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Stability',
            feedback.pitchStability,
            Icons.timeline,
            Colors.purple,
          ),
        ),
      ],
    );
  }
  
  Widget _buildMetricCard(String label, double value, IconData icon, Color color) {
    final percentage = (value * 100).round();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildVocalRangeCard(VocalRange range) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.piano, color: Colors.indigo),
              const SizedBox(width: 8),
              const Text(
                'Vocal Range',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  range.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    range.lowest,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const Text(
                    'Lowest',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward, color: Colors.grey),
              Column(
                children: [
                  Text(
                    range.highest,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const Text(
                    'Highest',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    '${range.rangeInSemitones}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const Text(
                    'Semitones',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildListCard(String title, List<String> items, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildSuggestionsCard(List<String> suggestions) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.withOpacity(0.1), Colors.purple.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Practice Tips',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...suggestions.map((suggestion) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              suggestion,
              style: const TextStyle(fontSize: 14),
            ),
          )),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    // 오디오 플레이어 정리
    _audioPlayer.dispose();
    
    // ResourceManagerMixin이 모든 AnimationController와 Timer를 자동으로 정리함
    super.dispose();
  }
}


// 피치 곡선 페인터
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

// 그리드 페인터
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 0.5;
    
    // 가로선 (음계별)
    for (int i = 0; i <= 49; i++) {
      final y = (i / 49) * size.height;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
    
    // 세로선 (시간별)
    for (int i = 0; i <= 20; i++) {
      final x = (i / 20) * size.width;
      
      // 점선 효과
      for (double y = 0; y < size.height; y += 5) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + 2),
          paint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}