import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../core/advanced_pitch_tracker.dart';

/// User Voice Profile Service
/// 사용자 맞춤 프로필 생성 및 관리
/// 개인화된 피치 추적 정확도 향상
class UserProfileService {
  static const String kProfileKey = 'user_voice_profile_v1';
  static const String kCalibrationKey = 'calibration_history';
  static const String kAdapterKey = 'model_adapter_params';
  
  // 프로필 파라미터
  static const int kMinCalibrationSamples = 100;
  static const int kProfileHistoryDays = 30;
  static const double kConfidenceThreshold = 0.7;
  
  // 어댑터 파라미터 (경량 개인화)
  static const int kAdapterSize = 128; // 128차원 어댑터 벡터
  static const double kLearningRate = 0.01;
  static const int kMaxAdapterUpdates = 100;
  
  // 현재 프로필
  UserVoiceProfile? _currentProfile;
  VoiceAdapter? _modelAdapter;
  final List<CalibrationSession> _calibrationHistory = [];
  
  // 통계
  final VoiceStatistics _statistics = VoiceStatistics();
  
  /// 초기화 및 프로필 로드
  Future<void> initialize() async {
    print('👤 사용자 프로필 서비스 초기화');
    
    await loadProfile();
    await loadAdapter();
    
    if (_currentProfile != null) {
      print('✅ 기존 프로필 로드 완료');
      print(_currentProfile);
    } else {
      print('ℹ️ 새 사용자 - 프로필 생성 필요');
    }
  }
  
  /// 프로필 로드
  Future<void> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString(kProfileKey);
      
