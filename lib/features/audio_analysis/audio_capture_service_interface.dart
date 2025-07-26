import 'dart:async';

/// Common interface for audio capture services
abstract class AudioCaptureServiceInterface {
  Stream<List<double>> get audioStream;
  
  Future<void> initialize();
  Future<void> startCapture();
  Future<void> stopCapture();
  void dispose();
}