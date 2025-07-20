import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'web_audio_capture_service.dart' if (dart.library.io) 'dummy_audio_capture_service.dart';

class AudioCaptureService {
  static const int sampleRate = 44100;
  static const int bufferSize = 1024;
  
  StreamController<List<double>>? _audioStreamController;
  Timer? _dummyTimer;
  bool _isInitialized = false;
  bool _isRecording = false;
  
  // Platform-specific audio capture service
  late final dynamic _platformService;
  
  Stream<List<double>> get audioStream {
    if (kIsWeb) {
      // Use real web audio capture
      return (_platformService as WebAudioCaptureService).audioStream;
    }
    // Fallback to dummy audio
    _audioStreamController ??= StreamController<List<double>>.broadcast();
    return _audioStreamController!.stream;
  }
  
  AudioCaptureService() {
    if (kIsWeb) {
      _platformService = WebAudioCaptureService();
    }
  }
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      if (kIsWeb) {
        // Use real web audio
        await (_platformService as WebAudioCaptureService).initialize();
        print('Web audio capture initialized');
      } else {
        // Dummy mode for other platforms
        print('Audio capture service initialized (dummy mode)');
      }
      _isInitialized = true;
    } catch (e) {
      print('Audio initialization failed: $e');
      // Fallback to dummy mode
      _isInitialized = true;
    }
  }
  
  Future<void> startCapture() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isRecording) return;
    
    _isRecording = true;
    
    if (kIsWeb) {
      // Use real web audio capture
      await (_platformService as WebAudioCaptureService).startCapture();
      print('Web audio capture started');
    } else {
      // 더미 오디오 데이터 생성
      _dummyTimer = Timer.periodic(
        const Duration(milliseconds: 23), // ~44.1kHz용 타이밍
        (_) => _generateDummyAudio(),
      );
      print('Audio capture started (dummy mode)');
    }
  }
  
  Future<void> stopCapture() async {
    if (!_isRecording) return;
    
    _isRecording = false;
    
    if (kIsWeb) {
      await (_platformService as WebAudioCaptureService).stopCapture();
    } else {
      _dummyTimer?.cancel();
    }
    print('Audio capture stopped');
  }
  
  Future<void> dispose() async {
    await stopCapture();
    
    if (kIsWeb) {
      (_platformService as WebAudioCaptureService).dispose();
    } else {
      await _audioStreamController?.close();
    }
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