      if (profileJson != null) {
        final profileData = json.decode(profileJson);
        _currentProfile = UserVoiceProfile.fromJson(profileData);
        
        // 캘리브레이션 히스토리 로드
        final historyJson = prefs.getString(kCalibrationKey);
        if (historyJson != null) {
          final historyData = json.decode(historyJson) as List;
          _calibrationHistory.clear();
          _calibrationHistory.addAll(
            historyData.map((e) => CalibrationSession.fromJson(e))
          );
        }
      }
    } catch (e) {
      print('❌ 프로필 로드 실패: $e');
    }
  }
  
  /// 프로필 저장
  Future<void> saveProfile() async {
    if (_currentProfile == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 프로필 저장
      await prefs.setString(kProfileKey, json.encode(_currentProfile!.toJson()));
      
      // 캘리브레이션 히스토리 저장 (최근 30일만)
      final recentHistory = _calibrationHistory
          .where((s) => s.timestamp.isAfter(
              DateTime.now().subtract(Duration(days: kProfileHistoryDays))))
          .toList();
      
      await prefs.setString(
        kCalibrationKey,
        json.encode(recentHistory.map((s) => s.toJson()).toList()),
      );
      
      print('💾 프로필 저장 완료');
    } catch (e) {
      print('❌ 프로필 저장 실패: $e');
    }
  }
  
  /// 캘리브레이션 세션 시작
  Future<CalibrationResult> startCalibration({
    required Stream<PitchResult> pitchStream,
    Duration duration = const Duration(seconds: 30),
  }) async {
    print('🎤 캘리브레이션 시작 (${duration.inSeconds}초)');
    
    final samples = <VoiceSample>[];
    final stopwatch = Stopwatch()..start();
    
    // 안내 메시지
    final exercises = [
      '편안한 음높이로 "아~" 소리를 5초간 내주세요',
      '낮은 음에서 높은 음으로 천천히 올려주세요',
      '높은 음에서 낮은 음으로 천천히 내려주세요',
      '좋아하는 노래를 짧게 불러주세요',
    ];
    
    int exerciseIndex = 0;
    int exerciseStartTime = 0;
    
    await for (final pitch in pitchStream) {
      // 운동 전환
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed > exerciseStartTime + 7500 && exerciseIndex < exercises.length - 1) {
        exerciseIndex++;
        exerciseStartTime = elapsed;
        print('🎵 다음: ${exercises[exerciseIndex]}');
      }
      
      // 유효한 샘플만 수집
      if (pitch.isVoiced && pitch.confidence > kConfidenceThreshold) {
        samples.add(VoiceSample(
          frequency: pitch.frequency,
          confidence: pitch.confidence,
          timestamp: pitch.timestamp,
          exerciseType: exerciseIndex,
        ));
      }
      
      // 시간 제한
      if (stopwatch.elapsed >= duration) break;
    }
    
    stopwatch.stop();
    
    // 분석 및 프로필 생성
    if (samples.length < kMinCalibrationSamples) {
      return CalibrationResult(
        success: false,
        message: '충분한 샘플을 수집하지 못했습니다 (${samples.length}/${kMinCalibrationSamples})',
      );
    }
    
    // 프로필 생성/업데이트
    final newProfile = _analyzeVoiceSamples(samples);
    
    // 기존 프로필과 병합
    if (_currentProfile != null) {
      _currentProfile = _mergeProfiles(_currentProfile!, newProfile);
    } else {
      _currentProfile = newProfile;
    }
    
    // 캘리브레이션 세션 기록
    final session = CalibrationSession(
      timestamp: DateTime.now(),
      sampleCount: samples.length,
      duration: stopwatch.elapsed,
      profile: newProfile,
    );
    _calibrationHistory.add(session);
    
    // 저장
    await saveProfile();
    
    // 어댑터 업데이트
    await _updateAdapter(samples);
    
    return CalibrationResult(
      success: true,
      profile: _currentProfile!,
      message: '캘리브레이션 완료! 음역대와 특성을 학습했습니다.',
      improvements: _calculateImprovements(newProfile),
    );
  }
  
  /// 음성 샘플 분석
  UserVoiceProfile _analyzeVoiceSamples(List<VoiceSample> samples) {
    // 주파수 분포 분석
    final frequencies = samples.map((s) => s.frequency).toList()..sort();
    
    // 통계 계산
    final minFreq = frequencies[frequencies.length ~/ 20]; // 5 percentile
    final maxFreq = frequencies[frequencies.length * 19 ~/ 20]; // 95 percentile
    final medianFreq = frequencies[frequencies.length ~/ 2];
    final meanFreq = frequencies.reduce((a, b) => a + b) / frequencies.length;
    
    // 표준편차 (안정성 지표)
    double variance = 0;
    for (final freq in frequencies) {
      variance += math.pow(freq - meanFreq, 2);
    }
    final stdDev = math.sqrt(variance / frequencies.length);
    
    // 비브라토 특성 분석
    final vibratoSamples = _detectVibratoCharacteristics(samples);
    
    // 음색 특성 (하모닉 분포 시뮬레이션)
    final timbreVector = _extractTimbreFeatures(samples);
    
    // 전환 특성 (포르타멘토/글리산도)
    final transitionStats = _analyzeTransitions(samples);
    
    return UserVoiceProfile(
      // 기본 통계
      minFrequency: minFreq,
      maxFrequency: maxFreq,
      comfortableMin: frequencies[frequencies.length ~/ 4],
      comfortableMax: frequencies[frequencies.length * 3 ~/ 4],
      medianFrequency: medianFreq,
      meanFrequency: meanFreq,
      stdDeviation: stdDev,
      
      // 고급 특성
      vibratoRate: vibratoSamples['rate'] ?? 0,
      vibratoExtent: vibratoSamples['extent'] ?? 0,
      timbreVector: timbreVector,
      
      // 신뢰도 가중치
      confidenceMultiplier: 1.0,
      
      // 메타데이터
      createdAt: DateTime.now(),
      sampleCount: samples.length,
      
      // 전환 특성
      averageTransitionSpeed: transitionStats['speed'] ?? 0,
      preferredPitchStep: transitionStats['step'] ?? 0,
    );
  }
  
  /// 비브라토 특성 감지
  Map<String, double> _detectVibratoCharacteristics(List<VoiceSample> samples) {
    // 연속된 샘플에서 주기적 변동 감지
    final result = <String, double>{};
    
    // 슬라이딩 윈도우 (1초 = 100 샘플 @ 100Hz)
    const windowSize = 100;
    if (samples.length < windowSize) return result;
    
    for (int i = 0; i < samples.length - windowSize; i++) {
      final window = samples.sublist(i, i + windowSize);
      final frequencies = window.map((s) => s.frequency).toList();
      
      // 평균 제거
      final mean = frequencies.reduce((a, b) => a + b) / frequencies.length;
      final centered = frequencies.map((f) => f - mean).toList();
      
      // Zero-crossing으로 주기 추정
      int crossings = 0;
      for (int j = 1; j < centered.length; j++) {
        if ((centered[j] >= 0) != (centered[j-1] >= 0)) {
          crossings++;
        }
      }
      
      final rate = crossings / 2.0; // Hz
      
      // 비브라토 범위 (4-8Hz)
      if (rate >= 4 && rate <= 8) {
        final extent = centered.map((c) => c.abs()).reduce(math.max);
        
        result['rate'] = (result['rate'] ?? 0) + rate;
        result['extent'] = (result['extent'] ?? 0) + extent;
        result['count'] = (result['count'] ?? 0) + 1;
      }
    }
    
    // 평균 계산
    if (result.containsKey('count') && result['count']! > 0) {
      result['rate'] = result['rate']! / result['count']!;
      result['extent'] = result['extent']! / result['count']!;
    }
    
    return result;
  }
  
  /// 음색 특징 추출
  List<double> _extractTimbreFeatures(List<VoiceSample> samples) {
    // 간단한 통계 기반 특징 벡터 (실제로는 스펙트럼 분석 필요)
    final features = List<double>.filled(8, 0);
    
    if (samples.isEmpty) return features;
    
    final frequencies = samples.map((s) => s.frequency).toList();
    final confidences = samples.map((s) => s.confidence).toList();
    
    // Feature 0-3: 주파수 4분위수
    frequencies.sort();
    features[0] = frequencies[frequencies.length ~/ 4];
    features[1] = frequencies[frequencies.length ~/ 2];
    features[2] = frequencies[frequencies.length * 3 ~/ 4];
    features[3] = frequencies.last - frequencies.first; // Range
    
    // Feature 4-5: 신뢰도 통계
    features[4] = confidences.reduce((a, b) => a + b) / confidences.length;
    features[5] = confidences.reduce(math.min);
    
    // Feature 6-7: 변동성
    double totalChange = 0;
    for (int i = 1; i < frequencies.length; i++) {
      totalChange += (frequencies[i] - frequencies[i-1]).abs();
    }
    features[6] = totalChange / frequencies.length;
    features[7] = features[6] / features[3]; // Normalized variation
    
    // 정규화
    final maxFeature = features.reduce(math.max);
    if (maxFeature > 0) {
      for (int i = 0; i < features.length; i++) {
        features[i] /= maxFeature;
      }
    }
    
    return features;
  }
  
  /// 전환 특성 분석
  Map<String, double> _analyzeTransitions(List<VoiceSample> samples) {
    final stats = <String, double>{};
    
    if (samples.length < 2) return stats;
    
    final transitions = <double>[];
    final speeds = <double>[];
    
    for (int i = 1; i < samples.length; i++) {
      final prev = samples[i-1];
      final curr = samples[i];
      
      final timeDiff = curr.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0;
      if (timeDiff <= 0) continue;
      
      final freqDiff = (curr.frequency - prev.frequency).abs();
      final cents = 1200 * math.log(curr.frequency / prev.frequency) / math.log(2);
      
      transitions.add(cents.abs());
      speeds.add(cents.abs() / timeDiff); // cents per second
    }
    
    if (transitions.isNotEmpty) {
      transitions.sort();
      speeds.sort();
      
      stats['speed'] = speeds[speeds.length ~/ 2]; // Median speed
      stats['step'] = transitions[transitions.length ~/ 2]; // Median step
      stats['maxSpeed'] = speeds[speeds.length * 9 ~/ 10]; // 90 percentile
    }
    
    return stats;
  }
  
  /// 프로필 병합
  UserVoiceProfile _mergeProfiles(UserVoiceProfile old, UserVoiceProfile new_) {
    // 가중 평균 (새 데이터에 더 많은 가중치)
    const oldWeight = 0.3;
    const newWeight = 0.7;
    
    return UserVoiceProfile(
      minFrequency: old.minFrequency * oldWeight + new_.minFrequency * newWeight,
      maxFrequency: old.maxFrequency * oldWeight + new_.maxFrequency * newWeight,
      comfortableMin: old.comfortableMin * oldWeight + new_.comfortableMin * newWeight,
      comfortableMax: old.comfortableMax * oldWeight + new_.comfortableMax * newWeight,
      medianFrequency: old.medianFrequency * oldWeight + new_.medianFrequency * newWeight,
      meanFrequency: old.meanFrequency * oldWeight + new_.meanFrequency * newWeight,
      stdDeviation: old.stdDeviation * oldWeight + new_.stdDeviation * newWeight,
      vibratoRate: old.vibratoRate * oldWeight + new_.vibratoRate * newWeight,
      vibratoExtent: old.vibratoExtent * oldWeight + new_.vibratoExtent * newWeight,
      timbreVector: _mergeVectors(old.timbreVector, new_.timbreVector, oldWeight, newWeight),
      confidenceMultiplier: old.confidenceMultiplier,
      createdAt: old.createdAt,
      sampleCount: old.sampleCount + new_.sampleCount,
      averageTransitionSpeed: old.averageTransitionSpeed * oldWeight + new_.averageTransitionSpeed * newWeight,
      preferredPitchStep: old.preferredPitchStep * oldWeight + new_.preferredPitchStep * newWeight,
    );
  }
  
  /// 벡터 병합
  List<double> _mergeVectors(List<double> old, List<double> new_, double oldWeight, double newWeight) {
    final merged = <double>[];
    final length = math.min(old.length, new_.length);
    
    for (int i = 0; i < length; i++) {
      merged.add(old[i] * oldWeight + new_[i] * newWeight);
    }
    
    return merged;
  }
  
  /// 어댑터 업데이트 (경량 개인화)
  Future<void> _updateAdapter(List<VoiceSample> samples) async {
    print('🔧 모델 어댑터 업데이트 중...');
    
    // 어댑터 초기화
    _modelAdapter ??= VoiceAdapter(size: kAdapterSize);
    
    // 특징 추출
    final features = _extractTimbreFeatures(samples);
    
    // 간단한 gradient descent 업데이트
    for (int i = 0; i < math.min(features.length, kAdapterSize); i++) {
      final error = features[i] - _modelAdapter!.weights[i];
      _modelAdapter!.weights[i] += error * kLearningRate;
    }
    
    _modelAdapter!.updateCount++;
    
    // 저장
    await _saveAdapter();
    
    print('✅ 어댑터 업데이트 완료 (iteration: ${_modelAdapter!.updateCount})');
  }
  
  /// 어댑터 로드
  Future<void> loadAdapter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adapterJson = prefs.getString(kAdapterKey);
      
      if (adapterJson != null) {
        final data = json.decode(adapterJson);
        _modelAdapter = VoiceAdapter.fromJson(data);
      }
    } catch (e) {
      print('❌ 어댑터 로드 실패: $e');
    }
  }
  
  /// 어댑터 저장
  Future<void> _saveAdapter() async {
    if (_modelAdapter == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kAdapterKey, json.encode(_modelAdapter!.toJson()));
    } catch (e) {
      print('❌ 어댑터 저장 실패: $e');
    }
  }
  
  /// 개선사항 계산
  List<String> _calculateImprovements(UserVoiceProfile newProfile) {
    final improvements = <String>[];
    
    if (_calibrationHistory.length > 1) {
      final prevProfile = _calibrationHistory[_calibrationHistory.length - 2].profile;
      
      // 음역대 확장
      final rangeIncrease = (newProfile.maxFrequency - newProfile.minFrequency) -
                           (prevProfile.maxFrequency - prevProfile.minFrequency);
      if (rangeIncrease > 10) {
        improvements.add('음역대가 ${rangeIncrease.toStringAsFixed(0)}Hz 확장되었습니다');
      }
      
      // 안정성 향상
      if (newProfile.stdDeviation < prevProfile.stdDeviation * 0.9) {
        improvements.add('음정 안정성이 ${((1 - newProfile.stdDeviation/prevProfile.stdDeviation) * 100).toStringAsFixed(0)}% 향상되었습니다');
      }
      
      // 비브라토 개선
      if (newProfile.vibratoRate > 0 && prevProfile.vibratoRate == 0) {
        improvements.add('비브라토가 감지되었습니다 (${newProfile.vibratoRate.toStringAsFixed(1)}Hz)');
      }
    }
    
    if (improvements.isEmpty) {
      improvements.add('프로필이 성공적으로 업데이트되었습니다');
    }
    
    return improvements;
  }
  
  /// 현재 프로필 가져오기
  UserVoiceProfile? get currentProfile => _currentProfile;
  
  /// 어댑터 가져오기
  VoiceAdapter? get adapter => _modelAdapter;
  
  /// 통계 가져오기
  VoiceStatistics get statistics => _statistics;
  
  /// 프로필 리셋
  Future<void> resetProfile() async {
    _currentProfile = null;
    _modelAdapter = null;
    _calibrationHistory.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kProfileKey);
    await prefs.remove(kCalibrationKey);
    await prefs.remove(kAdapterKey);
    
    print('🔄 프로필이 초기화되었습니다');
  }
}

