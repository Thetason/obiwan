import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/pages/main_analysis_page.dart';
import 'features/visual_guide/model_loader.dart';
import 'core/theme/app_theme.dart';

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
      theme: AppTheme.darkTheme,
      home: const MainAnalysisPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}