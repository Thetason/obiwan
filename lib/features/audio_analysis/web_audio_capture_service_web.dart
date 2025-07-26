import 'dart:async';
import 'dart:js_interop';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:js_util' as js_util;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'audio_capture_service_interface.dart';

/// Web implementation for audio capture using Web Audio API
class WebAudioCaptureService implements AudioCaptureServiceInterface {
  final StreamController<List<double>> _audioStreamController = StreamController<List<double>>.broadcast();
  
  @override
  Stream<List<double>> get audioStream => _audioStreamController.stream;
  
  bool _isInitialized = false;
  bool _isCapturing = false;
  
  // Web Audio API objects
  html.MediaStream? _mediaStream;
  dynamic _audioContext;
  dynamic _analyser;
  dynamic _microphone;
  dynamic _scriptProcessor;
  Timer? _audioProcessingTimer;
  
  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    if (kDebugMode) {
      debugPrint('[WebAudioCapture] Web implementation - initialize called');
    }
    
    try {
      await _initializeWebAudio();
      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('[WebAudioCapture] Successfully initialized Web Audio API');
      }
    } catch (e) {
      debugPrint('[WebAudioCapture] Failed to initialize: $e');
      throw Exception('Failed to initialize Web Audio API: $e');
    }
  }
  
  Future<void> _initializeWebAudio() async {
    try {
      // Request microphone permission
      _mediaStream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': {
          'sampleRate': 16000,
          'channelCount': 1,
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        }
      });
      
      if (kDebugMode) {
        debugPrint('[WebAudioCapture] Microphone access granted');
      }
      
      // Create Audio Context
      _audioContext = js.context.hasProperty('AudioContext') 
        ? js.JsObject(js.context['AudioContext'])
        : js.JsObject(js.context['webkitAudioContext']);
      
      if (kDebugMode) {
        debugPrint('[WebAudioCapture] Audio context created');
      }
      
      // Create analyser node for audio processing
      _analyser = js_util.callMethod(_audioContext, 'createAnalyser', []);
      js_util.setProperty(_analyser, 'fftSize', 2048);
      js_util.setProperty(_analyser, 'smoothingTimeConstant', 0.8);
      
      if (kDebugMode) {
        debugPrint('[WebAudioCapture] Analyser node created');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WebAudioCapture] Error in Web Audio initialization: $e');
      }
      
      if (e.toString().contains('Permission denied') || 
          e.toString().contains('NotAllowedError')) {
        throw Exception('마이크 권한이 거부되었습니다. 브라우저에서 마이크 접근을 허용해주세요.');
      } else if (e.toString().contains('NotFoundError')) {
        throw Exception('마이크를 찾을 수 없습니다. 마이크가 연결되어 있는지 확인해주세요.');
      } else {
        throw Exception('오디오 시스템 초기화 실패: $e');
      }
    }
  }
  
  @override
  Future<void> startCapture() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isCapturing) return;
    
    _isCapturing = true;
    
    if (kDebugMode) {
      debugPrint('[WebAudioCapture] Web implementation - capture started');
    }
    
    try {
      await _startWebAudioCapture();
    } catch (e) {
      _isCapturing = false;
      debugPrint('[WebAudioCapture] Failed to start capture: $e');
      throw e;
    }
  }
  
  Future<void> _startWebAudioCapture() async {
    try {
      // Create microphone source using js_util for better compatibility
      _microphone = js_util.callMethod(_audioContext, 'createMediaStreamSource', [_mediaStream]);
      
      // Connect microphone to analyser
      js_util.callMethod(_microphone, 'connect', [_analyser]);
      
      if (kDebugMode) {
        debugPrint('[WebAudioCapture] Microphone connected to analyser');
      }
      
      // Start audio processing loop
      _startAudioProcessingLoop();
      
    } catch (e) {
      debugPrint('[WebAudioCapture] Error starting audio capture: $e');
      throw Exception('오디오 캡처 시작 실패: $e');
    }
  }
  
  void _startAudioProcessingLoop() {
    const int bufferLength = 1024; // 64ms at 16kHz
    
    _audioProcessingTimer = Timer.periodic(
      const Duration(milliseconds: 64), 
      (timer) {
        if (!_isCapturing) {
          timer.cancel();
          return;
        }
        
        try {
          // Get time domain data from analyser
          final dataArray = js.JsObject(js.context['Float32Array'], [bufferLength]);
          js_util.callMethod(_analyser, 'getFloatTimeDomainData', [dataArray]);
          
          // Convert JS Float32Array to Dart List<double>
          final samples = <double>[];
          for (int i = 0; i < bufferLength; i++) {
            final sample = dataArray[i] as double;
            samples.add(sample);
          }
          
          // Apply simple high-pass filter to remove DC offset
          final filteredSamples = _applyHighPassFilter(samples);
          
          // Send to stream
          _audioStreamController.add(filteredSamples);
          
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[WebAudioCapture] Error in audio processing loop: $e');
          }
        }
      },
    );
  }
  
  List<double> _applyHighPassFilter(List<double> samples) {
    // Simple high-pass filter to remove DC offset
    final filtered = <double>[];
    double previousSample = 0.0;
    double previousOutput = 0.0;
    const double alpha = 0.95; // Filter coefficient
    
    for (final sample in samples) {
      final output = alpha * (previousOutput + sample - previousSample);
      filtered.add(output);
      previousSample = sample;
      previousOutput = output;
    }
    
    return filtered;
  }
  
  @override
  Future<void> stopCapture() async {
    if (!_isCapturing) return;
    
    _isCapturing = false;
    
    try {
      // Stop audio processing timer
      _audioProcessingTimer?.cancel();
      _audioProcessingTimer = null;
      
      // Disconnect audio nodes
      if (_microphone != null) {
        js_util.callMethod(_microphone, 'disconnect', []);
        _microphone = null;
      }
      
      if (kDebugMode) {
        debugPrint('[WebAudioCapture] Web implementation - capture stopped');
      }
      
    } catch (e) {
      debugPrint('[WebAudioCapture] Error stopping capture: $e');
    }
  }
  
  @override
  void dispose() {
    try {
      // Stop capture first
      if (_isCapturing) {
        stopCapture();
      }
      
      // Stop media stream tracks
      if (_mediaStream != null) {
        final tracks = _mediaStream!.getTracks();
        for (final track in tracks) {
          track.stop();
        }
        _mediaStream = null;
      }
      
      // Close audio context
      if (_audioContext != null) {
        try {
          js_util.callMethod(_audioContext, 'close', []);
        } catch (e) {
          // Ignore errors when closing context
        }
        _audioContext = null;
      }
      
      // Close stream controller
      _audioStreamController.close();
      
      _isInitialized = false;
      
      if (kDebugMode) {
        debugPrint('[WebAudioCapture] Web implementation - disposed');
      }
      
    } catch (e) {
      debugPrint('[WebAudioCapture] Error in dispose: $e');
    }
  }
}