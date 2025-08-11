import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../services/dual_engine_service.dart';
import '../services/native_audio_service.dart';

/// Advanced Real-time Pitch Tracking Architecture
/// 목표: 마이크→UI 지연 < 120ms, 정확도 > 95%
class AdvancedPitchTracker {
  // 1. 윈도/홉 재조정 설정
  static const int kWindowSize = 2048; // 약 42ms @ 48kHz
  static const int kHopSize = 512;     // 약 10ms @ 48kHz
  static const double kTargetLatency = 0.120; // 120ms 목표
  
  // 2. VAD (Voice Activity Detection) 설정
  static const double kVadEnergyThreshold = 0.01;
  static const double kVadZcrThreshold = 0.1;
  static const int kVadHangoverFrames = 5;
  
  // 3. 스무딩 설정
  static const int kMedianFilterSize = 5;
  static const double kViterbiTransitionCost = 10.0;
  
  // 4. 링 버퍼 설정
  static const int kRingBufferSeconds = 5;
  static const int kRingBufferSize = 48000 * kRingBufferSeconds;
  
  // 서비스
  final DualEngineService _dualEngine = DualEngineService();
  final NativeAudioService _audioService = NativeAudioService.instance;
  
  // 링 버퍼
  final Queue<double> _ringBuffer = Queue<double>();
  int _writePosition = 0;
  int _readPosition = 0;
  
  // VAD 상태
  bool _isVoiceActive = false;
  int _hangoverCounter = 0;
  double _noiseFloor = 0.0;
  
  // 스무딩 버퍼
  final List<double> _medianBuffer = [];
  final List<PitchFrame> _viterbiPath = [];
  
  // 성능 메트릭
  int _totalFrames = 0;
  int _processedFrames = 0;
  double _averageLatency = 0.0;
  
  // 사용자 프로필
  UserVoiceProfile? _userProfile;
  
  /// 초기화
  Future<void> initialize() async {
    await _audioService.initialize();
    await _dualEngine.initialize();
    
    // 노이즈 플로어 캘리브레이션
    await _calibrateNoiseFloor();
    
    print('🚀 Advanced Pitch Tracker 초기화 완료');
    print('📊 Window: ${kWindowSize}샘플 (${(kWindowSize/48000*1000).toStringAsFixed(1)}ms)');
    print('📊 Hop: ${kHopSize}샘플 (${(kHopSize/48000*1000).toStringAsFixed(1)}ms)');
    print('📊 목표 지연: ${(kTargetLatency*1000).toStringAsFixed(0)}ms');
  }
  
  /// 노이즈 플로어 캘리브레이션
  Future<void> _calibrateNoiseFloor() async {
    print('🎤 노이즈 플로어 캘리브레이션 중...');
    
    final samples = <double>[];
    for (int i = 0; i < 10; i++) {
      final buffer = await _audioService.getRealtimeAudioBuffer();
      if (buffer != null && buffer.isNotEmpty) {
        final energy = _calculateEnergy(buffer);
        samples.add(energy);
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    if (samples.isNotEmpty) {
      samples.sort();
      _noiseFloor = samples[samples.length ~/ 2] * 1.5; // 중간값의 1.5배
      print('✅ 노이즈 플로어: ${_noiseFloor.toStringAsFixed(4)}');
    }
  }
  
  /// 실시간 오디오 처리 시작
  Stream<PitchResult> startTracking() async* {
    print('🎙️ 실시간 피치 트래킹 시작');
    
    await _audioService.startRecording();
    final startTime = DateTime.now();
    
    while (true) {
      final frameStartTime = DateTime.now();
      
      // 1. 오디오 버퍼 획득
      final audioBuffer = await _audioService.getRealtimeAudioBuffer();
      if (audioBuffer == null || audioBuffer.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 10));
        continue;
      }
      
      // 2. 링 버퍼에 저장
      _addToRingBuffer(audioBuffer);
      
      // 3. 처리할 프레임 추출
      final frame = _extractFrame(kWindowSize);
      if (frame == null) continue;
      
      _totalFrames++;
      
      // 4. VAD 체크
      final vadResult = _performVAD(frame);
      if (!vadResult.isActive) {
        // 무성 구간 스킵 (연산량 절감)
        yield PitchResult(
          frequency: 0,
          confidence: 0,
          timestamp: DateTime.now(),
          isVoiced: false,
          latency: DateTime.now().difference(frameStartTime).inMilliseconds / 1000.0,
        );
        continue;
      }
      
      _processedFrames++;
      
      // 5. 피치 분석 (CREPE/SPICE 또는 경량 모델)
      final pitchData = await _analyzePitch(frame);
      
      // 6. 스무딩 적용
      final smoothedPitch = _applySmoothing(pitchData);
      
      // 7. 사용자 프로필 적용
      final adjustedPitch = _applyUserProfile(smoothedPitch);
      
      // 8. 레이턴시 계산
      final latency = DateTime.now().difference(frameStartTime).inMilliseconds / 1000.0;
      _averageLatency = (_averageLatency * 0.9) + (latency * 0.1);
      
      // 9. 결과 반환
      yield PitchResult(
        frequency: adjustedPitch.frequency,
        confidence: adjustedPitch.confidence,
        timestamp: DateTime.now(),
        isVoiced: true,
        latency: latency,
        note: _frequencyToNote(adjustedPitch.frequency),
        cents: _calculateCents(adjustedPitch.frequency),
      );
      
      // 10. 성능 모니터링
      if (_totalFrames % 100 == 0) {
        final reduction = (1 - _processedFrames / _totalFrames) * 100;
        print('📊 VAD 연산 절감: ${reduction.toStringAsFixed(1)}%');
        print('📊 평균 레이턴시: ${(_averageLatency*1000).toStringAsFixed(1)}ms');
      }
    }
  }
  
