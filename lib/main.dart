import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/pages/enhanced_main_analysis_page.dart';
import 'features/visual_guide/model_loader.dart';
import 'core/theme/enhanced_app_theme.dart';
import 'screens/real_time_pitch_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 3D 모델 미리 로드
  try {
    await ModelLoader().preloadModels();
  } catch (e) {
    debugPrint('Model preload failed: $e');
  }
  
  runApp(
    const ProviderScope(
      child: VocalTrainerApp(),
    ),
  );
}

class VocalTrainerApp extends StatelessWidget {
  const VocalTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 보컬 트레이너',
      theme: ThemeData.dark(),
      initialRoute: '/',
      routes: {
        '/': (context) => const MainMenuScreen(),
        '/enhanced_analysis': (context) => const EnhancedMainAnalysisPage(),
        '/realtime_pitch': (context) => const RealTimePitchScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오비완 v2 - AI 보컬 트레이너'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.music_note,
              size: 100,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 20),
            const Text(
              '오비완 v2',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'AI 보컬 트레이닝 앱',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            
            // 실시간 피치 분석 (CREPE)
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/realtime_pitch');
                },
                icon: const Icon(Icons.graphic_eq, size: 30),
                label: const Text(
                  '실시간 피치 분석 (CREPE)',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 고급 분석
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/enhanced_analysis');
                },
                icon: const Icon(Icons.analytics, size: 30),
                label: const Text(
                  '고급 보컬 분석',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // 서버 상태 표시
            Card(
              color: Colors.grey[850],
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.computer, color: Colors.green),
                        SizedBox(width: 10),
                        Text('CREPE 서버: localhost:5002'),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.precision_manufacturing, color: Colors.blue),
                        SizedBox(width: 10),
                        Text('모델: Official CREPE CNN'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}