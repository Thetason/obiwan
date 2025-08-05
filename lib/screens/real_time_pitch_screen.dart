import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../services/official_crepe_service.dart';

class RealTimePitchScreen extends StatefulWidget {
  const RealTimePitchScreen({Key? key}) : super(key: key);

  @override
  State<RealTimePitchScreen> createState() => _RealTimePitchScreenState();
}

class _RealTimePitchScreenState extends State<RealTimePitchScreen> {
  FlutterSoundRecorder? _recorder;
  OfficialCrepeService? _crepeService;
  RealtimeCrepeStream? _crepeStream;
  StreamController<Food>? _recordingDataController;
  
  bool _isRecording = false;
  bool _isInitialized = false;
  double _currentPitch = 0.0;
  double _currentConfidence = 0.0;
  double _targetPitch = 440.0; // A4
  String _feedback = "녹음을 시작하세요";
  
  CrepeAnalysisResult? _lastResult;
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
      
      // CREPE 서비스 초기화
      _crepeService = OfficialCrepeService();
      _crepeStream = RealtimeCrepeStream();
      
      // 서버 상태 확인
      final serverStatus = await _crepeService!.checkServerHealth();
      if (serverStatus == null || !serverStatus.isHealthy) {
        throw Exception('CREPE 서버에 연결할 수 없습니다');
      }
      
      // 실시간 스트림 설정
      _crepeStream!.stream.listen(_onCrepeResult);
      
      setState(() {
        _isInitialized = true;
        _feedback = "준비 완료! 🎤를 눌러 녹음을 시작하세요";
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
  
  void _onCrepeResult(CrepeAnalysisResult result) {
    setState(() {
      _lastResult = result;
      _currentPitch = result.mainPitch;
      _currentConfidence = result.overallConfidence;
      
      // 피치 히스토리 업데이트
      _pitchHistory.add(_currentPitch);
      if (_pitchHistory.length > 50) {
        _pitchHistory.removeAt(0);
      }
      
      // 피드백 생성
      if (_currentPitch > 0) {
        _feedback = CrepeVocalFeedback.getPitchAccuracyFeedback(
          _targetPitch, 
          _currentPitch, 
          _currentConfidence
        );
      } else {
        _feedback = "목소리가 감지되지 않았어요 🎤";
      }
    });
  }
  
  Future<void> _startRecording() async {
    if (!_isInitialized || _isRecording) return;
    
    try {
      _recordingDataController = StreamController<Food>();
      
      // 실시간 스트림 시작
      _crepeStream!.startStream();
      
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
            _crepeStream!.addAudioChunk(audioData);
          }
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
      _crepeStream!.stopStream();
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
      // PCM16 -> Float32 변환
      final int16Data = Int16List.view(buffer.buffer);
      final float32Data = Float32List(int16Data.length);
      
      for (int i = 0; i < int16Data.length; i++) {
        float32Data[i] = int16Data[i] / 32768.0; // 정규화
      }
      
      return float32Data;
    } catch (e) {
      debugPrint('Audio buffer processing failed: $e');
      return null;
    }
  }
  
  @override
  void dispose() {
    _recorder?.closeRecorder();
    _crepeStream?.dispose();
    _recordingDataController?.close();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('실시간 피치 분석'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 서버 상태 표시
            Card(
              child: ListTile(
                leading: Icon(
                  _isInitialized ? Icons.check_circle : Icons.error,
                  color: _isInitialized ? Colors.green : Colors.red,
                ),
                title: Text(_isInitialized ? 'CREPE 서버 연결됨' : '서버 연결 중...'),
                subtitle: Text(_isInitialized ? 'Official CREPE v0.0.16' : '초기화 중'),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 타겟 피치 설정
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('목표 음정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
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
            
            const SizedBox(height: 20),
            
            // 현재 피치 표시
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('현재 피치', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 피드백 메시지
            Card(
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.feedback, size: 40, color: Colors.deepPurple),
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
                      const Text('CREPE 분석 결과:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('모델: ${_lastResult!.parameters.model}'),
                      Text('처리 시간: ${_lastResult!.parameters.inferenceTimeMs.toStringAsFixed(1)}ms'),
                      Text('피치 안정성: ${_lastResult!.stability.toStringAsFixed(1)}%'),
                      Text('발성 비율: ${(_lastResult!.voicedRatio * 100).toStringAsFixed(1)}%'),
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