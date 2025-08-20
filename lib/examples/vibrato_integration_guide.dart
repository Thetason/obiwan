/// 🎵 오비완 v3.3 - 비브라토 분석기 통합 가이드
/// 
/// 새로운 비브라토 분석기를 기존 시스템에 통합하는 방법을 안내합니다.
/// 
/// 🚨 중요: DEVELOPMENT_PRINCIPLES.md의 "NO DUMMY DATA" 원칙을 준수하며,
/// 모든 분석은 실제 CREPE/SPICE 피치 데이터만을 사용합니다.

library vibrato_integration_guide;

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import '../services/vibrato_analyzer.dart';
import '../services/advanced_pitch_processor.dart';
import '../services/dual_engine_service.dart';
import '../utils/pitch_color_system.dart';
import '../widgets/vibrato_visualizer_widget.dart';

/// 📋 통합 가이드 목차
/// 
/// 1. 기본 통합 (Basic Integration)
/// 2. 실시간 스트림 통합 (Real-time Stream Integration)  
/// 3. UI 통합 (UI Integration)
/// 4. 에러 처리 및 최적화 (Error Handling & Optimization)
/// 5. 테스트 및 검증 (Testing & Validation)

// ===================================================================
// 1. 기본 통합 (Basic Integration)
// ===================================================================

/// 🔧 기본 통합 예제
/// 
/// 가장 간단한 형태의 비브라토 분석기 통합
class BasicVibratoIntegration {
  final VibratoAnalyzer _vibratoAnalyzer = VibratoAnalyzer();
  
  /// CREPE/SPICE 데이터를 받아서 비브라토 분석 수행
  VibratoAnalysisResult analyzePitchData(PitchData pitchData) {
    // ✅ 실제 피치 데이터만 사용 (NO DUMMY DATA)
    return _vibratoAnalyzer.analyzeVibrato(pitchData);
  }
  
  /// 예제: 단일 분석
  void exampleSingleAnalysis() {
    // 실제 CREPE/SPICE에서 받은 데이터라고 가정
    final pitchData = PitchData(
      frequency: 440.0,      // 실제 측정된 주파수
      confidence: 0.85,      // CREPE/SPICE 신뢰도
      cents: 5.0,           // 음정 정확도
      timestamp: DateTime.now(),
      amplitude: 0.6,       // 실제 음량
    );
    
    final result = analyzePitchData(pitchData);
    
    if (result.isPresent) {
      print('✅ 비브라토 감지됨: ${result.statusDescription}');
      print('   품질: ${result.quality.description}');
      print('   피드백: ${result.feedback}');
    } else {
      print('❌ 비브라토 없음');
    }
  }
  
  void dispose() {
    _vibratoAnalyzer.clearHistory();
  }
}

// ===================================================================
// 2. 실시간 스트림 통합 (Real-time Stream Integration)
// ===================================================================

/// 🌊 실시간 스트림 통합 예제
/// 
/// CREPE/SPICE 실시간 스트림과 통합하는 방법
class RealtimeVibratoIntegration {
  final VibratoAnalyzer _vibratoAnalyzer = VibratoAnalyzer();
  final DualEngineService _dualEngine = DualEngineService();
  
  StreamSubscription? _pitchSubscription;
  final StreamController<VibratoAnalysisResult> _vibratoStreamController = 
      StreamController<VibratoAnalysisResult>.broadcast();
  
  /// 실시간 비브라토 분석 스트림
  Stream<VibratoAnalysisResult> get vibratoStream => _vibratoStreamController.stream;
  
  /// 실시간 분석 시작
  Future<void> startRealtimeAnalysis() async {
    try {
      // CREPE/SPICE 피치 스트림 구독
      await _dualEngine.initialize();
      
      // 실제 피치 데이터 스트림에 연결 (예시)
      _pitchSubscription = _dualEngine.pitchStream?.listen(
        (pitchData) {
          // ✅ 실제 CREPE/SPICE 데이터 사용
          final vibratoResult = _vibratoAnalyzer.analyzeVibrato(pitchData);
          
          // 결과를 스트림으로 전달
          _vibratoStreamController.add(vibratoResult);
          
          // 로깅 (개발 단계에서)
          if (vibratoResult.isPresent) {
            print('🎵 실시간 비브라토: ${vibratoResult.rate.toStringAsFixed(1)}Hz');
          }
        },
        onError: (error) {
          print('❌ 피치 분석 오류: $error');
          _vibratoStreamController.addError(error);
        },
      );
      
      print('✅ 실시간 비브라토 분석 시작됨');
      
    } catch (e) {
      print('❌ 실시간 분석 시작 실패: $e');
      rethrow;
    }
  }
  
  /// 실시간 분석 중지
  void stopRealtimeAnalysis() {
    _pitchSubscription?.cancel();
    _vibratoAnalyzer.clearHistory();
    print('⏹️ 실시간 비브라토 분석 중지됨');
  }
  
  void dispose() {
    stopRealtimeAnalysis();
    _vibratoStreamController.close();
    _dualEngine.dispose();
  }
}

