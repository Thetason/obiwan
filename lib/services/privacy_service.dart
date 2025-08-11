import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

/// Privacy and Data Hygiene Service
/// 데이터 위생, 프라이버시 보호, 보안 저장
class PrivacyService {
  // 프라이버시 설정 키
  static const String kPrivacyPolicyAcceptedKey = 'privacy_policy_accepted_v1';
  static const String kDataRetentionKey = 'data_retention_days';
  static const String kRawAudioStorageKey = 'raw_audio_storage_enabled';
  static const String kCloudBackupKey = 'cloud_backup_enabled';
  static const String kAnonymousAnalyticsKey = 'anonymous_analytics_enabled';
  
  // 기본 설정
  static const int kDefaultRetentionDays = 30;
  static const double kMinSNRThreshold = 10.0; // dB
  static const double kMaxClippingRatio = 0.01; // 1%
  static const int kMinQualitySamples = 100;
  
  // 암호화 키 (실제로는 안전한 keychain/keystore 사용 권장)
  static const String _encryptionSalt = 'obi-wan-v3-2025';
  
  // 현재 설정
  late PrivacySettings _settings;
  final DataSanitizer _sanitizer = DataSanitizer();
  final StorageManager _storage = StorageManager();
  
  /// 초기화
  Future<void> initialize() async {
    print('🔒 프라이버시 서비스 초기화');
    
    await _loadSettings();
    await _cleanupOldData();
    
    print('📊 현재 프라이버시 설정:');
    print(_settings);
  }
  
