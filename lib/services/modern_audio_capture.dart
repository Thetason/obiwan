import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// 최신 Web Audio API를 사용한 고성능 오디오 캡처
/// ScriptProcessor 대신 AudioWorklet 사용
class ModernAudioCapture {
  html.MediaStream? _mediaStream;
  html.AudioContext? _audioContext;
  html.MediaStreamAudioSourceNode? _sourceNode;
  html.AudioWorkletNode? _workletNode;
  
  static const int _sampleRate = 16000;
  static const int _bufferSize = 1024;
  
  final StreamController<Float32List> _audioController = 
      StreamController<Float32List>.broadcast();
  
  Stream<Float32List> get audioStream => _audioController.stream;
  
  bool _isRecording = false;
  bool get isRecording => _isRecording;
  
  /// 오디오 캡처 초기화 및 시작
  Future<bool> startCapture() async {
    if (_isRecording) return true;
    
    try {
      // 1. 마이크 권한 요청
      _mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': {
          'sampleRate': _sampleRate,
          'channelCount': 1,
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        }
      });
      
      if (_mediaStream == null) {
        debugPrint('Failed to get media stream');
        return false;
      }
      
      // 2. AudioContext 생성
      _audioContext = html.AudioContext();
      
      // Safari/older browsers 호환성
      if (_audioContext!.sampleRate != _sampleRate) {
        debugPrint('Sample rate mismatch: ${_audioContext!.sampleRate} vs $_sampleRate');
      }
      
      // 3. AudioWorklet 지원 확인 및 폴백
      if (_supportsAudioWorklet()) {
        return await _setupAudioWorklet();
      } else {
        return await _setupScriptProcessor(); // 폴백
      }
      
    } catch (e) {
      debugPrint('Failed to start audio capture: $e');
      return false;
    }
  }
  
  /// AudioWorklet 지원 여부 확인
  bool _supportsAudioWorklet() {
    try {
      return js_util.hasProperty(_audioContext!, 'audioWorklet');
    } catch (e) {
      return false;
    }
  }
  
  /// AudioWorklet 설정 (최신 방식)
  Future<bool> _setupAudioWorklet() async {
    try {
      // AudioWorklet 프로세서 등록
      const workletCode = '''
        class VocalAnalysisProcessor extends AudioWorkletProcessor {
          constructor() {
            super();
            this.bufferSize = 1024;
            this.buffer = new Float32Array(this.bufferSize);
            this.bufferIndex = 0;
          }
          
          process(inputs, outputs, parameters) {
            const input = inputs[0][0]; // 첫 번째 입력의 첫 번째 채널
            
            if (!input) return true;
            
            for (let i = 0; i < input.length; i++) {
              this.buffer[this.bufferIndex] = input[i];
              this.bufferIndex++;
              
              if (this.bufferIndex >= this.bufferSize) {
                // 버퍼가 가득 차면 메인 스레드로 전송
                this.port.postMessage({
                  type: 'audioData',
                  data: Array.from(this.buffer)
                });
                this.bufferIndex = 0;
              }
            }
            
            return true;
          }
        }
        
        registerProcessor('vocal-analysis-processor', VocalAnalysisProcessor);
      ''';
      
      // Blob URL로 워클릿 생성
      final blob = html.Blob([workletCode], 'application/javascript');
      final workletUrl = html.Url.createObjectUrl(blob);
      
      // 워클릿 모듈 추가
      await js_util.promiseToFuture(
        js_util.callMethod(_audioContext!.audioWorklet, 'addModule', [workletUrl])
      );
      
      // AudioWorkletNode 생성
      _workletNode = html.AudioWorkletNode(_audioContext!, 'vocal-analysis-processor');
      
      // 메시지 리스너 등록
      _workletNode!.addEventListener('message', (html.Event event) {
        final messageEvent = event as html.MessageEvent;
        final data = messageEvent.data;
        
        if (data['type'] == 'audioData') {
          final audioData = Float32List.fromList(
            List<double>.from(data['data']).cast<double>()
          );
          _audioController.add(audioData);
        }
      });
      
      // 오디오 파이프라인 연결
      _sourceNode = _audioContext!.createMediaStreamSource(_mediaStream!);
      _sourceNode!.connectNode(_workletNode!);
      
      _isRecording = true;
      debugPrint('AudioWorklet setup successful');
      return true;
      
    } catch (e) {
      debugPrint('AudioWorklet setup failed: $e');
      return await _setupScriptProcessor(); // 폴백
    }
  }
  
  /// ScriptProcessor 설정 (폴백 방식)
  Future<bool> _setupScriptProcessor() async {
    try {
      debugPrint('Using ScriptProcessor fallback');
      
      // ScriptProcessorNode 생성
      final scriptProcessor = _audioContext!.createScriptProcessor(_bufferSize, 1, 1);
      
      // 오디오 처리 이벤트 리스너
      scriptProcessor.addEventListener('audioprocess', (html.Event event) {
        final audioEvent = event as html.AudioProcessingEvent;
        final inputBuffer = audioEvent.inputBuffer!;
        final inputData = inputBuffer.getChannelData(0);
        
        // Float32List로 변환
        final audioData = Float32List.fromList(inputData);
        _audioController.add(audioData);
      });
      
      // 오디오 파이프라인 연결
      _sourceNode = _audioContext!.createMediaStreamSource(_mediaStream!);
      _sourceNode!.connectNode(scriptProcessor);
      scriptProcessor.connectNode(_audioContext!.destination!);
      
      _isRecording = true;
      debugPrint('ScriptProcessor setup successful');
      return true;
      
    } catch (e) {
      debugPrint('ScriptProcessor setup failed: $e');
      return false;
    }
  }
  
  /// 오디오 캡처 중단
  Future<void> stopCapture() async {
    if (!_isRecording) return;
    
    try {
      // 연결 해제
      _sourceNode?.disconnect();
      _workletNode?.disconnect();
      
      // MediaStream 중단
      _mediaStream?.getTracks().forEach((track) => track.stop());
      
      // AudioContext 정리
      await _audioContext?.close();
      
      _isRecording = false;
      debugPrint('Audio capture stopped');
      
    } catch (e) {
      debugPrint('Error stopping audio capture: $e');
    } finally {
      _cleanup();
    }
  }
  
  /// 리소스 정리
  void _cleanup() {
    _mediaStream = null;
    _audioContext = null;
    _sourceNode = null;
    _workletNode = null;
    _isRecording = false;
  }
  
  /// 마이크 권한 확인
  static Future<bool> checkMicrophonePermission() async {
    try {
      final permissions = await html.window.navigator.permissions?.query({
        'name': 'microphone'
      });
      
      return permissions?.state == 'granted';
    } catch (e) {
      debugPrint('Permission check failed: $e');
      return false;
    }
  }
  
  /// 브라우저 호환성 확인
  static Map<String, bool> checkBrowserCompatibility() {
    final nav = html.window.navigator;
    final isWebkit = nav.userAgent.contains('WebKit');
    final isChrome = nav.userAgent.contains('Chrome');
    final isFirefox = nav.userAgent.contains('Firefox');
    final isSafari = nav.userAgent.contains('Safari') && !isChrome;
    
    return {
      'mediaDevices': nav.mediaDevices != null,
      'audioContext': html.AudioContext.supported,
      'audioWorklet': js_util.hasProperty(html.AudioContext(), 'audioWorklet'),
      'scriptProcessor': true, // 모든 브라우저 지원
      'browser': isChrome ? 'chrome' : 
                isFirefox ? 'firefox' : 
                isSafari ? 'safari' : 'other',
      'webkit': isWebkit,
    };
  }
  
  /// 지연시간 측정
  Future<double> measureLatency() async {
    if (!_isRecording || _audioContext == null) return -1;
    
    try {
      // 오디오 컨텍스트의 지연시간 정보
      final baseLatency = _audioContext!.baseLatency ?? 0;
      final outputLatency = _audioContext!.outputLatency ?? 0;
      
      return (baseLatency + outputLatency) * 1000; // ms 단위
    } catch (e) {
      debugPrint('Latency measurement failed: $e');
      return -1;
    }
  }
  
  /// 리소스 해제
  void dispose() {
    stopCapture();
    _audioController.close();
  }
}