// ===================================================================
// 3. UI 통합 (UI Integration)
// ===================================================================

/// 🎨 UI 통합 예제
/// 
/// 비브라토 분석 결과를 UI에 표시하는 방법
class VibratoUIIntegration extends StatefulWidget {
  const VibratoUIIntegration({Key? key}) : super(key: key);

  @override
  State<VibratoUIIntegration> createState() => _VibratoUIIntegrationState();
}

class _VibratoUIIntegrationState extends State<VibratoUIIntegration> {
  final RealtimeVibratoIntegration _realtimeIntegration = RealtimeVibratoIntegration();
  VibratoAnalysisResult? _currentResult;
  
  @override
  void initState() {
    super.initState();
    _setupVibratoStream();
  }
  
  void _setupVibratoStream() {
    // 실시간 비브라토 결과를 UI에 반영
    _realtimeIntegration.vibratoStream.listen(
      (result) {
        if (mounted) {
          setState(() {
            _currentResult = result;
          });
        }
      },
      onError: (error) {
        print('❌ UI 업데이트 오류: $error');
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. 메인 비브라토 시각화
        VibratoVisualizerWidget(
          vibratoResult: _currentResult,
          width: MediaQuery.of(context).size.width - 32,
          height: 200,
          showDetails: true,
        ),
        
        const SizedBox(height: 16),
        
        // 2. 간단한 상태 표시
        _buildStatusCard(),
        
        const SizedBox(height: 16),
        
        // 3. 제어 버튼
        _buildControlButtons(),
      ],
    );
  }
  
  Widget _buildStatusCard() {
    final result = _currentResult;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '비브라토 상태',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            
            if (result?.isPresent == true) ...[
              Text('✅ ${result!.feedback}'),
              Text('📊 ${result.statusDescription}'),
              Text('🎯 신뢰도: ${(result.confidenceLevel * 100).toStringAsFixed(0)}%'),
            ] else ...[
              const Text('⏳ 비브라토 분석 중...'),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            try {
              await _realtimeIntegration.startRealtimeAnalysis();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ 비브라토 분석 시작됨')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('❌ 시작 실패: $e')),
              );
            }
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text('분석 시작'),
        ),
        
        ElevatedButton.icon(
          onPressed: () {
            _realtimeIntegration.stopRealtimeAnalysis();
            setState(() {
              _currentResult = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('⏹️ 비브라토 분석 중지됨')),
            );
          },
          icon: const Icon(Icons.stop),
          label: const Text('분석 중지'),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _realtimeIntegration.dispose();
    super.dispose();
  }
}

// ===================================================================
// 4. 에러 처리 및 최적화 (Error Handling & Optimization)
// ===================================================================

/// 🛡️ 에러 처리 및 최적화 예제
class RobustVibratoIntegration {
  final VibratoAnalyzer _vibratoAnalyzer = VibratoAnalyzer();
  
  /// 안전한 비브라토 분석 (에러 처리 포함)
  VibratoAnalysisResult? safeAnalyzeVibrato(PitchData? pitchData) {
    try {
      // 1. 입력 검증
      if (pitchData == null) {
        print('⚠️ [VibratoIntegration] Null pitch data received');
        return null;
      }
      
      // 2. 데이터 품질 검증
      if (pitchData.frequency <= 0) {
        print('⚠️ [VibratoIntegration] Invalid frequency: ${pitchData.frequency}');
        return null;
      }
      
      if (pitchData.confidence < 0.3) {
        print('⚠️ [VibratoIntegration] Low confidence: ${pitchData.confidence}');
        return null;
      }
      
      // 3. 실제 분석 수행
      final result = _vibratoAnalyzer.analyzeVibrato(pitchData);
      
      // 4. 결과 로깅 (개발 단계)
      if (result.isPresent) {
        print('✅ [VibratoIntegration] Vibrato detected: ${result.quality.description}');
      }
      
      return result;
      
    } catch (e, stackTrace) {
      print('❌ [VibratoIntegration] Analysis error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// 메모리 최적화를 위한 주기적 정리
  Timer? _cleanupTimer;
  
  void startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      final stats = _vibratoAnalyzer.getAnalysisStats();
      print('🧹 [VibratoIntegration] Cleanup - Total analyses: ${stats.totalAnalysisCount}');
      
      // 히스토리가 너무 오래되었으면 일부 정리
      if (stats.timeSpan > 60.0) { // 60초 이상
        _vibratoAnalyzer.clearHistory();
        print('🧹 [VibratoIntegration] History cleared due to age');
      }
    });
  }
  
  void dispose() {
    _cleanupTimer?.cancel();
    _vibratoAnalyzer.clearHistory();
  }
}

// ===================================================================
// 5. 테스트 및 검증 (Testing & Validation)
// ===================================================================

/// 🧪 테스트 및 검증 예제
class VibratoTestingFramework {
  final VibratoAnalyzer _vibratoAnalyzer = VibratoAnalyzer();
  