  /// 설정 로드
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    _settings = PrivacySettings(
      policyAccepted: prefs.getBool(kPrivacyPolicyAcceptedKey) ?? false,
      retentionDays: prefs.getInt(kDataRetentionKey) ?? kDefaultRetentionDays,
      rawAudioStorageEnabled: prefs.getBool(kRawAudioStorageKey) ?? false,
      cloudBackupEnabled: prefs.getBool(kCloudBackupKey) ?? false,
      anonymousAnalyticsEnabled: prefs.getBool(kAnonymousAnalyticsKey) ?? true,
    );
  }
  
  /// 설정 저장
  Future<void> saveSettings(PrivacySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool(kPrivacyPolicyAcceptedKey, settings.policyAccepted);
    await prefs.setInt(kDataRetentionKey, settings.retentionDays);
    await prefs.setBool(kRawAudioStorageKey, settings.rawAudioStorageEnabled);
    await prefs.setBool(kCloudBackupKey, settings.cloudBackupEnabled);
    await prefs.setBool(kAnonymousAnalyticsKey, settings.anonymousAnalyticsEnabled);
    
    _settings = settings;
    
    print('💾 프라이버시 설정 저장 완료');
  }
  
  /// 오래된 데이터 정리
  Future<void> _cleanupOldData() async {
    print('🧾 오래된 데이터 정리 중...');
    
    final cutoffDate = DateTime.now().subtract(
      Duration(days: _settings.retentionDays),
    );
    
    // 오래된 오디오 파일 삭제
    int deletedFiles = await _storage.deleteOldFiles(cutoffDate);
    
    if (deletedFiles > 0) {
      print('🗑️ ${deletedFiles}개의 오래된 파일 삭제');
    }
  }
  
  /// 오디오 데이터 처리 (데이터 위생)
  Future<ProcessedAudioData?> processAudioData({
    required List<double> rawAudio,
    required double sampleRate,
    Map<String, dynamic>? metadata,
  }) async {
    print('🎧 오디오 데이터 처리 시작');
    
    // 1. 품질 필터링
    final qualityCheck = _sanitizer.checkQuality(
      rawAudio,
      sampleRate: sampleRate,
    );
    
    if (!qualityCheck.isAcceptable) {
      print('⚠️ 품질 기준 미달: ${qualityCheck.reason}');
      return null;
    }
    
    // 2. 개인정보 제거
    final sanitized = _sanitizer.sanitizeAudio(
      rawAudio,
      removeIdentifiers: true,
      normalizeAmplitude: true,
    );
    
    // 3. 필수 특징만 추출 (Mel-spectrogram, pitch curve)
    final features = await _extractMinimalFeatures(
      sanitized,
      sampleRate: sampleRate,
    );
    
    // 4. 메타데이터 비식별화
    final anonymizedMetadata = _anonymizeMetadata(metadata);
    
    // 5. 암호화 저장 (선택적)
    String? storageId;
    if (_settings.rawAudioStorageEnabled) {
      // 원음 저장 (암호화)
      storageId = await _storage.saveEncrypted(
        data: sanitized,
        type: StorageType.rawAudio,
      );
    } else {
      // 특징만 저장
      storageId = await _storage.saveFeatures(
        features: features,
        metadata: anonymizedMetadata,
      );
    }
    
    print('✅ 데이터 처리 완료 (ID: $storageId)');
    
    return ProcessedAudioData(
      id: storageId!,
      features: features,
      metadata: anonymizedMetadata,
      quality: qualityCheck,
      timestamp: DateTime.now(),
    );
  }
  
  /// 최소 특징 추출
  Future<AudioFeatures> _extractMinimalFeatures(
    List<double> audio,
    {required double sampleRate}
  ) async {
    // Mel-spectrogram 계산 (간단한 버전)
    final melSpec = _calculateMelSpectrogram(
      audio,
      sampleRate: sampleRate,
      nMels: 40,
      hopLength: 512,
    );
    
    // 피치 커브 추출
    final pitchCurve = _extractPitchCurve(
      audio,
      sampleRate: sampleRate,
      hopLength: 512,
    );
    
    // 전체 통계
    final stats = AudioStatistics(
      duration: audio.length / sampleRate,
      meanAmplitude: audio.map((s) => s.abs()).reduce((a, b) => a + b) / audio.length,
      maxAmplitude: audio.map((s) => s.abs()).reduce(math.max),
      silenceRatio: audio.where((s) => s.abs() < 0.01).length / audio.length,
    );
    
    return AudioFeatures(
      melSpectrogram: melSpec,
      pitchCurve: pitchCurve,
      statistics: stats,
    );
  }
  
  /// Mel-spectrogram 계산
  List<List<double>> _calculateMelSpectrogram(
    List<double> audio,
    {required double sampleRate, required int nMels, required int hopLength}
  ) {
    // 간단한 Mel-spectrogram 구현
    // 실제로는 librosa 같은 전문 라이브러리 사용 권장
    final melSpec = <List<double>>[];
    
    for (int i = 0; i < audio.length - hopLength; i += hopLength) {
      final frame = audio.sublist(i, i + hopLength);
      final spectrum = _fft(frame);
      final melBins = _melFilterBank(spectrum, nMels);
      melSpec.add(melBins);
    }
    
    return melSpec;
  }
  
  /// 간단한 FFT (실제로는 FFT 라이브러리 사용)
  List<double> _fft(List<double> frame) {
    // DFT 간단 구현
    final spectrum = List<double>.filled(frame.length ~/ 2, 0);
    
    for (int k = 0; k < spectrum.length; k++) {
      double real = 0, imag = 0;
      for (int n = 0; n < frame.length; n++) {
        final angle = -2 * math.pi * k * n / frame.length;
        real += frame[n] * math.cos(angle);
        imag += frame[n] * math.sin(angle);
      }
      spectrum[k] = math.sqrt(real * real + imag * imag);
    }
    
    return spectrum;
  }
  
  /// Mel 필터 뱅크
  List<double> _melFilterBank(List<double> spectrum, int nMels) {
    final melBins = List<double>.filled(nMels, 0);
    
    // 간단한 평균 풀링
    final binSize = spectrum.length ~/ nMels;
    for (int i = 0; i < nMels; i++) {
      double sum = 0;
      int count = 0;
      
      for (int j = i * binSize; j < math.min((i + 1) * binSize, spectrum.length); j++) {
        sum += spectrum[j];
        count++;
      }
      
      melBins[i] = count > 0 ? sum / count : 0;
    }
    
    return melBins;
  }
  
  /// 피치 커브 추출
  List<double> _extractPitchCurve(
    List<double> audio,
    {required double sampleRate, required int hopLength}
  ) {
    final pitchCurve = <double>[];
    
    for (int i = 0; i < audio.length - hopLength * 2; i += hopLength) {
      final frame = audio.sublist(i, i + hopLength * 2);
      final pitch = _estimatePitch(frame, sampleRate);
      pitchCurve.add(pitch);
    }
    
    return pitchCurve;
  }
  
  /// 간단한 피치 추정 (autocorrelation)
  double _estimatePitch(List<double> frame, double sampleRate) {
    const minPeriod = 40; // ~1000Hz @ 44.1kHz
    const maxPeriod = 400; // ~100Hz @ 44.1kHz
    
    double maxCorr = 0;
    int bestPeriod = 0;
    
    for (int period = minPeriod; period <= maxPeriod && period < frame.length; period++) {
      double corr = 0;
      for (int i = 0; i < frame.length - period; i++) {
        corr += frame[i] * frame[i + period];
      }
      
      if (corr > maxCorr) {
        maxCorr = corr;
        bestPeriod = period;
      }
    }
    
    return bestPeriod > 0 ? sampleRate / bestPeriod : 0;
  }
  
  /// 메타데이터 비식별화
  Map<String, dynamic> _anonymizeMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return {};
    
    final anonymized = <String, dynamic>{};
    
    // 허용된 필드만 포함
    const allowedFields = [
      'duration',
      'sample_rate',
      'recording_quality',
      'device_type', // iOS/Android/Web만, 모델명 제외
      'app_version',
      'session_id', // 해시된 ID
    ];
    
    for (final field in allowedFields) {
      if (metadata.containsKey(field)) {
        var value = metadata[field];
        
        // 추가 새니타이징
        if (field == 'device_type') {
          value = _generalizeDeviceType(value.toString());
        } else if (field == 'session_id') {
          value = _hashString(value.toString());
        }
        
        anonymized[field] = value;
      }
    }
    
    // 타임스탬프 추가 (날짜만, 시간 제외)
    anonymized['date'] = DateTime.now().toIso8601String().split('T')[0];
    
    return anonymized;
  }
  
  /// 디바이스 타입 일반화
  String _generalizeDeviceType(String deviceType) {
    if (deviceType.toLowerCase().contains('iphone') || 
        deviceType.toLowerCase().contains('ipad')) {
      return 'iOS';
    } else if (deviceType.toLowerCase().contains('android')) {
      return 'Android';
    } else if (deviceType.toLowerCase().contains('web')) {
      return 'Web';
    }
    return 'Unknown';
  }
  
  /// 문자열 해싱
  String _hashString(String input) {
    final bytes = utf8.encode(input + _encryptionSalt);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // 짧은 해시
  }
  
  /// 데이터 삭제 요청
  Future<bool> deleteUserData({bool includeProfile = false}) async {
    print('🗑️ 사용자 데이터 삭제 요청');
    
    try {
      // 오디오 데이터 삭제
      await _storage.deleteAllUserData();
      
      // 프로필 삭제 (선택적)
      if (includeProfile) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      }
      
      print('✅ 모든 사용자 데이터가 삭제되었습니다');
      return true;
      
    } catch (e) {
      print('❌ 데이터 삭제 실패: $e');
      return false;
    }
  }
  
  /// 현재 설정 가져오기
  PrivacySettings get settings => _settings;
  
  /// 데이터 사용량 통계
  Future<DataUsageStats> getDataUsageStats() async {
    return await _storage.calculateUsageStats();
  }
}