/// 사용자 음성 프로필
class UserVoiceProfile {
  final double minFrequency;
  final double maxFrequency;
  final double comfortableMin;
  final double comfortableMax;
  final double medianFrequency;
  final double meanFrequency;
  final double stdDeviation;
  final double vibratoRate;
  final double vibratoExtent;
  final List<double> timbreVector;
  final double confidenceMultiplier;
  final DateTime createdAt;
  final int sampleCount;
  final double averageTransitionSpeed;
  final double preferredPitchStep;
  
  const UserVoiceProfile({
    required this.minFrequency,
    required this.maxFrequency,
    required this.comfortableMin,
    required this.comfortableMax,
    required this.medianFrequency,
    required this.meanFrequency,
    required this.stdDeviation,
    required this.vibratoRate,
    required this.vibratoExtent,
    required this.timbreVector,
    required this.confidenceMultiplier,
    required this.createdAt,
    required this.sampleCount,
    required this.averageTransitionSpeed,
    required this.preferredPitchStep,
  });
  
  Map<String, dynamic> toJson() => {
    'minFrequency': minFrequency,
    'maxFrequency': maxFrequency,
    'comfortableMin': comfortableMin,
    'comfortableMax': comfortableMax,
    'medianFrequency': medianFrequency,
    'meanFrequency': meanFrequency,
    'stdDeviation': stdDeviation,
    'vibratoRate': vibratoRate,
    'vibratoExtent': vibratoExtent,
    'timbreVector': timbreVector,
    'confidenceMultiplier': confidenceMultiplier,
    'createdAt': createdAt.toIso8601String(),
    'sampleCount': sampleCount,
    'averageTransitionSpeed': averageTransitionSpeed,
    'preferredPitchStep': preferredPitchStep,
  };
  
