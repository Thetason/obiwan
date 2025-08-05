import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../services/dual_engine_service.dart';

class DualEnginePitchScreen extends StatefulWidget {
  const DualEnginePitchScreen({Key? key}) : super(key: key);

  @override
  State<DualEnginePitchScreen> createState() => _DualEnginePitchScreenState();
}

class _DualEnginePitchScreenState extends State<DualEnginePitchScreen> {
  FlutterSoundRecorder? _recorder;
  DualEngineService? _dualEngine;
  RealtimeDualStream? _dualStream;
  StreamController<Food>? _recordingDataController;
  
  bool _isRecording = false;
  bool _isInitialized = false;
  DualEngineStatus? _engineStatus;
  
  // 분석 결과
  DualAnalysisResult? _lastResult;
  double _currentPitch = 0.0;
  double _currentConfidence = 0.0;
  double _targetPitch = 440.0; // A4
  String _feedback = "초기화 중...";
  
  // 분석 모드
  AnalysisMode _analysisMode = AnalysisMode.auto;
  
  // 피치 히스토리
  List<double> _pitchHistory = [];
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    try {
      // 권한 요청
      await _requestPermissions();
      
      // Flutter Sound 초기화
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();
      
      // 듀얼 엔진 서비스 초기화
      _dualEngine = DualEngineService();
      _dualStream = RealtimeDualStream();
      
      // 서버 상태 확인
      _engineStatus = await _dualEngine!.checkEngineStatus();
      
      if (!_engineStatus!.anyHealthy) {
        throw Exception('CREPE 또는 SPICE 서버에 연결할 수 없습니다');
      }
      
      // 실시간 스트림 설정
      _dualStream!.stream.listen(_onDualResult);
      
      setState(() {
        _isInitialized = true;
        _feedback = "준비 완료! 🎤를 눌러 녹음을 시작하세요\n"
                  "${_engineStatus!.statusText}";
      });
      
    } catch (e) {
      setState(() {
        _feedback = "초기화 실패: $e";
      });
    }
  }
  
  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('마이크 권한이 필요합니다');
    }
  }
  
  void _onDualResult(DualAnalysisResult result) {
    setState(() {
      _lastResult = result;
      _currentPitch = result.bestPitch;
      _currentConfidence = result.bestConfidence;
      
      // 피치 히스토리 업데이트
      _pitchHistory.add(_currentPitch);
      if (_pitchHistory.length > 100) {
        _pitchHistory.removeAt(0);
      }
      
      // 피드백 생성
      _feedback = _generateDualFeedback(result);
    });
  }
  
  String _generateDualFeedback(DualAnalysisResult result) {
    if (result.bestPitch <= 0) {
      return "목소리가 감지되지 않았어요 🎤";
    }
    
    if (result.isChord) {
      final pitchCount = result.detectedPitches.length;
      final chordText = _getChordName(result.detectedPitches);
      return "화음 감지! 🎵\n$chordText ($pitchCount개 음성)";
    } else {
      // 단일음 피드백
      final cents = 1200 * (result.bestPitch / _targetPitch).clamp(0.1, 10.0).log() / (2.log());
      final absCents = cents.abs();
      
      if (absCents < 5) {
        return "완벽합니다! 🎯 (${cents.toStringAsFixed(1)} cents)";
      } else if (absCents < 20) {
        return cents > 0 
            ? "조금 높아요 ⬇️ (+${cents.toStringAsFixed(1)} cents)"
            : "조금 낮아요 ⬆️ (${cents.toStringAsFixed(1)} cents)";
      } else {
        return cents > 0 
            ? "많이 높아요 🔻 (+${cents.toStringAsFixed(1)} cents)"
            : "많이 낮아요 🔺 (${cents.toStringAsFixed(1)} cents)";
      }
    }
  }
  
  String _getChordName(List<MultiplePitch> pitches) {
    if (pitches.length < 2) return "단일음";
    if (pitches.length == 2) return "2성 화음";
    if (pitches.length == 3) return "3성 화음";
    return "${pitches.length}성 화음";
  }
  
  Future<void> _startRecording() async {
    if (!_isInitialized || _isRecording) return;
    
    try {
      _recordingDataController = StreamController<Food>();
      
      // 실시간 스트림 시작
      _dualStream!.startStream(mode: _analysisMode);
      
      await _recorder!.startRecorder(
        toStream: _recordingDataController!.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
      );
      
      // 오디오 데이터 처리
      _recordingDataController!.stream.listen((buffer) {
        if (buffer is FoodData) {
          final audioData = _processAudioBuffer(buffer.data!);
          if (audioData != null) {
            _dualStream!.addAudioChunk(audioData);
          }
        }
      });
      
      setState(() {
        _isRecording = true;
        _feedback = "녹음 중... 소리를 내보세요! 🎵\n모드: ${_getModeText(_analysisMode)}";
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
      _dualStream!.stopStream();
      await _recordingDataController?.close();
      _recordingDataController = null;
      
      setState(() {
        _isRecording = false;
        _feedback = "녹음 중지됨. 다시 시작하려면 🎤를 누르세요";
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
  
  String _getModeText(AnalysisMode mode) {
    switch (mode) {
      case AnalysisMode.auto:
        return "자동 (스마트 선택)";
      case AnalysisMode.crepe:
        return "CREPE (단일음 최적화)";
      case AnalysisMode.spice:
        return "SPICE (화음 분석)";
      case AnalysisMode.both:
        return "듀얼 (두 엔진 동시)";
    }
  }
  
  @override
  void dispose() {
    _recorder?.closeRecorder();
    _dualStream?.dispose();
    _recordingDataController?.close();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('듀얼 엔진 피치 분석'),
        backgroundColor: Colors.deepPurple,
        actions: [
          PopupMenuButton<AnalysisMode>(
            icon: const Icon(Icons.settings),
            onSelected: (mode) {
              setState(() {
                _analysisMode = mode;
                _dualStream?.setAnalysisMode(mode);
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: AnalysisMode.auto,
                child: Text('🎯 자동 모드'),
              ),
              const PopupMenuItem(
                value: AnalysisMode.crepe,
                child: Text('🎵 CREPE 모드'),
              ),
              const PopupMenuItem(
                value: AnalysisMode.spice,
                child: Text('🎼 SPICE 모드'),
              ),
              const PopupMenuItem(
                value: AnalysisMode.both,
                child: Text('⚡ 듀얼 모드'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 엔진 상태 표시
            if (_engineStatus != null)
              Card(
                color: _engineStatus!.bothHealthy ? Colors.green[50] : Colors.orange[50],
                child: ListTile(
                  leading: Icon(
                    _engineStatus!.bothHealthy ? Icons.check_circle : Icons.warning,
                    color: _engineStatus!.bothHealthy ? Colors.green : Colors.orange,
                  ),
                  title: Text(_engineStatus!.statusText),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _engineStatus!.crepeHealthy ? Icons.check : Icons.close,
                            size: 16,
                            color: _engineStatus!.crepeHealthy ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          const Text('CREPE'),
                          const SizedBox(width: 20),
                          Icon(
                            _engineStatus!.spiceHealthy ? Icons.check : Icons.close,
                            size: 16,
                            color: _engineStatus!.spiceHealthy ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          const Text('SPICE'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // 분석 모드 표시
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.blue),
                    const SizedBox(width: 10),
                    Text(
                      '분석 모드: ${_getModeText(_analysisMode)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 현재 피치 표시
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('감지된 피치', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(
                      '${_currentPitch.toStringAsFixed(1)} Hz',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '신뢰도: ${(_currentConfidence * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 16,
                        color: _currentConfidence > 0.7 ? Colors.green : Colors.orange,
                      ),
                    ),
                    
                    // 다중 피치 표시
                    if (_lastResult?.isChord == true) ...[
                      const SizedBox(height: 10),
                      const Text('감지된 화음:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...(_lastResult!.detectedPitches.take(3).map((pitch) => 
                        Text('${pitch.frequency.toStringAsFixed(1)}Hz (${(pitch.strength * 100).toStringAsFixed(0)}%)')
                      )),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 목표 피치 설정
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('목표 음정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _targetPitch,
                            min: 80.0,
                            max: 800.0,
                            divisions: 100,
                            label: '${_targetPitch.toStringAsFixed(1)}Hz',
                            onChanged: (value) {
                              setState(() {
                                _targetPitch = value;
                              });
                            },
                          ),
                        ),
                        Text('${_targetPitch.toStringAsFixed(1)}Hz'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 피드백 메시지
            Card(
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _lastResult?.isChord == true ? Icons.queue_music : Icons.music_note,
                      size: 40,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _feedback,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            // 녹음 버튼
            FloatingActionButton.large(
              onPressed: _isInitialized ? (_isRecording ? _stopRecording : _startRecording) : null,
              backgroundColor: _isRecording ? Colors.red : Colors.deepPurple,
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                size: 40,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 디버그 정보 (개발 모드에서만)
            if (_lastResult != null && kDebugMode)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('듀얼 엔진 분석 결과:', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (_lastResult!.crepeResult != null)
                        Text('CREPE: ${_lastResult!.crepeResult!.mainPitch.toStringAsFixed(1)}Hz'),
                      if (_lastResult!.spiceResult != null)
                        Text('SPICE: ${_lastResult!.spiceResult!.mainPitch.toStringAsFixed(1)}Hz (${_lastResult!.spiceResult!.multiplePitches.length}음)'),
                      if (_lastResult!.fusedResult != null)
                        Text('융합: ${_lastResult!.fusedResult!.primaryPitch.toStringAsFixed(1)}Hz, 품질: ${(_lastResult!.fusedResult!.analysisQuality * 100).toStringAsFixed(1)}%'),
                      Text('분석 타입: ${_lastResult!.analysisTypeText}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}