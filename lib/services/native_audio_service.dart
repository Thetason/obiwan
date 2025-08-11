import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../core/debug_logger.dart';
import '../core/error_handler.dart';

class NativeAudioService {
  static const MethodChannel _channel = MethodChannel('audio_capture');
  static NativeAudioService? _instance;
  
  StreamController<Map<String, double>>? _audioLevelController;
  Function(double)? onAudioLevelChanged;
  bool _isInitialized = false;
  bool _isDisposed = false;  // CRITICAL FIX: disposal 상태 추적
  
  NativeAudioService._();
  
  static NativeAudioService get instance {
    _instance ??= NativeAudioService._();
    return _instance!;
  }
  
  bool get isInitialized => _isInitialized;
  
  Stream<Map<String, double>> get audioLevelStream {
    _audioLevelController ??= StreamController<Map<String, double>>.broadcast();
    return _audioLevelController!.stream;
  }
  
  Future<void> initialize() async {
    return await errorHandler.safeExecute(
      () async {
        await logger.info('네이티브 오디오 서비스 초기화 시작', tag: 'NATIVE_AUDIO');
        
        // 메서드 콜 핸들러 등록
        _channel.setMethodCallHandler((MethodCall call) async {
          await logger.debug('Swift로부터 메서드 호출 수신: ${call.method}', tag: 'NATIVE_AUDIO');
          return await _handleMethodCall(call);
        });
        
        await logger.info('네이티브 오디오 서비스 초기화 완료', tag: 'NATIVE_AUDIO');
        _isInitialized = true;
      },
      operationName: 'Native Audio Service Initialize',
    );
  }
  