  factory UserVoiceProfile.fromJson(Map<String, dynamic> json) => UserVoiceProfile(
    minFrequency: json['minFrequency'],
    maxFrequency: json['maxFrequency'],
    comfortableMin: json['comfortableMin'],
    comfortableMax: json['comfortableMax'],
    medianFrequency: json['medianFrequency'],
    meanFrequency: json['meanFrequency'],
    stdDeviation: json['stdDeviation'],
    vibratoRate: json['vibratoRate'] ?? 0,
    vibratoExtent: json['vibratoExtent'] ?? 0,
    timbreVector: List<double>.from(json['timbreVector'] ?? []),
    confidenceMultiplier: json['confidenceMultiplier'] ?? 1.0,
    createdAt: DateTime.parse(json['createdAt']),
    sampleCount: json['sampleCount'],
    averageTransitionSpeed: json['averageTransitionSpeed'] ?? 0,
    preferredPitchStep: json['preferredPitchStep'] ?? 0,
  );
  
  @override
  String toString() {
    final noteMin = _frequencyToNote(minFrequency);
    final noteMax = _frequencyToNote(maxFrequency);
    final comfortNoteMin = _frequencyToNote(comfortableMin);
    final comfortNoteMax = _frequencyToNote(comfortableMax);
    
    return '''
User Voice Profile:
  Range: $noteMin - $noteMax (${minFrequency.toStringAsFixed(1)} - ${maxFrequency.toStringAsFixed(1)} Hz)
  Comfortable: $comfortNoteMin - $comfortNoteMax
  Median: ${_frequencyToNote(medianFrequency)} (${medianFrequency.toStringAsFixed(1)} Hz)
  Stability: ±${stdDeviation.toStringAsFixed(1)} Hz
  Vibrato: ${vibratoRate > 0 ? "${vibratoRate.toStringAsFixed(1)}Hz, ±${vibratoExtent.toStringAsFixed(1)} cents" : "Not detected"}
  Samples: $sampleCount
''';
  }
  
