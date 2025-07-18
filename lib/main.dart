import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/pages/main_analysis_page.dart';
import 'features/visual_guide/model_loader.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainAnalysisPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}