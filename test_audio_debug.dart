import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'lib/services/native_audio_service.dart';
import 'lib/services/dual_engine_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🎤 오디오 디버깅 테스트 시작');
  
  final audioService = NativeAudioService();
  final engineService = DualEngineService();
  
  // 1. 녹음 시작
  print('📝 녹음 시작 (5초간)...');
  await audioService.startRecording();
  
  // 5초 대기
  await Future.delayed(Duration(seconds: 5));
  
  // 2. 녹음 중지
  print('🛑 녹음 중지');
  await audioService.stopRecording();
  
  // 3. 녹음된 데이터 가져오기
  print('📊 녹음된 데이터 가져오기...');
  final audioData = await audioService.getRecordedAudioData();
  
  if (audioData == null || audioData.isEmpty) {
    print('❌ 녹음된 데이터가 없습니다!');
    return;
  }
  
  print('✅ 녹음 데이터: ${audioData.length} 샘플');
  
  // 4. 오디오 데이터 통계 출력
  final maxVal = audioData.reduce((a, b) => a.abs() > b.abs() ? a : b);
  final avgVal = audioData.reduce((a, b) => a + b) / audioData.length;
  final rms = sqrt(audioData.map((x) => x * x).reduce((a, b) => a + b) / audioData.length);
  
  print('📈 오디오 통계:');
  print('  - 최대값: $maxVal');
  print('  - 평균값: $avgVal');
  print('  - RMS: $rms');
  
  // 5. 첫 100개 샘플 출력
  print('🔊 첫 100개 샘플:');
  for (int i = 0; i < 100 && i < audioData.length; i++) {
    if (i % 10 == 0) print('');
    print('  [$i]: ${audioData[i].toStringAsFixed(6)}');
  }
  
  // 6. WAV 파일로 저장
  print('💾 WAV 파일로 저장...');
  await _saveAsWav(audioData, '/Users/seoyeongbin/vocal_trainer_ai/debug_recording.wav');
  
  // 7. CREPE 분석 테스트 (첫 1초만)
  print('🎵 CREPE 분석 테스트...');
  final chunkSize = 48000; // 1초
  if (audioData.length >= chunkSize) {
    final testChunk = Float32List.fromList(audioData.sublist(0, chunkSize));
    
    try {
      final result = await engineService.analyzeDual(testChunk);
      if (result != null) {
        print('✅ CREPE 분석 결과:');
        print('  - 주파수: ${result.frequency.toStringAsFixed(1)} Hz');
        print('  - 신뢰도: ${(result.confidence * 100).toStringAsFixed(1)}%');
        print('  - 엔진: ${result.recommendedEngine}');
      } else {
        print('❌ CREPE 분석 실패');
      }
    } catch (e) {
      print('❌ CREPE 분석 오류: $e');
    }
  }
  
  print('🎤 오디오 디버깅 테스트 완료');
}

Future<void> _saveAsWav(List<double> audioData, String filePath) async {
  // 간단한 WAV 헤더 생성
  final sampleRate = 48000;
  final numChannels = 1;
  final bitsPerSample = 16;
  
  // Float를 Int16으로 변환
  final int16Data = Int16List(audioData.length);
  for (int i = 0; i < audioData.length; i++) {
    final sample = (audioData[i] * 32767).clamp(-32768, 32767).toInt();
    int16Data[i] = sample;
  }
  
  // WAV 파일 생성
  final byteData = ByteData(44 + int16Data.length * 2);
  
  // RIFF header
  byteData.setUint8(0, 0x52); // 'R'
  byteData.setUint8(1, 0x49); // 'I'
  byteData.setUint8(2, 0x46); // 'F'
  byteData.setUint8(3, 0x46); // 'F'
  byteData.setUint32(4, 36 + int16Data.length * 2, Endian.little);
  byteData.setUint8(8, 0x57);  // 'W'
  byteData.setUint8(9, 0x41);  // 'A'
  byteData.setUint8(10, 0x56); // 'V'
  byteData.setUint8(11, 0x45); // 'E'
  
  // fmt chunk
  byteData.setUint8(12, 0x66); // 'f'
  byteData.setUint8(13, 0x6D); // 'm'
  byteData.setUint8(14, 0x74); // 't'
  byteData.setUint8(15, 0x20); // ' '
  byteData.setUint32(16, 16, Endian.little); // fmt chunk size
  byteData.setUint16(20, 1, Endian.little);  // PCM format
  byteData.setUint16(22, numChannels, Endian.little);
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(28, sampleRate * numChannels * bitsPerSample ~/ 8, Endian.little);
  byteData.setUint16(32, numChannels * bitsPerSample ~/ 8, Endian.little);
  byteData.setUint16(34, bitsPerSample, Endian.little);
  
  // data chunk
  byteData.setUint8(36, 0x64); // 'd'
  byteData.setUint8(37, 0x61); // 'a'
  byteData.setUint8(38, 0x74); // 't'
  byteData.setUint8(39, 0x61); // 'a'
  byteData.setUint32(40, int16Data.length * 2, Endian.little);
  
  // Audio data
  for (int i = 0; i < int16Data.length; i++) {
    byteData.setInt16(44 + i * 2, int16Data[i], Endian.little);
  }
  
  // 파일 저장
  final file = File(filePath);
  await file.writeAsBytes(byteData.buffer.asUint8List());
  
  print('✅ WAV 파일 저장 완료: $filePath');
}