/// Web Audio API 유틸리티
class WebAudioUtils {
  /// 브라우저별 최적 설정 가져오기
  static Map<String, dynamic> getOptimalSettings() {
    final compat = ModernAudioCapture.checkBrowserCompatibility();
    
    if (compat['browser'] == 'chrome') {
      return {
        'sampleRate': 16000,
        'bufferSize': 1024,
        'useAudioWorklet': compat['audioWorklet'],
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      };
    } else if (compat['browser'] == 'firefox') {
      return {
        'sampleRate': 16000,
        'bufferSize': 2048, // Firefox는 더 큰 버퍼 선호
        'useAudioWorklet': false, // Firefox AudioWorklet 지원 제한적
        'echoCancellation': true,
        'noiseSuppression': false, // 성능 이슈
        'autoGainControl': true,
      };
    } else if (compat['browser'] == 'safari') {
      return {
        'sampleRate': 16000,
        'bufferSize': 4096, // Safari는 큰 버퍼 필요
        'useAudioWorklet': false, // Safari AudioWorklet 지원 제한적
        'echoCancellation': false, // Safari 호환성 이슈
        'noiseSuppression': false,
        'autoGainControl': false,
      };
    } else {
      // 기본 설정 (최대 호환성)
      return {
        'sampleRate': 16000,
        'bufferSize': 2048,
        'useAudioWorklet': false,
        'echoCancellation': true,
        'noiseSuppression': false,
        'autoGainControl': true,
      };
    }
  }
  
