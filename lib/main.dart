import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/enhanced_home_screen.dart';
import 'screens/fixed_vocal_training_screen.dart';
import 'screens/wave_start_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 시스템 UI 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F0F23),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(const VocalTrainerApp());
}

class VocalTrainerApp extends StatelessWidget {
  const VocalTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '오비완 v2 - 듀얼 AI 보컬 트레이너',
      theme: ThemeData(
        primaryColor: const Color(0xFF6366F1),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFF1A1B23),
          background: Color(0xFF0F0F23),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          onBackground: Colors.white,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'System',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WaveStartScreen(),
        '/home': (context) => const EnhancedHomeScreen(),
        '/training': (context) => const FixedVocalTrainingScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}