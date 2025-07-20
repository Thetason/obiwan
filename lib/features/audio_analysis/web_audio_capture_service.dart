import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

/// Real Web Audio Capture Service using JavaScript interop
class WebAudioCaptureService {
  final StreamController<List<double>> _audioStreamController = StreamController<List<double>>.broadcast();
  final StreamController<double> _pitchStreamController = StreamController<double>.broadcast();
  
  Stream<List<double>> get audioStream => _audioStreamController.stream;
  Stream<double> get pitchStream => _pitchStreamController.stream;
  
  bool _isInitialized = false;
  bool _isCapturing = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize JavaScript audio capture
      final result = await js.context.callMethod('eval', [
        'window.audioCapture.initialize()'
      ]);
      
      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 500));
      
      _isInitialized = true;
      debugPrint('Web audio capture initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize web audio capture: $e');
      throw Exception('Failed to initialize audio capture: $e');
    }
  }

  Future<void> startCapture() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isCapturing) return;
    
    try {
      // Set up callback from JavaScript
      js.context['flutterAudioCallback'] = (js.JsObject data) {
        final samples = List<double>.from(data['samples']);
        final frequency = data['frequency'] as num;
        
        // Send audio samples
        if (!_audioStreamController.isClosed) {
          _audioStreamController.add(samples);
        }
        
        // Send pitch data
        if (!_pitchStreamController.isClosed && frequency > 0) {
          _pitchStreamController.add(frequency.toDouble());
        }
      };
      
      // Start recording with callback
      js.context.callMethod('eval', [
        'window.audioCapture.startRecording(window.flutterAudioCallback)'
      ]);
      
      _isCapturing = true;
      debugPrint('Web audio capture started');
    } catch (e) {
      debugPrint('Failed to start web audio capture: $e');
      throw Exception('Failed to start audio capture: $e');
    }
  }

  Future<void> stopCapture() async {
    if (!_isCapturing) return;
    
    try {
      js.context.callMethod('eval', [
        'window.audioCapture.stopRecording()'
      ]);
      
      _isCapturing = false;
      debugPrint('Web audio capture stopped');
    } catch (e) {
      debugPrint('Failed to stop web audio capture: $e');
    }
  }

  void dispose() {
    stopCapture();
    
    if (_isInitialized) {
      try {
        js.context.callMethod('eval', [
          'window.audioCapture.dispose()'
        ]);
      } catch (e) {
        debugPrint('Error disposing web audio capture: $e');
      }
    }
    
    _audioStreamController.close();
    _pitchStreamController.close();
  }
}