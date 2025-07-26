import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_capture_service_interface.dart';

/// Stub implementation for non-web platforms
class WebAudioCaptureService implements AudioCaptureServiceInterface {
  final StreamController<List<double>> _audioStreamController = StreamController<List<double>>.broadcast();
  
  @override
  Stream<List<double>> get audioStream => _audioStreamController.stream;
  
  bool _isInitialized = false;
  bool _isCapturing = false;
  
  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (kDebugMode) {
      debugPrint('[WebAudioCapture] Stub implementation - initialize called');
    }
    
    _isInitialized = true;
  }
  
  @override
  Future<void> startCapture() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isCapturing) return;
    
    _isCapturing = true;
    
    if (kDebugMode) {
      debugPrint('[WebAudioCapture] Stub implementation - capture started');
    }
    
    // Simulate audio data for testing
    Timer.periodic(const Duration(milliseconds: 64), (timer) {
      if (!_isCapturing) {
        timer.cancel();
        return;
      }
      
      // Generate placeholder audio data (silent)
      final samples = List<double>.filled(1024, 0.0);
      _audioStreamController.add(samples);
    });
  }
  
  @override
  Future<void> stopCapture() async {
    if (!_isCapturing) return;
    
    _isCapturing = false;
    
    if (kDebugMode) {
      debugPrint('[WebAudioCapture] Stub implementation - capture stopped');
    }
  }
  
  @override
  void dispose() {
    stopCapture();
    _audioStreamController.close();
    
    if (kDebugMode) {
      debugPrint('[WebAudioCapture] Stub implementation - disposed');
    }
  }
}