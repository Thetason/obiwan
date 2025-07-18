import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioCaptureService {
  static const int sampleRate = 16000;
  static const int bufferSize = 1024;
  static const int originalSampleRate = 48000;
  
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  StreamController<List<double>>? _audioStreamController;
  StreamSubscription? _recordingDataSubscription;
  bool _isInitialized = false;
  bool _isRecording = false;
  
  Stream<List<double>> get audioStream {
    _audioStreamController ??= StreamController<List<double>>.broadcast();
    return _audioStreamController!.stream;
  }
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // 권한 요청
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw AudioCaptureException('Microphone permission denied');
    }
    
    // 레코더 초기화
    await _recorder.openRecorder();
    _isInitialized = true;
  }
  
  Future<void> startCapture() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isRecording) return;
    
    _isRecording = true;
    
    // PCM 스트림으로 녹음 시작
    await _recorder.startRecorder(
      toStream: _audioStreamController!.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: originalSampleRate,
    );
    
    // 오디오 데이터 스트림 처리
    _recordingDataSubscription = _recorder.recordingDataStream!.listen(
      (buffer) {
        // Uint8List를 Float List로 변환
        final samples = _convertBufferToSamples(buffer);
        
        // 다운샘플링 (48kHz -> 16kHz)
        final downsampled = _downsample(samples, originalSampleRate, sampleRate);
        
        // 버퍼 크기에 맞게 청킹
        for (int i = 0; i < downsampled.length; i += bufferSize) {
          final end = math.min(i + bufferSize, downsampled.length);
          final chunk = downsampled.sublist(i, end);
          
          if (chunk.length == bufferSize) {
            _audioStreamController?.add(chunk);
          }
        }
      },
      onError: (error) {
        _audioStreamController?.addError(error);
      },
    );
  }
  
  Future<void> stopCapture() async {
    if (!_isRecording) return;
    
    _isRecording = false;
    
    await _recordingDataSubscription?.cancel();
    await _recorder.stopRecorder();
  }
  
  Future<void> dispose() async {
    await stopCapture();
    await _recorder.closeRecorder();
    await _audioStreamController?.close();
    _isInitialized = false;
  }
  
  List<double> _convertBufferToSamples(dynamic buffer) {
    if (buffer is List<int>) {
      // PCM16 형식: 2바이트씩 읽어서 16비트 정수로 변환
      final samples = <double>[];
      for (int i = 0; i < buffer.length - 1; i += 2) {
        // Little-endian 16비트 정수로 변환
        final int16 = (buffer[i + 1] << 8) | buffer[i];
        // 부호 있는 16비트 정수로 변환
        final signedInt16 = int16 > 32767 ? int16 - 65536 : int16;
        // -1.0 ~ 1.0 범위로 정규화
        samples.add(signedInt16 / 32768.0);
      }
      return samples;
    }
    return [];
  }
  
  List<double> _downsample(List<double> input, int fromRate, int toRate) {
    if (fromRate == toRate) return input;
    
    final ratio = fromRate / toRate;
    final outputLength = (input.length / ratio).floor();
    final output = List<double>.filled(outputLength, 0.0);
    
    // 선형 보간을 사용한 다운샘플링
    for (int i = 0; i < outputLength; i++) {
      final srcIndex = i * ratio;
      final srcIndexInt = srcIndex.floor();
      final fraction = srcIndex - srcIndexInt;
      
      if (srcIndexInt < input.length - 1) {
        // 선형 보간
        output[i] = input[srcIndexInt] * (1 - fraction) + 
                   input[srcIndexInt + 1] * fraction;
      } else {
        output[i] = input[srcIndexInt];
      }
    }
    
    return output;
  }
  
  // 디버깅용 메서드
  Future<void> testCapture(Duration duration) async {
    await startCapture();
    
    final samples = <double>[];
    final subscription = audioStream.listen((chunk) {
      samples.addAll(chunk);
    });
    
    await Future.delayed(duration);
    
    await stopCapture();
    await subscription.cancel();
    
    print('Captured ${samples.length} samples in ${duration.inSeconds} seconds');
    print('Average sample rate: ${samples.length / duration.inSeconds}');
  }
}

class AudioCaptureException implements Exception {
  final String message;
  AudioCaptureException(this.message);
  
  @override
  String toString() => 'AudioCaptureException: $message';
}