  /// 링 버퍼에 데이터 추가
  void _addToRingBuffer(List<double> samples) {
    for (final sample in samples) {
      if (_ringBuffer.length >= kRingBufferSize) {
        _ringBuffer.removeFirst();
      }
      _ringBuffer.add(sample);
    }
  }
  
  /// 프레임 추출
  List<double>? _extractFrame(int size) {
    if (_ringBuffer.length < size) return null;
    
    final frame = <double>[];
    final bufferList = _ringBuffer.toList();
    final startIdx = bufferList.length - size;
    
    for (int i = startIdx; i < bufferList.length; i++) {
      frame.add(bufferList[i]);
    }
    
    return frame;
  }
  
  /// VAD (Voice Activity Detection)
  VADResult _performVAD(List<double> frame) {
    // 에너지 계산
    final energy = _calculateEnergy(frame);
    
    // Zero Crossing Rate 계산
    final zcr = _calculateZCR(frame);
    
    // 음성 활동 판단
    final isActive = energy > _noiseFloor && energy > kVadEnergyThreshold;
    
    if (isActive) {
      _isVoiceActive = true;
      _hangoverCounter = kVadHangoverFrames;
    } else if (_hangoverCounter > 0) {
      _hangoverCounter--;
      _isVoiceActive = true;
    } else {
      _isVoiceActive = false;
    }
    
    return VADResult(
      isActive: _isVoiceActive,
      energy: energy,
      zcr: zcr,
    );
  }
  
  /// 에너지 계산
  double _calculateEnergy(List<double> frame) {
    double sum = 0;
    for (final sample in frame) {
      sum += sample * sample;
    }
    return math.sqrt(sum / frame.length);
  }
  
  /// Zero Crossing Rate 계산
  double _calculateZCR(List<double> frame) {
    int crossings = 0;
    for (int i = 1; i < frame.length; i++) {
      if ((frame[i] >= 0) != (frame[i-1] >= 0)) {
        crossings++;
      }
    }
    return crossings / frame.length;
  }
  
  /// 피치 분석
  Future<PitchData> _analyzePitch(List<double> frame) async {
    try {
      // 빠른 경로: 로컬 autocorrelation (< 5ms)
      if (_averageLatency > kTargetLatency * 0.8) {
        return _fastAutocorrelation(frame);
      }
      
      // 정확한 경로: CREPE/SPICE (< 50ms)
      final float32Frame = Float32List.fromList(frame);
      final result = await _dualEngine.analyzePitch(float32Frame);
      
      return PitchData(
        frequency: result.frequency,
        confidence: result.confidence,
        timestamp: DateTime.now(),
      );
      
    } catch (e) {
      // 폴백: 빠른 로컬 분석
      return _fastAutocorrelation(frame);
    }
  }
  
  /// 빠른 Autocorrelation 피치 검출
  PitchData _fastAutocorrelation(List<double> frame) {
    const minPeriod = 48000 ~/ 1000; // 1000Hz
    const maxPeriod = 48000 ~/ 50;   // 50Hz
    
    double maxCorr = 0;
    int bestPeriod = 0;
    
    for (int period = minPeriod; period <= maxPeriod; period++) {
      double corr = 0;
      for (int i = 0; i < frame.length - period; i++) {
        corr += frame[i] * frame[i + period];
      }
      
      if (corr > maxCorr) {
        maxCorr = corr;
        bestPeriod = period;
      }
    }
    
    final frequency = bestPeriod > 0 ? 48000.0 / bestPeriod : 0;
    final confidence = maxCorr / frame.length;
    
    return PitchData(
      frequency: frequency,
      confidence: confidence.clamp(0, 1),
      timestamp: DateTime.now(),
    );
  }
  