  /// 오디오 품질 진단
  static Future<Map<String, dynamic>> diagnoseAudioQuality(
    Stream<Float32List> audioStream
  ) async {
    final completer = Completer<Map<String, dynamic>>();
    final samples = <double>[];
    late StreamSubscription subscription;
    
    subscription = audioStream.listen((chunk) {
      samples.addAll(chunk);
      
      if (samples.length >= 16000) { // 1초 분량
        subscription.cancel();
        
        // 품질 분석
        final rms = _calculateRMS(samples);
        final snr = _estimateSNR(samples);
        final clipCount = samples.where((s) => s.abs() > 0.95).length;
        
        completer.complete({
          'rms': rms,
          'snr': snr,
          'clipping': clipCount / samples.length,
          'quality': _assessQuality(rms, snr, clipCount / samples.length),
        });
      }
    });
    
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => {'error': 'Timeout'}
    );
  }
  
  static double _calculateRMS(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    final sumSquares = samples.map((s) => s * s).reduce((a, b) => a + b);
    return (sumSquares / samples.length).clamp(0.0, 1.0);
  }
  
  static double _estimateSNR(List<double> samples) {
    // 간단한 SNR 추정 (신호 대 잡음비)
    final rms = _calculateRMS(samples);
    final noise = samples.map((s) => s.abs()).where((s) => s < 0.1).length / samples.length;
    return rms / (noise + 0.001); // 0으로 나누기 방지
  }
  
  static String _assessQuality(double rms, double snr, double clipping) {
    if (clipping > 0.01) return 'poor'; // 1% 이상 클리핑
    if (rms < 0.001) return 'poor'; // 너무 조용함
    if (snr > 10) return 'excellent';
    if (snr > 5) return 'good';
    if (snr > 2) return 'fair';
    return 'poor';
  }
}