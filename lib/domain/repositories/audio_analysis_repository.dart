import '../entities/audio_data.dart';
import '../entities/vocal_analysis.dart';

abstract class AudioAnalysisRepository {
  Future<VocalAnalysis> analyzeAudio(AudioData audioData);
  Future<List<double>> extractPitch(AudioData audioData);
  Future<List<double>> extractFormants(AudioData audioData);
  Future<BreathingType> classifyBreathing(AudioData audioData);
  Future<double> calculateSpectralTilt(AudioData audioData);
}