import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_trainer_ai/main.dart';

void main() {
  testWidgets('App should build without errors', (WidgetTester tester) async {
    // 앱 빌드 테스트
    await tester.pumpWidget(const VocalTrainerApp());
    
    // 앱이 정상적으로 로드되는지 확인
    expect(find.text('AI 보컬 코치'), findsOneWidget);
    
    // 기본 위젯들이 존재하는지 확인
    expect(find.text('녹음을 시작하여 AI 코치의 조언을 받아보세요'), findsOneWidget);
  });
}