  static String _frequencyToNote(double frequency) {
    if (frequency < 20 || frequency > 20000) return '';
    
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const a4 = 440.0;
    
    final halfSteps = 12 * math.log(frequency / a4) / math.log(2);
    final noteIndex = (halfSteps.round() + 9 + 48) % 12;
    final octave = ((halfSteps.round() + 9 + 48) ~/ 12) - 1;
    
    return '${notes[noteIndex]}$octave';
  }
}

/// 음성 샘플
class VoiceSample {
  final double frequency;
  final double confidence;
  final DateTime timestamp;
  final int exerciseType;
  
  const VoiceSample({
    required this.frequency,
    required this.confidence,
    required this.timestamp,
    required this.exerciseType,
  });
}

/// 캘리브레이션 세션
class CalibrationSession {
  final DateTime timestamp;
  final int sampleCount;
  final Duration duration;
  final UserVoiceProfile profile;
  
  const CalibrationSession({
    required this.timestamp,
    required this.sampleCount,
    required this.duration,
    required this.profile,
  });
  
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'sampleCount': sampleCount,
    'duration': duration.inSeconds,
    'profile': profile.toJson(),
  };
  
  factory CalibrationSession.fromJson(Map<String, dynamic> json) => CalibrationSession(
    timestamp: DateTime.parse(json['timestamp']),
    sampleCount: json['sampleCount'],
    duration: Duration(seconds: json['duration']),
    profile: UserVoiceProfile.fromJson(json['profile']),
  );
}

