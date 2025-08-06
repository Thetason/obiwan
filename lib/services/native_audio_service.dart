import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class NativeAudioService {
  static const MethodChannel _channel = MethodChannel('audio_capture');
  static NativeAudioService? _instance;
  
  StreamController<Map<String, double>>? _audioLevelController;
  Function(double)? onAudioLevelChanged;
  
  NativeAudioService._();
  
  static NativeAudioService get instance {
    _instance ??= NativeAudioService._();
    return _instance!;
  }
  
  Stream<Map<String, double>> get audioLevelStream {
    _audioLevelController ??= StreamController<Map<String, double>>.broadcast();
    return _audioLevelController!.stream;
  }
  
  Future<void> initialize() async {
    try {
      print('🎤 [Dart] 네이티브 오디오 서비스 초기화 시작');
      
      // 메서드 콜 핸들러 등록
      _channel.setMethodCallHandler((MethodCall call) async {
        print('📞 [Dart] Swift로부터 메서드 호출 수신: ${call.method}');
        return await _handleMethodCall(call);
      });
      
      print('🎤 [Dart] 네이티브 오디오 서비스 초기화 완료');
    } catch (e) {
      print('❌ [Dart] 네이티브 오디오 서비스 초기화 실패: $e');
      rethrow;
    }
  }
  
  Future<bool> startRecording() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final result = await _channel.invokeMethod<bool>('startRecording');
        print('🎤 [Dart] 네이티브 오디오 녹음 시작 요청: $result');
        return result ?? false;
      } else {
        print('⚠️ [Dart] 현재 플랫폼에서는 네이티브 오디오가 지원되지 않음');
        return false;
      }
    } catch (e) {
      print('❌ [Dart] 네이티브 오디오 녹음 시작 실패: $e');
      return false;
    }
  }
  
  Future<bool> stopRecording() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final result = await _channel.invokeMethod<bool>('stopRecording');
        print('🎤 [Dart] 네이티브 오디오 녹음 종료 요청: $result');
        return result ?? false;
      } else {
        return false;
      }
    } catch (e) {
      print('❌ [Dart] 네이티브 오디오 녹음 종료 실패: $e');
      return false;
    }
  }
  
  Future<List<double>?> getRecordedAudio() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final result = await _channel.invokeMethod<List<dynamic>>('getRecordedAudio');
        final audioData = result?.cast<double>();
        print('🎵 [Dart] 녹음된 오디오 데이터 수신: ${audioData?.length ?? 0} 샘플');
        return audioData;
      } else {
        return null;
      }
    } catch (e) {
      print('❌ [Dart] 녹음된 오디오 데이터 가져오기 실패: $e');
      return null;
    }
  }
  
  Future<bool> playAudio() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final result = await _channel.invokeMethod<bool>('playAudio');
        print('🔊 [Dart] 네이티브 오디오 재생 시작: $result');
        return result ?? false;
      } else {
        return false;
      }
    } catch (e) {
      print('❌ [Dart] 네이티브 오디오 재생 실패: $e');
      return false;
    }
  }
  
  Future<bool> pauseAudio() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final result = await _channel.invokeMethod<bool>('pauseAudio');
        print('⏸️ [Dart] 네이티브 오디오 일시정지: $result');
        return result ?? false;
      } else {
        return false;
      }
    } catch (e) {
      print('❌ [Dart] 네이티브 오디오 일시정지 실패: $e');
      return false;
    }
  }
  
  Future<bool> stopAudio() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final result = await _channel.invokeMethod<bool>('stopAudio');
        print('⏹️ [Dart] 네이티브 오디오 정지: $result');
        return result ?? false;
      } else {
        return false;
      }
    } catch (e) {
      print('❌ [Dart] 네이티브 오디오 정지 실패: $e');
      return false;
    }
  }
  
  Future<bool> seekAudio(double position) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final result = await _channel.invokeMethod<bool>('seekAudio', {'position': position});
        print('⏭️ [Dart] 네이티브 오디오 위치 이동: $result');
        return result ?? false;
      } else {
        return false;
      }
    } catch (e) {
      print('❌ [Dart] 네이티브 오디오 위치 이동 실패: $e');
      return false;
    }
  }
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      print('📞 [Dart] 메서드 처리 중: ${call.method}');
      
      switch (call.method) {
        case 'onAudioLevel':
          // Float로 직접 전달되는 RMS 값 처리
          final rms = (call.arguments as num).toDouble();
          
          print('🔊 [Dart] 오디오 레벨 수신: RMS = ${rms.toStringAsFixed(3)}');
          
          // 콜백 호출
          onAudioLevelChanged?.call(rms);
          
          // 스트림으로도 전송 (호환성)
          _audioLevelController?.add({
            'level': rms,
            'rms': rms,
          });
          
          return 'success';
        default:
          print('⚠️ [Dart] 알 수 없는 네이티브 메서드 호출: ${call.method}');
          return 'unknown_method';
      }
    } catch (e) {
      print('❌ [Dart] 메서드 처리 실패: $e');
      return 'error: $e';
    }
  }
  
  void dispose() {
    _audioLevelController?.close();
    _audioLevelController = null;
  }
}