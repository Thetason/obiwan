import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/analysis_result.dart';
import 'single_pitch_tracker.dart';
import 'ondevice_crepe_service.dart';
import '../config/app_config.dart';
import '../config/pipeline_preset.dart';

/// 초고속 CREPE + SPICE 듀얼 엔진 서비스 (HTTP/2 + 배치 처리)
class DualEngineService {
  static DualEngineService? _instance;

  final AppConfig _config;
  final String _crepeUrl;
  final String _spiceUrl;

  late final Dio _crepeClient;
  late final Dio _spiceClient;
  
  // HTTP/2 지원을 위한 클라이언트
  late final HttpClient _http2CrepeClient;
  late final HttpClient _http2SpiceClient;
  SinglePitchTracker? _pitchTracker;
  final OnDeviceCrepeService _onDeviceCrepe = OnDeviceCrepeService();
  
  // 피치 분석 캐시 (최근 10개 결과 저장)
  final Map<String, DualResult> _pitchCache = {};
  static const int _maxCacheSize = 10;
  
  // 싱글톤
  factory DualEngineService({AppConfig? config}) {
    if (_instance != null) {
      return _instance!;
    }

    if (config == null) {
      throw StateError(
        'DualEngineService must be initialized with an AppConfig before use. '
        'Call DualEngineService(config: appConfig) during application startup.',
      );
    }

    _instance = DualEngineService._internal(config);
    return _instance!;
  }

  // 배치 처리용 큐
  final List<BatchRequest> _crepeQueue = [];
  final List<BatchRequest> _spiceQueue = [];
  Timer? _batchTimer;
  
  // 연결 풀링
  final Map<String, String> _connectionPool = {};

  DualEngineService._internal(AppConfig config)
      : _config = config,
        _crepeUrl = config.crepeBaseUrl ?? '',
        _spiceUrl = config.spiceBaseUrl ?? '' {
    _validateBaseUrls();
    _initializeClients();
    _startBatchProcessor();
  }

  void _validateBaseUrls() {
    final missingKeys = _config.missingDualEngineKeys;
    if (missingKeys.isNotEmpty) {
      final message =
          'DualEngineService base URL configuration is missing for '
          '${_config.environment} environment. Please provide ${missingKeys.join(', ')} '
          'using --dart-define or platform environment variables.';
      debugPrint('⚠️ [DualEngineService] $message');
      throw StateError(message);
    }
  }
  
  void _initializeClients() {
    // 기존 Dio 클라이언트 (폴백용)
    _crepeClient = Dio(BaseOptions(
      baseUrl: _crepeUrl,
      connectTimeout: const Duration(seconds: 5),  // 더 빠른 타임아웃
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'Connection': 'keep-alive',
        'Keep-Alive': 'timeout=30, max=100',
      },
    ));
    