/// 캘리브레이션 결과
class CalibrationResult {
  final bool success;
  final UserVoiceProfile? profile;
  final String message;
  final List<String>? improvements;
  
  const CalibrationResult({
    required this.success,
    this.profile,
    required this.message,
    this.improvements,
  });
}

/// 음성 어댑터 (경량 개인화 파라미터)
class VoiceAdapter {
  final int size;
  final List<double> weights;
  int updateCount;
  
  VoiceAdapter({required this.size})
      : weights = List<double>.filled(size, 0.5),
        updateCount = 0;
  
  Map<String, dynamic> toJson() => {
    'size': size,
    'weights': weights,
    'updateCount': updateCount,
  };
  
  factory VoiceAdapter.fromJson(Map<String, dynamic> json) {
    final adapter = VoiceAdapter(size: json['size']);
    adapter.weights.setAll(0, List<double>.from(json['weights']));
    adapter.updateCount = json['updateCount'];
    return adapter;
  }
}

/// 음성 통계
class VoiceStatistics {
  int totalSessions = 0;
  int totalSamples = 0;
  Duration totalDuration = Duration.zero;
  double averageAccuracy = 0;
  double averageConfidence = 0;
  
  void update({
    required int samples,
    required Duration duration,
    required double accuracy,
    required double confidence,
  }) {
    totalSessions++;
    totalSamples += samples;
    totalDuration += duration;
    
    // 이동 평균
    averageAccuracy = (averageAccuracy * (totalSessions - 1) + accuracy) / totalSessions;
    averageConfidence = (averageConfidence * (totalSessions - 1) + confidence) / totalSessions;
  }
  
  @override
  String toString() => '''
Voice Statistics:
  Sessions: $totalSessions
  Total Samples: $totalSamples
  Total Duration: ${totalDuration.inMinutes} minutes
  Average Accuracy: ${(averageAccuracy * 100).toStringAsFixed(1)}%
  Average Confidence: ${(averageConfidence * 100).toStringAsFixed(1)}%
''';
}