  /// 스무딩 적용 (Median + Viterbi)
  PitchData _applySmoothing(PitchData raw) {
    // Median 필터
    _medianBuffer.add(raw.frequency);
    if (_medianBuffer.length > kMedianFilterSize) {
      _medianBuffer.removeAt(0);
    }
    
    final sorted = List<double>.from(_medianBuffer)..sort();
    final median = sorted[sorted.length ~/ 2];
    
    // Viterbi 경로 최적화 (간단한 버전)
    if (_viterbiPath.isNotEmpty) {
      final lastPitch = _viterbiPath.last.frequency;
      final distance = (median - lastPitch).abs();
      
      // 전이 비용이 너무 크면 이전 값 유지
      if (distance > kViterbiTransitionCost) {
        return PitchData(
          frequency: lastPitch,
          confidence: raw.confidence * 0.8,
          timestamp: raw.timestamp,
        );
      }
    }
    
    final smoothed = PitchData(
      frequency: median,
      confidence: raw.confidence,
      timestamp: raw.timestamp,
    );
    
    _viterbiPath.add(PitchFrame(
      frequency: median,
      confidence: raw.confidence,
      timestamp: raw.timestamp,
    ));
    
    if (_viterbiPath.length > 10) {
      _viterbiPath.removeAt(0);
    }
    
    return smoothed;
  }
  
  /// 사용자 프로필 적용
  PitchData _applyUserProfile(PitchData pitch) {
    if (_userProfile == null) return pitch;
    
    // 사용자 음역대에 맞춰 조정
    var adjustedFreq = pitch.frequency;
    
    if (adjustedFreq < _userProfile!.minFrequency) {
      adjustedFreq *= 2; // 옥타브 위로
    } else if (adjustedFreq > _userProfile!.maxFrequency) {
      adjustedFreq /= 2; // 옥타브 아래로
    }
    
    return PitchData(
      frequency: adjustedFreq,
      confidence: pitch.confidence * _userProfile!.confidenceMultiplier,
      timestamp: pitch.timestamp,
    );
  }
  
  /// 주파수를 음표로 변환
  String _frequencyToNote(double frequency) {
    if (frequency < 20 || frequency > 20000) return '';
    
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    const a4 = 440.0;
    
    final halfSteps = 12 * math.log(frequency / a4) / math.log(2);
    final noteIndex = (halfSteps.round() + 9 + 48) % 12;
    final octave = ((halfSteps.round() + 9 + 48) ~/ 12) - 1;
    
    return '${notes[noteIndex]}$octave';
  }
  
  /// 센트 계산
  double _calculateCents(double frequency) {
    if (frequency < 20 || frequency > 20000) return 0;
    
    const a4 = 440.0;
    final halfSteps = 12 * math.log(frequency / a4) / math.log(2);
    final nearestNote = halfSteps.round();
    final cents = (halfSteps - nearestNote) * 100;
    
    return cents;
  }
  
  /// 사용자 프로필 생성/업데이트
  Future<void> createUserProfile() async {
    print('🎤 사용자 음성 프로필 생성 중...');
    
    // 10초간 음성 수집
    final frequencies = <double>[];
    final stopwatch = Stopwatch()..start();
    
    await for (final result in startTracking()) {
      if (result.isVoiced && result.confidence > 0.7) {
        frequencies.add(result.frequency);
      }
      
      if (stopwatch.elapsedMilliseconds > 10000) break;
    }
    
    if (frequencies.isNotEmpty) {
      frequencies.sort();
      
      _userProfile = UserVoiceProfile(
        minFrequency: frequencies[frequencies.length ~/ 10],
        maxFrequency: frequencies[frequencies.length * 9 ~/ 10],
        averageFrequency: frequencies[frequencies.length ~/ 2],
        confidenceMultiplier: 1.0,
      );
      
      print('✅ 사용자 프로필 생성 완료');
      print('📊 음역대: ${_userProfile!.minFrequency.toStringAsFixed(1)}Hz - ${_userProfile!.maxFrequency.toStringAsFixed(1)}Hz');
    }
  }
  
  /// 정리
  void dispose() {
    _audioService.stopRecording();
    _ringBuffer.clear();
    _medianBuffer.clear();
    _viterbiPath.clear();
  }
}

/// 피치 결과
class PitchResult {
  final double frequency;
  final double confidence;
  final DateTime timestamp;
  final bool isVoiced;
  final double latency;
  final String? note;
  final double? cents;
  
  const PitchResult({
    required this.frequency,
    required this.confidence,
    required this.timestamp,
    required this.isVoiced,
    required this.latency,
    this.note,
    this.cents,
  });
}

/// VAD 결과
class VADResult {
  final bool isActive;
  final double energy;
  final double zcr;
  
  const VADResult({
    required this.isActive,
    required this.energy,
    required this.zcr,
  });
}

/// 피치 데이터
class PitchData {
  final double frequency;
  final double confidence;
  final DateTime timestamp;
  
  const PitchData({
    required this.frequency,
    required this.confidence,
    required this.timestamp,
  });
}

/// 피치 프레임 (Viterbi용)
class PitchFrame {
  final double frequency;
  final double confidence;
  final DateTime timestamp;
  
  const PitchFrame({
    required this.frequency,
    required this.confidence,
    required this.timestamp,
  });
}

/// 사용자 음성 프로필
class UserVoiceProfile {
  final double minFrequency;
  final double maxFrequency;
  final double averageFrequency;
  final double confidenceMultiplier;
  
  const UserVoiceProfile({
    required this.minFrequency,
    required this.maxFrequency,
    required this.averageFrequency,
    required this.confidenceMultiplier,
  });
}