  Future<bool> startRecording() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      await logger.warning('현재 플랫폼에서는 네이티브 오디오가 지원되지 않음', tag: 'NATIVE_AUDIO');
      return false;
    }

    final result = await errorHandler.handleAudioError(
      () async {
        final result = await _channel.invokeMethod<bool>('startRecording');
        await logger.info('네이티브 오디오 녹음 시작 성공: $result', tag: 'NATIVE_AUDIO');
        return result ?? false;
      },
      'Start Recording',
    );
    
    return result ?? false;
  }
  
  Future<bool> stopRecording() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return false;
    }

    final result = await errorHandler.handleAudioError(
      () async {
        final result = await _channel.invokeMethod<bool>('stopRecording');
        await logger.info('네이티브 오디오 녹음 종료 성공: $result', tag: 'NATIVE_AUDIO');
        return result ?? false;
      },
      'Stop Recording',
    );
    
    return result ?? false;
  }
  
  Future<List<double>?> getRecordedAudio() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return null;
    }

    return await errorHandler.handleAudioError(
      () async {
        final result = await _channel.invokeMethod<List<dynamic>>('getRecordedAudio');
        final audioData = result?.cast<double>();
        
        if (audioData != null && audioData.isNotEmpty) {
          await logger.info('녹음된 오디오 데이터 수신 성공: ${audioData.length} 샘플', tag: 'NATIVE_AUDIO');
        } else {
          await logger.warning('녹음된 오디오 데이터가 비어있음', tag: 'NATIVE_AUDIO');
        }
        
        return audioData ?? [];
      },
      'Get Recorded Audio',
    );
  }
  
  Future<List<double>?> getRealtimeAudioBuffer() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final result = await _channel.invokeMethod<List<dynamic>>('getRealtimeAudioBuffer');
        final audioData = result?.cast<double>();
        if (audioData != null && audioData.isNotEmpty) {
          print('🎤 [Dart] 실시간 오디오 버퍼 수신: ${audioData.length} 샘플');
        }
        return audioData;
      } else {
        return null;
      }
    } catch (e) {
      print('❌ [Dart] 실시간 오디오 버퍼 가져오기 실패: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> loadAudioFile(String filePath) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'loadAudioFile',
          {'path': filePath},
        );
        
        if (result != null) {
          // Map<dynamic, dynamic>을 Map<String, dynamic>으로 변환
          final audioData = Map<String, dynamic>.from(result);
          final samples = (audioData['samples'] as List<dynamic>?)?.cast<double>();
          
          print('🎵 [Dart] 오디오 파일 로드 완료: ${samples?.length ?? 0} 샘플');
          
          return {
            'samples': samples,
            'sampleRate': audioData['sampleRate'],
            'duration': audioData['duration'],
          };
        }
      }
      return null;
    } catch (e) {
      print('❌ [Dart] 오디오 파일 로드 실패: $e');
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
          // Map으로 전달되는 오디오 레벨 데이터 처리
          final Map<String, dynamic> levelData = Map<String, dynamic>.from(call.arguments as Map);
          
          final dbLevel = (levelData['level'] as num?)?.toDouble() ?? -60.0;
          final rms = (levelData['rms'] as num?)?.toDouble() ?? 0.0;
          final samples = (levelData['samples'] as num?)?.toInt() ?? 0;
          
          print('🔊 [Dart] 실시간 오디오: ${dbLevel.toStringAsFixed(1)}dB, RMS=${rms.toStringAsFixed(3)}, 샘플=${samples}');
          
          // RMS 값으로 콜백 호출
          onAudioLevelChanged?.call(rms);
          
          // 전체 데이터를 스트림으로 전송
          _audioLevelController?.add({
            'level': dbLevel,
            'rms': rms,
            'samples': samples.toDouble(),
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
  
  /// 녹음된 오디오 데이터 가져오기
  Future<List<double>?> getRecordedAudioData() async {
    try {
      await logger.info('녹음된 오디오 데이터 요청', tag: 'NATIVE_AUDIO');
      
      // Swift에서 녹음된 오디오 데이터 가져오기 (getRecordedAudio 메서드 사용)
      final result = await _channel.invokeMethod('getRecordedAudio');
      
      if (result != null) {
        // List<dynamic>을 List<double>로 변환
        final audioData = (result as List).map((e) => (e as num).toDouble()).toList();
        await logger.info('오디오 데이터 수신: ${audioData.length} 샘플', tag: 'NATIVE_AUDIO');
        return audioData;
      }
      
      return null;
    } catch (e) {
      await logger.error('오디오 데이터 가져오기 실패: $e', tag: 'NATIVE_AUDIO');
      return null;
    }
  }
  
  /// 오디오 시스템 상태 확인
  Future<Map<String, dynamic>> getAudioSystemStatus() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return {'supported': false, 'reason': 'Platform not supported'};
    }

    try {
      await logger.debug('오디오 시스템 상태 확인 시작', tag: 'NATIVE_AUDIO');
      
      // 임시로 녹음 시작을 시도해서 상태 확인
      bool canStart = false;
      String? errorMessage;
      
      try {
        canStart = await _channel.invokeMethod<bool>('startRecording') ?? false;
        if (canStart) {
          // 즉시 중지
          await _channel.invokeMethod<bool>('stopRecording');
        }
      } on PlatformException catch (e) {
        errorMessage = e.message;
        await logger.error('오디오 상태 확인 중 에러: ${e.code} - ${e.message}', tag: 'NATIVE_AUDIO');
      }
      
      final status = {
        'supported': true,
        'canRecord': canStart,
        'error': errorMessage,
        'platform': 'macOS',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await logger.info('오디오 시스템 상태: $status', tag: 'NATIVE_AUDIO');
      return status;
      
    } catch (e) {
      await logger.error('오디오 상태 확인 실패: $e', tag: 'NATIVE_AUDIO');
      return {
        'supported': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// 재시도 메커니즘이 포함된 녹음 시작
  Future<bool> startRecordingWithRetry({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      await logger.info('녹음 시작 시도 $attempt/$maxRetries', tag: 'NATIVE_AUDIO');
      
      final success = await startRecording();
      if (success) {
        await logger.info('녹음 시작 성공 (시도 $attempt회)', tag: 'NATIVE_AUDIO');
        return true;
      }
      
      if (attempt < maxRetries) {
        await logger.warning('녹음 시작 실패, ${attempt * 500}ms 후 재시도', tag: 'NATIVE_AUDIO');
        await Future.delayed(Duration(milliseconds: attempt * 500));
      }
    }
    
    await logger.error('모든 재시도 실패: 녹음을 시작할 수 없음', tag: 'NATIVE_AUDIO');
    return false;
  }

  /// 오디오 데이터 유효성 검사
  Future<bool> validateRecordedAudio() async {
    final audioData = await getRecordedAudio();
    
    if (audioData == null || audioData.isEmpty) {
      await logger.error('오디오 데이터 유효성 검사 실패: 데이터 없음', tag: 'NATIVE_AUDIO');
      return false;
    }
    
    // 기본 품질 검사
    final rmsLevel = _calculateRMS(audioData);
    final peakLevel = audioData.reduce((a, b) => a.abs() > b.abs() ? a : b);
    
    await logger.info('오디오 품질: RMS=$rmsLevel, Peak=$peakLevel, 길이=${audioData.length}', tag: 'NATIVE_AUDIO');
    
    // 너무 조용하거나 클리핑된 오디오 체크
    if (rmsLevel < 0.001) {
      await logger.warning('오디오가 너무 조용함 (RMS: $rmsLevel)', tag: 'NATIVE_AUDIO');
      return false;
    }
    
    if (peakLevel.abs() > 0.95) {
      await logger.warning('오디오 클리핑 감지 (Peak: $peakLevel)', tag: 'NATIVE_AUDIO');
    }
    
    return true;
  }

  /// RMS 레벨 계산
  double _calculateRMS(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    return math.sqrt(sum / samples.length);
  }
  
  /// 녹음된 오디오 재생
  Future<bool> playRecordedAudio() async {
    try {
      await logger.info('오디오 재생 시작', tag: 'NATIVE_AUDIO');
      final result = await _channel.invokeMethod<bool>('playAudio');
      
      if (result == true) {
        await logger.info('오디오 재생 성공', tag: 'NATIVE_AUDIO');
        return true;
      } else {
        await logger.error('오디오 재생 실패', tag: 'NATIVE_AUDIO');
        return false;
      }
    } catch (e) {
      await logger.error('오디오 재생 예외: $e', tag: 'NATIVE_AUDIO');
      return false;
    }
  }
  
  /// 재생 중지
  Future<void> stopPlayback() async {
    try {
      await logger.info('오디오 재생 중지', tag: 'NATIVE_AUDIO');
      await _channel.invokeMethod('stopPlayback')
          .timeout(const Duration(seconds: 2));
    } on PlatformException catch (e) {
      // Native 메서드가 구현되지 않은 경우 무시
      if (e.code != 'MissingPluginException') {
        await logger.error('재생 중지 플랫폼 에러: ${e.code} - ${e.message}', tag: 'NATIVE_AUDIO');
      }
    } on TimeoutException {
      await logger.warning('재생 중지 타임아웃', tag: 'NATIVE_AUDIO');
    } catch (e) {
      await logger.error('재생 중지 실패: $e', tag: 'NATIVE_AUDIO');
    }
  }
  
  /// 현재 오디오 레벨 가져오기
  Future<double> getCurrentAudioLevel() async {
    try {
      final level = await _channel.invokeMethod<double>('getCurrentAudioLevel')
          .timeout(const Duration(seconds: 2));
      return level ?? 0.0;
    } on PlatformException catch (e) {
      await logger.warning('Native 오디오 레벨 가져오기 실패: ${e.code} - ${e.message}', tag: 'NATIVE_AUDIO');
      return 0.0;
    } on TimeoutException catch (e) {
      await logger.warning('Native 오디오 레벨 타임아웃: $e', tag: 'NATIVE_AUDIO');
      return 0.0;
    } catch (e) {
      await logger.error('오디오 레벨 가져오기 예외: $e', tag: 'NATIVE_AUDIO');
      // 실제 구현이 없는 경우 0.0 반환 (랜덤 값 제거)
      return 0.0;
    }
  }

  void dispose() {
    logger.info('Native Audio Service 정리', tag: 'NATIVE_AUDIO');
    _isDisposed = true;  // CRITICAL FIX: disposal 상태 설정
    
    // 진행 중인 오디오 작업 모두 중지
    try {
      stopAudio().catchError((e) {
        logger.warning('dispose 중 오디오 정지 실패: $e', tag: 'NATIVE_AUDIO');
      });
      stopRecording().catchError((e) {
        logger.warning('dispose 중 녹음 정지 실패: $e', tag: 'NATIVE_AUDIO');
      });
    } catch (e) {
      logger.error('dispose 중 오디오 정리 실패: $e', tag: 'NATIVE_AUDIO');
    }
    
    // StreamController 안전하게 정리
    try {
      if (_audioLevelController != null && !_audioLevelController!.isClosed) {
        _audioLevelController!.close();
      }
    } catch (e) {
      logger.error('StreamController 정리 실패: $e', tag: 'NATIVE_AUDIO');
    } finally {
      _audioLevelController = null;
    }
    
    // 콜백 정리
    onAudioLevelChanged = null;
    _isInitialized = false;
  }
}