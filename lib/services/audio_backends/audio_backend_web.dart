import 'dart:async';
import 'dart:math' as math;
import 'audio_backend_interface.dart';

class WebMockAudioBackend implements AudioBackend {
  final StreamController<Map<String, double>> _levelController =
      StreamController<Map<String, double>>.broadcast();
  AudioCaptureResult? _lastMockCapture;

  @override
  Stream<Map<String, double>> get audioLevelStream => _levelController.stream;

  @override
  Future<AudioServiceStatus> initialize() async {
    return const AudioServiceStatus(
      supported: true,
      initialized: true,
      permissionGranted: false,
      backendName: 'web_mock',
      message: 'Web Audio API 미구현 - 모의 캡처 사용',
    );
  }

  @override
  Future<AudioServiceStatus> requestPermissions() async {
    return const AudioServiceStatus(
      supported: true,
      initialized: true,
      permissionGranted: false,
      backendName: 'web_mock',
      message: '브라우저 마이크 권한은 UI에서 안내합니다.',
    );
  }

  @override
  Future<bool> startRecording() async {
    // 모의 데이터 생성
    final fakeSamples = List<double>.generate(44100, (index) {
      final t = index / 44100.0;
      return math.sin(2 * math.pi * 440 * t) * 0.2;
    });
    _lastMockCapture = AudioCaptureResult(
      samples: fakeSamples,
      sampleRate: 44100,
      duration: const Duration(seconds: 1),
      format: 'mock',
    );
    _levelController.add({'level': -12.0, 'rms': 0.2, 'samples': fakeSamples.length.toDouble()});
    return true;
  }

  @override
  Future<bool> stopRecording() async {
    return true;
  }

  @override
  Future<AudioCaptureResult?> fetchRecordedAudio() async {
    return _lastMockCapture;
  }

  @override
  Future<Map<String, dynamic>> describeSystem() async {
    return {
      'supported': true,
      'backend': 'web_mock',
      'message': 'Mock data only',
      'hasCapture': _lastMockCapture != null,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> dispose() async {
    await _levelController.close();
  }
}

AudioBackend createBackend() => WebMockAudioBackend();
