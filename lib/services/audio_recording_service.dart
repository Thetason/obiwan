import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/services.dart';

/// 실시간 오디오 녹음 서비스 (테스트용)
class AudioRecordingService {
  static const MethodChannel _channel = MethodChannel('vocal_trainer/audio');
  
  bool _isRecording = false;
  final List<Float32List> _audioChunks = [];
  Timer? _chunkTimer;
  
  bool get isRecording => _isRecording;
  
  /// 녹음 시작
  Future<void> startRecording() async {
    if (_isRecording) return;
    
    try {
      final result = await _channel.invokeMethod<bool>('startRecording');
      
      if (result == true) {
        _isRecording = true;
        _audioChunks.clear();
        
        // 100ms마다 오디오 청크 수집
        _chunkTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
          if (!_isRecording) return;
          
          try {
            final audioData = await _channel.invokeMethod<Uint8List>('getAudioChunk');
            if (audioData != null) {
              final float32Data = audioData.buffer.asFloat32List();
              _audioChunks.add(float32Data);
              
              // 메모리 관리: 최근 50개 청크만 보관 (5초)
              if (_audioChunks.length > 50) {
                _audioChunks.removeAt(0);
              }
            }
          } catch (e) {
            print('Failed to get audio chunk: $e');
          }
        });
      } else {
        throw Exception('Failed to start recording');
      }
    } catch (e) {
      print('Failed to start recording: $e');
      _isRecording = false;
      rethrow;
    }
  }
  
  /// 녹음 중지
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    
    _isRecording = false;
    _chunkTimer?.cancel();
    
    try {
      await _channel.invokeMethod<bool>('stopRecording');
    } catch (e) {
      print('Failed to stop recording: $e');
    }
    
    _audioChunks.clear();
  }
  
  /// 최근 오디오 데이터 가져오기
  Future<Float32List?> getRecentAudio(int milliseconds) async {
    if (!_isRecording || _audioChunks.isEmpty) return null;
    
    final chunksNeeded = (milliseconds / 100).ceil();
    final startIndex = (_audioChunks.length - chunksNeeded).clamp(0, _audioChunks.length);
    
    if (startIndex >= _audioChunks.length) return null;
    
    // 필요한 청크들을 결합
    final recentChunks = _audioChunks.sublist(startIndex);
    final totalLength = recentChunks.fold(0, (sum, chunk) => sum + chunk.length);
    
    final combinedAudio = Float32List(totalLength);
    int offset = 0;
    
    for (final chunk in recentChunks) {
      combinedAudio.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    
    return combinedAudio;
  }
  
  /// 전체 녹음 데이터 가져오기
  Float32List? getAllAudioData() {
    if (_audioChunks.isEmpty) return null;
    
    final totalLength = _audioChunks.fold(0, (sum, chunk) => sum + chunk.length);
    final combinedAudio = Float32List(totalLength);
    int offset = 0;
    
    for (final chunk in _audioChunks) {
      combinedAudio.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    
    return combinedAudio;
  }
  
  void dispose() {
    stopRecording();
  }
}