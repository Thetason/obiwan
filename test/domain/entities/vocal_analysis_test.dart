import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_trainer_ai/domain/entities/vocal_analysis.dart';

void main() {
  group('VocalAnalysis', () {
    late VocalAnalysis vocalAnalysis;
    
    setUp(() {
      vocalAnalysis = VocalAnalysis(
        pitchStability: 75.0,
        breathingType: BreathingType.diaphragmatic,
        resonancePosition: ResonancePosition.mixed,
        mouthOpening: MouthOpening.medium,
        tonguePosition: TonguePosition.lowFront,
        vibratoQuality: VibratoQuality.light,
        overallScore: 82,
        timestamp: DateTime(2024, 1, 1),
        fundamentalFreq: [220.0, 225.0, 230.0],
        formants: [800.0, 1200.0, 2500.0],
        spectralTilt: -9.5,
      );
    });
    
    test('should create VocalAnalysis with all properties', () {
      expect(vocalAnalysis.pitchStability, 75.0);
      expect(vocalAnalysis.breathingType, BreathingType.diaphragmatic);
      expect(vocalAnalysis.resonancePosition, ResonancePosition.mixed);
      expect(vocalAnalysis.mouthOpening, MouthOpening.medium);
      expect(vocalAnalysis.tonguePosition, TonguePosition.lowFront);
      expect(vocalAnalysis.vibratoQuality, VibratoQuality.light);
      expect(vocalAnalysis.overallScore, 82);
      expect(vocalAnalysis.fundamentalFreq, [220.0, 225.0, 230.0]);
      expect(vocalAnalysis.formants, [800.0, 1200.0, 2500.0]);
      expect(vocalAnalysis.spectralTilt, -9.5);
    });
    
    test('should create copy with modified properties', () {
      final modified = vocalAnalysis.copyWith(
        pitchStability: 85.0,
        overallScore: 90,
      );
      
      expect(modified.pitchStability, 85.0);
      expect(modified.overallScore, 90);
      expect(modified.breathingType, BreathingType.diaphragmatic);
      expect(modified.resonancePosition, ResonancePosition.mixed);
    });
    
    test('should convert to JSON correctly', () {
      final json = vocalAnalysis.toJson();
      
      expect(json['pitchStability'], 75.0);
      expect(json['breathingType'], 'diaphragmatic');
      expect(json['resonancePosition'], 'mixed');
      expect(json['mouthOpening'], 'medium');
      expect(json['tonguePosition'], 'lowFront');
      expect(json['vibratoQuality'], 'light');
      expect(json['overallScore'], 82);
      expect(json['fundamentalFreq'], [220.0, 225.0, 230.0]);
      expect(json['formants'], [800.0, 1200.0, 2500.0]);
      expect(json['spectralTilt'], -9.5);
    });
    
    test('should create from JSON correctly', () {
      final json = vocalAnalysis.toJson();
      final fromJson = VocalAnalysis.fromJson(json);
      
      expect(fromJson.pitchStability, vocalAnalysis.pitchStability);
      expect(fromJson.breathingType, vocalAnalysis.breathingType);
      expect(fromJson.resonancePosition, vocalAnalysis.resonancePosition);
      expect(fromJson.mouthOpening, vocalAnalysis.mouthOpening);
      expect(fromJson.tonguePosition, vocalAnalysis.tonguePosition);
      expect(fromJson.vibratoQuality, vocalAnalysis.vibratoQuality);
      expect(fromJson.overallScore, vocalAnalysis.overallScore);
      expect(fromJson.fundamentalFreq, vocalAnalysis.fundamentalFreq);
      expect(fromJson.formants, vocalAnalysis.formants);
      expect(fromJson.spectralTilt, vocalAnalysis.spectralTilt);
    });
    
    test('should compare equality correctly', () {
      final identical = VocalAnalysis(
        pitchStability: 75.0,
        breathingType: BreathingType.diaphragmatic,
        resonancePosition: ResonancePosition.mixed,
        mouthOpening: MouthOpening.medium,
        tonguePosition: TonguePosition.lowFront,
        vibratoQuality: VibratoQuality.light,
        overallScore: 82,
        timestamp: DateTime(2024, 1, 1),
        fundamentalFreq: [220.0, 225.0, 230.0],
        formants: [800.0, 1200.0, 2500.0],
        spectralTilt: -9.5,
      );
      
      final different = vocalAnalysis.copyWith(pitchStability: 80.0);
      
      expect(vocalAnalysis, equals(identical));
      expect(vocalAnalysis, isNot(equals(different)));
    });
    
    test('should have consistent hashCode', () {
      final identical = VocalAnalysis(
        pitchStability: 75.0,
        breathingType: BreathingType.diaphragmatic,
        resonancePosition: ResonancePosition.mixed,
        mouthOpening: MouthOpening.medium,
        tonguePosition: TonguePosition.lowFront,
        vibratoQuality: VibratoQuality.light,
        overallScore: 82,
        timestamp: DateTime(2024, 1, 1),
        fundamentalFreq: [220.0, 225.0, 230.0],
        formants: [800.0, 1200.0, 2500.0],
        spectralTilt: -9.5,
      );
      
      expect(vocalAnalysis.hashCode, equals(identical.hashCode));
    });
  });
}