import 'dart:async';
import 'audio_backend_interface.dart';

class UnsupportedAudioBackend implements AudioBackend {
  final StreamController<Map<String, double>> _controller =
      StreamController<Map<String, double>>.broadcast();

  @override
  Stream<Map<String, double>> get audioLevelStream => _controller.stream;

  @override
  Future<AudioServiceStatus> initialize() async {
    return const AudioServiceStatus.unsupported(
      message: '해당 플랫폼에서는 네이티브 녹음이 지원되지 않습니다.',
    );
  }

  @override
  Future<AudioServiceStatus> requestPermissions() async {
    return const AudioServiceStatus.unsupported(
      message: '마이크 권한 요청이 지원되지 않습니다.',
    );
  }

  @override
  Future<bool> startRecording() async => false;

  @override
  Future<bool> stopRecording() async => false;

  @override
  Future<AudioCaptureResult?> fetchRecordedAudio() async => null;

  @override
  Future<Map<String, dynamic>> describeSystem() async {
    return {
      'supported': false,
      'backend': 'unsupported',
      'reason': 'No audio backend available',
    };
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

AudioBackend createBackend() => UnsupportedAudioBackend();