  /// 알려진 주파수로 분석기 테스트
  Future<void> testWithKnownFrequencies() async {
    print('🧪 [VibratoTesting] Starting known frequency tests...');
    
    // 테스트 케이스 1: 일정한 주파수 (비브라토 없음)
    await _testSteadyPitch();
    
    // 테스트 케이스 2: 시뮬레이션된 비브라토
    await _testSimulatedVibrato();
    
    // 테스트 케이스 3: 잘못된 데이터
    await _testInvalidData();
    
    print('✅ [VibratoTesting] All tests completed');
  }
  
  Future<void> _testSteadyPitch() async {
    print('📊 Testing steady pitch (no vibrato expected)...');
    
    // 일정한 440Hz 피치 10개 생성
    for (int i = 0; i < 10; i++) {
      final pitchData = PitchData(
        frequency: 440.0, // 정확히 440Hz
        confidence: 0.9,
        cents: 0.0,
        timestamp: DateTime.now(),
        amplitude: 0.5,
      );
      
      final result = _vibratoAnalyzer.analyzeVibrato(pitchData);
      
      // 일정한 피치에서는 비브라토가 감지되지 않아야 함
      if (result.isPresent) {
        print('⚠️ Unexpected vibrato detected in steady pitch');
      }
      
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    print('✅ Steady pitch test completed');
  }
  
  Future<void> _testSimulatedVibrato() async {
    print('📊 Testing simulated vibrato (vibrato expected)...');
    
    // 6Hz 비브라토 시뮬레이션
    const baseFreq = 440.0;
    const vibratoRate = 6.0; // Hz
    const vibratoDepth = 30.0; // cents
    
    for (int i = 0; i < 30; i++) {
      final time = i * 0.05; // 50ms 간격
      final vibratoPhase = 2 * 3.14159 * vibratoRate * time;
      final centsOffset = vibratoDepth * math.sin(vibratoPhase);
      
      // cents를 주파수 비율로 변환
      final freqRatio = math.pow(2, centsOffset / 1200);
      final currentFreq = baseFreq * freqRatio;
      
      final pitchData = PitchData(
        frequency: currentFreq,
        confidence: 0.85,
        cents: centsOffset,
        timestamp: DateTime.now(),
        amplitude: 0.6,
      );
      
      final result = _vibratoAnalyzer.analyzeVibrato(pitchData);
      
      // 충분한 데이터가 쌓인 후에는 비브라토가 감지되어야 함
      if (i > 15 && !result.isPresent) {
        print('⚠️ Vibrato not detected in simulated vibrato data');
      } else if (result.isPresent) {
        print('✅ Vibrato detected: rate=${result.rate.toStringAsFixed(1)}Hz, depth=${result.depth.toStringAsFixed(1)} cents');
      }
      
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    print('✅ Simulated vibrato test completed');
  }
  
  Future<void> _testInvalidData() async {
    print('📊 Testing invalid data handling...');
    
    // 테스트: 0Hz 주파수
    var result = _vibratoAnalyzer.analyzeVibrato(
      PitchData(
        frequency: 0.0,
        confidence: 0.9,
        cents: 0.0,
        timestamp: DateTime.now(),
        amplitude: 0.5,
      ),
    );
    
    if (result.isPresent) {
      print('⚠️ Vibrato detected with 0Hz frequency');
    } else {
      print('✅ Correctly rejected 0Hz frequency');
    }
    
    // 테스트: 낮은 신뢰도
    result = _vibratoAnalyzer.analyzeVibrato(
      PitchData(
        frequency: 440.0,
        confidence: 0.1, // 매우 낮은 신뢰도
        cents: 0.0,
        timestamp: DateTime.now(),
        amplitude: 0.5,
      ),
    );
    
    if (result.isPresent) {
      print('⚠️ Vibrato detected with low confidence');
    } else {
      print('✅ Correctly rejected low confidence data');
    }
    
    print('✅ Invalid data test completed');
  }
  
  void dispose() {
    _vibratoAnalyzer.clearHistory();
  }
}

// ===================================================================
// 통합 체크리스트
// ===================================================================

/// 📋 통합 체크리스트
/// 
/// 비브라토 분석기를 통합할 때 확인해야 할 사항들:
/// 
/// ✅ 1. CREPE/SPICE 실제 데이터 연결 확인
/// ✅ 2. 신뢰도 임계값 설정 (권장: 0.6 이상)
/// ✅ 3. 실시간 스트림 연결 테스트
/// ✅ 4. UI 업데이트 성능 확인
/// ✅ 5. 메모리 누수 방지 (dispose 호출)
/// ✅ 6. 에러 처리 구현
/// ✅ 7. 알려진 주파수로 정확도 테스트
/// ✅ 8. 사용자 피드백 메시지 현지화
/// ✅ 9. 분석 통계 모니터링
/// ✅ 10. 성능 최적화 (주기적 정리)

/// 🎯 다음 단계 권장사항:
/// 
/// 1. 실제 CREPE/SPICE 데이터로 통합 테스트
/// 2. 다양한 목소리 샘플로 정확도 검증  
/// 3. UI/UX 피드백 수집 및 개선
/// 4. 성능 프로파일링 및 최적화
/// 5. 사용자 가이드 및 튜토리얼 제작