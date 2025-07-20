import 'dart:async';

/// Dummy audio capture service for non-web platforms
class WebAudioCaptureService {
  final StreamController<List<double>> _audioStreamController = StreamController<List<double>>.broadcast();
  Stream<List<double>> get audioStream => _audioStreamController.stream;
  
  Future<void> initialize() async {}
  Future<void> startCapture() async {}
  Future<void> stopCapture() async {}
  void dispose() {
    _audioStreamController.close();
  }
}