/// 데이터 새니타이저
class DataSanitizer {
  /// 품질 체크
  QualityCheck checkQuality(
    List<double> audio,
    {required double sampleRate}
  ) {
    // SNR 계산
    final signal = audio.map((s) => s * s).reduce((a, b) => a + b) / audio.length;
    final noise = _estimateNoise(audio);
    final snr = 10 * math.log(signal / math.max(noise, 1e-10)) / math.ln10;
    
    // 클리핑 체크
    final clippedSamples = audio.where((s) => s.abs() >= 0.99).length;
    final clippingRatio = clippedSamples / audio.length;
    
    // 무음 비율
    final silentSamples = audio.where((s) => s.abs() < 0.01).length;
    final silenceRatio = silentSamples / audio.length;
    
    // 판정
    bool isAcceptable = true;
    String? reason;
    
    if (snr < PrivacyService.kMinSNRThreshold) {
      isAcceptable = false;
      reason = 'SNR too low: ${snr.toStringAsFixed(1)}dB';
    } else if (clippingRatio > PrivacyService.kMaxClippingRatio) {
      isAcceptable = false;
      reason = 'Too much clipping: ${(clippingRatio * 100).toStringAsFixed(1)}%';
    } else if (silenceRatio > 0.8) {
      isAcceptable = false;
      reason = 'Too much silence: ${(silenceRatio * 100).toStringAsFixed(1)}%';
    } else if (audio.length < PrivacyService.kMinQualitySamples) {
      isAcceptable = false;
      reason = 'Too few samples: ${audio.length}';
    }
    
    return QualityCheck(
      isAcceptable: isAcceptable,
      snr: snr,
      clippingRatio: clippingRatio,
      silenceRatio: silenceRatio,
      reason: reason,
    );
  }
  
