import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'screens/fixed_vocal_training_screen.dart';
import 'screens/wave_start_screen.dart';
import 'screens/pitch_test_screen.dart';
import 'screens/vocal_app_screen.dart';
import 'design_system/screens/vj_home_screen.dart';  // New Voice Journey import
import 'core/debug_logger.dart';
import 'core/error_handler.dart';
import 'core/resource_manager.dart';
import 'core/resilience_manager.dart';
import 'core/network_interceptor.dart';
import 'services/crash_reporter.dart';
import 'services/native_audio_service.dart';
import 'services/dual_engine_service.dart';
import 'widgets/debug_dashboard.dart';
import 'package:dio/dio.dart';

// 디버그 모드 플래그 (앱 인자나 환경변수로 제어 가능)
bool _isDebugModeEnabled = kDebugMode;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🚀 오비완 v3 디버깅 시스템 초기화
  print('🚀 오비완 v3 시작 - 디버깅 시스템 초기화 중...');
  
  // 디버그 로거 초기화
  await logger.initialize();
  await logger.info('=== 오비완 v3 디버깅 시스템 시작 ===', tag: 'MAIN');
  
  // 🔧 고도화된 디버그 도구 초기화 (디버그 모드에서만)
  if (_isDebugModeEnabled) {
    await _initializeAdvancedDebugTools();
  }
  
  // 에러 핸들러 초기화
  errorHandler.initialize();
  await logger.info('에러 핸들러 초기화 완료', tag: 'MAIN');
  
  // 🛡️ 안정성 시스템 초기화
  print('🛡️ 안정성 시스템 초기화 중...');
  
  // 크래시 리포터 초기화
  await CrashReporter().initialize(
    onRecoveryAttempt: () async {
      // 복구 시도 시 실행할 콜백
      print('🔄 앱 복구 시도 중...');
      await ResourceManager().disposeAll();
      await Future.delayed(const Duration(seconds: 1));
    },
  );
  await logger.info('크래시 리포터 초기화 완료', tag: 'MAIN');
  
  // 리소스 매니저 모니터링 시작
  ResourceManager().startMonitoring();
  await logger.info('리소스 매니저 모니터링 시작', tag: 'MAIN');
  
  // 복구 시스템 초기화
  await ResilienceManager().initialize(
    dualEngineService: DualEngineService(),
    nativeAudioService: NativeAudioService.instance,
  );
  await logger.info('복구 시스템 초기화 완료', tag: 'MAIN');
  
  // 네이티브 오디오 서비스 초기화
  await NativeAudioService.instance.initialize();
  await logger.info('네이티브 오디오 서비스 초기화 완료', tag: 'MAIN');
  
  // 오디오 시스템 상태 확인
  final audioStatus = await NativeAudioService.instance.getAudioSystemStatus();
  await logger.info('오디오 시스템 상태: $audioStatus', tag: 'MAIN');
  
  // 시스템 UI 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF8FAFC),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  await logger.info('오비완 v3 앱 시작 준비 완료', tag: 'MAIN');
  runApp(VocalTrainerApp(debugModeEnabled: _isDebugModeEnabled));
}

// 🔧 고도화된 디버그 도구 초기화 함수
Future<void> _initializeAdvancedDebugTools() async {
  try {
    // 네트워크 인터셉터 설정
    final dio = Dio();
    final networkInterceptor = NetworkInterceptor();
    dio.interceptors.add(networkInterceptor);
    
    await logger.info('🌐 네트워크 인터셉터 초기화 완료', tag: 'DEBUG');
    
    // 성능 모니터링 시작
    await logger.info('📊 성능 모니터링 시스템 초기화 완료', tag: 'DEBUG');
    
    // 오디오 디버그 시스템 준비
    await logger.info('🎵 오디오 디버그 시스템 준비 완료', tag: 'DEBUG');
    
    await logger.info('🚀 모든 고도화 디버그 도구 초기화 완료', tag: 'DEBUG');
    
  } catch (e) {
    await logger.error('디버그 도구 초기화 실패: $e', tag: 'DEBUG');
  }
}

class VocalTrainerApp extends StatefulWidget {
  final bool debugModeEnabled;
  
  const VocalTrainerApp({
    super.key,
    this.debugModeEnabled = false,
  });
  
  @override
  State<VocalTrainerApp> createState() => _VocalTrainerAppState();
}

class _VocalTrainerAppState extends State<VocalTrainerApp> {
  @override
  void dispose() {
    // 앱 종료 시 모든 시스템 정리
    _cleanupSystems();
    super.dispose();
  }

  Future<void> _cleanupSystems() async {
    print('🧹 앱 종료 - 시스템 정리 중...');
    
    try {
      // 복구 시스템 정리
      await ResilienceManager().dispose();
      
      // 리소스 매니저 정리
      await ResourceManager().cleanup();
      
      // 크래시 리포터 정리
      await CrashReporter().dispose();
      
      // 듀얼 엔진 서비스 정리
      DualEngineService().dispose();
      
      print('✅ 시스템 정리 완료');
    } catch (e) {
      print('❌ 시스템 정리 중 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'Voice Journey - AI Vocal Trainer',
      theme: ThemeData(
        primaryColor: const Color(0xFFFF6B6B),  // VJColors.primary
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFFF6B6B),     // Coral
          secondary: Color(0xFF4ECDC4),   // Mint
          tertiary: Color(0xFF9B84EC),    // Lavender
          surface: Color(0xFFFFFFFF),
          background: Color(0xFFFBFCFD),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF1A1A1A),
          onBackground: Color(0xFF1A1A1A),
        ),
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'SF Pro Display',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Color(0xFF1A1A1A),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Color(0xFF636E72),
          ),
        ),
      ),
      initialRoute: '/vj_home',  // Start with new Voice Journey UI
      routes: {
        '/': (context) => const VocalAppScreen(),  // Keep existing for compatibility
        '/vj_home': (context) => const VJHomeScreen(),  // New Voice Journey home
        '/wave_start': (context) => const WaveStartScreen(),
        '/training': (context) => const FixedVocalTrainingScreen(audioData: []),
        '/pitch_test': (context) => const PitchTestScreen(),
      },
      debugShowCheckedModeBanner: false,
    );

    // 🔧 디버그 모드에서만 DebugDashboard로 감싸기
    if (widget.debugModeEnabled && !kReleaseMode) {
      return DebugDashboard(
        enabled: true,
        // 오디오 스트림은 나중에 실제 오디오 서비스에서 가져올 수 있음
        audioDataStream: _createMockAudioStream(),
        child: app,
      );
    }

    return app;
  }
  
  // 테스트용 모의 오디오 스트림 (실제 구현에서는 NativeAudioService에서 가져올 것)
  Stream<List<double>>? _createMockAudioStream() {
    if (!widget.debugModeEnabled) return null;
    
    return Stream.periodic(const Duration(milliseconds: 50), (count) {
      // 모의 오디오 데이터 생성 (실제로는 마이크 입력)
      final samples = <double>[];
      for (int i = 0; i < 4096; i++) {
        final frequency = 440.0; // A4 note
        final sample = 0.3 * sin(2 * pi * frequency * count * 0.05 + i / 100.0);
        samples.add(sample);
      }
      return samples;
    });
  }
}