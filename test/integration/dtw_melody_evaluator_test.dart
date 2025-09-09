import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_trainer_ai/services/melody_evaluator.dart';

void main() {
  group('MelodyEvaluator DTW', () {
    test('aligns similar melodies and yields high score', () {
      // reference: 2 seconds at 100 fps, simple steady pitch with slight variation
      final ref = List<double>.generate(200, (i) => 440.0 + (i % 10 == 0 ? 1.0 : 0.0));
      // user: small cents deviations and minor timing wobble
      final user = List<double>.generate(200, (i) => 440.0 * (1.0 + ((i % 12 == 0) ? 0.002 : -0.001)));

      final evaluator = MelodyEvaluator();
      final result = evaluator.evaluate(reference: ref, user: user, frameRate: 100.0);

      expect(result.overallScore, greaterThan(0.7));
      expect(result.summary.isNotEmpty, true);
    });

    test('detects poorer alignment on shifted melody', () {
      final ref = List<double>.filled(150, 440.0);
      // user is off by ~1 semitone (approx 100 cents)
      final user = List<double>.filled(150, 466.16);

      final evaluator = MelodyEvaluator();
      final result = evaluator.evaluate(reference: ref, user: user, frameRate: 100.0);

      expect(result.overallScore, lessThan(0.5));
    });
  });
}