  /// 노이즈 추정
  double _estimateNoise(List<double> audio) {
    // 하위 10% 샘플의 평균을 노이즈로 간주
    final sorted = List<double>.from(audio.map((s) => s.abs()))..sort();
    final noiseFloor = sorted.take(sorted.length ~/ 10);
    
    if (noiseFloor.isEmpty) return 0;
    
    final sum = noiseFloor.reduce((a, b) => a + b);
    return sum / noiseFloor.length;
  }
  
  /// 오디오 새니타이징
  List<double> sanitizeAudio(
    List<double> audio,
    {bool removeIdentifiers = true, bool normalizeAmplitude = true}
  ) {
    var sanitized = List<double>.from(audio);
    
    // 진폭 정규화
    if (normalizeAmplitude) {
      final maxAmp = sanitized.map((s) => s.abs()).reduce(math.max);
      if (maxAmp > 0) {
        sanitized = sanitized.map((s) => s / maxAmp * 0.9).toList();
      }
    }
    
    // 개인 식별 패턴 제거 (간단한 랜덤화)
    if (removeIdentifiers) {
      // 시작/끝 부분 트리밍 (무음 제거)
      int startIdx = 0, endIdx = sanitized.length - 1;
      
      while (startIdx < sanitized.length && sanitized[startIdx].abs() < 0.01) {
        startIdx++;
      }
      
      while (endIdx > startIdx && sanitized[endIdx].abs() < 0.01) {
        endIdx--;
      }
      
      if (startIdx < endIdx) {
        sanitized = sanitized.sublist(startIdx, endIdx + 1);
      }
    }
    
    return sanitized;
  }
}

/// 저장소 관리자
class StorageManager {
  /// 암호화 저장
  Future<String> saveEncrypted({
    required List<double> data,
    required StorageType type,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final id = _generateId();
    final file = File('${dir.path}/${type.name}/$id.enc');
    
    // 디렉토리 생성
    await file.parent.create(recursive: true);
    
    // 간단한 XOR 암호화 (실제로는 AES 사용 권장)
    final encrypted = _simpleEncrypt(data);
    await file.writeAsBytes(encrypted);
    
    return id;
  }
  
  /// 특징 저장
  Future<String> saveFeatures({
    required AudioFeatures features,
    required Map<String, dynamic> metadata,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final id = _generateId();
    final file = File('${dir.path}/features/$id.json');
    
    await file.parent.create(recursive: true);
    
    final data = {
      'features': features.toJson(),
      'metadata': metadata,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await file.writeAsString(json.encode(data));
    
    return id;
  }
  
  /// 오래된 파일 삭제
  Future<int> deleteOldFiles(DateTime cutoffDate) async {
    final dir = await getApplicationDocumentsDirectory();
    int deletedCount = 0;
    
    for (final type in StorageType.values) {
      final typeDir = Directory('${dir.path}/${type.name}');
      if (await typeDir.exists()) {
        await for (final file in typeDir.list()) {
          if (file is File) {
            final stat = await file.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              await file.delete();
              deletedCount++;
            }
          }
        }
      }
    }
    
    return deletedCount;
  }
  
  /// 모든 사용자 데이터 삭제
  Future<void> deleteAllUserData() async {
    final dir = await getApplicationDocumentsDirectory();
    
    for (final type in StorageType.values) {
      final typeDir = Directory('${dir.path}/${type.name}');
      if (await typeDir.exists()) {
        await typeDir.delete(recursive: true);
      }
    }
  }
  
  /// 사용량 통계
  Future<DataUsageStats> calculateUsageStats() async {
    final dir = await getApplicationDocumentsDirectory();
    int fileCount = 0;
    int totalBytes = 0;
    
    for (final type in StorageType.values) {
      final typeDir = Directory('${dir.path}/${type.name}');
      if (await typeDir.exists()) {
        await for (final file in typeDir.list()) {
          if (file is File) {
            fileCount++;
            totalBytes += await file.length();
          }
        }
      }
    }
    
    return DataUsageStats(
      fileCount: fileCount,
      totalBytes: totalBytes,
      totalMegabytes: totalBytes / (1024 * 1024),
    );
  }
  
  /// ID 생성
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
           '_' +
           math.Random().nextInt(10000).toString();
  }
  
  /// 간단한 암호화 (실제로는 적절한 암호화 라이브러리 사용)
  Uint8List _simpleEncrypt(List<double> data) {
    final bytes = Float32List.fromList(data).buffer.asUint8List();
    final key = utf8.encode(PrivacyService._encryptionSalt);
    
    final encrypted = Uint8List(bytes.length);
    for (int i = 0; i < bytes.length; i++) {
      encrypted[i] = bytes[i] ^ key[i % key.length];
    }
    
    return encrypted;
  }
}

// 데이터 타입들

/// 프라이버시 설정
class PrivacySettings {
  final bool policyAccepted;
  final int retentionDays;
  final bool rawAudioStorageEnabled;
  final bool cloudBackupEnabled;
  final bool anonymousAnalyticsEnabled;
  
