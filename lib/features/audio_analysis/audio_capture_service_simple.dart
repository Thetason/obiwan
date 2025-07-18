import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioCaptureService {
  static const int sampleRate = 16000;
  static const int bufferSize = 1024;
  
  StreamController<List<double>>? _audioStreamController;
  Timer? _dummyTimer;
  bool _isInitialized = false;
  bool _isRecording = false;
  
  Stream<List<double>> get audioStream {
    _audioStreamController ??= StreamController<List<double>>.broadcast();
    return _audioStreamController!.stream;
  }
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // 권한 요청
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw AudioCaptureException('Microphone permission denied');
    }
    
    _isInitialized = true;
  }
  
  Future<void> startCapture() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isRecording) return;
    
    _isRecording = true;
    
    // 더미 오디오 데이터 생성 (실제 구현에서는 flutter_sound 사용)
    _dummyTimer = Timer.periodic(
      const Duration(milliseconds: 64), // 16ms for 1024 samples at 16kHz
      (_) => _generateDummyAudio(),
    );
  }
  
  Future<void> stopCapture() async {
    if (!_isRecording) return;
    
    _isRecording = false;
    _dummyTimer?.cancel();
  }
  
  Future<void> dispose() async {
    await stopCapture();
    await _audioStreamController?.close();
    _isInitialized = false;
  }
  
  void _generateDummyAudio() {
    // 더미 오디오 데이터 생성 (사인파 + 노이즈)
    final samples = <double>[];
    final random = math.Random();
    
    for (int i = 0; i < bufferSize; i++) {
      final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final frequency = 440.0; // A4
      final sample = math.sin(2 * math.pi * frequency * time * i / sampleRate) * 0.5 +
                    (random.nextDouble() - 0.5) * 0.1; // 노이즈 추가
      samples.add(sample);
    }
    
    _audioStreamController?.add(samples);
  }
  
  Future<void> testCapture(Duration duration) async {
    await startCapture();
    
    final samples = <double>[];
    final subscription = audioStream.listen((chunk) {
      samples.addAll(chunk);
    });
    
    await Future.delayed(duration);
    
    await stopCapture();
    await subscription.cancel();
    
    print('Captured ${samples.length} samples in ${duration.inSeconds} seconds');
    print('Average sample rate: ${samples.length / duration.inSeconds}');
  }
}

class AudioCaptureException implements Exception {
  final String message;
  AudioCaptureException(this.message);
  
  @override
  String toString() => 'AudioCaptureException: $message';
}