    _spiceClient = Dio(BaseOptions(
      baseUrl: _spiceUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'Connection': 'keep-alive',
        'Keep-Alive': 'timeout=30, max=100',
      },
    ));
    
    // HTTP/2 클라이언트 초기화
    _http2CrepeClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      ..idleTimeout = const Duration(seconds: 30)
      ..maxConnectionsPerHost = 10;
      
    _http2SpiceClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3) 
      ..idleTimeout = const Duration(seconds: 30)
      ..maxConnectionsPerHost = 10;
  }
  
  /// 배치 처리 시작
  void _startBatchProcessor() {
    _batchTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _processBatches();
    });
  }
  
  /// SinglePitchTracker를 지연 초기화
  SinglePitchTracker get pitchTracker {
    _pitchTracker ??= SinglePitchTracker();
    return _pitchTracker!;
  }
  
  /// 배치 처리 실행
  void _processBatches() async {
    if (_crepeQueue.isNotEmpty) {
      await _processCrepeBatch();
    }
    if (_spiceQueue.isNotEmpty) {
      await _processSpiceBatch();
    }
  }
  
  /// CREPE 배치 처리
  Future<void> _processCrepeBatch() async {
    if (_crepeQueue.isEmpty) return;
    
    final batch = List<BatchRequest>.from(_crepeQueue);
    _crepeQueue.clear();
    
    try {
      // HTTP/2 다중 요청 (병렬 처리)
      final futures = batch.map((request) => 
        _sendHttp2Request(_http2CrepeClient, _crepeUrl, request));
      
      final results = await Future.wait(futures);
      
      // 결과 분배
      for (int i = 0; i < results.length; i++) {
        batch[i].completer.complete(results[i]);
      }
    } catch (e) {
      // 실패시 폴백
      for (final request in batch) {
        request.completer.completeError(e);
      }
    }
  }
  
  /// SPICE 배치 처리
  Future<void> _processSpiceBatch() async {
    if (_spiceQueue.isEmpty) return;
    
    final batch = List<BatchRequest>.from(_spiceQueue);
    _spiceQueue.clear();
    
    try {
      final futures = batch.map((request) => 
        _sendHttp2Request(_http2SpiceClient, _spiceUrl, request));
      
      final results = await Future.wait(futures);
      
      for (int i = 0; i < results.length; i++) {
        batch[i].completer.complete(results[i]);
      }
    } catch (e) {
      for (final request in batch) {
        request.completer.completeError(e);
      }
    }
  }
  
  /// HTTP/2 요청 전송
  Future<DualResult> _sendHttp2Request(HttpClient client, String baseUrl, BatchRequest request) async {
    final uri = Uri.parse('$baseUrl/analyze');
    
    final httpRequest = await client.postUrl(uri);
    httpRequest.headers.set('Content-Type', 'application/json');
    httpRequest.headers.set('Accept-Encoding', 'gzip, deflate, br'); // 압축 지원
    
    final requestBody = json.encode({
      'audio_data': request.audioData.toList(),
      'sample_rate': request.sampleRate,
      'batch_id': request.batchId,
    });
    
    httpRequest.write(requestBody);
    
    final httpResponse = await httpRequest.close();
    final responseBody = await httpResponse.transform(utf8.decoder).join();
    
    final Map<String, dynamic> data = json.decode(responseBody);
    
    return DualResult(
      frequency: data['frequency']?.toDouble() ?? 0.0,
      confidence: data['confidence']?.toDouble() ?? 0.0,
      timestamp: DateTime.now(),
      noteName: data['note'] ?? '',
      cents: data['cents']?.toDouble() ?? 0.0,
      recommendedEngine: baseUrl.contains('crepe') ? 'CREPE' : 'SPICE',
    );
  }
  
  /// 초고속 단일 피치 분석 (배치 큐 사용)
  Future<DualResult?> analyzeSinglePitchFast(Float32List audioData, {double sampleRate = 48000}) async {
    // 캐시 확인
    final cacheKey = _generateCacheKey(audioData);
    if (_pitchCache.containsKey(cacheKey)) {
      return _pitchCache[cacheKey];
    }
    
    // 배치 요청 생성
    final request = BatchRequest(
      audioData: audioData,
      sampleRate: sampleRate,
      batchId: DateTime.now().millisecondsSinceEpoch,
      completer: Completer<DualResult>(),
    );
    
    // 큐에 추가 (CREPE 우선)
    _crepeQueue.add(request);
    
    try {
      final result = await request.completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => DualResult(
          frequency: 0, 
          confidence: 0, 
          timestamp: DateTime.now(),
          noteName: '', 
          cents: 0, 
          recommendedEngine: 'TIMEOUT'
        ),
      );
      
      // 결과 캐싱
      _cacheResult(cacheKey, result);
      return result;
      
    } catch (e) {
      debugPrint('❌ 배치 분석 실패: $e');
      // 로컬 분석으로 폴백
      return await _fallbackToLocalAnalysis(audioData, sampleRate);
    }
  }
  
  /// 로컬 분석 폴백
  Future<DualResult?> _fallbackToLocalAnalysis(Float32List audioData, double sampleRate) async {
    try {
      final result = await pitchTracker.trackSinglePitch(audioData, sampleRate: sampleRate);
      
      return DualResult(
        frequency: result.frequency,
        confidence: result.confidence,
        timestamp: DateTime.now(),
        noteName: result.noteName,
        cents: result.cents,
        recommendedEngine: 'LOCAL',
      );
    } catch (e) {
      debugPrint('❌ 로컬 분석도 실패: $e');
      return null;
    }
  }

  /// 실시간 단일 피치 분석 (기존 호환성)
  Future<DualResult?> analyzeSinglePitch(Float32List audioData) async {
    try {
      // 새로운 고속 배치 방식 사용
      final cacheKey = _generateCacheKey(audioData);
      
      // 캐시 확인
      if (_pitchCache.containsKey(cacheKey)) {
        print('🎯 [Cache Hit] 캐시된 피치 결과 사용');
        return _pitchCache[cacheKey];
      }
      
      // 실시간 분석용 적절한 타임아웃 설정
      final crepeClient = Dio(BaseOptions(
        baseUrl: _crepeUrl,
        connectTimeout: const Duration(seconds: 2),  // 연결 타임아웃 2초
        receiveTimeout: const Duration(seconds: 3),  // 수신 타임아웃 3초
      ));
      
      // Base64 인코딩
      final base64Audio = base64Encode(audioData.buffer.asUint8List());
      
      final response = await crepeClient.post(
        '/analyze',
        data: {
          'audio_base64': base64Audio,
          'sample_rate': 44100,  // MP3는 보통 44.1kHz
        },
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        // CREPE는 배열로 반환하므로 평균값 또는 최빈값 사용
        double frequency = 0;
        double confidence = 0;
        String note = '';
        
        if (data['frequencies'] is List && (data['frequencies'] as List).isNotEmpty) {
          // 배열의 평균값 계산
          final freqs = (data['frequencies'] as List).map((e) => (e as num).toDouble()).toList();
          final confs = (data['confidence'] as List).map((e) => (e as num).toDouble()).toList();
          
          // 신뢰도가 높은 값들의 평균
          double totalFreq = 0;
          double totalConf = 0;
          int count = 0;
          
          for (int i = 0; i < freqs.length && i < confs.length; i++) {
            if (confs[i] > 0.5) {  // 신뢰도 50% 이상만
              totalFreq += freqs[i];
              totalConf += confs[i];
              count++;
            }
          }
          
          if (count > 0) {
            frequency = totalFreq / count;
            confidence = totalConf / count;
          }
          
          if (data['notes'] is List && (data['notes'] as List).isNotEmpty) {
            note = (data['notes'] as List).first.toString();
          }
        } else if (data['frequency'] != null) {
          // 단일 값 처리 (이전 형식 호환)
          frequency = (data['frequency'] as num).toDouble();
          confidence = (data['confidence'] ?? 0.8).toDouble();
          note = data['note'] ?? '';
        }
        
        final result = DualResult(
          frequency: frequency,
          confidence: confidence,
          timestamp: DateTime.now(),
          noteName: note,
          recommendedEngine: 'CREPE',
        );
        
        // 캐시에 저장
        _addToCache(cacheKey, result);
        
        return result;
      }
    } catch (e) {
      // 타임아웃이나 에러 시 빠른 폴백
      print('Quick CREPE analysis failed: $e');
    }
    return null;
  }
  
  /// 캐시 키 생성 (오디오 데이터의 간단한 해시)
  String _generateCacheKey(Float32List audioData) {
    if (audioData.isEmpty) return '';
    
    // 처음과 끝, 중간 값들로 간단한 키 생성
    final keyValues = <double>[];
    keyValues.add(audioData.first);
    keyValues.add(audioData.last);
    keyValues.add(audioData[audioData.length ~/ 2]);
    keyValues.add(audioData.length.toDouble());
    
    // RMS 값도 추가 (전체적인 볼륨 특성)
    double sum = 0;
    for (int i = 0; i < math.min(100, audioData.length); i++) {
      sum += audioData[i] * audioData[i];
    }
    keyValues.add(math.sqrt(sum / math.min(100, audioData.length)));
    
    return keyValues.map((v) => v.toStringAsFixed(3)).join('_');
  }
  
  /// 캐시에 결과 추가
  void _addToCache(String key, DualResult result) {
    if (key.isEmpty) return;
    
    // 캐시 크기 제한
    if (_pitchCache.length >= _maxCacheSize) {
      // 가장 오래된 항목 제거 (FIFO)
      _pitchCache.remove(_pitchCache.keys.first);
    }
    
    _pitchCache[key] = result;
    print('💾 [Cache] 피치 결과 캐시에 저장 (캐시 크기: ${_pitchCache.length})');
  }
  
  /// 서버 상태 확인
  // Public initialize method for external access
  Future<void> initialize() async {
    await checkStatus();
  }

  // Analyze pitch method for compatibility
  Future<Map<String, dynamic>> analyzePitch(Float32List audioData) async {
    final result = await analyzeSinglePitch(audioData);
    if (result == null) {
      return {
        'frequency': 0.0,
        'confidence': 0.0,
        'note': '',
        'error': 'No pitch detected'
      };
    }
    return {
      'frequency': result.frequency,
      'confidence': result.confidence,
      'note': result.noteName ?? '',
      'timestamp': DateTime.now().toIso8601String()
    };
  }

  // Getter for pitch stream
  Stream<Map<String, dynamic>> get pitchStream {
    // Create a realtime analysis stream
    final analysisStream = RealtimeAnalysisStream._internal(this);
    analysisStream.startStream();
    
    // Convert DualResult stream to Map stream
    return analysisStream.stream.map((result) => {
      'frequency': result.frequency,
      'confidence': result.confidence,
      'note': result.noteName ?? '',
      'timestamp': DateTime.now().toIso8601String()
    });
  }

  Future<EngineStatus> checkStatus() async {
    final crepeHealthy = await _checkServerHealth(_crepeClient);
    final spiceHealthy = await _checkServerHealth(_spiceClient);
    
    return EngineStatus(
      crepeHealthy: crepeHealthy,
      spiceHealthy: spiceHealthy,
    );
  }
  
  Future<bool> _checkServerHealth(Dio client) async {
    try {
      final response = await client.get('/health');
      if (response.statusCode != 200) return false;
      final status = response.data['status'];
      // Treat 'healthy' as true, 'degraded' as usable but warn
      if (status == 'healthy') return true;
      if (status == 'degraded') {
        debugPrint('Server health degraded: self-test did not fully pass');
        return true; // allow but mark degraded
      }
      return false;
    } catch (e) {
      debugPrint('Server health check failed: $e');
      return false;
    }
  }
  
  /// CREPE 단일 분석
  Future<CrepeResult?> analyzeWithCrepe(Float32List audioData) async {
    try {
      print('🎵 [CREPE] 분석 시작 - 데이터 크기: ${audioData.length}');
      
      // 오디오 데이터 검증 (디버깅)
      final audioMax = audioData.reduce((a, b) => a.abs() > b.abs() ? a : b);
      final audioRMS = math.sqrt(audioData.map((x) => x * x).reduce((a, b) => a + b) / audioData.length);
      print('📊 [CREPE] 입력 오디오: max=${audioMax.toStringAsFixed(4)}, RMS=${audioRMS.toStringAsFixed(4)}');
      
      // Float32List를 안전한 Base64로 인코딩 (전처리 포함)
      final audioBase64 = _encodeAudioToBase64(audioData);
      print('🎵 [CREPE] Base64 인코딩 완료: ${audioBase64.length} 바이트');

      // 1) Try Schema v2 endpoint first
      try {
        final v2 = await _crepeClient.post('/analyze_v2', data: {
          'audio_base64': audioBase64,
          'sample_rate': 48000,
          'encoding': 'base64_float32',
        });
        if (v2.statusCode == 200 && v2.data != null && (v2.data['success'] == true)) {
          // Prefer primary f0 if present
          final pitch = v2.data['pitch'] as Map<String, dynamic>?;
          if (pitch != null) {
            final f0 = (pitch['f0'] as num?)?.toDouble() ?? 0.0;
            final confList = (pitch['confidence_adaptive'] as List?) ?? (pitch['confidence_raw'] as List?);
            double conf = 0.0;
            if (confList != null && confList.isNotEmpty) {
              // take max confidence frame
              final cl = confList.map((e) => (e as num).toDouble()).toList();
              conf = cl.reduce((a, b) => a > b ? a : b);
            }
            if (f0 > 0) {
              final result = CrepeResult(
                frequency: f0,
                confidence: conf,
                timestamp: DateTime.now(),
                stability: 0.8,
                voicedRatio: (v2.data['voicing']?['vad'] as num?)?.toDouble() ?? conf,
                processingTimeMs: 100.0,
              );
              print('✅ [CREPE v2] ${result.frequency.toStringAsFixed(1)}Hz conf=${result.confidence.toStringAsFixed(3)}');
              return result;
            }
          }
        }
      } catch (e) {
        // Fallthrough to legacy
        debugPrint('CREPE v2 analyze failed, falling back: $e');
      }

      // 2) Legacy endpoint (with new server also mirroring top-level fields)
      final response = await _crepeClient.post('/analyze', data: {
        'audio_base64': audioBase64,
        'sample_rate': 48000,
        'encoding': 'base64_float32'
      });

      print('🎵 [CREPE] 서버 응답: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        // legacy: server now includes top-level arrays
        final freqsAny = response.data['frequencies'] ?? response.data['data']?['frequencies'];
        final confsAny = response.data['confidence'] ?? response.data['data']?['confidence'];
        if (freqsAny is List && confsAny is List && freqsAny.isNotEmpty && confsAny.isNotEmpty) {
          final frequencies = freqsAny.map((e) => (e as num).toDouble()).toList();
          final confidences = confsAny.map((e) => (e as num).toDouble()).toList();
          // pick frame with highest confidence
          int bestIdx = 0;
          double maxConf = confidences[0];
          for (int i = 1; i < confidences.length; i++) {
            if (confidences[i] > maxConf) {
              maxConf = confidences[i];
              bestIdx = i;
            }
          }
          final result = CrepeResult(
            frequency: frequencies[bestIdx],
            confidence: maxConf,
            timestamp: DateTime.now(),
            stability: 0.8,
            voicedRatio: maxConf,
            processingTimeMs: 100.0,
          );
          print('✅ [CREPE] 분석 성공: ${result.frequency.toStringAsFixed(1)}Hz, 신뢰도: ${result.confidence}');
          return result;
        }
      }
      print('⚠️ [CREPE] 분석 실패 - 응답 형식 오류');
      return null;
    } catch (e) {
      if (e.toString().contains('silence or noise only')) {
        print('🔇 [CREPE] 침묵/노이즈만 감지됨 - 분석 생략');
        return null;
      }
      print('❌ [CREPE] 분석 오류: $e');
      return null;
    }
  }
  
  /// SPICE 단일 분석
  Future<SpiceResult?> analyzeWithSpice(Float32List audioData) async {
    try {
      print('🎵 [SPICE] 분석 시작 - 데이터 크기: ${audioData.length}');
      
      // Float32List를 안전한 Base64로 인코딩 (전처리 포함)
      final audioBase64 = _encodeAudioToBase64(audioData);
      print('🎵 [SPICE] Base64 인코딩 완료: ${audioBase64.length} 바이트');
      
      final response = await _spiceClient.post('/analyze', data: {
        'audio_base64': audioBase64,
        'sample_rate': 48000,
        'encoding': 'base64_float32'
      });
      
      print('🎵 [SPICE] 서버 응답: ${response.statusCode}');
      
      if (response.statusCode == 200 && response.data != null) {
        // SPICE 서버는 success와 data 구조로 응답
        if (response.data['success'] == true && response.data['data'] != null) {
          final data = response.data['data'];
          if (data['frequencies'] != null && data['confidence'] != null) {
            final frequencies = (data['frequencies'] as List).map((e) => (e as num).toDouble()).toList();
            final confidences = (data['confidence'] as List).map((e) => (e as num).toDouble()).toList();
            
            if (frequencies.isNotEmpty && confidences.isNotEmpty) {
              // 가장 높은 신뢰도의 주파수 선택
              int bestIdx = 0;
              double maxConf = confidences[0];
              for (int i = 1; i < confidences.length; i++) {
                if (confidences[i] > maxConf) {
                  maxConf = confidences[i];
                  bestIdx = i;
                }
              }
              
              // SPICE 주파수 보정 제거: 원본 주파수 그대로 사용
              final rawFreq = frequencies[bestIdx];
              final correctedFreq = rawFreq; // 보정 없이 원본 주파수 사용
              
              final result = SpiceResult(
                frequency: correctedFreq,
                confidence: maxConf,
                timestamp: DateTime.now(),
                multiplePitches: [MultiplePitch(
                  frequency: correctedFreq,
                  strength: maxConf,
                  confidence: maxConf,
                )],
                detectedPitchCount: 1,
                processingTimeMs: 100.0,  // 기본값
              );
              print('✅ [SPICE] 분석 성공: ${correctedFreq.toStringAsFixed(1)}Hz (원본: ${frequencies[bestIdx].toStringAsFixed(1)}Hz), 신뢰도: ${maxConf.toStringAsFixed(3)}');
              return result;
            }
          }
        }
      }
      print('⚠️ [SPICE] 분석 실패 - 응답 형식 오류');
      return null;
    } catch (e) {
      if (e.toString().contains('silence or noise only')) {
        print('🔇 [SPICE] 침묵/노이즈만 감지됨 - 분석 생략');
        return null;
      }
      print('❌ [SPICE] 분석 오류: $e');
      return null;
    }
  }
  
  /// 고정밀 단일 음정 분석 (SinglePitchTracker 사용)
  /// 단선 CREPE 분석 (단일 청크용)
  Future<double> analyzeSingleWithCREPE(Float32List audioData, {
    double sampleRate = 48000.0,
  }) async {
    try {
      // Base64 인코딩
      final audioBytes = audioData.buffer.asUint8List();
      final audioBase64 = base64Encode(audioBytes);
      
      // CREPE 서버로 요청
      final response = await _crepeClient.post('/analyze', data: {
        'audio_base64': audioBase64,
        'sample_rate': sampleRate,
      });
      
      if (response.statusCode == 200) {
        final data = response.data;
        final frequencies = List<double>.from(data['frequencies'] ?? []);
        final confidences = List<double>.from(data['confidence'] ?? []);
        
        if (frequencies.isNotEmpty && confidences.isNotEmpty) {
          // 가장 높은 신뢰도의 주파수 반환
          int bestIdx = 0;
          double maxConf = confidences[0];
          for (int i = 1; i < confidences.length; i++) {
            if (confidences[i] > maxConf) {
              maxConf = confidences[i];
              bestIdx = i;
            }
          }
          return frequencies[bestIdx];
        }
      }
      return 0;
    } catch (e) {
      print('❌ [CREPE] 서버 요청 실패: $e');
      return 0;
    }
  }
  
  /// 단선 멜로디에 최적화된 정확한 음정 분석
  Future<List<DualResult>> analyzeSinglePitchAccurate(Float32List audioData, {
    int windowSize = 24000,   // 0.5초 분량 (SinglePitchTracker 최적)
    int hopSize = 6000,       // 0.125초 간격 (75% 오버랩)
    double sampleRate = 48000.0,
  }) async {
    print('🎯 [DualEngine] analyzeSinglePitchAccurate 호출됨 - 오디오 길이: ${audioData.length} 샘플');
    
    if (audioData.length < windowSize) {
      print('⚠️ [SinglePitch] 오디오 데이터가 너무 짧음: ${audioData.length} < $windowSize');
      return [];
    }
    
    final numWindows = (audioData.length - windowSize) ~/ hopSize + 1;
    print('🎯 [SinglePitch] 고정밀 단일 음정 분석 시작: $numWindows개 윈도우');
    
    final results = <DualResult>[];
    
    for (int i = 0; i < numWindows; i++) {
      final startIdx = i * hopSize;
      final endIdx = math.min(startIdx + windowSize, audioData.length);
      
      if (endIdx - startIdx < windowSize) break;
      
      final window = audioData.sublist(startIdx, endIdx);
      final timeSeconds = startIdx / sampleRate;
      
      try {
        // SinglePitchTracker를 사용한 고정밀 분석
        final pitchResult = await pitchTracker.trackSinglePitch(
          Float32List.fromList(window),
          sampleRate: sampleRate,
        );
        
        final dualResult = DualResult(
          frequency: pitchResult.frequency,
          confidence: pitchResult.confidence,
          timestamp: DateTime.now(),
          timeSeconds: timeSeconds,
          // SinglePitchTracker 결과 추가 정보
          noteName: pitchResult.noteName,
          cents: pitchResult.cents,
          isAccurate: pitchResult.isAccurate,
          latencyMs: pitchResult.latencyMs,
        );
        
        results.add(dualResult);
        
        if (i % 10 == 0) {
          print('🎯 청크 $i 분석: ${pitchResult.frequency.toStringAsFixed(1)}Hz (${pitchResult.noteName}) 신뢰도: ${(pitchResult.confidence * 100).toStringAsFixed(0)}%');
        }
        
      } catch (e) {
        print('❌ [SinglePitch] 청크 $i 분석 실패: $e');
        
        // 실패한 경우 기본값 추가
        results.add(DualResult(
          frequency: 0,
          confidence: 0,
          timestamp: DateTime.now(),
          timeSeconds: timeSeconds,
        ));
      }
      
      // 진행 상황 로그
      if ((i + 1) % 20 == 0 || i == numWindows - 1) {
        print('📊 [SinglePitch] 진행: ${i + 1}/$numWindows 완료');
      }
    }
    
    print('✅ [SinglePitch] 고정밀 단일 음정 분석 완료: ${results.length}개 결과');
    return results;
  }

  /// 시간별 피치 분석 (기존 CREPE+SPICE 듀얼 엔진)
  Future<List<DualResult>> analyzeTimeBasedPitch(List<double> audioData, {
    int windowSize = 48000,  // 1초 분량 (CREPE/SPICE 최적)
    int hopSize = 48000,     // 1초 간격 (0% 오버랩)
    double sampleRate = 48000.0,
    double confidenceThreshold = 0.8,  // 기본 임계값
    double minimumNoteDuration = 0.8,   // 최소 음표 지속시간
    bool useHMM = false,                // HMM 기반 세그멘테이션 사용 여부
  }) async {
    final buffer = Float32List.fromList(audioData);
    if (buffer.length < windowSize) {
      print('⚠️ [DualEngine] 오디오 데이터가 너무 짧음: ${audioData.length} < $windowSize');
      return [];
    }
    
    final numWindows = (buffer.length - windowSize) ~/ hopSize + 1;
    print('🎵 [DualEngine] 시간별 분석 시작: $numWindows개 윈도우');
    
    // HMM 모드일 때는 더 촘촘하게 샘플링 (0.125s)
    if (useHMM) {
      hopSize = (sampleRate * 0.125).toInt();
      windowSize = math.max(windowSize, (sampleRate * 0.25).toInt()); // 0.25s 창
    }

    final results = <DualResult>[];
    int successCount = 0;
    int failCount = 0;
    
    // 순차적으로 처리하되 서버 호출은 병렬로
    for (int i = 0; i < numWindows; i++) {
      final startIdx = i * hopSize;
      final endIdx = math.min(startIdx + windowSize, buffer.length);
      
      if (endIdx - startIdx < windowSize) break;
      
      final chunk = Float32List.fromList(buffer.sublist(startIdx, endIdx));
      
      // 청크 통계 출력 (디버깅)
      if (i == 0 || i == numWindows ~/ 2 || i == numWindows - 1) {
        final chunkMax = chunk.reduce((a, b) => a.abs() > b.abs() ? a : b);
        final chunkRMS = math.sqrt(chunk.map((x) => x * x).reduce((a, b) => a + b) / chunk.length);
        print('📊 청크 $i 통계: max=${chunkMax.toStringAsFixed(4)}, RMS=${chunkRMS.toStringAsFixed(4)}');
      }
      
      final timeSeconds = startIdx / sampleRate;
      
      try {
        // 각 청크에 타임아웃 적용
        final result = await analyzeDual(chunk).timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            print('⏰ 청크 $i 분석 타임아웃');
            return null;
          },
        );
        
        // Adaptive confidence threshold 계산
        final adaptiveThresh = _computeAdaptiveThreshold(
          chunk,
          sampleRate: sampleRate,
          baseThreshold: confidenceThreshold,
        );

        if (result != null && result.frequency > 0 && result.confidence >= adaptiveThresh) {
          // 시간 정보를 추가한 새 결과 생성
          results.add(DualResult(
            frequency: result.frequency,
            confidence: result.confidence,
            timestamp: result.timestamp,
            crepeResult: result.crepeResult,
            spiceResult: result.spiceResult,
            recommendedEngine: result.recommendedEngine,
            analysisQuality: result.analysisQuality,
            timeSeconds: timeSeconds,
          ));
          
          successCount++;
          if (i % 5 == 0) { // 5개마다 로그
            print('✅ 청크 $i 분석 완료: ${result.frequency.toStringAsFixed(1)}Hz at ${timeSeconds.toStringAsFixed(2)}s (신뢰도: ${(result.confidence * 100).toInt()}%, 임계=${(adaptiveThresh * 100).toInt()}%)');
          }
        } else {
          failCount++;
          if (result?.confidence != null) {
            print('⚠️ 청크 $i 신뢰도 낮음: ${(result!.confidence * 100).toInt()}% < ${(adaptiveThresh * 100).toInt()}%');
          }
        }
      } catch (e) {
        print('❌ 청크 $i 분석 실패: $e');
        failCount++;
      }
      
      // 진행 상황 표시 (10개마다)
      if ((i + 1) % 10 == 0) {
        print('📊 진행: ${i + 1}/$numWindows 완료 (성공: $successCount, 실패: $failCount)');
      }
    }
    
    final successRate = (successCount / numWindows * 100).toStringAsFixed(1);
    print('📊 [DualEngine] 원본 분석 완료: ${results.length}개 결과 (성공률: $successRate%)');
    
    // 음표 통합: 기본 또는 HMM 고도화
    final consolidatedResults = useHMM
        ? _consolidateNotesHMM(
            results,
            minimumDuration: minimumNoteDuration,
            maxSlopeCentsPerSec: 300, // 글리산도 보호 (<= 300 cents/s)
            vibratoExtentCentsMin: 20,
            vibratoExtentCentsMax: 80,
            vibratoWindowSec: 1.0,
          )
        : _consolidateNotes(results, minimumNoteDuration);
    print('✅ [DualEngine] 음표 통합 완료: ${consolidatedResults.length}개 최종 결과 (${results.length}개에서 감소)');
    
    return consolidatedResults;
  }

  /// 적응형 신뢰도 임계값 계산 (RMS/ZCR/스펙트럼 평탄도/SNR 기반)
  double _computeAdaptiveThreshold(Float32List chunk, {required double sampleRate, double baseThreshold = 0.8}) {
    double thr = baseThreshold;

    // RMS as energy
    final rms = _calculateRMS(chunk);
    // ZCR
    final zcr = _calculateZCR(chunk);
    // SNR (간단 추정: 하위 10% 절대값 평균을 노이즈로 가정)
    final sortedAbs = chunk.map((e) => e.abs()).toList()..sort();
    final noiseCount = math.max(1, (sortedAbs.length * 0.1).toInt());
    double noiseFloor = 0.0;
    for (int i = 0; i < noiseCount; i++) { noiseFloor += sortedAbs[i]; }
    noiseFloor = noiseFloor / noiseCount;
    final signal = rms;
    final snrDb = (signal > 0 && noiseFloor > 0)
        ? 20.0 * (math.log(signal / noiseFloor) / math.ln10)
        : 0.0;

    // Spectral flatness on reduced frame (up to 2048)
    final flatness = _spectralFlatness(chunk, sampleRate: sampleRate, maxLen: 2048);

    // Heuristics
    if (snrDb >= 20) thr -= 0.05;
    if (snrDb < 10) thr += 0.10;

    if (zcr < 0.10) thr -= 0.05; // voiced-like
    if (zcr > 0.30) thr += 0.05; // unvoiced/noise-like

    if (flatness < 0.5) thr -= 0.05; // harmonic
    if (flatness > 0.8) thr += 0.10; // noise-like

    // Clamp
    thr = thr.clamp(0.5, 0.95);
    return thr;
  }

  /// 간단한 스펙트럼 평탄도 계산 (저비용용 축약 DFT)
  double _spectralFlatness(Float32List data, {required double sampleRate, int maxLen = 2048}) {
    final n = math.min(maxLen, data.length);
    if (n < 32) return 1.0;
    double geometricMean = 1.0;
    double arithmeticMean = 0.0;
    int count = 0;
    // naive DFT magnitude for first n/2 bins
    for (int k = 0; k < n ~/ 2; k++) {
      double real = 0.0, imag = 0.0;
      for (int t = 0; t < n; t++) {
        final angle = -2.0 * math.pi * k * t / n;
        final s = data[t];
        real += s * math.cos(angle);
        imag += s * math.sin(angle);
      }
      final mag = math.sqrt(real * real + imag * imag);
      if (mag > 0) {
        // use power measure for stability
        geometricMean *= math.pow(mag, 1.0 / (n / 2));
        arithmeticMean += mag;
        count++;
      }
    }
    if (count == 0) return 1.0;
    arithmeticMean /= count;
    if (arithmeticMean <= 1e-12) return 1.0;
    return (geometricMean / arithmeticMean).clamp(0.0, 1.0);
  }

  /// 음표 통합: 비슷한 연속 피치를 하나로 합침
  List<DualResult> _consolidateNotes(List<DualResult> results, double minimumDuration) {
    if (results.isEmpty) return results;
    
    final consolidated = <DualResult>[];
    DualResult? currentNote;
    double currentNoteStartTime = 0.0;
    
    for (final result in results) {
      final frequency = result.frequency;
      final time = result.timeSeconds ?? 0.0;
      
      if (currentNote == null) {
        // 첫 번째 음표
        currentNote = result;
        currentNoteStartTime = time;
      } else {
        // 현재 음표와 비슷한지 확인 (±5% 허용)
        final frequencyDiff = (frequency - currentNote.frequency).abs();
        final frequencyThreshold = currentNote.frequency * 0.05; // 5% 허용
        
        if (frequencyDiff <= frequencyThreshold) {
          // 같은 음표 계속 - 신뢰도가 더 높으면 업데이트
          if (result.confidence > currentNote.confidence) {
            currentNote = DualResult(
              frequency: result.frequency,
              confidence: result.confidence,
              timestamp: result.timestamp,
              crepeResult: result.crepeResult,
              spiceResult: result.spiceResult,
              recommendedEngine: result.recommendedEngine,
              analysisQuality: result.analysisQuality,
              timeSeconds: currentNoteStartTime, // 시작 시간 유지
            );
          }
        } else {
          // 새로운 음표 - 이전 음표가 최소 지속시간을 만족하는지 확인
          final noteDuration = time - currentNoteStartTime;
          if (noteDuration >= minimumDuration) {
            consolidated.add(currentNote);
          }
          
          // 새 음표 시작
          currentNote = result;
          currentNoteStartTime = time;
        }
      }
    }
    
    // 마지막 음표 추가 (최소 지속시간 확인)
    if (currentNote != null) {
      final lastTime = results.last.timeSeconds ?? 0.0;
      final noteDuration = lastTime - currentNoteStartTime;
      if (noteDuration >= minimumDuration) {
        consolidated.add(currentNote);
      }
    }
    
    return consolidated;
  }

  /// HMM 스타일 세그멘테이션: 전이비용 + 비브라토/글리산도 보호 규칙
  List<DualResult> _consolidateNotesHMM(
    List<DualResult> results, {
      required double minimumDuration,
      required double maxSlopeCentsPerSec,
      required double vibratoExtentCentsMin,
      required double vibratoExtentCentsMax,
      required double vibratoWindowSec,
    }
  ) {
    if (results.isEmpty) return results;
    results.sort((a, b) => (a.timeSeconds ?? 0).compareTo(b.timeSeconds ?? 0));

    final consolidated = <DualResult>[];
    DualResult? current;
    double startTime = 0.0;
    // buffer for vibrato window
    final window = <DualResult>[];

    double centsDelta(double f, double g) => 1200.0 * (math.log(f / g) / math.ln2);

    for (final r in results) {
      final t = r.timeSeconds ?? 0.0;
      if (current == null) {
        current = r;
        startTime = t;
        window.clear();
        window.add(r);
        continue;
      }

      // calculate slope and cents difference
      final dt = math.max(1e-3, t - (current.timeSeconds ?? 0.0));
      final centsDiff = centsDelta(r.frequency, current.frequency).abs();
      final slope = centsDiff / dt; // cents per second

      // Vibrato detection on window (~1s)
      window.add(r);
      // keep last W seconds
      while (window.isNotEmpty && t - (window.first.timeSeconds ?? 0.0) > vibratoWindowSec) {
        window.removeAt(0);
      }
      double vibratoStd = 0.0;
      if (window.length >= 4) {
        // compute mean freq over window
        final meanFreq = window.map((e) => e.frequency).reduce((a, b) => a + b) / window.length;
        final centsVals = window.map((e) => centsDelta(e.frequency, meanFreq)).toList();
        final meanCents = centsVals.reduce((a, b) => a + b) / centsVals.length;
        double varianceSum = 0.0;
        for (final v in centsVals) { varianceSum += (v - meanCents) * (v - meanCents); }
        vibratoStd = math.sqrt(varianceSum / centsVals.length).abs();
      }

      final isVibrato = vibratoStd >= vibratoExtentCentsMin && vibratoStd <= vibratoExtentCentsMax;
      final isGlissando = slope <= maxSlopeCentsPerSec;

      final sameNote = (centsDiff <= 50) || isVibrato || isGlissando;

      if (sameNote) {
        // merge by keeping higher confidence
        if (r.confidence > current.confidence) {
          current = DualResult(
            frequency: r.frequency,
            confidence: r.confidence,
            timestamp: r.timestamp,
            crepeResult: r.crepeResult,
            spiceResult: r.spiceResult,
            recommendedEngine: r.recommendedEngine,
            analysisQuality: r.analysisQuality,
            timeSeconds: startTime,
          );
        }
      } else {
        // finalize current if long enough
        final dur = (r.timeSeconds ?? t) - startTime;
        if (dur >= minimumDuration) {
          consolidated.add(current);
        }
        current = r;
        startTime = t;
        window.clear();
        window.add(r);
      }
    }

    if (current != null) {
      final lastTime = (results.last.timeSeconds ?? startTime);
      final dur = lastTime - startTime;
      if (dur >= minimumDuration) {
        consolidated.add(current);
      }
    }

    return consolidated;
  }

  /// 듀얼 엔진 분석 (무조건 병렬 실행)
  Future<DualResult?> analyzeDual(Float32List audioData) async {
    // v0.1: Prefer on-device CREPE (or local tracker) first for immediate UX
    try {
      final onDevice = await _onDeviceCrepe.analyzeWindow(audioData, sampleRate: 48000.0);
      // Adaptive gating: prefer on-device if confidence over local tau
      if (onDevice.confidence >= PipelinePresetV01.tauLocal && onDevice.frequency > 0) {
        return DualResult(
          frequency: onDevice.frequency,
          confidence: onDevice.confidence,
          timestamp: DateTime.now(),
          recommendedEngine: 'ONDEVICE',
        );
      }
    } catch (e) {
      debugPrint('On-device analysis failed: $e');
    }

    // Then, try server engines in parallel (CREPE/SPICE) and fuse
    final results = await Future.wait([
      analyzeWithCrepe(audioData).catchError((e) {
        print('⚠️ CREPE 실패: $e');
        return null;
      }),
      analyzeWithSpice(audioData).catchError((e) {
        print('⚠️ SPICE 실패: $e');
        return null;
      }),
    ], eagerError: false);

    final crepeResult = results[0] as CrepeResult?;
    final spiceResult = results[1] as SpiceResult?;

    return _fuseResults(crepeResult, spiceResult);
  }
  
  /// 오디오 복잡도 판단
  bool _isComplexAudio(Float32List audioData) {
    if (audioData.length < 100) return false;
    
    // 간단한 휴리스틱: RMS와 Zero-crossing rate
    final rms = _calculateRMS(audioData);
    final zcr = _calculateZCR(audioData);
    
    return rms > 0.05 && zcr > 0.1;
  }
  
  double _calculateRMS(Float32List data) {
    if (data.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (final sample in data) {
      sum += sample * sample;
    }
    return math.sqrt(sum / data.length);
  }
  
  double _calculateZCR(Float32List data) {
    if (data.length < 2) return 0.0;
    
    int crossings = 0;
    for (int i = 1; i < data.length; i++) {
      if ((data[i-1] >= 0) != (data[i] >= 0)) {
        crossings++;
      }
    }
    return crossings / data.length;
  }
  
  /// 오디오 전처리 (노이즈 감소, 정규화, 침묵 감지)
  Float32List _preprocessAudio(Float32List audioData) {
    if (audioData.isEmpty) return audioData;
    
    try {
      // 1. 침묵 감지
      if (_isSilence(audioData)) {
        debugPrint('🔇 [Preprocessing] 침묵 구간 감지됨');
        return Float32List(0); // 빈 배열 반환하여 분석 생략
      }
      
      // 2. 노이즈 감소 (간단한 하이패스 필터)
      final filtered = _applyHighPassFilter(audioData);
      
      // 3. 정규화 (RMS 기반)
      final normalized = _normalizeAudio(filtered);
      
      // 4. 윈도잉 (Hamming window)
      final windowed = _applyHammingWindow(normalized);
      
      debugPrint('🎛️ [Preprocessing] 전처리 완료 - 원본: ${audioData.length}, 처리 후: ${windowed.length}');
      return windowed;
      
    } catch (e) {
      debugPrint('❌ [Preprocessing] 전처리 실패: $e');
      return audioData; // 실패시 원본 반환
    }
  }
  
  /// 침묵 감지 (RMS 기반)
  bool _isSilence(Float32List audioData, {double threshold = 0.01}) {
    if (audioData.isEmpty) return true;
    
    final rms = _calculateRMS(audioData);
    return rms < threshold;
  }
  
  /// 간단한 하이패스 필터 (80Hz 이하 주파수 제거)
  Float32List _applyHighPassFilter(Float32List audioData, {double cutoffHz = 80.0}) {
    if (audioData.length < 2) return audioData;
    
    try {
      // 간단한 1차 IIR 하이패스 필터
      const double sampleRate = 48000.0;
      final double rc = 1.0 / (2.0 * math.pi * cutoffHz);
      final double dt = 1.0 / sampleRate;
      final double alpha = rc / (rc + dt);
      
      final filtered = Float32List(audioData.length);
      filtered[0] = audioData[0];
      
      for (int i = 1; i < audioData.length; i++) {
        filtered[i] = alpha * (filtered[i-1] + audioData[i] - audioData[i-1]);
      }
      
      return filtered;
    } catch (e) {
      debugPrint('❌ 하이패스 필터 실패: $e');
      return audioData;
    }
  }
  
  /// RMS 정규화
  Float32List _normalizeAudio(Float32List audioData, {double targetRMS = 0.3}) {
    if (audioData.isEmpty) return audioData;
    
    try {
      final currentRMS = _calculateRMS(audioData);
      if (currentRMS < 1e-6) return audioData; // 너무 작은 신호는 정규화하지 않음
      
      final gain = targetRMS / currentRMS;
      final normalized = Float32List(audioData.length);
      
      for (int i = 0; i < audioData.length; i++) {
        normalized[i] = math.max(-1.0, math.min(1.0, audioData[i] * gain)); // 클리핑 방지
      }
      
      return normalized;
    } catch (e) {
      debugPrint('❌ 정규화 실패: $e');
      return audioData;
    }
  }
  
  /// Hamming 윈도우 적용 (스펙트럼 누수 방지)
  Float32List _applyHammingWindow(Float32List audioData) {
    if (audioData.isEmpty) return audioData;
    
    try {
      final windowed = Float32List(audioData.length);
      final length = audioData.length;
      
      for (int i = 0; i < length; i++) {
        final window = 0.54 - 0.46 * math.cos(2.0 * math.pi * i / (length - 1));
        windowed[i] = audioData[i] * window;
      }
      
      return windowed;
    } catch (e) {
      debugPrint('❌ 윈도잉 실패: $e');
      return audioData;
    }
  }
  
  /// Float32List를 안전한 Base64로 인코딩
  String _encodeAudioToBase64(Float32List audioData) {
    try {
      // 전처리 적용
      final preprocessed = _preprocessAudio(audioData);
      if (preprocessed.isEmpty) {
        // 침묵이나 노이즈만 있는 경우 기본 응답 반환
        throw Exception('Audio preprocessing detected silence or noise only');
      }
      
      // Float32를 바이트 배열로 변환
      final byteData = ByteData(preprocessed.length * 4);
      for (int i = 0; i < preprocessed.length; i++) {
        byteData.setFloat32(i * 4, preprocessed[i], Endian.little);
      }
      
      // Base64로 인코딩
      final bytes = byteData.buffer.asUint8List();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Audio encoding failed: $e');
      rethrow;
    }
  }
  
  /// JSON 응답 안전성 검증
  bool _isValidJsonResponse(Map<String, dynamic> data) {
    try {
      // 필수 필드 확인
      if (!data.containsKey('success') || !data.containsKey('data')) {
        return false;
      }
      
      // 데이터 타입 검증
      final success = data['success'];
      if (success is! bool) return false;
      
      // 성공 응답인 경우 데이터 필드 검증
      if (success && data['data'] == null) {
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('JSON validation failed: $e');
      return false;
    }
  }
  
  /// 결과 융합
  DualResult? _fuseResults(CrepeResult? crepe, SpiceResult? spice) {
    if (crepe == null && spice == null) return null;
    
    // 주요 피치 선택 (CREPE 우선)
    final mainFreq = crepe?.frequency ?? spice?.frequency ?? 0.0;
    final mainConf = crepe?.confidence ?? spice?.confidence ?? 0.0;
    
    // 추천 엔진 결정
    String recommended = 'CREPE';
    if (spice != null && spice.isChord) {
      recommended = 'SPICE';
    }
    
    // 분석 품질 계산
    double quality = 0.0;
    if (crepe != null) quality += crepe.confidence * 0.7;
    if (spice != null) quality += spice.confidence * 0.3;
    
    return DualResult(
      frequency: mainFreq,
      confidence: mainConf,
      timestamp: DateTime.now(),
      crepeResult: crepe,
      spiceResult: spice,
      recommendedEngine: recommended,
      analysisQuality: quality,
    );
  }
  
  
  /// 결과 캐싱 (LRU 방식)
  void _cacheResult(String key, DualResult result) {
    if (_pitchCache.length >= _maxCacheSize) {
      // 가장 오래된 항목 제거 (단순 FIFO)
      final oldestKey = _pitchCache.keys.first;
      _pitchCache.remove(oldestKey);
    }
    
    _pitchCache[key] = result;
  }

  /// 앱 종료시 호출할 정리 메서드 (최적화 버전)
  Future<void> cleanup() async {
    debugPrint('🧹 [DualEngineService] Starting optimized cleanup...');
    
    try {
      // 배치 타이머 정지
      _batchTimer?.cancel();
      _batchTimer = null;
      
      // 진행 중인 요청들 정리
      for (final request in _crepeQueue) {
        if (!request.completer.isCompleted) {
          request.completer.completeError('Service disposed');
        }
      }
      for (final request in _spiceQueue) {
        if (!request.completer.isCompleted) {
          request.completer.completeError('Service disposed');
        }
      }
      
      // 캐시 정리
      _pitchCache.clear();
      _crepeQueue.clear();
      _spiceQueue.clear();
      
      // HTTP/2 클라이언트 정리 (안전하게)
      try {
        _http2CrepeClient.close(force: true);
        _http2SpiceClient.close(force: true);
      } catch (e) {
        debugPrint('HTTP/2 클라이언트 정리 실패: $e');
      }
      
      // 기존 HTTP 클라이언트 정리 (안전하게)
      try {
        _crepeClient.close(force: true);
        _spiceClient.close(force: true);
      } catch (e) {
        debugPrint('HTTP 클라이언트 정리 실패: $e');
      }
      
      // 연결 풀 정리
      _connectionPool.clear();
      
      // SinglePitchTracker 정리
      if (_pitchTracker != null) {
        try {
          // SinglePitchTracker에 dispose 메서드가 있다면 호출
          _pitchTracker = null;
        } catch (e) {
          debugPrint('PitchTracker 정리 실패: $e');
        }
      }
      
      debugPrint('✅ [DualEngineService] Cleanup completed');
    } catch (e) {
      debugPrint('❌ [DualEngineService] Cleanup failed: $e');
    }
  }
  
  /// 리소스 정리 (dispose 패턴)
  void dispose() {
    cleanup();
  }
}

/// 엔진 상태
class EngineStatus {
  final bool crepeHealthy;
  final bool spiceHealthy;
  
  EngineStatus({
    required this.crepeHealthy,
    required this.spiceHealthy,
  });
  
  bool get anyHealthy => crepeHealthy || spiceHealthy;
  bool get bothHealthy => crepeHealthy && spiceHealthy;
  
  String get statusText {
    if (bothHealthy) return "두 엔진 모두 정상";
    if (crepeHealthy) return "CREPE만 정상";
    if (spiceHealthy) return "SPICE만 정상";
    return "두 엔진 모두 오프라인";
  }
}

/// 실시간 스트림
class RealtimeAnalysisStream {
  final DualEngineService _service;
  
  RealtimeAnalysisStream._internal(this._service);
  
  final StreamController<DualResult> _controller = 
      StreamController<DualResult>.broadcast();
  
  Stream<DualResult> get stream => _controller.stream;
  
  Timer? _timer;
  final List<Float32List> _buffer = [];
  static const int _maxBufferSize = 3;
  bool _isDisposed = false;
  
  void startStream() {
    if (_isDisposed) return;
    
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_isDisposed) {
        _processBuffer();
      }
    });
  }
  
  void addAudioChunk(Float32List chunk) {
    if (_isDisposed) return;
    
    _buffer.add(chunk);
    if (_buffer.length > _maxBufferSize) {
      _buffer.removeAt(0);
    }
  }
  
  void _processBuffer() async {
    if (_buffer.isEmpty || _isDisposed) return;
    
    try {
      // 버퍼 결합 (안전한 크기 체크)
      final totalLength = _buffer.fold<int>(0, (sum, chunk) => sum + chunk.length);
      if (totalLength <= 0) return;
      
      final combined = Float32List(totalLength);
      
      int offset = 0;
      for (final chunk in _buffer) {
        if (_isDisposed) return; // 중간에 dispose된 경우 즉시 반환
        
        if (offset + chunk.length <= combined.length) {
          combined.setRange(offset, offset + chunk.length, chunk);
          offset += chunk.length;
        }
      }
      
      // 분석 실행 (dispose 체크)
      if (!_isDisposed) {
        final result = await _service.analyzeDual(combined);
        if (result != null && !_isDisposed && !_controller.isClosed) {
          _controller.add(result);
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        debugPrint('❌ [RealtimeAnalysisStream] Process buffer error: $e');
      }
    }
  }
  
  void stopStream() {
    _timer?.cancel();
    _timer = null;
    _buffer.clear();
  }
  
  void dispose() {
    if (_isDisposed) return;
    
    _isDisposed = true;
    stopStream();
    
    // StreamController 안전하게 닫기
    if (!_controller.isClosed) {
      _controller.close();
    }
    
    debugPrint('✅ [RealtimeAnalysisStream] Disposed successfully');
  }
}

/// 배치 요청 클래스
class BatchRequest {
  final Float32List audioData;
  final double sampleRate;
  final int batchId;
  final Completer<DualResult> completer;
  
  BatchRequest({
    required this.audioData,
    required this.sampleRate,
    required this.batchId,
    required this.completer,
  });
}
