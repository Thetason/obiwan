import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../widgets/particle_system.dart';
import '../services/dual_engine_service.dart';
import '../models/analysis_result.dart';
import '../services/pitch_analysis_service.dart';
import '../widgets/pitch_graph_widget.dart';
import '../widgets/vertical_pitch_scale_widget.dart';

class FixedVocalTrainingScreen extends StatefulWidget {
  final DualResult? analysisResult;
  final List<double> audioData;
  
  const FixedVocalTrainingScreen({
    super.key,
    this.analysisResult,
    required this.audioData,
  });

  @override
  State<FixedVocalTrainingScreen> createState() => _FixedVocalTrainingScreenState();
}

class _FixedVocalTrainingScreenState extends State<FixedVocalTrainingScreen>
    with TickerProviderStateMixin {
  FlutterSoundRecorder? _recorder;
  RealtimeAnalysisStream? _analysisStream;
  StreamController<Uint8List>? _recordingController;
  
  bool _isInitialized = false;
  bool _isRecording = false;
  
  // 분석 결과
  DualResult? _lastResult;
  double _currentPitch = 0.0;
  double _targetPitch = 440.0; // A4
  String _feedback = "초기화 중...";
  String _noteName = "---";
  double _cents = 0.0;
  double _audioLevel = 0.0;
  
  // 애니메이션
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  
  // 피치 히스토리 (시각화용)
  final List<double> _pitchHistory = [];
  static const int _maxHistoryLength = 100;
  
  // 시간별 피치 분석 데이터
  List<PitchDataPoint> _pitchDataPoints = [];
  VibratoData? _vibratoData;
  bool _isPitchAnalysisComplete = false;
  
  // 오디오 데이터 (시각화용)
  Float32List? _currentAudioData;
  
  // 색상 테마 - 밝고 친근한 톤
  final Color _primaryColor = const Color(0xFF5B8DEE); // 부드러운 파랑
  final Color _secondaryColor = const Color(0xFF9C88FF); // 파스텔 보라
  final Color _accentColor = const Color(0xFF00BFA6); // 민트색

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeServices();
    _startPitchAnalysis(); // 피치 분석 시작
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _waveAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.linear),
    );

    _pulseController.repeat(reverse: true);
    _waveController.repeat();
  }

  Future<void> _initializeServices() async {
    try {
      // 마이크 권한 요청
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('마이크 권한이 필요합니다');
      }

      // Flutter Sound 초기화
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();

      // 분석 스트림 초기화
      _analysisStream = RealtimeAnalysisStream();
      _analysisStream!.stream.listen(_onAnalysisResult);

      setState(() {
        _isInitialized = true;
        _feedback = "준비 완료! 🎤 버튼을 눌러 시작하세요";
      });

    } catch (e) {
      setState(() {
        _feedback = "초기화 실패: $e";
      });
    }
  }

  void _onAnalysisResult(DualResult result) {
    setState(() {
      _lastResult = result;
      _currentPitch = result.frequency;
      
      // 피치 히스토리 업데이트
      _pitchHistory.add(_currentPitch);
      if (_pitchHistory.length > _maxHistoryLength) {
        _pitchHistory.removeAt(0);
      }
      
      // 노트 이름과 센트 계산
      if (_currentPitch > 0) {
        _noteName = _getNoteName(_currentPitch);
        _cents = _getCentsFromFrequency(_currentPitch, _targetPitch);
      } else {
        _noteName = "---";
        _cents = 0.0;
      }
      
      // 피드백 생성
      _feedback = _generateFeedback(result);
    });
  }

  String _generateFeedback(DualResult result) {
    if (result.frequency <= 0) {
      return "목소리가 감지되지 않았어요 🎤";
    }

    if (result.isChord) {
      final pitchCount = result.detectedPitches.length;
      return "화음 감지! 🎵\n${pitchCount}개 음성이 감지되었습니다";
    }

    // 단일음 피드백
    final cents = 1200 * math.log(result.frequency / _targetPitch) / math.log(2);
    final absCents = cents.abs();
    
    if (absCents < 5) {
      return "완벽합니다! 🎯\n${cents.toStringAsFixed(1)} cents 오차";
    } else if (absCents < 20) {
      return cents > 0 
          ? "조금 높아요 ⬇️\n+${cents.toStringAsFixed(1)} cents"
          : "조금 낮아요 ⬆️\n${cents.toStringAsFixed(1)} cents";
    } else {
      return cents > 0 
          ? "많이 높아요 🔻\n+${cents.toStringAsFixed(1)} cents"
          : "많이 낮아요 🔺\n${cents.toStringAsFixed(1)} cents";
    }
  }

  Future<void> _startRecording() async {
    if (!_isInitialized || _isRecording) return;

    try {
      _recordingController = StreamController<Uint8List>();
      
      // 분석 스트림 시작
      _analysisStream!.startStream();

      // 녹음 시작
      await _recorder!.startRecorder(
        toStream: _recordingController!.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
      );

      // 오디오 데이터 처리
      _recordingController!.stream.listen((buffer) {
        final audioData = _processAudioBuffer(buffer);
        if (audioData != null) {
          // 시각화를 위해 현재 오디오 데이터 저장
          setState(() {
            _currentAudioData = audioData;
            _audioLevel = _calculateAudioLevel(audioData);
          });
          _analysisStream!.addAudioChunk(audioData);
        }
      });

      setState(() {
        _isRecording = true;
        _feedback = "녹음 중... 소리를 내보세요! 🎵";
      });

    } catch (e) {
      setState(() {
        _feedback = "녹음 시작 실패: $e";
      });
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder!.stopRecorder();
      _analysisStream!.stopStream();
      await _recordingController?.close();
      _recordingController = null;

      setState(() {
        _isRecording = false;
        _feedback = "녹음 중지됨. 다시 시작하려면 🎤를 누르세요";
        _audioLevel = 0.0;
        _currentAudioData = null;
      });

    } catch (e) {
      setState(() {
        _feedback = "녹음 중지 실패: $e";
      });
    }
  }

  Float32List? _processAudioBuffer(Uint8List buffer) {
    try {
      final int16Data = Int16List.view(buffer.buffer);
      final float32Data = Float32List(int16Data.length);
      
      for (int i = 0; i < int16Data.length; i++) {
        float32Data[i] = int16Data[i] / 32768.0;
      }
      
      return float32Data;
    } catch (e) {
      debugPrint('Audio buffer processing failed: $e');
      return null;
    }
  }
  
  double _calculateAudioLevel(Float32List audioData) {
    double sum = 0.0;
    for (int i = 0; i < audioData.length; i++) {
      sum += audioData[i].abs();
    }
    return (sum / audioData.length).clamp(0.0, 1.0);
  }
  
  String _getNoteName(double frequency) {
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const a4 = 440.0;
    
    final semitones = 12 * (math.log(frequency / a4) / math.log(2));
    final noteIndex = (semitones.round() + 9) % 12;
    final octave = ((semitones + 9) / 12).floor() + 4;
    
    return '${noteNames[noteIndex]}$octave';
  }
  
  double _getCentsFromFrequency(double frequency, double targetFreq) {
    return 1200 * math.log(frequency / targetFreq) / math.log(2);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _recorder?.closeRecorder();
    _analysisStream?.dispose();
    _recordingController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF5F5F7),
              const Color(0xFFFFFFFF),
              const Color(0xFFF8F9FA),
              _primaryColor.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(),
              
              // 상단: 세로 음계 스케일 (고정 높이)
              Container(
                height: MediaQuery.of(context).size.height * 0.45, // 화면의 45%
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: _buildVerticalPitchScale(),
              ),
              
              // 하단: 분석 결과 (스크롤 가능)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // 분석 결과 헤더
                        _buildAnalysisResultHeader(),
                        const SizedBox(height: 20),
                        
                        // 상세 분석 결과
                        _buildDetailedAnalysis(),
                        const SizedBox(height: 24),
                        
                        // 녹음 버튼
                        _buildPremiumRecordingButton(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 상단: 세로 음계 스케일 위젯
  Widget _buildVerticalPitchScale() {
    return VerticalPitchScaleWidget(
      pitchData: _pitchDataPoints,
      width: double.infinity,
      height: double.infinity,
      primaryColor: _primaryColor,
      backgroundColor: const Color(0xFFF5F5F7),
    );
  }

  /// 하단: 분석 결과 헤더
  Widget _buildAnalysisResultHeader() {
    final result = widget.analysisResult;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor.withOpacity(0.2),
            _secondaryColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // AI 분석 아이콘
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.analytics,
              color: _primaryColor,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 분석 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 보컬 분석 결과',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result != null 
                    ? 'CREPE + SPICE 듀얼 엔진으로 분석 완료'
                    : '분석 대기 중...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1D1D1F).withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          
          // 분석 상태 표시
          if (_isPitchAnalysisComplete) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF34C759),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '분석 완료',
                    style: TextStyle(
                      color: Color(0xFF34C759),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
              ),
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오비완 v2 보컬 트레이너',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1D1D1F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CREPE + SPICE 듀얼 AI 엔진',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1D1D1F).withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isRecording 
                  ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                  : [_accentColor, const Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (_isRecording ? const Color(0xFFEF4444) : _accentColor)
                      .withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isRecording ? Icons.fiber_manual_record : Icons.check_circle,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _isRecording ? 'RECORDING' : 'READY',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumRecordingButton() {
    return Container(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        onPressed: _isInitialized ? (_isRecording ? _stopRecording : _startRecording) : null,
        icon: Icon(
          _isRecording ? Icons.stop : Icons.mic,
          color: Colors.white,
        ),
        label: Text(
          _isRecording ? '녹음 중지' : '보컬 트레이닝 시작',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isRecording ? const Color(0xFFEF4444) : _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          elevation: 4,
        ),
      ),
    );
  }
  
  /// AI 분석 결과 시각화
  Widget _buildAnalysisVisualization() {
    final result = widget.analysisResult;
    
    if (result == null) {
      return Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withOpacity(0.3),
          border: Border.all(color: Colors.grey, width: 2),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.white70),
              SizedBox(height: 12),
              Text(
                '분석 결과 없음',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 피치를 노트로 변환
    final noteName = _frequencyToNoteName(result.frequency);
    final confidence = result.confidence;
    final quality = result.analysisQuality;
    
    // 분석 품질에 따른 색상 결정
    Color qualityColor = _primaryColor;
    if (quality > 0.8) {
      qualityColor = const Color(0xFF34C759); // 녹색 - 뛰어남
    } else if (quality > 0.6) {
      qualityColor = const Color(0xFF007AFF); // 파랑 - 양호
    } else if (quality > 0.4) {
      qualityColor = const Color(0xFFFF9500); // 주황 - 보통
    } else {
      qualityColor = const Color(0xFFFF3B30); // 빨강 - 개선 필요
    }
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // 외부 원 (분석 품질 표시)
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: qualityColor.withOpacity(0.3),
              width: 4,
            ),
          ),
        ),
        
        // 메인 원 (피치 정보)
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: qualityColor.withOpacity(0.2),
            border: Border.all(color: qualityColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: qualityColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${result.frequency.toStringAsFixed(1)} Hz',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                noteName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: qualityColor,
                ),
              ),
              const SizedBox(height: 12),
              // 엔진 표시
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: qualityColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  result.recommendedEngine,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: qualityColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 신뢰도 인디케이터
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(confidence * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  /// 상세 분석 결과
  Widget _buildDetailedAnalysis() {
    final result = widget.analysisResult;
    
    if (result == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.analytics_outlined, size: 48, color: Color(0xFF1D1D1F).withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              '분석 데이터가 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF1D1D1F).withOpacity(0.7),
              ),
            ),
            Text(
              '녹음 후 AI 분석을 통해 상세한 보컬 피드백을 받아보세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF1D1D1F).withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }
    
    final quality = result.analysisQuality;
    String qualityText = '개선 필요';
    String feedback = '더 안정적인 발성을 연습해보세요';
    
    if (quality > 0.8) {
      qualityText = '뛰어남';
      feedback = '매우 안정적인 발성입니다! 계속 유지하세요';
    } else if (quality > 0.6) {
      qualityText = '양호';
      feedback = '좋은 발성입니다. 조금 더 연습하면 완벽해질 것 같아요';
    } else if (quality > 0.4) {
      qualityText = '보통';
      feedback = '기본기는 있습니다. 호흡과 발성을 더 연습해보세요';
    }
    
    return Column(
      children: [
        // 전체적인 평가 카드
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primaryColor.withOpacity(0.2),
                _secondaryColor.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assessment, color: _primaryColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'CREPE + SPICE 듀얼 엔진 분석',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAnalysisMetric('분석 품질', qualityText, quality),
                  _buildAnalysisMetric('신뢰도', '${(result.confidence * 100).toStringAsFixed(0)}%', result.confidence),
                  _buildAnalysisMetric('추천 엔진', result.recommendedEngine, 1.0),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feedback,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1D1D1F).withOpacity(0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 시간별 피치 그래프
        _buildPitchGraphSection(),
        
        const SizedBox(height: 16),
        
        // 개별 엔진 결과 (있는 경우만)
        if (result.crepeResult != null || result.spiceResult != null) ...[
          Row(
            children: [
              if (result.crepeResult != null) ...[
                Expanded(child: _buildEngineCard('CREPE', result.crepeResult!)),
                const SizedBox(width: 12),
              ],
              if (result.spiceResult != null)
                Expanded(child: _buildEngineCard('SPICE', result.spiceResult!)),
            ],
          ),
        ],
      ],
    );
  }
  
  Widget _buildAnalysisMetric(String label, String value, double score) {
    Color color = Colors.grey;
    if (score > 0.8) color = const Color(0xFF34C759);
    else if (score > 0.6) color = const Color(0xFF007AFF);
    else if (score > 0.4) color = const Color(0xFFFF9500);
    else color = const Color(0xFFFF3B30);
    
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF1D1D1F).withOpacity(0.6),
          ),
        ),
      ],
    );
  }
  
  Widget _buildEngineCard(String engineName, dynamic result) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            engineName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.frequency?.toStringAsFixed(1) ?? '---'} Hz',
            style: TextStyle(
              fontSize: 12,
              color: _primaryColor,
            ),
          ),
          Text(
            '${((result.confidence ?? 0) * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF1D1D1F).withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
  
  String _frequencyToNoteName(double frequency) {
    if (frequency < 80) return '---';
    
    final notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final a4 = 440.0;
    final c0 = a4 * math.pow(2, -4.75); // C0 frequency
    
    if (frequency <= c0) return '---';
    
    final h = 12 * (math.log(frequency / c0) / math.ln2);
    final octave = (h / 12).floor();
    final noteIndex = (h % 12).round() % 12;
    
    return '${notes[noteIndex]}${octave}';
  }
  
  /// 피치 그래프 섹션
  Widget _buildPitchGraphSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 피치 그래프 헤더
        Row(
          children: [
            Icon(Icons.show_chart, color: _primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              '시간별 피치 분석',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            const Spacer(),
            if (_isPitchAnalysisComplete) ...[
              Icon(Icons.check_circle, color: const Color(0xFF34C759), size: 16),
              const SizedBox(width: 4),
              Text(
                '완료',
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF34C759),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 4),
              Text(
                '분석 중...',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1D1D1F).withOpacity(0.6),
                ),
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 16),
        
        // 피치 그래프
        if (_isPitchAnalysisComplete && _pitchDataPoints.isNotEmpty) ...[
          PitchGraphWidget(
            pitchData: _pitchDataPoints,
            width: double.infinity,
            height: 180,
            primaryColor: _primaryColor,
            backgroundColor: const Color(0xFFF8F9FA),
          ),
          
          const SizedBox(height: 12),
          
          // 비브라토 정보
          if (_vibratoData != null && _vibratoData!.isPresent) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9500).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFF9500).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq, color: Color(0xFFFF9500), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '비브라토 감지됨 - 속도: ${_vibratoData!.rate.toStringAsFixed(1)}Hz, 깊이: ${_vibratoData!.depth.toStringAsFixed(0)} cents',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF9500),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
        ] else if (!_isPitchAnalysisComplete) ...[
          // 로딩 상태
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    '시간별 피치 분석 중...',
                    style: TextStyle(
                      color: _primaryColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '오디오 데이터를 분석하여 피치 변화를 추출하고 있습니다',
                    style: TextStyle(
                      color: Color(0xFF1D1D1F).withOpacity(0.6),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          // 데이터 없음
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 48, color: Color(0xFF1D1D1F).withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Text(
                    '피치 데이터를 분석할 수 없습니다',
                    style: TextStyle(
                      color: Color(0xFF1D1D1F).withOpacity(0.6),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '더 길고 안정적인 음성 녹음이 필요합니다',
                    style: TextStyle(
                      color: Color(0xFF1D1D1F).withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  /// CREPE/SPICE 기반 피치 분석 시작
  void _startPitchAnalysis() async {
    print('🎵 [DualEngine] CREPE+SPICE 시간별 피치 분석 시작...');
    
    try {
      final audioData = widget.audioData;
      if (audioData.isEmpty) {
        print('⚠️ [DualEngine] 오디오 데이터가 비어있음');
        return;
      }
      
      // 비동기적으로 CREPE+SPICE 분석 실행
      Future.delayed(Duration.zero, () async {
        final dualService = DualEngineService();
        final Float32List audioFloat32 = Float32List.fromList(audioData);
        
        // CREPE + SPICE 시간별 분석 (hop size 늘려서 빠르게)
        final dualResults = await dualService.analyzeTimeBasedPitch(
          audioFloat32,
          windowSize: 4096,  // 더 큰 윈도우
          hopSize: 2048,     // 더 큰 hop (적은 분석 횟수)
        );
        
        if (mounted && dualResults.isNotEmpty) {
          // DualResult를 PitchDataPoint로 변환
          final pitchPoints = dualResults.map((result) {
            return PitchDataPoint(
              timeSeconds: result.timeSeconds ?? 0.0,
              frequency: result.frequency,
              confidence: result.confidence,
              amplitude: 0.5, // RMS는 별도 계산 필요시 추가
              noteName: _frequencyToNoteName(result.frequency),
              isStable: result.confidence > 0.6,
            );
          }).toList();
          
          // 비브라토는 로컬 분석 유지 (CREPE/SPICE에서 제공하지 않음)
          final vibratoData = PitchAnalysisService.analyzeVibrato(pitchPoints);
          
          setState(() {
            _pitchDataPoints = pitchPoints;
            _vibratoData = vibratoData;
            _isPitchAnalysisComplete = true;
          });
          
          print('✅ [DualEngine] CREPE+SPICE 피치 분석 완료: ${pitchPoints.length}개 포인트');
          
          if (vibratoData.isPresent) {
            print('🎼 [DualEngine] 비브라토 감지됨 - 속도: ${vibratoData.rate.toStringAsFixed(1)}Hz, 깊이: ${vibratoData.depth.toStringAsFixed(1)} cents');
          }
        } else {
          print('❌ [DualEngine] 분석 결과 없음');
        }
      });
      
    } catch (e) {
      print('❌ [DualEngine] 피치 분석 실패: $e');
    }
  }
}