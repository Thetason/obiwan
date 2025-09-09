import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

/// CREPE 서버로 레퍼런스 멜로디(피치 시퀀스)를 생성하는 서비스
class ReferenceMelodyService {
  final Dio _dio;
  final String baseUrl;

  ReferenceMelodyService({String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? 'http://localhost:5002',
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 20),
        )),
        baseUrl = baseUrl ?? 'http://localhost:5002';

  /// WAV(권장) 또는 float32 raw bytes(base64)로 CREPE 분석 → 주파수 배열 반환
  Future<List<double>> createFromAudioBytes(Uint8List bytes, {int sampleRate = 44100}) async {
    final audioBase64 = base64Encode(bytes);
    final resp = await _dio.post('/analyze', data: {
      'audio_base64': audioBase64,
      'sample_rate': sampleRate,
    });
    if (resp.statusCode == 200 && resp.data != null) {
      // server mirrors top-level keys: frequencies/timestamps
      final freqsAny = resp.data['frequencies'] ?? resp.data['data']?['frequencies'];
      if (freqsAny is List) {
        final freqs = freqsAny.map((e) => (e as num).toDouble()).toList();
        return _postProcess(freqs);
      }
    }
    return <double>[];
  }

  List<double> _postProcess(List<double> freqs) {
    if (freqs.isEmpty) return freqs;
    // 간단한 스무딩(이웃 평균)과 무음(0Hz) 처리
    final out = List<double>.from(freqs);
    for (int i = 1; i < out.length - 1; i++) {
      final a = out[i - 1];
      final b = out[i];
      final c = out[i + 1];
      if (b <= 0 && a > 0 && c > 0) {
        out[i] = (a + c) / 2.0;
      } else if (b > 0 && a > 0 && c > 0) {
        out[i] = (a + b + c) / 3.0;
      }
    }
    return out;
  }
}