  const PrivacySettings({
    required this.policyAccepted,
    required this.retentionDays,
    required this.rawAudioStorageEnabled,
    required this.cloudBackupEnabled,
    required this.anonymousAnalyticsEnabled,
  });
  
  @override
  String toString() => '''
Privacy Settings:
  Policy Accepted: $policyAccepted
  Data Retention: $retentionDays days
  Raw Audio Storage: ${rawAudioStorageEnabled ? 'Enabled' : 'Disabled'}
  Cloud Backup: ${cloudBackupEnabled ? 'Enabled' : 'Disabled'}
  Anonymous Analytics: ${anonymousAnalyticsEnabled ? 'Enabled' : 'Disabled'}
''';
}

/// 품질 체크 결과
class QualityCheck {
  final bool isAcceptable;
  final double snr;
  final double clippingRatio;
  final double silenceRatio;
  final String? reason;
  
  const QualityCheck({
    required this.isAcceptable,
    required this.snr,
    required this.clippingRatio,
    required this.silenceRatio,
    this.reason,
  });
}

/// 처리된 오디오 데이터
class ProcessedAudioData {
  final String id;
  final AudioFeatures features;
  final Map<String, dynamic> metadata;
  final QualityCheck quality;
  final DateTime timestamp;
  
  const ProcessedAudioData({
    required this.id,
    required this.features,
    required this.metadata,
    required this.quality,
    required this.timestamp,
  });
}

/// 오디오 특징
class AudioFeatures {
  final List<List<double>> melSpectrogram;
  final List<double> pitchCurve;
  final AudioStatistics statistics;
  
  const AudioFeatures({
    required this.melSpectrogram,
    required this.pitchCurve,
    required this.statistics,
  });
  
  Map<String, dynamic> toJson() => {
    'mel_spectrogram': melSpectrogram,
    'pitch_curve': pitchCurve,
    'statistics': statistics.toJson(),
  };
}

/// 오디오 통계
class AudioStatistics {
  final double duration;
  final double meanAmplitude;
  final double maxAmplitude;
  final double silenceRatio;
  
  const AudioStatistics({
    required this.duration,
    required this.meanAmplitude,
    required this.maxAmplitude,
    required this.silenceRatio,
  });
  
  Map<String, dynamic> toJson() => {
    'duration': duration,
    'mean_amplitude': meanAmplitude,
    'max_amplitude': maxAmplitude,
    'silence_ratio': silenceRatio,
  };
}

/// 저장소 타입
enum StorageType {
  rawAudio,
  features,
  profile,
  cache,
}

/// 데이터 사용량 통계
class DataUsageStats {
  final int fileCount;
  final int totalBytes;
  final double totalMegabytes;
  
  const DataUsageStats({
    required this.fileCount,
    required this.totalBytes,
    required this.totalMegabytes,
  });
  
  @override
  String toString() => '''
Data Usage:
  Files: $fileCount
  Size: ${totalMegabytes.toStringAsFixed(2)} MB
''';
}